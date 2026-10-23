#!/usr/bin/env node
/**
 * preset-declare.mjs —— 生成/校验 profile 内的 preset 声明块
 *
 * 背景：DSH 0.1.7 起 `agent-preset-registry` 不再扫描 `~/.dsh/.agent-presets/<id>/`，
 * 自定义预设必须以 `@deepseek-ai/dsh-agent-preset` 声明行注入 profile（注册表不接受
 * preset 路径，也不扫描目录）。于是同一份组合出现两处表示：
 *
 *   源（唯一权威）  <preset-root>/agent.cordis.yml
 *   副本（进程实读）profile patch 内 `id: preset-<id>` 声明的 `plugins:` 内联块
 *
 * 本工具消除二者漂移：副本必须由源生成，改源后跑 `apply`，`check` 进验证电池。
 *
 * 用法：
 *   node plans/preset-declare.mjs emit   [--id <id>] [--order N] [--root <dir>]
 *   node plans/preset-declare.mjs check  [--patch <profile-patch>] [--id <id>]
 *   node plans/preset-declare.mjs apply  [--patch <profile-patch>] [--id <id>] [--order N]
 * 说明：副本中同一 id 出现多处（重复声明）时，check/apply 一律以退出码 2 拒绝并提示人工保留 1 处。
 *      apply 为**原子替换**：写同目录临时文件 `${patch}.tmp-<pid>` 后 rename，保留原文件权限位；
 *      并发读者与中途崩溃都只会看到旧内容或新内容（绝不出现 0 字节/半截补丁）。
 *
 * profile patch 默认取 $DSH_PROFILE_PATCH，其次 ~/.dsh/profiles/desktop/cordis.patch.yml。
 * 退出码：0=一致/成功；1=漂移；2=环境或参数错误。
 *
 * 依赖：js-yaml（按 $DSH_CODEPUNK_TOOLS → ~/.dsh-codepunk/tools → $DSH_APP_ROOT →
 *      $DSH_ASAR 同级 → 当前目录 顺序发现）。找不到时 check 退化为「行内容比对」
 *      （忽略缩进，仍能捕获增删改，但报不出精确路径）。
 */
import { readFileSync, writeFileSync, copyFileSync, existsSync, writeSync,
         renameSync, chmodSync, statSync, unlinkSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';

const here = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(here, '..');
const INDENT = ' '.repeat(10);
const SOURCE_REL = 'agent.cordis.yml';
const ROLE_SOURCE_REL = 'role-presets.cordis.yml';

// ── 依赖发现（不硬编码任何平台路径） ─────────────────────────────────────────
function loadYaml() {
  const home = homedir();
  const cands = [
    process.env.DSH_CODEPUNK_TOOLS ?? '',
    join(home, '.dsh-codepunk', 'tools'),
    process.env.DSH_APP_ROOT ?? '',
    process.env.DSH_ASAR ? dirname(process.env.DSH_ASAR) : '',
    process.env.DSH_ASAR ? join(dirname(process.env.DSH_ASAR), 'app') : '',
    ROOT,
    process.cwd(),
  ].filter(Boolean);
  for (const base of cands) {
    if (!existsSync(join(base, 'node_modules'))) continue;
    try {
      const req = createRequire(join(base, 'noop.js'));
      return req('js-yaml');
    } catch {
      /* 继续找下一个候选 */
    }
  }
  return null;
}

/** `!!js` 在源组合里是普通标量（宿主自行求值），解析时按字符串透传。 */
function schemaFor(yaml) {
  const jsScalar = new yaml.Type('tag:yaml.org,2002:js', {
    kind: 'scalar',
    resolve: () => true,
    construct: (data) => String(data),
  });
  return yaml.DEFAULT_SCHEMA.extend([jsScalar]);
}

// F349（无 js-yaml 的降级模式）：取**首个有效行**判定文档根结构——`- ` 开头为块序列（本工具的追加前提），
//   其余（`key:` 映射 / `[...]`/`{...}` 流式）一律视为不兼容。仅用于拒答，不用于通过。
function textRootKind(text) {
  for (const raw of text.split('\n')) {
    const line = raw.replace(/\s+$/, '');
    const t = line.trim();
    if (t === '' || t.startsWith('#') || t === '---' || t.startsWith('%')) continue;
    if (/^\s/.test(line)) continue;                    // 缩进行属上一结构，不作根判定
    if (/^-(\s|$)/.test(t)) return 'seq';
    if (/^[[{]/.test(t)) return 'flow';
    return 'map';
  }
  return 'empty';
}

// ── 参数 ────────────────────────────────────────────────────────────────────
// 布尔开关（不吞下一个 token）；其余 --key 需要取值，缺失即报错，避免误吞后续选项。
const FLAGS = new Set(['append']);

function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    // F366：全预设统一用法约定（`-h`/`--help` ⇒ 用法 + rc=0）；此前被当子命令 ⇒ rc=2。
    if (a === '-h' || a === '--help') {
      console.log('用法：preset-declare.mjs <emit|check|apply> [--patch <profile-patch>] [--id <id>] '
        + '[--order N] [--root <dir>] [--append]  （首次安装：apply --append）');
      console.log('  emit  打印声明块（供 --patch 叠加或人工检视）');
      console.log('  check 比对声明源与 profile patch 副本（一致 rc=0 / 漂移 rc=1 / 无法核验 rc=2）');
      console.log('  apply 把声明块写入 profile patch（幂等；--append 用于首次安装）');
      console.log('退出码：0=一致或成功 · 1=存在漂移 · 2=用法错误或无法核验');
      process.exit(0);
    }
    if (!a.startsWith('--')) {
      out._.push(a);
      continue;
    }
    const eq = a.indexOf('=');
    if (eq >= 0) {
      out[a.slice(2, eq)] = a.slice(eq + 1);
      continue;
    }
    const key = a.slice(2);
    if (FLAGS.has(key)) {
      out[key] = true;
      continue;
    }
    const val = argv[i + 1];
    if (val === undefined || val.startsWith('--')) die(`选项 --${key} 缺少取值`);
    out[key] = val;
    i++;
  }
  return out;
}

const args = parseArgs(process.argv.slice(2));
const action = args._[0];
const ID = args.id ?? 'dsh-codepunk';
// F398：CLI 取值守卫。旧行为是 `--order=abc` 静默产出 `order: NaN`、`--order=2.5` 产出小数、
//   `--id ''` 产出 `- id: preset-`、`--id 'a b'` 产出含空格的 id，且全部 rc=0 —— apply 会把它们
//   原样写进 profile 副本（实测：apply --append --order=abc 后副本第 15 行为 `order: NaN`），
//   部署方见绿灯而产物不可用（id 为空时后续 check 还会报「存在 2 处声明」而自相矛盾）。
if (!/^[a-z0-9][a-z0-9._-]*$/.test(ID)) {
  die(`--id 取值非法：${JSON.stringify(ID)}（须匹配 ^[a-z0-9][a-z0-9._-]*$，例：dsh-codepunk）——`
    + '非法 id 会被原样写进 profile 副本，产品注册行为未定义');
}
const ORDER = Number(args.order ?? 5);
if (!Number.isSafeInteger(ORDER) || ORDER < 0) {
  die(`--order 取值非法：${JSON.stringify(args.order ?? 5)}（须为非负整数，例：5）——`
    + '非法 order 会被原样写进 profile 副本（NaN / 小数无意义）');
}
const PRESET_ROOT = resolve(args.root ?? ROOT);
const PATCH = resolve(
  args.patch ??
    process.env.DSH_PROFILE_PATCH ??
    join(homedir(), '.dsh', 'profiles', 'desktop', 'cordis.patch.yml'),
);
const SOURCE = join(PRESET_ROOT, SOURCE_REL);
const ROLE_SOURCE = join(PRESET_ROOT, ROLE_SOURCE_REL);

function die(msg, code = 2) {
  console.error(`  ✗ ${msg}`);
  process.exit(code);
}

if (!action || !['emit', 'check', 'apply'].includes(action)) {
  die('用法：preset-declare.mjs <emit|check|apply> [--patch <profile-patch>] [--id <id>] '
      + '[--order N] [--root <dir>] [--append]  （首次安装：apply --append）');
}

// ── 声明块渲染 ──────────────────────────────────────────────────────────────
const BAR = '# ' + '─'.repeat(76);

function headerLines() {
  return [
    BAR,
    '# 自定义 preset 声明（DSH 0.1.7+ 注册表不扫描目录，须以声明行注入 profile）',
    `# 源与权威：<preset-root>/${SOURCE_REL}`,
    '# 本块是其内联副本。改源后跑：node plans/preset-declare.mjs apply',
    '# 校验副本是否漂移：node plans/preset-declare.mjs check',
    '# 回滚：删除以下 insert 块',
    BAR,
  ];
}

function roleHeaderLines() {
  return [
    BAR,
    '# 角色 Agent Preset 声明（由 role-presets.cordis.yml 生成，勿手改）',
    '# 角色声明必须位于主 preset 之前；子代理通过 agentPreset 选择。',
    '# 校验：node plans/preset-declare.mjs check',
    BAR,
  ];
}

/**
 * 内联副本必须做的路径适配：独立目录挂载时 baseUrl = 预设目录；内联进 profile 后
 * baseUrl = profile 目录，所有 `new URL(<预设内相对路径>, baseUrl)` 都必须回到预设目录，
 * 否则技能目录、hooks 配置与钩子根目录都会解析到 profile 下。
 */
function adaptSourceLine(line) {
  const rewrites = [
    ["new URL('skills/', baseUrl)", `new URL('../../.agent-presets/${ID}/skills/', baseUrl)`],
    ["new URL('plans/hooks/hooks.json', baseUrl)", `new URL('../../.agent-presets/${ID}/plans/hooks/hooks.json', baseUrl)`],
    ["new URL('./', baseUrl)", `new URL('../../.agent-presets/${ID}/', baseUrl)`],
  ];
  for (const [from, to] of rewrites) {
    if (line.includes(from)) return line.replace(from, to);
  }
  return null;
}

function adaptLines(sourceLines) {
  const body = [];
  for (const line of sourceLines) {
    const adapted = adaptSourceLine(line);
    if (adapted) {
      const pad = ' '.repeat(Math.max(0, line.length - line.trimStart().length));
      body.push(`${pad}# 内联进 profile 后 baseUrl 指向 profile 目录，不再按预设目录解析；`);
      body.push(`${pad}# 此路径回到 ~/.dsh 再指向预设自带资源（由 preset-declare.mjs 生成，勿手改）。`);
      body.push(adapted);
    } else {
      body.push(line);
    }
  }
  // 源文件以换行结尾时 split('\n') 会多出一个空尾元素；不清掉它每次 apply 都会
  // 追加一个尾随空行（实测 +1 行/次，永不收敛）。
  while (body.length && !body[body.length - 1].trim()) body.pop();
  return body;
}

function renderRoleBlock(roleLines) {
  const body = adaptLines(roleLines);
  return [
    ...roleHeaderLines(),
    '- insert:',
    ...body.map((l) => (l.trim() ? '    ' + l : '')),
  ];
}

function renderBlock(sourceLines) {
  const body = adaptLines(sourceLines);
  return [
    ...headerLines(),
    '- insert:',
    `    - id: preset-${ID}`,
    `      name: '@deepseek-ai/dsh-agent-preset'`,
    '      config:',
    `        id: ${ID}`,
    `        order: ${ORDER}`,
    '        plugins:',
    ...body.map((l) => (l.trim() ? INDENT + l : '')),
  ];
}

function renderAll(roleLines, sourceLines) {
  return [...renderRoleBlock(roleLines), '', ...renderBlock(sourceLines)];
}

// ── 副本定位 ────────────────────────────────────────────────────────────────
function escapeRe(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function locateBlock(patchLines, rowId) {
  const anchor = new RegExp(`^\\s*- id: ${escapeRe(rowId)}\\s*$`);
  const start = patchLines.findIndex((l) => anchor.test(l));
  if (start < 0) return null;
  // 起点回溯：把「声明头注释 + `- insert:` 指令行」一并纳入替换区间。
  // 两个坑（实测）：① 只吞 `- insert:` 而不吞其上方注释头 → 每次 apply 重插 8 行，永不收敛；
  // ② 吞了 `- insert:` 却漏掉注释头 → 残留悬空指令行，YAML 结构被破坏。故须继续上溯吸收注释。
  let head = start;
  let absorbedInsert = false;
  for (;;) {
    if (head - 1 < 0) break;
    const prev = patchLines[head - 1];
    if (prev.trimStart().startsWith('#')) {
      head--;
      continue;
    }
    if (!absorbedInsert && /^\s*- insert:\s*$/.test(prev)) {
      head--;
      absorbedInsert = true;
      continue;
    }
    break;
  }
  let end = patchLines.length;
  for (let j = start + 1; j < patchLines.length; j++) {
    const line = patchLines[j];
    if (/^\s*- (insert|id|name|config)\s*:/.test(line) && !line.startsWith(INDENT)) {
      end = j;
      while (end - 1 > start && patchLines[end - 1].trimStart().startsWith('#')) end--;
      break;
    }
  }
  while (end - 1 > start && !patchLines[end - 1].trim()) end--;
  return { head, end };
}

function spanText(patchLines, span) {
  return patchLines.slice(span.head, span.end).join('\n');
}

/** 从 insert 块取出声明原文；自动去掉块内最小缩进，供无 js-yaml 时行比对。 */
function copyInsertLines(patchLines, span) {
  let start = -1;
  for (let j = span.head; j < span.end; j++) {
    if (patchLines[j].trim() === '- insert:') {
      start = j;
      break;
    }
  }
  if (start < 0) return null;
  const raw = [];
  let minIndent = null;
  for (let j = start + 1; j < span.end; j++) {
    const line = patchLines[j];
    if (!line.trim()) {
      raw.push('');
      continue;
    }
    const indent = line.match(/^\s*/)[0].length;
    if (minIndent === null || indent < minIndent) minIndent = indent;
    raw.push(line);
  }
  if (minIndent === null) return [];
  const out = raw.map((l) => (l.trim() ? l.slice(minIndent) : ''));
  while (out.length && !out[out.length - 1].trim()) out.pop();
  return out;
}

function insertEntriesFromSpan(patchLines, span, yaml) {
  if (!yaml) return null;
  try {
    const doc = yaml.load(spanText(patchLines, span), { schema: schemaFor(yaml) });
    if (!Array.isArray(doc) || !doc[0] || !Array.isArray(doc[0].insert)) return null;
    return doc[0].insert;
  } catch {
    return null;
  }
}

// ── 语义比对 ────────────────────────────────────────────────────────────────
/** 副本内联后 baseUrl 变为 profile 目录，故预设内路径被改写为回到预设目录——归一后应相等。 */
function normalizeCopyValue(value) {
  if (typeof value === 'string') {
    let s = value;
    // 预设根目录在源里是 `new URL('./', baseUrl)`；副本是回到预设根的目录 URL。
    // 先还原这一形态，再统一去掉其余 `../../.agent-presets/<id>/` 前缀。
    s = s.split(`new URL('../../.agent-presets/${ID}/', baseUrl)`).join("new URL('./', baseUrl)");
    s = s.split(`../../.agent-presets/${ID}/`).join('');
    return s;
  }
  if (Array.isArray(value)) return value.map(normalizeCopyValue);
  if (value && typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = normalizeCopyValue(v);
    return out;
  }
  return value;
}

function deepDiff(a, b, path = '', out = []) {
  if (out.length >= 40) return out;
  const ta = Array.isArray(a) ? 'array' : a === null ? 'null' : typeof a;
  const tb = Array.isArray(b) ? 'array' : b === null ? 'null' : typeof b;
  if (ta !== tb) {
    out.push(`${path || '<根>'}：类型 ${ta} → ${tb}`);
    return out;
  }
  if (ta === 'null') {
    if (a !== b) out.push(`${path || '<根>'}：null 差异`);
    return out;
  }
  if (ta === 'array') {
    if (a.length !== b.length) out.push(`${path || '<根>'}：长度 ${a.length} → ${b.length}`);
    for (let i = 0; i < Math.min(a.length, b.length); i++) deepDiff(a[i], b[i], `${path}[${i}]`, out);
    return out;
  }
  if (ta === 'object') {
    for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) {
      if (!(k in a)) out.push(`${path}.${k}：副本新增`);
      else if (!(k in b)) out.push(`${path}.${k}：副本缺失`);
      else deepDiff(a[k], b[k], `${path}.${k}`, out);
    }
    return out;
  }
  if (a !== b) {
    const show = (v) => (typeof v === 'string' && v.length > 60 ? v.slice(0, 60) + '…' : JSON.stringify(v));
    out.push(`${path || '<根>'}：${show(a)} → ${show(b)}`);
  }
  return out;
}

function summarizePlugins(entries) {
  return entries.map((e) => `${e?.id ?? '?'} (${e?.name ?? '?'})`);
}

function roleIdsFromSource(roleLines) {
  const ids = [];
  for (const line of roleLines) {
    const m = line.match(/^- id:\s*(\S+)\s*$/);
    if (m) ids.push(m[1]);
  }
  return ids;
}

function uniqueSpans(spans) {
  const seen = new Set();
  const out = [];
  for (const span of spans) {
    const key = `${span.head}:${span.end}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(span);
  }
  return out.sort((a, b) => a.head - b.head);
}

function findRoleSpans(patchLines, roleRowIds) {
  return uniqueSpans(roleRowIds.map((id) => locateBlock(patchLines, id)).filter(Boolean));
}

/** 角色声明共享一个顶层 `- insert:`；区间只覆盖角色行，不吞后续主 preset 的头注释。 */
function findRoleGroupSpan(patchLines, roleRowIds) {
  const spans = findRoleSpans(patchLines, roleRowIds);
  if (spans.length === 0) return null;
  let head = spans[0].head;
  for (let j = head - 1; j >= 0; j--) {
    const line = patchLines[j];
    if (!line.trim() || line.trimStart().startsWith('#')) continue;
    if (/^-\s*insert:\s*$/.test(line)) head = j;
    break;
  }
  // 把 insert 上方紧邻的角色声明头注释一并纳入替换区间；否则第二次 apply 会留下旧头注释。
  for (let j = head - 1; j >= 0; j--) {
    const line = patchLines[j];
    if (!line.trimStart().startsWith('#')) break;
    head = j;
  }
  return { head, end: spans[spans.length - 1].end };
}

function stripQuotes(s) {
  return String(s ?? '').trim().split(String.fromCharCode(39, 34)).join('');
}

function checkMainWrapper(patchLines, span, yaml) {
  const lines = patchLines.slice(span.head, span.end);
  const text = lines.join('\n');
  const probs = [];
  let decl = null;
  if (yaml) {
    try {
      const doc = yaml.load(text, { schema: schemaFor(yaml) });
      decl = Array.isArray(doc) && doc[0] && Array.isArray(doc[0].insert) ? doc[0].insert[0] : null;
    } catch {
      decl = null;
    }
  }
  if (decl) {
    if (decl.name !== '@deepseek-ai/dsh-agent-preset') probs.push('顶层 name 与期望不一致（当前 ' + String(decl.name) + '）');
    if (!decl.config || decl.config.id !== ID) probs.push('config.id 与期望不一致');
    if (!decl.config || String(decl.config.order) !== String(ORDER)) {
      probs.push(`config.order 与期望不一致（当前 ${decl.config ? decl.config.order : '缺失'}，期望 ${ORDER}）`);
    }
  } else {
    const nameLine = lines.find((l) => l.trimStart().startsWith('name:'));
    const idLine = lines.find((l) => l.trimStart().startsWith('id:') && !l.includes('- id:'));
    const orderLine = lines.find((l) => l.trimStart().startsWith('order:'));
    const nameVal = nameLine ? stripQuotes(nameLine.slice(nameLine.indexOf(':') + 1)) : '';
    const idVal = idLine ? stripQuotes(idLine.slice(idLine.indexOf(':') + 1)) : '';
    const orderVal = orderLine ? stripQuotes(orderLine.slice(orderLine.indexOf(':') + 1)) : '';
    if (nameVal !== '@deepseek-ai/dsh-agent-preset') probs.push('顶层 name 与期望不一致（当前 ' + nameVal + '）');
    if (idVal !== ID) probs.push('config.id 与期望不一致');
    if (orderVal !== String(ORDER)) probs.push(`config.order 与期望不一致（当前 ${orderVal || '缺失'}，期望 ${ORDER}）`);
  }
  if (probs.length) {
    console.log('  ✗ 声明包装漂移：' + probs.join('；') + '（修复：node plans/preset-declare.mjs apply）');
    return false;
  }
  return true;
}

function compareEntries(label, srcEntries, copyEntries) {
  const diffs = deepDiff(srcEntries, normalizeCopyValue(copyEntries));
  if (diffs.length === 0) {
    console.log(`  ✅ ${label}与源语义一致（${srcEntries.length} 条）`);
    return true;
  }
  console.log(`  ✗ ${label}与源漂移（语义比对）：源 ${srcEntries.length} 条 / 副本 ${copyEntries.length} 条`);
  for (const d of diffs.slice(0, 20)) console.log('     · ' + d);
  console.log('     修复：node plans/preset-declare.mjs apply');
  return false;
}

function compareLines(label, srcLines, copyLines) {
  const norm = (ls) => ls.map((l) => l.trim()).filter((l) => l && !l.startsWith('#'));
  const a = norm(srcLines);
  const b = norm(copyLines);
  if (a.length === b.length && a.every((l, i) => l === b[i])) {
    console.log(`  ✅ ${label}与源一致（行内容比对，${a.length} 行）`);
    return true;
  }
  console.log(`  ⚠ 无法判定是否漂移（缺 js-yaml，仅行内容比对；已忽略注释行）：${label}`);
  console.log(`     源 ${a.length} 行 / 副本 ${b.length} 行`);
  console.log('     启用语义核验：设 DSH_APP_ROOT 指向 DSH app 目录，或在 ~/.dsh-codepunk/tools 内 npm i js-yaml');
  const n = Math.max(a.length, b.length);
  let shown = 0;
  for (let i = 0; i < n && shown < 10; i++) {
    if (a[i] !== b[i]) {
      console.log(`     行 ${i + 1}：源 ${JSON.stringify((a[i] ?? '').slice(0, 70))}`);
      console.log(`              副本 ${JSON.stringify((b[i] ?? '').slice(0, 70))}`);
      shown++;
    }
  }
  return null;
}

/** 静态守卫：旧字段、agentPreset 可达性、fork 禁用、角色工具面边界。 */
function validateSources(roleLines, sourceLines, yaml) {
  if (!yaml) return;
  const schema = schemaFor(yaml);
  let mainEntries;
  let roleEntries;
  try {
    mainEntries = yaml.load(sourceLines.join('\n'), { schema });
    roleEntries = yaml.load(roleLines.join('\n'), { schema });
  } catch (e) {
    die(`源组合解析失败：${e.message}`);
  }
  if (!Array.isArray(mainEntries)) die('agent.cordis.yml 根节点不是序列');
  if (!Array.isArray(roleEntries)) die('role-presets.cordis.yml 根节点不是序列');

  const roleConfigIds = new Set();
  for (const role of roleEntries) {
    const id = role?.config?.id;
    if (typeof id !== 'string' || !id) die('角色 preset 缺 config.id');
    if (role?.id !== `preset-${id}`) die(`角色 preset 行 id 与 config.id 不一致：${role?.id ?? '?'} / ${id}`);
    if (roleConfigIds.has(id)) die(`角色 preset config.id 重复：${id}`);
    roleConfigIds.add(id);
    const plugins = role?.config?.plugins;
    if (!Array.isArray(plugins)) die(`角色 preset ${id} 缺 plugins`);
    if (!plugins.some((p) => p?.name === '@deepseek-ai/dsh-persona')) die(`角色 preset ${id} 缺 persona 插件`);
    if (plugins.some((p) => p?.name === '@deepseek-ai/dsh-tool-subagent')) die(`角色 preset ${id} 递归挂载 tool-subagent`);
    const hasWeb = plugins.some((p) => p?.name === '@deepseek-ai/dsh-tool-web');
    if (hasWeb !== id.endsWith('-research')) die(`角色 preset ${id} 的 tool-web 边界不符（仅 research 可挂）`);
  }

  const delegation = mainEntries.find((e) => e?.id === 'delegation');
  if (!delegation || !Array.isArray(delegation.config)) die('agent.cordis.yml 缺 delegation 分组');
  for (const entry of delegation.config) {
    if (entry?.name !== '@deepseek-ai/dsh-tool-subagent') continue;
    const cfg = entry.config ?? {};
    if ('persona' in cfg || 'toolFilter' in cfg) die(`tool-subagent ${entry.id} 仍含退役字段 persona/toolFilter`);
    if (entry.id === 'tool-subagent-fork') {
      if (entry.disabled !== true) die('tool-subagent-fork 必须显式 disabled: true');
      if ('agentPreset' in cfg) die('tool-subagent-fork 不得配置 agentPreset');
      continue;
    }
    if (entry.disabled) continue;
    if (cfg.provider === 'spawn') {
      if (typeof cfg.agentPreset !== 'string' || !cfg.agentPreset) die(`spawn 子代理 ${entry.id} 缺 agentPreset`);
      if (!roleConfigIds.has(cfg.agentPreset)) die(`spawn 子代理 ${entry.id} 的 agentPreset 无对应声明：${cfg.agentPreset}`);
    }
  }
}

// ── 动作 ────────────────────────────────────────────────────────────────────
if (!existsSync(SOURCE)) die(`源组合不存在：${SOURCE}`);
if (!existsSync(ROLE_SOURCE)) die(`角色 preset 源不存在：${ROLE_SOURCE}`);
const sourceLines = readFileSync(SOURCE, 'utf8').split('\n');
const roleLines = readFileSync(ROLE_SOURCE, 'utf8').split('\n');
const roleRowIds = roleIdsFromSource(roleLines);
if (roleRowIds.length === 0) die(`role-presets.cordis.yml 未发现角色声明：${ROLE_SOURCE}`);
const probeYaml = loadYaml();
validateSources(roleLines, sourceLines, probeYaml);

if (action === 'emit') {
  // F362（实测）：`process.stdout.write(...)` 紧接 `process.exit(0)` 时，stdout 在**管道**
  //   （`| cmd`、`$(...)`、子进程 capture）上是异步写，exit 立即终止进程 ⇒ 只写出管道缓冲
  //   （实测恰 64 KiB）内的部分；截断产物仍是**合法 YAML** 且含声明 id，故下游会静默采用
  //   半截声明（红证：`emit | wc -c` = 65536 vs 重定向 71493）。故改为同步写 fd 1。
  writeSync(1, renderAll(roleLines, sourceLines).join('\n') + '\n');
  process.exit(0);
}

if (!existsSync(PATCH)) die(`profile patch 不存在：${PATCH}`);
const patchText = readFileSync(PATCH, 'utf8');
const patchLines = patchText.split('\n');
// F341：既有补丁若是**非文本**或**不可解析的 YAML**，`apply --append` 会把声明块静默追加到损坏文件末尾
//   （产物仍无法被产品加载）却报「生效」；`check` 又只比对声明块文本 ⇒ 两者皆假绿灯。
//   此处先做机械守卫：非文本一律拒答；可解析性在 js-yaml 可用时校验（无法核验 ≠ 通过）。
if (patchText.includes('\0')) {
  die(`profile patch 含 NUL 字节（非文本文件）：${PATCH}`
      + '——无法核验其 YAML 结构，拒绝读写（无法核验 ≠ 通过；请从备份重建）');
}
if (probeYaml && patchText.trim() !== '') {
  let rootVal;
  try {
    rootVal = probeYaml.load(patchText, { schema: schemaFor(probeYaml) });
  } catch (e) {
    const msg = (e && e.message) ? String(e.message).split('\n')[0] : String(e);
    die(`profile patch 不是合法 YAML（${msg}）：${PATCH}`
        + '——追加/比对都会在损坏文件上给出假绿灯；请先修复或从备份重建再重试（本工具不擅自改写坏文件）');
  }
  // F349：**根结构前置校验**。profile patch 约定为序列（`- id: …` / `- insert: …`；见本文件头注与
  //   产品自带 patch）。旧实现只看「能否解析」：根为**映射**的补丁被追加 `- insert:` 项后，顶层同时出现
  //   映射与序列 ⇒ 产出**非法 YAML**，而工具仍打印「✅ 生效」并提示重启 DSH（operator 拿到坏补丁）。
  if (rootVal !== null && !Array.isArray(rootVal)) {
    const kind = (typeof rootVal === 'object') ? '映射' : typeof rootVal;
    die(`profile patch 根节点不是序列（当前为${kind}）：${PATCH}`
        + '——追加/替换声明块要求顶层为 `- id: …` / `- insert: …` 列表；'
        + '否则产物的顶层会同时含映射与序列而无法解析（请先改为序列结构）');
  }
}
if (!probeYaml && patchText.trim() !== '') {
  // 降级模式（无 js-yaml）：仍须拒答不兼容根结构，否则「追加后产物无法解析」照旧发生。
  const kind = textRootKind(patchText);
  if (kind === 'map' || kind === 'flow') {
    die(`profile patch 根节点不是序列（当前为${kind === 'flow' ? '流式集合' : '映射'}，文本判定）：${PATCH}`
        + '——追加/替换声明块要求顶层为 `- id: …` / `- insert: …` 列表；'
        + '否则产物的顶层会同时含映射与序列而无法解析（请先改为序列结构）');
  }
  // 含文档分隔符时追加会产出**多文档** YAML，而降级模式无法复核产物 ⇒ 拒答。
  //   首行 `---` 作为文档起始合法，其余 `---` 与任意 `...`（文档结束符）均为不安全信号。
  const sigLines = patchText.split('\n').map((l) => l.replace(/\s+$/, '')).filter((l) => l.trim() !== '');
  const seps = sigLines.filter((l) => l.trim() === '---' || l.trim() === '...');
  const leadingSep = sigLines.length > 0 && sigLines[0].trim() === '---' ? 1 : 0;
  if (seps.length - leadingSep > 0) {
    die(`profile patch 含文档分隔符（\`---\`/\`...\`）：${PATCH}`
        + '——追加会产出多文档 YAML，而当前环境缺 js-yaml 无法复核产物（无法核验 ≠ 通过）；'
        + '请安装 js-yaml（见本文件头注的依赖发现顺序）后重试');
  }
}

const mainRowId = `preset-${ID}`;
const countRow = (rowId) => (patchText.match(new RegExp(`^\\s*- id: ${escapeRe(rowId)}\\s*$`, 'gm')) ?? []).length;
const mainCount = countRow(mainRowId);
if (mainCount > 1) {
  die(`profile patch 中存在 ${mainCount} 处声明：id: ${mainRowId}`
      + '——重复声明将被产品重复注册或行为未定义；请保留 1 处（本工具不擅自删改多余块）');
}
for (const rowId of roleRowIds) {
  const n = countRow(rowId);
  if (n > 1) {
    die(`profile patch 中存在 ${n} 处声明：id: ${rowId}`
        + '——重复声明将被产品重复注册或行为未定义；请保留 1 处（本工具不擅自删改多余块）');
  }
}

const mainSpan = locateBlock(patchLines, mainRowId);
if (!mainSpan && !(action === 'apply' && args.append !== undefined)) {
  die(`profile patch 中找不到声明：id: ${mainRowId}（首次安装用 apply --append 追加）`);
}
if (!mainSpan && action === 'check') die(`profile patch 中找不到声明：id: ${mainRowId}`);

if (action === 'apply') {
  const roleBlock = renderRoleBlock(roleLines);
  const mainBlock = renderBlock(sourceLines);
  let lines = patchLines.slice();

  // 角色声明必须先集中到一个 insert 块，再整体放到主 preset 之前。
  const oldRoleSpan = findRoleGroupSpan(lines, roleRowIds);
  if (oldRoleSpan) lines.splice(oldRoleSpan.head, oldRoleSpan.end - oldRoleSpan.head);
  let currentMain = locateBlock(lines, mainRowId);
  if (!currentMain) {
    if (args.append === undefined) die(`profile patch 中找不到声明：id: ${mainRowId}`);
    while (lines.length && !lines[lines.length - 1].trim()) lines.pop();
    lines = [...lines, ...roleBlock, '', ...mainBlock];
  } else {
    // 移除主 preset 头前的分隔空行后再插入，保证重复 apply 不累积空行。
    let insertAt = currentMain.head;
    while (insertAt > 0 && !lines[insertAt - 1].trim()) insertAt--;
    lines.splice(insertAt, currentMain.head - insertAt, ...roleBlock, '');
    currentMain = locateBlock(lines, mainRowId);
    if (!currentMain) die('内部错误：插入角色声明后主 preset 定位失败');
    lines.splice(currentMain.head, currentMain.end - currentMain.head, ...mainBlock);
  }

  const mergedText = lines.join('\n');
  if (mergedText === patchText) {
    console.log(`  ✅ 无需改动，副本已与源一致：${ID}`);
    process.exit(0);
  }
  // ISO 串含 '.'（毫秒前），只去 [-:T] 会让备份名以尾随点结尾；一并去掉 '.' 并截到秒。
  const stamp = new Date().toISOString().replace(/[-:T.]/g, '').slice(0, 14);
  const backup = `${PATCH}.bak-${stamp}`;
  // F380（原子替换）：就地 writeFileSync 会**先截断原文件**再写入 —— 实测并发读者能读到 0 字节，
  //   进程被 SIGKILL/断电时用户平面补丁停在截断态，而 F349 的回滚只在正常路径执行，
  //   产品下次启动即读到一个不可用的 profile。改为「同目录临时文件 + rename」：
  //   同文件系统内 rename 是原子操作，读者只可能看到旧内容或新内容。
  //   rename 会替换 inode ⇒ 必须显式把原文件 mode 复制到临时文件（就地写本来会保留 mode）。
  const tmp = `${PATCH}.tmp-${process.pid}`;
  let prevMode = null;
  try { prevMode = statSync(PATCH).mode & 0o7777; } catch { /* 目标不存在：沿用进程 umask */ }
  try {
    copyFileSync(PATCH, backup);
    writeFileSync(tmp, mergedText, 'utf8');
    if (prevMode !== null) chmodSync(tmp, prevMode);
    renameSync(tmp, PATCH);
  } catch (e) {
    try { unlinkSync(tmp); } catch { /* 临时文件可能未创建 */ }
    const _p = (e && e.path) ? e.path : PATCH;
    const _c = (e && e.code) ? e.code : 'IO';
    const _m = (e && e.message) ? e.message : String(e);
    // F203：写入失败（如只读文件/只读挂载/权限不足）不得抛裸堆栈——给清晰消息并按契约用环境错误码 2
    console.error(`✗ 无法写入 profile patch：${_p}（${_c}：${_m}）——请检查文件权限或只读挂载`);
    process.exit(2);
  }
  // F349（写后自校验）：写前守卫只保证**输入**可解析、前置校验只覆盖根结构；产物本身仍须复核。
  //   不合规则从刚写的备份**回滚**并以 2 拒答——绝不让「✅ 生效」指向一个产品读不了的补丁。
  if (probeYaml) {
    try {
      probeYaml.load(readFileSync(PATCH, 'utf8'), { schema: schemaFor(probeYaml) });
    } catch (e) {
      const msg = (e && e.message) ? String(e.message).split('\n')[0] : String(e);
      try {
        copyFileSync(backup, PATCH);
        console.error(`  ↩︎ 已回滚：${PATCH} ← ${backup}`);
      } catch (e2) {
        console.error(`  ✗ 回滚失败（${e2 && e2.message ? e2.message : e2}）——请手工从 ${backup} 恢复`);
      }
      die(`写出自校验失败（${msg}）：${PATCH}`
          + '——本工具不产出无法解析的 profile patch（无法核验 ≠ 通过）');
    }
  }
  console.log(`  ✅ 已用源${mainSpan ? '重写' : '追加'}声明块：${ID}`);
  console.log(`     备份：${backup}`);
  console.log('     生效：重启 DSH Desktop（声明在进程启动时读取）');
  process.exit(0);
}

// check
const yaml = loadYaml();
const roleSpan = findRoleGroupSpan(patchLines, roleRowIds);
if (!roleSpan) {
  die('角色声明缺失——修复：node plans/preset-declare.mjs apply');
}
if (roleSpan.end > mainSpan.head) {
  die('角色声明必须位于主 preset 之前——修复：node plans/preset-declare.mjs apply');
}
const between = patchLines.slice(roleSpan.end, mainSpan.head)
  .filter((l) => l.trim() && !l.trimStart().startsWith('#'));
if (between.length) {
  die('角色声明与主 preset 之间夹带其他顶层条目——修复：node plans/preset-declare.mjs apply');
}

let roleOk;
let mainOk;
if (!yaml) {
  const roleCopy = copyInsertLines(patchLines, roleSpan);
  if (!roleCopy) die('角色声明块内找不到 - insert:');
  roleOk = compareLines('角色声明副本', roleLines, roleCopy);
  if (roleOk === null) process.exit(2);
} else {
  const schema = schemaFor(yaml);
  let srcRoleEntries;
  try {
    srcRoleEntries = yaml.load(roleLines.join('\n'), { schema });
  } catch (e) {
    die(`角色源解析失败：${e.message}`);
  }
  const copyRoleEntries = insertEntriesFromSpan(patchLines, roleSpan, yaml);
  if (!copyRoleEntries) die('角色声明块不是合法的 insert 序列');
  roleOk = compareEntries('角色声明副本', srcRoleEntries, copyRoleEntries);
}

if (!roleOk) process.exit(1);

if (!yaml) {
  const mainCopy = copyInsertLines(patchLines, mainSpan);
  if (!mainCopy) die('主 preset 声明块内找不到 - insert:');
  mainOk = compareLines('主 preset 声明副本', sourceLines, mainCopy);
  if (mainOk === null) process.exit(2);
  if (mainOk && !checkMainWrapper(patchLines, mainSpan, null)) process.exit(1);
} else {
  const schema = schemaFor(yaml);
  let srcEntries;
  try {
    srcEntries = yaml.load(sourceLines.join('\n'), { schema });
  } catch (e) {
    die(`源组合解析失败：${e.message}`);
  }
  const mainInsert = insertEntriesFromSpan(patchLines, mainSpan, yaml);
  const copyEntries = Array.isArray(mainInsert) && mainInsert[0]?.config?.plugins;
  if (!Array.isArray(copyEntries)) die('主 preset 声明块内缺 config.plugins 序列');
  mainOk = compareEntries('主 preset 声明副本', srcEntries, copyEntries);
  if (mainOk && !checkMainWrapper(patchLines, mainSpan, yaml)) mainOk = false;
}

if (mainOk) {
  console.log(`  ✅ 角色与主 preset 声明均与源一致：${ID}`);
  process.exit(0);
}
process.exit(1);

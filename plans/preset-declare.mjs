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
 *
 * profile patch 默认取 $DSH_PROFILE_PATCH，其次 ~/.dsh/profiles/desktop/cordis.patch.yml。
 * 退出码：0=一致/成功；1=漂移；2=环境或参数错误。
 *
 * 依赖：js-yaml（按 $DSH_CODEPUNK_TOOLS → ~/.dsh-codepunk/tools → $DSH_APP_ROOT →
 *      $DSH_ASAR 同级 → 当前目录 顺序发现）。找不到时 check 退化为「行内容比对」
 *      （忽略缩进，仍能捕获增删改，但报不出精确路径）。
 */
import { readFileSync, writeFileSync, copyFileSync, existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';

const here = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(here, '..');
const INDENT = ' '.repeat(10);
const SOURCE_REL = 'agent.cordis.yml';

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

// ── 参数 ────────────────────────────────────────────────────────────────────
// 布尔开关（不吞下一个 token）；其余 --key 需要取值，缺失即报错，避免误吞后续选项。
const FLAGS = new Set(['append']);

function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
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
const ORDER = Number(args.order ?? 5);
const PRESET_ROOT = resolve(args.root ?? ROOT);
const PATCH = resolve(
  args.patch ??
    process.env.DSH_PROFILE_PATCH ??
    join(homedir(), '.dsh', 'profiles', 'desktop', 'cordis.patch.yml'),
);
const SOURCE = join(PRESET_ROOT, SOURCE_REL);

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
    `# 自定义 preset 声明（DSH 0.1.7+ 注册表不扫描目录，须以声明行注入 profile）`,
    `# 源与权威：<preset-root>/${SOURCE_REL}`,
    `# 本块是其内联副本。改源后跑：node plans/preset-declare.mjs apply`,
    `# 校验副本是否漂移：node plans/preset-declare.mjs check`,
    `# 回滚：删除以下 insert 块`,
    BAR,
  ];
}

/**
 * 内联副本必须做的一处适配：`customSkillDirs` 用 `new URL('skills/', baseUrl)` 定位。
 * 独立目录挂载时 baseUrl = 预设目录；内联进 profile 后 baseUrl = profile 目录，
 * 必须改写为回到预设目录的相对路径，否则技能目录解析不到。
 */
function adaptSourceLine(line) {
  if (!line.includes("new URL('skills/', baseUrl)")) return null;
  return line.replace("new URL('skills/', baseUrl)", `new URL('../../.agent-presets/${ID}/skills/', baseUrl)`);
}

function renderBlock(sourceLines) {
  const body = [];
  for (const line of sourceLines) {
    const adapted = adaptSourceLine(line);
    if (adapted) {
      const pad = ' '.repeat(Math.max(0, line.length - line.trimStart().length));
      body.push(`${pad}# 内联进 profile 后 baseUrl 指向 profile 目录，不再按预设目录解析；`);
      body.push(`${pad}# 此路径回到 ~/.dsh 再指向预设自带 skills/（由 preset-declare.mjs 生成，勿手改）。`);
      body.push(adapted);
    } else {
      body.push(line);
    }
  }
  // 源文件以换行结尾时 split('\n') 会多出一个空尾元素；不清掉它每次 apply 都会
  // 追加一个尾随空行（实测 +1 行/次，永不收敛）。
  while (body.length && !body[body.length - 1].trim()) body.pop();
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

// ── 副本定位 ────────────────────────────────────────────────────────────────
function locateBlock(patchLines) {
  const anchor = new RegExp(`^\\s*- id: preset-${ID.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*$`);
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

/** 从 patch 文本里取出副本的 plugins 原文（10 空格缩进区；保留块内空行——块标量靠空行分段）。 */
function copyPluginLines(patchLines, span) {
  let start = -1;
  for (let j = span.head; j < span.end; j++) {
    if (patchLines[j].trim() === 'plugins:') {
      start = j;
      break;
    }
  }
  if (start < 0) return null;
  const out = [];
  for (let j = start + 1; j < span.end; j++) {
    const l = patchLines[j];
    if (!l.trim()) {
      out.push('');
      continue;
    }
    if (!l.startsWith(INDENT)) break;
    out.push(l.slice(INDENT.length));
  }
  while (out.length && !out[out.length - 1].trim()) out.pop();
  return out;
}

// ── 语义比对 ────────────────────────────────────────────────────────────────
/** 副本内联后 baseUrl 变为 profile 目录，故 skills 路径被改写为回到预设目录——归一后应相等。 */
function normalizeCopyText(s) {
  if (typeof s !== 'string') return s;
  return s.replace(new RegExp(`\\.\\./\\.\\./\\.agent-presets/${ID}/`, 'g'), '');
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

// ── 动作 ────────────────────────────────────────────────────────────────────
if (!existsSync(SOURCE)) die(`源组合不存在：${SOURCE}`);
const sourceLines = readFileSync(SOURCE, 'utf8').split('\n');

if (action === 'emit') {
  process.stdout.write(renderBlock(sourceLines).join('\n') + '\n');
  process.exit(0);
}

if (!existsSync(PATCH)) die(`profile patch 不存在：${PATCH}`);
const patchText = readFileSync(PATCH, 'utf8');
const patchLines = patchText.split('\n');
const span = locateBlock(patchLines);
if (!span && !(action === 'apply' && args.append !== undefined)) {
  die(`profile patch 中找不到声明：id: preset-${ID}（首次安装用 apply --append 追加）`);
}
if (!span && action === 'check') die(`profile patch 中找不到声明：id: preset-${ID}`);

if (action === 'apply') {
  const block = renderBlock(sourceLines);
  const merged = span
    ? [...patchLines.slice(0, span.head), ...block, ...patchLines.slice(span.end)]
    : [...patchLines, ...block];
  const mergedText = merged.join('\n');
  if (mergedText === patchText) {
    console.log(`  ✅ 无需改动，副本已与源一致：${ID}`);
    process.exit(0);
  }
  // ISO 串含 '.'（毫秒前），只去 [-:T] 会让备份名以尾随点结尾；一并去掉 '.' 并截到秒。
  const stamp = new Date().toISOString().replace(/[-:T.]/g, '').slice(0, 14);
  const backup = `${PATCH}.bak-${stamp}`;
  copyFileSync(PATCH, backup);
  writeFileSync(PATCH, mergedText, 'utf8');
  console.log(`  ✅ 已用源${span ? '重写' : '追加'}声明块：${ID}`);
  console.log(`     备份：${backup}`);
  console.log('     生效：重启 DSH Desktop（声明在进程启动时读取）');
  process.exit(0);
}

// check
const yaml = loadYaml();
const copyLines = copyPluginLines(patchLines, span);
if (!copyLines) die(`声明块内找不到 plugins: 段：id: preset-${ID}`);

if (!yaml) {
  // 降级比对口径与语义比对一致：忽略注释行与空行（apply 会插入适配注释，计为差异即假阳性）
  const norm = (ls) => ls.map((l) => l.trim()).filter((l) => l && !l.startsWith('#'));
  const a = norm(sourceLines);
  const b = norm(copyLines);
  const same = a.length === b.length && a.every((l, i) => l === b[i]);
  if (same) {
    console.log(`  ✅ 声明副本与源一致（行内容比对，${a.length} 行）：${ID}`);
    process.exit(0);
  }
  // 忽略注释后仍有差异：**无法判定**是真实漂移还是环境差异——不冒充「确认漂移」
  console.log(`  ⚠ 无法判定是否漂移（缺 js-yaml，仅行内容比对；已忽略注释行）：${ID}`);
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
  process.exit(2);            // 2=环境/无法核验（区别于 1=确认漂移）
}

const schema = schemaFor(yaml);
let srcEntries, copyEntries;
try {
  srcEntries = yaml.load(sourceLines.join('\n'), { schema });
} catch (e) {
  die(`源组合解析失败：${e.message}`);
}
try {
  const copyDoc = yaml.load(copyLines.join('\n'), { schema });
  copyEntries = Array.isArray(copyDoc) ? copyDoc : [];
} catch (e) {
  die(`副本解析失败：${e.message}`);
}

// 归一：副本 skills 路径改写
for (const e of copyEntries) {
  const dirs = e?.config?.customSkillDirs;
  if (Array.isArray(dirs)) e.config.customSkillDirs = dirs.map(normalizeCopyText);
}

const diffs = deepDiff(srcEntries, copyEntries);

if (diffs.length === 0) {
  const a = summarizePlugins(srcEntries);
  const b = summarizePlugins(copyEntries);
  const sameNames = a.length === b.length && a.every((x, i) => x === b[i]);
  console.log(`  ✅ 声明副本与源语义一致（${srcEntries.length} 条）：${ID}`);
  if (!sameNames) console.log('     ⚠ 条目名称顺序不同但结构一致，请复核');
  process.exit(0);
}

console.log(`  ✗ 声明副本与源漂移（语义比对）：${ID}`);
console.log(`     源 ${srcEntries.length} 条 / 副本 ${copyEntries.length} 条`);
for (const d of diffs.slice(0, 20)) console.log('     · ' + d);
console.log('     修复：node plans/preset-declare.mjs apply');
process.exit(1);

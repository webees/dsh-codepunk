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
 *
 * profile patch 默认取 $DSH_PROFILE_PATCH，其次 ~/.dsh/profiles/desktop/cordis.patch.yml。
 * 退出码：0=一致/成功；1=漂移；2=环境或参数错误。
 *
 * 依赖：js-yaml（按 $DSH_CODEPUNK_TOOLS → ~/.dsh-codepunk/tools → $DSH_APP_ROOT →
 *      $DSH_ASAR 同级 → 当前目录 顺序发现）。找不到时 check 退化为「行内容比对」
 *      （忽略缩进，仍能捕获增删改，但报不出精确路径）。
 */
import { readFileSync, writeFileSync, copyFileSync, existsSync, writeSync } from 'node:fs';
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
  // F362（实测）：`process.stdout.write(...)` 紧接 `process.exit(0)` 时，stdout 在**管道**
  //   （`| cmd`、`$(...)`、子进程 capture）上是异步写，exit 立即终止进程 ⇒ 只写出管道缓冲
  //   （实测恰 64 KiB）内的部分；截断产物仍是**合法 YAML** 且含声明 id，故下游会静默采用
  //   半截声明（红证：`emit | wc -c` = 65536 vs 重定向 71493）。故改为同步写 fd 1。
  writeSync(1, renderBlock(sourceLines).join('\n') + '\n');
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
const probeYaml = loadYaml();
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
// 重复声明检测（F302）：同一 id 出现多处时产品注册行为未定义，且本工具既不改也不报 ⇒ 先显式拒绝（无法核验 ≠ 通过）。
const declCount = patchText.split(`id: preset-${ID}`).length - 1;
if (declCount > 1) {
  die(`profile patch 中存在 ${declCount} 处声明：id: preset-${ID}`
      + `——重复声明将被产品重复注册或行为未定义；请保留 1 处（本工具不擅自删改多余块）`);
}
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
  try {
    copyFileSync(PATCH, backup);
    writeFileSync(PATCH, mergedText, 'utf8');
  } catch (e) {
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
  // F170：包装字段亦须一致——此前只 deepDiff 内嵌条目，改**顶层 name / config.id** 不会被发现
  //   （生成侧 apply 写包装、校验侧只验内嵌 → 生成/校验不齐，与 F169 同族）。
  {
    const wrapIdx = patchLines.findIndex((l) => l.includes(`- id: preset-${ID}`));
    if (wrapIdx >= 0) {
      // F326：窗口须覆盖**整个声明块**——固定 8 行窗口在块内插入注释行（`order:` 被下移）时会误报
      //   「config.order 缺失（期望 N）」，值其实在位且正确 ⇒ 假红 + 消息失实（独立复核实测）。
      const wrapLines = patchLines.slice(wrapIdx, span && span.end > wrapIdx ? span.end : wrapIdx + 8);
      const wrap = wrapLines.join('\n');
      const probs = [];
      // F305：包装字段须按 **YAML 语义**比对（解析后取值），不得用文本正则/切片——
      //   否则语义等价改写（给纯量加引号、改引号风格）会被误判为漂移（实测：`id: "dsh-codepunk"`
      //   触发假红「config.id 与期望不一致」，而内嵌条目走 deepDiff 语义比对，两者口径不一）。
      let wrapDoc = null;
      try {
        const indent = wrapLines[0].match(/^\s*/)[0].length;
        const dedented = wrapLines.map((l) => l.replace(new RegExp(`^\\s{0,${indent}}`), ''));
        const doc = yaml.load(dedented.join('\n'), { schema });
        wrapDoc = Array.isArray(doc) ? doc[0] : doc;
      } catch (e) {
        wrapDoc = null; // 解析失败 ⇒ 退回文本口径（保守：宁可报漂移，不得假通过）
      }
      let nameVal = '';
      if (wrapDoc && typeof wrapDoc.name === 'string') nameVal = wrapDoc.name;
      else {
        const nameLine = wrapLines.find((l) => l.trimStart().startsWith('name:'));
        nameVal = nameLine ? nameLine.slice(nameLine.indexOf(':') + 1).trim().split(String.fromCharCode(39, 34)).join('') : '';
      }
      if (nameVal !== '@deepseek-ai/dsh-agent-preset') probs.push('顶层 name 与期望不一致（当前 ' + nameVal + '）');
      const idSemantic = wrapDoc && wrapDoc.config && typeof wrapDoc.config.id === 'string' ? wrapDoc.config.id === ID : null;
      const idOk = idSemantic !== null ? idSemantic : new RegExp('^\\s*id:\\s*' + ID + '\\s*$', 'm').test(wrap);
      if (!idOk) probs.push('config.id 与期望不一致');
      // F325：包装 `config.order` 亦须比对——生成侧 `apply` 写 order（renderBlock），校验侧此前只比
      //   name / config.id，实测副本 `order: 9`（期望 5）时 check 仍报「语义一致」而 apply 会改写
      //   ⇒ 校验漏项、漂移可静默通过。口径与 apply 一致：期望值取 ORDER（CLI 默认 5）。
      let orderVal = null;
      if (wrapDoc && wrapDoc.config && wrapDoc.config.order !== undefined && wrapDoc.config.order !== null) {
        orderVal = String(wrapDoc.config.order);
      } else {
        const orderLine = wrapLines.find((l) => l.trimStart().startsWith('order:'));
        if (orderLine) orderVal = orderLine.slice(orderLine.indexOf(':') + 1).trim();
      }
      if (orderVal === null) probs.push(`config.order 缺失（期望 ${ORDER}）`);
      else if (orderVal !== String(ORDER)) probs.push(`config.order 与期望不一致（当前 ${orderVal}，期望 ${ORDER}）`);
      if (probs.length) {
        console.log('  ✗ 声明包装漂移：' + probs.join('；') + '（修复：node plans/preset-declare.mjs apply）');
        process.exit(1);
      }
    }
  }
  console.log(`  ✅ 声明副本与源语义一致（${srcEntries.length} 条）：${ID}`);
  if (!sameNames) console.log('     ⚠ 条目名称顺序不同但结构一致，请复核');
  process.exit(0);
}

console.log(`  ✗ 声明副本与源漂移（语义比对）：${ID}`);
console.log(`     源 ${srcEntries.length} 条 / 副本 ${copyEntries.length} 条`);
for (const d of diffs.slice(0, 20)) console.log('     · ' + d);
console.log('     修复：node plans/preset-declare.mjs apply');
process.exit(1);

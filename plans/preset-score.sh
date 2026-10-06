#!/usr/bin/env bash
# =============================================================================
# preset-score.sh —— dsh-codepunk 15 指标评分器（run-score-15 rubric 固化）
# -----------------------------------------------------------------------------
# 用法: preset-score.sh [预设根]
# 输出: 15 项得分（每项 100 分为满分门槛）+ 失分证据 + 是否「全满分」
# 退出码: 0=15 项全 100；1=存在未满分项；2=环境/用法错误（预设根不存在等）
#
# 判据原则：优先客观可验证（解析/实跑/计数/grep），主观项给出明确扣分锚点。
# 环境变量:
#   OLD_NAME=<旧名>      启用品牌卫生回归检查（默认跳过，不在仓库内硬编码旧名）
#   PWSH_VALIDATOR=<路径> PowerShell 语法校验器（默认 ~/.dsh-codepunk/tools/ps-validate.mjs）
# bash 3.2 兼容（macOS 自带）：不使用关联数组/mapfile。
# =============================================================================
set -u

# F195：本工具多处判据依赖**多字节**模式（占位符、编号、①②③…）。C/POSIX locale 下 BSD 工具链会
#   逐字节处理，`grep`/`cut` 甚至报 `Invalid argument` / `Illegal byte sequence` → 判据失效或**误报**
#   （假拒绝；F192/F193 已各实证一处）。故在当前 locale 为 C/POSIX（或未设）且系统存在 UTF-8 locale 时固定之。
# F196：以 `locale charmap` 判定**是否 UTF-8**，而非枚举 C/POSIX——非 UTF-8 locale（如 ISO-8859 系）同样会
#   逐字节处理并误报（实证：`LC_ALL=de_DE.ISO8859-15` 下 doc-consistency 误报 1 处不一致）。
case "$(locale charmap 2>/dev/null)" in
  UTF-8|utf8|UTF8) ;;
  *)
    for _l in en_US.UTF-8 UTF-8; do
      if locale -a 2>/dev/null | grep -qx "$_l"; then export LC_ALL="$_l"; break; fi
    done ;;
esac
# -h/--help：打印头部用法（与其余脚本一致的通用约定）
case "${1:-}" in
  -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" 2>/dev/null || { echo "✗ 预设根不存在: $ROOT"; exit 2; }   # 2 = 环境/用法错误（与全仓约定一致）
# 仓库标识校验：存在但非本预设仓库的根路径属「用法/环境错误」（exit 2），
#   否则检查器会在错误的树上判 1、甚至挂起（实测：preset-score 于错误根 rc=124）。
if [ ! -f skills/dsh-codepunk-workflow/SKILL.md ] || [ ! -d plans ]; then
  printf '✗ 根路径不是本预设仓库（缺 skills/dsh-codepunk-workflow/SKILL.md 或 plans/）: %s\n' "$ROOT" >&2
  exit 2
fi


# ---- 评分累计器（15 项独立变量） -------------------------------------------
A1=100; A2=100; A3=100; A4=100; A5=100
B6=100; B7=100; B8=100; B9=100; B10=100
B11=100; B12=100; B13=100; B14=100; B15=100
EV=""   # 证据累积

ded() { # $1=指标变量名 $2=扣分 $3=证据
  eval "cur=\$$1"
  cur=$(( cur - $2 )); [ "$cur" -lt 0 ] && cur=0
  eval "$1=$cur"
  EV="${EV}
  - [$1 −$2] $3"
}
full() { # $1=指标变量名
  eval "v=\$$1"
  [ "$v" -eq 100 ]
}
named() { case "$1" in
  A1) echo "A1 策略性";; A2) echo "A2 质量";; A3) echo "A3 准确性";;
  A4) echo "A4 规范性";; A5) echo "A5 精简度";; B6) echo "B6 一致性";;
  B7) echo "B7 完整性";; B8) echo "B8 可执行性";; B9) echo "B9 可维护性";;
  B10) echo "B10 跨平台性";; B11) echo "B11 安全性";; B12) echo "B12 可发现性";;
  B13) echo "B13 语义保真";; B14) echo "B14 工程卫生";; B15) echo "B15 演进性";;
esac; }

SKILL="skills/dsh-codepunk-workflow/SKILL.md"
REF="skills/dsh-codepunk-workflow/references"
BM="skills/dsh-codepunk-workflow/benchmarks"

echo "===== dsh-codepunk 15 指标评分 ====="

# ── A1 策略性 ───────────────────────────────────────────────────────────────
for s in "需求确认" "规划与组队" "并行开发" "巡检与交接" "解散与评分" "再规划"; do
  grep -q "$s" "$SKILL" 2>/dev/null || ded A1 15 "SKILL 缺阶段: $s"
done
for s in "双门闩" "实现三角" "审查门" "合并门" "总库"; do
  grep -q "$s" "$SKILL" 2>/dev/null || ded A1 8 "SKILL 缺承重机制: $s"
done
for s in "create_goal" "get_goal" "update_goal"; do
  grep -q "$s" "$SKILL" 2>/dev/null || ded A1 6 "SKILL 缺 goal 工具链: $s"
done

# ── A2 质量 ─────────────────────────────────────────────────────────────────
if git rev-parse --git-dir >/dev/null 2>&1; then
TODO=$(git grep -nE "TODO|FIXME|XXX([^X]|$)|待补|待填|WIP[:：(]" -- '*.md' '*.yml' ':(exclude)skills/dsh-codepunk-workflow/benchmarks/**' 2>/dev/null | grep -viE "todo_write|allowParallel|todo\b" | head -3)
[ -n "$TODO" ] && ded A2 20 "占位残留: $(echo "$TODO" | head -1 | cut -c1-70)"
else
  ded A2 20 "占位残留无法核验（非 git 工作区）——无法核验 ≠ 通过"
fi
# 命令示例可执行性：SKILL 引用的脚本必须真实存在
# （原实现只声明 BADCMD 却从不累加 —— 死分支，恒不扣分，属假满分口径）
BADCMD=0
# 扫描源：SKILL.md + references/*.md（benchmarks 属调研档案，含历史路径，排除）；
# 带 ~ 的正式位写法（~/.dsh-codepunk/scripts/x.sh）先归一到 scripts/x.sh 再判定。
SKILLREFS="$(ls "$SKILL" "$REF"/*.md 2>/dev/null | grep -v '/benchmarks/')"
for p in $(grep -hoE '(~\.dsh-codepunk/)?(plans|scripts)/[a-z0-9._-]+\.(sh|py|mjs)' $SKILLREFS 2>/dev/null | sed 's#^~/\.dsh-codepunk/##' | sort -u); do
  case "$p" in
    plans/*)   [ -e "./$p" ] || BADCMD=$((BADCMD+1)) ;;
    scripts/*)
      # 总库正式位优先；缺失时回退仓内源副本（plans/ 同名文件）。
      # 不回退会因 DSH_CODEPUNK_HOME 指向沙箱/他处而误报（环境依赖型假失败）。
      _name="${p#scripts/}"
      [ -e "${DSH_CODEPUNK_HOME:-$HOME/.dsh-codepunk}/$p" ] || [ -e "./plans/$_name" ] || BADCMD=$((BADCMD+1)) ;;
  esac
done
[ "$BADCMD" -gt 0 ] && ded A2 15 "SKILL/references 引用了不存在的脚本 $BADCMD 处"
# 占位符标注检查（模板示例须标注）
UNLABELED=$(grep -rnE "<[A-Z_]{3,}>" "$SKILL" 2>/dev/null | grep -vcE "占位|示例|模板|<project_id>|<run_id>|<task_id>|<PROVIDER>|<MODEL>" || true)
[ "${UNLABELED:-0}" -gt 3 ] && ded A2 10 "未标注的占位符 ${UNLABELED} 处"

# 行尾空白 / 连续 3+ 空行（格式卫生）
if command -v python3 >/dev/null 2>&1; then
WS=$(python3 - <<'PYEOF2'
import subprocess
files = subprocess.run(['git','ls-files'], capture_output=True, text=True).stdout.split()
bad = 0
for f in files:
    try: txt = open(f, encoding='utf-8').read()
    except (OSError, UnicodeDecodeError): continue
    for ln in txt.split("\n"):
        if ln != ln.rstrip() and ln.strip(): bad += 1
    if "\n\n\n\n" in txt: bad += 1
print('UNVERIFIED' if not files else bad)
PYEOF2
)
if [ "$WS" = "UNVERIFIED" ]; then
  ded A2 10 "格式卫生无法核验（非 git 工作区或 git ls-files 失败）——无法核验 ≠ 通过"
elif [ -z "${WS:-}" ]; then
  ded A2 10 "格式卫生无法核验（python3 不可用或执行失败）——无法核验 ≠ 通过"
elif [ "$WS" -gt 0 ]; then
  ded A2 10 "行尾空白/连续空行 ${WS} 处"
fi
fi   # command -v python3

# ── A3 准确性 ───────────────────────────────────────────────────────────────
NB=$(ls "$BM"/*.md 2>/dev/null | wc -l | tr -d ' ')
# 只在 README 的 benchmarks/ 行上取计数：原文取「首个 ×N」，任何更早出现的 ×N
# （如目录树里其它条目带计数）都会让本项误判为不准确。
DOCB=$(grep -E '^\s+benchmarks/' README.md 2>/dev/null | grep -oE '×[0-9]+' | head -1 | tr -d '×')
[ -n "$DOCB" ] && [ "$DOCB" != "$NB" ] && ded A3 20 "README 声称基准 ×${DOCB}，实测 ${NB}"
NS=$(ls plans/*.sh 2>/dev/null | wc -l | tr -d ' ')
DOCS=$(grep -cE '^\s+\S+\.sh\s+#' README.md 2>/dev/null)
[ "${DOCS:-0}" != "$NS" ] && ded A3 20 "README 列脚本 ${DOCS}，实测 ${NS}"
NPW=$(grep -cE '^\s+\S+\.ps1\s+#' README.md 2>/dev/null)
NW=$(ls plans/windows/*.ps1 2>/dev/null | wc -l | tr -d ' ')
[ "${NPW:-0}" != "$NW" ] && ded A3 15 "README 列 Windows 脚本 ${NPW}，实测 ${NW}"
# 引用的 references 路径存在性
MISREF=$(grep -rhoE 'references/[a-z0-9-]+\.md' "$SKILL" 2>/dev/null | sort -u | while read -r r; do [ -f "skills/dsh-codepunk-workflow/$r" ] || echo "$r"; done)
[ -n "$MISREF" ] && ded A3 20 "悬空引用: $(echo "$MISREF" | tr '\n' ' ')"
# 过时结论仍作现行表述
grep -qE "D087[^|]*现行实现" "$REF/standard.md" 2>/dev/null && ded A3 25 "D087 已废弃却仍自称「现行实现」"

# ── A4 规范性 ───────────────────────────────────────────────────────────────
PARSE="skip"
if command -v ruby >/dev/null 2>&1; then
  # F215：两路径谓词须**语义一致**（与 preset-audit 的 F214 同族）——统一为「name 为**非空字符串**」。
  ruby -ryaml -e 'd=YAML.load_file("agent.cordis.yml"); exit(d.is_a?(Array) && d.all?{|r| r.is_a?(Hash) && r["name"].is_a?(String) && !r["name"].empty?} ? 0 : 1)' 2>/dev/null && PARSE="ok" || PARSE="fail"
elif command -v node >/dev/null 2>&1 && [ -d "$HOME/.dsh-codepunk/tools/node_modules/js-yaml" ]; then
  node -e 'const y=require(process.env.HOME+"/.dsh-codepunk/tools/node_modules/js-yaml");const d=y.load(require("fs").readFileSync("agent.cordis.yml","utf8"));process.exit(Array.isArray(d)&&d.every(r=>r&&typeof r.name==="string"&&r.name.length>0)?0:1)' 2>/dev/null && PARSE="ok" || PARSE="fail"   # F215：与 ruby 路径同语义
fi
[ "$PARSE" = "fail" ] && ded A4 100 "agent.cordis.yml 解析失败"
# 决策号冲突/跳号
DUPD=$(grep -oE '^\| D[0-9]{3} ' "$REF/standard.md" 2>/dev/null | tr -d '| ' | sort | uniq -d)
[ -n "$DUPD" ] && ded A4 20 "决策号重复: $(echo "$DUPD" | tr '\n' ' ')"
# 文件命名规范（references/benchmarks 均 kebab-case .md）
BADNAME=$(ls "$REF"/*.md "$BM"/*.md 2>/dev/null | xargs -n1 basename | grep -vE '^[a-z0-9]+(-[a-z0-9]+)*\.md$' | head -3)
[ -n "$BADNAME" ] && ded A4 10 "命名不符 kebab-case: $(echo "$BADNAME" | tr '\n' ' ')"
# 品牌卫生（OLD_NAME 驱动）
if [ -n "${OLD_NAME:-}" ]; then
  N=$(git grep -ic -- "$OLD_NAME" 2>/dev/null | awk -F: '{s+=$2}END{print s+0}')
  [ "${N:-0}" -ne 0 ] && ded A4 50 "旧名残留 ${N} 处"
fi

# ── A5 精简度 ───────────────────────────────────────────────────────────────
SZ=$(wc -c < "$SKILL" | tr -d ' ')
[ "$SZ" -gt 32768 ] && ded A5 50 "SKILL ${SZ}B 超预算 32768" && ded A5 $(( (SZ-32768)/64 )) "超预算按比例追加扣分"
# 成段重复检测：只算「实质段落」——按**字符**（非字节）≥60 且非结构行。
#   理由：①各基准共用的小节标题/表格头属正常结构；②中文一行 30 字 ≈ 85 字节，
#   按字节计会把短标语误判为长段落，故按字符计。
# F194：缺 python3 时不得抛裸 `command not found`（会把**环境缺口**误报成质量缺陷），
#   而应与套件其它工具一致地标注「无法核验 ≠ 通过」并给出扣分理由。
if command -v python3 >/dev/null 2>&1; then
DUPSEG=$(python3 - <<'PYEOF2'
import glob, io
seen = {}
for fp in glob.glob("**/*.md", recursive=True):
    if "/.git/" in fp: continue
    try: lines = io.open(fp, encoding="utf-8", errors="replace").read().splitlines()
    except OSError: continue
    for ln in lines:
        t = ln.strip()
        if len(t) < 60: continue
        if t[0] in "#>|*-": continue
        if t.startswith("**") and t.count("**") >= 2 and len(t.split("**")[1]) < 30: continue
        seen[t] = seen.get(t, 0) + 1
dups = [k for k, v in seen.items() if v > 1]
print(" ||| ".join(d[:70] for d in dups[:2]))
PYEOF2
)
else
  ded A5 15 "成段重复无法核验（缺 python3）——无法核验 ≠ 通过"
  DUPSEG=""
fi
[ -n "$DUPSEG" ] && ded A5 15 "成段重复: $(echo "$DUPSEG" | head -1 | cut -c1-60)"

# ── B6 一致性 ───────────────────────────────────────────────────────────────
# 术语混用（中英双写须成对出现才算违规；此处查同义词混用）
# 判据改为**双向**计数比对（F134：旧判据绑定已不存在的旧措辞「工程主责（run-lead）」，
#   致该扣分永不可达=死守卫）：任一侧使用 run-lead 别名而另一侧从不使用 → 术语混用。
# 注意：`grep -c` 零命中时输出 0 但退出 1——若写 `|| echo 0` 会得到**两行**（"0\n0"），
#   使 `[ "$X" -eq 0 ]` 整数比较失败、分支静默不触发（F135：负向探针抓出的自身缺陷）。
SK_ALIAS=$(grep -c "run-lead" "$SKILL" 2>/dev/null); SK_ALIAS=${SK_ALIAS:-0}
RO_ALIAS=$(grep -c "run-lead" "$REF/roles.md" 2>/dev/null); RO_ALIAS=${RO_ALIAS:-0}
if [ "$SK_ALIAS" -gt 0 ] && [ "$RO_ALIAS" -eq 0 ]; then
  ded B6 10 "roles.md 未使用 run-lead 术语"
elif [ "$RO_ALIAS" -gt 0 ] && [ "$SK_ALIAS" -eq 0 ]; then
  ded B6 10 "SKILL 未引入 run-lead 术语（roles.md 单侧使用）"
fi
# 工具正式位描述一致
POSREF=$(grep -c "\.dsh-codepunk/scripts/" "$SKILL" 2>/dev/null)
[ "${POSREF:-0}" -eq 0 ] && ded B6 15 "SKILL 未说明工具正式位"

# ── B7 完整性 ───────────────────────────────────────────────────────────────
[ -f "$REF/standard.md" ] || ded B7 25 "缺 references/standard.md（决策登记表）"
[ -f "$REF/roles.md" ] || ded B7 25 "缺 references/roles.md"
[ -f "$REF/learned-skills.md" ] || ded B7 25 "缺 references/learned-skills.md"
# 岗位人设 ↔ 组合条目一一对应
ROLES=$(grep -oE 'tool-subagent-[a-z-]+' agent.cordis.yml | sort -u | wc -l | tr -d ' ')
[ "$ROLES" -lt 9 ] && ded B7 20 "岗位人设仅 ${ROLES} 个（应 ≥9）"
# 决策号在登记表有条目
# F174：standard.md 缺失时跳过本比对（其缺失已由 B7 扣分），否则内层 grep 会向输出抛 raw 报错，
#   并把**所有** D 号误报为「登记表缺」（误导性扣分）。
DN=""
if [ -f "$REF/standard.md" ]; then
  DN=$(grep -oE 'D0[0-9]{2}' "$SKILL" | sort -u | while read -r d; do grep -q "| $d " "$REF/standard.md" 2>/dev/null || echo "$d"; done)
fi
[ -n "$DN" ] && ded B7 20 "SKILL 引用但登记表缺: $(echo "$DN" | tr '\n' ' ')"

# ── B8 可执行性 ─────────────────────────────────────────────────────────────
for f in plans/*.sh; do bash -n "$f" 2>/dev/null || ded B8 25 "bash -n 失败: $f"; done
PV="${PWSH_VALIDATOR:-$HOME/.dsh-codepunk/tools/ps-validate.mjs}"
if [ -f "$PV" ] && command -v node >/dev/null 2>&1; then
  # ps-validate 退出码语义：0=通过 · 1=语法错误 · 2=依赖缺失（校验器不可用）。
  # 把 2 与 1 混为一谈会错误归因为「语法失败」，故分列。
  node "$PV" plans/windows/*.ps1 >/dev/null 2>&1; PV_RC=$?
  case "$PV_RC" in
    0) ;;
    2) echo "  ℹ PowerShell 校验器依赖缺失（退出码 2），本次跳过；启用见 README「PowerShell 校验」" >&2 ;;
    *) ded B8 25 "PowerShell 语法校验失败（退出码 ${PV_RC}）" ;;
  esac
else
  echo "  ℹ PowerShell 语法校验跳过：无校验器（\$PV）。启用：见 README「PowerShell 校验」" >&2
fi
bash plans/preset-audit.sh >/dev/null 2>&1 || ded B8 25 "preset-audit.sh 自跑未满分"

# ── B9 可维护性 ─────────────────────────────────────────────────────────────
grep -q "## 维护公约" README.md 2>/dev/null || grep -q "维护公约" CONTRIBUTING.md 2>/dev/null || ded B9 20 "缺维护公约"
grep -q "平台对等" CONTRIBUTING.md 2>/dev/null || ded B9 20 "缺平台对等公约"
grep -q "提交前检查清单\|提 PR 的门槛" CONTRIBUTING.md 2>/dev/null || ded B9 20 "缺 PR 门槛清单"
grep -qE "已被.*反驳|⚠废弃|作废" "$REF/standard.md" 2>/dev/null || ded B9 20 "决策表无废弃态标记机制"

# ── B10 跨平台性 ────────────────────────────────────────────────────────────
grep -q "process.platform === 'win32'" agent.cordis.yml 2>/dev/null || ded B10 20 "缺 Windows shell 门控"
grep -q "process.platform !== 'win32'" agent.cordis.yml 2>/dev/null || ded B10 20 "缺 POSIX shell 门控"
NP=$(ls plans/windows/*.ps1 2>/dev/null | wc -l | tr -d ' ')
[ "$NP" -lt 4 ] && ded B10 20 "Windows 脚本仅 ${NP} 个（应 ≥4）"
# F233：原判据仅 `[ -f ]`（**存在性**）⇒ 空 `.gitattributes` 也算通过 —— 而该文件承载的「换行策略」是 README
#   明确指向的跨平台不变量（第 370 轮曾实测：仓内统一 LF、ps1 检出 CRLF）。故加**非空 + 含 eol 规则**两项，并给出诚实理由。
if [ ! -f .gitattributes ]; then ded B10 15 "缺 .gitattributes（换行策略）"
elif [ ! -s .gitattributes ] || ! grep -q 'eol=' .gitattributes 2>/dev/null; then
  ded B10 15 ".gitattributes 为空或未含任何 eol 规则（换行策略名存实亡）"
fi
# 硬编码用户绝对路径
HARDP=$(git grep -nE "/Users/[a-z]+/|/home/[a-z]+/" -- plans/ '*.md' 2>/dev/null | grep -vE "例|示例|如 \`|/Users/\[" | head -2)
[ -n "$HARDP" ] && ded B10 20 "硬编码用户绝对路径: $(echo "$HARDP" | head -1 | cut -c1-70)"
# BSD/GNU 专有未兜底
# F186：扫描须排除**守卫自身**（`preset-score.sh` 的消息文本含这些字面）与**自检 harness**
#   （`checker-self-test.sh` 的变异载荷必然含这些字面）——否则豁免/命中都会**自触发**：
#   早先的豁免被自身源码命中 → 扣分恒假；不排除则健康仓库被误扣（假拒绝）。
SCAN_SH=$(ls plans/*.sh 2>/dev/null | grep -vE 'preset-score\.sh|checker-self-test\.sh')
if grep -qE "sed -i ''|stat -f%z[^|]*$" $SCAN_SH 2>/dev/null; then
  grep -qE "sed -i ''" $SCAN_SH 2>/dev/null && ! grep -qE "sed_i[[:space:]]" $SCAN_SH 2>/dev/null && ded B10 20 "sed -i ''（BSD 专有）无兜底"
  # F186：`stat -f%z` 同为 BSD 专有（GNU 侧为 `stat -c%s`）；**原实现只进入外层 if 却不扣分**，
  #   使该半边守卫恒假（macOS 专用用法可免罚）——此处补扣分，与本项「BSD/GNU 专有未兜底」的声明一致。
  grep -qE "stat -f%z" $SCAN_SH 2>/dev/null && ! grep -qE "stat_z[[:space:]]" $SCAN_SH 2>/dev/null \
    && ded B10 20 "stat -f%z（BSD 专有）无兜底封装"
fi

# ── B11 安全性 ──────────────────────────────────────────────────────────────
bash plans/dsh-codepunk-leak-guard.sh --tree >/dev/null 2>&1 || ded B11 50 "泄露防护门未通过"
CRED=$(git grep -nE "sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY" -- . 2>/dev/null | head -1)
[ -n "$CRED" ] && ded B11 50 "凭据形态命中"
grep -q "denylist.txt" "$REF/file-hygiene.md" 2>/dev/null || ded B11 15 "禁词「留本地」机制未文档化"

# ── B12 可发现性 ────────────────────────────────────────────────────────────
for s in "## 定位" "## 快速开始" "## 目录结构" "## 平台支持"; do
  grep -q "$s" README.md 2>/dev/null || ded B12 15 "README 缺节: $s"
done
grep -qE "^### 1\.1|^## " "$SKILL" 2>/dev/null || ded B12 15 "SKILL 无分节导航"

# ── B13 语义保真 ────────────────────────────────────────────────────────────
# 硬规则覆盖：范围**自 SKILL 推导**（R 编号最大值），逐号校验——既能覆盖新增规则，也能发现**缺号**。
#   旧写法硬编码 `1 2 … 14`，SKILL 增至 R15 后 R15 即失去覆盖（F143：注释也停留在「R1–R14」）。
# 覆盖面取**独立权威声称**（README 的「硬规则 R1–R15」）：若从 SKILL 自身推导最大值，删掉末条规则会
#   同步降低范围从而「自证齐全」（轮次 147 的对照实验实证），必须用外部声称做上界。
RN=$(grep -oE '硬规则 R1[–-]R[0-9]+' README.md 2>/dev/null | grep -oE '[0-9]+$' | head -1)
RN=${RN:-0}
[ "$RN" -eq 0 ] && RN=$(grep -oE '^\| R[0-9]+ ' "$SKILL" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1)
RN=${RN:-0}
for i in $(seq 1 "$RN" 2>/dev/null); do
  grep -qE "\| R$i \||R${i}（" "$SKILL" 2>/dev/null || ded B13 5 "SKILL 缺硬规则 R$i"
done
# 关键阈值在位
grep -q "thresholdRatio: 0.6" agent.cordis.yml 2>/dev/null || ded B13 15 "缺 thresholdRatio 0.6 阈值"
# 压缩后约束强度词（MUST/禁止/绝不）仍在
grep -qE "MUST|绝不|禁止" "$SKILL" 2>/dev/null || ded B13 20 "约束强度词丢失"

# ── B14 工程卫生 ────────────────────────────────────────────────────────────
FSYNC=$(for p in plans/*.sh; do f=$(basename "$p"); diff -q "$HOME/.dsh-codepunk/scripts/$f" "$p" >/dev/null 2>&1 || echo "$f"; done)
WSYNC=$(for p in plans/windows/*.ps1; do [ -f "$p" ] || continue; f=$(basename "$p"); diff -q "$HOME/.dsh-codepunk/scripts/$f" "$p" >/dev/null 2>&1 || echo "$f"; done)
SYNC="$(printf '%s %s' "$FSYNC" "$WSYNC" | tr -s ' ' ' ' | sed 's/^ *//; s/ *$//')"
[ -n "$SYNC" ] && ded B14 25 "plans↔scripts 不同步: $SYNC"
for f in LICENSE .gitattributes .gitignore; do
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 || ded B14 15 "未跟踪发布必备文件: $f"
done
STRAY=$(git status --short 2>/dev/null | grep -c '^??' || true)
[ "${STRAY:-0}" -gt 0 ] && ded B14 10 "工作区有 ${STRAY} 个未跟踪项（可能杂散）"
# 工作区物理杂散（被忽略但仍占工作区；D079 卫生纪律：不留杂散）
DS=$(find . -name '.DS_Store' -not -path './.git/*' 2>/dev/null | wc -l | tr -d ' ')
[ "${DS:-0}" -gt 0 ] && ded B14 10 "工作区有 ${DS} 个 .DS_Store 杂散"

# 注册表 schema 合法性（本地总库；不存在则跳过）：能过真实 YAML 解析器 + 键名一致
IDX="$HOME/.dsh-codepunk/INDEX.yaml"
if [ -f "$IDX" ] && command -v ruby >/dev/null 2>&1; then
  ruby -ryaml -e '
    d = YAML.load_file(ARGV[0])
    raise "顶层非映射" unless d.is_a?(Hash)
    raise "缺 schema_version" unless d.key?("schema_version")
    raise "缺 projects 或非数组" unless d["projects"].is_a?(Array) || d["projects"].nil?
  ' "$IDX" 2>/dev/null || ded B14 20 "总库 INDEX.yaml schema 非法（真实 YAML 解析失败或键名不符）"
elif [ -f "$IDX" ]; then
  # F216：INDEX 存在但**无 ruby** → 旧实现**静默跳过**该校验（判据消失而不告知 = 「缺失即通过」）。
  #   与本套件「无法核验 ≠ 通过」口径一致，此处按失分处理并说明原因（可用 python3 解析的可选增强见台账 ℹ）。
  ded B14 20 "总库 INDEX.yaml schema 无法核验（缺 ruby）——无法核验 ≠ 通过（装 ruby 后重跑）"
fi
# 本地脚本正式位与本仓源副本的 schema 约定一致性由 F2 同步检查覆盖

# ── B15 演进性 ──────────────────────────────────────────────────────────────
grep -qE "版本|version" "$REF/learned-skills.md" 2>/dev/null || ded B15 20 "learned-skills 缺版本列"
grep -qE "升级|废弃" "$REF/skill-governance.md" 2>/dev/null || ded B15 20 "缺 skill 升级/废弃机制"
grep -q "knowledge" "$SKILL" 2>/dev/null || ded B15 15 "SKILL 未说明知识库布局"
grep -q "D0[0-9][0-9]" "$REF/standard.md" 2>/dev/null || ded B15 20 "无决策登记路径"

# ── 汇总 ────────────────────────────────────────────────────────────────────
echo
NOTFULL=0
for v in A1 A2 A3 A4 A5 B6 B7 B8 B9 B10 B11 B12 B13 B14 B15; do
  eval "s=\$$v"
  mark="✅"; [ "$s" -lt 100 ] && { mark="✗"; NOTFULL=$((NOTFULL+1)); }
  printf "  %s %-14s %3s\n" "$mark" "$(named $v)" "$s"
done

echo
if [ -n "$EV" ]; then
  echo "---- 失分证据 ----"
  printf '%s\n' "$EV"
  echo
fi

echo "===== 结论 ====="
if [ "$NOTFULL" -eq 0 ]; then
  echo "15/15 全满分 —— 本轮计为一次满分"
  exit 0
fi
echo "未满分 $NOTFULL 项 —— 需继续优化"
exit 1

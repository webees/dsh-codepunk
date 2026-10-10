#!/usr/bin/env bash
# =============================================
# preset-score.sh —— dsh-codepunk 16 指标评分器（rubric 固化：策略/质量/准确性/规范性/精简度/一致性/完整性/可执行性/可维护性/跨平台性/安全性/可发现性/语义保真/工程卫生/演进性/内容卫生）
# ---------------------------------------------
# 用法: preset-score.sh [预设根]
# 输出: 16 项得分（每项 100 分为满分门槛）+ 失分证据 + 是否「全满分」
# 退出码: 0=16 项全 100；1=存在未满分项；2=环境/用法错误（预设根不存在等）
#
# 判据原则：优先客观可验证（解析/实跑/计数/grep），主观项给出明确扣分锚点。
# 环境变量:
#   OLD_NAME=<旧名>      启用品牌卫生回归检查（默认跳过，不在仓库内硬编码旧名）
#   PWSH_VALIDATOR=<路径> PowerShell 语法校验器（默认 ~/.dsh-codepunk/tools/ps-validate.mjs）
# bash 3.2 兼容（macOS 自带）：不使用关联数组/mapfile。
# =============================================
set -u

_EG="$(dirname "${BASH_SOURCE[0]:-$0}")/env-guard.sh"; [ -r "$_EG" ] || { echo "✗ 缺 ${_EG}（无法核验）" >&2; exit 2; }; . "$_EG"  # F195/F197+F421 守卫库
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


# ---- 评分累计器（16 项独立变量） -------------------------------------------
A1=100; A2=100; A3=100; A4=100; A5=100
B6=100; B7=100; B8=100; B9=100; B10=100
B11=100; B12=100; B13=100; B14=100; B15=100; B16=100
EV=""   # 证据累积

# F405（依赖预检，MUST）：扣分判据的抽取管道（`grep -hoE … | sed … | sort -u`、`tr`/`cut`/`find`）依赖
#   下列外部命令。缺失时**必须**判「无法核验 ≠ 通过」（rc=2），绝不静默降级为通过 ——
#   实证：缺 sed 时 A2 的「引用了不存在的脚本」循环体一次都不执行，BADCMD 恒 0 ⇒ 该扣分项静默消失。
for _t in git awk sed grep cut tr; do
  command -v "$_t" >/dev/null 2>&1 \
    || { echo "✗ 缺少必需工具 ${_t} ⇒ 无法核验 ≠ 通过（rc=2）" >&2; exit 2; }
done

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
  B16) echo "B16 内容卫生";;
esac; }

SKILL="skills/dsh-codepunk-workflow/SKILL.md"
REF="skills/dsh-codepunk-workflow/references"
BM="skills/dsh-codepunk-workflow/benchmarks"

echo "===== dsh-codepunk 16 指标评分 ====="

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
files = [f for f in subprocess.run(['git','ls-files', '-z'], capture_output=True, text=True).stdout.split('\0') if f]  # F419：`-z` + NUL 切分（`.split()` 分词 ⇒ 含空白文件名被拆碎 ⇒ 漏扫）
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
# 只在 README 的 benchmarks/ 行上取计数，且与 doc-consistency 第 1 类同一口径（`N 篇`，
# 前缀 × 可有可无）：曾只认 `×N`，README 改写为「# 基准调研 N 篇」后取值为空 ⇒
# A3 静默空转（README 声称与实际不符不再扣分）。口径以本行为准，改 README 措辞无需改门禁。
DOCB=$(grep -E '^\s+benchmarks/' README.md 2>/dev/null | grep -oE '[0-9]+ 篇' | head -1 | grep -oE '[0-9]+')
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
# F399：js-yaml 回退候选与 `verify-battery.sh` 对齐（含 `$DSH_APP_ROOT` 指向的 DSH 安装）。
YAML_DIR=""
if [ -d "$HOME/.dsh-codepunk/tools/node_modules/js-yaml" ]; then
  YAML_DIR="$HOME/.dsh-codepunk/tools/node_modules/js-yaml"
elif [ -n "${DSH_APP_ROOT:-}" ] && [ -d "${DSH_APP_ROOT}/node_modules/js-yaml" ]; then
  YAML_DIR="${DSH_APP_ROOT}/node_modules/js-yaml"
fi
if command -v ruby >/dev/null 2>&1; then
  # F215：两路径谓词须**语义一致**（与 preset-audit 的 F214 同族）——统一为「name 为**非空字符串**」。
  # F309：同 preset-audit A1 —— Psych 4/5（ruby >= 3.1）默认禁用别名，本仓配置的
  #   YAML 锚点会让 YAML.load_file 抛 Psych::AliasesNotEnabled ⇒ 跨版本修法：先带
  #   aliases: true，Psych 3 不认该关键字时回退旧调用。
  ruby -ryaml -e 'begin; d=YAML.load_file("agent.cordis.yml", aliases: true); rescue ArgumentError; d=YAML.load_file("agent.cordis.yml"); end; exit(d.is_a?(Array) && d.all?{|r| r.is_a?(Hash) && r["name"].is_a?(String) && !r["name"].empty?} ? 0 : 1)' 2>/dev/null && PARSE="ok" || PARSE="fail"
elif command -v node >/dev/null 2>&1 && [ -n "$YAML_DIR" ]; then
  YAML_DIR="$YAML_DIR" node -e 'const y=require(process.env.YAML_DIR);const d=y.load(require("fs").readFileSync("agent.cordis.yml","utf8"));process.exit(Array.isArray(d)&&d.every(r=>r&&typeof r.name==="string"&&r.name.length>0)?0:1)' 2>/dev/null && PARSE="ok" || PARSE="fail"   # F215：与 ruby 路径同语义
fi
[ "$PARSE" = "fail" ] && ded A4 100 "agent.cordis.yml 解析失败"
# F399：`PARSE=skip` 旧行为**既不扣分也不提示**（判据消失而不告知）——同族 F216 已判为「缺失即通过」。
#   且旧实现只认 `$HOME/.dsh-codepunk/tools/node_modules/js-yaml`（本机该路径不存在），而 `verify-battery.sh`
#   与 `plans/preset-declare.mjs` 都接受 `$DSH_APP_ROOT/node_modules/js-yaml` 回退 ⇒ 同套件口径不一。
[ "$PARSE" = "skip" ] && echo "  ℹ A4 结构解析无法核验（缺 ruby，且未找到 js-yaml：设 DSH_APP_ROOT 指向 DSH app 目录，或在 ~/.dsh-codepunk/tools 内 npm i js-yaml）——无法核验 ≠ 通过" >&2
# 决策号冲突/跳号
DUPD=$(grep -oE '^\| D[0-9]{3} ' "$REF/standard.md" 2>/dev/null | tr -d '| ' | sort | uniq -d)
[ -n "$DUPD" ] && ded A4 20 "决策号重复: $(echo "$DUPD" | tr '\n' ' ')"
# F263：治理矩阵（skill-governance.md「编号一致性（D/P/R 定义与引用、重复号）」行）声称由
#   `preset-audit` B7/D1/D3 与本组**并列**承担，但实测**重复 R 号**（SKILL 硬规则表追加第二条 `| R9 |`）
#   在 `doc-consistency`（rc=0）／`preset-audit`（100/100）／本组（全满分）**三工具下全部放行**，
#   而重复 **D** 号确被上方抓获 ⇒ D 有覆盖、R 缺失（**覆盖不对称**）。此处**同构**补 R 号重复检测。
DUPR=$(grep -oE '^\| R[0-9]{1,2} ' skills/dsh-codepunk-workflow/SKILL.md 2>/dev/null | tr -d '| ' | sort | uniq -d)
[ -n "$DUPR" ] && ded A4 20 "硬规则号重复: $(echo "$DUPR" | tr '\n' ' ')"
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
import io, os
seen = {}
# F339：glob("**/*.md", recursive=True) 默认跟随符号链接 ⇒ 检出含链接环时无限递归、评分门永不返回
#   （实测 rc=124）；改用 os.walk（followlinks=False）。
_md = []
for _dp, _dns, _fns in os.walk("."):
    _dns[:] = [d for d in _dns if d != ".git"]
    for _fn in _fns:
        if _fn.endswith(".md"):
            _md.append(os.path.relpath(os.path.join(_dp, _fn), "."))
for fp in _md:
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
bash plans/preset-audit.sh >/dev/null 2>&1 || ded B8 25 "preset-audit.sh 自跑未满分（详见其输出：先跑 bash plans/preset-audit.sh 定位具体 F 项）"

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
# 覆盖面取**独立权威声称**（README 的「硬规则 R1–R16」）：若从 SKILL 自身推导最大值，删掉末条规则会
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
# F423：B14 的「plans↔scripts 同步」此前只对照 `plans/*.sh`（与 Windows 侧 `.ps1`），缺 `plans/*.py`/
#   `plans/*.mjs` ⇒ 这两类脚本的总库副本陈旧时 B14 仍满分（实测 `plans/preset-compat.py` 陈旧而满分）。
#   此处与 `plans/preset-audit.sh` 的 F2 正向对照保持同一扩展名集合。
FSYNC=$(for p in plans/*.sh plans/*.py plans/*.mjs; do f=$(basename "$p"); diff -q "$HOME/.dsh-codepunk/scripts/$f" "$p" >/dev/null 2>&1 || echo "$f"; done)
WSYNC=$(for p in plans/windows/*.ps1; do [ -f "$p" ] || continue; f=$(basename "$p"); diff -q "$HOME/.dsh-codepunk/scripts/$f" "$p" >/dev/null 2>&1 || echo "$f"; done)
SYNC="$(printf '%s %s' "$FSYNC" "$WSYNC" | tr -s ' ' ' ' | sed 's/^ *//; s/ *$//')"
[ -n "$SYNC" ] && ded B14 25 "plans↔scripts 不同步: $SYNC"
for f in LICENSE .gitattributes .gitignore; do
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 || ded B14 15 "未跟踪发布必备文件: $f"
done
STRAY=$(git status --short 2>/dev/null | grep -c '^??' || true)
[ "${STRAY:-0}" -gt 0 ] && ded B14 10 "工作区有 ${STRAY} 个未跟踪项（可能杂散）"
# 工作区物理杂散（被忽略但仍占工作区；D079 卫生纪律：不留杂散）
# F372：`find` 缺失时管道取到 0 行 ⇒ 原实现静默判「无杂散」；MUST 显式按「无法核验」扣分。
if command -v find >/dev/null 2>&1; then
  DS=$(find . -name '.DS_Store' -not -path './.git/*' 2>/dev/null | wc -l | tr -d ' ')
  [ "${DS:-0}" -gt 0 ] && ded B14 10 "工作区有 ${DS} 个 .DS_Store 杂散"
else
  ded B14 10 "无法核验 .DS_Store 杂散（缺 find）——无法核验 ≠ 通过"
fi

# 注册表 schema 合法性（本地总库；不存在则跳过）：能过真实 YAML 解析器 + 键名一致
IDX="$HOME/.dsh-codepunk/INDEX.yaml"
if [ -f "$IDX" ] && command -v ruby >/dev/null 2>&1; then
  # 跨版本 + 跨 locale 双修（与 link.sh ② 同构）：
  #   ① Psych 4/5（ruby ≥ 3.1）的 load_file 是 safe_load，INDEX 未加引号的 last_updated 时间戳
  #      会抛 Psych::DisallowedClass ⇒ 在 Linux 上把「合法注册表」误判为非法；带 permitted_classes
  #      后由 Psych 3 的 ArgumentError 回退旧调用。
  #   ② `-Ku`（源编码 UTF-8）：本片段含中文字面量，C/POSIX locale 下（无 UTF-8 locale 的最小
  #      容器/CI）ruby 以 US-ASCII 读取 `-e` 源码 ⇒ `invalid multibyte char` 编译失败 ⇒ 同一误判。
  #      注意：`-E utf-8` 只改**外部编码**，不改 `-e` 源码编码，修不了此病；`-Ku` 才行（两者实测见台账）。
  ruby -Ku -ryaml -e '
    begin; d = YAML.load_file(ARGV[0], permitted_classes: [Time], aliases: true); rescue ArgumentError; d = YAML.load_file(ARGV[0]); end
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

# ── B16 内容卫生（垃圾与重复治理；阈值源 docs/development.md §7.1） ──────────────
# D118：单文件上限 / 跨文件重复块冗余 / 跨文件重复行冗余 / 孤儿内容 / 溯源档案索引缺口——五项各自独立判据，
#   上限值**只降不升**（削减落地后下调；上调须登记理由）。判据实现在下方内联 python，
#   与工位仪器 `tools/junk-dup-scan.py` 同口径（三行窗口 / 块 ≥200 B、行 ≥40 字符）。
if command -v python3 >/dev/null 2>&1; then
  HYG_OUT=$(python3 - <<'PYEOF'
# -*- coding: utf-8 -*-
"""B16 内容卫生判据（供 plans/preset-score.sh 内联调用；也可独立跑做核验）。

输出：每行 FINDING|扣分|消息；无输出＝全项达标。
口径（与 docs/development.md §7.1 上限表逐项对应；与运行根工位仪器 tools/junk-dup-scan.py 同口径）：
  单文件字节 / 跨文件重复块冗余 / 跨文件重复行冗余 / 孤儿内容 / 溯源档案索引缺口
注意：本体内联进 plans/preset-score.sh 的 heredoc，**不得出现反引号**（macOS bash 3.2 会在命令替换里把反引号
  当作旧式命令替换起点，导致 $() 提前收尾、后续 python 被当 shell 解析）⇒ 代码围栏与索引表用 chr 拼接。
退出码：0（判据已跑完，扣分以 FINDING 行表达）/ 2（无法核验）
"""
import hashlib
import io
import os
import re
import subprocess
import sys

DOC = "docs/development.md"
IDX = "skills/dsh-codepunk-workflow/references/learned-skills.md"
BENCH = "skills/dsh-codepunk-workflow/benchmarks"
LABELS = ("单文件字节", "跨文件重复块冗余", "跨文件重复行冗余", "孤儿内容", "溯源档案索引缺口")
MIN_LINES, MIN_BLOCK_BYTES, MIN_LINE_CHARS = 3, 200, 40
WHITELIST = re.compile(
    r"^(LICENSE|README\.md|CHANGELOG\.md|CONTRIBUTING\.md|SECURITY\.md|SUPPORT\.md|"
    r"CODE_OF_CONDUCT\.md|GOVERNANCE\.md|Makefile|agent\.cordis\.yml|preset\.yml|AGENT-PLANE\.yml)$"
    r"|^\."
    r"|^docs/index\.md$"
    r"|^\.github/"
    r"|^plans/hooks/"
)
TEXT_EXT = (".md", ".sh", ".py", ".mjs", ".yml", ".yaml", ".json", ".ps1", ".txt", ".ini", ".cfg", ".toml")


def finding(points, msg):
    sys.stdout.write("FINDING|%d|%s\n" % (points, msg))


def norm(s):
    return re.sub(r"\s+", " ", s.strip())


def tracked():
    p = subprocess.run(["git", "ls-files", "-z"], capture_output=True)
    if p.returncode != 0:
        return None
    out = p.stdout.decode("utf-8", "replace")
    return [f for f in out.split("\0") if f]


def read_text(path):
    try:
        if os.path.getsize(path) > 4 * 1024 * 1024:
            return None
        raw = io.open(path, "rb").read()
        if b"\0" in raw[:4096]:
            return None
        return raw.decode("utf-8", "replace")
    except OSError:
        return None


def limits():
    got = {}
    try:
        rows = io.open(DOC, encoding="utf-8").read().split("\n")
    except OSError:
        return None
    for lab in LABELS:
        for r in rows:
            if not r.startswith("|"):
                continue
            cells = [c.strip() for c in r.strip("|").split("|")]
            if len(cells) >= 2 and cells[0] == lab and re.fullmatch(r"[0-9]+", cells[1]):
                got[lab] = int(cells[1])
                break
    return got if len(got) == len(LABELS) else None


def dup_blocks(contents):
    windows = {}
    for f, text in contents.items():
        if not f.endswith(TEXT_EXT) and os.path.basename(f) != "Makefile":
            continue
        lines = [norm(x) for x in text.split("\n")]
        for i in range(0, max(0, len(lines) - MIN_LINES + 1)):
            win = lines[i:i + MIN_LINES]
            if sum(len(w) for w in win) < MIN_BLOCK_BYTES:
                continue
            if all(not w for w in win):
                continue
            key = hashlib.sha1(("\n".join(win)).encode("utf-8")).hexdigest()
            windows.setdefault(key, []).append((f, i, sum(len(w) + 1 for w in win)))
    seen, total, count = [], 0, 0
    for key, occ in windows.items():
        if len(occ) < 2 or len(set(o[0] for o in occ)) < 2:
            continue
        first = occ[0]
        span = (first[0], first[1], first[1] + MIN_LINES)
        if any(span[0] == s[0] and s[1] <= span[1] <= s[2] for s in seen):
            continue
        seen.append(span)
        count += 1
        total += first[2] * (len(occ) - 1)
    return count, total


def repeat_lines(contents):
    occ = {}
    for f, text in contents.items():
        for i, raw in enumerate(text.split("\n")):
            n = norm(raw)
            if len(n) < MIN_LINE_CHARS:
                continue
            if n.startswith((chr(96) * 3, "|---")) or set(n) <= set("-|: "):
                continue
            occ.setdefault(n, []).append((f, i + 1))
    rows = [l for l, v in occ.items() if len(set(f for f, _ in v)) > 1]
    return len(rows), sum(len(l) * (len(occ[l]) - 1) for l in rows)


def main():
    lim = limits()
    if lim is None:
        finding(15, "内容卫生上限无法核验：%s 的 §7.1 上限表缺行或格式不符（无法核验 ≠ 通过）" % DOC)
        return 2
    files = tracked()
    if not files:
        finding(30, "内容卫生无法核验：git 枚举失败或为空（无法核验 ≠ 通过）")
        return 2
    contents = {}
    for f in files:
        if os.path.isfile(f):
            t = read_text(f)
            if t is not None:
                contents[f] = t

    # ① 单文件字节
    biggest, big = 0, ""
    for f in files:
        try:
            s = os.path.getsize(f)
        except OSError:
            continue
        if s > biggest:
            biggest, big = s, f
    if biggest > lim["单文件字节"]:
        finding(15, "单文件超限：%s %d 字节 > 上限 %d（拆分或削减）" % (big, biggest, lim["单文件字节"]))

    # ② / ③ 重复块、重复行
    _, blk = dup_blocks(contents)
    if blk > lim["跨文件重复块冗余"]:
        finding(10, "跨文件重复块冗余 %d 字节 > 上限 %d（抽公用片段）" % (blk, lim["跨文件重复块冗余"]))
    _, line = repeat_lines(contents)
    if line > lim["跨文件重复行冗余"]:
        finding(10, "跨文件重复行冗余 %d 字节 > 上限 %d（消除样板重复）" % (line, lim["跨文件重复行冗余"]))

    # ④ 溯源档案索引缺口
    try:
        idx = io.open(IDX, encoding="utf-8").read()
    except OSError:
        idx, listed, claim = None, [], None
        finding(10, "溯源档案索引无法核验：缺 %s（无法核验 ≠ 通过）" % IDX)
    if idx is not None:
        _bq = chr(96)
        listed = sorted(set(re.findall("^\\|\\s*" + _bq + "benchmarks/([^" + _bq + "]+[.]md)" + _bq + "\\s*\\|",
                                      idx, re.M)))
        try:
            real = sorted(f for f in os.listdir(BENCH) if f.endswith(".md"))
        except OSError:
            real = []
            finding(10, "溯源档案索引无法核验：缺目录 %s（无法核验 ≠ 通过）" % BENCH)
        claim = re.search(r"（\**([0-9]+) 篇", idx)
        if len(listed) != len(real) or (claim and int(claim.group(1)) != len(real)):
            finding(10, "溯源档案索引缺口：表内 %d 条 / 目录 %d 个 / 声称 %s 篇（须列全且计数相符）"
                    % (len(listed), len(real), claim.group(1) if claim else "无"))

    # ⑤ 孤儿内容
    if lim["孤儿内容"] == 0:
        orph = []
        for f in files:
            if WHITELIST.search(f):
                continue
            base = os.path.basename(f)
            hit = any(base in t for g, t in contents.items() if g != f)
            if not hit:
                orph.append(f)
        if orph:
            finding(10, "孤儿内容（零引用）%d 个: %s" % (len(orph), ", ".join(sorted(orph)[:5])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
PYEOF
) || HYG_OUT="FINDING|30|内容卫生判据执行失败 ⇒ 无法核验 ≠ 通过（重跑并检查 python3）"
  while IFS='|' read -r _tag _pts _msg; do
    [ "$_tag" = "FINDING" ] && ded B16 "$_pts" "$_msg"
  done <<HYGEOF
$HYG_OUT
HYGEOF
else
  ded B16 20 "内容卫生无法核验（缺 python3）——无法核验 ≠ 通过"
fi

# ── 汇总 ────────────────────────────────────────────────────────────────────
echo
NOTFULL=0
NITEMS=0
for v in A1 A2 A3 A4 A5 B6 B7 B8 B9 B10 B11 B12 B13 B14 B15 B16; do
  eval "s=\$$v"
  NITEMS=$((NITEMS+1))
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
  echo "${NITEMS}/${NITEMS} 全满分 —— 本轮计为一次满分"
  exit 0
fi
echo "未满分 $NOTFULL 项 —— 需继续优化"
exit 1

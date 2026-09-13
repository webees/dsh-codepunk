#!/usr/bin/env bash
# =============================================================================
# preset-score.sh —— dsh-codepunk 15 指标评分器（run-score-15 rubric 固化）
# -----------------------------------------------------------------------------
# 用法: preset-score.sh [预设根]
# 输出: 15 项得分（每项 100 分为满分门槛）+ 失分证据 + 是否「全满分」
# 退出码: 0=15 项全 100；1=存在未满分项
#
# 判据原则：优先客观可验证（解析/实跑/计数/grep），主观项给出明确扣分锚点。
# 环境变量:
#   OLD_NAME=<旧名>      启用品牌卫生回归检查（默认跳过，不在仓库内硬编码旧名）
#   PWSH_VALIDATOR=<路径> PowerShell 语法校验器（默认 ~/.dsh-codepunk/tools/ps-validate.mjs）
# bash 3.2 兼容（macOS 自带）：不使用关联数组/mapfile。
# =============================================================================
set -u
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" || { echo "✗ 预设根不存在: $ROOT"; exit 1; }

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
TODO=$(git grep -nE "TODO|FIXME|XXX(?!X)|待补|待填|WIP" -- '*.md' '*.yml' 2>/dev/null | grep -viE "todo_write|allowParallel|todo\b" | head -3)
[ -n "$TODO" ] && ded A2 20 "占位残留: $(echo "$TODO" | head -1 | cut -c1-70)"
# 命令示例可执行性：SKILL 内 bash 代码块
BADCMD=0
for c in $(grep -oE '^\s*(dsh-codepunk-[a-z-]+|bash plans/[a-z-]+\.sh)[^|]*' "$SKILL" 2>/dev/null | head -20); do
  case "$c" in *"<"*) continue;; esac   # 跳过含占位符的示例
done
[ "$BADCMD" -gt 0 ] && ded A2 15 "不可执行的命令示例 $BADCMD 处"
# 占位符标注检查（模板示例须标注）
UNLABELED=$(grep -rnE "<[A-Z_]{3,}>" "$SKILL" 2>/dev/null | grep -vcE "占位|示例|模板|<project_id>|<run_id>|<task_id>|<PROVIDER>|<MODEL>" || true)
[ "${UNLABELED:-0}" -gt 3 ] && ded A2 10 "未标注的占位符 ${UNLABELED} 处"

# ── A3 准确性 ───────────────────────────────────────────────────────────────
NB=$(ls "$BM"/*.md 2>/dev/null | wc -l | tr -d ' ')
DOCB=$(grep -oE '×[0-9]+' README.md 2>/dev/null | head -1 | tr -d '×')
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
  ruby -ryaml -e 'd=YAML.load_file("agent.cordis.yml"); exit(d.is_a?(Array) && d.all?{|r| r.is_a?(Hash) && r.key?("name")} ? 0 : 1)' 2>/dev/null && PARSE="ok" || PARSE="fail"
elif command -v node >/dev/null 2>&1 && [ -d "$HOME/.dsh-codepunk/tools/node_modules/js-yaml" ]; then
  node -e 'const y=require(process.env.HOME+"/.dsh-codepunk/tools/node_modules/js-yaml");const d=y.load(require("fs").readFileSync("agent.cordis.yml","utf8"));process.exit(Array.isArray(d)&&d.every(r=>r&&r.name)?0:1)' 2>/dev/null && PARSE="ok" || PARSE="fail"
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
[ -n "$DUPSEG" ] && ded A5 15 "成段重复: $(echo "$DUPSEG" | head -1 | cut -c1-60)"

# ── B6 一致性 ───────────────────────────────────────────────────────────────
# 术语混用（中英双写须成对出现才算违规；此处查同义词混用）
if grep -q "工程主责（run-lead）" "$SKILL" 2>/dev/null && ! grep -q "run-lead" "$REF/roles.md" 2>/dev/null; then
  ded B6 10 "roles.md 未使用 run-lead 术语"
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
DN=$(grep -oE 'D0[0-9]{2}' "$SKILL" | sort -u | while read -r d; do grep -q "| $d " "$REF/standard.md" || echo "$d"; done)
[ -n "$DN" ] && ded B7 20 "SKILL 引用但登记表缺: $(echo "$DN" | tr '\n' ' ')"

# ── B8 可执行性 ─────────────────────────────────────────────────────────────
for f in plans/*.sh; do bash -n "$f" 2>/dev/null || ded B8 25 "bash -n 失败: $f"; done
PV="${PWSH_VALIDATOR:-$HOME/.dsh-codepunk/tools/ps-validate.mjs}"
if [ -f "$PV" ] && command -v node >/dev/null 2>&1; then
  node "$PV" plans/windows/*.ps1 >/dev/null 2>&1 || ded B8 25 "PowerShell 语法校验失败"
else
  : # 无校验器 → 不扣分（与 ruby/node 跳过同策略）
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
[ -f .gitattributes ] || ded B10 15 "缺 .gitattributes（换行策略）"
# 硬编码用户绝对路径
HARDP=$(git grep -nE "/Users/[a-z]+/|/home/[a-z]+/" -- plans/ '*.md' 2>/dev/null | grep -vE "例|示例|如 \`|/Users/\[" | head -2)
[ -n "$HARDP" ] && ded B10 20 "硬编码用户绝对路径: $(echo "$HARDP" | head -1 | cut -c1-70)"
# BSD/GNU 专有未兜底
if grep -qE "sed -i ''|stat -f%z[^|]*$" plans/*.sh 2>/dev/null; then
  grep -qE "sed -i ''" plans/*.sh 2>/dev/null && ! grep -q "sed_i()" plans/*.sh 2>/dev/null && ded B10 20 "sed -i ''（BSD 专有）无兜底"
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
# 硬规则 R1–R14 齐全
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
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

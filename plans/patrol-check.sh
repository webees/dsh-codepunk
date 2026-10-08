#!/usr/bin/env bash
# ============================================================================
# patrol-check.sh —— 巡检名册字段契约门（运行根 agents.yaml 的 `patrol_log`）
# ----------------------------------------------------------------------------
# 用法:
#   patrol-check.sh --run-root <运行根目录> [--ledger <台账路径>] [--max-gap N] [-h|--help]
#     --run-root <目录>  含 `agents.yaml` 的运行根（**必需**；缺 ⇒ 退出码 2）
#     --ledger <路径>    巡检台账（`ledger.md`）；给了则每个巡检轮次 MUST 在台账中有行
#     --max-gap N        轮次升序后相邻间隔上限（默认 5）
#     -h, --help         显示本用法
#
# 退出码: 0=全部合规；1=发现契约违规（列出条目与原因）；2=用法或环境错误（缺 --run-root、运行根或
#   agents.yaml 不存在、缺必需工具）
#
# 依赖: bash + awk / grep / sort / uniq（**不依赖 YAML 库**——仓内无 pyyaml，一律行级解析）
#
# 说明（判据 a–f；源＝references/artifacts.md 的 D095/D099 写入约束「每个 round 条目须齐备
#   round/at/note」）:
#   a 在 agents.yaml 定位 `patrol_log:` 段（到下一个顶格键为止），逐条解析 `- round: <整数>` 条目块；
#   b 每条 MUST 有非空 `at:` 与非空 `note:`（缺失或值为空 ⇒ 违规，报「缺 at」/「缺 note」）；
#   c `round` MUST 唯一（重复 ⇒ 违规并列出重复值）；
#   d `round` MUST 为整数（非整数 ⇒ 违规）；
#   e 给了 --ledger：每个巡检轮次 MUST 有 `| R<轮次> |` 行（缺 ⇒ 违规）；
#   f 升序排序后相邻轮次间隔 MUST ≤ --max-gap（默认 5）；超限报出间隔端点；不要求文件内顺序。
#   值 MUST 为单行标量；段缺失或段内零条目同样判违规（1）。重复键（D099 的严格解析器域）不在
#   本门判据内——见解析处的 dsh-debt 标注。
#   环境缺口一律 `exit 2` 并打印「无法核验 ≠ 通过」，不得静默判通过。
# ============================================================================
set -uo pipefail

# 判据与输出含多字节（中文结论）。非 UTF-8 locale 下会被逐字节处理并误报，故在系统存在 UTF-8
# locale 时固定之（与 plans/write-scope-check.sh 同口径；探测只用 ASCII）。
case "$(locale charmap 2>/dev/null)" in
  UTF-8|utf8|UTF8) ;;
  *)
    for _l in en_US.UTF-8 C.UTF-8 C.utf8 UTF-8; do
      if locale -a 2>/dev/null | grep -qx "$_l"; then export LC_ALL="$_l"; break; fi
    done ;;
esac

RUN_ROOT=""
LEDGER=""
MAXGAP=5

while [ $# -gt 0 ]; do
  case "$1" in
    --run-root)
      [ $# -ge 2 ] || { echo "✗ --run-root 缺参数（无法核验 ≠ 通过）" >&2; exit 2; }
      RUN_ROOT="$2"; shift 2 ;;
    --ledger)
      [ $# -ge 2 ] || { echo "✗ --ledger 缺参数（无法核验 ≠ 通过）" >&2; exit 2; }
      LEDGER="$2"; shift 2 ;;
    --max-gap)
      [ $# -ge 2 ] || { echo "✗ --max-gap 缺参数（无法核验 ≠ 通过）" >&2; exit 2; }
      MAXGAP="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)
      echo "✗ 未知参数: $1（用法: patrol-check.sh --run-root <运行根> [--ledger <台账>] [--max-gap N]）" >&2
      exit 2 ;;
  esac
done

# 工具预检：缺任一解析/统计工具 ⇒ 无法核验（不静默通过）
for _t in awk grep sort uniq; do
  command -v "$_t" >/dev/null 2>&1 || { echo "✗ 缺必需工具 ${_t}（无法核验 ≠ 通过）" >&2; exit 2; }
done

[ -n "$RUN_ROOT" ] || { echo "✗ 缺 --run-root（用法: patrol-check.sh --run-root <运行根>）" >&2; exit 2; }
[ -d "$RUN_ROOT" ] || { echo "✗ 运行根不存在: ${RUN_ROOT}（无法核验 ≠ 通过）" >&2; exit 2; }
AGENTS="$RUN_ROOT/agents.yaml"
[ -f "$AGENTS" ] || { echo "✗ 运行根缺 agents.yaml: ${AGENTS}（无法核验 ≠ 通过）" >&2; exit 2; }
if [ -n "$LEDGER" ] && [ ! -f "$LEDGER" ]; then
  echo "✗ 台账不存在: ${LEDGER}（无法核验 ≠ 通过）" >&2; exit 2
fi
case "$MAXGAP" in
  ''|*[!0-9]*) echo "✗ --max-gap 须为非负整数: ${MAXGAP}（无法核验 ≠ 通过）" >&2; exit 2 ;;
esac

BAD=""
bad() { BAD="${BAD}✗ $1
"; }

# ── 段定位：`patrol_log:` 到下一个顶格键（非空白、非注释）为止 ──────────────────
SEC=""
HAS_SEC=0
if grep -qE '^patrol_log:' "$AGENTS"; then
  HAS_SEC=1
  SEC=$(awk '
    /^patrol_log:/ { insec = 1; next }
    insec && /^[^[:space:]#]/ { exit }
    insec { print }
  ' "$AGENTS")
else
  bad "缺 patrol_log 段（agents.yaml 无顶格 patrol_log: 键）"
fi

# ── 行级解析：每个条目输出三行 `R<TAB>round` / `A<TAB>at` / `N<TAB>note` ────────
# dsh-debt: 行级解析不检测**重复键**（同一条目下两个 at/note）——那是 D099 严格解析器
#   （js-yaml 拒重复键）的域，仓内无 YAML 库。ceiling: 条目内重复键。upgrade: 引入
#   js-yaml/node 后改严格解析并在本门加「重复键 ⇒ 违规」。
TAB=$'\t'
# 引号字符经 -v 传入（BSD awk 不支持 `\x` 转义；单引号字面量亦无法内嵌于 shell 单引号串）
SQ=$'\''
DQ='"'
PARSE=""
if [ -n "$SEC" ]; then
  PARSE=$(printf '%s\n' "$SEC" | awk -v sq="$SQ" -v dq="$DQ" '
    function unq(s) {
      sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s)
      if ((substr(s, 1, 1) == sq && substr(s, length(s), 1) == sq && length(s) >= 2) ||
          (substr(s, 1, 1) == dq && substr(s, length(s), 1) == dq && length(s) >= 2))
        s = substr(s, 2, length(s) - 2)
      sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s)
      return s
    }
    function flush() { if (started) printf "R\t%s\nA\t%s\nN\t%s\n", r, a, n }
    /^[[:space:]]*-[[:space:]]*round:/ {
      flush()
      started = 1
      r = unq(substr($0, index($0, ":") + 1))
      a = ""; n = ""
      next
    }
    started {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line ~ /^at:/)        a = unq(substr(line, 4))
      else if (line ~ /^note:/) n = unq(substr(line, 6))
    }
    END { flush() }
  ' 2>/dev/null)
fi

# ── 逐条核验（b/c/d + e）─────────────────────────────────────────────────────
ROUNDS=""
N_ENT=0
r=""; at=""; note=""; started=0

check_entry() {
  N_ENT=$((N_ENT + 1))
  local raw="$1" v_at="$2" v_note="$3"
  case "$raw" in
    ''|*[!0-9]*)
      bad "round=${raw} 非整数（round MUST 为整数）" ;;
    *)
      ROUNDS="${ROUNDS}${raw}
"
      # 单行「测空即报」形态：便于存活变异以 `true` 短路该判据（见 checker-self-test 的 M176-c）
      [ -n "$v_at" ] || bad "round=${raw} 缺 at"
      [ -n "$v_note" ] || bad "round=${raw} 缺 note"
      if [ -n "$LEDGER" ]; then
        grep -qE "^[|] *R${raw}([^0-9]|$)" "$LEDGER" || bad "round=${raw} 台账无行（| R${raw} |）"
      fi ;;
  esac
}

while IFS= read -r line; do
  case "$line" in
    R"$TAB"*) [ "$started" = 1 ] && check_entry "$r" "$at" "$note"
              r=${line#*"$TAB"}; at=""; note=""; started=1 ;;
    A"$TAB"*) at=${line#*"$TAB"} ;;
    N"$TAB"*) note=${line#*"$TAB"} ;;
  esac
done <<< "$PARSE"
[ "$started" = 1 ] && check_entry "$r" "$at" "$note"

if [ "$HAS_SEC" = 1 ] && [ "$N_ENT" = 0 ]; then
  bad "patrol_log 段内无 round 条目（名册为空）"
fi

# ── c 唯一性 ────────────────────────────────────────────────────────────────
DUPS=$(printf '%s\n' "$ROUNDS" | grep -v '^$' | sort -n | uniq -d | tr '\n' ' ')
if [ -n "$DUPS" ]; then bad "round 重复: ${DUPS}"; fi

# ── f 间隔（升序、去重后相邻差）───────────────────────────────────────────────
prev=""
while IFS= read -r cur; do
  [ -n "$cur" ] || continue
  if [ -n "$prev" ]; then
    gap=$((cur - prev))
    if [ "$gap" -gt "$MAXGAP" ]; then
      bad "间隔超限：${prev} → ${cur}（间隔 ${gap} > ${MAXGAP}）"
    fi
  fi
  prev="$cur"
done <<< "$(printf '%s\n' "$ROUNDS" | grep -v '^$' | sort -n -u)"

# ── 结论 ────────────────────────────────────────────────────────────────────
if [ -z "$BAD" ]; then
  LEDGER_NOTE=""
  [ -n "$LEDGER" ] && LEDGER_NOTE=" / 台账齐备"
  echo "✅ 巡检名册合规：条目 ${N_ENT}（字段齐备 / 唯一 / 间隔 ≤ ${MAXGAP}${LEDGER_NOTE}）"
  exit 0
fi
printf '%s' "$BAD"
NBAD=$(printf '%s' "$BAD" | grep -c '^✗')
echo "✗ 巡检名册不合规：${NBAD} 处违规（条目 ${N_ENT}）"
exit 1

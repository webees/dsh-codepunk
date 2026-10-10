#!/usr/bin/env bash
# ======
# acceptance-verify.sh —— 签收文件校验器（D069 实现 · 防假通过的机械门 S2）
# ------
# 用法：
#   bash acceptance-verify.sh <acceptance.yaml> <交付方 task_id>
# 退出码：0=结构合法且签收独立 · 1=不合规（列出问题） · 2=用法/文件缺失或未提供交付方
#
# 依据：
#   artifacts.md D069「schema 强约束」：acceptance.yaml 结构与 evidence.yaml 同理，
#     MUST 生成期可机器校验（必填字段齐、类型对、accepted_by 为数组）；
#   artifacts.md「无此文件不得 dissolved」；
#   stages.md ④：有下游 → 下游小队主责签；无下游 → docs-lead 签收；
#     **签收方 MUST 独立于交付方**。F268：本文件旧头注曾写「仅 docs-lead 不可用时才由 run-lead 自签，
#     且 MUST 在 note 记原因」，与实现（:116「自签」判据**一律 FAIL、不看 note**）不一致 ⇒ 现按实现与
#     流程权威（artifacts.md:154／stages.md:52「无下游 → docs-lead」）改写：自签**无例外**。
#
# 断言：
#   ① task_id 必填
#   ② accepted_by 必填且为**数组**（至少 1 项；不能写成标量）
#   ③ accepted_at 必填且可解析为 ISO 8601
#   ④ 签收独立性：签收方不得等于**或包含**交付方 task_id —— **自签一律判不合规，与 note 无关**
#      （F268：实现见 :116/:121，无例外分支）；**比较不区分大小写并去首尾空白**（F331：原实现为
#      区分大小写的子串包含 ⇒ 交付方 `task-a` 的签收方写 `Task-A` 即判通过，自签可被改大小写绕过）；
#      签收方出现 run-lead/技术统筹（run-lead 兼任）字样
#      且**非**自签时，note 必须非空（记明由 run-lead 签收的原因，:122/:123）
#   ⑤ note 若出现「不可用/缺席」类表述但为空则告警（不判失败）
# ======
set -uo pipefail

_EG="$(dirname "${BASH_SOURCE[0]:-$0}")/env-guard.sh"; [ -r "$_EG" ] || { echo "✗ 缺 ${_EG}（无法核验）" >&2; exit 2; }; . "$_EG"  # F195/F197+F421 守卫库

# F361（本轮巡检实测）：本脚本原无 `-h`/`--help` 分支 ⇒ `-h` 被当位置参数、只报参数不足，
#   违反全仓「实现者 MUST 返回 0 并打印用法」约定（第 20 类）——现补上。
case "${1:-}" in
  -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

if [ $# -lt 2 ]; then
  echo "用法: acceptance-verify.sh <acceptance.yaml> <交付方 task_id>" >&2
  # F332：交付方原为可选参（`[交付方 task_id]`）⇒ 不传时 ④「签收独立性」整段跳过，工具仍打印
  #   「PASS: 结构合法且签收独立」——**声称已校验独立性而实际未校验**（违反本仓「无法核验 ≠ 通过」）。
  #   现改必填：缺交付方 ⇒ rc=2（与 leak-guard 缺 HOME、preset-declare 缺 DSH_APP_ROOT 同口径）。
  if [ $# -eq 1 ]; then
    echo "✗ 未提供交付方 task_id ⇒ 无法校验签收独立性（无法核验 ≠ 通过）" >&2
  fi
  exit 2                       # 与全仓约定一致：用法/文件缺失 = 2
fi
ACC="$1"
DELIVERER="$2"

[ -f "$ACC" ] || { echo "❌ [fetch] acceptance 文件不存在: $ACC"; exit 2; }

# F254：python3 不可用时下方断言体输出为空 ⇒ `grep -q verdict=PASS` 落空 ⇒ **rc=1 但零诊断**
#   （违背本脚本「列出问题」契约；方向失败安全，但成因不可见）。统一前置为显式失败（2）。
codepunk_need_py

ACC_OUT="$(mktemp "${TMPDIR:-/tmp}/acceptance_verify.XXXXXX")" || { echo "❌ 无法创建临时文件"; exit 2; }
trap 'rm -f "$ACC_OUT"' EXIT
python3 - "$ACC" "$DELIVERER" <<'PYEOF' > "$ACC_OUT" 2>&1
import datetime
import re
import sys

f, deliverer = sys.argv[1], sys.argv[2] or ""
src = open(f, encoding="utf-8").read()
problems = []
warnings = []

# ① task_id
m_task = re.search(r'^task_id:\s*(\S+)', src, re.M)
task_id = m_task.group(1) if m_task else None
if not task_id:
    problems.append("① 缺 task_id")

# ② accepted_by 必须为数组且至少一项
lines = src.splitlines()
signers = []
in_block = False
for ln in lines:
    if re.match(r'^accepted_by:\s*$', ln):
        in_block = True
        continue
    if in_block:
        m = re.match(r'^\s+-\s*["\']?([^"\'#\n]+?)["\']?\s*(?:#.*)?$', ln)
        if m:
            signers.append(m.group(1).strip())
            continue
        if ln.strip() == "":
            continue
        in_block = False
# 注意用 [ \t] 而非 \s：\s 会跨行匹配到下一行的 `-`，把正确的数组写法误判为标量
# ②-b 流式数组（合法 YAML 数组写法）：accepted_by: [a, b] —— F171：原实现把 [..] 误判为标量
flow = re.search(r'^accepted_by:[ \t]*\[(.*)\][ \t]*(?:#.*)?$', src, re.M)
if flow:
    items = [x.strip().strip(chr(34) + chr(39)) for x in flow.group(1).split(',')]
    signers.extend([x for x in items if x])
# 标量判据须排除流式数组写法
scalar_form = re.search(r'^accepted_by:[ \t]*(?!\[)\S', src, re.M)
if scalar_form:
    problems.append("② accepted_by 写成了标量（MUST 为数组，每项一行 `  - \"…\"`）")
elif not signers:
    problems.append("② accepted_by 缺失或为空数组（签收方至少 1 项，且不得自签）")

# ③ accepted_at 可解析
m_at = re.search(r'^accepted_at:\s*"?([^"\n]+)"?', src, re.M)
if not m_at:
    problems.append("③ 缺 accepted_at")
else:
    try:
        datetime.datetime.fromisoformat(m_at.group(1).strip().replace("Z", "+00:00"))
    except Exception as e:
        problems.append(f"③ accepted_at 无法解析为 ISO 8601: {m_at.group(1).strip()}（{e}）")

# ④ 签收独立性
note = ""
m_note = re.search(r'^note:\s*"?([^"\n]*)"?', src, re.M)
if m_note:
    note = m_note.group(1).strip()
for s in signers:
    if deliverer and deliverer.strip().lower() in s.strip().lower():   # F331：不区分大小写（改大小写不得绕过自签判据）
        problems.append(f"④ 自签：签收方 {s} 即交付方 {deliverer}（无独立签收；无下游时改由 docs-lead 签）")
    if "run-lead" in s and not note:
        problems.append(f"④ 签收方 {s}（run-lead）但 note 为空——run-lead 签收 MUST 在 note 记明原因"
                        "（F283：此处原写「仅 docs-lead 不可用时方可自签」，暗示已被 F268 废除的自签例外；"
                        "自签＝签收方为交付方，一律不合规且与 note 无关，判据见上一条）")

# ⑤ 提示级
if not signers and not scalar_form:
    warnings.append("⑤ 未解析到任何签收方，请确认 YAML 缩进")
if re.search(r'^accepted_by:\s*\[\s*\]', src, re.M):
    warnings.append("⑤ accepted_by 为空列表字面量")

print("=" * 52)
print(f"acceptance: {f}")
print(f"task_id:    {task_id or 'MISSING'}")
print(f"signers:    {', '.join(signers) if signers else '(none)'}")
print(f"accepted_at: {m_at.group(1).strip() if m_at else 'MISSING'}")
print("-" * 52)
if problems:
    print("FAIL:")
    for p in problems:
        print("  ❌ " + p)
else:
    print("PASS: 结构合法且签收独立（task_id / accepted_by[] / accepted_at 齐备）")
if warnings:
    print("WARN:")
    for w in warnings:
        print("  ⚠ " + w)
print(f"verdict={'FAIL' if problems else 'PASS'}")
PYEOF
cat "$ACC_OUT"
grep -q "verdict=PASS" "$ACC_OUT" && exit 0 || exit 1

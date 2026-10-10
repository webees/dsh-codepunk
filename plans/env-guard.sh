#!/usr/bin/env bash
# 作用：门禁脚本共用的**环境前置守卫**（纯 source 库，非 CLI 入口——无参数解析、无 `-h` 分支）。
#   ① locale 固定（F195/F196/F197）：C/POSIX 与非 UTF-8 locale 下 BSD 工具链逐字节处理 ⇒ 判据失效或误报；
#      按 `locale charmap` 判定，仅当当前 locale 非 UTF-8 且系统存在 UTF-8 locale 时固定 `LC_ALL`。
#   ② POSIX 模式拒答（F421）：`POSIXLY_CORRECT=1` 或 `bash --posix` 关闭进程替换等扩展 ⇒ 语法错误
#      且**无保守措辞**，会被误归因为「脚本坏了」⇒ 前置拒答，绝不带残缺判据继续。
# 用法（消费方自定位 + 先判可读性；**缺库不得静默跳过**，否则 locale 固定与 POSIX 拒答同时消失）：
#   _EG="$(dirname "${BASH_SOURCE[0]:-$0}")/env-guard.sh"; [ -r "$_EG" ] || { echo "✗ 缺 ${_EG}（无法核验）" >&2; exit 2; }; . "$_EG"  # F195/F197+F421 守卫库
# 库导出（D125–D128 单一声明源）：`EG_ROOT` · `codepunk_have` · `codepunk_need` · `codepunk_py` ·
#   `codepunk_need_py` · `codepunk_need_root` · `codepunk_usage`。
# 落位：源副本 `plans/env-guard.sh`（仓内）；总库正式位 `$DSH_CODEPUNK_HOME/scripts/env-guard.sh`
#   ——与消费方脚本**同目录**，故 `dirname "${BASH_SOURCE[0]:-$0}"` 在两种落位下都解析正确。
# 退出码: 0=环境合格（返回消费方继续）; 2=POSIX 模式 ⇒ 拒绝核验（source 上下文中 `exit` 终止消费方）
case "$(locale charmap 2>/dev/null)" in
  UTF-8|utf8|UTF8) ;;
  *)
    for _l in en_US.UTF-8 C.UTF-8 C.utf8 UTF-8; do
      if locale -a 2>/dev/null | grep -qx "$_l"; then export LC_ALL="$_l"; break; fi
    done ;;
esac

if [ -n "${POSIXLY_CORRECT:-}" ] || set -o 2>/dev/null | grep -qE '^posix[[:space:]]+on'; then
  echo "✗ POSIX 模式（POSIXLY_CORRECT 或 bash --posix）⇒ 无法核验 ≠ 通过（rc=2）" >&2
  exit 2
fi

# ②b 仓库根（内容治理第 9 轮）：库所在目录的上一级即本预设仓库根（仓内落位与总库落位同构）。
#   消费方 `ROOT="${1:-$EG_ROOT}"`——此前 4 个门禁各写一遍同形 183 B 行。
# D128：仓库根的单一声明源（消费方 MUST 用 ${EG_ROOT:-} 而非各自 cd/.. 求根）。
EG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || true)"

# codepunk_need_root <root>：校验根路径确为本预设仓库（缺 SKILL.md 或 plans/ ⇒ rc=2 拒答）。
#   F443 / 内容治理第 4 轮：此前 4 个门禁脚本各自内联同一段校验（5 行 ×4 ⇒ 块冗余 217 B ×3、
#   样板重复行 837 B）；改由库提供，消费方单行调用。错误根必须拒答——不得在错误的树上继续判。
# ③ 依赖可用性探针（D126）：以**声明**为依据的判据 MUST 先探依赖——探法只在此处定义，
#    避免各判据各写一遍 `command -v x >/dev/null 2>&1` 而口径漂移（F405 家族）。
codepunk_have() { command -v "$1" >/dev/null 2>&1; }

# ③b 依赖预检（F405 家族 / 内容治理第 9 轮）：一组必需外部工具齐备才继续，缺任一 ⇒ 拒答 2。
#   此前 3 个门禁各写一遍同形 3 行块（样板重复行 118 B ×3）；调用式 `codepunk_need git awk sed`。
codepunk_need() {
  for _t in "$@"; do
    command -v "$_t" >/dev/null 2>&1 \
      || { echo "✗ 缺少必需工具 ${_t} ⇒ 无法核验 ≠ 通过（rc=2）" >&2; exit 2; }
  done
}

# ④ python3 能力探针（D126）：presence 与 executability 两段探法只在此处定义；
#    消费方单行 `codepunk_need_py`（F254：缺 python3 时断言体输出为空 ⇒ 零诊断的 rc=1，
#    与本仓教义「无法核验 ≠ 通过」不符 ⇒ 统一前置为显式失败 2 并说明成因）。
codepunk_py() { command -v python3 >/dev/null 2>&1 && python3 -c 'pass' 2>/dev/null; }

codepunk_need_py() {
  codepunk_py || { echo "✗ python3 不可用（缺失或执行失败）——无法核验 ≠ 通过" >&2; exit 2; }
}

codepunk_need_root() {
  if [ -f "$1/skills/dsh-codepunk-workflow/SKILL.md" ] && [ -d "$1/plans" ]; then
    return 0
  fi
  printf '✗ 根路径不是本预设仓库（缺 skills/dsh-codepunk-workflow/SKILL.md 或 plans/）: %s\n' "$1" >&2
  return 2
}

# ⑤ 用法块打印（D127）：`codepunk_usage <行区间>` 打印 `$0` 的第 2..N 行并去掉行首 `# `，随后以 0 退出。
#   行区间 MUST **显式传入**——各脚本头部长度不同（实物 28/27/30/18 并存），库内固定值会静默截断用法块。
#   参数非整数或越界 ⇒ 保守拒答 2（MUST NOT 静默打印空用法而报 rc=0）；F465 / 内容治理第 8 轮：
#   域内 5 个消费方此前各写一遍**逐字相同**的用法行（256 B ×5，是剩余跨文件重复行的最大单一行源）。
codepunk_usage() {
  case "${1:-}" in ''|*[!0-9]*) echo "✗ codepunk_usage 需 1 个行区间整数（形如 28）⇒ 无法核验 ≠ 通过" >&2; exit 2 ;; esac
  [ "$1" -ge 2 ] && [ "$1" -le 999 ] || { echo "✗ codepunk_usage 行区间越界: $1 ⇒ 无法核验 ≠ 通过" >&2; exit 2; }
  # F466（本轮自引入）：打印 MUST **先取文本再判空**——写成 `sed … | sed … || { 拒答 }` 时管道退出码
  #   只反映末段（首段 sed 打不开 `$0` 也照样 rc=0），失败分支**永不可达**，且行区间越界会静默打印空用法。
  _u="$(sed -n "2,${1}p" "$0" 2>/dev/null)" || { echo "✗ 用法块打印失败 ⇒ 无法核验 ≠ 通过" >&2; exit 2; }
  [ -n "$_u" ] || { echo "✗ 用法块为空（行区间 ${1} 超出 $0 长度）⇒ 无法核验 ≠ 通过" >&2; exit 2; }
  printf '%s\n' "$_u" | sed 's/^# \{0,1\}//'
  exit 0
}

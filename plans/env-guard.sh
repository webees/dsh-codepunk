#!/usr/bin/env bash
# 作用：门禁脚本共用的**环境前置守卫**（纯 source 库，非 CLI 入口——无参数解析、无 `-h` 分支）。
#   ① locale 固定（F195/F196/F197）：C/POSIX 与非 UTF-8 locale 下 BSD 工具链逐字节处理 ⇒ 判据失效或误报；
#      按 `locale charmap` 判定，仅当当前 locale 非 UTF-8 且系统存在 UTF-8 locale 时固定 `LC_ALL`。
#   ② POSIX 模式拒答（F421）：`POSIXLY_CORRECT=1` 或 `bash --posix` 关闭进程替换等扩展 ⇒ 语法错误
#      且**无保守措辞**，会被误归因为「脚本坏了」⇒ 前置拒答，绝不带残缺判据继续。
# 用法（消费方自定位 + 先判可读性；**缺库不得静默跳过**，否则 locale 固定与 POSIX 拒答同时消失）：
#   _EG="$(dirname "${BASH_SOURCE[0]:-$0}")/env-guard.sh"; [ -r "$_EG" ] || { echo "✗ 缺 ${_EG}（无法核验）" >&2; exit 2; }; . "$_EG"  # F195/F197+F421 守卫库
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

# codepunk_need_root <root>：校验根路径确为本预设仓库（缺 SKILL.md 或 plans/ ⇒ rc=2 拒答）。
#   F443 / 内容治理第 4 轮：此前 4 个门禁脚本各自内联同一段校验（5 行 ×4 ⇒ 块冗余 217 B ×3、
#   样板重复行 837 B）；改由库提供，消费方单行调用。错误根必须拒答——不得在错误的树上继续判。
codepunk_need_root() {
  if [ -f "$1/skills/dsh-codepunk-workflow/SKILL.md" ] && [ -d "$1/plans" ]; then
    return 0
  fi
  printf '✗ 根路径不是本预设仓库（缺 skills/dsh-codepunk-workflow/SKILL.md 或 plans/）: %s\n' "$1" >&2
  return 2
}

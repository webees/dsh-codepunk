#!/usr/bin/env bash
# =============================================================================
# checker-self-test.sh —— 检查器**存活自检**（变异测试）
# -----------------------------------------------------------------------------
# 动机（实证）：F097/F099/F101/F102 一整类缺陷是「检查项因工具不可用/正则不兼容/空值判定
# 而恒判 PASS」——静态审计自身无法发现这种「守护空转」。本脚本用**注入已知缺陷**的方式验证
# 检查项真的会失败：在临时副本内逐个变异，断言**对应检查项**（按名称核对，非仅看退出码）
# MUST 判失败——只看退出码会因「其它项恰好也在失败」而误判为「已捕获」（本轮实测踩到）。
#
# 用法: checker-self-test.sh [预设根]
# 退出码: 0=全部变异均被对应检查项捕获；1=存在未被捕获的变异（守护失效/空转）；2=环境错误
# =============================================================================
set -u
SRC="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -d "$SRC/plans" ] || { echo "✗ 预设根无效: $SRC" >&2; exit 2; }
FAILED=0
# 递归防护：若自身已在自检上下文内（例如 M5 经电池再次触发本脚本），立即退出
if [ "${DSH_CODEPUNK_SKIP_SELFTEST:-0}" = 1 ]; then
  echo "ℹ 已在自检上下文内，跳过（递归防护）"
  exit 0
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/cst.XXXXXX")" || { echo "✗ 无法建临时目录" >&2; exit 2; }
trap 'rm -rf "$work"' EXIT

fresh() { rm -rf "$work/cur"; cp -R "$SRC" "$work/cur"; }

# check <标签> <命令> <必须出现的检查项名|BASELINE>
check() {
  local label="$1" cmd="$2" marker="$3" rc=0 out
  out="$( cd "$work/cur" && eval "$cmd" 2>&1 )" || rc=1
  if [ "$marker" = "BASELINE" ]; then
    if [ "$rc" = 0 ] && ! printf '%s' "$out" | grep -q '✗'; then
      printf '  ✅ %s（基线全绿）\n' "$label"
    else
      printf '  ✗ %s（基线即失败）: %s\n' "$label" "$(printf '%s' "$out" | grep '✗' | head -1 | cut -c1-72)"
      FAILED=1
    fi
    return
  fi
  if printf '%s' "$out" | grep '✗' | grep -q -- "$marker"; then
    printf '  ✅ %s（已捕获）\n' "$label"
  else
    printf '  ✗ %s（**未被 %s 捕获**）实际失败项: %s\n' "$label" "$marker" \
      "$(printf '%s' "$out" | grep '✗' | head -1 | cut -c1-68)"
    FAILED=1
  fi
}

# mutate <描述> <文件> <grep 模式>：确认变异**真的落盘**——否则自检会误报「守护未捕获」
mutate() {
  local desc="$1" f="$2" pat="$3"
  if ! grep -qE "$pat" "$f" 2>/dev/null; then
    printf '  ‼ 变异未生效（%s）——自检自身问题，非守护问题\n' "$desc" >&2
    MUTFAIL=1
  fi
}
MUTFAIL=0

FW=$(printf '\357\274\210')   # 全角左括号：载荷用拼接构造，避免本脚本自身被 B1b 误判

echo "== 检查器存活自检（变异测试） =="
echo "预设根: $SRC"

fresh; echo "[基线]"
check "未变异·审计" "bash plans/preset-audit.sh" BASELINE

fresh; printf '\nfail "x $HOME%s注入"\n' "$FW" >> "$work/cur/plans/dsh-codepunk-home.sh"
echo "[M1 注入全角紧邻陷阱 → B1b]"
check "审计/B1b" "bash plans/preset-audit.sh" "B1b"

# 变异须保持 YAML 合法（首版变异弄坏 YAML，触发的是 A1 而非 A7——自检因此暴露真相）
fresh
sed -i '' '1,/backgroundMode: continuable/{s/backgroundMode: continuable/backgroundMode: one-shot/;}' "$work/cur/agent.cordis.yml" 2>/dev/null \
  || sed -i '1,/backgroundMode: continuable/{s/backgroundMode: continuable/backgroundMode: one-shot/;}' "$work/cur/agent.cordis.yml"
mutate "岗位改为 one-shot" "$work/cur/agent.cordis.yml" 'backgroundMode: one-shot'
echo "[M2 削弱一个岗位的可恢复性 → A7]"
check "审计/A7" "bash plans/preset-audit.sh" "A7"

fresh; printf '\n见 [工具](plans/no-such-tool-xyz.sh)。\n' >> "$work/cur/README.md"
echo "[M3 注入仓内死链 → E3]"
check "审计/E3" "bash plans/preset-audit.sh" "E3"

fresh; mv "$work/cur/skills/dsh-codepunk-workflow/benchmarks" "$work/cur/skills/dsh-codepunk-workflow/bm_x"
echo "[M4 基准目录改名 → D1]"
check "审计/D1" "bash plans/preset-audit.sh" "D1"

fresh; printf 'x = 1   \n' >> "$work/cur/CONTRIBUTING.md"
echo "[M5 注入行尾空白 → 电池格式项]"
check "电池/格式" "DSH_CODEPUNK_SKIP_SELFTEST=1 bash plans/verify-battery.sh" "格式"   # 跳过自检项，避免递归

fresh; printf '\n# 注入\n' >> "$work/cur/plans/preset-score.sh"
echo "[M6 源与总库副本不同步 → F2]"
check "审计/F2" "bash plans/preset-audit.sh" "F2"

echo
if [ "$MUTFAIL" != 0 ]; then echo "✗ 自检失败：有变异未生效（自检脚本问题）" >&2; exit 2; fi
if [ "$FAILED" = 0 ]; then echo "✔ 自检通过：全部变异均被对应检查项捕获"; exit 0; fi
echo "✗ 自检失败：存在「注入缺陷却未被对应检查项捕获」的守护——疑似空转，请排查" >&2
exit 1

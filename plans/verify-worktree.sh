#!/usr/bin/env bash
# ============================================================================
# verify-worktree.sh —— worktree 治理核验脚本
# ----------------------------------------------------------------------------
# 用法:
#   verify-worktree.sh [主仓库路径] [--quiet]
#   默认主仓库: ${MAIN_REPO:-/Users/x/Desktop/newtest}（可用环境变量覆盖）
#   主仓库归位工程根尚未执行时，脚本接受主仓库留在现位的 WARN（不判 FAIL，
#   归位由 run-lead 另行排期；结尾给出建议命令供执行时对照）。
#
# 检查（acceptance 3）:
#   1) Desktop 根不再出现任何散落 worktree（git 仓库目录，主仓库自身除外）
#   2) 主仓库 `git worktree list` 干净：除主仓库外无任何其他 worktree
#   附加: 主仓库若仍在 Desktop 根 → WARN（归位待 run-lead 排期）
#
# 退出码: 0=全部通过; 1=存在 FAIL; 2=用法/环境错误
# ============================================================================
set -uo pipefail

MAIN="${1:-${MAIN_REPO:-/Users/x/Desktop/newtest}}"
DESKTOP="${HOME}/Desktop"
QUIET=0
[ "${2:-}" = "--quiet" ] && QUIET=1

say()    { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
warn()   { printf 'WARN: %s\n' "$*" >&2; }
fail()   { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }
fatal()  { printf '错误: %s\n' "$*" >&2; exit 2; }

FAIL=0

# --- 0. 环境前提 ----------------------------------------------------------
[ -d "$DESKTOP" ] || fatal "Desktop 目录不存在: $DESKTOP"
git -C "$MAIN" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fatal "主仓库不是 git 仓库（或路径不可达）: $MAIN"
MAIN_ABS="$(cd "$MAIN" && pwd)" || fatal "无法解析主仓库绝对路径: $MAIN"
MAIN_BASE="$(basename "$MAIN_ABS")"

say "==== verify-worktree · 主仓库: $MAIN_ABS ===="

# --- 1. Desktop 根散落 worktree 扫描（含兜底，不只信主仓库登记） ----------
say "-- [1/2] 扫描 $DESKTOP 根下散落 worktree --"
SCATTER=0
# 1a. 权威：主仓库登记的全部 worktree 中，除主仓库自身外，凡落在 Desktop 根 → FAIL
while IFS= read -r line; do
  case "$line" in
    worktree*)
      wt="${line#worktree }"
      # 跳过主仓库自身条目
      [ "$(cd "$wt" 2>/dev/null && pwd)" = "$MAIN_ABS" ] && continue
      if [ "$(dirname "$wt")" = "$DESKTOP" ]; then
        fail "散落 worktree 在 Desktop 根（主仓库登记）: $wt"
        SCATTER=1
      else
        say "  提示: 非 Desktop 根的 worktree 存在: $wt（列表干净检查会裁决）"
      fi
      ;;
  esac
done < <(git -C "$MAIN_ABS" worktree list --porcelain 2>/dev/null)

# 1b. 兜底：Desktop 根下任意目录若是 git 仓库且非主仓库 → FAIL
for entry in "$DESKTOP"/*; do
  [ -d "$entry" ] || continue
  [ "$(basename "$entry")" = "$MAIN_BASE" ] && continue
  [ -e "$entry/.git" ] || continue
  tl="$(git -C "$entry" rev-parse --show-toplevel 2>/dev/null)" || continue
  if [ "$tl" = "$entry" ]; then
    fail "散落 git 仓库/worktree 在 Desktop 根（目录直扫）: $entry"
    SCATTER=1
  fi
done
[ "$SCATTER" -eq 0 ] && say "  PASS: Desktop 根无散落 worktree"

# --- 2. 主仓库 worktree 列表干净 ------------------------------------------
say "-- [2/2] 主仓库 worktree 列表 --"
WT_COUNT=$(git -C "$MAIN_ABS" worktree list --porcelain 2>/dev/null | grep -c '^worktree ' || true)
if [ "$WT_COUNT" -le 1 ]; then
  say "  PASS: 主仓库 worktree 列表干净（仅主仓库，count=${WT_COUNT}）"
else
  fail "主仓库 worktree 列表不干净（count=${WT_COUNT}，应仅主仓库 1 条）:"
  git -C "$MAIN_ABS" worktree list >&2
fi

# --- 附加：主仓库位置 WARN（归位由 run-lead 另排期，不判 FAIL） ------------
if [ "$(dirname "$MAIN_ABS")" = "$DESKTOP" ]; then
  warn "主仓库仍位于 Desktop 根: ${MAIN_ABS}（归位工程根由 run-lead 排期，此处仅提示）"
  warn "  建议命令（run-lead 批准后执行）:"
  warn "    mv ${MAIN_ABS} ${DESKTOP}/projects/$(basename "$MAIN_ABS")"
  warn "    git -C ${DESKTOP}/projects/$(basename "$MAIN_ABS") worktree list   # 复核落点"
fi

# --- 汇总 ----------------------------------------------------------------
if [ "$FAIL" -eq 0 ]; then
  say "==== 结果: PASS（exit 0）===="
  exit 0
fi
say "==== 结果: FAIL（exit 1，修复后重跑）===="
exit 1
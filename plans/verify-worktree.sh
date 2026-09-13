#!/usr/bin/env bash
# ============================================================================
# verify-worktree.sh —— worktree 治理核验脚本
# ----------------------------------------------------------------------------
# 用法:
#   verify-worktree.sh [主仓库路径] [--quiet]
#   主仓库：位置参数优先，其次环境变量 MAIN_REPO；两者都没有则报用法错误退出
#   主仓库归位工程根尚未执行时，脚本接受主仓库留在现位的 WARN（不判 FAIL，
#   归位由 run-lead 另行排期；结尾给出建议命令供执行时对照）。
#
# 检查（acceptance 3）:
#   1) 散落根不再出现任何散落 worktree（git 仓库目录，主仓库自身除外）
#   2) 主仓库 `git worktree list` 干净：除主仓库外无任何其他 worktree
#   附加: 主仓库若仍在散落根 → WARN（归位待 run-lead 排期）
#
# 退出码: 0=全部通过; 1=存在 FAIL; 2=用法/环境错误
# ============================================================================
set -uo pipefail

MAIN="${1:-${MAIN_REPO:-}}"
if [ -z "$MAIN" ]; then
  printf '✗ 用法: %s <主仓库路径> [--quiet]（或用环境变量 MAIN_REPO 指定）\n' "$0" >&2
  exit 2
fi
# 散落根（scatter root）：worktree 不应散落的位置。
#   解析优先级：SCAN_ROOT > DESKTOP > 平台候选（Desktop / 桌面）；
#   全部不存在时不判 FAIL（优雅降级为 WARN），因为无桌面环境的机器属正常情形。
SCAN_ROOT="${SCAN_ROOT:-${DESKTOP:-}}"
if [ -z "$SCAN_ROOT" ]; then
  for cand in "$HOME/Desktop" "$HOME/桌面"; do
    [ -d "$cand" ] && { SCAN_ROOT="$cand"; break; }
  done
fi
# （phys 定义在下方函数区，此处先占位，解析完函数后归一）
QUIET=0
[ "${2:-}" = "--quiet" ] && QUIET=1

# 物理路径（解析符号链接）：macOS `/var`→`/private/var` 等场景必须归一后比较，
#   否则 git 返回的物理路径与逻辑路径永不相等，比较静默失效。
phys() { if [ -d "$1" ]; then (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; else printf '%s' "$1"; fi; }

say()    { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
warn()   { printf 'WARN: %s\n' "$*" >&2; }
fail()   { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }
fatal()  { printf '错误: %s\n' "$*" >&2; exit 2; }

FAIL=0

# 路径归一（须在函数定义之后）：消除符号链接差异
[ -n "$SCAN_ROOT" ] && SCAN_ROOT="$(phys "$SCAN_ROOT")"

# --- 0. 环境前提 ----------------------------------------------------------
SCATTER_CHECK=1
if [ -z "$SCAN_ROOT" ] || [ ! -d "$SCAN_ROOT" ]; then
  warn "散落根不存在（SCAN_ROOT=${SCAN_ROOT:-未设}）：跳过第 1 项扫描（无桌面环境属正常）"
  SCATTER_CHECK=0
  SCAN_ROOT="${SCAN_ROOT:-$HOME}"
fi
git -C "$MAIN" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fatal "主仓库不是 git 仓库（或路径不可达）: $MAIN"
MAIN_ABS="$(phys "$MAIN")" || fatal "无法解析主仓库绝对路径: $MAIN"
MAIN_BASE="$(basename "$MAIN_ABS")"

say "==== verify-worktree · 主仓库: $MAIN_ABS ===="

# --- 1. 散落根 worktree 扫描（含兜底，不只信主仓库登记） --------------------
say "-- [1/2] 扫描 $SCAN_ROOT 下散落 worktree --"
SCATTER=0
if [ "${SCATTER_CHECK:-1}" -eq 1 ]; then
# 1a. 权威：主仓库登记的全部 worktree 中，除主仓库自身外，凡落在散落根 → FAIL
while IFS= read -r line; do
  case "$line" in
    worktree*)
      wt="${line#worktree }"
      # 跳过主仓库自身条目
      [ "$(phys "$wt")" = "$MAIN_ABS" ] && continue
      if [ "$(dirname "$(phys "$wt")")" = "$SCAN_ROOT" ]; then
        fail "散落 worktree 在散落根（主仓库登记）: $wt"
        SCATTER=1
      else
        say "  提示: 非散落根的 worktree 存在: ${wt}（列表干净检查会裁决）"
      fi
      ;;
  esac
done < <(git -C "$MAIN_ABS" worktree list --porcelain 2>/dev/null)

# 1b. 兜底：散落根下任意目录若是 git 仓库且非主仓库 → FAIL
for entry in "$SCAN_ROOT"/*; do
  [ -d "$entry" ] || continue
  [ "$(basename "$entry")" = "$MAIN_BASE" ] && continue
  [ -e "$entry/.git" ] || continue
  tl="$(phys "$(git -C "$entry" rev-parse --show-toplevel 2>/dev/null)")" || continue
  if [ "$tl" = "$(phys "$entry")" ]; then
    fail "散落 git 仓库/worktree 在散落根（目录直扫）: $entry"
    SCATTER=1
  fi
done
[ "$SCATTER" -eq 0 ] && say "  PASS: 散落根无散落 worktree"
fi

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
if [ "$(dirname "$MAIN_ABS")" = "$SCAN_ROOT" ]; then
  warn "主仓库仍位于散落根: ${MAIN_ABS}（归位工程根由 run-lead 排期，此处仅提示）"
  warn "  建议命令（run-lead 批准后执行）:"
  warn "    mv ${MAIN_ABS} ${SCAN_ROOT}/projects/$(basename "$MAIN_ABS")"
  warn "    git -C ${SCAN_ROOT}/projects/$(basename "$MAIN_ABS") worktree list   # 复核落点"
fi

# --- 汇总 ----------------------------------------------------------------
if [ "$FAIL" -eq 0 ]; then
  say "==== 结果: PASS（exit 0）===="
  exit 0
fi
say "==== 结果: FAIL（exit 1，修复后重跑）===="
exit 1
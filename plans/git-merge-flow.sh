#!/usr/bin/env bash
# ============================================================================
# git-merge-flow.sh —— 特性分支 → 提交 → 推送 → PR → 合并提交 → 删分支
# ----------------------------------------------------------------------------
# 用法:
#   git-merge-flow.sh start <分支名>              从最新 main 建分支（脏工作区拒绝）
#   git-merge-flow.sh commit "<type(scope): 摘要>" git add -A 后提交（Conventional Commits；
#                                                 当前分支已有 PR 时自动追加 Refs: #<PR>）
#   git-merge-flow.sh pr <标题>                   推送当前分支并 gh pr create --base main
#                                                 （同分支已有开着 PR 时复用，不重复创建）
#   git-merge-flow.sh merge <PR号>                以**合并提交**落地：gh pr merge <n> --merge
#                                                 --delete-branch=false → 本地 main 拉取
#                                                 --ff-only → 断言顶端为合并提交（父数=2）
#                                                 → 删除远端特性分支
#   git-merge-flow.sh status                      当前分支 / 开着的 PR / main 合并提交数
#   git-merge-flow.sh -h|--help                   显示本用法
# 退出码: 0=成功；1=业务前置不满足（脏工作区、分支已存在、无 PR、断言失败、git/gh 操作失败）；2=用法或环境错误（未知子命令、缺参数、非法参数、非 git 仓库、无 gh 或未登录）
# 依赖: git；pr/merge/status 需 gh（GitHub CLI，已登录）
# 说明: 合并方式固定为合并提交（merge commit）——不使用 squash/rebase；
#       远端分支删除在**断言通过后**执行，断言失败则保留分支以便排查
# ============================================================================

set -uo pipefail

say() { printf '%s\n' "$*"; }
fail1() { printf '✗ %s\n' "$*" >&2; exit 1; }
die2() { printf '✗ %s\n' "$*" >&2; exit 2; }
usage() { sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; }
need_git() { git rev-parse --git-dir >/dev/null 2>&1 || die2 "当前目录不是 git 仓库"; }
need_gh() {
  command -v gh >/dev/null 2>&1 || die2 "未找到 gh（GitHub CLI）——无法核验 ≠ 通过"
  gh auth status >/dev/null 2>&1 || die2 "gh 未登录——无法核验 ≠ 通过（先执行 gh auth login）"
}
head_branch() { git branch --show-current; }
ensure_main() { # 切到本地 main；不存在则从 origin/main 建立
  if git show-ref --verify --quiet refs/heads/main; then
    git checkout main >/dev/null 2>&1 || fail1 "切回本地 main 失败"
  else
    git checkout -b main --track origin/main >/dev/null 2>&1 || fail1 "本地无 main，且无法从 origin/main 建立"
  fi
}
open_pr_number() { # 当前分支开着的 PR 号（无则空）
  command -v gh >/dev/null 2>&1 || return 0
  gh pr list --head "$(head_branch)" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true
}

case "${1:-}" in
  -h|--help|help) usage; exit 0 ;;
  start|commit|pr|merge|status) ;;
  "") printf '✗ 缺子命令（见 --help）\n' >&2; usage >&2; exit 2 ;;
  *) die2 "未知子命令（见 --help）: $1" ;;
esac
CMD="$1"; shift

case "$CMD" in
  start)
    [ $# -ge 1 ] || die2 "start 缺分支名（用法: start <分支名>）"
    NAME="$1"
    case "$NAME" in -*|*' '*) die2 "分支名非法: $NAME" ;; esac
    need_git
    DIRTY="$(git status --porcelain)"
    [ -z "$DIRTY" ] || fail1 "工作区不干净（$(printf '%s\n' "$DIRTY" | wc -l | tr -d ' ') 项未提交）⇒ 拒绝创建分支"
    git show-ref --verify --quiet "refs/heads/${NAME}" && fail1 "本地分支已存在: ${NAME}"
    git fetch origin main --quiet || fail1 "git fetch origin main 失败"
    git checkout -b "$NAME" origin/main >/dev/null 2>&1 || fail1 "创建分支失败: ${NAME}"
    say "已创建分支 ${NAME}（基于 origin/main $(git rev-parse --short origin/main)）"
    ;;

  commit)
    [ $# -ge 1 ] || die2 "commit 缺提交信息（用法: commit \"<type(scope): 摘要>\"）"
    MSG="$*"
    printf '%s' "$MSG" | grep -qE '^[a-z]+(\([^)]+\))?!?: .+' \
      || die2 "提交信息须为 Conventional Commits 形式（type(scope): 摘要）: ${MSG}"
    need_git
    PR_NUM="$(open_pr_number)"
    FULL="$MSG"
    [ -z "$PR_NUM" ] || FULL="$(printf '%s\n\nRefs: #%s' "$MSG" "$PR_NUM")"
    git add -A || fail1 "git add -A 失败"
    git commit -m "$FULL" >/dev/null 2>&1 || fail1 "git commit 失败（无改动可提交？）"
    say "已提交 $(git log -1 --pretty='%h %s')"
    [ -z "$PR_NUM" ] || say "已追加 Refs: #${PR_NUM}"
    ;;

  pr)
    [ $# -ge 1 ] || die2 "pr 缺标题（用法: pr <标题>）"
    TITLE="$*"
    need_git; need_gh
    BR="$(head_branch)"
    [ -n "$BR" ] || fail1 "当前为游离 HEAD，无法发起 PR"
    [ "$BR" != main ] || fail1 "当前分支是 main；PR 须由特性分支发起（先 start <分支名>）"
    EXIST="$(open_pr_number)"
    if [ -n "$EXIST" ]; then
      say "已存在 PR #${EXIST}（分支 ${BR}）——不重复创建"
      exit 0
    fi
    git push -u origin HEAD >/dev/null 2>&1 || fail1 "推送分支 ${BR} 失败"
    URL="$(gh pr create --base main --head "$BR" --title "$TITLE" \
             --body "${PR_BODY:-由 git-merge-flow.sh 创建：以合并提交（merge commit）方式落地 main。}" 2>&1)" \
      || fail1 "创建 PR 失败: ${URL}"
    say "已推送分支 ${BR}"
    say "PR #${URL##*/}: ${URL}"
    ;;

  merge)
    [ $# -ge 1 ] || die2 "merge 缺 PR 号（用法: merge <PR号>）"
    NUM="$1"
    case "$NUM" in ''|*[!0-9]*) die2 "PR 号须为正整数: ${NUM}" ;; esac
    need_git; need_gh
    HEAD_REF="$(gh pr view "$NUM" --json headRefName --jq '.headRefName' 2>/dev/null)" \
      || fail1 "读取 PR #${NUM} 失败（号不存在或无权限？）"
    [ -n "$HEAD_REF" ] || fail1 "PR #${NUM} 无 headRefName，无法确定要删除的分支"
    say "合并 PR #${NUM}（head=${HEAD_REF}）——使用合并提交（--merge），不自动删远端分支"
    gh pr merge "$NUM" --merge --delete-branch=false >/dev/null 2>&1 \
      || fail1 "gh pr merge 失败（可能：本仓仅允许合并提交/必需状态检查未通过/无权限）"
    ensure_main
    git pull --ff-only origin main >/dev/null 2>&1 || fail1 "本地 main 快进失败（git pull --ff-only origin main）"
    PARENTS="$(git log -1 --pretty=%P | wc -w | tr -d ' ')"
    [ "$PARENTS" = 2 ] || fail1 "断言失败：main 顶端父提交数=${PARENTS}（非合并提交）⇒ 不删除远端分支"
    say "断言通过：main 顶端为合并提交（父提交数=2，$(git log -1 --pretty='%h %s'))"
    git push origin --delete "$HEAD_REF" >/dev/null 2>&1 || fail1 "删除远端分支失败: ${HEAD_REF}"
    say "已完成：PR #${NUM} 以合并提交落地 main，远端分支 ${HEAD_REF} 已删除"
    ;;

  status)
    need_git
    say "当前分支: $(head_branch)"
    RC=0
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
      say "开着的 PR:"
      gh pr list --state open --json number,headRefName,title \
        --jq '.[] | "  #\(.number)  \(.headRefName)  —— \(.title)"' 2>/dev/null \
        || say "  （读取失败）"
    else
      say "开着的 PR: 无法核验（gh 缺失或未登录）——无法核验 ≠ 通过"
      RC=2
    fi
    REF=main
    git show-ref --verify --quiet refs/heads/main || REF=origin/main
    if git rev-parse --verify --quiet "$REF" >/dev/null; then
      say "main 上合并提交数: $(git rev-list --merges --count "$REF")（最近 3 条）"
      git log --merges --oneline -3 "$REF" | sed 's/^/  /'
    else
      say "main 上合并提交数: 无法核验（本地无 main 与 origin/main）——无法核验 ≠ 通过"
      RC=2
    fi
    exit "$RC"
    ;;
esac

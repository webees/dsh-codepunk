#!/usr/bin/env bash
# ============================================================================
# github-setup.sh —— GitHub 仓库治理幂等应用（仓库元数据 + main 分支保护）
# ----------------------------------------------------------------------------
# 用法:
#   github-setup.sh [--dry-run] [--repo <owner/name>] [-h|--help]
#     --dry-run     只打印将执行的 gh api 调用（含请求体），不改动远端
#     --repo <slug> 目标仓库，缺省 webees/dsh-codepunk（环境变量 REPO_SLUG 可覆盖）
# 应用内容:
#   ① 仓库元数据: description（中文，取自 preset.yml/README 的定位）/ homepage /
#      delete_branch_on_merge=true / has_discussions=true / allow_squash_merge=false /
#      allow_rebase_merge=false / allow_merge_commit=true（**只允许合并提交**）/
#      allow_auto_merge=true（依赖更新 PR 的自动合并能力，见 ④ 与
#      .github/workflows/dependabot-auto-merge.yml）
#   ② topics: deepseek-harness, multi-agent, ai-agents, orchestration, code-review,
#      preset, workflow-automation, chinese
#   ③ ruleset「保护 main」: deletion + non_fast_forward + pull_request
#      （allowed_merge_methods=["merge"]、required_review_thread_resolution=true、
#      required_approving_review_count=0、dismiss_stale_reviews_on_push=true）+
#      required_status_checks（strict；门禁回归/存活自检/跨平台可移植/文档一致性）；
#      **不启用** required_linear_history（保留合并提交）
#   ④ 自动合并标签「automerge」: 幂等创建（缺失即建）。带该标签的 PR 由
#      .github/workflows/dependabot-auto-merge.yml 自动合并；标签缺失时该路径静默失效
# 幂等: 每步先 GET 比对，再 PATCH/PUT/POST；已存在的 ruleset 按原 id 更新（id 不变）
# 退出码: 0=全部应用且校验通过；1=未完全应用或校验不符（含 required_status_checks 被 GitHub 以 422 拒绝，已写入其余规则、待 CI 首跑后重跑本脚本）；2=环境或用法错误（无 gh、未登录、参数错）
# 依赖: gh（GitHub CLI，已登录）；写操作需该账号对本仓有 admin 权限
# 环境变量: REPO_SLUG / REPO_DESCRIPTION / REPO_HOMEPAGE 可覆盖默认值
# ============================================================================

set -uo pipefail

RS_NAME="保护 main"
SLUG="${REPO_SLUG:-webees/dsh-codepunk}"
DESCRIPTION="${REPO_DESCRIPTION:-多智能体开发流程预设（DeepSeek Harness）：六阶段闭环、双门闩、实现三角、goal 自动续行}"
TOPICS=(deepseek-harness multi-agent ai-agents orchestration code-review preset workflow-automation chinese)
CHECK_CONTEXTS=(门禁回归 存活自检 跨平台可移植 文档一致性)
AUTOMERGE_LABEL="automerge"
LABEL_JSON='{"name":"automerge","color":"0e8a16","description":"带此标签的 PR 由 dependabot-auto-merge.yml 自动合并（必需检查全绿后以合并提交入库）"}'
DRY=0

say() { printf '%s\n' "$*"; }
fail1() { printf '✗ %s\n' "$*" >&2; exit 1; }
die2() { printf '✗ %s\n' "$*" >&2; exit 2; }
usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; }

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --repo) shift; [ $# -gt 0 ] || die2 "--repo 缺参数值"; SLUG="$1" ;;
    *) die2 "未知参数（见 --help）: $1" ;;
  esac
  shift
done
case "$SLUG" in
  */*/*|*/|/*) die2 "仓库标识须为 owner/name 形式: $SLUG" ;;
  */*) ;;
  *) die2 "仓库标识须为 owner/name 形式: $SLUG" ;;
esac
HOMEPAGE="${REPO_HOMEPAGE:-https://github.com/${SLUG}#readme}"

command -v gh >/dev/null 2>&1 || die2 "未找到 gh（GitHub CLI）——无法核验 ≠ 通过"
gh auth status >/dev/null 2>&1 || die2 "gh 未登录——无法核验 ≠ 通过（先执行 gh auth login）"

# ---- API 薄封装：结果入 API_OUT，退出码入 API_RC（均不做隐式退出） --------------
api_get() { # api_get <路径> <jq 表达式>
  API_OUT="$(gh api "$1" --jq "$2" 2>&1)"; API_RC=$?
}
api_write() { # api_write <方法> <路径> <JSON 体>
  if [ "$DRY" = 1 ]; then
    printf '[DRY-RUN] gh api --method %s %s --input - <<JSON\n%s\nJSON\n' "$1" "$2" "$3"
    API_OUT="(dry-run)"; API_RC=0
    return 0
  fi
  API_OUT="$(gh api --method "$1" "$2" --input - 2>&1 <<JSON
$3
JSON
)"; API_RC=$?
}
step() { printf '\n== %s ==\n' "$1"; }
diff_lines() { # diff_lines <期望> <当前>：打印逐行差异（可读，非机器判据）
  say "  --- 期望 / +++ 当前"
  diff <(printf '%s\n' "$1") <(printf '%s\n' "$2") \
    | grep -vE '^[0-9]+(,[0-9]+)?[acd][0-9]+(,[0-9]+)?$' \
    | sed -e 's/^</  期望 /' -e 's/^>/  当前 /' || true
}

REPO_FIELDS='"description\t\(.description // "")\nhomepage\t\(.homepage // "")\nallow_merge_commit\t\(.allow_merge_commit)\nallow_squash_merge\t\(.allow_squash_merge)\nallow_rebase_merge\t\(.allow_rebase_merge)\ndelete_branch_on_merge\t\(.delete_branch_on_merge)\nhas_discussions\t\(.has_discussions)\nallow_auto_merge\t\(.allow_auto_merge)"'
WANT_REPO="$(printf 'description\t%s\nhomepage\t%s\nallow_merge_commit\ttrue\nallow_squash_merge\tfalse\nallow_rebase_merge\tfalse\ndelete_branch_on_merge\ttrue\nhas_discussions\ttrue\nallow_auto_merge\ttrue' "$DESCRIPTION" "$HOMEPAGE")"
REPO_JSON="$(cat <<JSON
{
  "description": "${DESCRIPTION}",
  "homepage": "${HOMEPAGE}",
  "allow_merge_commit": true,
  "allow_squash_merge": false,
  "allow_rebase_merge": false,
  "delete_branch_on_merge": true,
  "has_discussions": true,
  "allow_auto_merge": true
}
JSON
)"

TOPICS_JSON='{"names":['
for _t in "${TOPICS[@]}"; do
  case "$TOPICS_JSON" in *'[') ;; *) TOPICS_JSON="${TOPICS_JSON}," ;; esac
  TOPICS_JSON="${TOPICS_JSON}\"${_t}\""
done
TOPICS_JSON="${TOPICS_JSON}]}"
CHECKS_JSON='['; CHECKS_CSV=""
for _c in "${CHECK_CONTEXTS[@]}"; do
  case "$CHECKS_JSON" in *'[') ;; *) CHECKS_JSON="${CHECKS_JSON}," ;; esac
  CHECKS_JSON="${CHECKS_JSON}{\"context\": \"${_c}\"}"
done
CHECKS_JSON="${CHECKS_JSON}]"
CHECKS_CSV="$(printf '%s\n' "${CHECK_CONTEXTS[@]}" | LC_ALL=C sort | paste -sd, -)"

rules_json() { # rules_json <1=含 required_status_checks | 0=不含>：返回**含前导逗号**的规则片段
  if [ "$1" = 1 ]; then
    cat <<JSON
,
    { "type": "required_status_checks",
      "parameters": { "strict_required_status_checks_policy": true,
                      "required_status_checks": ${CHECKS_JSON} } }
JSON
  fi
}
# 注: pull_request 规则的参数 schema 是**闭集**——缺任一字段即 422「data matches no possible
#   input」（实测：仅给 allowed_merge_methods 或仅给 required_approving_review_count 均被拒），
#   故此处写全 7 个参数；required_status_checks 则接受**尚未有运行记录**的检查名（实测通过）。
payload() { # payload <1=含 required_status_checks | 0=不含>
  cat <<JSON
{
  "name": "${RS_NAME}",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request",
      "parameters": { "allowed_merge_methods": ["merge"],
                      "required_approving_review_count": 0,
                      "dismiss_stale_reviews_on_push": true,
                      "required_review_thread_resolution": true,
                      "require_code_owner_review": false,
                      "require_last_push_approval": false,
                      "required_reviewers": [] } }$(rules_json "$1")
  ]
}
JSON
}

DEGRADED=0
say "目标仓库: ${SLUG}$( [ "$DRY" = 1 ] && printf '（--dry-run：只打印将执行的调用）' )"

step "① 仓库元数据"
api_get "repos/${SLUG}" "$REPO_FIELDS"
[ "$API_RC" = 0 ] || fail1 "读取仓库元数据失败: ${API_OUT}"
if [ "$API_OUT" = "$WANT_REPO" ]; then
  say "无变化：仓库元数据（description/homepage/merge 策略/discussions）"
else
  say "更新：仓库元数据"
  diff_lines "$WANT_REPO" "$API_OUT"
  api_write PATCH "repos/${SLUG}" "$REPO_JSON"
  [ "$API_RC" = 0 ] || fail1 "更新仓库元数据失败: ${API_OUT}"
  [ "$DRY" = 1 ] || say "已更新：仓库元数据"
fi

step "② topics"
api_get "repos/${SLUG}/topics" '.names | sort | .[]'
[ "$API_RC" = 0 ] || fail1 "读取 topics 失败: ${API_OUT}"
if [ "$API_OUT" = "$(printf '%s\n' "${TOPICS[@]}" | LC_ALL=C sort)" ]; then
  say "无变化：topics（$(printf '%s' "${TOPICS[*]}" | tr ' ' ',')）"
else
  say "更新：topics"
  api_write PUT "repos/${SLUG}/topics" "$TOPICS_JSON"
  [ "$API_RC" = 0 ] || fail1 "更新 topics 失败: ${API_OUT}"
  [ "$DRY" = 1 ] || say "已更新：topics"
fi

step "③ 分支保护 ruleset「${RS_NAME}」"
api_get "repos/${SLUG}/rulesets" '.[] | "\(.id)\t\(.name)\t\(.enforcement)"'
[ "$API_RC" = 0 ] || fail1 "读取 rulesets 失败: ${API_OUT}"
RS_ID=""
while IFS=$'\t' read -r _id _name _enf; do
  [ "${_name:-}" = "$RS_NAME" ] && RS_ID="$_id"
done <<EOF
$API_OUT
EOF

RS_FIELDS='[ (.rules | map(.type) | sort | join(",")),
  ((.rules[] | select(.type == "pull_request") | .parameters
    | [ (.allowed_merge_methods | sort | join(",")), (.required_approving_review_count | tostring),
        (.dismiss_stale_reviews_on_push | tostring), (.required_review_thread_resolution | tostring) ] | join(","))
   // "pull_request 缺失"),
  ((.rules[] | select(.type == "required_status_checks") | .parameters
    | [ (.strict_required_status_checks_policy | tostring),
        ([.required_status_checks[].context] | sort | join(",")) ] | join(","))
   // "required_status_checks 缺失") ] | .[]'
# 注: jq 的 sort 为码点序，与下方 LC_ALL=C 的 sort 一致（避免中文 locale 下的排序差异）
WANT_RS="deletion,non_fast_forward,pull_request,required_status_checks
merge,0,true,true
true,${CHECKS_CSV}"

if [ -z "$RS_ID" ]; then
  say "创建：ruleset「${RS_NAME}」（本仓当前不存在）"
  api_write POST "repos/${SLUG}/rulesets" "$(payload 1)"
  if [ "$API_RC" != 0 ] && printf '%s' "$API_OUT" | grep -q '422'; then
    say "⚠ required_status_checks 被 GitHub 以 422 拒绝（检查名尚无 CI 运行记录）⇒ 先写入其余规则"
    say "  原始错误: $(printf '%s' "$API_OUT" | head -3 | tr '\n' ' ')"
    api_write POST "repos/${SLUG}/rulesets" "$(payload 0)"
    DEGRADED=1
  fi
  [ "$API_RC" = 0 ] || fail1 "创建 ruleset 失败: ${API_OUT}"
  [ "$DRY" = 1 ] || say "已创建：ruleset"
else
  say "已存在：ruleset id=${RS_ID}（存在即更新，id 不变）"
  api_get "repos/${SLUG}/rulesets/${RS_ID}" "$RS_FIELDS"
  [ "$API_RC" = 0 ] || fail1 "读取 ruleset ${RS_ID} 失败: ${API_OUT}"
  if [ "$API_OUT" = "$WANT_RS" ]; then
    say "无变化：ruleset 规则（deletion / non_fast_forward / pull_request / required_status_checks）"
  else
    say "更新：ruleset 规则"
    diff_lines "$WANT_RS" "$API_OUT"
    api_write PUT "repos/${SLUG}/rulesets/${RS_ID}" "$(payload 1)"
    if [ "$API_RC" != 0 ] && printf '%s' "$API_OUT" | grep -q '422'; then
      say "⚠ required_status_checks 被 GitHub 以 422 拒绝（检查名尚未有 CI 运行记录）⇒ 先写入其余规则"
      say "  原始错误: $(printf '%s' "$API_OUT" | head -3 | tr '\n' ' ')"
      api_write PUT "repos/${SLUG}/rulesets/${RS_ID}" "$(payload 0)"
      DEGRADED=1
    fi
    [ "$API_RC" = 0 ] || fail1 "更新 ruleset 失败: ${API_OUT}"
    [ "$DRY" = 1 ] || say "已更新：ruleset id=${RS_ID}（id 不变）"
  fi
fi

step "④ 自动合并标签「${AUTOMERGE_LABEL}」"
api_get "repos/${SLUG}/labels/${AUTOMERGE_LABEL}" '.name'
if [ "$API_RC" = 0 ] && [ "$API_OUT" = "$AUTOMERGE_LABEL" ]; then
  say "无变化：标签「${AUTOMERGE_LABEL}」（存在 ⇒ 打此标签的 PR 会被自动合并）"
else
  say "创建：标签「${AUTOMERGE_LABEL}」"
  api_write POST "repos/${SLUG}/labels" "$LABEL_JSON"
  [ "$API_RC" = 0 ] || fail1 "创建标签「${AUTOMERGE_LABEL}」失败: ${API_OUT}"
  [ "$DRY" = 1 ] || say "已创建：标签「${AUTOMERGE_LABEL}」"
fi

if [ "$DRY" = 1 ]; then
  say ""
  say "（--dry-run：未改动远端，跳过最终校验）"
  exit 0
fi

step "⑤ 最终校验（GET 回读）"
api_get "repos/${SLUG}" "$REPO_FIELDS"
[ "$API_RC" = 0 ] || fail1 "回读仓库元数据失败: ${API_OUT}"
printf '%s\n' "$API_OUT" | sed 's/^/  /'
api_get "repos/${SLUG}/rulesets" '.[] | "\(.id)\t\(.name)\t\(.target)\t\(.enforcement)"'
[ "$API_RC" = 0 ] || fail1 "回读 rulesets 列表失败: ${API_OUT}"
printf '%s\n' "$API_OUT" | sed 's/^/  /'
RS_ID=""
while IFS=$'\t' read -r _id _name _rest; do
  [ "${_name:-}" = "$RS_NAME" ] && RS_ID="$_id"
done <<EOF
$API_OUT
EOF
[ -n "$RS_ID" ] || fail1 "回读未找到 ruleset「${RS_NAME}」"
api_get "repos/${SLUG}/rulesets/${RS_ID}" '.rules[].type'
[ "$API_RC" = 0 ] || fail1 "回读 ruleset 规则失败: ${API_OUT}"
say "  ruleset id=${RS_ID} 规则类型:"
printf '%s\n' "$API_OUT" | sed 's/^/    · /'
api_get "repos/${SLUG}/labels/${AUTOMERGE_LABEL}" '.name'
[ "$API_RC" = 0 ] || fail1 "回读标签「${AUTOMERGE_LABEL}」失败: ${API_OUT}"
say "  自动合并标签: ${API_OUT}"
api_get "repos/${SLUG}/rulesets/${RS_ID}" "$RS_FIELDS"
[ "$API_RC" = 0 ] || fail1 "回读 ruleset 参数失败: ${API_OUT}"
RS_READBACK="$API_OUT"
printf '%s\n' "$RS_READBACK" | sed 's/^/  /'

say ""
if [ "$DEGRADED" = 1 ]; then
  say "结论：部分应用 —— 除 required_status_checks 外的规则均已生效；"
  say "      待 CI 首次运行产出上述检查名后，重跑本脚本即可补齐（重跑幂等）。"
  exit 1
fi
if [ "$RS_READBACK" = "$WANT_RS" ]; then
  say "结论：全部应用并校验通过（仓库元数据（含 allow_auto_merge）+ topics + 标签「${AUTOMERGE_LABEL}」+ ruleset「${RS_NAME}」）"
  exit 0
fi
say "结论：校验不符 —— ruleset 参数与期望不一致（见上，重跑本脚本）"
exit 1

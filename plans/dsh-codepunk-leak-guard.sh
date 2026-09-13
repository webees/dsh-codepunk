#!/usr/bin/env bash
# ============================================================================
# dsh-codepunk-leak-guard —— 泄露防护门（推送/提交前守卫，D091）
#
# 设计原则：**机制进仓库，禁词留本地**。
#   公开仓库里的守卫脚本本身不得包含任何私人词（否则守卫自身即泄露源，
#   与 preset-audit.sh 曾硬编码旧名同一教训）；私人词从本地配置读取。
#
# 禁词来源（按优先级，均不进仓库）：
#   1) 环境变量 DSH_CODEPUNK_DENYLIST（分隔符 : , 空格 或换行）
#   2) ~/.dsh-codepunk/denylist.txt（每行一词，# 开头为注释）
#   3) 仓库内 .leak-denylist（仅当项目自建，且已确认其内容可公开）
#
# 通用模式（可进仓库，非私人信息）：绝对路径 / 私网地址 / 凭据形态 /
#   邮箱 / 内部会话号。这些即使无禁词也生效。
#
# 用法：
#   bash dsh-codepunk-leak-guard.sh                 # 扫索引（git diff --cached），适合作为 pre-commit
#   bash dsh-codepunk-leak-guard.sh --tree          # 扫工作树全部跟踪文件
#   bash dsh-codepunk-leak-guard.sh --history       # 扫提交信息与新增行（HEAD~N..HEAD）
#   bash dsh-codepunk-leak-guard.sh --install-hook  # 安装 pre-push 钩子（扫将推送的提交）
#   bash dsh-codepunk-leak-guard.sh --list          # 只打印载入的禁词（脱敏）
#
# 退出码：0=通过；1=命中（阻断）；2=用法/环境错误
# ============================================================================
set -uo pipefail

MODE="staged"
for a in "$@"; do
  case "$a" in
    --tree)         MODE="tree" ;;
    --history)      MODE="history" ;;
    --staged)       MODE="staged" ;;
    --install-hook) MODE="install" ;;
    --list)         MODE="list" ;;
    -h|--help)      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: ${a}（--help 查看用法）" >&2; exit 2 ;;
  esac
done

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "不在 git 仓库内" >&2; exit 2; }
cd "$ROOT"

# ── 通用模式（可公开：形态而非具体值） ────────────────────────────────────
read -r -d '' GENERIC <<'PAT' || true
/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/|[A-Za-z]:\\\\Users\\\\|/Applications/[A-Za-z]
(^|[^0-9])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3})
sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}
-----BEGIN [A-Z ]*PRIVATE KEY-----
[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}
PAT

# ── 载入禁词 ──────────────────────────────────────────────────────────────
DENY_RAW=""
[ -n "${DSH_CODEPUNK_DENYLIST:-}" ] && DENY_RAW+=$'\n'"$(printf '%s' "$DSH_CODEPUNK_DENYLIST" | tr ':,' '\n')"
for f in "$HOME/.dsh-codepunk/denylist.txt" "$ROOT/.leak-denylist"; do
  [ -f "$f" ] && DENY_RAW+=$'\n'"$(grep -v '^\s*#' "$f" 2>/dev/null)"
done
# 归一：去空白、去过短（<3 字符易误报）、去重
DENY=$(printf '%s\n' "$DENY_RAW" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | awk 'length($0)>=3' | sort -u)

mask() { # 脱敏显示
  local t="$1" n=${#1}
  if [ "$n" -le 4 ]; then printf '%s' "$t" | sed 's/./*/g'
  else printf '%s%s' "$(printf '%s' "$t" | cut -c1-2)" "$(printf '%s' "$t" | cut -c3- | sed 's/./*/g')"; fi
}

if [ "$MODE" = "list" ]; then
  n=$(printf '%s' "$DENY" | grep -c . || true)
  echo "载入禁词: ${n:-0} 条"
  [ "${n:-0}" -gt 0 ] && printf '%s\n' "$DENY" | while read -r t; do [ -n "$t" ] && echo "  • $(mask "$t")"; done
  exit 0
fi

# ── 安装 pre-push 钩子 ────────────────────────────────────────────────────
if [ "$MODE" = "install" ]; then
  HOOK_DIR=$(git rev-parse --git-path hooks)
  mkdir -p "$HOOK_DIR"
  SELF="$ROOT/plans/dsh-codepunk-leak-guard.sh"
  [ -f "$SELF" ] || SELF="$0"
  SELF_ABS="$(cd "$(dirname "$SELF")" && pwd)/$(basename "$SELF")"
  # pre-commit：扫索引（含提交信息草稿无法覆盖，但能拦下将入库的内容）
  cat > "$HOOK_DIR/pre-commit" <<HOOK
#!/usr/bin/env bash
# dsh-codepunk 泄露防护门（D091）——由 --install-hook 生成
exec bash "$SELF_ABS" --staged
HOOK
  # pre-push：扫近 20 提交（含提交信息体——实证：曾把本机凭据路径写进提交信息）
  cat > "$HOOK_DIR/pre-push" <<HOOK
#!/usr/bin/env bash
# dsh-codepunk 泄露防护门（D091）——由 --install-hook 生成
exec bash "$SELF_ABS" --history
HOOK
  chmod +x "$HOOK_DIR/pre-commit" "$HOOK_DIR/pre-push"
  echo "✓ 已安装钩子:"
  echo "    $HOOK_DIR/pre-commit  （--staged：拦截将入库内容）"
  echo "    $HOOK_DIR/pre-push    （--history：拦截含提交信息体的近 20 提交）"
  echo "  绕过（不建议）: --no-verify"
  exit 0
fi

# ── 扫描 ──────────────────────────────────────────────────────────────────
HITS=0
scan_stream() { # $1=描述  $2=内容流
  local label="$1" content="$2" pat="$GENERIC" line
  # 通用模式
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if printf '%s\n' "$content" | grep -nE -- "$line" | grep -qvE 'noreply\.github\.com'; then
      printf '%s\n' "$content" | grep -nE -- "$line" | grep -vE 'noreply\.github\.com' | head -3 | while IFS= read -r m; do
        printf '  [通用] %s :: %s\n' "$label" "$(printf '%.160s' "$m")"
      done
      HITS=$((HITS+1))
    fi
  done <<< "$pat"
  # 禁词
  while IFS= read -r term; do
    [ -z "$term" ] && continue
    if printf '%s\n' "$content" | grep -nFiq -- "$term"; then
      c=$(printf '%s\n' "$content" | grep -ncFi -- "$term")
      printf '  [禁词] %s :: 命中 %s 次（词已脱敏）\n' "$label" "$c"
      HITS=$((HITS+1))
    fi
  done <<< "$DENY"
}

case "$MODE" in
  staged)
    CONTENT=$(git diff --cached -U0 2>/dev/null | grep '^+' | grep -v '^+++')
    [ -z "$CONTENT" ] && { echo "✓ 索引无新增内容（无可扫描的提交内容）"; exit 0; }
    scan_stream "staged" "$CONTENT"
    ;;
  tree)
    CONTENT=""
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      case "$f" in *.png|*.jpg|*.jpeg|*.gif|*.webp|*.pdf|*.zip|*.gz|*.bundle) continue ;; esac
      CONTENT+=$(sed -n '1,4000p' "$f" 2>/dev/null)
      CONTENT+=$'\n'
    done < <(git ls-files)
    scan_stream "tracked-tree" "$CONTENT"
    ;;
  history)
    CONTENT=$(git log -20 --format='%s%n%b' 2>/dev/null; git log -20 -p -U0 2>/dev/null | grep '^+' | grep -v '^+++')
    [ -z "$CONTENT" ] && { echo "✓ 近 20 提交无可扫描内容"; exit 0; }
    scan_stream "history(近20提交)" "$CONTENT"
    ;;
esac

echo
if [ "$HITS" -gt 0 ]; then
  printf '\033[31m✗ 泄露防护门：命中 %s 类，已阻断\033[0m\n' "$HITS"
  echo "  处置：脱敏上述内容后重试；确认为误报时用 git commit/push --no-verify 绕过（需留痕说明）"
  exit 1
fi
DN=$(printf '%s' "$DENY" | grep -c . 2>/dev/null | head -1); DN=${DN:-0}
GN=$(printf '%s\n' "$GENERIC" | grep -c . 2>/dev/null | head -1); GN=${GN:-0}
printf '\033[32m✓ 泄露防护门：通过（禁词 %s 条 + 通用模式 %s 类）\033[0m\n' "$DN" "$GN"
exit 0

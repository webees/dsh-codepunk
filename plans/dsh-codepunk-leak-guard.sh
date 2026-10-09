#!/usr/bin/env bash
# =============================================
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
#   邮箱。这些即使无禁词也生效。
#   （早前注释曾多列「内部会话号」，但 `GENERIC` 从未实现该模式——已按实况更正，F140。）
#
# 用法：
#   bash dsh-codepunk-leak-guard.sh                 # 扫索引（git diff --cached），适合作为 pre-commit
#   bash dsh-codepunk-leak-guard.sh --tree          # 扫工作树全部跟踪文件
#   bash dsh-codepunk-leak-guard.sh --history       # 扫提交信息与新增行（近 20 提交窗口；报实际扫描提交数，
#                                                   #   浅克隆/空仓库判「无法核验 ≠ 通过」rc=2）
#   bash dsh-codepunk-leak-guard.sh --msg <file>   # 扫指定提交信息文件（commit-msg 钩子用；信息体不进索引，pre-commit 覆盖不到）
#   bash dsh-codepunk-leak-guard.sh --staged       # 显式指定扫索引（与默认同）
#   bash dsh-codepunk-leak-guard.sh --install-hook  # 装 pre-commit + pre-push + commit-msg 三钩子
#   bash dsh-codepunk-leak-guard.sh --list          # 只打印载入的禁词（脱敏）
#
# 退出码：0=通过；1=命中（阻断）；2=用法/环境错误、**无法核验**（含 git 行为异常、tree 模式扫描零文件、
#   history 模式浅克隆或空仓库）
# =============================================
set -uo pipefail

# F195/F196/F197（locale 固定）：C/POSIX 与非 UTF-8 locale 下 BSD 工具链逐字节处理 ⇒ 判据失效或误报，按 `locale charmap` 判定并在存在 UTF-8 locale 时固定。
case "$(locale charmap 2>/dev/null)" in
  UTF-8|utf8|UTF8) ;;
  *)
    for _l in en_US.UTF-8 C.UTF-8 C.utf8 UTF-8; do
      if locale -a 2>/dev/null | grep -qx "$_l"; then export LC_ALL="$_l"; break; fi
    done ;;
esac

# F421：POSIX 模式（`POSIXLY_CORRECT=1` 或 `bash --posix`）关闭扩展 ⇒ 进程替换报语法错误且无保守措辞，会被误归因为「脚本坏了」；此处前置拒答。
if [ -n "${POSIXLY_CORRECT:-}" ] || set -o 2>/dev/null | grep -qE '^posix[[:space:]]+on'; then
  echo "✗ POSIX 模式（POSIXLY_CORRECT 或 bash --posix）⇒ 无法核验 ≠ 通过（rc=2）" >&2
  exit 2
fi

# F405（依赖预检，MUST）：本门禁的禁词归一管道（`sed … | awk 'length($0)>=3' | sort -u`）与掩码、文件枚举
#   都依赖下列外部命令。缺失时**必须**判「无法核验 ≠ 通过」（rc=2），绝不静默降级为通过 ——
#   实证：影子 PATH 去掉 awk 时，禁词表 25 条被静默归零，门仍打印「✓ 通过（禁词 0 条 + 通用模式 5 类）」。
for _t in git awk sed sort grep cut; do
  command -v "$_t" >/dev/null 2>&1 \
    || { printf '✗ 缺少必需工具 %s ⇒ 无法核验 ≠ 通过（rc=2）\n' "$_t" >&2; exit 2; }
done

MODE="staged"
MSG_FILE=""
while [ $# -gt 0 ]; do
  a="$1"
  case "$a" in
    --msg)          MODE="msg"; shift; MSG_FILE="${1:-}"; [ -n "$MSG_FILE" ] || { echo "--msg 需要文件参数" >&2; exit 2; } ;;
    --tree)         MODE="tree" ;;
    --history)      MODE="history" ;;
    --staged)       MODE="staged" ;;
    --install-hook) MODE="install" ;;
    --list)         MODE="list" ;;
    # 注：此处曾有重复的 `--msg)` 分支（未 shift 且 MSG_FILE 取错值）。bash 的 case 只取
    # 首个匹配，故它恒不可达；一旦上方分支重排即会静默读错文件——已删除，勿再补。
    -h|--help)      sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: ${a}（--help 查看用法）" >&2; exit 2 ;;
  esac
  shift
done

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "不在 git 仓库内" >&2; exit 2; }
# F387（本轮对抗实测）：`git rev-parse` **只验退出码**时，「说谎的 git」（PATH 前置 stub，exit 0 且零输出）
#   与环境变量误设（`GIT_DIR`/`GIT_WORK_TREE` 指向别处或空仓）都能通过本守卫，随后 `git ls-files` 返回空
#   ⇒ tree 模式**一个文件都没扫**，末尾仍打「✓ 泄露防护门：通过」并 rc=0（与 F250「按扩展名排除的二进制
#   从不被扫描却默默打通过」、F252「依赖故障伪装成通过」同族）。故：判定前先要求 git 自证可用
#   （`--git-dir` 必须有输出），tree 模式再核对**实际扫描文件数**，零输入一律以 2 拒绝（无法核验 ≠ 通过）。
GITDIR_OUT=$(git rev-parse --git-dir 2>/dev/null)
if [ -z "$GITDIR_OUT" ]; then
  echo "✗ git 不可用或行为异常（git rev-parse --git-dir 无输出；疑为损坏/替身 git 或 GIT_DIR 误设）——无法核验 ≠ 通过" >&2
  exit 2
fi
cd "$ROOT"

# ── 通用模式（可公开：形态而非具体值） ────────────────────────────────────
# F251：形态覆盖缺口（均以**自然写法**即可绕过，非刻意混淆）——
#   · 绝对路径原要求**尾斜杠** ⇒ 句末「/Users/<名>」这类最常见形态假阴；现尾斜杠可省（跟随非名字字符或行尾）。
#   · 私网地址原缺 **CGNAT 100.64/10**（tailnet/运营商级 NAT 常用段）。
#   · 凭据形态原仅 sk-（连字符）、gh[pousr]_、AKIA、xox ⇒ 补 sk 下划线变体、GitLab 形态、Google 形态。
#   注：本块内**不得书写可命中的字面样例**（tree 扫描会读到本文件自身 ⇒ 自锁）。
read -r -d '' GENERIC <<'PAT' || true
/Users/[A-Za-z0-9._-]+(/|[^A-Za-z0-9._-]|$)|/home/[A-Za-z0-9._-]+(/|[^A-Za-z0-9._-]|$)|[A-Za-z]:[\\/]{1,2}Users[\\/]|/Applications/[A-Za-z]
(^|[^0-9])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3})
sk[-_][A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|glpat-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}
-----BEGIN [A-Z ]*PRIVATE KEY-----
[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}
PAT

# F287：本脚本多处引用 HOME 变量（禁词表、总库路径；注释内亦不使用 `$` 紧跟全角，免触 B1b）。若 HOME 未设（极端环境或已被清空的会话），
#   旧实现在 `set -u` 下直接以 `HOME: unbound variable` 中止——既非契约式退出、也无「无法核验 ≠ 通过」
#   式诊断，且因被 pre-commit 钩子调用而**静默阻断一切提交**（实测：提交未发生而仅见 unbound 报错）。
#   此处统一兜底：HOME 未设/为空 ⇒ 按环境错误给可读诊断并按契约返回 2。
if [ -z "${HOME:-}" ]; then
  echo "  ✗ 环境错误：HOME 未设 ⇒ 无法定位禁词表与总库（无法核验 ≠ 通过）" >&2
  echo "    处理：在设好 HOME 的会话中重跑；或显式提供 DSH_CODEPUNK_DENYLIST 后重试。" >&2
  exit 2
fi

# ── 载入禁词 ──────────────────────────────────────────────────────────────
DENY_RAW=""
[ -n "${DSH_CODEPUNK_DENYLIST:-}" ] && DENY_RAW+=$'\n'"$(printf '%s' "$DSH_CODEPUNK_DENYLIST" | tr ':,' '\n')"
DENY_UNREADABLE=""
for f in "$HOME/.dsh-codepunk/denylist.txt" "$ROOT/.leak-denylist"; do
  # F284：旧实现 `[ -f "$f" ] && … 2>/dev/null` 会**吞掉读错误** ⇒ 文件存在但不可读时禁词**静默降为 0 条**，
  #   而门禁仍报「通过」❌（违反本仓教义「无法核验 ≠ 通过」；对公开仓的推送前隐私门属**静默失效**）。
  #   现分三态：不存在＝正常态（只用通用模式）；可读＝载入；**存在但不可读＝无法核验 ⇒ 响亮失败 rc=2**。
  if [ -f "$f" ]; then
    if [ -r "$f" ]; then
      DENY_RAW+=$'\n'"$(grep -v '^\s*#' "$f" 2>/dev/null)"
    else
      DENY_UNREADABLE="$f"
    fi
  fi
done
if [ -n "$DENY_UNREADABLE" ]; then
  {
    printf '\033[31m✗ 禁词表存在但不可读：%s\033[0m\n' "$DENY_UNREADABLE"
    printf '  ⇒ 禁词数未知（无法核验），按「无法核验 ≠ 通过」判**失败**（rc=2）。\n'
    printf '  ⇒ 请修复该文件权限后重跑；如确为空表，请写入至少一行或删除该文件。\n'
  } >&2
  exit 2
fi
# 归一：去空白、去过短（<3 字符易误报）、去重
DENY=$(printf '%s\n' "$DENY_RAW" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | awk 'length($0)>=3' | sort -u)
# F405 不变量：源非空而归一后为空 ⇒ 归一管道失效（外部命令缺失/被改写）⇒ 无法核验 ≠ 通过。
#   仅有上面的依赖预检还不够：预检只覆盖「命令不存在」，此断言覆盖「命令在但管道被改坏/被别名遮蔽」。
if [ -n "$(printf '%s' "$DENY_RAW" | tr -d '[:space:]')" ] && [ -z "$(printf '%s' "$DENY" | tr -d '[:space:]')" ]; then
  printf '\033[31m✗ 禁词表非空但归一后为空 ⇒ 归一管道失效（无法核验 ≠ 通过，rc=2）\033[0m\n' >&2
  exit 2
fi

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

# ── 安装三钩子：pre-commit（索引）/ pre-push（近 20 提交含信息体）/ commit-msg（信息即时） ──
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
  # commit-msg：提交信息即时扫描（信息体不进索引，pre-commit 覆盖不到）
  cat > "$HOOK_DIR/commit-msg" <<HOOK
#!/usr/bin/env bash
# dsh-codepunk 泄露防护门（D091）——由 --install-hook 生成
exec bash "$SELF_ABS" --msg "\$1"
HOOK
  chmod +x "$HOOK_DIR/pre-commit" "$HOOK_DIR/pre-push" "$HOOK_DIR/commit-msg"
  echo "✓ 已安装钩子:"
  echo "    $HOOK_DIR/pre-commit  （--staged：拦截将入库内容）"
  echo "    $HOOK_DIR/pre-push    （--history：拦截含提交信息体的近 20 提交）"
  echo "    $HOOK_DIR/commit-msg  （--msg：提交信息入库前即时拦截）"
  echo "  绕过（不建议）: --no-verify"
  exit 0
fi

# ── 扫描 ──────────────────────────────────────────────────────────────────
HITS=0
scan_stream() { # $1=描述  $2=内容流
  local label="$1" content="$2" pat="$GENERIC" line term tmp c m
  # 内容落临时文件后按文件检索。
  # 关键：不得用 `printf … | grep -q`——命中时 grep 提前退出会让上游 printf 收
  # SIGPIPE(141)，在本脚本的 `set -o pipefail` 下整条管道判为失败，命中反被吞掉
  # （内容超过管道缓冲区 64KB 时必现，实测 tree 模式聚合 444KB → 全部命中漏检）。
  # F252：原为 `|| return 0` ⇒ 临时文件不可用（mktemp 失败/依赖缺失/受限环境）时**静默跳过扫描**，
  #   HITS 保持 0 ⇒ 末尾打「✓ 泄露防护门：通过」并 rc=0 —— 依赖故障被伪装成「通过」（跳过 ≠ 通过，
  #   与 F180/F234/F239/F247/F250 同族）。现改为显式报错并归入「无法核验」（2）。
  tmp="$(mktemp)" || { echo "✗ 无法创建临时文件（mktemp 失败）——无法核验 ≠ 通过" >&2; exit 2; }
  printf '%s\n' "$content" > "$tmp"

  # 通用模式
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    m="$(grep -nE -- "$line" "$tmp" 2>/dev/null | grep -vE 'noreply\.github\.com' | head -3)"
    if [ -n "$m" ]; then
      # 命中样例 MUST 脱敏：通用模式可能命中凭据/邮箱/私网地址，回显原文＝把秘密写进终端与 CI 日志
      #   （F141；与 [禁词] 路径的「词已脱敏」及 Windows 端口口径一致）。
      _cnt=$(printf '%s\n' "$m" | grep -c . )
      printf '  [通用] %s :: 命中 %s 处（样例已脱敏：%s）\n' "$label" "$_cnt" "$(mask "$(printf '%s' "$m" | head -1 | cut -c1-8)")"

      HITS=$((HITS+1))
    fi
  done <<< "$pat"

  # 禁词（-c 不加 -q：计数即判定，避免提前退出）
  while IFS= read -r term; do
    [ -z "$term" ] && continue
    c="$(grep -cFi -- "$term" "$tmp" 2>/dev/null || true)"
    if [ "${c:-0}" -gt 0 ]; then
      printf '  [禁词] %s :: 命中 %s 次（词已脱敏）\n' "$label" "$c"
      HITS=$((HITS+1))
    fi
  done <<< "$DENY"

  rm -f "$tmp"
}

case "$MODE" in
  msg)
    # commit-msg 钩子：提交信息在入库前即时扫描（不再只靠 pre-push 回溯）
    [ -f "$MSG_FILE" ] || { echo "提交信息文件不存在: $MSG_FILE" >&2; exit 2; }
    CONTENT=$(cat "$MSG_FILE")
    [ -z "$CONTENT" ] && { echo "✓ 提交信息为空（无可扫描内容）"; exit 0; }
    scan_stream "commit-msg" "$CONTENT"
    ;;
  staged)
    # F250：二进制文件在 `git diff --cached -U0` 中不产生 `+` 内容行 ⇒ 原实现把「唯一变更是一个二进制文件」
    #   也当作「索引无新增内容」并以 0 放行 ⇒ 该二进制**从未被扫描**却呈现为「通过」（跳过 ≠ 通过），
    #   且 `2>/dev/null` 会把 git 报错一并降级为「通过」。现改为：git 出错 ⇒ 2（无法核验）；
    #   含二进制 ⇒ 显式阻断（本仓口径：无法核验不得当作通过；确需提交二进制用 --no-verify 并留痕）。
    if ! DIFF=$(git diff --cached -U0 2>&1); then
      echo "✗ 无法读取索引（git diff 失败）：$(printf '%s' "$DIFF" | head -1)——无法核验 ≠ 通过" >&2
      exit 2
    fi
    CONTENT=$(printf '%s\n' "$DIFF" | grep '^+' | grep -v '^+++')
    BIN=$(git diff --cached --numstat 2>/dev/null | awk '$1=="-" && $2=="-"' | wc -l | tr -d ' ')
    if [ -z "$CONTENT" ]; then
      if [ "${BIN:-0}" -gt 0 ]; then
        echo "✗ 索引含 ${BIN} 个二进制文件（无法扫描内容）——无法核验 ≠ 通过；确需提交请 git commit --no-verify 并留痕说明"
        exit 1
      fi
      echo "✓ 索引无新增内容（无可扫描的提交内容）"; exit 0
    fi
    [ "${BIN:-0}" -gt 0 ] && echo "  ℹ 另有 ${BIN} 个二进制文件未扫描（无法核验 ≠ 通过；确需提交请 --no-verify 并留痕）" >&2
    scan_stream "staged" "$CONTENT"
    ;;
  tree)
    # F250 同族：按扩展名排除的二进制从未被扫描 ⇒ 原实现对此**不发一言**即打「✓ 通过」。
    #   现显式告知跳过数量（无法核验 ≠ 通过）。非 git 工作区已由上方 ROOT 守卫以 2 拒绝，此处无需再判。
    # F387（本轮实测）：上方守卫只能挡「git 不可用」，挡不住「git 可用但枚举为空」——`GIT_DIR`/`GIT_WORK_TREE`
    #   指向别处（如空仓）时 `git ls-files` 返回空、`[ -f ]` 再滤掉一切 ⇒ 扫描 0 文件却打「✓ 通过」。
    #   故此处统计**实际扫描数**，零输入以 2 拒绝，并在通过行报告扫描数（零输入在输出中必须可见）。
    CONTENT=""; SKIPPED=0; SCANNED=0
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      case "$f" in *.png|*.jpg|*.jpeg|*.gif|*.webp|*.pdf|*.zip|*.gz|*.bundle) SKIPPED=$((SKIPPED+1)); continue ;; esac
      CONTENT+=$(sed -n '1,4000p' "$f" 2>/dev/null)
      CONTENT+=$'\n'
      SCANNED=$((SCANNED+1))
    done < <(git ls-files)
    if [ "$SCANNED" -eq 0 ]; then
      echo "✗ 未扫描到任何跟踪文件（git ls-files 返回空或所列文件在本工作树中不存在；疑为 GIT_DIR/GIT_WORK_TREE 误设或替身 git）——无法核验 ≠ 通过" >&2
      exit 2
    fi
    [ "$SKIPPED" -gt 0 ] && echo "  ℹ 跳过 ${SKIPPED} 个按扩展名排除的二进制文件（未扫描）——无法核验 ≠ 通过" >&2
    echo "  ℹ 已扫描 ${SCANNED} 个跟踪文件（未扫描数：${SKIPPED}）" >&2
    scan_stream "tracked-tree" "$CONTENT"
    ;;
  history)
    # 轮次 605（F321）：**git 尾注（trailer）中的邮箱属结构化提交元数据，非隐私泄漏**——机器人与 DCO 签名
    #   （`Signed-off-by: <机器人> <<地址>>` 形态）会命中通用「邮箱形态」模式，导致**一切带尾注签名的
    #   提交/PR 被永久阻断**（实测：Dependabot 的 5 个依赖更新 PR 在 rebase 后仍全红，失败步骤＝电池的
    #   「守卫 --history」）。此处**只屏蔽尾注行内的地址**（其余内容仍全量扫描，以免连凭据/路径类泄漏
    #   一并豁免）；真泄漏在文件内容与提交主题中仍会被拦截。注意：本注释内不得书写可命中的地址字面样例
    #   （tree 扫描会读到本文件自身 ⇒ 自锁）。
    # F409（本轮实测）：与 tree 模式同族——**覆盖率必须可见**。原实现只打印「✓ 通过（禁词 25 条 + 通用
    #   模式 5 类）」，不报实际扫描的提交数；浅克隆（`.git/shallow` 在场，CI 与「只取一层的」克隆常见）下
    #   `git log` 只返回可见提交，输出却与全历史扫描**无法区分** ⇒ 审计者会以为全历史已核验（实测：
    #   `--depth 1` 克隆 rc=0 且与完整仓输出同形）；空仓库同理（0 提交也打「✓」）。二者判「无法核验 ≠ 通过」。
    if [ -n "$GITDIR_OUT" ] && [ -f "$GITDIR_OUT/shallow" ]; then
      echo "✗ 浅克隆仓库（\`.git/shallow\` 在场）：历史被截断 ⇒ 无法核验 ≠ 通过（rc=2）；处置：git fetch --unshallow 后重试" >&2
      exit 2
    fi
    TOTAL=$(git rev-list --count HEAD 2>/dev/null || true); TOTAL=${TOTAL:-0}
    if [ "$TOTAL" -eq 0 ]; then
      echo "✗ 无任何提交可扫描（空仓库）——无法核验 ≠ 通过（rc=2）" >&2
      exit 2
    fi
    TRAILER_MASK='s/^((Signed-off-by|Co-authored-by|Reviewed-by|Tested-by|Acked-by|Reported-by|Suggested-by):[^<]*<)[^>]*@[^>]*>/\1redacted>/'
    WIN=$(git log -20 --format=%H 2>/dev/null | grep -c . || true); WIN=${WIN:-0}
    echo "  ℹ 已扫描 ${WIN} 个提交（窗口＝近 20；仓库总提交 ${TOTAL}）" >&2
    if [ "$TOTAL" -gt "$WIN" ]; then
      echo "  ℹ 更早的 $((TOTAL-WIN)) 个提交不在本窗口内（全历史内容扫描请另用 git log -p 或加大窗口）" >&2
    fi
    CONTENT=$( { git log -20 --format='%s%n%b' 2>/dev/null | sed -E "$TRAILER_MASK"; git log -20 -p -U0 2>/dev/null | grep '^+' | grep -v '^+++'; } )
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

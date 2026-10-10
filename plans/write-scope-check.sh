#!/usr/bin/env bash
# ======
# write-scope-check.sh —— 写盘纪律门（仓库残留 / 主目录散落 / 临时目录残留）
# ------
# 需求源：写盘纪律契约（用户指令 2026-10-07，knowledge/write-scope-policy.md）。
#   探针/补丁脚本与临时产物 MUST 落在运行根；工程工作树内、主目录顶层与系统临时
#   目录顶层的**临时/探针命名物**一律视为越界（不依赖 git 跟踪状态——未跟踪同样算）。
#
# 退出码: 0=通过; 1=发现越界或运行根 write_scope 登记不合规; 2=无法核验或用法错（--repo 不存在/非目录、
#   HOME 未设、未知参数、--exempt-from 文件不可读、--run-root 目录或 README 缺失）
#
# 用法:
#   write-scope-check.sh [--repo <路径>] [--home] [--tmp] [--home-all] [--exempt-from <文件>]
#                        [--run-root <运行根>] [--quiet] [--help]
#     --repo <路径>  被检目录树（缺省＝当前目录）；含未跟踪文件，排除 .git/
#     --home         扫 $HOME 顶层（maxdepth 1）：dsh-codepunk* / probe-* / patch-* / 轮次号（ROUND_PAT）
#     --tmp          扫**两个**临时根顶层：${TMPDIR:-/tmp} 与 /tmp（契约允许临时物落 $TMPDIR **或**
#                    /tmp/dsh-codepunk-<run>-<step>/）；两者解析为同一目录时按 realpath 去重、只扫一次；
#                    判定**只认本契约命名空间**（条目名以 `dsh-codepunk-` 开头），其余同形条目降级 INFO
#                    （归属规则详见下方「检查」段 G3）
#     --home-all     同 --home，并额外**列出**（INFO，永不判 FAIL）$HOME 顶层的
#                    *.sh/*.py/*.md/*.json/*.yaml/*.yml/*.log（排除 README*、LICENSE*、.DS_Store）
#     --exempt-from <文件>
#                    读取豁免登记（约定为运行根 README.md 的 `write_scope:` 段 `exempt:` 列表）；
#                    与登记项**相等**、或位于某登记项**之内**（＝登记项为命中路径的**祖先目录**）的命中降级为 INFO（列出但不判 FAIL；登记写法相对/`./x`/尾斜杠/绝对等价）。
#                    缺省**不启用**（行为同旧版）。文件不存在/不可读 ⇒ exit 2（无法核验 ≠ 通过）。
#     --run-root <运行根>
#                    核验该运行根的 `README.md` 是否含 R17 要求的 `write_scope:` 登记段
#                    （键：run_id / allowed_prefixes / created / cleanup_status / exempt；
#                    cleanup_status 取值须为 clean 或 pending）。只跑这一项、不扫目录树。
#                    **判据 h（F396，加严 F403）**：`cleanup_status: clean` 时运行根**含子目录**不得存在
#                    备份/临时命名物与编译缓存（`*.bak` / `*.bak-*` / `*~` / `*.orig` / `*.rej` / `*.tmp` /
#                    `*.swp` / `__pycache__` / `*.pyc`）——否则该取值与实况不符（R17/§6.2 黑名单；
#                    声称不可核验时 MUST 判失败）。递归扫描需要 `find`，缺 `find` ⇒ exit 2。
#                    该模式的 `write_scope:` 段抽取依赖 `awk`/`sed`/`grep`/`head`/`tr`，缺任一个 ⇒
#                    exit 2（F405：否则空值会被判成「段缺失」，保守但把操作者引向错误原因）。
#                    运行根或 README 缺失 ⇒ exit 2（无法核验 ≠ 通过）；段缺失/缺键/取值非法/判据 h 命中 ⇒ exit 1。
#     --quiet        静默通过行；失败行与结论仍输出
#     -h, --help     显示本用法
#   未给 --home/--tmp/--home-all 时，默认等价于 `--repo . --tmp`；显式给了模式参数时只跑所选模式。
#
# 检查:
#   G1 仓库残留：--repo 目录树内命中临时/探针命名 ⇒ FAIL（含 Python 字节码缓存 `__pycache__`/`*.pyc`
#       —— 本仓多个 python 门禁被 import 即生成，实测对旧判据不可见：F364）
#       （probe-*、patch-*、tmp*、*.bak、*.orig、*.rej、*.log、*.tmp、*~）
#   G2 主目录散落：$HOME 顶层命中预设/探针前缀/轮次号 ⇒ FAIL
#   G3 临时目录残留（**归属收窄**）：${TMPDIR:-/tmp} 与 /tmp 顶层命中同前缀/轮次号时——
#       仅**条目名以 `dsh-codepunk-` 开头**者（＝契约 §一.3 允许的 /tmp/dsh-codepunk-<run>-<step>/
#       本契约命名空间）判 FAIL；其余同形条目（轮次号 ROUND_PAT*、probe-*、patch-*，但**不以**
#       `dsh-codepunk-` 开头）一律降级为 INFO「归属不明」——不改判、不影响退出码
#       （宿主 /tmp 常有他人遗留，归因错误只会制造不可行动的红项）
#   G1/G2 判据不受 G3 收窄影响（仍按原前缀/轮次号模式判 FAIL）
#
# 口径统一：轮次号用**同一个**共享变量 ROUND_PAT（见下方常量；`r`+≥2 位数字前缀）供 G2/G3 使用——
#   两位/三位轮次号通用（`r70-probe`、`r700-probe` 均命中），避免两处正则各写一份而漂移
#   （旧版 G3 写死 `r6[0-9][0-9]*`，700 轮后即失效）。
#
# ======
set -uo pipefail

_EG="$(dirname "${BASH_SOURCE[0]:-$0}")/env-guard.sh"; [ -r "$_EG" ] || { echo "✗ 缺 ${_EG}（无法核验）" >&2; exit 2; }; . "$_EG"  # F195/F197+F421 守卫库

# 轮次号命名口径（G2/G3 **共用**此变量，避免两处漂移）：`r` + ≥2 位数字的前缀，
#   两位/三位轮次号通用（`r70-probe`、`r700-probe` 均命中）；使用处一律写 `$ROUND_PAT*`
#   （旧版 G3 写死 `r6[0-9][0-9]*`，仅覆盖 6xx，700 轮起即漏检）。
ROUND_PAT='r[0-9][0-9]'

REPO="."
RUN_ROOT=""
SCAN_HOME=0
SCAN_HOME_ALL=0
SCAN_TMP=0
QUIET=0
MODE_GIVEN=0
EXEMPT_FILE=""

while [ $# -gt 0 ]; do
  a="$1"
  case "$a" in
    --repo) shift; REPO="${1:-}"
            [ -n "${REPO}" ] || { printf '✗ 用法: --repo 需要一个路径参数（--help 查看用法）\n' >&2; exit 2; } ;;
    --home)     SCAN_HOME=1; MODE_GIVEN=1 ;;
    --tmp)      SCAN_TMP=1; MODE_GIVEN=1 ;;
    --home-all) SCAN_HOME=1; SCAN_HOME_ALL=1; MODE_GIVEN=1 ;;
    --run-root) shift; RUN_ROOT="${1:-}"
            [ -n "${RUN_ROOT}" ] || { printf '✗ 用法: --run-root 需要一个目录参数（--help 查看用法）\n' >&2; exit 2; } ;;
    --exempt-from) shift; EXEMPT_FILE="${1:-}"
            [ -n "${EXEMPT_FILE}" ] || { printf '✗ 用法: --exempt-from 需要一个文件路径参数（--help 查看用法）\n' >&2; exit 2; } ;;
    --quiet)    QUIET=1 ;;
    -h|--help)  sed -n '2,50p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf '✗ 未知参数: %s（--help 查看用法）\n' "$a" >&2; exit 2 ;;
  esac
  shift
done
# 默认模式：未给任何模式参数 ⇒ 等价 `--repo . --tmp`
[ "${MODE_GIVEN}" -eq 0 ] && SCAN_TMP=1

say()  { [ "${QUIET}" -eq 1 ] || printf '%s\n' "$*"; }
fail() { printf '%s\n' "$*" >&2; FAIL=1; }
fatal() { printf '✗ %s\n' "$*" >&2; printf '  ⇒ 无法核验，不判「通过」（无法核验 ≠ 通过）\n' >&2; exit 2; }
FAIL=0

# ── --run-root：核验运行根 README 的 `write_scope:` 登记段（R17 MUST） ──────────
# F377 实证：运行根 README 只写了**散文**形态的写盘说明（无 `write_scope:` 键、内容陈旧三十余轮），
#   而 `references/artifacts.md` §1.3 要求 MUST 含 YAML 登记段（run_id / allowed_prefixes / created /
#   cleanup_status / exempt），且 `cleanup_status: clean` 是**交接门与合并门的前置读数** ⇒ 散文形态下
#   该读数根本不存在（门闩形同空转）。本模式把该 MUST 变成机械判据（只跑这一项，不扫目录树）。
if [ -n "${RUN_ROOT}" ]; then
  [ -d "${RUN_ROOT}" ] || fatal "运行根不存在或不是目录: ${RUN_ROOT}"
  RR_README="${RUN_ROOT}/README.md"
  [ -f "${RR_README}" ] || fatal "运行根缺 README.md: ${RR_README}（R17 要求其中含 write_scope: 段）"
  # F405（诊断准确性；与 preset-audit/preset-score/leak-guard/verify-battery 同族）：
  #   下方 awk 抽取与 sed 归一是**解析依赖**。缺失时 BLK/CS 为空 ⇒ 门**保守地**判失败，但报出的是
  #   「运行根 README 缺 write_scope: 段」，把操作者引向错误方向（实证：影子 PATH 去掉 awk 后
  #   rc=1 且报「缺 write_scope: 段」，而该运行根 README 实况合规、正常环境下 rc=0）。
  #   ⇒ 显式预检，给出真实原因（无法核验 ≠ 通过，rc=2）。
  for _t in awk sed grep head tr; do
    command -v "$_t" >/dev/null 2>&1 \
      || fatal "缺少必需工具 ${_t} ⇒ 无法核验 ≠ 通过（rc=2）"
  done
  BLK="$(awk '
    /^write_scope:[ \t]*$/ { inblk=1; print; next }
    inblk && /^[A-Za-z_][A-Za-z0-9_]*:/ { exit }
    inblk { print }
  ' "${RR_README}")"
  say "==== write-scope-check · 运行根写域登记（R17） ===="
  say "运行根：${RUN_ROOT}"
  if [ -z "${BLK}" ]; then
    fail "✗ 运行根 README 缺 write_scope: 段（R17 MUST；模板见 references/artifacts.md §1.3）"
  else
    MISS=""
    for k in run_id allowed_prefixes created cleanup_status exempt; do
      printf '%s\n' "${BLK}" | grep -qE "^[[:space:]]+${k}:" || MISS="${MISS} ${k}"
    done
    [ -n "${MISS}" ] && fail "✗ write_scope 段缺键:${MISS}"
    CS="$(printf '%s\n' "${BLK}" | sed -n 's/^[[:space:]]*cleanup_status:[[:space:]]*//p' | head -1 \
          | sed -E 's/[[:space:]]+#.*$//' | sed -E 's/[[:space:]]+$//' | tr -d '"')"
    case "${CS}" in
      clean|pending) say "  ✅ cleanup_status=${CS}" ;;
      "") fail "✗ write_scope 段缺 cleanup_status 取值（须为 clean 或 pending）" ;;
      *)  fail "✗ cleanup_status 取值非法: '${CS}'（须为 clean 或 pending）" ;;
    esac
    [ -z "${MISS}" ] && [ -n "${CS}" ] && say "  ✅ write_scope 段 5 键齐备（run_id / allowed_prefixes / created / cleanup_status / exempt）"
    # 判据 h（F396 / 加严 F403）：cleanup_status=clean 的**实况**核验——运行根**含子目录**不得留
    #   备份/临时命名物与编译缓存（`*.bak`/`*.bak-*`/`*~`/`*.orig`/`*.rej`/`*.tmp`/`*.swp`/`__pycache__`/`*.pyc`）。
    #   F403 实证：原实现只扫**顶层**（shell 通配）⇒ `tools/__pycache__/*.pyc`（14 个）在场而门仍 rc=0、
    #   `cleanup_status: clean` 在子目录层面不可核验。递归扫描需要 find ⇒ 缺 find 时显式 exit 2。
    if [ "${CS}" = "clean" ]; then
      if command -v find >/dev/null 2>&1; then
        RR_N=$( ( cd "${RUN_ROOT}" && find . \( -name '*.bak' -o -name '*.bak-*' -o -name '*~' -o -name '*.orig' \
                  -o -name '*.rej' -o -name '*.tmp' -o -name '*.swp' -o -name '__pycache__' -o -name '*.pyc' \) \
                  -print 2>/dev/null ) | wc -l | tr -d ' ')
        RR_JUNK=$( ( cd "${RUN_ROOT}" && find . \( -name '*.bak' -o -name '*.bak-*' -o -name '*~' -o -name '*.orig' \
                  -o -name '*.rej' -o -name '*.tmp' -o -name '*.swp' -o -name '__pycache__' -o -name '*.pyc' \) \
                  -print 2>/dev/null ) | head -6 | tr '\n' ' ')
      else
        fatal "缺少必需工具 find ⇒ 无法核验运行根残留（无法核验 ≠ 通过）"
      fi
      if [ "${RR_N:-0}" -gt 0 ]; then
        fail "✗ cleanup_status=clean 但运行根存在备份/临时/编译缓存残留 ${RR_N} 处（收尾未清理，R17/§6.2 黑名单）: ${RR_JUNK}"
      else
        say "  ✅ cleanup_status=clean 且运行根（含子目录）无备份/临时/编译缓存残留（判据 h 实况核验）"
      fi
    fi
  fi
  echo
  if [ "${FAIL}" -eq 0 ]; then printf '==== 运行根写域登记：通过（exit 0）====\n'; exit 0; fi
  printf '==== 运行根写域登记：不合规（exit 1）====\n'; exit 1
fi

# hits_line <总数> <路径...> → 「残留 N 处：a、b、c 等」（最多列 4 个路径 + 总数）
hits_line() {
  local n="$1"; shift
  local shown="" i=0 p
  for p in "$@"; do
    [ "$i" -lt 4 ] || break
    [ -n "${shown}" ] && shown="${shown}、"
    shown="${shown}${p}"
    i=$((i + 1))
  done
  if [ "$n" -gt "$i" ]; then printf '残留 %s 处：%s 等' "$n" "$shown"
  else printf '残留 %s 处：%s' "$n" "$shown"; fi
}

# ── 豁免登记（--exempt-from；缺省不启用 ⇒ 行为同旧版） ─────────────────────
# 契约 §六：真实交付物不属临时物；豁免须在运行根 README.md 的 `write_scope.exempt:` 登记。
# 本实现只做**机械采信**：登记为「交付物」即降级为 INFO，理由是否成立由人审（不在此判）。
SQ="'"; DQ='"'
EXEMPT_FILE_ABS=""
EXEMPT_N=0
EXEMPT_LIST=()

trim_ws() {  # 去首尾空白（含 CR）
  local s="$1"
  s="${s//$'\r'/}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

norm_path() {  # 归一化登记路径：去引号/去尾斜杠/展开 ~；目录存在时取物理路径
  local p
  p="$(trim_ws "$1")"
  p="${p%$DQ}"; p="${p#$DQ}"
  p="${p%$SQ}"; p="${p#$SQ}"
  p="$(trim_ws "$p")"
  p="${p%/}"
  if [ "$p" = "~" ]; then p="${HOME:-~}"
  elif [ "${p:0:2}" = "~/" ]; then p="${HOME:-~}/${p:2}"; fi
  case "$p" in
    /*) if [ -d "$p" ]; then printf '%s' "$(cd "$p" 2>/dev/null && pwd -P)"; else printf '%s' "$p"; fi ;;
    *)  printf '%s' "$p" ;;
  esac
}

push_exempt() {  # 去重后登记
  local e="$1" x
  [ -n "$e" ] || return 0
  for x in ${EXEMPT_LIST[@]+"${EXEMPT_LIST[@]}"}; do [ "$x" = "$e" ] && return 0; done
  EXEMPT_LIST+=( "$e" )
  EXEMPT_N=$((EXEMPT_N + 1))
}

parse_exempt() {  # 解析 `write_scope:` 段内 `exempt:` 列表（见 --help）
  local f="$1" line ind rest ind_len in_ws=0 in_ex=0 ex_ind="" item pv inner part
  local _parts=()
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//$'\r'/}"
    ind="${line%%[![:space:]]*}"
    rest="${line#"$ind"}"
    [ -n "$rest" ] || continue                      # 空行/纯空白行
    case "$rest" in '#'*) continue ;; esac          # 整行注释
    ind_len=${#ind}
    if [ "$ind_len" -eq 0 ]; then
      # 顶层键：仅在 write_scope: 段内继续解析 exempt
      case "$line" in
        write_scope:*) in_ws=1; in_ex=0 ;;
        *)             in_ws=0; in_ex=0 ;;
      esac
      continue
    fi
    [ "$in_ws" -eq 1 ] || continue
    if [ "$in_ex" -eq 0 ]; then
      case "$line" in
        *exempt:*) ;;   # 仅在 exempt 键所在行之后收集条目
        *) continue ;;
      esac
      item="$(trim_ws "${line#*exempt:}")"
      ex_ind="$ind_len"; in_ex=1
      # 行内形式 `exempt: [a, b]`
      case "$item" in
        \[*\])
          inner="${item#[}"; inner="${inner%]}"
          IFS=',' read -r -a _parts <<< "$inner"
          for part in ${_parts[@]+"${_parts[@]}"}; do push_exempt "$(norm_path "$part")"; done
          ;;
        '') ;;                                    # 块列表，条目在后续行
        *)  push_exempt "$(norm_path "$item")" ;;
      esac
      continue
    fi
    # in_ex=1：缩进 > exempt 键 且以 `-` 起者为本列表条目；缩进回退则结束
    if [ "$ind_len" -le "$ex_ind" ]; then in_ex=0; continue; fi
    item="$(trim_ws "$line")"
    case "$item" in
      -*) item="$(trim_ws "${item#-}")" ;;
      *)  continue ;;
    esac
    # 支持三种写法：`- path: X` / `- { path: X, reason: ... }` / `- X`
    case "$item" in
      '{'*path:*) pv="${item#*path:}" ;;
      path:*)     pv="${item#path:}" ;;
      *)          pv="$item" ;;
    esac
    if [ "$pv" != "$item" ] || [ "${item:0:1}" = "{" ]; then
      pv="${pv%%, reason:*}"    # 流式映射/同行 reason 的截断（无匹配时原样保留）
      pv="${pv%%,reason:*}"
      pv="${pv%\}}"
    fi
    push_exempt "$(norm_path "$pv")"
  done < "$f"
}

# canon_path <路径>：**纯字符串**归一（去 `.` 段、折叠 `//`、去尾 `/`），不访问文件系统。
#   必要性：登记写法各异（`plans`、`plans/`、`./plans`、绝对路径）须落到同一形态再比前缀，
#   否则「登记项是命中路径的祖先目录」这条判据会被 `./` 这类纯书写差异漏判。
canon_path() {
  local p="$1" out="" seg lead=""
  case "$p" in /*) lead="/" ;; esac
  while [ -n "$p" ]; do
    seg="${p%%/*}"
    if [ "$p" = "$seg" ]; then p=""; else p="${p#*/}"; fi
    case "$seg" in ''|.) continue ;; esac
    out="${out:+$out/}${seg}"
  done
  printf '%s%s' "$lead" "$out"
}

# is_exempt <命中路径> → 命中与登记项**相等**，或**位于登记项之内**（＝登记项为命中的祖先目录）⇒ 0。
#   方向（F306 finding-1）：登记项是**父目录**时命中降级（登记 `plans` ⇒ 命中 `plans/x.bak` 降级 INFO）；
#   反向（命中是登记项的父目录）**不**豁免——旧实现两处前缀判据写反，`plans`/`plans/`/`./plans`/
#   绝对路径四种父目录写法全部漏判（与本文件 usage、README「登记项为命中路径的相等项或祖先目录」不符）。
is_exempt() {
  local hit="$1" e ra re h
  [ "$EXEMPT_N" -gt 0 ] || return 1
  h="$(canon_path "$hit")"
  for e in "${EXEMPT_LIST[@]}"; do
    [ -n "$e" ] || continue
    re="$(canon_path "$e")"
    case "$re" in
      /*) [ "$h" = "$re" ] && return 0
          case "$h" in "$re"/*) return 0 ;; esac ;;       # 登记项为命中的祖先目录
      *)  ra="$(canon_path "${REPO_ABS}/${re}")"          # 相对登记：先按被检仓库根解析
          [ "$h" = "$ra" ] && return 0
          case "$h" in "$ra"/*) return 0 ;; esac          # 登记项为命中的祖先目录
          case "$h" in "$re"|*/"$re") return 0 ;; esac    # 被检根之外：按路径尾部对齐
          case "$re" in "${h##*/}"/*) return 0 ;; esac ;;
    esac
  done
  return 1
}

emit_exempt() {  # 命中**仍须列出**，只是不判 FAIL
  local p
  for p in "$@"; do say "  ℹ 豁免（登记于 ${EXEMPT_FILE}）: ${p}"; done
}

# split_exempt <路径...> → 置全局 G_VIOL（判 FAIL）/ G_EXE（降级 INFO）
# 三门共用同一分类逻辑，避免「G1 采信豁免而 G3 不采信」这类漂移。
split_exempt() {
  local p
  G_VIOL=(); G_EXE=()
  for p in ${1+"$@"}; do
    if is_exempt "$p"; then G_EXE+=( "$p" ); else G_VIOL+=( "$p" ); fi
  done
}

# ── 环境前提（无法核验 ⇒ 2） ──────────────────────────────────────────────
if [ ! -d "${REPO}" ]; then
  case "${REPO}" in
    /*) _r="${REPO}" ;;
    *)  _r="$(pwd)/${REPO}" ;;
  esac
  fatal "被检目录不存在或不是目录: ${_r}"
fi
[ -r "${REPO}" ] && [ -x "${REPO}" ] || fatal "被检目录不可读/不可进入: ${REPO}"
case "${REPO}" in
  /*) REPO_ABS="${REPO}" ;;
  *)  REPO_ABS="$(pwd)/${REPO}" ;;
esac
REPO_ABS="$(cd "${REPO_ABS}" 2>/dev/null && pwd -P)" || fatal "无法解析被检目录的物理路径: ${REPO}"
if [ -n "${EXEMPT_FILE}" ]; then
  # 豁免登记不可读 ⇒ 无法核验（**无法核验 ≠ 通过**）；不给 --exempt-from 时完全不走此路径。
  [ -f "${EXEMPT_FILE}" ] && [ -r "${EXEMPT_FILE}" ] \
    || fatal "无法核验豁免登记（--exempt-from 文件不存在或不可读）: ${EXEMPT_FILE}"
  EXEMPT_FILE_ABS="$(cd "$(dirname "${EXEMPT_FILE}")" 2>/dev/null && pwd -P)/$(basename "${EXEMPT_FILE}")"
  parse_exempt "${EXEMPT_FILE}"
fi
TMP_ROOT="${TMPDIR:-/tmp}"
if [ "${SCAN_TMP}" -eq 1 ]; then
  [ -d "${TMP_ROOT}" ] || fatal "临时目录不存在: ${TMP_ROOT}（TMPDIR/默认值均不可达）"
  [ -r "${TMP_ROOT}" ] && [ -x "${TMP_ROOT}" ] || fatal "临时目录不可读/不可进入: ${TMP_ROOT}"
fi
if [ "${SCAN_HOME}" -eq 1 ]; then
  [ -n "${HOME:-}" ] || fatal "HOME 未设置 ⇒ 无法定位主目录顶层（无法核验 ≠ 通过）"
  [ -d "${HOME}" ] || fatal "HOME 不是目录: ${HOME}"
fi

# ── 扫描工具可用性（无法核验 ⇒ 2）─────────────────────────────────────────
# F372：G1/G2/G3 全部经 `find … 2>/dev/null` 的**进程替换**取列表；`find` 不在 PATH 时
#   进程替换为空、stderr 被 `2>/dev/null` 吞掉 ⇒ 三项都判「无残留」⇒ exit 0 假绿。
#   实测（真实克隆 + `probe-leftover.sh` 残留）：PATH 含 find ⇒ rc=1「发现越界」；
#   PATH 去掉 find（git/grep/sed/awk/python3/node 仍在）⇒ 修复前 rc=0「通过」，与本文件
#   头部契约「2=无法核验」直接冲突。故此处 MUST 显式预检——且预检**真的执行**一次
#   （非仅 `command -v`），以覆盖「同名但不可用/被替换」的情形。
command -v find >/dev/null 2>&1 || fatal "缺少必需工具 find ⇒ 无法扫描仓库/主目录/临时目录（无法核验 ≠ 通过）"
find . -maxdepth 0 >/dev/null 2>&1 || fatal "find 不可用（预检执行失败）⇒ 无法核验 ≠ 通过"

say "==== write-scope-check · 写盘纪律门 ===="
if [ -n "${EXEMPT_FILE}" ]; then
  say "ℹ 豁免登记：${EXEMPT_FILE_ABS}（--exempt-from；解析出 ${EXEMPT_N} 条；命中降级 INFO，不判 FAIL）"
fi

# ── G1 仓库残留 ───────────────────────────────────────────────────────────
say "-- [G1] 仓库残留扫描: ${REPO_ABS}（含未跟踪，排除 .git/）--"
G1_LIST=()
while IFS= read -r -d '' p; do
  case "${p##*/}" in
    probe-*|patch-*|tmp*|*.bak|*.orig|*.rej|*.log|*.tmp|*~|__pycache__|*.pyc) G1_LIST+=( "$p" ) ;;
  esac
done < <(find "${REPO_ABS}" -mindepth 1 \( -name .git -type d -prune \) -o -print0 2>/dev/null)
G1_HIT=${#G1_LIST[@]}
split_exempt ${G1_LIST[@]+"${G1_LIST[@]}"}
G1_N=${#G_VIOL[@]}
G1_EXE=(${G_EXE[@]+"${G_EXE[@]}"})
if [ "${G1_N}" -gt 0 ]; then
  fail "✗ G1 仓库残留：$(hits_line "${G1_N}" ${G_VIOL[@]+"${G_VIOL[@]}"})"
  fail "  处置：临时/探针物移入运行根（logs/ 或 tmp/<run>/<step>/）或删除；交付物请改用正式命名。"
elif [ "${G1_HIT}" -gt 0 ]; then
  say "  ✓ G1 仓库残留：无越界（命中 ${G1_HIT} 处，均已按豁免登记降级）"
else
  say "  ✓ G1 仓库残留：无（临时/探针命名物 0 处）"
fi
[ "${#G1_EXE[@]}" -gt 0 ] && emit_exempt "${G1_EXE[@]}"

# ── G2 主目录散落 ─────────────────────────────────────────────────────────
if [ "${SCAN_HOME}" -eq 1 ]; then
  say "-- [G2] 主目录散落扫描: ${HOME}（maxdepth 1）--"
  G2_LIST=()
  while IFS= read -r -d '' p; do
    case "${p##*/}" in
      dsh-codepunk*|probe-*|patch-*|$ROUND_PAT*) G2_LIST+=( "$p" ) ;;
    esac
  done < <(find "${HOME}" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
  G2_HIT=${#G2_LIST[@]}
  split_exempt ${G2_LIST[@]+"${G2_LIST[@]}"}
  G2_N=${#G_VIOL[@]}
  G2_EXE=(${G_EXE[@]+"${G_EXE[@]}"})
  if [ "${G2_N}" -gt 0 ]; then
    fail "✗ G2 主目录散落：$(hits_line "${G2_N}" ${G_VIOL[@]+"${G_VIOL[@]}"})"
    fail "  处置：移入运行根或删除；主目录顶层不得留预设/探针命名物。"
  elif [ "${G2_HIT}" -gt 0 ]; then
    say "  ✓ G2 主目录散落：无越界（命中 ${G2_HIT} 处，均已按豁免登记降级）"
  else
    say "  ✓ G2 主目录散落：无（$HOME 顶层 0 处）"
  fi
  [ "${#G2_EXE[@]}" -gt 0 ] && emit_exempt "${G2_EXE[@]}"
fi

# ── G2b 主目录脚本/文档类 INFO（--home-all；永不判 FAIL） ──────────────────
if [ "${SCAN_HOME_ALL}" -eq 1 ]; then
  INFO_LIST=()
  while IFS= read -r -d '' p; do
    b="${p##*/}"
    case "${b}" in
      README*|LICENSE*|.DS_Store) continue ;;
      *.sh|*.py|*.md|*.json|*.yaml|*.yml|*.log) INFO_LIST+=( "$p" ) ;;
    esac
  done < <(find "${HOME}" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
  INFO_N=${#INFO_LIST[@]}
  if [ "${INFO_N}" -eq 0 ]; then
    say "  ℹ --home-all INFO：$HOME 顶层无脚本/文档类文件"
  else
    say "  ℹ --home-all INFO（仅提示，不判失败；请人工确认归属）：${INFO_N} 个"
    _i=0
    for p in "${INFO_LIST[@]}"; do
      [ "${_i}" -lt 10 ] || break
      say "      ${p}"
      _i=$((_i + 1))
    done
    [ "${INFO_N}" -gt 10 ] && say "      …（其余 $((INFO_N - 10)) 个省略）"
  fi
fi

# ── G3 临时目录残留（**两个**根：${TMPDIR:-/tmp} 与 /tmp） ─────────────────
# 契约 §一.3：临时物落 `${TMPDIR}` **或** `/tmp/dsh-codepunk-<run>-<step>/` ⇒ 两个根都必须扫，
#   否则「用 /tmp 而 TMPDIR 指别处」这类残留会静默漏检。两根本质相同（TMPDIR 未设/即 /tmp 时）
#   按物理路径去重，避免同一命中重复计。
if [ "${SCAN_TMP}" -eq 1 ]; then
  TMP_A_R="$(cd "${TMP_ROOT}" 2>/dev/null && pwd -P)"
  TMP_B_R="$(cd /tmp 2>/dev/null && pwd -P)"
  TMP_ROOTS=( "${TMP_A_R}" )
  [ -n "${TMP_B_R}" ] && [ "${TMP_B_R}" != "${TMP_A_R}" ] && TMP_ROOTS+=( "${TMP_B_R}" )
  say "-- [G3] 临时目录残留扫描（maxdepth 1）--"
  if [ -z "${TMP_B_R}" ]; then
    say "  扫描根: ${TMP_ROOTS[0]}（/tmp 不存在或不可进入，本次未扫）"
  elif [ "${TMP_B_R}" = "${TMP_A_R}" ]; then
    say "  扫描根: ${TMP_A_R}（与 /tmp 同一目录，已去重）"
  else
    say "  扫描根: ${TMP_A_R}、${TMP_B_R}"
  fi
  G3_LIST=()
  for _root in "${TMP_ROOTS[@]}"; do
    while IFS= read -r -d '' p; do
      case "${p##*/}" in
        dsh-codepunk*|probe-*|patch-*|$ROUND_PAT*) G3_LIST+=( "$p" ) ;;
      esac
    done < <(find "${_root}" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
  done
  # 归属收窄（契约 §一.3）：FAIL 集合**只**含本契约命名空间（`dsh-codepunk-` 前缀）。宿主临时根顶层
  #   常有他人/历史条目，与「本仓库越界」同形 ⇒ 归因错误（红项不可行动）；这类降级 INFO，不改退出码。
  G3_NS=(); G3_FOREIGN=()
  for p in ${G3_LIST[@]+"${G3_LIST[@]}"}; do
    case "${p##*/}" in
      dsh-codepunk-*) G3_NS+=( "$p" ) ;;
      *)              G3_FOREIGN+=( "$p" ) ;;
    esac
  done
  G3_NS_N=${#G3_NS[@]}
  G3_FOREIGN_N=${#G3_FOREIGN[@]}
  split_exempt ${G3_NS[@]+"${G3_NS[@]}"}
  G3_N=${#G_VIOL[@]}
  G3_EXE=(${G_EXE[@]+"${G_EXE[@]}"})
  if [ "${G3_N}" -gt 0 ]; then
    fail "✗ G3 临时目录残留：$(hits_line "${G3_N}" ${G_VIOL[@]+"${G_VIOL[@]}"})"
    fail "  处置：用毕即删（契约要求临时产物不留裸文件）。"
  elif [ "${G3_NS_N}" -gt 0 ]; then
    say "  ✓ G3 临时目录残留：无越界（本契约命名空间命中 ${G3_NS_N} 处，均已按豁免登记降级）"
  else
    say "  ✓ G3 临时目录残留：无（本契约命名空间 dsh-codepunk-* 在扫描根顶层 0 处）"
  fi
  [ "${#G3_EXE[@]}" -gt 0 ] && emit_exempt "${G3_EXE[@]}"
  if [ "${G3_FOREIGN_N}" -gt 0 ]; then
    for p in "${G3_FOREIGN[@]}"; do
      say "  ℹ G3 归属不明（非本契约命名空间，不改判）：${p}（如属本工程请清理或登记 --exempt-from）"
    done
    say "  ℹ G3 归属不明条目 ${G3_FOREIGN_N} 条（不影响判定）"
  fi
fi

# ── 汇总 ──────────────────────────────────────────────────────────────────
echo
if [ "${FAIL}" -eq 0 ]; then
  printf '==== 写盘纪律门：通过（exit 0）====\n'
  exit 0
fi
printf '==== 写盘纪律门：发现越界（exit 1，按契约清理后重跑）====\n'
exit 1

#!/usr/bin/env bash
#
# dsh-codepunk-link.sh — 项目↔总库记忆关联解析器
#
# 退出码: 0=成功; 1=业务失败（未注册、目录不存在、ID 重复、INDEX 结构或语义非法）; 2=用法/环境错误（未知子命令、缺参数）
#
# 用法：
#   dsh-codepunk-link resolve <项目路径>   三态路由：
#                                   ① README frontmatter `dsh-codepunk: <id>` 命中（主通道）
#                                   ② 回退 ~/.dsh-codepunk/INDEX.yaml 注册表（project_root 精确匹配）
#                                   ③ 都无 → stderr 明确「未注册」exit 1
#   dsh-codepunk-link index               校验 INDEX.yaml：条目字段齐 + project_root/dsh-codepunk_path 无空悬
#   dsh-codepunk-link register [-y] <项目路径> <id>
#                                   追加注册条目（不覆盖既有 project_id/project_root，
#                                   需交互确认，-y 跳过；INDEX 缺失时按 hub 骨架初始化）
#   dsh-codepunk-link --help              用法
#
# 环境变量：
#   DSH_CODEPUNK_HOME   总库根（默认 ~/.dsh-codepunk；若 hub 已产出 scripts/dsh-codepunk-home.sh 则 source 复用其常量）
#   DSH_CODEPUNK_INDEX  INDEX.yaml 路径（默认 $DSH_CODEPUNK_HOME/INDEX.yaml；测试可覆盖，不污染真实注册表）
#
# 冲突规则：README 标记与 INDEX 不一致时以 INDEX 为准（product.md E 点）；
#           不回写/不批量改写任何项目 README（禁区）。
# 解析实现：frontmatter 段优先 python3（有 PyYAML 用 yaml 解析，无则行级正则），
#           不可用时降级 awk；INDEX 为平坦 YAML 子集，awk 行解析足够，字段名做
#           骨架别名探测（project_root|repo_path、dsh-codepunk_path 可选）。register
#           写入前备份 INDEX.yaml，追加不覆盖。
#
# exit code: 0 成功；1 业务失败（未注册 / 校验有 FAIL / INDEX 未初始化 / 重复注册）；2 用法错误。

set -u

_EG="$(dirname "${BASH_SOURCE[0]:-$0}")/env-guard.sh"; [ -r "$_EG" ] || { echo "✗ 缺 ${_EG}（无法核验）" >&2; exit 2; }; . "$_EG"  # F195/F197+F421 守卫库

SCRIPT_NAME="dsh-codepunk-link"

# ---- 初始化：DSH_CODEPUNK_HOME / DSH_CODEPUNK_INDEX ----
# 外部显式环境变量优先（测试覆写刚需），其次 hub 的 dsh-codepunk-home.sh 常量，最后默认值。
# 注：hub 文件无条件 export DSH_CODEPUNK_INDEX（与其自身「允许测试覆写」注释矛盾，
#     缺陷见早期 handoff known_issues），故 source 后恢复外部显式值。
_DSH_CODEPUNK_HOME_EXT="${DSH_CODEPUNK_HOME:-}"
_DSH_CODEPUNK_INDEX_EXT="${DSH_CODEPUNK_INDEX:-}"
_resolve_dsh-codepunk_home() {
  local home="${DSH_CODEPUNK_HOME:-$HOME/.dsh-codepunk}"
  # hub 产出 dsh-codepunk-home.sh 落位 ~/.dsh-codepunk/ 根；scripts/ 子目录为兼容探测
  if [ -f "$home/dsh-codepunk-home.sh" ]; then
    # shellcheck disable=SC1091
    . "$home/dsh-codepunk-home.sh"
  elif [ -f "$home/scripts/dsh-codepunk-home.sh" ]; then
    # shellcheck disable=SC1091
    . "$home/scripts/dsh-codepunk-home.sh"
  fi
  printf '%s' "${DSH_CODEPUNK_HOME:-$home}"
}
DSH_CODEPUNK_HOME="$(_resolve_dsh-codepunk_home)"
[ -n "$_DSH_CODEPUNK_HOME_EXT" ] && DSH_CODEPUNK_HOME="$_DSH_CODEPUNK_HOME_EXT"
DSH_CODEPUNK_INDEX="${DSH_CODEPUNK_INDEX:-$DSH_CODEPUNK_HOME/INDEX.yaml}"
[ -n "$_DSH_CODEPUNK_INDEX_EXT" ] && DSH_CODEPUNK_INDEX="$_DSH_CODEPUNK_INDEX_EXT"

# ---- js-yaml 解析路径（F352） ----
# 与 preset-declare / verify-battery 同候选链：cwd 式 `require("js-yaml")` 会漏掉**文档化**的安装位置
# （$DSH_CODEPUNK_TOOLS → ~/.dsh-codepunk/tools → ${DSH_APP_ROOT}），使「按文档装好 js-yaml」的主机
# 仍降级为「未做解析核验」。成功时打印 js-yaml 包目录，失败返回 1。
_jy_dir() {
  local cand
  for cand in "${DSH_CODEPUNK_TOOLS:-}" "${HOME:-}/.dsh-codepunk/tools" "${DSH_APP_ROOT:-}" \
              "${DSH_ASAR:+$(dirname "${DSH_ASAR}")}" "${DSH_ASAR:+$(dirname "${DSH_ASAR}")/app}"; do
    [ -n "$cand" ] && [ -d "$cand/node_modules/js-yaml" ] && { printf '%s\n' "$cand/node_modules/js-yaml"; return 0; }
  done
  return 1
}

# ---- 路径规范化 ----
_norm_path() {
  local p="$1"
  case "$p" in
    "~"|"~/"*) p="$HOME${p#\~}" ;;
  esac
  # 转绝对路径
  case "$p" in
    /*) ;;
    *) p="$(pwd)/$p" ;;
  esac
  # 去掉尾部斜杠（根目录除外）
  while [ "$p" != "/" ] && [ "${p%/}" != "$p" ]; do p="${p%/}"; done
  # F270（独立复核所报，medium）：旧实现**只**做「拼 pwd + 去尾斜杠」，不折叠 `.` / `..` / 重复斜杠
  #   ⇒ `resolve ./proj`、`/x/./proj`、`/x/y/../proj`、`/x//proj` 对**同一已注册目录**误判「未注册」
  #   （假阴性），且 `register ./proj <另一 id>` 可重复登记同目录（INDEX 键写脏、记忆分裂）。
  #   ⚠ 修复选型（实测教训）：**不做 realpath/符号链接解析** —— macOS 上 `/tmp` 会解析为 `/private/tmp`，
  #   而既有注册表存的多是未解析形式 ⇒ 解析会**反向制造不一致**（对存量 hub 属回归）。故仅做
  #   **纯文本折叠**（`.` / `..` / 重复斜杠），与存量键保持同形；符号链接形态的差异留作已知残余项。
  local out="" seg
  local IFS_OLD="$IFS"; IFS='/'
  set -f
  for seg in $p; do
    case "$seg" in
      ""|".") ;;
      "..") out="${out%/*}" ;;
      *) out="$out/$seg" ;;
    esac
  done
  set +f; IFS="$IFS_OLD"
  p="${out:-/}"
  printf '%s' "$p"
}

# ---- README 主通道：frontmatter `dsh-codepunk:` 或注释行 ----
# 成功输出 project_id；无命中输出空 + exit 1
# 优先 python3（PyYAML → 行级正则），降级 awk：二者等价，双保险
# F199：标记值形状校验——python(PyYAML 缺失→正则回退)与 awk 回退都可能把**畸形 YAML 标量**
#   （如 `dsh-codepunk: [unclosed`、含空格、超长串）原样当作 project_id（实测 rc 0 + project_id="[unclosed"）。
_validate_marker() {
  case "$1" in
    *[!A-Za-z0-9._-]*|'') printf '%s: README 标记非法：%s（dsh-codepunk 值仅允许字母/数字/./_/-，≤64 字符）\n' "$SCRIPT_NAME" "$1" >&2; return 1 ;;
  esac
  [ "${#1}" -le 64 ] || { printf '%s: README 标记非法：值超长（>64 字符）\n' "$SCRIPT_NAME" >&2; return 1; }
  return 0
}

_extract_dsh-codepunk_from_readme() {
  local readme="$1" id=""
  [ -f "$readme" ] || return 1
  if codepunk_have python3; then
    id="$(python3 - "$readme" <<'PY'
import re, sys
readme = sys.argv[1]
try:
    lines = open(readme, "r", encoding="utf-8", errors="replace").read().splitlines()
except OSError:
    sys.exit(1)
prefix = None
if lines and lines[0].strip() == "---":
    for i in range(1, min(len(lines), 25)):
        if lines[i].strip() == "---":
            prefix = "\n".join(lines[1:i])
            break
try:
    import yaml  # PyYAML 可用则用
    if prefix is not None:
        try:
            data = yaml.safe_load(prefix) or {}
            if isinstance(data, dict) and data.get("dsh-codepunk"):
                print(str(data["dsh-codepunk"]).strip())
                sys.exit(0)
        except Exception:
            pass
    for ln in lines[:10]:
        m = re.search(r"<!--\s*dsh-codepunk\s*:\s*([^>]+?)\s*-->", ln)
        if m:
            print(m.group(1).strip().strip("\"'"))
            sys.exit(0)
except ImportError:
    if prefix is not None:
        for ln in prefix.splitlines():
            m = re.match(r"^\s*dsh-codepunk\s*:\s*(.+?)\s*$", ln)
            if m:
                print(m.group(1).strip().strip("\"'"))
                sys.exit(0)
    for ln in lines[:10]:
        m = re.search(r"<!--\s*dsh-codepunk\s*:\s*([^>]+?)\s*-->", ln)
        if m:
            print(m.group(1).strip().strip("\"'"))
            sys.exit(0)
sys.exit(1)
PY
)"
    if [ -n "$id" ]; then _validate_marker "$id" && { printf '%s' "$id"; return 0; }; return 1; fi
  fi
  # ② 降级 awk：YAML frontmatter（首行 ---，前 25 行内闭合，dsh-codepunk: <id>）
  id="$(awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && /^[[:space:]]*dsh-codepunk[[:space:]]*:/ {
      line = $0
      sub(/^[[:space:]]*dsh-codepunk[[:space:]]*:[[:space:]]*/, "", line)
      gsub(/["'"'"']/, "", line)
      print line; exit
    }
    NR > 25 { exit }
  ' "$readme")"
  if [ -n "$id" ]; then _validate_marker "$id" || return 1; printf '%s' "$id"; return 0; fi   # F200：两处 awk 回退（无 python3 / 注释行形态）同样校验

  # ③ 降级 awk：兼容注释行 `<!-- dsh-codepunk: <id> -->`（前 25 行内，无 frontmatter 时）
  id="$(awk '
    NR <= 25 && /<!--[[:space:]]*dsh-codepunk[[:space:]]*:/ {
      line = $0
      sub(/^.*dsh-codepunk[[:space:]]*:[[:space:]]*/, "", line)
      sub(/[[:space:]]*-->.*$/, "", line)
      gsub(/["'"'"']/, "", line)
      print line; exit
    }
  ' "$readme")"
  if [ -n "$id" ]; then _validate_marker "$id" || return 1; printf '%s' "$id"; return 0; fi   # F200：两处 awk 回退（无 python3 / 注释行形态）同样校验
  return 1
}

# ---- INDEX 解析 ----
# 输入 INDEX.yaml，输出逐条目为单行制表符分隔 key=value（k=v 顺序不保证）
# 行格式：project_id=… \t root=… \t dsh-codepunk=… \t migrated_at=… \t source=…
#   root   = project_root 优先，骨架若是 repo_path 则自动兼容（字段别名探测）
#   dsh-codepunk = dsh-codepunk_path（骨架未定义时为空，调用方自行处理）
_parse_index_entries() {
  local idx="$1"
  [ -f "$idx" ] || return 1
  awk '
    function clean(v,   f, l) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      # 只剥首尾**成对**引号：值内的引号是合法字符（如路径 /tmp/p'"'"'q），
      # 全量删除会把路径读错且不可逆（resolve/index 永久不一致）。
      if (length(v) >= 2) {
        f = substr(v, 1, 1); l = substr(v, length(v), 1)
        if (f == l && f ~ /^["'"'"']$/) v = substr(v, 2, length(v) - 2)
      }
      return v
    }
    /^[[:space:]]*-/ {
      if (entry != "") print entry
      entry = ""
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      if (line ~ /:/) {
        k = line; sub(/:.*$/, "", k); gsub(/[[:space:]]+/, "", k)
        v = line; sub(/^[^:]*:[[:space:]]*/, "", v); v = clean(v)
        entry = k "=" v
      }
      next
    }
    /:/ {
      k = $1; gsub(/[[:space:]]*:$/, "", k)
      v = substr($0, index($0, ":") + 1); v = clean(v)
      if (entry != "") entry = entry "\t" k "=" v
    }
    END { if (entry != "") print entry }
  ' "$idx"
}

# 条目行 → 提取指定 key 的值（root 别名：root 兼容 project_root|repo_path；dsh-codepunk 兼容 dsh-codepunk_path）
_entry_get() {
  local row="$1" key="$2" got=""
  if [ "$key" = "root" ]; then
    got="$(printf '%s\n' "$row" | tr '\t' '\n' | sed -n 's/^project_root=//p' | head -1)"
    [ -n "$got" ] || got="$(printf '%s\n' "$row" | tr '\t' '\n' | sed -n 's/^repo_path=//p' | head -1)"
    printf '%s' "$got"
    return 0
  fi
  if [ "$key" = "dsh-codepunk_path" ] || [ "$key" = "dsh_codepunk_path" ] || [ "$key" = "dsh-codepunk" ]; then
    got="$(printf '%s\n' "$row" | tr '\t' '\n' | sed -n 's/^dsh_codepunk_path=//p' | head -1)"
    [ -n "$got" ] || got="$(printf '%s\n' "$row" | tr '\t' '\n' | sed -n 's/^dsh-codepunk_path=//p' | head -1)"
    [ -n "$got" ] || got="$(printf '%s\n' "$row" | tr '\t' '\n' | sed -n 's/^dsh-codepunk=//p' | head -1)"
    printf '%s' "$got"
    return 0
  fi
  printf '%s\n' "$row" | tr '\t' '\n' | sed -n "s/^$key=//p" | head -1
}

# INDEX 查询 helpers（TSV 行集 → 单值/整行）
# F273（F270 残余项）：**仅比较用**的实体路径求值。刻意**不**改写存储值 —— 存量 INDEX 的 project_root
#   可能是 /tmp/... 或 /private/tmp/...（macOS 下 /tmp 为符号链接）任一写法，改写会造成与旧记录错位。
_real_path() {
  local p="$1" r=""
  if command -v realpath >/dev/null 2>&1; then r="$(realpath "$p" 2>/dev/null)" || r=""; fi
  if [ -z "$r" ] && command -v python3 >/dev/null 2>&1; then
    r="$(python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$p" 2>/dev/null)" || r=""
  fi
  if [ -n "$r" ]; then printf '%s' "$r"; else _norm_path "$p"; fi
}

_index_id_by_root() {  # 按 project_root(/repo_path 别名) 精确匹配 → project_id
  local want="$1"
  _parse_index_entries "$DSH_CODEPUNK_INDEX" | awk -v want="$want" -F '\t' '
    { root = ""; pid = ""
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^project_root=/) { root = $i; sub(/^project_root=/, "", root) }
        if ($i ~ /^repo_path=/) { r2 = $i; sub(/^repo_path=/, "", r2); if (root == "") root = r2 }
        if ($i ~ /^project_id=/) { pid = $i; sub(/^project_id=/, "", pid) } }
      if (root == want) print pid }
  ' | head -1
}
# F273：实体形兜底匹配 —— 折叠形未命中时，比较双方 realpath（仅内存比较，不写盘）。
_index_id_by_root_real() {
  local want rroot
  want="$(_real_path "$1")"
  _parse_index_entries "$DSH_CODEPUNK_INDEX" | while IFS= read -r row; do
    rroot="$(_entry_get "$row" project_root)"
    [ -n "$rroot" ] || rroot="$(_entry_get "$row" repo_path)"
    [ -n "$rroot" ] || continue
    if [ "$(_real_path "$rroot")" = "$want" ]; then _entry_get "$row" project_id; break; fi
  done
}

_index_row_by_id() {  # 按 project_id 匹配 → 整行 TSV
  local want="$1"
  _parse_index_entries "$DSH_CODEPUNK_INDEX" | awk -v want="$want" -F '\t' '
    { pid = ""
      for (i = 1; i <= NF; i++) if ($i ~ /^project_id=/) { pid = $i; sub(/^project_id=/, "", pid) }
      if (pid == want) print $0 }
  ' | head -1
}

_index_dsh-codepunk_by_id() {  # 按 project_id 匹配 → dsh-codepunk_path（一条条目只输出一次）
  local want="$1"
  _parse_index_entries "$DSH_CODEPUNK_INDEX" | awk -v want="$want" -F '\t' '
    { pid = ""; pc = ""
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^project_id=/) { pid = $i; sub(/^project_id=/, "", pid) }
        if ($i ~ /^dsh-codepunk_path=/) { pc = $i; sub(/^dsh-codepunk_path=/, "", pc) } }
      if (pid == want && pc != "") print pc }
  ' | head -1
}

# ---- resolve ----
cmd_resolve() {
  [ $# -ge 1 ] || { printf '用法: %s resolve <项目路径>\n' "$SCRIPT_NAME" >&2; return 2; }
  local target id
  target="$(_norm_path "$1")"
  [ -d "$target" ] || { printf '%s: 目录不存在: %s\n' "$SCRIPT_NAME" "$target" >&2; return 1; }

  local readme="$target/README.md"
  id="$(_extract_dsh-codepunk_from_readme "$readme")"

  if [ -n "$id" ]; then
    # ①-a 先按路径精确匹配 INDEX（冲突规则：README 标记 vs INDEX 不一致 → 以 INDEX 为准，product E）
    local pid_p dcp_p
    pid_p="$(_index_id_by_root "$target")"
    if [ -n "$pid_p" ]; then
      if [ "$pid_p" != "$id" ]; then
        printf '%s: 冲突：README 标记 dsh-codepunk: %s 与 INDEX project_id=%s 不一致，以 INDEX 为准（不回写 README）\n' "$SCRIPT_NAME" "$id" "$pid_p" >&2
      fi
      dcp_p="$(_index_dsh-codepunk_by_id "$pid_p")"
      [ -n "$dcp_p" ] || dcp_p="$DSH_CODEPUNK_HOME/projects/$pid_p"
      printf 'project_id=%s\ndsh-codepunk_path=%s\n' "$pid_p" "$dcp_p"
      return 0
    fi
    # ①-b 再按标记 id 匹配（同 id 不同路径：worktree / 别名场景）
    local row_bid root_bid dcp_bid
    row_bid="$(_index_row_by_id "$id")"
    if [ -n "$row_bid" ]; then
      root_bid="$(_entry_get "$row_bid" root)"
      dcp_bid="$(_entry_get "$row_bid" dsh_codepunk_path)"
      if [ -n "$root_bid" ] && [ "$(_norm_path "$root_bid")" != "$target" ]; then
        printf '%s: 提示：%s 的 INDEX project_root=%s 与输入路径不同，按 INDEX 关联输出\n' "$SCRIPT_NAME" "$id" "$root_bid" >&2
      fi
      [ -n "$dcp_bid" ] || dcp_bid="$DSH_CODEPUNK_HOME/projects/$id"
      printf 'project_id=%s\ndsh-codepunk_path=%s\n' "$id" "$dcp_bid"
      return 0
    fi
    # ①-c 标记已识别但 INDEX 未登记：pre-register 推算（B 点 projects/<id>/）
    printf '%s: project_id=%s 未在 INDEX 登记，总库路径为推算值（可用 register 正式登记）\n' "$SCRIPT_NAME" "$id" >&2
    printf 'project_id=%s\ndsh-codepunk_path=%s\n' "$id" "$DSH_CODEPUNK_HOME/projects/$id"
    return 0
  fi

  # ② 无标记：回退 INDEX 按 project_root 精确匹配
  local pid2 dcp2
  pid2="$(_index_id_by_root "$target")"
  # F273：折叠形未命中时按【实体形】兜底（覆盖 macOS /tmp ↔ /private/tmp 等符号链接写法差异）
  [ -n "$pid2" ] || pid2="$(_index_id_by_root_real "$target")"
  if [ -n "$pid2" ]; then
    dcp2="$(_index_dsh-codepunk_by_id "$pid2")"
    [ -n "$dcp2" ] || dcp2="$DSH_CODEPUNK_HOME/projects/$pid2"
    printf 'project_id=%s\ndsh-codepunk_path=%s\n' "$pid2" "$dcp2"
    return 0
  fi

  # ③ 未注册
  printf '%s: 未注册：%s（README 无 dsh-codepunk 标记，INDEX 无匹配条目）\n' "$SCRIPT_NAME" "$target" >&2
  return 1
}

# ---- index：校验无空悬 + 字段齐 ----
cmd_index() {
  if [ ! -f "$DSH_CODEPUNK_INDEX" ]; then
    printf '%s: INDEX 未初始化：%s 不存在\n' "$SCRIPT_NAME" "$DSH_CODEPUNK_INDEX" >&2
    return 1
  fi
  # ① 结构核验（无依赖）：顶层只允许 schema_version / projects / last_updated。
  #   顶格的块序列项（`- project_id: …`）是 **合法 YAML**——`projects:` 的序列允许与键同列，
  #   迁移/早期写入器产出的 INDEX 即为该形态（实测：真实总库 24 条目顶格，source: migration-report）。
  #   旧实现把这类行一律当「未知顶层键」⇒ index/register 全部 rc=1 并建议「从备份恢复」，
  #   而文件本身可被 YAML 解析器正常读取（误导性建议 + 整条登记链失效）。
  local stray
  stray="$(grep -nE '^[^ \t#]' "$DSH_CODEPUNK_INDEX" 2>/dev/null \
           | grep -vE '^[0-9]+:(schema_version|projects|last_updated):|^[0-9]+:(---|\.\.\.)$|^[0-9]+:- ' | head -3)"
  if [ -n "$stray" ]; then
    printf '%s: INDEX 结构非法（未知顶层键）：%s\n' "$SCRIPT_NAME" "$(printf '%s' "$stray" | tr '\n' ' ')" >&2
    printf '%s: 合法顶层键仅 schema_version / projects / last_updated（projects 下的序列项可顶格写作「- 」）；请修复或从备份恢复\n' "$SCRIPT_NAME" >&2
    return 1
  fi
  # ② 解析核验（与 preset-audit 同链：ruby 优先、node+js-yaml 回退）；损坏文件 MUST 报错而非当空表
  # 跨版本可移植（Psych 4/5 = ruby ≥ 3.1，Ubuntu 24.04 自带 3.2）：`YAML.load_file` 已改为
  #   safe_load，INDEX 里未加引号的 `last_updated` 时间戳会被判为「未许可的 Time」并抛
  #   Psych::DisallowedClass ⇒ 本核验在 Linux 上恒失败（macOS 的 Psych 3.1 走 unsafe_load，故不暴露）。
  #   修法：先带 permitted_classes: [Time]，Psych 3 不认该关键字（ArgumentError）时回退旧调用——
  #   与 agent.cordis.yml 锚点的 aliases 修法同构，macOS 行为不变。
  local parse_rc=0 parser=""
  if codepunk_have ruby; then
    parser="ruby"
    ruby -ryaml -e 'begin; YAML.load_file(ARGV[0], permitted_classes: [Time], aliases: true); rescue ArgumentError; YAML.load_file(ARGV[0]); rescue => e; warn e.message; exit 1; end' \
      "$DSH_CODEPUNK_INDEX" >/dev/null 2>&1 || parse_rc=1
  elif codepunk_have node && _JY="$(_jy_dir)" && [ -n "$_JY" ]; then
    parser="node"
    node -e 'const y=require(process.argv[1]),fs=require("fs");try{y.load(fs.readFileSync(process.argv[2],"utf8"))}catch(e){console.error(e.message);process.exit(1)}' \
      "$_JY" "$DSH_CODEPUNK_INDEX" >/dev/null 2>&1 || parse_rc=1
  else
    printf '%s: ⚠ 未做解析核验（无 ruby/node+js-yaml）——仅完成结构核验\n' "$SCRIPT_NAME" >&2
  fi
  if [ "$parse_rc" != 0 ]; then
    printf '%s: INDEX 解析失败（文件已损坏，非空骨架）：%s\n' "$SCRIPT_NAME" "$DSH_CODEPUNK_INDEX" >&2
    printf '%s: 请从备份恢复（register 写入前会留 INDEX.yaml.bak）或按骨架重建\n' "$SCRIPT_NAME" >&2
    return 1
  fi
  # ③ 语义/类型核验（F129）：结构与解析都通过、但类型非法的文件（如 projects 为标量）此前被当作
  #    空骨架放行，随后 register 会据错模型覆盖注册表 → 真实登记项丢失。此处按同一解析链核验类型。
  local sem_rc=0 sem_msg=""
  if codepunk_have ruby; then
    sem_msg="$(ruby -Ku -ryaml -e '   # -Ku：本片段含中文字面量，须显式声明 -e 源编码为 UTF-8（C/POSIX locale 下默认 US-ASCII 会编译失败）
      begin; d = YAML.load_file(ARGV[0], permitted_classes: [Time], aliases: true); rescue ArgumentError; d = YAML.load_file(ARGV[0]); end   # Psych 4/5 见 ② 的说明
      d = {} if d.nil?
      fail "顶层须为映射" unless d.is_a?(Hash)
      fail "schema_version 须为标量" if d.key?("schema_version") && d["schema_version"].is_a?(Hash)
      proj = d["projects"]
      fail "projects 须为映射或条目序列（当前 #{proj.class}）" unless proj.nil? || proj.is_a?(Hash) || proj.is_a?(Array)
      (proj.is_a?(Array) ? proj : (proj || {}).values).each { |v| fail "projects 条目须为映射（当前 #{v.class}）" unless v.nil? || v.is_a?(Hash) }
      lt = d["last_updated"]
      fail "last_updated 须为标量" if lt.is_a?(Hash) || lt.is_a?(Array)
    ' "$DSH_CODEPUNK_INDEX" 2>&1)" || sem_rc=1
  elif codepunk_have node && _JY="$(_jy_dir)" && [ -n "$_JY" ]; then
    sem_msg="$(node -e '
      const y=require(process.argv[1]),fs=require("fs");
      let d; try { d = y.load(fs.readFileSync(process.argv[2],"utf8")) || {}; } catch(e){ console.log(e.message); process.exit(1); }
      // F353：与 ruby 路径语义对齐——js-yaml 默认 schema 把 `last_updated: 2026-10-07T…` 解析成
      //   **Date 对象**，而 ruby 的 Psych 同样给 Time；ruby 侧判据是 `is_a?(Hash)/is_a?(Array)`
      //   ⇒ Time 属**标量**。node 侧若用 `typeof === "object"` 会把 Date 误判为「非标量」，
      //   在真实 INDEX 上产生假红（实测「INDEX 语义非法：last_updated 须为标量」）。
      //   同时按 ruby 口径校准三处边界：projects 允许 null；last_updated 数组亦非法；
      //   条目值须为映射（nil 允许）。
      const isPlain=(o)=>o!==null&&typeof o==="object"&&!Array.isArray(o)&&!(o instanceof Date);
      const isMapOrArr=(o)=>isPlain(o)||Array.isArray(o);
      const bad=(m)=>{console.log(m);process.exit(1);};
      if (typeof d!=="object"||Array.isArray(d)||d instanceof Date) bad("顶层须为映射");
      if (d.schema_version!==undefined && isPlain(d.schema_version)) bad("schema_version 须为标量");
      if (d.projects!==undefined && d.projects!==null && !isMapOrArr(d.projects)) bad("projects 须为映射或条目序列");
      if (d.projects!==undefined && d.projects!==null) for (const k of Object.keys(d.projects)) { const v=d.projects[k]; if (v!==null && !isPlain(v)) bad("projects["+k+"] 须为映射"); }
      if (d.last_updated!==undefined && isMapOrArr(d.last_updated)) bad("last_updated 须为标量");
    ' "$_JY" "$DSH_CODEPUNK_INDEX" 2>&1)" || sem_rc=1
  else
    printf '%s: ⚠ 未做语义核验（无 ruby/node+js-yaml）\n' "$SCRIPT_NAME" >&2
  fi
  if [ "$sem_rc" != 0 ]; then
    printf '%s: INDEX 语义非法：%s\n' "$SCRIPT_NAME" \
      "$(printf '%s' "$sem_msg" | head -1 | sed -E "s/.*<main>': //; s/\s*\((RuntimeError|Error)\)$//")" >&2
    printf '%s: 请勿据其写入（register 会覆盖注册表）；从 INDEX.yaml.bak 恢复或按骨架重建\n' "$SCRIPT_NAME" >&2
    return 1
  fi
  local rows n_ok n_fail
  rows="$(_parse_index_entries "$DSH_CODEPUNK_INDEX")"
  if [ -z "$rows" ]; then
    # 空数组 = 合法骨架态（register 填充前），已过结构与解析核验
    # F271（独立复核所报，low-中）：**无注释头**的「合法但空」INDEX（被截断为 `schema_version: 1` +
    #   `projects: []`，或运维手写骨架）与**真正的空注册表**在文件层**不可区分** ⇒ 旧实现只打印
    #   「校验通过：0 条（骨架态）」，读者可能把「条目已丢失」当成正常空表而继续操作（静默）。此处
    #   保留 rc（合法 YAML 的空表仍是合法输入），但**显式告警 + 给出备份线索**，消除静默。
    printf '%s: 校验通过：0 条（注册表为空，骨架态；结构+解析已核验）\n' "$SCRIPT_NAME"
    printf '%s: ⚠ 空注册表与「条目已丢失 / 被截断 / 被手写覆盖」在文件层不可区分；若此前登记过项目，请先核对备份（%s*.bak*）再继续\n' \
      "$SCRIPT_NAME" "$DSH_CODEPUNK_INDEX"
    return 0
  fi
  n_ok=0; n_fail=0
  printf '%s: 校验 %s\n' "$SCRIPT_NAME" "$DSH_CODEPUNK_INDEX"
  local row pid root dcp
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    pid="$(_entry_get "$row" project_id)"
    root="$(_entry_get "$row" project_root)"
    dcp="$(_entry_get "$row" dsh_codepunk_path)"
    local problems=""
    # 必填校验（run-lead 裁决标准 5 字段）：project_id / project_root / dsh-codepunk_path 必须有值；
    # migrated_at / source 字段必须存在（migrated_at 可为 null——未迁移项目合法，骨架注释允许）
    [ -n "$pid" ]  || problems="${problems}缺project_id;"
    [ -n "$root" ] || problems="${problems}缺project_root;"
    if ! printf '%s\n' "$row" | tr '\t' '\n' | grep -q '^migrated_at='; then
      problems="${problems}缺migrated_at字段;"
    fi
    if ! printf '%s\n' "$row" | tr '\t' '\n' | grep -q '^source='; then
      problems="${problems}缺source字段;"
    fi
    [ -n "$dcp" ] || problems="${problems}缺dsh-codepunk_path;"
    if [ -n "$root" ] && [ ! -d "$(_norm_path "$root")" ]; then
      problems="${problems}project_root空悬($root);"
    fi
    if [ -n "$dcp" ] && [ ! -e "$(_norm_path "$dcp")" ]; then
      problems="${problems}dsh-codepunk_path空悬($dcp);"
    fi
    if [ -n "$problems" ]; then
      printf '  [FAIL] %s: %s\n' "${pid:-<无id>}" "$problems"
      n_fail=$((n_fail + 1))
    else
      printf '  [ok]   %s: root=%s dsh-codepunk=%s\n' "$pid" "$root" "$dcp"
      n_ok=$((n_ok + 1))
    fi
  done <<< "$rows"
  printf 'summary: %d ok, %d fail\n' "$n_ok" "$n_fail"
  [ "$n_fail" -eq 0 ]
}

# ---- register：追加注册条目（不覆盖，需确认） ----
# 回滚助手：回滚成功才清理备份；回滚失败必须显式报出并保留备份供人工恢复
# （原实现无论 cp 成败都打印「已回滚」，且 rm 漏掉时间戳备份 → 假保证 + 残留）
_rollback() { # $1=备份路径  $2=失败原因
  local bak="$1" why="$2"
  if cp "$bak" "$DSH_CODEPUNK_INDEX" 2>/dev/null; then
    printf '%s: %s，已回滚到写入前状态\n' "$SCRIPT_NAME" "$why" >&2
    rm -f "$DSH_CODEPUNK_INDEX.bak" "$bak"
  else
    printf '%s: %s，且**回滚失败**\n' "$SCRIPT_NAME" "$why" >&2
    printf '%s: 请手工恢复——备份保留在 %s\n' "$SCRIPT_NAME" "$bak" >&2
    rm -f "$DSH_CODEPUNK_INDEX.bak"
  fi
}

cmd_register() {
  local yes=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -y|--yes) yes=1; shift ;;
      *) break ;;
    esac
  done
  [ $# -eq 2 ] || { printf '用法: %s register [-y] <项目路径> <id>\n' "$SCRIPT_NAME" >&2; return 2; }
  local target id
  target="$(_norm_path "$1")"
  [ -d "$target" ] || { printf '%s: 目录不存在: %s\n' "$SCRIPT_NAME" "$target" >&2; return 1; }
  id="$2"
  if ! printf '%s' "$id" | grep -qE '^[A-Za-z0-9._-]+$'; then
    printf '%s: 非法 project_id: %s（仅允许字母数字 . _ -）\n' "$SCRIPT_NAME" "$id" >&2
    return 2
  fi

  # INDEX 缺失 → 按总库骨架初始化（幂等，不触碰 config.yaml）
  if [ ! -f "$DSH_CODEPUNK_INDEX" ]; then
    mkdir -p "$(dirname "$DSH_CODEPUNK_INDEX")"
    # F272（独立复核所报，low）：旧实现未检查 `cat >` 的退出码即**无条件**打印「已按骨架创建」⇒
    #   在总库只读/目录不可写时先冒裸 shell 报错（`cat: …: Permission denied`），紧跟一句**与事实相反**
    #   的成功宣告。此处改为：失败即给出可读诊断并以 2 退出，成功才宣告。
    # F360（本轮巡检实测）：本处骨架**须与 plans/dsh-codepunk-init.sh 的骨架逐字节一致**——
    #   旧实现只有 1 行头注释，而 init 的骨架是 11 行注释块，且 init 见 INDEX 已存在即跳过
    #   ⇒ 终态注释头取决于「谁先建文件」（顺序① init→register 保留 11 行头；顺序② register→init
    #   只有 1 行头）。机械判据见 plans/doc-consistency.sh 第 25 类（两处模板须一致）。
    if cat > "$DSH_CODEPUNK_INDEX" <<'EOF'
# ======
# dsh-codepunk 统一总库 · 全局注册表 INDEX.yaml（骨架模板，init 内置）
# 字段（规范名以 dsh-codepunk-link 校验实现为准）：project_id（slug，冲突加路径 hash）·
#   project_root（工程根绝对路径）· dsh_codepunk_path（总库托管路径，须存在）·
#   migrated_at（ISO 8601 或 null）· source（register 或历史 migration-report）
# 树形约定：projects/<project_id>/runs/<run_id>/…（= 工程内 .dsh-codepunk/ 平移）
# ======
schema_version: 1
projects: []
last_updated: null
EOF
    then
      printf '%s: INDEX 未初始化，已按骨架创建: %s\n' "$SCRIPT_NAME" "$DSH_CODEPUNK_INDEX" >&2
    else
      printf '%s: INDEX 未初始化，且**无法创建**（总库目录不可写或文件系统只读）：%s\n' "$SCRIPT_NAME" "$DSH_CODEPUNK_INDEX" >&2
      printf '%s: 请检查总库目录权限后重试——无法核验 ≠ 通过\n' "$SCRIPT_NAME" >&2
      return 2
    fi
  fi

  # 追加不覆盖：project_id 或 project_root 任一已存在即拒绝
  local rows dup=""
  rows="$(_parse_index_entries "$DSH_CODEPUNK_INDEX")"
  local row pid root
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    pid="$(_entry_get "$row" project_id)"
    root="$(_entry_get "$row" root)"
    if [ "$pid" = "$id" ]; then dup="project_id=$id"; break; fi
    # F274：查重亦须覆盖**符号链接别名**（仅比较、不改写存储值）；否则同一实体可被重复登记、记忆分裂。
    if [ -n "$root" ] && { [ "$(_norm_path "$root")" = "$target" ] || [ "$(_real_path "$root")" = "$(_real_path "$target")" ]; }; then dup="project_root=$target"; break; fi
  done <<< "$rows"
  if [ -n "$dup" ]; then
    printf '%s: 已存在，不覆盖: %s 已在 INDEX.yaml（追加语义）\n' "$SCRIPT_NAME" "$dup" >&2
    return 1
  fi

  # 确认（非 TTY 且无 -y 时拒绝，防自动化误写）
  if [ "$yes" -ne 1 ]; then
    if [ ! -t 0 ]; then
      printf '%s: stdin 非 TTY 无法交互确认；确认后请加 -y 跳过确认\n' "$SCRIPT_NAME" >&2
      return 1
    fi
    local ans
    printf '确认注册 %s ← %s 到 %s？[y/N] ' "$id" "$target" "$DSH_CODEPUNK_INDEX"
    read -r ans || ans=""
    case "$ans" in
      y|Y|yes|YES) ;;
      *) printf '%s: 已取消，未写入 INDEX.yaml\n' "$SCRIPT_NAME"; return 1 ;;
    esac
  fi

  # 先确保总库目录存在：失败即中止。此步必须早于备份与任何 INDEX 改写，
  # 否则失败路径会留下备份残留、且 INDEX 已被半改写（last_updated 已刷新、
  # `projects: []` 已归一）却无回滚。
  local hosted="$DSH_CODEPUNK_HOME/projects/$id"
  mkdir -p "$hosted" 2>/dev/null || { printf '%s: 总库目录创建失败: %s\n' "$SCRIPT_NAME" "$hosted" >&2; return 1; }

  # F244（medium）：并发 register 的**读-改-写竞态**。实测：并发两路 `register -y`（不同 id）后
  #   两进程**均报成功**，而 INDEX 中仅存其中一条（另一条静默丢失）——因临界区内「备份 → sed 改
  #   last_updated → 归一 `projects: []` → 追加空行 → python 整文件重写」各自独立读写。
  #   ⇒ 以**可移植 mkdir 自旋锁**串行化整个临界区（macOS 无 flock，故不用 flock）；上限约 10s，
  #   超时按「环境/用法错误」返回 2 并给出可操作的排除指引（锁残留须人工确认后清理）。
  DSH_LOCKDIR="$DSH_CODEPUNK_INDEX.lock"   # 必须**全局**：EXIT trap 在函数返回后仍需展开该路径；
  lk_i=0                                    # 若用 local，trap 内变量已出作用域 ⇒ rmdir 空路径 ⇒ 锁泄漏（F244 首版踩坑）
  while ! mkdir "$DSH_LOCKDIR" 2>/dev/null; do
    lk_i=$((lk_i + 1))
    if [ "$lk_i" -ge 200 ]; then
      # F260：**只读/无写权限的总库目录**同样令 mkdir 失败，而原消息只归因「另一进程正在写 / 锁残留」⇒
      #   实测（`chmod 555` 总库目录）真因为权限，指引误导运维（去查不存在的并发）。此处补一次写权限探测，
      #   按因给出可操作指引：目录不可写 ⇒ 直指权限/只读文件系统；可写 ⇒ 维持并发/残留锁口径。
      lk_parent="$(dirname "$DSH_LOCKDIR")"
      if [ ! -w "$lk_parent" ]; then
        printf '%s: 无法获取 INDEX 写锁（%s）——总库目录不可写（权限或只读文件系统）：%s\n' "$SCRIPT_NAME" "$DSH_LOCKDIR" "$lk_parent" >&2
      else
        printf '%s: 无法获取 INDEX 写锁（%s）——可能有另一 register 正在写，或锁残留；确认无并发后删除该目录再重试\n' "$SCRIPT_NAME" "$DSH_LOCKDIR" >&2
      fi
      return 2
    fi
    sleep 0.05
  done
  trap "rmdir \"$DSH_LOCKDIR\" 2>/dev/null" EXIT INT TERM   # 路径**此刻展开**（代入字面量），不依赖退出时变量存在

  # F246（low/medium）：**同键并发**时两进程各自通过上面的**锁外**存在性检查，随后在锁内各追加一条
  #   ⇒ INDEX 出现两条同 id 条目、且双方均回显「已注册」（实测 rcs=0,0、重复 2 行）。F244 的锁只挡
  #   「丢更新」，不挡「同键重复」。⇒ 取锁后以**同一判据**复检一次；命中则按既定语义「已存在，不覆盖」
  #   返回 1（锁由上面的 EXIT trap 释放）。
  local r2 pid2 root2
  while IFS= read -r r2; do
    [ -n "$r2" ] || continue
    pid2="$(_entry_get "$r2" project_id)"
    root2="$(_entry_get "$r2" root)"
    if [ "$pid2" = "$id" ]; then
      printf '%s: 已存在，不覆盖: project_id=%s 已在 INDEX.yaml（追加语义）\n' "$SCRIPT_NAME" "$id" >&2
      return 1
    fi
    if [ -n "$root2" ] && { [ "$(_norm_path "$root2")" = "$target" ] || [ "$(_real_path "$root2")" = "$(_real_path "$target")" ]; }; then  # F274
      printf '%s: 已存在，不覆盖: project_root=%s 已在 INDEX.yaml（追加语义）\n' "$SCRIPT_NAME" "$target" >&2
      return 1
    fi
  done <<< "$(_parse_index_entries "$DSH_CODEPUNK_INDEX")"

  # 写入前备份（人设：INDEX 写入先备份字段结构），追加后校验新条目
  local bak ts
  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  bak="$DSH_CODEPUNK_INDEX.bak-$(date +%Y%m%d%H%M%S)"
  cp "$DSH_CODEPUNK_INDEX" "$bak" || { printf '%s: 备份失败，中止写入\n' "$SCRIPT_NAME" >&2; return 1; }

  # ① 先刷新 last_updated（保留原结构，仅更新值）
  local lu_new="last_updated: $ts"
  if grep -q '^last_updated:' "$DSH_CODEPUNK_INDEX"; then
    sed -i.bak "s/^last_updated:.*/$lu_new/" "$DSH_CODEPUNK_INDEX"
  else
    printf '%s\n' "$lu_new" >> "$DSH_CODEPUNK_INDEX"
  fi

  # ①-b 归一空内联列表：init 骨架写 `projects: []`，其后**不能**再追加列表项
  #      （否则产出非法 YAML：`projects: []` 已声明为空列表，任何真实 YAML 解析器都会报错；
  #        工具自身靠行级解析才"能用"，属隐式缺陷）。先改为 `projects:` 再追加。
  if grep -qE '^projects:[[:space:]]*\[\][[:space:]]*$' "$DSH_CODEPUNK_INDEX"; then
    tmpf="$(mktemp)"
    # F359（本轮巡检实测）：macOS `mktemp` 建文件即 0600，`mv` 覆盖后把 INDEX.yaml 从 init
    #   建库的 644 **降为 600** ⇒ 同一输入、两种顺序（init→register vs register→init）终态
    #   权限不同（「同输入终态一致」判据被推翻）。写回前记录原 mode，`mv` 后按原 mode 复位；
    #   不可用 `chmod --reference`（BSD chmod 无该选项）。
    idx_mode="$(stat -f '%Lp' "$DSH_CODEPUNK_INDEX" 2>/dev/null || stat -c '%a' "$DSH_CODEPUNK_INDEX" 2>/dev/null || echo 644)"
    # F257：`sed` 或 `mv` 失败（如 INDEX 不可写/受限文件系统）时该临时文件会**残留**在 $TMPDIR
    #   （实测失败路径每次泄漏 1 个；成功路径 tmpf 已被 mv 消耗 ⇒ rm 为安全空操作）。
    #   统一在此清理，与全仓 cleanup 口径（trap/显式 rm）一致。
    if sed 's/^projects:[[:space:]]*\[\][[:space:]]*$/projects:/' "$DSH_CODEPUNK_INDEX" > "$tmpf"; then
      mv "$tmpf" "$DSH_CODEPUNK_INDEX" || { rm -f "$tmpf"; return 1; }
      chmod "$idx_mode" "$DSH_CODEPUNK_INDEX" 2>/dev/null || true
    else
      rm -f "$tmpf"
    fi
  fi

  # ② 追加条目（先确保文件末尾有换行，防与末行粘行）
  [ -n "$(tail -c1 "$DSH_CODEPUNK_INDEX" 2>/dev/null)" ] && printf '\n' >> "$DSH_CODEPUNK_INDEX"
  local line
  # 列表缩进风格自适应（F346）：INDEX 可能由迁移/早期写入器产出**顶格**序列项
  #   （`projects:` 与 `- project_id:` 同列——合法 YAML）。追加 MUST 沿用既有风格：
  #   在顶格列表后追加「2 空格缩进」的条目会使其成为映射值下的嵌套序列 ⇒ 真实解析器
  #   报非法 YAML（实测：真总库 24 条目顶格 ⇒ register 每次「写入后校验失败
  #   （INDEX 非法 YAML）」并回滚，登记功能整体失效）。无既有条目时沿用骨架的 2 空格。
  local IND="  " _ind_first
  if grep -qE '^-[[:space:]]*project_id:' "$DSH_CODEPUNK_INDEX" 2>/dev/null; then
    IND=""
  elif grep -qE '^[[:space:]]+-[[:space:]]*project_id:' "$DSH_CODEPUNK_INDEX" 2>/dev/null; then
    _ind_first="$(grep -m1 -E '^[[:space:]]+-[[:space:]]*project_id:' "$DSH_CODEPUNK_INDEX" | sed 's/-.*$//')"
    [ -n "$_ind_first" ] && IND="$_ind_first"
  fi
  # 注：run-lead 裁决（字段冲突）——INDEX 条目标准 5 字段：
  #     project_id / project_root / dsh_codepunk_path / migrated_at / source；
  #     骨架扩展字段 repo_path/readme_marker/status 由 run-lead 合并时统一修订，register 不写；
  #     dsh_codepunk_path = 总库托管路径（D072）。2026-09-05 修正：原「默认 = project_root」
  #     会让 resolve 把工程目录当总库、把运行状态写进工程造成污染，现改为总库真实路径。
  line="${IND}- project_id: $id
${IND}  project_root: $target
${IND}  dsh_codepunk_path: $hosted
${IND}  migrated_at: null
${IND}  source: register"
  # 失败时只回显异常末行（错误类型 + errno），避免整段 traceback 淹没真正的失败原因；
  # 需要完整回溯时设 DSH_CODEPUNK_DEBUG=1。
  PYERR="$(mktemp)"
  if ! python3 - "$DSH_CODEPUNK_INDEX" "$line" 2>"$PYERR" <<'PYEOF'
import sys, re
f, line = sys.argv[1], sys.argv[2]
lines = open(f, encoding='utf-8').read().split('\n')
# 结构守卫：projects 键之后只允许出现「缩进的条目行」「顶格的序列项」或 last_updated——
# 其它顶层键若夹在列表中，先前的「就地插在 last_updated 之前」写法会把条目
# 落到列表之外，产出非法 YAML（实测事故：INDEX 曾因此损坏，真实解析器拒读）。
# 顶格序列项（`- project_id: …`）属合法 YAML（迁移/早期写入器形态，见 cmd_index ①），
# 旧实现把它当未知顶层键 ⇒ register 在真实总库上直接失败。
lu = [l for l in lines if re.match(r'^last_updated:', l)]
stray = [
    l for l in lines
    if l.strip() and not l.startswith((' ', '\t', '#'))
    and not re.match(r'^(schema_version|projects|last_updated):', l)
    and not re.match(r'^-(\s|$)', l)
    and not re.match(r'^(---|\.\.\.)$', l)
]
if stray:
    sys.stderr.write('INDEX 含未知顶层键：' + ', '.join(stray) + '\n')
    sys.exit(1)
body = [l for l in lines if not re.match(r'^last_updated:', l)]
while body and not body[-1].strip():
    body.pop()
# 条目追加到 projects 列表末尾（即正文末尾），last_updated 恒置文件尾
body.extend(line.rstrip('\n').split('\n'))
if lu:
    body.append(lu[-1])
open(f, 'w', encoding='utf-8').write('\n'.join(body) + '\n')
PYEOF
    then
    _reason="$(tail -1 "$PYERR" 2>/dev/null)"
    [ -n "${_reason:-}" ] || _reason="未知错误"
    if [ "${DSH_CODEPUNK_DEBUG:-0}" = "1" ]; then
      printf '%s: INDEX 写入失败（完整回溯）:\n' "$SCRIPT_NAME" >&2
      cat "$PYERR" >&2
    fi
    rm -f "$PYERR"
    _rollback "$bak" "写入失败：${_reason}"
    return 1
  fi
  # 写入后校验：真实 YAML 解析器必须能读（防「行级解析自洽但 YAML 非法」长期潜伏）
  if codepunk_have ruby; then
    if ! ruby -Ku -ryaml -e '   # -Ku：本片段含中文字面量，须显式声明 -e 源编码为 UTF-8（C/POSIX locale 下默认 US-ASCII 会编译失败）
begin; d = YAML.load_file(ARGV[0], permitted_classes: [Time], aliases: true); rescue ArgumentError; d = YAML.load_file(ARGV[0]); end   # Psych 4/5 见 ② 的说明
raise "顶层非映射" unless d.is_a?(Hash)
raise "projects 非数组" unless d["projects"].is_a?(Array)
' "$DSH_CODEPUNK_INDEX" >/dev/null 2>&1; then
      _rollback "$bak" "写入后校验失败（INDEX 非法 YAML）"
      return 1
    fi
  else
    # F217：本校验注释声明「必须能读」，但旧实现仅在**有 ruby** 时执行 → 无 ruby 主机上**静默跳过**
    #   （判据消失而不告知）；与上方「无 ruby/node 时明确声明『未做解析核验』」的口径也应一致。
    printf '%s: ⚠ 写入后未做真实 YAML 解析核验（无 ruby）——已写入，建议装 ruby 后复跑 index 复验\n' "$SCRIPT_NAME" >&2
  fi
  rm -f "$PYERR" "$DSH_CODEPUNK_INDEX.bak" "$bak"
  printf '%s: 已注册 %s ← %s\n' "$SCRIPT_NAME" "$id" "$target"
  return 0
}

# ---- 主入口 ----
case "${1:-}" in
  resolve) shift; cmd_resolve "$@" ;;
  index)   shift; cmd_index "$@" ;;
  register) shift; cmd_register "$@" ;;
  --help|-h|"")
    cat <<EOF
dsh-codepunk-link — 项目↔总库记忆关联解析器

用法:
  $SCRIPT_NAME resolve <项目路径>   三态路由: README标记 → INDEX回退 → 未注册报错(exit 1)
  $SCRIPT_NAME index                校验 INDEX.yaml 条目字段齐 + 无空悬
  $SCRIPT_NAME register [-y] <项目路径> <id>   追加注册条目(不覆盖, 需确认, -y 跳过)
  $SCRIPT_NAME --help               本帮助

环境变量: DSH_CODEPUNK_HOME(默认 ~/.dsh-codepunk)  DSH_CODEPUNK_INDEX(默认 \$DSH_CODEPUNK_HOME/INDEX.yaml)
EOF
    [ "${1:-}" = "" ] && exit 2
    exit 0 ;;
  *) printf '未知子命令: %s（--help 查看用法）\n' "$1" >&2; exit 2 ;;
esac

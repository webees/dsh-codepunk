#!/usr/bin/env bash
#
# dsh-codepunk-link.sh — 项目↔总库记忆关联解析器（chunk-link · 连衡产出）
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

SCRIPT_NAME="dsh-codepunk-link"

# ---------- 初始化：DSH_CODEPUNK_HOME / DSH_CODEPUNK_INDEX ----------
# 外部显式环境变量优先（测试覆写刚需），其次 hub 的 dsh-codepunk-home.sh 常量，最后默认值。
# 注：hub 文件无条件 export DSH_CODEPUNK_INDEX（与其自身「允许测试覆写」注释矛盾，
#     缺陷见 chunk-link handoff known_issues），故 source 后恢复外部显式值。
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

# ---------- 路径规范化 ----------
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
  printf '%s' "$p"
}

# ---------- README 主通道：frontmatter `dsh-codepunk:` 或注释行 ----------
# 成功输出 project_id；无命中输出空 + exit 1
# 优先 python3（PyYAML → 行级正则），降级 awk：二者等价，双保险
_extract_dsh-codepunk_from_readme() {
  local readme="$1" id=""
  [ -f "$readme" ] || return 1
  if command -v python3 >/dev/null 2>&1; then
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
    [ -n "$id" ] && { printf '%s' "$id"; return 0; }
  fi
  # ② 降级 awk：YAML frontmatter（首行 ---，前 15 行内闭合，dsh-codepunk: <id>）
  id="$(awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && /^[[:space:]]*dsh-codepunk[[:space:]]*:/ {
      line = $0
      sub(/^[[:space:]]*dsh-codepunk[[:space:]]*:[[:space:]]*/, "", line)
      gsub(/["'"'"']/, "", line)
      print line; exit
    }
    NR > 15 { exit }
  ' "$readme")"
  [ -n "$id" ] && { printf '%s' "$id"; return 0; }

  # ③ 降级 awk：兼容注释行 `<!-- dsh-codepunk: <id> -->`（前 15 行内，无 frontmatter 时）
  id="$(awk '
    NR <= 15 && /<!--[[:space:]]*dsh-codepunk[[:space:]]*:/ {
      line = $0
      sub(/^.*dsh-codepunk[[:space:]]*:[[:space:]]*/, "", line)
      sub(/[[:space:]]*-->.*$/, "", line)
      gsub(/["'"'"']/, "", line)
      print line; exit
    }
  ' "$readme")"
  [ -n "$id" ] && { printf '%s' "$id"; return 0; }
  return 1
}

# ---------- INDEX 解析 ----------
# 输入 INDEX.yaml，输出逐条目为单行制表符分隔 key=value（k=v 顺序不保证）
# 行格式：project_id=… \t root=… \t dsh-codepunk=… \t migrated_at=… \t source=…
#   root   = project_root 优先，骨架若是 repo_path 则自动兼容（字段别名探测）
#   dsh-codepunk = dsh-codepunk_path（骨架未定义时为空，调用方自行处理）
_parse_index_entries() {
  local idx="$1"
  [ -f "$idx" ] || return 1
  awk '
    function clean(v) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      gsub(/["'"'"']/, "", v)
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
  if [ "$key" = "dsh-codepunk_path" ] || [ "$key" = "dsh-codepunk" ]; then
    got="$(printf '%s\n' "$row" | tr '\t' '\n' | sed -n 's/^dsh-codepunk_path=//p' | head -1)"
    [ -n "$got" ] || got="$(printf '%s\n' "$row" | tr '\t' '\n' | sed -n 's/^dsh-codepunk=//p' | head -1)"
    printf '%s' "$got"
    return 0
  fi
  printf '%s\n' "$row" | tr '\t' '\n' | sed -n "s/^$key=//p" | head -1
}

# INDEX 查询 helpers（TSV 行集 → 单值/整行）
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

# ---------- resolve ----------
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

# ---------- index：校验无空悬 + 字段齐 ----------
cmd_index() {
  if [ ! -f "$DSH_CODEPUNK_INDEX" ]; then
    printf '%s: INDEX 未初始化：%s 不存在\n' "$SCRIPT_NAME" "$DSH_CODEPUNK_INDEX" >&2
    return 1
  fi
  local rows n_ok n_fail
  rows="$(_parse_index_entries "$DSH_CODEPUNK_INDEX")"
  if [ -z "$rows" ]; then
    # 空数组 = 合法骨架态（register 填充前）；仅文件缺失才算未初始化
    printf '%s: 校验通过：0 条（注册表为空，骨架态）\n' "$SCRIPT_NAME"
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

# ---------- register：追加注册条目（不覆盖，需确认） ----------
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

  # INDEX 缺失 → 按 chunk-hub 骨架初始化（幂等，不触碰 config.yaml）
  if [ ! -f "$DSH_CODEPUNK_INDEX" ]; then
    mkdir -p "$(dirname "$DSH_CODEPUNK_INDEX")"
    cat > "$DSH_CODEPUNK_INDEX" <<EOF
# dsh-codepunk 全局项目索引（骨架模板，chunk-hub 约定；条目由 dsh-codepunk-link register 构建）
schema_version: 1
projects: []

last_updated: null
EOF
    printf '%s: INDEX 未初始化，已按骨架创建: %s\n' "$SCRIPT_NAME" "$DSH_CODEPUNK_INDEX" >&2
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
    if [ -n "$root" ] && [ "$(_norm_path "$root")" = "$target" ]; then dup="project_root=$target"; break; fi
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

  # ② 追加条目（先确保文件末尾有换行，防与末行粘行）
  [ -n "$(tail -c1 "$DSH_CODEPUNK_INDEX" 2>/dev/null)" ] && printf '\n' >> "$DSH_CODEPUNK_INDEX"
  local line
  # 注：run-lead 裁决（字段冲突）——INDEX 条目标准 5 字段：
  #     project_id / project_root / dsh-codepunk_path / migrated_at / source；
  #     骨架扩展字段 repo_path/readme_marker/status 由 run-lead 合并时统一修订，register 不写；
  #     dsh-codepunk_path 默认 = project_root（夹具/未迁移托管位），迁移项目由 migrate 报告回填
  line="  - project_id: $id
    project_root: $target
    dsh-codepunk_path: $target
    migrated_at: null
    source: register"
  if ! python3 - "$DSH_CODEPUNK_INDEX" "$line" <<'PYEOF'
import sys, re
f, line = sys.argv[1], sys.argv[2]
s = open(f, encoding='utf-8').read()
if not s.endswith('\n'): s += '\n'
s = re.sub(r'^(last_updated:.*)$', lambda m: line.rstrip('\n') + '\n' + m.group(1), s, count=1, flags=re.M)
open(f, 'w', encoding='utf-8').write(s)
PYEOF
    then
    printf '%s: 写入失败，已回滚（备份 %s）\n' "$SCRIPT_NAME" "$bak" >&2
    cp "$bak" "$DSH_CODEPUNK_INDEX"
    rm -f "$DSH_CODEPUNK_INDEX.bak"
    return 1
  fi
  rm -f "$DSH_CODEPUNK_INDEX.bak" "$bak"
  printf '%s: 已注册 %s ← %s\n' "$SCRIPT_NAME" "$id" "$target"
  return 0
}

# ---------- 主入口 ----------
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
#!/usr/bin/env bash
# =============================================================================
# dsh-codepunk-migrate.sh —— 项目 .dsh-codepunk → 总库一次性迁移工具
# 团队: 移星 | 实现: 挑山 (engineer@chunk-migrate)
#
# 职责（WORK_BRIEF chunk-migrate acceptance 6 条）：
#   1. --scan                      只读扫描全部 .dsh-codepunk（路径/大小/runs 数/素材量估算），不写任何目标
#   2. --migrate <src> <project_id>复制到 $DSH_CODEPUNK_HOME/projects/<id>/，
#                                  sha256 树校验（全量小文件 / 随机抽样 ≥3），
#                                  原 .dsh-codepunk 目录改名 .pre-refactor-dsh-codepunk 保留窗（可回滚）
#   3. --exclude-assets            跳过 *.ipsw / *.dmg.aea / *.dmg / >100M 素材，记录跳过清单
#   4. 幂等/断点续传               重复执行不重复复制；中断后可续（状态机 + rsync/cp 覆盖语义）
#   5. migration-report.yaml       含 project_id/源路径/迁移文件数/跳过素材清单/校验结果/保留窗路径
#   6. 全程只读源数据，不写业务代码、不改工程本体文件
#
# 配套：
#   - --rollback <project_id>      保留窗回滚（把 .pre-refactor-dsh-codepunk 还原为 .dsh-codepunk；
#                                  --restore 额外把总库内容复制回工程根）
#   - 复用 chunk-hub 的 dsh-codepunk-home.sh 常量（存在则 source，否则内置默认）
#
# 环境：bash 3.2+（macOS 自带），仅依赖 rsync（可选，无则 cp 兜底）+ shasum
# =============================================================================
set -u

# macOS APFS 默认大小写不敏感；统一 nocasematch，保证 .IPSW/.Dmg 等变体也被跳过
shopt -s nocasematch
# 固定 C locale：规避 bash 3.2 在 C.UTF-8 下「||/&& 右侧函数实参含局部变量时 unbound」bug
export LC_ALL=C

SCRIPT_NAME="dsh-codepunk-migrate.sh"
SCHEMA="migrate-report-v1"

# ---------------------------------------------------------------------------
# 常量与状态目录
# ---------------------------------------------------------------------------
# 优先复用 chunk-hub 产出的常量（hub 已落位 ~/.dsh-codepunk/dsh-codepunk-home.sh）；未产出时内置默认（总库根 = ~/.dsh-codepunk）
for _hubf in "$HOME/.dsh-codepunk/dsh-codepunk-home.sh" "$HOME/.dsh-codepunk/scripts/dsh-codepunk-home.sh"; do
  if [ -f "$_hubf" ]; then
    # shellcheck disable=SC1091
    source "$_hubf" && break
  fi
done
# DSH_CODEPUNK_HOME 允许环境变量覆盖（夹具/测试隔离用）；hub 脚本若已定义则以其为准
DSH_CODEPUNK_HOME="${DSH_CODEPUNK_HOME:-$HOME/.dsh-codepunk}"
PROJECTS_DIR="${PROJECTS_DIR:-${DSH_CODEPUNK_PROJECTS:-$DSH_CODEPUNK_HOME/projects}}"  # hub 变量 DSH_CODEPUNK_PROJECTS 优先；--dest 覆盖（夹具隔离用）
STATE_DIR="${STATE_DIR:-$PROJECTS_DIR/.migrate-state}"  # 状态目录跟随 projects 根，不写总库顶层

# --scan 默认清单（WORK_BRIEF 现场事实 9 处；目录不存在则标注 missing）
SCAN_DEFAULT_ROOTS=(
  "$HOME/.dsh-codepunk"                 # 总库根（仅标记，不迁移）
  "$HOME/Desktop/newtest"
  "$HOME/Desktop/__TEMP__/vphone"
  "$HOME/Desktop/__GITHUB__/webees@ios0day"
  "$HOME/Desktop/__TEMP__/cck.damaicn.cc"
  "$HOME/Desktop/qqtime"
  "$HOME/Desktop/研究"
  "$HOME/Desktop/__TEST__"
  "$HOME/Desktop/Downloads"
)

# 素材默认排除的项目（简报：vphone 只迁流程资产，33G 固件素材默认排除）
ASSETS_AUTO_EXCLUDE=("vphone" "__TEMP__/vphone")

# 排除规则（--exclude-assets）
ASSET_EXT_PATTERNS=("*.ipsw" "*.dmg.aea" "*.dmg" "*.app")  # *.app 见 sponsor 决策
ASSET_MIN_SIZE_BYTES=104857600   # 100M

# 全量校验阈值：文件数 ≤ 200 且总字节 ≤ 100MB → 全量；否则随机抽样 ≥ 3
FULL_VERIFY_MAX_FILES=200
FULL_VERIFY_MAX_BYTES=104857600

# ---------------------------------------------------------------------------
# 工具函数
# ---------------------------------------------------------------------------
log()  { printf '[migrate] %s\n' "$*" >&2; }
info() { printf '[migrate] %s\n' "$*"; }
die()  { printf '[migrate] 错误: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
用法:
  dsh-codepunk-migrate.sh --scan [dir ...]
     只读扫描 .dsh-codepunk：无参数 = 内置已知清单（Desktop 全量 9 处）；
     带参数 = 扫描指定目录（存在 .dsh-codepunk 则纳入；也接受直接给 .dsh-codepunk 路径）。
     输出 TSV：path / size / runs / files / asset_files / asset_size / structure。
  dsh-codepunk-migrate.sh --migrate <src> <project_id> [选项]
     <src>        工程根目录（内部找 .dsh-codepunk）或 .dsh-codepunk 目录本身
     <project_id> 目标 id，仅 [A-Za-z0-9._-]，禁止 '..'
     选项:
       --exclude-assets   跳过 *.ipsw / *.dmg.aea / *.dmg / *.app / >100M（vphone 自动启用）
       --verify-full      强制全量 sha256 校验（默认小文件全量、大文件抽样 ≥3）
       --dry-run          演练：打印将执行的动作，不实际复制/改名
       --dest <dir>       目标 projects 根（默认 ~/.dsh-codepunk/projects；夹具演练可隔离指定）
       --report-out <f>   报告输出路径（默认 $PROJECTS_DIR/.migrate-state/reports/<id>.yaml）
       -v                 详细日志
  dsh-codepunk-migrate.sh --rollback <project_id> [--dry-run] [--restore]
     回滚保留窗：把 <工程根>/.pre-refactor-dsh-codepunk 还原为 .dsh-codepunk；
     --restore 额外从 $DSH_CODEPUNK_HOME/projects/<id>/ 复制回工程根。
  dsh-codepunk-migrate.sh --help | --version
退出码: 0 成功 | 1 用法/参数错误 | 2 复制/校验失败 | 3 目标冲突（拒绝覆盖）
EOF
}

version() { printf '%s %s (移星/chunk-migrate)\n' "$SCRIPT_NAME" "$SCHEMA"; }

# 人类可读大小（K/M/G）
human_size() {
  local b=$1
  if   [ "$b" -ge 1073741824 ]; then awk -v n="$b" 'BEGIN{printf "%.1fG", n/1073741824}'
  elif [ "$b" -ge 1048576 ];   then awk -v n="$b" 'BEGIN{printf "%.1fM", n/1048576}'
  elif [ "$b" -ge 1024 ];      then awk -v n="$b" 'BEGIN{printf "%.1fK", n/1024}'
  else printf '%sB' "$b"; fi
}

# 目录总字节（du -ck 最后一行以 KB 计，×1024 转字节；无文件返回 0）
dir_bytes() {
  local d=$1 total
  total=$(du -ck "$d" 2>/dev/null | awk 'END{print $1*1024}')
  [ -n "${total:-}" ] || total=0
  printf '%s' "$total"
}

# 素材文件统计（匹配扩展名 或 >100M，去重）：输出 "文件数<TAB>总字节"
asset_stats() {
  local d=$1
  find "$d" -type f \( -iname "*.ipsw" -o -iname "*.dmg.aea" -o -iname "*.dmg" -o -iname "*.app" -o -size +100M \) 2>/dev/null \
  | while IFS= read -r f; do
      st=$(stat -f%z "$f" 2>/dev/null || echo 0)
      printf '%s\t%s\n' "$f" "$st"
    done
}

# 一组 sha256 校验：<source_file> <dest_file> -> 0 一致 / 1 不一致 / 2 目标缺失
sha_check() {
  [ -f "$2" ] || return 2
  local s d
  s=$(shasum -a 256 "$1" 2>/dev/null | awk '{print $1}')
  d=$(shasum -a 256 "$2" 2>/dev/null | awk '{print $1}')
  [ -n "$s" ] && [ "$s" = "$d" ]
}

# find 的素材排除表达式（--exclude-assets 时拼入 find；-iname 大小写不敏感）
asset_exclude_expr() {
  printf '%s' "! -iname '*.ipsw' ! -iname '*.dmg.aea' ! -iname '*.dmg' ! -iname '*.app' ! -size +100M"
}

timestamp() { date '+%Y-%m-%dT%H:%M:%S%z'; }

# ---------------------------------------------------------------------------
# 命令: --scan
# ---------------------------------------------------------------------------
cmd_scan() {
  local roots=() d dsh-codepunk n_runs n_files
  if [ "$#" -eq 0 ]; then
    roots=("${SCAN_DEFAULT_ROOTS[@]}")
  else
    roots=("$@")
  fi
  printf '# %s scan @ %s\n' "$SCRIPT_NAME" "$(timestamp)"
  printf '# path\tsize\truns\tfiles\tasset_files\tasset_size\tstructure\n'
  local total_found=0 total_runs=0 total_assets=0 total_asset_bytes=0
  for d in "${roots[@]}"; do
    dsh-codepunk=""
    if [ -d "$d/.dsh-codepunk" ]; then dsh-codepunk="$d/.dsh-codepunk"
    elif [ -d "$d" ] && [ "$(basename "$d")" = ".dsh-codepunk" ]; then dsh-codepunk="$d"
    fi
    if [ -z "$dsh-codepunk" ]; then
      # 显式清单里不存在的目录也要标注（简报现场 9 处核对）
      case "$d" in
        "$HOME/Desktop/Downloads") printf '%s\tMISSING\t-\t-\t-\t-\t-\n' "$d" ;;
        *) if [ "${VERBOSE:-0}" = 1 ]; then log "跳过（无 .dsh-codepunk）: $d"; fi ;;
      esac
      continue
    fi
    n_runs=$( [ -d "$dsh-codepunk/runs" ] && find "$dsh-codepunk/runs" -maxdepth 1 -type d -name 'run-*' 2>/dev/null | wc -l | tr -d ' ' || echo 0 )
    n_files=$(find "$dsh-codepunk" -type f 2>/dev/null | wc -l | tr -d ' ')
    local_size=$(dir_bytes "$dsh-codepunk")
    # 素材量估算
    local a_files=0 a_bytes=0
    while IFS=$'\t' read -r _f _b; do
      [ -n "$_f" ] || continue
      a_files=$((a_files + 1))
      a_bytes=$((a_bytes + _b))
    done < <(asset_stats "$dsh-codepunk")
    # 结构标记（README/goal/chunks/runs/knowledge 存在度）
    local struct=""
    [ -f "$dsh-codepunk/README.md" ]  && struct="${struct}R"
    [ -f "$dsh-codepunk/goal.yaml" ]  && struct="${struct}G"
    [ -f "$dsh-codepunk/chunks.yaml" ] && struct="${struct}C"
    [ -d "$dsh-codepunk/runs" ]       && struct="${struct}U"
    [ -d "$dsh-codepunk/knowledge" ]  && struct="${struct}K"
    [ -z "$struct" ] && struct="-"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$dsh-codepunk" "$(human_size "$local_size")" "$n_runs" "$n_files" \
      "$a_files" "$(human_size "$a_bytes")" "$struct"
    total_found=$((total_found + 1)); total_runs=$((total_runs + n_runs))
    total_assets=$((total_assets + a_files)); total_asset_bytes=$((total_asset_bytes + a_bytes))
  done
  printf '# 汇总: %d 处 .dsh-codepunk | runs 合计 %d | 素材文件 %d（%s）\n' \
    "$total_found" "$total_runs" "$total_assets" "$(human_size "$total_asset_bytes")"
  return 0
}

# ---------------------------------------------------------------------------
# 命令: --migrate
# ---------------------------------------------------------------------------
# resolve_src <src_arg> -> 设置 SRC_ROOT（工程根）SRC_DSH_CODEPUNK（.dsh-codepunk 绝对路径）
# 断点续传兼容：源已改名 .pre-refactor-dsh-codepunk（renaming 后中断）时视为已迁移，不 die
SRC_ROOT=""; SRC_DSH_CODEPUNK=""; ALREADY_RENAMED=0
resolve_src() {
  local a=$1
  if [ -d "$a/.dsh-codepunk" ]; then
    SRC_ROOT=$(cd "$a" && pwd); SRC_DSH_CODEPUNK="$SRC_ROOT/.dsh-codepunk"
  elif [ -d "$a" ] && [ "$(basename "$a")" = ".dsh-codepunk" ]; then
    SRC_ROOT=$(cd "$(dirname "$a")" && pwd); SRC_DSH_CODEPUNK="$SRC_ROOT/.dsh-codepunk"
  elif [ -d "$a/.pre-refactor-dsh-codepunk" ]; then
    SRC_ROOT=$(cd "$a" && pwd); SRC_DSH_CODEPUNK="$SRC_ROOT/.dsh-codepunk"
    ALREADY_RENAMED=1
    log "源已改名保留窗（断点续传场景），视为已迁移: $SRC_ROOT/.pre-refactor-dsh-codepunk"
  elif [ -n "$a" ] && [ -d "$(dirname "$a")/.pre-refactor-dsh-codepunk" ] && [ "$(basename "$a")" = ".dsh-codepunk" ]; then
    SRC_ROOT=$(cd "$(dirname "$a")" && pwd); SRC_DSH_CODEPUNK="$SRC_ROOT/.dsh-codepunk"
    ALREADY_RENAMED=1
  else
    die "源不存在或不是工程根/.dsh-codepunk 目录: $a"
  fi
}

# 决定是否排除素材：显式 --exclude-assets 或 src 匹配 ASSETS_AUTO_EXCLUDE
want_exclude_assets() {
  local s=$1
  [ "${EXCLUDE_ASSETS:-0}" = 1 ] && return 0
  local pat
  for pat in "${ASSETS_AUTO_EXCLUDE[@]}"; do
    case "$s" in
      *"$pat"*) return 0 ;;
    esac
  done
  return 1
}

# 退出前清理（中断安全）：保留 state 为当前 phase，续传时重新复制/校验
trap 'log "被中断，状态保留于 phase=$(cat "$STATE_FILE" 2>/dev/null | grep ^phase= )，可重跑续传"; exit 130' INT TERM

cmd_migrate() {
  local src_arg="" FORCE=0
  project_id=""          # 全局（write_state 依赖，需跨函数可见）
  REPORT_OUT=""          # 全局（generate_report 依赖）
  EXCLUDE_ASSETS=0; EXCLUDE_ASSETS_SET=0; VERIFY_FULL=0; DRY_RUN=0; VERBOSE=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --exclude-assets) EXCLUDE_ASSETS_SET=1; EXCLUDE_ASSETS=1 ;;
      --verify-full)   VERIFY_FULL=1 ;;
      --dry-run)       DRY_RUN=1 ;;
      --force)         FORCE=1 ;;
      --dest)          [ $# -ge 2 ] || die "--dest 需要参数"; PROJECTS_DIR=$(cd "${2%/}" 2>/dev/null && pwd || printf '%s' "${2%/}"); STATE_DIR="$PROJECTS_DIR/.migrate-state"; shift ;;
      --report-out)    [ $# -ge 2 ] || die "--report-out 需要参数"; REPORT_OUT=$2; shift ;;
      -v)              VERBOSE=1 ;;
      -h|--help)       usage; exit 0 ;;
      -*)              die "未知选项: $1" ;;
      *)
        if [ -z "$src_arg" ]; then src_arg=$1
        elif [ -z "$project_id" ]; then project_id=$1
        else die "多余参数: $1"; fi ;;
    esac
    shift
  done
  [ -n "$src_arg" ] || die "缺少 <src>（用法见 --help）"
  [ -n "$project_id" ] || die "缺少 <project_id>（用法见 --help）"
  case "$project_id" in
    *..*|*/*|*\\*) die "project_id 非法（禁止路径/..）: $project_id" ;;
    *[!A-Za-z0-9._-]*) die "project_id 非法（仅允许 [A-Za-z0-9._-]）: $project_id" ;;
  esac

  resolve_src "$src_arg"
  local dest="$PROJECTS_DIR/$project_id"
  STATE_FILE="$STATE_DIR/$project_id.state"
  [ -n "$REPORT_OUT" ] || REPORT_OUT="$STATE_DIR/reports/$project_id.yaml"

  # 默认排除：vphone 等素材重项目（显式 --exclude-assets 已启用则仅提示）
  if want_exclude_assets "$src_arg"; then
    EXCLUDE_ASSETS=1
    if [ "${EXCLUDE_ASSETS_SET:-0}" != 1 ]; then log "检测到素材重项目路径，自动启用 --exclude-assets"; fi
  fi

  mkdir -p "$STATE_DIR/reports"

  # —— 幂等检查：state 为 done/renaming 且目录完整 → 直接短路 ——
  local prev_phase=""
  [ -f "$STATE_FILE" ] && prev_phase=$(sed -n 's/^phase=//p' "$STATE_FILE")
  if [ "$prev_phase" = "done" ] && [ -d "$dest" ]; then
    info "幂等命中：<${project_id}> 已完成迁移（$(sed -n 's/^migrated_at=//p' "$STATE_FILE")），不重复复制。"
    if [ "$DRY_RUN" = 1 ]; then info "（dry-run）"; return 0; fi
    print_report_unless_dry
    return 0
  fi
  # 断点续传：renaming 后中断（源已改名、done 未写）→ 补写 done 短路
  if [ "$ALREADY_RENAMED" = 1 ] && [ -d "$dest" ]; then
    info "断点续传命中：源已改名保留窗（phase=${prev_phase:-none}），补写完成状态 <${project_id}>。"
    if [ "$DRY_RUN" = 1 ]; then info "（dry-run）"; return 0; fi
    write_state "done"
    print_report_unless_dry
    return 0
  fi

  # —— 目标冲突保护 ——
  if [ -d "$dest" ] && [ -z "$prev_phase" ]; then
    if [ "$FORCE" = 1 ]; then log "目标已存在，--force 覆盖继续（本工具状态缺失，视为外部残留）"
    else die "目标已存在且无本工具迁移状态: $dest （确认后加 --force 或先 --rollback）"; fi
  fi
  # 同 id 换源防护
  if [ -f "$STATE_FILE" ]; then
    local st_src
    st_src=$(sed -n 's/^dsh-codepunk_abs=//p' "$STATE_FILE")
    if [ -n "$st_src" ] && [ "$st_src" != "$SRC_DSH_CODEPUNK" ]; then
      die "project_id <${project_id}> 已绑定源 $st_src，拒绝换源（$SRC_DSH_CODEPUNK）"
    fi
  fi

  local skip=0 n_skip=0 skip_bytes=0
  local files_total=0 total_bytes=0
  SKIP_LIST=()

  # —— 计算迁移清单与跳过清单 ——
  local find_expr=""
  if [ "$EXCLUDE_ASSETS" = 1 ]; then
    find_expr=$(asset_exclude_expr)
  fi
  # 排除参数用数组展开（无 eval、无引号解析风险；-size 用 +100M 等价 104857600B）
  local -a excl_args=()
  if [ "$EXCLUDE_ASSETS" = 1 ]; then
    excl_args=('!' '-iname' '*.ipsw' '!' '-iname' '*.dmg.aea' '!' '-iname' '*.dmg' '!' '-iname' '*.app' '!' '-size' '+100M')
  fi
  # bash 3.2 空数组在 set -u 下展开会报 unbound，分条件执行
  local filelist
  if [ "$EXCLUDE_ASSETS" = 1 ]; then
    filelist=$(find "$SRC_DSH_CODEPUNK" -type f "${excl_args[@]}" 2>/dev/null)
  else
    filelist=$(find "$SRC_DSH_CODEPUNK" -type f 2>/dev/null)
  fi
  files_total=$(printf '%s\n' "$filelist" | sed '/^$/d' | wc -l | tr -d ' ')
  if [ "$EXCLUDE_ASSETS" = 1 ]; then
    # 只对「可能命中素材规则」的文件判定（扩展名匹配 或 >100M），避免全量 stat 巨大文件树
    local list_skip f sz reason
    list_skip=$(find "$SRC_DSH_CODEPUNK" -type f \( -iname '*.ipsw' -o -iname '*.dmg.aea' -o -iname '*.dmg' -o -iname '*.app' -o -size +100M \) 2>/dev/null)
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      sz=$(stat -f%z "$f" 2>/dev/null || echo 0)
      reason=""
      case "$f" in
        *.ipsw)    reason="ipsw" ;;
        *.dmg.aea) reason="dmg.aea" ;;
        *.dmg)     reason="dmg" ;;
        *.app)     reason="app" ;;
      esac
      if [ -z "$reason" ] && [ "$sz" -gt "$ASSET_MIN_SIZE_BYTES" ]; then reason=">100M"; fi
      if [ -n "$reason" ]; then
        SKIP_LIST+=("$f|$sz|$reason")
        skip_bytes=$((skip_bytes + sz))
      fi
    done <<< "$list_skip"
    n_skip=${#SKIP_LIST[@]}
  fi

  # —— dry-run：只打印计划 ——
  if [ "$DRY_RUN" = 1 ]; then
    info "dry-run 计划:"
    info "  源:      $SRC_DSH_CODEPUNK"
    info "  目标:    $dest"
    info "  复制文件: $files_total"
    if [ "$EXCLUDE_ASSETS" = 1 ]; then
      info "  排除素材: $n_skip 个（$(human_size "$skip_bytes")）"
      for _s in "${SKIP_LIST[@]:0:10}"; do info "    - ${_s%%|*}"; done
      if [ "$n_skip" -gt 10 ]; then info "    ... 共 $n_skip 个（完整清单见报告）"; fi
    fi
    info "  校验:    $( if [ "$VERIFY_FULL" = 1 ] || [ "$files_total" -le "$FULL_VERIFY_MAX_FILES" ]; then echo 全量; else echo 随机抽样≥3; fi )"
    info "  保留窗:  $SRC_ROOT/.pre-refactor-dsh-codepunk"
    info "  状态:    $STATE_FILE | 报告: $REPORT_OUT"
    return 0
  fi

  # —— 写入 phase=copying 并复制 ——
  write_state "copying"
  log "复制 $files_total 个文件 → $dest ..."
  mkdir -p "$dest"
  # 生成相对清单（供 rsync --files-from 与校验复用；统计=复制=校验同一清单）
  local rel_list
  rel_list=$(printf '%s\n' "$filelist" | sed '/^$/d' | sed "s#^$SRC_DSH_CODEPUNK/#./#")
  if command -v rsync >/dev/null 2>&1; then
    # --files-from 仅复制清单内文件（排除在 find 层已生效）；-c 内容校验 + --inplace 断点续传
    printf '%s\n' "$rel_list" > "$dest/.migrate-filelist.tmp"
    rsync -a -c --inplace -R --files-from="$dest/.migrate-filelist.tmp" "$SRC_DSH_CODEPUNK/" "$dest/" \
      || { rm -f "$dest/.migrate-filelist.tmp"; die "rsync 复制失败（exit $?）"; }
    rm -f "$dest/.migrate-filelist.tmp"
  else
    # 兜底：cp 逐文件（跳过匹配素材）
    local rel
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if [ "$EXCLUDE_ASSETS" = 1 ]; then
        case "$f" in
          *.ipsw|*.dmg.aea|*.dmg|*.app) continue ;;
        esac
        [ "$(stat -f%z "$f" 2>/dev/null || echo 0)" -gt "$ASSET_MIN_SIZE_BYTES" ] && continue
      fi
      rel=${f#"$SRC_DSH_CODEPUNK"/}
      mkdir -p "$dest/$(dirname "$rel")"
      if ! cp -p "$f" "$dest/$rel"; then die "复制失败: $f"; fi
    done <<< "$filelist"
  fi

  # —— phase=verifying：sha256 树校验 ——
  write_state "verifying"
  log "sha256 树校验 ..."
  local mode="sample" checked=0 mism=0
  if [ "$VERIFY_FULL" = 1 ] || [ "$files_total" -le "$FULL_VERIFY_MAX_FILES" ]; then
    mode="full"
    local f rel
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      rel=${f#"$SRC_DSH_CODEPUNK"/}
      checked=$((checked + 1))
      if ! sha_check "$f" "$dest/$rel"; then
        log "校验不一致: $rel"
        mism=$((mism + 1))
      fi
    done <<< "$filelist"
  else
    # 随机抽样 ≥ 3（awk rand 排序取前 3，避免依赖 shuf）
    local samples
    samples=$(printf '%s\n' "$filelist" | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | head -3 | cut -f2-)
    local f rel
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      rel=${f#"$SRC_DSH_CODEPUNK"/}
      checked=$((checked + 1))
      if ! sha_check "$f" "$dest/$rel"; then
        log "校验不一致: $rel"
        mism=$((mism + 1))
      fi
    done <<< "$samples"
    log "抽样校验 $checked 个文件（≥3），模式 sample（文件数 $files_total 超阈值）"
  fi
  if [ "$mism" -gt 0 ]; then
    write_state "failed_verify"
    die "sha256 校验失败 $mism 处（详见日志），未改名、可重跑续传（phase=failed_verify 会自动重新复制+校验）"
  fi

  # —— 结构断言（源有则目标必须有）——
  local s_rel ok=1
  for s_rel in README.md goal.yaml chunks.yaml runs knowledge; do
    if [ -e "$SRC_DSH_CODEPUNK/$s_rel" ]; then
      # rsync --files-from 不复制空目录：源目录存在但为空 → 目标补建空目录（幂等）
      if [ -d "$SRC_DSH_CODEPUNK/$s_rel" ] && [ ! -d "$dest/$s_rel" ]; then
        mkdir -p "$dest/$s_rel" && log "补建空目录: $s_rel"
      elif [ -f "$SRC_DSH_CODEPUNK/$s_rel" ] && [ ! -e "$dest/$s_rel" ]; then
        log "结构断言失败: 源有 $s_rel 而目标缺失"
        ok=0
      fi
    fi
  done
  [ "$ok" = 1 ] || { write_state "failed_verify"; die "结构断言失败，未改名"; }

  # —— 原目录改名 .pre-refactor-dsh-codepunk 保留窗 ——
  local pre_refactor="$SRC_ROOT/.pre-refactor-dsh-codepunk"
  if [ -d "$SRC_DSH_CODEPUNK" ] && [ ! -e "$pre_refactor" ]; then
    write_state "renaming"
    log "原目录改名保留窗: $SRC_DSH_CODEPUNK → $pre_refactor"
    mv "$SRC_DSH_CODEPUNK" "$pre_refactor" || die "改名保留窗失败（迁移数据已完整，可手工处理）"
  elif [ -d "$pre_refactor" ]; then
    log "保留窗已存在，跳过改名: $pre_refactor"
  fi

  # —— 完成 ——
  write_state "done"
  info "迁移完成: $SRC_DSH_CODEPUNK → $dest"
  [ "$DRY_RUN" = 1 ] && return 0
  generate_report "$project_id" "$files_total" "$n_skip" "$skip_bytes" "$mode" "$checked" "$mism"
  info "报告: $REPORT_OUT"
  return 0
}

# ---------------------------------------------------------------------------
# state 读写 / 报告生成（与 handoff/migration-report.yaml 模板同 schema）
# ---------------------------------------------------------------------------
write_state() {
  local phase=$1
  {
    printf 'schema=%s\n' "$SCHEMA"
    printf 'project_id=%s\n' "$project_id"
    printf 'src_arg_abs=%s\n' "$SRC_ROOT"
    printf 'dsh-codepunk_abs=%s\n' "$SRC_DSH_CODEPUNK"
    printf 'dest_abs=%s\n' "$PROJECTS_DIR/$project_id"
    printf 'exclude_assets=%s\n' "$EXCLUDE_ASSETS"
    printf 'phase=%s\n' "$phase"
    printf 'migrated_at=%s\n' "$(timestamp)"
    printf 'report=%s\n' "$REPORT_OUT"
  } > "$STATE_FILE"
}

# 幂等命中时直接补打印报告（不重新校验）
print_report_unless_dry() {
  local rep
  rep=$(sed -n 's/^report=//p' "$STATE_FILE")
  if [ -n "$rep" ] && [ -f "$rep" ]; then info "既有报告: $rep"; fi
}

# generate_report <project_id> <files_total> <n_skip> <skip_bytes> <vmode> <vchecked> <vmism>
# 注意：参数显式传入，避免跨函数读取 cmd_migrate 的 local 变量（bash 作用域）
generate_report() {
  local gid=$1 gfiles=$2 gnskip=$3 gskipbytes=$4 vmode=$5 vchecked=$6 vmism=$7
  local pre_refactor="$SRC_ROOT/.pre-refactor-dsh-codepunk"
  # runs 数可能在改名后读不到源，回退保留窗
  local runs_src="${SRC_DSH_CODEPUNK}"
  [ -d "$runs_src/runs" ] || runs_src="$pre_refactor"
  local now; now=$(timestamp)
  mkdir -p "$(dirname "$REPORT_OUT")"
  {
    cat <<EOF
migration:
  schema: $SCHEMA
  project_id: $gid
  migrated_at: $now
  status: migrated
  source:
    root_abs: $SRC_ROOT
    dsh-codepunk_abs: $SRC_DSH_CODEPUNK
    files_total: $gfiles
    runs: $( [ -d "$runs_src/runs" ] && find "$runs_src/runs" -maxdepth 1 -type d -name 'run-*' 2>/dev/null | wc -l | tr -d ' ' || echo 0 )
  destination:
    path_abs: $PROJECTS_DIR/$gid
  exclude_assets: $EXCLUDE_ASSETS
EOF
    if [ "$EXCLUDE_ASSETS" = 1 ]; then
      cat <<EOF
  excluded:
    rules: ["*.ipsw", "*.dmg.aea", "*.dmg", "*.app", ">100M"]
    files_count: $gnskip
    size_bytes: $gskipbytes
    files:
EOF
      local _s
      for _s in "${SKIP_LIST[@]}"; do
        printf '      - path: "%s"\n        size_bytes: %s\n        reason: "%s"\n' \
          "${_s%%|*}" "$(printf '%s' "$_s" | cut -d'|' -f2)" "$(printf '%s' "$_s" | cut -d'|' -f3)"
      done
    else
      printf '  excluded: {enabled: false}\n'
    fi
    cat <<EOF
  copied:
    files_count: $gfiles
  verify:
    mode: $vmode
    checked_files: $vchecked
    mismatches: $vmism
  pre_refactor:
    old_path: $SRC_DSH_CODEPUNK
    new_path: $pre_refactor
  registry:            # 供 chunk-link register 消费（本工具不写 INDEX.yaml）
    project_id: $gid
    repo_path: $SRC_ROOT
    readme_marker: "dsh-codepunk-project: $gid"
EOF
  } > "$REPORT_OUT"
  [ "${VERBOSE:-0}" = 1 ] && log "报告已写入 $REPORT_OUT"
}

# ---------------------------------------------------------------------------
# 命令: --rollback
# ---------------------------------------------------------------------------
cmd_rollback() {
  local project_id="" DRY_RUN=0 RESTORE=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --restore) RESTORE=1 ;;
      --dest)    [ $# -ge 2 ] || die "--dest 需要参数"; PROJECTS_DIR=$(cd "${2%/}" 2>/dev/null && pwd || printf '%s' "${2%/}"); STATE_DIR="$PROJECTS_DIR/.migrate-state"; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) die "未知选项: $1" ;;
      *)
        if [ -z "$project_id" ]; then project_id=$1
        else die "多余参数: $1"; fi ;;
    esac
    shift
  done
  [ -n "$project_id" ] || die "缺少 <project_id>"
  local st="$STATE_DIR/$project_id.state"
  if [ ! -f "$st" ]; then die "无迁移状态: $project_id（state=$st）"; fi
  local root dsh-codepunk pre
  root=$(sed -n 's/^src_arg_abs=//p' "$st")
  dsh-codepunk=$(sed -n 's/^dsh-codepunk_abs=//p' "$st")
  pre=$(sed -n 's/^dsh-codepunk_abs=//p' "$st"); pre="${pre%/*}/.pre-refactor-dsh-codepunk"
  if [ -z "$root" ] || [ -z "$dsh-codepunk" ]; then die "state 损坏: $st"; fi
  if [ ! -d "$pre" ]; then
    if [ -f "$st" ]; then
      if grep -q '^phase=' "$st"; then sed -i '' 's/^phase=.*/phase=rolled_back/' "$st"
      else printf 'phase=rolled_back\n' >> "$st"; fi
      info "保留窗不存在，按已回滚处理（state 标记 rolled_back）: $pre"
    else
      info "保留窗不存在（可能已回滚或从未迁移）: $pre"
    fi
    return 0
  fi
  if [ "$RESTORE" = 1 ]; then
    local dest="$PROJECTS_DIR/$project_id"
    if [ "$DRY_RUN" = 1 ]; then
      info "dry-run: 将从 $dest 复制回 $dsh-codepunk"
    else
      if [ ! -d "$dest" ]; then die "总库项目不存在: $dest"; fi
      if [ -e "$dsh-codepunk" ]; then die "工程根已存在 .dsh-codepunk: $dsh-codepunk（先移除或人工处理）"; fi
      mkdir -p "$root"
      if ! cp -a "$dest" "$dsh-codepunk"; then die "复制回失败"
      else log "已复制回: $dsh-codepunk"; fi
    fi
  fi
  if [ "$DRY_RUN" = 1 ]; then
    info "dry-run: mv $pre → $dsh-codepunk"
  else
    mv "$pre" "$dsh-codepunk" || die "回滚改名失败"
    # 回滚后标记 state，避免下次 --migrate 以 done 幂等短路误判
    if [ -f "$st" ]; then
      if grep -q '^phase=' "$st"; then sed -i '' 's/^phase=.*/phase=rolled_back/' "$st"
      else printf 'phase=rolled_back\n' >> "$st"; fi
    fi
    info "已还原: $dsh-codepunk（state 标记 rolled_back）"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# 入口
# ---------------------------------------------------------------------------
[ "$#" -ge 1 ] || { usage; exit 1; }
case "$1" in
  --scan)       shift; cmd_scan "$@" ;;
  --migrate)    shift; cmd_migrate "$@" ;;
  --rollback)   shift; cmd_rollback "$@" ;;
  --help|-h)    usage ;;
  --version)    version ;;
  *)            die "未知命令: $1（--help 查看用法）" ;;
esac
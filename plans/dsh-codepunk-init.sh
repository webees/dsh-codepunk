#!/usr/bin/env bash

# F197：本工具的判据/内联脚本含**多字节**内容（中文结论、计数标签）。非 UTF-8 locale（C/POSIX/ISO-8859 系）
#   下会被逐字节或按 US-ASCII 处理，甚至把**环境问题**误诊为数据损坏（实证：`link.sh index` 在 `LC_ALL=C`
#   下报「INDEX 语义非法：invalid multibyte char (US-ASCII)」并提示「从备份恢复或重建」——而 INDEX 完好）。
#   故在非 UTF-8 且系统存在 UTF-8 locale 时固定之；探测只用 ASCII。
case "$(locale charmap 2>/dev/null)" in
  UTF-8|utf8|UTF8) ;;
  *)
    for _l in en_US.UTF-8 C.UTF-8 C.utf8 UTF-8; do
      if locale -a 2>/dev/null | grep -qx "$_l"; then export LC_ALL="$_l"; break; fi
    done ;;
esac
# =============================================================================
# dsh-codepunk-init：幂等建立 dsh-codepunk 统一总库骨架
# -----------------------------------------------------------------------------
# 落位：预设 plans/ 下（待评审后移入正式位 scripts/init-hub.sh）。
# 职责：
#   0. 安装路径常量到总库根、发布无扩展名入口、**同步工具脚本到总库正式位**（升级动作）
#   1. 建 projects/  worktrees/  scripts/ 三目录（mkdir -p，天然幂等）
#   2. 生成 INDEX.yaml 骨架模板（仅文件缺失时写入；存在则跳过 —— 幂等且
#      不产生重复条目，注册表条目后续由 dsh-codepunk-link 演进）
#   3. 绝不触碰 ~/.dsh-codepunk/config.yaml（配置层与运营层职责分离）
# 退出码：0=成功（含幂等无事可做）；1=有失败项（缺失/过期/不一致）；2=环境/用法错误（写权限、父目录缺失）
# 重复执行：幂等且不报错——已是最新则不做任何写入；**内容有差异时按升级语义覆盖总库正式位的**
#   路径常量（home）与工具脚本，并发布/修正无扩展名入口**（这是设计行为，非副作用）；
#   不改写 INDEX.yaml 既有内容（仅缺失时生成骨架）、绝不触碰 config.yaml。
#   注：若你手改过总库 scripts/ 下的副本，运行本脚本会用源副本覆盖之（升级语义），请改源。
# 用法：bash dsh-codepunk-init.sh [--check]     --check=只断言不创建
# =============================================================================
set -euo pipefail

# F421（本轮对抗实测）：**帮助 MUST 不依赖环境**。旧实现里 `-h` 分支（下方 case）位于 `$HOME` 展开
#   **之后**，而 `set -u` 下 HOME 未设时第 39 行先报 `HOME: unbound variable` 并 rc=1 ⇒
#   `doc-consistency` 的退出码契约探针判「init -h(rc=1,want=0) 漂移」（假红：帮助文本本应可离线查看）。
#   故 `-h` 前置；其余路径给显式环境前置（rc=2，而非 unbound variable 崩溃）。
case "${1:-}" in
  -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
if [ -z "${HOME:-}" ]; then
  echo "✗ HOME 未设 ⇒ 无法核验 ≠ 通过（本脚本安装到 \$HOME/.dsh-codepunk，无法确定落点；rc=2）" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 常量来源三态（fresh 机器必须能跑通：仓内副本 → 总库已装副本 → 内联兜底）：
# 早期实现只 source 前两者，仓内缺副本时 fresh 机器直接失败（set -e 令 init 退出），
# 而 README/SKILL 的第二步正是 source 该文件——属首次部署阻断缺陷。
HOME_SH_SRC="$SCRIPT_DIR/dsh-codepunk-home.sh"
HOME_SH_DST="$HOME/.dsh-codepunk/dsh-codepunk-home.sh"
if [[ -f "$HOME_SH_SRC" ]]; then
  source "$HOME_SH_SRC"
elif [[ -f "$HOME_SH_DST" ]]; then
  source "$HOME_SH_DST"
else
  export DSH_CODEPUNK_HOME="${DSH_CODEPUNK_HOME:-$HOME/.dsh-codepunk}"
  export DSH_CODEPUNK_PROJECTS="$DSH_CODEPUNK_HOME/projects"
  export DSH_CODEPUNK_INDEX="$DSH_CODEPUNK_HOME/INDEX.yaml"
  export DSH_CODEPUNK_WORKTREES="$DSH_CODEPUNK_HOME/worktrees"
  export DSH_CODEPUNK_SCRIPTS="$DSH_CODEPUNK_HOME/scripts"
fi

CHECK_ONLY=0
case "${1:-}" in
  -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --check)   CHECK_ONLY=1 ;;
  "")        : ;;
  *)         echo "未知参数: $1（--check 只读校验；-h 查看用法）" >&2; exit 2 ;;
esac

fail()     { echo "✗ $*" >&2; exit 1; }   # 1 = 有失败项（内容/一致性）
fail_env() { echo "✗ $*" >&2; exit 2; }   # 2 = 环境/用法错误（写权限、父目录缺失等）
pass() { echo "✓ $*"; }

# --- 0. 安装路径常量文件到总库根（README/SKILL 承诺的 source 路径） ---------------
install_home_sh() {
  [[ -f "$HOME_SH_SRC" ]] || return 0          # 无源副本（内联兜底路径）时不安装
  # 只读（--check）模式：**先判定、绝不创建**总库根（F154：原实现在守卫之前 mkdir，
  #   导致「只读」模式仍会写入总库根目录）。
  if (( CHECK_ONLY )); then
    [[ -f "$HOME_SH_DST" ]] || fail "路径常量文件缺失: ${HOME_SH_DST}（运行本体脚本安装）"
    cmp -s "$HOME_SH_SRC" "$HOME_SH_DST" || fail "路径常量文件过期: ${HOME_SH_DST}（运行本体脚本覆盖）"
    return 0
  fi
  mkdir -p "$DSH_CODEPUNK_HOME" 2>/dev/null \
    || fail_env "无法创建总库根: ${DSH_CODEPUNK_HOME}（检查父目录写权限；或改 DSH_CODEPUNK_HOME 环境变量）"
  if [[ -f "$HOME_SH_DST" ]] && cmp -s "$HOME_SH_SRC" "$HOME_SH_DST"; then
    return 0
  fi
  cp "$HOME_SH_SRC" "$HOME_SH_DST" 2>/dev/null \
    || fail_env "路径常量安装失败: ${HOME_SH_DST}（检查 $DSH_CODEPUNK_HOME 写权限）"
  chmod +x "$HOME_SH_DST"
  pass "已安装路径常量: $HOME_SH_DST"
}
install_home_sh

# --- 0b. 发布无扩展名入口（README/SKILL 用的是裸命令形态，如 dsh-codepunk-link） ---
# 源脚本名带 .sh；文档写 `dsh-codepunk-link resolve …`。补符号链接使 PATH 生效后
# 文档命令可用（幂等：已存在且指向正确即跳过）。
publish_bare_commands() {
  local src base dst
  for src in "$DSH_CODEPUNK_SCRIPTS"/dsh-codepunk-*.sh; do
    [[ -f "$src" ]] || continue
    base="$(basename "$src" .sh)"
    dst="$DSH_CODEPUNK_SCRIPTS/$base"
    [[ -L "$dst" && "$(readlink "$dst")" == "$(basename "$src")" ]] && continue
    if (( CHECK_ONLY )); then
      [[ -e "$dst" ]] || fail "缺无扩展名入口: ${dst}（运行本体脚本发布）"
      continue
    fi
    if ! ln -sf "$(basename "$src")" "$dst" 2>/dev/null; then
      # F262：BSD `ln -sf` 是 unlink→symlink 两步，存在**竞态窗口** ⇒ 并发 init 时落败方得 EEXIST 并
      #   **泄漏原始报错**（实测 4 路并发：rc=1,0,1,1 且输出 `ln: … File exists`），而**顺序**重跑是幂等的
      #   （实测 rc=0）⇒ 此处若链接**已正确**即视为成功（等价于对端先行完成），否则给可读结论、不泄漏底层报错。
      if [[ -L "$dst" && "$(readlink "$dst")" == "$(basename "$src")" ]]; then
        pass "已发布入口: ${base}（并发对端已先行完成）"
      else
        fail "无法发布入口: ${dst}（ln 失败且链接不正确；请检查总库 scripts/ 目录权限）"
      fi
      continue
    fi
    pass "已发布入口: $base"
  done
}

# --- 0c. 同步工具脚本到总库正式位（预设升级路径） --------------------------------
# 运行期用的是总库副本（~/.dsh-codepunk/scripts/*），故升级预设后 MUST 同步此处；
# 原先只建骨架、不同步脚本，导致升级后总库长期停留在旧版且无检测。
# 同步源 = 本脚本所在目录（即仓内 plans/）：**从仓内运行本脚本即为升级动作**。
install_scripts() {
  local src_dir="$SCRIPT_DIR" n_new=0 n_upd=0 n_stale=0 f base dst
  local _stale_names=""   # F424：点名漂移文件（旧实现只报数量 ⇒ 定位需手工逐文件比对）
  if [[ "$(cd "$src_dir" && pwd)" == "$(cd "$DSH_CODEPUNK_SCRIPTS" 2>/dev/null && pwd)" ]]; then
    echo "  ℹ 正从总库副本自身运行：更新工具请改用仓内副本（bash <repo>/plans/dsh-codepunk-init.sh）" >&2
    return 0
  fi
  if (( CHECK_ONLY )); then :; else
    mkdir -p "$DSH_CODEPUNK_SCRIPTS" 2>/dev/null \
      || fail_env "无法创建总库 scripts 目录: ${DSH_CODEPUNK_SCRIPTS}（检查写权限）"
  fi
  for f in "$src_dir"/*.sh "$src_dir"/*.py "$src_dir"/*.mjs "$src_dir"/windows/*.ps1; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    dst="$DSH_CODEPUNK_SCRIPTS/$base"
    if [[ ! -e "$dst" ]]; then
      n_new=$((n_new + 1))
      _stale_names="${_stale_names} ${base}（缺失）"
      (( CHECK_ONLY )) || { cp "$f" "$dst"; chmod 755 "$dst" 2>/dev/null; }
    elif ! cmp -s "$f" "$dst"; then
      n_upd=$((n_upd + 1))
      _stale_names="${_stale_names} ${base}（过期）"
      (( CHECK_ONLY )) || { cp "$f" "$dst"; chmod 755 "$dst" 2>/dev/null; }
    elif (( ! CHECK_ONLY )); then
      # F304：内容一致时**权限仍可能漂移**——源为 711/644 会把非规范模式带进总库，或副本被人工改成
      #   644 后 `chmod +x` 分支永不触及 ⇒ 总库脚本不可执行/不可读，而 init 仍报成功。故此处按规范
      #   模式 755（可执行 + 可读）归一化；仅当与 755 不同才改，保持幂等与无副作用。
      _mode="$(stat -f '%Lp' "$dst" 2>/dev/null || stat -c '%a' "$dst" 2>/dev/null)"
      [ "$_mode" = "755" ] || chmod 755 "$dst" 2>/dev/null
    fi
  done
  if (( CHECK_ONLY )); then
    n_stale=$((n_new + n_upd))
    (( n_stale == 0 )) && pass "工具脚本与源一致（${DSH_CODEPUNK_SCRIPTS}）" \
                       || fail "总库工具脚本缺失/过期 $n_stale 个:${_stale_names}（运行本体脚本同步）"
  else
    if (( n_new + n_upd == 0 )); then
      pass "工具脚本已是最新（无变更）"
    else
      pass "工具脚本已同步：新增 $n_new · 更新 $n_upd"
    fi
  fi
}
install_scripts

# 发布无扩展名入口 MUST 在脚本拷入总库之后（F155：原顺序在全新总库上 glob 空匹配，入口从未发布）
publish_bare_commands

# --- 1. 目录骨架（mkdir -p 幂等） -------------------------------------------------
for d in "$DSH_CODEPUNK_PROJECTS" "$DSH_CODEPUNK_WORKTREES" "$DSH_CODEPUNK_SCRIPTS"; do
  if (( CHECK_ONLY )); then
    [[ -d "$d" ]] || fail "目录缺失: $d (运行本体脚本补建)"
  else
    mkdir -p "$d" 2>/dev/null \
      || fail_env "目录创建失败: ${d}（检查父目录写权限）"
    pass "目录就绪: $d"
  fi
done

# --- 2. INDEX.yaml 骨架模板（缺失才写；存在即视为已初始化） --------------------------
if [[ -f "$DSH_CODEPUNK_INDEX" ]]; then
  pass "INDEX.yaml 已存在，跳过生成（幂等）: $DSH_CODEPUNK_INDEX"
else
  if (( CHECK_ONLY )); then
    fail "INDEX.yaml 缺失: $DSH_CODEPUNK_INDEX"
  fi
  cat > "$DSH_CODEPUNK_INDEX" <<'EOF'
# =============================================================================
# dsh-codepunk 统一总库 · 全局注册表 INDEX.yaml（骨架模板，init 内置）
# 条目 schema（骨架期声明；条目本体由 dsh-codepunk-link 的 register 构建）：
#   project_id:        项目 slug（目录名直用，冲突加路径 hash 后缀）
#   project_root:      工程根绝对路径（resolve 按此匹配输入路径）
#   dsh_codepunk_path: 总库托管路径（~/.dsh-codepunk/projects/<id>/，须真实存在）
#   migrated_at:       迁移完成时间（ISO 8601；未迁移项目为 null）
#   source:            条目来源：register（或历史 migration-report）
# 字段名以 dsh-codepunk-link 的校验实现为准（早期骨架注释用 repo_path/status 旧名，已对齐）。
# 树形约定：projects/<project_id>/runs/<run_id>/…（结构 = 现工程内 .dsh-codepunk/ 内容平移）
# =============================================================================
schema_version: 1
projects: []
last_updated: null
EOF
  pass "生成 INDEX.yaml 骨架: $DSH_CODEPUNK_INDEX"
fi

# --- 3. config.yaml 不动性自检（只读断言，绝不写入） --------------------------------
CONFIG="$DSH_CODEPUNK_HOME/config.yaml"
if [[ -f "$CONFIG" ]]; then
  pass "全局配置层保留（未触碰）: $CONFIG"
else
  pass "无 config.yaml（维持现状，不创建）"
fi

echo "✔ init 完成（$([ "$CHECK_ONLY" = 1 ] && echo check || echo setup)）: DSH_CODEPUNK_HOME=$DSH_CODEPUNK_HOME"

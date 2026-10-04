#!/usr/bin/env bash
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
# 重复执行：幂等且不报错——已是最新则不做任何写入；**内容有差异时按升级语义覆盖总库正式位的**
#   路径常量（home）与工具脚本，并发布/修正无扩展名入口**（这是设计行为，非副作用）；
#   不改写 INDEX.yaml 既有内容（仅缺失时生成骨架）、绝不触碰 config.yaml。
#   注：若你手改过总库 scripts/ 下的副本，运行本脚本会用源副本覆盖之（升级语义），请改源。
# 用法：bash dsh-codepunk-init.sh [--check]     --check=只断言不创建
# =============================================================================
set -euo pipefail

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
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

fail() { echo "✗ $*" >&2; exit 1; }
pass() { echo "✓ $*"; }

# --- 0. 安装路径常量文件到总库根（README/SKILL 承诺的 source 路径） ---------------
install_home_sh() {
  [[ -f "$HOME_SH_SRC" ]] || return 0          # 无源副本（内联兜底路径）时不安装
  mkdir -p "$DSH_CODEPUNK_HOME"
  if [[ -f "$HOME_SH_DST" ]] && cmp -s "$HOME_SH_SRC" "$HOME_SH_DST"; then
    return 0
  fi
  if (( CHECK_ONLY )); then
    fail "路径常量文件缺失或过期: $HOME_SH_DST（运行本体脚本安装）"
  fi
  cp "$HOME_SH_SRC" "$HOME_SH_DST"
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
    ln -sf "$(basename "$src")" "$dst"
    pass "已发布入口: $base"
  done
}
publish_bare_commands

# --- 0c. 同步工具脚本到总库正式位（预设升级路径） --------------------------------
# 运行期用的是总库副本（~/.dsh-codepunk/scripts/*），故升级预设后 MUST 同步此处；
# 原先只建骨架、不同步脚本，导致升级后总库长期停留在旧版且无检测。
# 同步源 = 本脚本所在目录（即仓内 plans/）：**从仓内运行本脚本即为升级动作**。
install_scripts() {
  local src_dir="$SCRIPT_DIR" n_new=0 n_upd=0 n_stale=0 f base dst
  if [[ "$(cd "$src_dir" && pwd)" == "$(cd "$DSH_CODEPUNK_SCRIPTS" 2>/dev/null && pwd)" ]]; then
    echo "  ℹ 正从总库副本自身运行：更新工具请改用仓内副本（bash <repo>/plans/dsh-codepunk-init.sh）" >&2
    return 0
  fi
  (($(CHECK_ONLY))) || mkdir -p "$DSH_CODEPUNK_SCRIPTS"
  for f in "$src_dir"/*.sh "$src_dir"/*.py "$src_dir"/*.mjs "$src_dir"/windows/*.ps1; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    dst="$DSH_CODEPUNK_SCRIPTS/$base"
    if [[ ! -e "$dst" ]]; then
      n_new=$((n_new + 1))
      (($(CHECK_ONLY))) || { cp "$f" "$dst"; chmod +x "$dst" 2>/dev/null; }
    elif ! cmp -s "$f" "$dst"; then
      n_upd=$((n_upd + 1))
      (($(CHECK_ONLY))) || { cp "$f" "$dst"; chmod +x "$dst" 2>/dev/null; }
    fi
  done
  if (( CHECK_ONLY )); then
    n_stale=$((n_new + n_upd))
    (( n_stale == 0 )) && pass "工具脚本与源一致（$DSH_CODEPUNK_SCRIPTS）" \
                       || fail "总库工具脚本缺失/过期 $n_stale 个（运行本体脚本同步）"
  else
    if (( n_new + n_upd == 0 )); then
      pass "工具脚本已是最新（无变更）"
    else
      pass "工具脚本已同步：新增 $n_new · 更新 $n_upd"
    fi
  fi
}
install_scripts

# --- 1. 目录骨架（mkdir -p 幂等） -------------------------------------------------
for d in "$DSH_CODEPUNK_PROJECTS" "$DSH_CODEPUNK_WORKTREES" "$DSH_CODEPUNK_SCRIPTS"; do
  if (( CHECK_ONLY )); then
    [[ -d "$d" ]] || fail "目录缺失: $d (运行本体脚本补建)"
  else
    mkdir -p "$d"
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

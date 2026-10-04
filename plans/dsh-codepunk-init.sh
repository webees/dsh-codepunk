#!/usr/bin/env bash
# =============================================================================
# dsh-codepunk-init：幂等建立 dsh-codepunk 统一总库骨架
# -----------------------------------------------------------------------------
# 落位：预设 plans/ 下（待评审后移入正式位 scripts/init-hub.sh）。
# 职责（只增不改）：
#   1. 建 projects/  worktrees/  scripts/ 三目录（mkdir -p，天然幂等）
#   2. 生成 INDEX.yaml 骨架模板（仅文件缺失时写入；存在则跳过 —— 幂等且
#      不产生重复条目，注册表条目后续由 dsh-codepunk-link 演进）
#   3. 绝不触碰 ~/.dsh-codepunk/config.yaml（配置层与运营层职责分离）
# 重复执行：无任何副作用、不报错、不覆盖任何既有文件。
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
      [[ -e "$dst" ]] || fail "缺无扩展名入口: $dst（运行本体脚本发布）"
      continue
    fi
    ln -sf "$(basename "$src")" "$dst"
    pass "已发布入口: $base"
  done
}
publish_bare_commands

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
#   project_id:    项目 slug（目录名直用，冲突加路径 hash 后缀）
#   repo_path:     工程根绝对路径
#   readme_marker: 工程根 README 的 frontmatter 标记（dsh-codepunk: <id>，空=未标记）
#   migrated_at:   迁移完成时间（ISO 8601；未迁移项目可为 null）
#   status:        active | archived
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

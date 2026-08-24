#!/usr/bin/env bash
# =============================================================================
# workspace-refactor · chunk-hub init：幂等建立 dsh-codepunk 统一总库骨架
# -----------------------------------------------------------------------------
# 落位：预设 plans/ 下（待评审后移入正式位 scripts/init-hub.sh）。
# 职责（只增不改）：
#   1. 建 projects/  worktrees/  scripts/ 三目录（mkdir -p，天然幂等）
#   2. 生成 INDEX.yaml 骨架模板（仅文件缺失时写入；存在则跳过 —— 幂等且
#      不产生重复条目，注册表条目后续由 chunk-link 演进）
#   3. 绝不触碰 ~/.dsh-codepunk/config.yaml（配置层与运营层职责分离）
# 重复执行：无任何副作用、不报错、不覆盖任何既有文件。
# 用法：bash workspace-refactor-hub.sh [--check]     --check=只断言不创建
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/dsh-codepunk-home.sh" ]]; then
  source "$SCRIPT_DIR/dsh-codepunk-home.sh"
else
  source "$HOME/.dsh-codepunk/dsh-codepunk-home.sh"
fi

CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

fail() { echo "✗ $*" >&2; exit 1; }
pass() { echo "✓ $*"; }

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
# dsh-codepunk 统一总库 · 全局注册表 INDEX.yaml（骨架模板，chunk-hub 产出）
# 条目 schema（骨架期声明；条目本体由 chunk-link 的 register 构建）：
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
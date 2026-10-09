#!/usr/bin/env bash
# =============================================
# dsh-codepunk 统一总库 · 共享路径常量
# ---------------------------------------------
# 导入方式（所有 CLI 脚本统一）：
#   source "$HOME/.dsh-codepunk/dsh-codepunk-home.sh"
# 亦可先设 DSH_CODEPUNK_HOME 覆盖默认值（测试/沙箱场景），再 source 本文件。
#
# 落位：本文件是**仓内源副本**（plans/dsh-codepunk-home.sh）。
#   `dsh-codepunk-init.sh` 会在首次运行时把它安装到总库根
#   `$HOME/.dsh-codepunk/dsh-codepunk-home.sh`（README/SKILL 承诺的 source 路径），
#   此后由该处提供常量；修改请改仓内源并重跑 init 覆盖安装。
#
# 常量清单：
#   DSH_CODEPUNK_HOME      总库根（默认 ~/.dsh-codepunk）
#   DSH_CODEPUNK_PROJECTS  项目运营层根 projects/<project_id>/
#   DSH_CODEPUNK_INDEX     全局注册表 INDEX.yaml
#   DSH_CODEPUNK_WORKTREES worktree 治理区
#   DSH_CODEPUNK_SCRIPTS   总库工具脚本落位
#
# 副作用：把 $DSH_CODEPUNK_SCRIPTS 前置进 PATH（幂等、不重复追加），
#   使文档中的裸命令（dsh-codepunk-link / dsh-codepunk-init / dsh-codepunk-leak-guard）
#   在 source 之后可直接调用——SKILL §1.1 第 2 步即要求 source 本文件。
# =============================================

# 尊重外部预置值（允许测试覆写），否则默认用户级总库根
# F277：本文件**须 source** 方生效（见上方「导入方式」）。旧行为：被**直接执行**时静默 rc=0、零输出 ⇒
#   使用者可能误以为「已生效」，随后命令却因缺常量而失败。此处仅在【未被 source】时给一行提示（rc 仍 0，
#   不改任何常量语义；被 source 时无任何输出）。
if [ "${BASH_SOURCE[0]:-}" = "${0:-}" ]; then
  printf '%s\n' "dsh-codepunk-home.sh: 本文件须以 source 导入方生效：source ~/.dsh-codepunk/dsh-codepunk-home.sh" >&2
fi

export DSH_CODEPUNK_HOME="${DSH_CODEPUNK_HOME:-$HOME/.dsh-codepunk}"
export DSH_CODEPUNK_PROJECTS="$DSH_CODEPUNK_HOME/projects"
export DSH_CODEPUNK_INDEX="$DSH_CODEPUNK_HOME/INDEX.yaml"
export DSH_CODEPUNK_WORKTREES="$DSH_CODEPUNK_HOME/worktrees"
export DSH_CODEPUNK_SCRIPTS="$DSH_CODEPUNK_HOME/scripts"

case ":$PATH:" in
  *":$DSH_CODEPUNK_SCRIPTS:"*) ;;
  *) export PATH="$DSH_CODEPUNK_SCRIPTS:$PATH" ;;
esac

# =============================================================================
# dsh-codepunk 统一总库 · 共享路径常量（Windows / PowerShell 版）
# -----------------------------------------------------------------------------
# 导入方式（所有 CLI 脚本统一）：
#   . "$HOME\.dsh-codepunk\dsh-codepunk-home.ps1"
# 亦可先设 $env:DSH_CODEPUNK_HOME 覆盖默认值（测试/沙箱场景），再点源本文件。
#
# 常量清单（与 POSIX 版 dsh-codepunk-home.sh 一一对应）：
#   DSH_CODEPUNK_HOME      总库根（默认 ~/.dsh-codepunk）
#   DSH_CODEPUNK_PROJECTS  项目运营层根 projects/<project_id>/
#   DSH_CODEPUNK_INDEX     全局注册表 INDEX.yaml
#   DSH_CODEPUNK_WORKTREES worktree 治理区
#   DSH_CODEPUNK_SCRIPTS   总库工具脚本落位
# =============================================================================

# 尊重外部预置值（允许测试覆写），否则默认用户级总库根
if ([string]::IsNullOrEmpty($env:DSH_CODEPUNK_HOME)) {
  $env:DSH_CODEPUNK_HOME = Join-Path $HOME '.dsh-codepunk'
}
$env:DSH_CODEPUNK_PROJECTS  = Join-Path $env:DSH_CODEPUNK_HOME 'projects'
$env:DSH_CODEPUNK_INDEX     = Join-Path $env:DSH_CODEPUNK_HOME 'INDEX.yaml'
$env:DSH_CODEPUNK_WORKTREES = Join-Path $env:DSH_CODEPUNK_HOME 'worktrees'
$env:DSH_CODEPUNK_SCRIPTS   = Join-Path $env:DSH_CODEPUNK_HOME 'scripts'

# 便捷只读镜像（供点源后直接引用变量名，与 bash 版习惯一致）
$DSH_CODEPUNK_HOME       = $env:DSH_CODEPUNK_HOME
$DSH_CODEPUNK_PROJECTS   = $env:DSH_CODEPUNK_PROJECTS
$DSH_CODEPUNK_INDEX      = $env:DSH_CODEPUNK_INDEX
$DSH_CODEPUNK_WORKTREES  = $env:DSH_CODEPUNK_WORKTREES
$DSH_CODEPUNK_SCRIPTS    = $env:DSH_CODEPUNK_SCRIPTS

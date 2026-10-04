# =============================================================================
# dsh-codepunk-init（Windows / PowerShell 版）：幂等建立 dsh-codepunk 统一总库骨架
# -----------------------------------------------------------------------------
# 职责（与 POSIX 版 dsh-codepunk-init.sh **等价**，唯一差异见末条）：
#   1. 安装路径常量到总库根 + 同步工具脚本到总库正式位（升级动作：从仓内运行本脚本即同步）
#   2. 建 projects/ worktrees/ scripts/ 三目录（-Force 天然幂等）
#   3. 生成 INDEX.yaml 骨架模板（仅文件缺失时写入；存在则跳过）
#   4. 绝不触碰总库 config.yaml（配置层与运营层职责分离）
# 差异：POSIX 版另发布「无扩展名入口」符号链接；Windows 无同构机制，按 README 以
#       `pwsh -File ~/.dsh-codepunk/scripts/<name>.ps1` 调用（PATH 已由 home.ps1 前置）。
# 重复执行：无副作用、不报错、不覆盖任何既有文件。
# 用法：pwsh -File dsh-codepunk-init.ps1 [-Check]
#   注：Windows 上写总库脚本正式位为 .ps1；本文件即正式位的源副本。
# =============================================================================
[CmdletBinding()]
param([switch]$Check)

$ErrorActionPreference = 'Stop'

# 载入路径常量（同目录优先，其次总库根）
$homeScript = Join-Path $PSScriptRoot 'dsh-codepunk-home.ps1'
if (-not (Test-Path $homeScript)) { $homeScript = Join-Path $HOME '.dsh-codepunk\dsh-codepunk-home.ps1' }
if (Test-Path $homeScript) { . $homeScript }
else {
  if ([string]::IsNullOrEmpty($env:DSH_CODEPUNK_HOME)) { $env:DSH_CODEPUNK_HOME = Join-Path $HOME '.dsh-codepunk' }
  $env:DSH_CODEPUNK_PROJECTS  = Join-Path $env:DSH_CODEPUNK_HOME 'projects'
  $env:DSH_CODEPUNK_INDEX     = Join-Path $env:DSH_CODEPUNK_HOME 'INDEX.yaml'
  $env:DSH_CODEPUNK_WORKTREES = Join-Path $env:DSH_CODEPUNK_HOME 'worktrees'
  $env:DSH_CODEPUNK_SCRIPTS   = Join-Path $env:DSH_CODEPUNK_HOME 'scripts'
}

function Fail([string]$m) { Write-Error "x $m"; exit 1 }
function Pass([string]$m) { Write-Host "v $m" }

# --- 1. 目录骨架（幂等） ----------------------------------------------------
# --- 0. 安装 home.ps1 到总库根 + 同步工具脚本（与 POSIX 端口等价；运行期用总库副本）---
function Install-Home {
  $src = Join-Path $PSScriptRoot 'dsh-codepunk-home.ps1'
  if (-not (Test-Path $src)) { return }
  $dst = Join-Path $HOME '.dsh-codepunk\dsh-codepunk-home.ps1'
  if ((Test-Path $dst) -and ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash)) { return }
  if ($Check) { Fail "路径常量文件缺失或过期: $dst (运行本体脚本安装)" }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
  Copy-Item -LiteralPath $src -Destination $dst -Force
  Pass "已安装路径常量: $dst"
}
function Sync-Scripts {
  $hub = Resolve-Path $env:DSH_CODEPUNK_SCRIPTS -ErrorAction SilentlyContinue
  if ($hub -and ((Resolve-Path $PSScriptRoot).Path -eq $hub.Path)) {
    Write-Host "  i 正从总库副本自身运行：更新工具请改用仓内副本"
    return
  }
  if (-not $Check) { New-Item -ItemType Directory -Force -Path $env:DSH_CODEPUNK_SCRIPTS | Out-Null }
  $new = 0; $upd = 0
  foreach ($f in (Get-ChildItem -Path $PSScriptRoot -Filter *.ps1 -File)) {
    $dst = Join-Path $env:DSH_CODEPUNK_SCRIPTS $f.Name
    if (-not (Test-Path $dst)) { $new++ }
    elseif ((Get-FileHash $f.FullName).Hash -ne (Get-FileHash $dst).Hash) { $upd++ }
    else { continue }
    if (-not $Check) { Copy-Item -LiteralPath $f.FullName -Destination $dst -Force }
  }
  if ($Check) {
    if ($new + $upd -gt 0) { Fail "总库工具脚本缺失/过期 $($new + $upd) 个 (运行本体脚本同步)" }
    else { Pass "工具脚本与源一致 ($env:DSH_CODEPUNK_SCRIPTS)" }
  } elseif ($new + $upd -eq 0) { Pass "工具脚本已是最新 (无变更)" }
  else { Pass "工具脚本已同步：新增 $new · 更新 $upd" }
}
Install-Home
Sync-Scripts

foreach ($d in @($env:DSH_CODEPUNK_PROJECTS, $env:DSH_CODEPUNK_WORKTREES, $env:DSH_CODEPUNK_SCRIPTS)) {
  if ($Check) {
    if (-not (Test-Path $d)) { Fail "目录缺失: $d (运行本体脚本补建)" }
  } else {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    Pass "目录就绪: $d"
  }
}

# --- 2. INDEX.yaml 骨架模板（缺失才写；存在即视为已初始化） ------------------
if (Test-Path $env:DSH_CODEPUNK_INDEX) {
  Pass "INDEX.yaml 已存在，跳过生成（幂等）: $($env:DSH_CODEPUNK_INDEX)"
} else {
  if ($Check) { Fail "INDEX.yaml 缺失: $($env:DSH_CODEPUNK_INDEX)" }
  $skeleton = @'
# =============================================================================
# dsh-codepunk 统一总库 · 全局注册表 INDEX.yaml（骨架模板，init 内置）
# 条目 schema：
#   project_id:    项目 slug（目录名直用，冲突加路径 hash 后缀）
#   repo_path:     工程根绝对路径
#   readme_marker: 工程根 README 的 frontmatter 标记（dsh-codepunk: <id>，空=未标记）
#   migrated_at:   迁移完成时间（ISO 8601；未迁移项目可为 null）
#   status:        active | archived
# =============================================================================
schema_version: 1
projects: []
last_updated: null
'@
  # 无 BOM UTF-8 写入（PowerShell 5.1 的 Set-Content -Encoding UTF8 会带 BOM）
  [System.IO.File]::WriteAllText($env:DSH_CODEPUNK_INDEX, $skeleton, (New-Object System.Text.UTF8Encoding($false)))
  Pass "生成 INDEX.yaml 骨架: $($env:DSH_CODEPUNK_INDEX)"
}

# --- 3. config.yaml 不动性自检（只读断言，绝不写入） ------------------------
$config = Join-Path $env:DSH_CODEPUNK_HOME 'config.yaml'
if (Test-Path $config) { Pass "全局配置层保留（未触碰）: $config" }
else { Pass "无 config.yaml（维持现状，不创建）" }

$mode = if ($Check) { 'check' } else { 'setup' }
Write-Host "OK init 完成（$mode）: DSH_CODEPUNK_HOME=$($env:DSH_CODEPUNK_HOME)"

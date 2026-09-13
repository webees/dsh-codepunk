# =============================================================================
# dsh-codepunk-leak-guard.ps1 — 泄露防护门（Windows / PowerShell 版）
# -----------------------------------------------------------------------------
# 与 POSIX 版 dsh-codepunk-leak-guard.sh 语义等价。
# 设计原则：**机制进仓库，禁词留本地**——公开仓库的守卫脚本本身不得含私人词。
#
# 禁词来源（均不进仓库）：
#   1) $env:DSH_CODEPUNK_DENYLIST（分隔符 : , 空格 或换行）
#   2) $HOME\.dsh-codepunk\denylist.txt（每行一词，# 开头为注释）
#   3) 仓库内 .leak-denylist
# 通用模式（可进仓库，非私人信息）：绝对路径 / 私网地址 / 凭据形态 / 私钥头 / 邮箱。
#
# 用法：
#   pwsh -File dsh-codepunk-leak-guard.ps1               # 扫索引（pre-commit）
#   pwsh -File dsh-codepunk-leak-guard.ps1 -Tree         # 扫工作树全部跟踪文件
#   pwsh -File dsh-codepunk-leak-guard.ps1 -History      # 扫近 20 提交（pre-push）
#   pwsh -File dsh-codepunk-leak-guard.ps1 -InstallHook  # 装 pre-push 钩子
#   pwsh -File dsh-codepunk-leak-guard.ps1 -List         # 脱敏列出载入禁词
# 退出码：0=通过；1=命中（阻断）；2=用法/环境错误
# =============================================================================
[CmdletBinding()]
param(
  [switch]$Tree,
  [switch]$History,
  [switch]$Staged,
  [switch]$InstallHook,
  [switch]$List
)

$ErrorActionPreference = 'Stop'

# 通用模式（形态而非具体值，可公开）
$GenericPatterns = @(
  '/Users/[A-Za-z0-9._-]+/',
  '/home/[A-Za-z0-9._-]+/',
  '[A-Za-z]:\\Users\\',
  '/Applications/[A-Za-z]',
  '\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b',
  '\b192\.168\.\d{1,3}\.\d{1,3}\b',
  '\b172\.(1[6-9]|2[0-9]|3[01])\.\d{1,3}\.\d{1,3}\b',
  'sk-[A-Za-z0-9]{20,}',
  'gh[pousr]_[A-Za-z0-9]{20,}',
  'AKIA[0-9A-Z]{16}',
  'xox[baprs]-[A-Za-z0-9-]{10,}',
  '-----BEGIN [A-Z ]*PRIVATE KEY-----',
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
)

function Get-RepoRoot {
  $r = (git rev-parse --show-toplevel 2>$null)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($r)) { return $null }
  return $r.Trim()
}

$root = Get-RepoRoot
if (-not $root) { [Console]::Error.WriteLine('不在 git 仓库内'); exit 2 }
Set-Location $root

# ---------- 载入禁词 ----------
$raw = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrEmpty($env:DSH_CODEPUNK_DENYLIST)) {
  foreach ($t in ($env:DSH_CODEPUNK_DENYLIST -split '[:, \r\n]+')) { $raw.Add($t) }
}
foreach ($f in @((Join-Path $HOME '.dsh-codepunk\denylist.txt'), (Join-Path $root '.leak-denylist'))) {
  if (Test-Path $f) {
    foreach ($ln in [System.IO.File]::ReadAllLines($f, [System.Text.Encoding]::UTF8)) {
      if ($ln -notmatch '^\s*#' -and $ln.Trim().Length -gt 0) { $raw.Add($ln.Trim()) }
    }
  }
}
$Deny = @($raw | Where-Object { $_.Trim().Length -ge 3 } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)

function Mask-Term([string]$t) {
  if ($t.Length -le 4) { return ('*' * $t.Length) }
  return $t.Substring(0, 2) + ('*' * ($t.Length - 2))
}

if ($List) {
  Write-Output ("载入禁词: {0} 条" -f $Deny.Count)
  foreach ($t in $Deny) { Write-Output ("  - " + (Mask-Term $t)) }
  exit 0
}

# ---------- 安装 pre-push 钩子 ----------
if ($InstallHook) {
  $hookDir = (git rev-parse --git-path hooks).Trim()
  if (-not (Test-Path $hookDir)) { New-Item -ItemType Directory -Force -Path $hookDir | Out-Null }
  $self = $MyInvocation.MyCommand.Path
  $hookPath = Join-Path $hookDir 'pre-push'
  $hookBody = @"
#!/usr/bin/env pwsh
# dsh-codepunk 泄露防护门（D091）——由 -InstallHook 生成
pwsh -NoProfile -File "$self" -History
exit `$LASTEXITCODE
"@
  [System.IO.File]::WriteAllText($hookPath, $hookBody, (New-Object System.Text.UTF8Encoding($false)))
  Write-Output "OK 已安装 pre-push 钩子: $hookPath"
  Write-Output "   绕过（不建议）: git push --no-verify"
  exit 0
}

# ---------- 收集待扫内容 ----------
$content = New-Object System.Collections.Generic.List[string]
$label = ''

if ($Tree) {
  $label = 'tracked-tree'
  foreach ($f in (git ls-files)) {
    $f = $f.Trim()
    if (-not $f -or -not (Test-Path $f)) { continue }
    if ($f -match '\.(png|jpg|jpeg|gif|webp|pdf|zip|gz|bundle)$') { continue }
    try { $content.AddRange([System.IO.File]::ReadAllLines($f, [System.Text.Encoding]::UTF8)) } catch { }
  }
} elseif ($History) {
  $label = 'history(近20提交)'
  $msgs = git log -20 '--format=%s%n%b' 2>$null
  if ($msgs) { foreach ($l in $msgs) { $content.Add($l) } }
  $diff = git log -20 -p '-U0' 2>$null | Where-Object { $_ -like '+*' -and $_ -notlike '+++*' }
  if ($diff) { foreach ($l in $diff) { $content.Add($l) } }
} else {
  $label = 'staged'
  $diff = git diff --cached '-U0' 2>$null | Where-Object { $_ -like '+*' -and $_ -notlike '+++*' }
  if ($diff) { foreach ($l in $diff) { $content.Add($l) } }
}

if ($content.Count -eq 0) { Write-Output "OK 泄露防护门：无可扫描内容（$label）"; exit 0 }

# ---------- 扫描 ----------
$hits = 0
foreach ($pat in $GenericPatterns) {
  $matched = $content | Where-Object { $_ -match $pat -and $_ -notmatch 'noreply\.github\.com' }
  if ($matched) {
    $hits++
    Write-Output ("  [通用] {0} :: {1} 处" -f $label, @($matched).Count)
    @($matched) | Select-Object -First 1 | ForEach-Object { Write-Output ("         " + $_.Substring(0, [Math]::Min(120, $_.Length))) }
  }
}
foreach ($term in $Deny) {
  $n = @($content | Where-Object { $_.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count
  if ($n -gt 0) {
    $hits++
    Write-Output ("  [禁词] {0} :: 命中 {1} 次（词已脱敏）" -f $label, $n)
  }
}

Write-Output ''
if ($hits -gt 0) {
  Write-Output ("x 泄露防护门：命中 {0} 类，已阻断" -f $hits)
  Write-Output "  处置：脱敏上述内容后重试；确认为误报时用 git commit/push --no-verify 绕过（需留痕说明）"
  exit 1
}
Write-Output ("v 泄露防护门：通过（禁词 {0} 条 + 通用模式 {1} 类）" -f $Deny.Count, $GenericPatterns.Count)
exit 0

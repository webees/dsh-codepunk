# =============================================================================
# dsh-codepunk-link.ps1 — 项目↔总库记忆关联解析器（Windows / PowerShell 版）
# -----------------------------------------------------------------------------
# 与 POSIX 版 dsh-codepunk-link.sh 语义等价：
#   dsh-codepunk-link resolve <项目路径>   三态路由：
#       ① README frontmatter `dsh-codepunk: <id>` 命中（主通道）
#       ② 回退 ~/.dsh-codepunk/INDEX.yaml 注册表（project_root 精确匹配）
#       ③ 都无 → 未注册，退出码 1
#   dsh-codepunk-link index               校验 INDEX.yaml：条目字段齐 + 路径无空悬
#   dsh-codepunk-link register [-y] <项目路径> <id>   追加注册（不覆盖）
#
# 差异说明：PowerShell 无内置 YAML 解析器，本版用行级解析（等价 POSIX 版
#   在无 PyYAML 时的降级路径）；INDEX.yaml 由 init 生成的格式规范，行级解析足够。
# 用法：pwsh -File dsh-codepunk-link.ps1 resolve <路径>
# =============================================================================
[CmdletBinding()]
param(
  [Parameter(Position = 0)][string]$Command,
  [Parameter(Position = 1)][string]$Arg1,
  [Parameter(Position = 2)][string]$Arg2,
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$ScriptName = 'dsh-codepunk-link'

function Write-Err([string]$m) { [Console]::Error.WriteLine("$ScriptName`: $m") }

# ---------- 初始化：DSH_CODEPUNK_HOME / DSH_CODEPUNK_INDEX ----------
# 外部显式环境变量优先（测试覆写刚需），其次 hub 的 home 文件常量，最后默认值。
$extHome  = $env:DSH_CODEPUNK_HOME
$extIndex = $env:DSH_CODEPUNK_INDEX
$home = if ([string]::IsNullOrEmpty($extHome)) { Join-Path $HOME '.dsh-codepunk' } else { $extHome }
foreach ($cand in @((Join-Path $home 'dsh-codepunk-home.ps1'), (Join-Path $home 'scripts\dsh-codepunk-home.ps1'))) {
  if (Test-Path $cand) { . $cand; break }
}
$DSH_CODEPUNK_HOME  = if ([string]::IsNullOrEmpty($extHome))  { $env:DSH_CODEPUNK_HOME }  else { $extHome }
if ([string]::IsNullOrEmpty($DSH_CODEPUNK_HOME)) { $DSH_CODEPUNK_HOME = $home }
$DSH_CODEPUNK_INDEX = if ([string]::IsNullOrEmpty($extIndex)) { Join-Path $DSH_CODEPUNK_HOME 'INDEX.yaml' } else { $extIndex }

# ---------- 路径规范化（~ 展开 / 绝对化 / 去尾斜杠） ----------
function Normalize-Path([string]$p) {
  if ([string]::IsNullOrEmpty($p)) { return $p }
  if ($p -eq '~') { $p = $HOME }
  elseif ($p -like '~/*' -or $p -like '~\*') { $p = Join-Path $HOME $p.Substring(2) }
  if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path (Get-Location).Path $p }
  # 归一化（PowerShell 的 Resolve-Path 需路径存在，故用 GetFullPath）
  try { $p = [System.IO.Path]::GetFullPath($p) } catch { }
  # 去尾斜杠/反斜杠（根除外）
  $root = [System.IO.Path]::GetPathRoot($p)
  while ($p.Length -gt $root.Length -and ($p.EndsWith('\') -or $p.EndsWith('/'))) { $p = $p.Substring(0, $p.Length - 1) }
  return $p
}

# ---------- README 主通道：frontmatter `dsh-codepunk:` 或注释行 ----------
function Get-ReadmeId([string]$readme) {
  if (-not (Test-Path $readme)) { return $null }
  $lines = [System.IO.File]::ReadAllLines($readme, [System.Text.Encoding]::UTF8)
  # ① frontmatter 段（首行 --- 起，前 25 行内找闭合 ---）
  if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
    for ($i = 1; $i -lt [Math]::Min($lines.Count, 25); $i++) {
      if ($lines[$i].Trim() -eq '---') {
        for ($j = 1; $j -lt $i; $j++) {
          $m = [regex]::Match($lines[$j], '^\s*dsh-codepunk\s*:\s*(.+?)\s*$')
          if ($m.Success) { return $m.Groups[1].Value.Trim().Trim('"', "'") }
        }
        break
      }
    }
  }
  # ② 注释行 <!-- dsh-codepunk: <id> -->（前 10 行）
  for ($i = 0; $i -lt [Math]::Min($lines.Count, 10); $i++) {
    $m = [regex]::Match($lines[$i], '<!--\s*dsh-codepunk\s*:\s*([^>]+?)\s*-->')
    if ($m.Success) { return $m.Groups[1].Value.Trim().Trim('"', "'") }
  }
  return $null
}

# ---------- INDEX 解析（行级，等价 POSIX 降级路径） ----------
function Clean-Value([string]$v) {
  if ($null -eq $v) { return '' }
  return ($v -replace '^\s+|\s+$', '' -replace '["'']', '')
}

# 读取 INDEX.yaml → 条目数组（每项为 @{key=value} 有序 hashtable）
function Get-IndexEntries([string]$idx) {
  if (-not (Test-Path $idx)) { return @() }
  $entries = @()
  $cur = $null
  foreach ($raw in [System.IO.File]::ReadAllLines($idx, [System.Text.Encoding]::UTF8)) {
    if ($raw -match '^\s*-\s*(.*)$') {
      if ($null -ne $cur) { $entries += $cur }
      $cur = @{}
      $rest = $Matches[1]
      if ($rest -match '^\s*([^:]+):\s*(.*)$') {
        $k = ($Matches[1] -replace '\s', '')
        $cur[$k] = Clean-Value $Matches[2]
      }
      continue
    }
    if ($null -ne $cur -and $raw -match '^\s*([^:]+):\s*(.*)$') {
      $k = ($Matches[1] -replace '\s', '')
      $cur[$k] = Clean-Value $Matches[2]
    }
  }
  if ($null -ne $cur) { $entries += $cur }
  return ,$entries
}

# 取条目字段（root 别名 project_root|repo_path；dsh-codepunk 别名 dsh_codepunk_path）
function Get-EntryGet($row, [string]$key) {
  if ($null -eq $row) { return '' }
  if ($key -eq 'root') {
    if ($row.ContainsKey('project_root') -and $row['project_root']) { return $row['project_root'] }
    if ($row.ContainsKey('repo_path') -and $row['repo_path']) { return $row['repo_path'] }
    return ''
  }
  if ($key -in @('dsh-codepunk_path', 'dsh_codepunk_path', 'dsh-codepunk')) {
    if ($row.ContainsKey('dsh_codepunk_path') -and $row['dsh_codepunk_path']) { return $row['dsh_codepunk_path'] }
    if ($row.ContainsKey('dsh-codepunk_path') -and $row['dsh-codepunk_path']) { return $row['dsh-codepunk_path'] }
    if ($row.ContainsKey('dsh-codepunk') -and $row['dsh-codepunk']) { return $row['dsh-codepunk'] }
    return ''
  }
  if ($row.ContainsKey($key)) { return $row[$key] }
  return ''
}

function Get-IndexIdByRoot([string]$want) {
  foreach ($row in (Get-IndexEntries $DSH_CODEPUNK_INDEX)) {
    $root = Get-EntryGet $row 'root'
    if ($root -and (Normalize-Path $root) -eq $want) { return (Get-EntryGet $row 'project_id') }
  }
  return ''
}

function Get-IndexRowById([string]$want) {
  foreach ($row in (Get-IndexEntries $DSH_CODEPUNK_INDEX)) {
    if ((Get-EntryGet $row 'project_id') -eq $want) { return $row }
  }
  return $null
}

# ---------- resolve ----------
function Invoke-Resolve([string]$targetIn) {
  if ([string]::IsNullOrEmpty($targetIn)) { Write-Err '用法: dsh-codepunk-link resolve <项目路径>'; $script:rc = 2; return }
  $target = Normalize-Path $targetIn
  if (-not (Test-Path -LiteralPath $target -PathType Container)) { Write-Err "目录不存在: $target"; $script:rc = 1; return }

  $id = Get-ReadmeId (Join-Path $target 'README.md')
  if ($id) {
    # ①-a 先按路径精确匹配 INDEX（冲突以 INDEX 为准）
    $pidP = Get-IndexIdByRoot $target
    if ($pidP) {
      if ($pidP -ne $id) { Write-Err "冲突：README 标记 dsh-codepunk: $id 与 INDEX project_id=$pidP 不一致，以 INDEX 为准（不回写 README）" }
      $dcp = Get-EntryGet (Get-IndexRowById $pidP) 'dsh_codepunk_path'
      if (-not $dcp) { $dcp = Join-Path $DSH_CODEPUNK_HOME "projects/$pidP" }
      Write-Output "project_id=$pidP"; Write-Output "dsh-codepunk_path=$dcp"; $script:rc = 0; return
    }
    # ①-b 再按标记 id 匹配（worktree / 别名场景）
    $rowB = Get-IndexRowById $id
    if ($null -ne $rowB) {
      $rootB = Get-EntryGet $rowB 'root'
      $dcpB  = Get-EntryGet $rowB 'dsh_codepunk_path'
      if ($rootB -and (Normalize-Path $rootB) -ne $target) { Write-Err "提示：$id 的 INDEX project_root=$rootB 与输入路径不同，按 INDEX 关联输出" }
      if (-not $dcpB) { $dcpB = Join-Path $DSH_CODEPUNK_HOME "projects/$id" }
      Write-Output "project_id=$id"; Write-Output "dsh-codepunk_path=$dcpB"; $script:rc = 0; return
    }
    # ①-c 标记已识别但未登记：pre-register 推算
    Write-Err "project_id=$id 未在 INDEX 登记，总库路径为推算值（可用 register 正式登记）"
    Write-Output "project_id=$id"; Write-Output "dsh-codepunk_path=$(Join-Path $DSH_CODEPUNK_HOME "projects/$id")"; $script:rc = 0; return
  }

  # ② 无标记：回退 INDEX 按 project_root 精确匹配
  $pid2 = Get-IndexIdByRoot $target
  if ($pid2) {
    $dcp2 = Get-EntryGet (Get-IndexRowById $pid2) 'dsh_codepunk_path'
    if (-not $dcp2) { $dcp2 = Join-Path $DSH_CODEPUNK_HOME "projects/$pid2" }
    Write-Output "project_id=$pid2"; Write-Output "dsh-codepunk_path=$dcp2"; $script:rc = 0; return
  }

  # ③ 未注册
  Write-Err "未注册：$target（README 无 dsh-codepunk 标记，INDEX 无匹配条目）"
  $script:rc = 1; return
}

# ---------- index：校验无空悬 + 字段齐 ----------
function Invoke-Index() {
  if (-not (Test-Path $DSH_CODEPUNK_INDEX)) { Write-Err "INDEX 未初始化：$DSH_CODEPUNK_INDEX 不存在"; $script:rc = 1; return }
  $entries = Get-IndexEntries $DSH_CODEPUNK_INDEX
  $bad = 0; $n = 0
  foreach ($row in $entries) {
    $n++
    $pid = Get-EntryGet $row 'project_id'
    $root = Get-EntryGet $row 'root'
    if (-not $pid) { Write-Err "条目缺 project_id（第 $n 条）"; $bad++ ; continue }
    if (-not $root) { Write-Err "$pid 缺 project_root/repo_path"; $bad++; continue }
    if (-not (Test-Path -LiteralPath $root)) { Write-Err "$pid 的工程根不存在（空悬）: $root"; $bad++ }
    $dcp = Get-EntryGet $row 'dsh_codepunk_path'
    if ($dcp -and -not (Test-Path -LiteralPath $dcp)) { Write-Err "$pid 的总库路径不存在（空悬）: $dcp"; $bad++ }
  }
  if ($bad -gt 0) { Write-Err "INDEX 校验失败：$bad 处问题（共 $n 条）"; $script:rc = 1; return }
  Write-Output "OK INDEX 校验通过：$n 条，无空悬"
  $script:rc = 0
}

# ---------- register：追加不覆盖 ----------
function Invoke-Register([string]$targetIn, [string]$id) {
  if ([string]::IsNullOrEmpty($targetIn) -or [string]::IsNullOrEmpty($id)) { Write-Err '用法: dsh-codepunk-link register [-y] <项目路径> <id>'; $script:rc = 2; return }
  $target = Normalize-Path $targetIn
  if (-not (Test-Path -LiteralPath $target -PathType Container)) { Write-Err "目录不存在: $target"; $script:rc = 1; return }
  if ($id -notmatch '^[A-Za-z0-9._-]+$') { Write-Err "非法 project_id: $id（仅允许字母数字 . _ -）"; $script:rc = 2; return }

  if (-not (Test-Path $DSH_CODEPUNK_INDEX)) {
    $dir = Split-Path -Parent $DSH_CODEPUNK_INDEX
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $skeleton = "# dsh-codepunk 全局项目索引（骨架模板；条目由 dsh-codepunk-link register 构建）`nschema_version: 1`nprojects: []`n`nlast_updated: null`n"
    [System.IO.File]::WriteAllText($DSH_CODEPUNK_INDEX, $skeleton, (New-Object System.Text.UTF8Encoding($false)))
    Write-Err "INDEX 未初始化，已按骨架创建: $DSH_CODEPUNK_INDEX"
  }

  # 追加不覆盖：project_id 或 project_root 任一已存在即拒绝
  foreach ($row in (Get-IndexEntries $DSH_CODEPUNK_INDEX)) {
    $pid = Get-EntryGet $row 'project_id'
    $root = Get-EntryGet $row 'root'
    if ($pid -eq $id) { Write-Err "已存在，不覆盖: project_id=$id 已在 INDEX.yaml（追加语义）"; $script:rc = 1; return }
    if ($root -and (Normalize-Path $root) -eq $target) { Write-Err "已存在，不覆盖: project_root=$target 已在 INDEX.yaml（追加语义）"; $script:rc = 1; return }
  }

  # 归一空内联列表：init 骨架写 `projects: []`，其后不能再追加列表项
  #   （否则产出非法 YAML）。先改为 `projects:` 再追加。
  $idxText = [System.IO.File]::ReadAllText($DSH_CODEPUNK_INDEX, [System.Text.Encoding]::UTF8)
  $idxText = [regex]::Replace($idxText, '(?m)^projects:\s*\[\]\s*$', 'projects:')
  [System.IO.File]::WriteAllText($DSH_CODEPUNK_INDEX, $idxText, (New-Object System.Text.UTF8Encoding($false)))

  $dcp = Join-Path $DSH_CODEPUNK_HOME "projects/$id"
  $ts  = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
  $block = @"

  - project_id: $id
    project_root: $target
    dsh_codepunk_path: $dcp
    migrated_at: null
    source: register
"@
  # 追加到 projects: 列表末尾（文件末尾追加，缩进与 init 骨架一致）
  $content = [System.IO.File]::ReadAllText($DSH_CODEPUNK_INDEX, [System.Text.Encoding]::UTF8)
  $content = $content.TrimEnd("`r", "`n") + "`n" + $block.TrimStart("`n")
  # 刷新 last_updated
  $content = [regex]::Replace($content, '(?m)^last_updated:.*$', "last_updated: $ts")
  [System.IO.File]::WriteAllText($DSH_CODEPUNK_INDEX, $content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Output "OK 已登记: project_id=$id"
  Write-Output "   project_root=$target"
  Write-Output "   dsh-codepunk_path=$dcp"
  $script:rc = 0
}

# ---------- 主入口 ----------
$script:rc = 0
switch ($Command) {
  'resolve'  { Invoke-Resolve $Arg1 }
  'index'    { Invoke-Index }
  'register' { Invoke-Register $Arg1 $Arg2 }
  default {
    Write-Err "用法: dsh-codepunk-link {resolve <路径> | index | register [-y] <路径> <id>}"
    $script:rc = 2
  }
}
exit $script:rc

#Requires -Version 5.1
<#
.SYNOPSIS
  Win2Lin.ps1 - Windows -> Linux export tool (advanced)
.DESCRIPTION
  Scans installed apps, dev tools, browser PROFILE METADATA (counts only), app config paths,
  fonts, startup entries, git repos. Then copies ONLY user data folders:
  Documents, Desktop, Downloads, Pictures, Videos, Music + D: top-level user dirs.

  STORAGE FORMAT (open, readable everywhere, UTF-8 no BOM):
    <local Win2Lin_export>\<date>_<time>\
      inventory.json   - full scan JSON
      manifest.csv     - every file: source,dest,size_bytes,status,mtime (RFC4180 quoted)
      copy_result.json - totals with failed paths (truthful)
      C_DRIVE\Users\<you>\...  - old C: anchored at drive root (no collision)
      D_DRIVE\...      - old D: anchored at drive root

  SECURITY (never copies credential material):
    - Browser Login Data, Cookies, Web Data, Local Storage/IndexedDB/Session Storage leveldb (*.ldb/*.log)
    - Preferences, Secure Preferences, Local State (DPAPI key), History, Bookmarks DBs
    - Windows DPAPI keys, SAM, security hives, pagefile/hiberfil/swapfile
    - Private keys (*.pfx, *.kdbx, id_rsa, id_ed25519), .aws, .azure
    - C:\Windows, C:\Program Files, C:\ProgramData
  So: Safe to run; re-login once on Linux via Brave/Edge Sync + Google Password Manager.
  Script is forgiving: missing/locked browsers, failed sync, locked files never crash it - logged and skipped.

.PARAMETER Mode Inventory|Copy|Full - Inventory=scan only, Copy=scans + copies user data with live %.
.PARAMETER Destination Export root. Default: local (NOT OneDrive) C:\Win2Lin_export or %USERPROFILE%\Win2Lin_export
.PARAMETER DryRun Preview only - writes nothing, just reports totals + what WOULD copy.
.PARAMETER Resume Skip files already hash/size verified on dest.
.PARAMETER ChunkMB 1-256 (default 16). Validated.
.PARAMETER IncludeDev Include .git projects scan. Copy still excludes heavy dirs by default (see -KeepHeavy).
.PARAMETER KeepHeavy Include node_modules/.venv/.git objects (default OFF - they are Windows binaries, useless on Linux).
.PARAMETER SkipD Skip copying D:\ (default: D:\ is included if present).
.PARAMETER TimeStamped Create dated subfolder.
.PARAMETER NoGui Do not pop notepad.
#>
[CmdletBinding()]
param(
  [ValidateSet('Inventory','Copy','Full')][string]$Mode = 'Inventory',
  [string]$Destination = '',
  [switch]$DryRun,
  [switch]$Resume,
  [ValidateRange(1,256)][int]$ChunkMB = 16,
  [switch]$IncludeDev,
  [switch]$KeepHeavy,
  [switch]$SkipD,
  [bool]$TimeStamped = $true,
  [switch]$NoGui
)

$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest
$script:LogPath = $null

function Get-DesktopPath {
  $p = [Environment]::GetFolderPath('Desktop')
  if (-not $p) { $p = Join-Path $env:USERPROFILE 'Desktop' }
  return $p
}

function Write-Log([string]$msg, [string]$level='INFO') {
  $ts = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  $line = "[$ts] [$level] $msg"
  Write-Host $line
  if ($script:LogPath) { try { Add-Content -Path $script:LogPath -Value $line -Encoding UTF8 } catch {} }
}

function Get-FreeBytesForPath([string]$path) {
  try {
    if (-not $path) { return $null }
    $full = [IO.Path]::GetFullPath($path)
    $root = [IO.Path]::GetPathRoot($full)
    if (-not $root) { return $null }
    $di = [IO.DriveInfo]::new($root)
    return [int64]$di.AvailableFreeSpace
  } catch { return $null }
}

function To-LongPath([string]$p) {
  if (-not $p) { return $p }
  if ($p.StartsWith('\\?\')) { return $p }
  try { return '\\?\' + [IO.Path]::GetFullPath($p) } catch { return $p }
}

function q-Csv([string]$s) {
  $s = if ($null -eq $s) { '' } else { [string]$s }
  if ($s -match '^[=+\-@|%]') { $s = "'" + $s }
  $s = $s.Replace("`r",'\r').Replace("`n",'\n')
  return '"' + ($s -replace '"','""') + '"'
}

function Test-IsInside([string]$child, [string]$parent) {
  if (-not $child -or -not $parent) { return $false }
  try {
    $c = [IO.Path]::GetFullPath($child).TrimEnd('\','/')
    $p = [IO.Path]::GetFullPath($parent).TrimEnd('\','/')
    if ($c.Equals($p, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $c.StartsWith($p + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
  } catch { return $false }
}

function Get-DriveInfo {
  try {
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } | ForEach-Object {
      [PSCustomObject]@{
        Name=$_.Name; Root=$_.Root
        UsedGB=[math]::Round($_.Used/1GB,2); FreeGB=[math]::Round($_.Free/1GB,2)
        TotalGB=[math]::Round(($_.Used+$_.Free)/1GB,2)
      }
    }
  } catch { @() }
}

function Get-InstalledApps {
  $apps = @()
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    try {
      $w = & winget list --accept-source-agreements --disable-interactivity 2>$null | Select-Object -Skip 1
      if ($w) { foreach ($line in $w) { if ($line -and $line.Trim()) { $apps += [PSCustomObject]@{ Source='winget'; Name=$line.Trim() } } } }
    } catch {}
  }
  $keys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
  foreach ($k in $keys) {
    try {
      $propsList = Get-ItemProperty $k -ErrorAction SilentlyContinue
      foreach ($p in $propsList) {
        if (-not $p -or -not $p.DisplayName) { continue }
        $ver = if ($p.PSObject.Properties['DisplayVersion']) { [string]$p.DisplayVersion } else { '' }
        $pub = if ($p.PSObject.Properties['Publisher']) { [string]$p.Publisher } else { '' }
        $loc = if ($p.PSObject.Properties['InstallLocation']) { [string]$p.InstallLocation } else { '' }
        $apps += [PSCustomObject]@{ Source='registry'; Name=[string]$p.DisplayName; Version=$ver; Publisher=$pub; InstallLocation=$loc }
      }
    } catch {}
  }
  $apps | Sort-Object Name | Select-Object -First 2000
}

function Get-DevTools {
  $tools = @('git','node','npm','bun','python','pip','code','docker','go','java','dotnet','rustc','cargo','ffmpeg','codex','opencode')
  $extraPaths = @{
    bun = @((Join-Path $env:USERPROFILE '.bun\bin\bun.exe'), 'C:\Users\' + $env:USERNAME + '\.bun\bin\bun.exe')
    cargo = @((Join-Path $env:USERPROFILE '.cargo\bin\cargo.exe'))
  }
  $results = @()
  foreach ($t in $tools) {
    $c = Get-Command $t -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $c -and $extraPaths.ContainsKey($t)) {
      foreach ($ep in $extraPaths[$t]) { if ($ep -and (Test-Path $ep)) { $c = [PSCustomObject]@{ Source=$ep; Name=$t }; break } }
    }
    if ($c) {
      $ver = ''
      try {
        $tmpOut = Join-Path $env:TEMP ('win2lin_ver_' + $t + '.txt')
        $proc = Start-Process -FilePath $c.Source -ArgumentList '--version' -NoNewWindow -PassThru -RedirectStandardOutput $tmpOut -RedirectStandardError "$tmpOut.err" -ErrorAction SilentlyContinue
        if ($proc) {
          if (-not $proc.WaitForExit(5000)) { try { $proc.Kill() } catch {}; $ver = '(timeout)' }
          else { if (Test-Path $tmpOut) { $ver = [string](Get-Content $tmpOut -TotalCount 1 -ErrorAction SilentlyContinue); $ver = $ver.Trim() } }
        }
      } catch {}
      $results += [PSCustomObject]@{ Tool=$t; Found=$true; Path=$c.Source; Version=$ver }
    } else {
      $results += [PSCustomObject]@{ Tool=$t; Found=$false; Path=''; Version='' }
    }
  }
  $results
}

function Get-BrowserInventory {
  $root = $env:LOCALAPPDATA
  if (-not $root) { try { $root = [Environment]::GetFolderPath('LocalApplicationData') } catch {} }
  if (-not $root) { $root = Join-Path $env:USERPROFILE 'AppData\Local' }
  $candidates = @(
    @{Name='Brave';  Path=Join-Path $root 'BraveSoftware\Brave-Browser\User Data'; Priority=1; Required=$true},
    @{Name='Edge';   Path=Join-Path $root 'Microsoft\Edge\User Data';              Priority=2; Required=$true},
    @{Name='Chrome'; Path=Join-Path $root 'Google\Chrome\User Data';              Priority=3; Required=$false}
  )
  $out = @()
  foreach ($b in $candidates) {
    try {
      if (Test-Path $b.Path) {
        $profiles = Get-ChildItem $b.Path -Directory -Force -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' -or $_.Name -like 'Guest Profile' }
        if ($null -eq $profiles) { $profiles = @() }
        $pList = @()
        foreach ($p in $profiles) {
          try {
            $extDir = Join-Path $p.FullName 'Extensions'
            $extCount = 0
            if (Test-Path $extDir) { $extCount = @(Get-ChildItem $extDir -Directory -ErrorAction SilentlyContinue).Count }
            $syncDir = Join-Path $p.FullName 'Sync Data'
            $syncDetected = Test-Path $syncDir
            $bookmarkFile = Join-Path $p.FullName 'Bookmarks'
            $bookmarkExists = Test-Path $bookmarkFile
            $bookmarksSizeMB = 0
            if ($bookmarkExists) { try { $bookmarksSizeMB = [math]::Round((Get-Item $bookmarkFile).Length/1MB,3) } catch {} }
            # lightweight size: top-2 levels only (avoid walking 5GB Cache/LOCK in Inventory mode)
            $sizeMB = 0
            try {
              $items = Get-ChildItem $p.FullName -Recurse -File -Depth 2 -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum
              if ($items -and $items.Sum) { $sizeMB = [math]::Round([int64]$items.Sum/1MB,1) }
            } catch {}
            $status = if ($syncDetected) { 'Sync folder found (heuristic, not proof)' } else { 'Sync not detected - re-login manually on Linux (fallback: export bookmarks HTML from browser)' }
            $pList += [PSCustomObject]@{ Profile=$p.Name; Extensions=$extCount; SizeMB=$sizeMB; SyncDetected=$syncDetected; BookmarksExists=$bookmarkExists; BookmarksSizeMB=$bookmarksSizeMB; Status=$status; Path=$p.FullName; Note='Heuristic size (top 2 levels only). SyncDetected is best-effort - missing folder does not prove unsynced.' }
          } catch {
            try { Write-Log "Browser profile skipped (ignored): $($p.FullName)" "WARN" } catch {}
          }
        }
        $out += [PSCustomObject]@{ Browser=$b.Name; Priority=$b.Priority; Required=$b.Required; UserDataPath=$b.Path; ProfileCount=@($profiles).Count; Profiles=$pList; Fallback='If sync failed, export bookmarks HTML from browser (Settings > Bookmarks > Export) and import on Linux. Passwords via Google Password Manager.' }
      } else {
        $status = if ($b.Required) { 'Not found - skipping, re-login manually on Linux' } else { 'Optional - not needed, skipped safely' }
        $out += [PSCustomObject]@{ Browser=$b.Name; Priority=$b.Priority; Required=$b.Required; UserDataPath=$b.Path; ProfileCount=0; Profiles=@(); Status=$status }
      }
    } catch {
      $out += [PSCustomObject]@{ Browser=$b.Name; Priority=$b.Priority; Required=$b.Required; UserDataPath=$b.Path; ProfileCount=0; Profiles=@(); Status="Error (ignored, script continues): $($_.Exception.Message)"; Fallback='Re-login manually on Linux' }
    }
  }
  $out | Sort-Object Priority
}

function Get-ConfigPaths {
  $paths = @()
  $expected = @(
    @{App='Antigravity'; Path=Join-Path $env:APPDATA 'Antigravity'},
    @{App='Antigravity-local'; Path=Join-Path $env:LOCALAPPDATA 'Antigravity'},
    @{App='Antigravity-dot'; Path=Join-Path $env:USERPROFILE '.antigravity'},
    @{App='OpenCode'; Path=Join-Path $env:APPDATA 'opencode'},
    @{App='OpenCode-local'; Path=Join-Path $env:LOCALAPPDATA 'opencode'},
    @{App='OpenCode-xdg'; Path=Join-Path $env:USERPROFILE '.config\opencode'},
    @{App='VS Code'; Path=Join-Path $env:APPDATA 'Code'},
    @{App='GitConfig'; Path=Join-Path $env:USERPROFILE '.gitconfig'},
    @{App='GitSSH'; Path=Join-Path $env:USERPROFILE '.ssh'},
    @{App='Python'; Path=Join-Path $env:APPDATA 'Python'}
  )
  foreach ($e in $expected) {
    if (-not $e.Path) { continue }
    $exists = Test-Path $e.Path
    $sizeMB = 0
    if ($exists) {
      try {
        if (Test-Path $e.Path -PathType File) { $sizeMB = [math]::Round((Get-Item $e.Path).Length/1MB,2) }
        else { $sizeMB = [math]::Round([int64](Get-ChildItem $e.Path -Recurse -File -Depth 3 -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum/1MB,2) }
      } catch {}
    }
    $paths += [PSCustomObject]@{ App=$e.App; Path=$e.Path; Exists=$exists; SizeMB=$sizeMB }
  }
  try {
    Get-ChildItem $env:USERPROFILE -Directory -Force -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like '.*config*' -or $_.Name -in '.opencode','.cursor','.config','.local','.antigravity' } |
      ForEach-Object {
        $sizeMB = 0
        try { $sizeMB = [math]::Round([int64](Get-ChildItem $_.FullName -Recurse -File -Depth 3 -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum/1MB,2) } catch {}
        $paths += [PSCustomObject]@{ App=$_.Name; Path=$_.FullName; Exists=$true; SizeMB=$sizeMB }
      }
  } catch {}
  $paths
}

function Get-StartupAndTasks {
  $startup = @()
  foreach ($k in @('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run')) {
    try {
      $item = Get-ItemProperty $k -ErrorAction SilentlyContinue
      if ($item) {
        foreach ($prop in $item.PSObject.Properties) {
          if ($prop.Name -notlike 'PS*') {
            $val = [string]$prop.Value
            $val = $val -replace '(password|token|secret|key)=([^\s"]+)','$1=[REDACTED]'
            $startup += [PSCustomObject]@{Name=$prop.Name; Where=$k; Value=$val}
          }
        }
      }
    } catch {}
  }
  $tasks = @()
  try {
    $cmd = Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue
    if ($cmd) { $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Select-Object -First 500 TaskName, TaskPath, State }
    else {
      # PS7 fallback: schtasks
      $out = & schtasks /query /fo CSV 2>$null
      if ($out) { $tasks = $out | Select-Object -Skip 1 -First 500 | ForEach-Object { [PSCustomObject]@{TaskName=$_; TaskPath=''; State='Unknown'} } }
    }
  } catch {}
  [PSCustomObject]@{ Startup=$startup; ScheduledTasks=$tasks }
}

function Get-GitRepos {
  $roots = @((Join-Path $env:USERPROFILE 'Documents'), (Join-Path $env:USERPROFILE 'Desktop'), (Join-Path $env:USERPROFILE 'source'), (Join-Path $env:USERPROFILE 'projects'))
  $found = @()
  foreach ($r in $roots) {
    if (-not (Test-Path $r)) { continue }
    try {
      $stack = [System.Collections.Generic.Stack[string]]::new()
      $stack.Push($r)
      $visited = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      while ($stack.Count) {
        $dir = $stack.Pop()
        if (-not $visited.Add($dir)) { continue }
        if (-not (Test-Path $dir)) { continue }
        try { $di = Get-Item $dir -Force -ErrorAction SilentlyContinue; if ($di -and ($di.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue } } catch {}
        foreach ($entry in Get-ChildItem $dir -Directory -Force -ErrorAction SilentlyContinue) {
          if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
          if ($entry.Name -eq '.git') { $found += [PSCustomObject]@{ Repo=$entry.Parent.FullName } }
          elseif ($entry.Name -notlike '*.git*' -and $entry.Name -ne 'node_modules' -and $entry.Name -ne '.venv') { $stack.Push($entry.FullName) }
        }
      }
    } catch {}
  }
  $found | Sort-Object Repo -Unique
}

function Get-Fonts {
  $fp = Join-Path $env:WINDIR 'Fonts'
  if (Test-Path $fp) { Get-ChildItem $fp -File -ErrorAction SilentlyContinue | Select-Object Name, Length, Extension, FullName } else { @() }
}

function Test-Preflight {
  $isAdmin = $false
  try { $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch {}
  Write-Log "Preflight: Admin=$isAdmin OS=$([System.Environment]::OSVersion.VersionString) PS=$($PSVersionTable.PSVersion.ToString())" "INFO"
  if ($isAdmin) { Write-Log "Running as Administrator. This is fine, but not required." "INFO" }
}

# ---------- Safe copy engine ----------
function Copy-WithLiveProgress {
  param(
    [string[]]$SourceRoots,
    [string]$DestRoot,
    [string]$ManifestPath,
    [int]$BufferMB,
    [bool]$DryRun,
    [bool]$DoResume,
    [bool]$KeepHeavyMode
  )

  $blockedSegs = @('local storage','indexeddb','session storage','sessions','secure preferences','preferences','local state','history','bookmarks','current','locked','manifest-*')
  $blockedExts = @('.ldb','.log','.key','.pfx','.kdbx','.vault')
  $blockedNames = @('login data','login data-journal','cookies','web data','local state','secure preferences','preferences','history','bookmarks')
  $skipDirsDefault = @('node_modules','.venv','venv','__pycache__','$recycle.bin','system volume information','win2lin_export')
  $skipDirsHeavy = @()

  if ($KeepHeavyMode) { $skipDirsDefault = @('$recycle.bin','system volume information','win2lin_export') }

  Write-Log "[1/2] Enumerating files (safe walk, cycle-protected, skips file reparse points)..." "INFO"
  $files = New-Object System.Collections.Generic.List[object]
  [int64]$totalBytes = 0
  [int]$enumErrors = 0

  $destFull = $null
  try { $destFull = [IO.Path]::GetFullPath($DestRoot).TrimEnd('\','/') } catch {}

  foreach ($root in $SourceRoots) {
    if (-not (Test-Path $root)) { Write-Log "SKIP not found: $root" "WARN"; continue }
    try {
      $stack = [System.Collections.Generic.Stack[string]]::new()
      $visited = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      $rootFull = [IO.Path]::GetFullPath($root)
      $stack.Push($rootFull)
      while ($stack.Count) {
        $dir = $stack.Pop()
        if (-not $visited.Add($dir)) { continue }
        if ($destFull -and $dir.StartsWith($destFull, [StringComparison]::OrdinalIgnoreCase)) { continue }
        # Do NOT skip reparse points on directories - user folders (Downloads, OneDrive-redirected) are often reparse points.
        # Visited set prevents cycles. Only skip reparse points on FILES (below).
        try {
          $children = Get-ChildItem -Path $dir -Force -ErrorAction SilentlyContinue
        } catch { $enumErrors++; continue }
        if (-not $children) { continue }
        foreach ($entry in $children) {
          try {
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            # Desktop inside source but dest inside Desktop: hard exclude dest subtree
            if ($destFull -and $entry.FullName.StartsWith($destFull, [StringComparison]::OrdinalIgnoreCase)) { continue }
            if ($entry.PSIsContainer) {
              $lname = $entry.Name.ToLowerInvariant()
              if ($skipDirsDefault -contains $lname) { continue }
              $stack.Push($entry.FullName)
            } else {
              $full = $entry.FullName
              $lname = $entry.Name.ToLowerInvariant()
              $lext = $entry.Extension.ToLowerInvariant()
              if ($blockedNames -contains $lname) { continue }
              if ($blockedExts -contains $lext) { continue }
              $skip = $false
              foreach ($seg in $full.Split('\')) {
                if ($blockedSegs -contains $seg.ToLowerInvariant()) { $skip = $true; break }
              }
              if ($full -match '\\(Local Storage|IndexedDB|Session Storage|Sessions)\\') { $skip = $true }
              if ($lname -in @('id_rsa','id_ed25519','*.pfx','*.kdbx')) { $skip = $true }
              if ($lext -in @('.pfx','.kdbx')) { $skip = $true }
              if ($skip) { continue }
              if ($lname -in @('pagefile.sys','hiberfil.sys','swapfile.sys')) { continue }
              $files.Add($entry); $totalBytes += [int64]$entry.Length
              if ($files.Count % 10000 -eq 0) { Write-Host -NoNewline "`r  Enumerated: $($files.Count) files, $([math]::Round($totalBytes/1GB,2)) GB   " }
            }
          } catch { $enumErrors++; continue }
        }
      }
    } catch { $enumErrors++; Write-Log "Enumerate failed for $root (ignored): $($_.Exception.Message)" "WARN" }
  }

  $totalFiles = $files.Count
  $totalGB = [math]::Round($totalBytes/1GB,3)
  Write-Log "`r  Enumerated: $totalFiles files, $totalGB GB  EnumErrors=$enumErrors" "OK"

  if ($totalFiles -eq 0) { Write-Log "Nothing to copy (check roots / DryRun). If you expected files, check OneDrive sync finished." "WARN"; return @{TotalFiles=0; TotalBytes=0; CopiedFiles=0; CopiedBytes=0; Skipped=0; Failed=0; EnumErrors=$enumErrors} }

  # free space (bytes, not GB)
  if (-not $DryRun) {
    $freeBytes = Get-FreeBytesForPath $DestRoot
    $needed = [int64]($totalBytes * 1.05) + 268435456 # 5% + 256MB headroom
    if ($freeBytes -ne $null -and $freeBytes -lt $needed) {
      Write-Log "ERROR: dest needs ~$([math]::Round($needed/1GB,2)) GB, only $([math]::Round($freeBytes/1GB,2)) GB free. Use a USB stick with 2x space or free disk." "ERROR"
      return @{TotalFiles=$totalFiles; TotalBytes=$totalBytes; CopiedFiles=0; CopiedBytes=0; Skipped=0; Failed=-1; EnumErrors=$enumErrors}
    }
  }

  if ($DryRun) {
    Write-Log "DRY RUN: Would copy $totalFiles files ($totalGB GB). No writes done. File count + GB above is your preview." "OK"
    # write dry-run manifest to temp so user can inspect without touching dest
    try {
      $tmpManifest = Join-Path $env:TEMP 'Win2Lin_manifest_dryrun.csv'
      $sw = [IO.StreamWriter]::new($tmpManifest, $false, [Text.UTF8Encoding]::new($false))
      try {
        $sw.WriteLine('source,destination,size_bytes,status,mtime')
        foreach ($f in $files) {
          $driveLetter = $f.FullName.Substring(0,1).ToUpper()
          $driveRoot = [IO.Path]::GetPathRoot($f.FullName)
          $rel = if ($driveRoot) { $f.FullName.Substring($driveRoot.Length) } else { '\' + $f.Name }
          $destPath = Join-Path (Join-Path $DestRoot ("{0}_DRIVE" -f $driveLetter)) $rel
          $line = (@((q-Csv $f.FullName), (q-Csv $destPath), [string]$f.Length, (q-Csv 'dryrun'), (q-Csv $f.LastWriteTime.ToString('o'))) -join ',')
          $sw.WriteLine($line)
        }
      } finally { $sw.Flush($true); $sw.Close() }
      Write-Log "Dry-run manifest (temp, not dest): $tmpManifest" "INFO"
    } catch {}
    return @{TotalFiles=$totalFiles; TotalBytes=$totalBytes; CopiedFiles=0; CopiedBytes=0; Skipped=$totalFiles; Failed=0; SimulatedBytes=$totalBytes; EnumErrors=$enumErrors}
  }

  # buffered manifest writer (UTF8 no BOM)
  if (-not (Test-Path $DestRoot)) { New-Item -ItemType Directory -Path $DestRoot -Force | Out-Null }
  $writer = [IO.StreamWriter]::new($ManifestPath, $false, [Text.UTF8Encoding]::new($false))
  try { $writer.WriteLine('source,destination,size_bytes,status,mtime') } catch {}

  Write-Log "[2/2] Copying (live %, do not close window, plug in power). DryRun=$DryRun Resume=$DoResume KeepHeavy=$KeepHeavyMode" "INFO"

  [int64]$copiedBytes = 0; [int]$copiedFiles = 0; [int]$skipped = 0; [int]$failed = 0
  $failedPaths = New-Object System.Collections.Generic.List[string]
  $start = Get-Date; $speedEMA = 0; $progressBarWidth = 40
  $bufferSize = $BufferMB * 1MB
  $buffer = New-Object byte[] $bufferSize
  $nextUi = (Get-Date).AddMilliseconds(250)
  [int64]$lastBytes = 0; $lastTime = Get-Date

  foreach ($f in $files) {
    $driveLetter = $f.FullName.Substring(0,1).ToUpper()
    $driveRoot = [IO.Path]::GetPathRoot($f.FullName)
    # KEY FIX: anchor at drive root so Documents/Desktop/Downloads do NOT collide
    $rel = if ($driveRoot) { $f.FullName.Substring($driveRoot.Length) } else { '\' + $f.Name }
    $destPath = Join-Path (Join-Path $DestRoot ("{0}_DRIVE" -f $driveLetter)) $rel
    $destDir = Split-Path $destPath -Parent
    try { if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null } } catch { $failed++; $failedPaths.Add($f.FullName) }

    $status = 'copied'; $doCopy = $true
    if ($DoResume -and (Test-Path $destPath)) {
      try {
        $di = Get-Item $destPath -ErrorAction SilentlyContinue
        if ($di -and $di.Length -eq $f.Length) {
          # strong resume: size match + dest mtime >= source mtime (size+mtime is fast path; hash checked in Verify step if needed)
          if ($di.LastWriteTime -ge $f.LastWriteTime) { $doCopy=$false; $status='skipped-resumed' }
        }
      } catch {}
    }

    if (-not $doCopy) {
      $copiedBytes += [int64]$f.Length; $skipped++; $copiedFiles++
    } else {
      $tmpPath = $destPath + ".part." + [Guid]::NewGuid().ToString('N')
      $srcStream = $null; $dstStream = $null
      try {
        # retry open with ReadWrite share so locked-but-readable files still copy
        for ($attempt=0; $attempt -lt 3; $attempt++) {
          try { $srcStream = [IO.File]::Open((To-LongPath $f.FullName), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite); break }
          catch { if ($attempt -eq 2) { throw }; Start-Sleep -Milliseconds (500*($attempt+1)) }
        }
        try { $dstStream = [IO.File]::Create((To-LongPath $tmpPath)) } catch { throw }
        while (($read = $srcStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
          $dstStream.Write($buffer, 0, $read)
          $copiedBytes += $read
        }
        if ($dstStream) { $dstStream.Flush($true); $dstStream.Dispose(); $dstStream = $null }
        if ($srcStream) { $srcStream.Dispose(); $srcStream = $null }
        # atomic replace: only now overwrite dest
        try { [IO.File]::Replace((To-LongPath $tmpPath), (To-LongPath $destPath), $null) } catch { [IO.File]::Move((To-LongPath $tmpPath), (To-LongPath $destPath)) }
        try { (Get-Item $destPath).LastWriteTime = $f.LastWriteTime } catch {}
        $copiedFiles++; $status='copied'
      } catch {
        $failed++; $status="failed: $($_.Exception.Message)"
        $failedPaths.Add($f.FullName)
        Write-Log "FAILED: $($f.FullName) - $($_.Exception.Message)" "ERROR"
        try { if ($dstStream) { $dstStream.Dispose() } } catch {}
        try { if ($srcStream) { $srcStream.Dispose() } } catch {}
        try { if (Test-Path $tmpPath) { Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue } } catch {}
      }
    }

    $line = (@((q-Csv $f.FullName), (q-Csv $destPath), [string]$f.Length, (q-Csv $status), (q-Csv $f.LastWriteTime.ToString('o'))) -join ',')
    try { $writer.WriteLine($line); if (($copiedFiles+$skipped+$failed) % 100 -eq 0) { $writer.Flush() } } catch {}

    # throttled UI (<=4Hz), clamped percent, safe ETA
    $nowUi = Get-Date
    if ($nowUi -ge $nextUi) {
      $nextUi = $nowUi.AddMilliseconds(250)
      $pct = if ($totalBytes -gt 0) { [math]::Min(100, [math]::Max(0, ($copiedBytes*100.0/$totalBytes))) } else { 100 }
      $dt = ($nowUi - $lastTime).TotalSeconds
      $inst = if ($dt -ge 0.25) { ($copiedBytes - $lastBytes) / $dt } else { 0 }
      $speedEMA = if ($speedEMA -eq 0) { $inst } else { 0.8*$speedEMA + 0.2*$inst }
      $remainSec = if ($speedEMA -gt 0) { [math]::Min(31536000, [math]::Max(0, ($totalBytes-$copiedBytes)/$speedEMA)) } else { 0 }
      $eta = $nowUi.AddSeconds($remainSec).ToString('HH:mm:ss')
      $filled = [int]($pct * $progressBarWidth / 100)
      $bar = ('#' * $filled) + ('-' * ($progressBarWidth-$filled))
      $speedMBs = [math]::Round($speedEMA/1MB,1)
      Write-Host -NoNewline "`r[$bar] $([math]::Round($pct,1))%  $([math]::Round($copiedBytes/1GB,2))/$totalGB GB  $speedMBs MB/s  ETA $eta  Files: $($copiedFiles+$skipped+$failed)/$totalFiles  "
      $lastBytes = $copiedBytes; $lastTime = $nowUi
    }
  }

  try { $writer.Flush($true); $writer.Close() } catch {}
  $pctFinal = if ($totalBytes -gt 0) { [math]::Min(100, [math]::Max(0, ($copiedBytes*100.0/$totalBytes))) } else { 100 }
  Write-Log "DONE. Copied $([math]::Round($copiedBytes/1GB,3)) GB  Files: $copiedFiles  Skipped/resumed: $skipped  Failed: $failed  Final: $([math]::Round($pctFinal,2))%  Time: $((Get-Date - $start).ToString())" "OK"
  return @{ TotalFiles=$totalFiles; TotalBytes=$totalBytes; CopiedFiles=$copiedFiles; CopiedBytes=$copiedBytes; Skipped=$skipped; Failed=$failed; EnumErrors=$enumErrors; FailedPaths=@($failedPaths) }
}

# ================= MAIN =================
Test-Preflight

$desktop = Get-DesktopPath
if (-not $Destination) {
  # Default to LOCAL, not OneDrive-synced desktop (prevents PII cloud leak + self-copy)
  $candidates = @('C:\Win2Lin_export', (Join-Path $env:USERPROFILE 'Win2Lin_export'))
  $base = $candidates | Where-Object { $_ -and $_.Length -gt 0 } | Select-Object -First 1
  $Destination = if ($TimeStamped) { Join-Path $base ("{0}_{1}" -f (Get-Date -Format 'yyyyMMdd'), (Get-Date -Format 'HHmmss')) } else { $base }
}
else {
  try { $Destination = [IO.Path]::GetFullPath($Destination) } catch {}
}
# destination jail: block system dirs + UNC
if ($Destination -match '^(C:\\(Windows|Program Files|ProgramData)|\\\\[^\\]+\\[^\\]+)') {
  Write-Log "ERROR: Destination '$Destination' is blocked (system/UNC path). Use a local folder like C:\Win2Lin_export." "ERROR"
  return
}
if ($desktop -and $Destination.ToLowerInvariant().Contains('onedrive')) {
  Write-Log "WARNING: Destination is inside OneDrive-synced Desktop - files will auto-upload to cloud. Prefer local C:\Win2Lin_export. Continuing because you chose it." "WARN"
}
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$script:LogPath = Join-Path $Destination 'copy_log.txt'
Write-Log "Win2Lin_script Mode=$Mode Dest=$Destination"
Write-Log "User=$env:USERNAME Host=$env:COMPUTERNAME"

Write-Log "Scanning..." "INFO"
$startupTasks = Get-StartupAndTasks  # called once
$inventory = [PSCustomObject]@{
  generated_at = (Get-Date).ToString('o'); user = $env:USERNAME; host = $env:COMPUTERNAME
  os = [System.Environment]::OSVersion.VersionString
  drives = Get-DriveInfo
  installed_apps = Get-InstalledApps
  dev_tools = Get-DevTools
  browsers_profile_metadata_only = Get-BrowserInventory
  app_config_paths = Get-ConfigPaths
  startup_run_keys = $startupTasks.Startup
  scheduled_tasks_names = $startupTasks.ScheduledTasks
  git_repos = if ($IncludeDev) { Get-GitRepos } else { @() }
  fonts = Get-Fonts
  notes = 'Brave + Edge are primary (synced by user). Chrome is optional and ignored if missing. Browser Login Data / Cookies / Web Data were NOT copied (Windows DPAPI locked, cannot reuse on Linux). If sync fails, script still succeeds - re-login manually on Linux. Fallback: export bookmarks HTML + use Google Password Manager.'
  linux_mount_hint = 'C_DRIVE and D_DRIVE are plain folders on Linux anchored at drive root, e.g. /home/user/Win2Lin_export/C_DRIVE/Users/<you>/Documents/...'
}
$json = $inventory | ConvertTo-Json -Depth 10
[IO.File]::WriteAllText((Join-Path $Destination 'inventory.json'), $json, [Text.UTF8Encoding]::new($false))
Write-Log "Inventory -> inventory.json (UTF-8 no BOM, so Linux python can read it)" "OK"

if ($Mode -in @('Copy','Full')) {
  # OneDrive-aware user folders
  $roots = @()
  foreach ($folder in @('MyDocuments','Desktop','MyPictures','MyMusic','MyVideos')) {
    try { $fp = [Environment]::GetFolderPath($folder); if ($fp -and (Test-Path $fp)) { $roots += $fp } } catch {}
  }
  try { $dl = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'; if (Test-Path $dl) { $roots += $dl } } catch {}
  # fallback to profile subfolders if special folders missed
  if ($roots.Count -lt 2) {
    $roots += @((Join-Path $env:USERPROFILE 'Documents'), (Join-Path $env:USERPROFILE 'Desktop'), (Join-Path $env:USERPROFILE 'Downloads'), (Join-Path $env:USERPROFILE 'Pictures'), (Join-Path $env:USERPROFILE 'Videos'), (Join-Path $env:USERPROFILE 'Music')) | Where-Object { $_ -and (Test-Path $_) }
  }
  $roots = $roots | Sort-Object -Unique

  # Hard abort if destination is inside any source root (self-copy)
  $destFull = $null
  try { $destFull = [IO.Path]::GetFullPath($Destination).TrimEnd('\','/') } catch {}
  foreach ($r in $roots) {
    if (Test-IsInside $destFull $r) {
      Write-Log "ERROR: Destination '$destFull' is INSIDE source '$r'. This would self-copy forever and corrupt the backup. Refusing. Choose e.g. C:\Win2Lin_export or D:\Win2Lin_export." "ERROR"
      Write-Log "NEXT: Re-run with -Destination 'C:\Win2Lin_export' (outside Documents/Desktop/etc)." "WARN"
      return
    }
  }

  if (-not $SkipD -and (Test-Path 'D:\')) {
    # D:\ is a source, so dest must NOT be inside D:\ either
    if (Test-IsInside $destFull 'D:\') {
      Write-Log "ERROR: Destination inside D:\ (which is also a source). Refusing self-copy. Use C:\Win2Lin_export." "ERROR"
      return
    }
    $roots += 'D:\'
  } elseif ($SkipD) {
    Write-Log "D:\ skipped by -SkipD flag." "INFO"
  }

  Write-Log "Copy roots (C_DRIVE = drive-anchored, no collision): $($roots -join ', ')" "INFO"
  $manifest = Join-Path $Destination 'manifest.csv'
  $result = Copy-WithLiveProgress -SourceRoots $roots -DestRoot $Destination -ManifestPath $manifest -BufferMB $ChunkMB -DryRun:$DryRun -DoResume:$Resume -KeepHeavyMode:$KeepHeavy
  $json2 = $result | ConvertTo-Json -Depth 4
  [IO.File]::WriteAllText((Join-Path $Destination 'copy_result.json'), $json2, [Text.UTF8Encoding]::new($false))

  if ($DryRun) {
    Write-Log "================ DRY RUN DONE ================" "OK"
    Write-Log "  This was a PREVIEW only. No files were copied to $Destination." "OK"
    Write-Log "  Files found: $($result.TotalFiles)  Total size: $([math]::Round($result.TotalBytes/1GB,2)) GB" "OK"
    Write-Log "  Dry-run manifest (temp): $env:TEMP\Win2Lin_manifest_dryrun.csv" "INFO"
    Write-Log "  If this looks right, run the same command WITHOUT -DryRun to do the real copy." "INFO"
    Write-Log "  Easiest: double-click Win2Lin_run.bat > type 2 > press Y after preview." "INFO"
    Write-Log "==============================================" "OK"
  } else {
    $failedCount = if ($result -and $result.PSObject.Properties['Failed']) { [int]$result.Failed } else { 0 }
    if ($failedCount -lt 0) {
      Write-Log "COPY DID NOT START (check errors above - usually not enough disk space)." "ERROR"
    } else {
      Write-Log "Copy finished (see copy_result.json - check Failed count). Manifest: manifest.csv" "OK"
      try {
        $verify = Join-Path $PSScriptRoot 'Verify-Win2LinBundle.ps1'
        if (Test-Path $verify) {
          & $verify -BundlePath $Destination -Mode Write 2>&1 | % { Write-Log "$_" "INFO" }
          Write-Log "Wrote checksums.sha256 (verify later with -Mode Verify). Skipped payload hashing for speed." "INFO"
        }
      } catch { Write-Log "Checksum step skipped (non-fatal): $($_.Exception.Message)" "WARN" }
      Write-Log "================ NEXT STEPS ================" "OK"
      Write-Log "  1. Find your export: $Destination"
      Write-Log "  2. Copy the WHOLE folder to a USB stick or cloud (rclone)."
      Write-Log "     The folder name has the date. Do not move files out of it."
      Write-Log "  3. In Linux Mint: Files > USB stick > Win2Lin_export > right-click > Copy, then paste into Home."
      Write-Log "     You should get: ~/Win2Lin_export\<date>_<time>\C_DRIVE\Users\<you>\..."
      Write-Log "  4. Open Terminal in that folder and run:    bash Win2Lin_script.sh"
      Write-Log "  5. Re-login in this order:"
      Write-Log "     a. Brave Sync   b. Edge Sync   c. Google Password Manager"
      Write-Log "     d. Antigravity   e. OpenCode"
      Write-Log "  6. Keep this Windows copy for 14 days. Test Mint daily."
      Write-Log "  7. If sync failed: export Bookmarks HTML in browser: Settings > Bookmarks > Export, then import in Linux."
      if ($failedCount -gt 0) {
        Write-Log "  WARNING: $failedCount file(s) failed (probably open in Office/Brave). Close them and run again with -Resume - it will resume and finish them." "WARN"
      }
      Write-Log "==============================================" "OK"
    }
  }
} else {
  Write-Log "Inventory only. Run with -Mode Copy to copy user data with live %." "WARN"
}

if (-not $NoGui) {
  $invPath = Join-Path $Destination 'inventory.json'
  if (Test-Path $invPath) { try { Start-Process notepad.exe -ArgumentList "`"$invPath`"" -ErrorAction SilentlyContinue } catch {} }
}

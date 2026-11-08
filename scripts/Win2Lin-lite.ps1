#Requires -Version 5.1
# Win2Lin_script_lite.ps1 - Simple, safe Windows -> Linux export (uses robocopy)
# Less code, fewer bugs. Does: inventory scan + robocopy of your user folders.
# Does NOT copy: browser passwords/cookies (use Brave/Edge Sync), Windows system folders.
# Usage:
#   .\Win2Lin_script_lite.ps1 -Mode Inventory
#   .\Win2Lin_script_lite.ps1 -Mode Copy
#   .\Win2Lin_script_lite.ps1 -Mode Copy -DryRun
[CmdletBinding()]
param(
  [ValidateSet('Inventory','Copy')][string]$Mode = 'Inventory',
  [string]$Destination = '',
  [switch]$DryRun,
  [switch]$SkipD
)
$ErrorActionPreference = 'Continue'
$script:LogPath = $null

function Log([string]$m,[string]$l='INFO'){ $t=(Get-Date -Format 'HH:mm:ss'); Write-Host "[$t][$l] $m"; if($script:LogPath){ try{ Add-Content $script:LogPath "[$t][$l] $m" -Encoding UTF8 }catch{} } }

# --- destination (local, not OneDrive) ---
if (-not $Destination) { $Destination = "C:\Win2Lin_export\$(Get-Date -Format 'yyyyMMdd_HHmmss')" }
try { $Destination = [IO.Path]::GetFullPath($Destination) } catch {}
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$script:LogPath = Join-Path $Destination 'log.txt'
Log "Mode=$Mode Dest=$Destination"

# --- quick inventory (simple, forgiving) ---
$inv = [ordered]@{
  generated=(Get-Date).ToString('o'); user=$env:USERNAME; host=$env:COMPUTERNAME
  drives = @(Get-PSDrive -PSProvider FileSystem -EA SilentlyContinue | ?{$_.Used -ne $null} | %{ [ordered]@{Name=$_.Name;UsedGB=[math]::Round($_.Used/1GB,1);FreeGB=[math]::Round($_.Free/1GB,1)} })
  dev_tools = @(@('git','node','bun','python','code','docker','codex','opencode') | %{ $c=Get-Command $_ -EA SilentlyContinue|Select -First 1; [ordered]@{Tool=$_;Found=[bool]$c;Path=if($c){$c.Source}else{''}} })
  notes = 'Lite version. Browser passwords/cookies NOT copied (Windows-locked). Use Brave/Edge Sync + Google Password Manager. Re-login on Linux.'
}
$invJson = $inv | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $Destination 'inventory.json'), $invJson, [Text.UTF8Encoding]::new($false))
Log "Inventory -> inventory.json"

if ($Mode -ne 'Copy') { Log "Done (inventory only). Run with -Mode Copy to copy files."; return }

# --- copy roots ---
$roots = @()
foreach($f in @('MyDocuments','Desktop','MyPictures','MyMusic','MyVideos')){ try{ $p=[Environment]::GetFolderPath($f); if($p -and (Test-Path $p)){ $roots += [pscustomobject]@{Path=$p;Drive='C'} } }catch{} }
try{ $dl=Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'; if(Test-Path $dl){ $roots += [pscustomobject]@{Path=$dl;Drive='C'} } }catch{}
$roots = $roots | Sort-Object Path -Unique
if(-not $SkipD -and (Test-Path 'D:\')){ $roots += [pscustomobject]@{Path='D:\';Drive='D'} }

# self-copy guard
$destFull = [IO.Path]::GetFullPath($Destination).TrimEnd('\','/')
foreach($r in $roots){
  $rFull = [IO.Path]::GetFullPath($r.Path).TrimEnd('\','/')
  if($destFull -eq $rFull -or $destFull.StartsWith($rFull+'\',[StringComparison]::OrdinalIgnoreCase)){
    Log "ERROR: Destination is inside source '$($r.Path)'. Refusing. Use C:\Win2Lin_export." "ERROR"; return
  }
}

# exclude dirs/files (heavy/useless on Linux; credential-ish names as defense-in-depth)
$xd = @('node_modules','.venv','venv','__pycache__','$RECYCLE.BIN','System Volume Information','Win2Lin_export','Cache','Code Cache','GPUCache')
$xf = @('pagefile.sys','hiberfil.sys','swapfile.sys','*.tmp','desktop.ini')

Log "Copying with robocopy (built-in, robust). DryRun=$DryRun"
$totalOk = 0; $totalFail = 0
foreach($r in $roots){
  $driveRoot = [IO.Path]::GetPathRoot($r.Path)
  $rel = if($driveRoot){ $r.Path.Substring($driveRoot.Length) } else { $r.Path.TrimStart('\') }
  $dest = Join-Path (Join-Path $Destination ("$($r.Drive)_DRIVE")) $rel
  New-Item -ItemType Directory -Path $dest -Force | Out-Null
  Log "  $($r.Path)  ->  $dest"
  $args = @("`"$($r.Path)`"","`"$dest`"","/E","/R:1","/W:1","/XJ","/NFL","/NDL","/NP","/XD") + ($xd | %{ "`"$_`"" }) + @("/XF") + ($xf | %{ "`"$_`"" })
  if($DryRun){ $args += '/L' }
  $logFile = Join-Path $Destination ("robocopy_$($r.Drive)_$([IO.Path]::GetFileName($r.Path) -replace '[^a-zA-Z0-9]','_').log")
  $args += @("/LOG+:`"$logFile`"")
  try {
    $p = Start-Process -FilePath robocopy.exe -ArgumentList $args -Wait -PassThru -NoNewWindow
    $code = $p.ExitCode
    # robocopy: 0-7 = success/warnings, >=8 = failure
    if($code -le 7){ $totalOk++; Log "    robocopy exit=$code (OK)" "OK" }
    else { $totalFail++; Log "    robocopy exit=$code (errors, see $logFile)" "WARN" }
  } catch { $totalFail++; Log "    robocopy failed: $($_.Exception.Message)" "ERROR" }
}

if($DryRun){ Log "DRY RUN done. No files copied. Remove -DryRun to copy for real." "OK" }
else { Log "Done. OK=$totalOk Failed=$totalFail. Check log.txt and robocopy_*.log" "OK" }
Log "NEXT: copy '$Destination' to USB -> Linux -> run Win2Lin_script.sh"
Log "RE-LOGIN on Linux: 1) Brave Sync 2) Edge Sync 3) Google Password Manager 4) Antigravity 5) OpenCode"

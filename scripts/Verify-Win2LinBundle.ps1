#Requires -Version 5.1
<#
.SYNOPSIS
  Verify or create SHA-256 checksums for a Win2Lin export bundle.
.DESCRIPTION
  Supports backup/sync verification and disaster recovery integrity checks.
  -Mode Write: writes checksums.sha256 (relative paths) for key files / all files (configurable).
  -Mode Verify: verifies checksums.sha256 or a provided checksum file.
  Never reads or exports secrets; operates only on existing bundle files.
.PARAMETER BundlePath
  Path to the Win2Lin export folder (contains inventory.json, C_DRIVE/, etc.)
.PARAMETER Mode
  Write or Verify.
.PARAMETER ChecksumFile
  Checksum file name/path. Default: checksums.sha256 in BundlePath.
.PARAMETER IncludePayload
  When writing, include C_DRIVE/D_DRIVE payload files (can be slow for large bundles). Default: false (writes checksums for metadata/manifests only).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$BundlePath,
  [ValidateSet('Write','Verify')][string]$Mode = 'Verify',
  [string]$ChecksumFile = '',
  [switch]$IncludePayload
)
$ErrorActionPreference = 'Stop'
function Resolve-Normal([string]$p) { try { [IO.Path]::GetFullPath($p).TrimEnd('\','/') } catch { $p } }
$bundle = Resolve-Normal $BundlePath
if (-not (Test-Path $bundle)) { throw "BundlePath not found: $bundle" }
if (-not $ChecksumFile) { $ChecksumFile = Join-Path $bundle 'checksums.sha256' }
else { try { $ChecksumFile = [IO.Path]::GetFullPath($ChecksumFile) } catch {} }

function Get-BundleFiles([string]$root, [bool]$payload) {
  $files = New-Object System.Collections.Generic.List[string]
  $meta = @('inventory.json','manifest.csv','copy_result.json','log.txt','copy_log.txt','migration-report.md','migration-plan.json')
  foreach ($m in $meta) { $p = Join-Path $root $m; if (Test-Path $p) { $files.Add($p) } }
  Get-ChildItem -Path $root -Filter 'robocopy_*.log' -File -ErrorAction SilentlyContinue | % { $files.Add($_.FullName) }
  if ($payload) {
    foreach ($d in @('C_DRIVE','D_DRIVE')) {
      $dp = Join-Path $root $d
      if (Test-Path $dp) {
        Get-ChildItem -Path $dp -Recurse -File -Force -ErrorAction SilentlyContinue | ? { $_.Name -notlike '*.part.*' } | % { $files.Add($_.FullName) }
      }
    }
  }
  $files | Sort-Object -Unique
}

if ($Mode -eq 'Write') {
  $targets = Get-BundleFiles $bundle $IncludePayload.IsPresent
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($f in $targets) {
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $f).Hash.ToLowerInvariant()
    $rel = $f.Substring($bundle.Length).TrimStart('\','/').Replace('\','/')
    $lines.Add("$hash *$rel")
  }
  [IO.File]::WriteAllLines($ChecksumFile, $lines, [Text.UTF8Encoding]::new($false))
  Write-Host "Wrote $($lines.Count) checksums -> $ChecksumFile"
  if (-not $IncludePayload) { Write-Host "Note: payload (C_DRIVE/D_DRIVE) not included. Use -IncludePayload for full bundle checksums (slow)." }
  exit 0
}

# Verify
if (-not (Test-Path $ChecksumFile)) { throw "Checksum file not found: $ChecksumFile" }
$script:_ok=0; $script:_bad=0; $script:_missing=0
Get-Content -LiteralPath $ChecksumFile -Encoding UTF8 | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith('#')) { return }
  if ($line -match '^([a-fA-F0-9]{64})\s+\*?(.+)$') {
    $expected = $Matches[1].ToLowerInvariant(); $rel = $Matches[2].Trim().Replace('/','\')
    $path = Join-Path $bundle $rel
    if (-not (Test-Path -LiteralPath $path)) { Write-Host "MISSING: $rel"; $script:_missing++; return }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    if ($actual -eq $expected) { $script:_ok++ } else { Write-Host "BAD: $rel (expected $expected got $actual)"; $script:_bad++ }
  }
}
Write-Host "Verify: OK=$($script:_ok) BAD=$($script:_bad) MISSING=$($script:_missing) ($ChecksumFile)"
if ($script:_bad -gt 0 -or $script:_missing -gt 0) { exit 2 }
exit 0

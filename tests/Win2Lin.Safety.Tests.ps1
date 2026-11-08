# Pester tests - compatible with Pester 3.4 (Windows PowerShell 5.1) and Pester 5+.
# Run: Invoke-Pester .\tests
# Uses temp dirs + fake bundles only. No real user data.

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function New-TempDir {
  $p = Join-Path ([IO.Path]::GetTempPath()) ('win2lin-pester-' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $p -Force | Out-Null
  return $p
}

function New-FakeBundle($TempRoot, $Name) {
  $b = Join-Path $TempRoot $Name
  New-Item -ItemType Directory -Path (Join-Path $b 'C_DRIVE\Users\Test\Documents') -Force | Out-Null
  "hello" | Set-Content -LiteralPath (Join-Path $b 'C_DRIVE\Users\Test\Documents\a.txt') -Encoding UTF8
  $inv = @{
    generated_at = (Get-Date).ToString('o'); user='Test'; host='TestPC'
    drives = @(@{Name='C';UsedGB=10;FreeGB=90;TotalGB=100})
    installed_apps = @(@{Name='VS Code'}, @{Name='Git'})
    dev_tools = @(@{Tool='git';Found=$true;Version='2.0'})
    browsers_profile_metadata_only = @(@{Browser='Brave';ProfileCount=1})
  }
  ($inv | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath (Join-Path $b 'inventory.json') -Encoding UTF8
  return $b
}

function Invoke-VerifiedBundle($Mode, $Bundle) {
  # Run Verify in separate process so `exit` codes are real and Pester is not killed.
  $script = Join-Path $script:RepoRoot 'scripts\Verify-Win2LinBundle.ps1'
  $out = powershell -ExecutionPolicy Bypass -NoProfile -File $script -BundlePath $Bundle -Mode $Mode 2>&1
  return @{ Output = ($out | Out-String); ExitCode = $LASTEXITCODE }
}

Describe 'Verify-Win2LinBundle (checksums)' {
  It 'writes and verifies metadata checksums' {
    $tmp = New-TempDir
    try {
      $b = New-FakeBundle $tmp 'bundle_write_verify'
      $w = Invoke-VerifiedBundle 'Write' $b
      $w.ExitCode | Should Be 0
      (Test-Path (Join-Path $b 'checksums.sha256')) | Should Be $true
      $v = Invoke-VerifiedBundle 'Verify' $b
      $v.ExitCode | Should Be 0
      $v.Output | Should Match 'BAD=0'
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
  }

  It 'detects tampering with exit 2' {
    $tmp = New-TempDir
    try {
      $b = New-FakeBundle $tmp 'bundle_tamper'
      Invoke-VerifiedBundle 'Write' $b | Out-Null
      "tampered" | Set-Content -LiteralPath (Join-Path $b 'inventory.json') -Encoding UTF8
      $v = Invoke-VerifiedBundle 'Verify' $b
      $v.ExitCode | Should Be 2
      $v.Output | Should Match 'BAD='
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
  }

  It 'detects missing files with exit 2' {
    $tmp = New-TempDir
    try {
      $b = New-FakeBundle $tmp 'bundle_missing'
      Invoke-VerifiedBundle 'Write' $b | Out-Null
      Remove-Item (Join-Path $b 'inventory.json') -Force
      $v = Invoke-VerifiedBundle 'Verify' $b
      $v.ExitCode | Should Be 2
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
  }
}

Describe 'Migration report generation' {
  It 'generates safety + identity + accessibility sections' {
    $tmp = New-TempDir
    try {
      $b = New-FakeBundle $tmp 'bundle_report'
      & (Join-Path $script:RepoRoot 'scripts\New-Win2LinReport.ps1') -BundlePath $b | Out-Null
      $rep = Join-Path $b 'migration-report.md'
      (Test-Path $rep) | Should Be $true
      $raw = [IO.File]::ReadAllText($rep)
      $raw | Should Match 'Never copied'
      $raw | Should Match 'Identity'
      $raw | Should Match 'Accessibility checklist'
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
  }

  It 'fails on missing inventory.json' {
    $tmp = New-TempDir
    try {
      $b = Join-Path $tmp 'bundle_no_inv'
      New-Item -ItemType Directory -Path $b -Force | Out-Null
      $threw = $false
      try { & (Join-Path $script:RepoRoot 'scripts\New-Win2LinReport.ps1') -BundlePath $b } catch { $threw = $true }
      $threw | Should Be $true
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
  }
}

Describe 'Recovery kit generation' {
  It 'generates recovery-checklist.md' {
    $tmp = New-TempDir
    try {
      $b = New-FakeBundle $tmp 'bundle_recovery'
      & (Join-Path $script:RepoRoot 'scripts\New-Win2LinRecoveryKit.ps1') -BundlePath $b | Out-Null
      (Test-Path (Join-Path $b 'recovery-checklist.md')) | Should Be $true
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
  }
}

Describe 'Lite exporter (dry-run only)' {
  It 'Inventory creates inventory.json' {
    $tmp = New-TempDir
    try {
      $dest = Join-Path $tmp 'lite_inv'
      & (Join-Path $script:RepoRoot 'scripts\Win2Lin-lite.ps1') -Mode Inventory -Destination $dest | Out-Null
      (Test-Path (Join-Path $dest 'inventory.json')) | Should Be $true
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
  }

  It 'DryRun with SkipD does not copy payload' {
    $tmp = New-TempDir
    try {
      $dest = Join-Path $tmp 'lite_dry'
      & (Join-Path $script:RepoRoot 'scripts\Win2Lin-lite.ps1') -Mode Copy -DryRun -SkipD -Destination $dest | Out-Null
      $payload = Join-Path $dest 'C_DRIVE'
      if (Test-Path $payload) {
        @(Get-ChildItem $payload -Recurse -File -ErrorAction SilentlyContinue).Count | Should Be 0
      } else {
        $true | Should Be $true
      }
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
  }
}

Describe 'Self-copy guard logic' {
  It 'detects destination inside source' {
    $tmp = New-TempDir
    try {
      $src = Join-Path $tmp 'src\Documents'
      New-Item -ItemType Directory -Path $src -Force | Out-Null
      $dest = Join-Path $src 'Win2Lin_export'
      $destFull = [IO.Path]::GetFullPath($dest).TrimEnd('\','/')
      $rFull = [IO.Path]::GetFullPath($src).TrimEnd('\','/')
      ($destFull -eq $rFull -or $destFull.StartsWith($rFull+'\',[StringComparison]::OrdinalIgnoreCase)) | Should Be $true
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
  }
}

Describe 'Safety boundaries' {
  It 'required safety docs exist' {
    (Test-Path (Join-Path $script:RepoRoot 'SECURITY.md')) | Should Be $true
    (Test-Path (Join-Path $script:RepoRoot 'specs\bundle-format.md')) | Should Be $true
  }

  It 'lite exporter roots include user folders (no AppData browser profile roots)' {
    $raw = [IO.File]::ReadAllText((Join-Path $script:RepoRoot 'scripts\Win2Lin-lite.ps1'))
    ($raw -match 'MyDocuments') | Should Be $true
    ($raw -match 'BraveSoftware.*User Data') | Should Be $false
  }
}

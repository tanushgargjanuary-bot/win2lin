# Pester 3.4-compatible smoke tests for Verify-Win2LinBundle (PS + optional Rust interop note).
Describe 'Verify bundle (PowerShell tool)' {
  It 'writes + verifies metadata checksums' {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('win2lin-verify-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
      "hello" | Set-Content -LiteralPath (Join-Path $tmp 'inventory.json') -Encoding UTF8
      $script = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'scripts\Verify-Win2LinBundle.ps1'
      & $script -BundlePath $tmp -Mode Write | Out-Null
      (Test-Path (Join-Path $tmp 'checksums.sha256')) | Should Be $true
      & $script -BundlePath $tmp -Mode Verify | Out-Null
      $LASTEXITCODE | Should Be 0
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
  }
}

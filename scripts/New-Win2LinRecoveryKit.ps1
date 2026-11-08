#Requires -Version 5.1
<#
.SYNOPSIS
  Create a small disaster-recovery checklist next to a Win2Lin bundle.
.DESCRIPTION
  Reads inventory.json and writes recovery-checklist.md. No secrets.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$BundlePath,
  [string]$OutputPath = ''
)
$ErrorActionPreference = 'Stop'
$bundle = try { [IO.Path]::GetFullPath($BundlePath) } catch { $BundlePath }
$invPath = Join-Path $bundle 'inventory.json'
if (-not (Test-Path $invPath)) { throw "inventory.json not found in $bundle" }
$inv = Get-Content -LiteralPath $invPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $OutputPath) { $OutputPath = Join-Path $bundle 'recovery-checklist.md' }
$body = @"
# Win2Lin Recovery Checklist

> Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
> Bundle: ``$bundle``  
> **Never stored here:** passwords, cookies/sessions, DPAPI/keychain data, private keys, MFA secrets.

## 1. Verify integrity
- [ ] Run: ``scripts/Verify-Win2LinBundle.ps1 -BundlePath "$bundle" -Mode Verify``
- [ ] If no checksums exist, create metadata checksums: ``-Mode Write`` (add ``-IncludePayload`` for full payload; slow).

## 2. Restore essential data
- [ ] Copy `C_DRIVE`/`D_DRIVE` payload to safe locations (no-clobber where needed).
- [ ] Confirm critical documents/projects open correctly.

## 3. Rebuild system
- [ ] Install OS/drivers/firmware using distro-supported methods.
- [ ] Reinstall apps (see `migration-report.md` / app mappings).
- [ ] Recreate dev environment from intent (not copied binaries).

## 4. Re-bootstrap identity (re-auth only)
- [ ] Browser sync + password manager
- [ ] Email/MFA/accounts/SSH public config (regenerate private keys if needed)

## 5. Validate
- [ ] Accessibility settings
- [ ] Core workflows and backups
"@
[IO.File]::WriteAllText($OutputPath, $body, [Text.UTF8Encoding]::new($false))
Write-Host "Wrote recovery checklist: $OutputPath"

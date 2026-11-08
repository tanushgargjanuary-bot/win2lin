#Requires -Version 5.1
<#
.SYNOPSIS
  Generate a migration report/checklist from a Win2Lin bundle inventory.
.DESCRIPTION
  Reads inventory.json and writes migration-report.md in the bundle (or -OutputPath).
  Includes: summary, reinstall checklist hints, dev environment, identity/bootstrap re-auth steps,
  accessibility reminders, and safety statements. Never handles secrets.
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
if (-not $OutputPath) { $OutputPath = Join-Path $bundle 'migration-report.md' }

$apps = @(); try { $apps = @($inv.installed_apps) } catch {}
$dev = @(); try { $dev = @($inv.dev_tools) } catch {}
$browsers = @(); try { $browsers = @($inv.browsers_profile_metadata_only) } catch {}
$drives = @(); try { $drives = @($inv.drives) } catch {}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Win2Lin Migration Report")
$lines.Add("")
$lines.Add("> Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  ")
$lines.Add("> Bundle: ``$bundle``  ")
$lines.Add("> Host: $($inv.host)  User: $($inv.user)")
$lines.Add("")
$lines.Add("## Safety (never copied)")
$lines.Add("- **No passwords, cookies/session tokens, browser credential stores/DPAPI data, private SSH/GPG keys, MFA secrets, or API tokens** were exported by Win2Lin.")
$lines.Add("- Use **browser sync**, **password manager**, and **re-authentication** on Linux.")
$lines.Add("")

$lines.Add("## Source summary")
foreach ($d in $drives) { $lines.Add("- Drive $($d.Name): used $($d.UsedGB) GB / total $($d.TotalGB) GB (free $($d.FreeGB) GB)") }
$lines.Add("- Apps discovered: $($apps.Count)")
$lines.Add("- Browser profiles (metadata only): " + (($browsers | % { "$($_.Browser)=$($_.ProfileCount)" }) -join ', '))
$lines.Add("")

$lines.Add("## Dev environment (recreate on Linux)")
$foundDev = @($dev | ? { $_.Found -eq $true } | % { "$($_.Tool) $($_.Version)".Trim() })
if ($foundDev.Count -gt 0) { foreach ($t in $foundDev) { $lines.Add("- [ ] $t") } } else { $lines.Add("- (No dev tools detected in inventory)") }
$lines.Add("- [ ] Prefer reproducible installs: distro packages, Flatpak, `mise`/`asdf`, `devbox`, or declarative configs (review before applying).")
$lines.Add("")

$lines.Add("## Apps to review (top entries)")
$top = @($apps | Select-Object -First 40)
foreach ($a in $top) { $n = if ($a.Name) { $a.Name } elseif ($a.DisplayName) { $a.DisplayName } else { [string]$a }; $lines.Add("- [ ] $n") }
if ($apps.Count -gt 40) { $lines.Add("- ... and $($apps.Count - 40) more (see inventory.json)") }
$lines.Add("- [ ] Use `data/app-mappings/windows-to-linux.yml` as a starting point; verify package names for your distro.")
$lines.Add("")

$lines.Add("## Identity & app-state bootstrap (re-auth required)")
$lines.Add("- [ ] Browser sync: Brave -> Edge -> (others as needed)")
$lines.Add("- [ ] Password manager / Google Password Manager")
$lines.Add("- [ ] Email, 2FA/MFA authenticators (use provider recovery/export methods; never copy secret seeds via Win2Lin)")
$lines.Add("- [ ] Dev accounts: GitHub/GitLab, SSH (use public keys/config; regenerate private keys if needed), cloud CLIs")
$lines.Add("- [ ] Key apps: Antigravity, OpenCode, messaging, office, creative tools")
$lines.Add("")

$lines.Add("## Accessibility checklist")
$lines.Add("- [ ] Verify screen reader / magnification / contrast / keyboard & pointer settings on Linux")
$lines.Add("- [ ] Check font scaling, display scaling, night light/color filters, captions")
$lines.Add("- [ ] Test input methods/keyboard layouts and assistive hardware")
$lines.Add("- [ ] Prioritize accessibility before optional customization")
$lines.Add("")

$lines.Add("## Data & verification")
$lines.Add("- [ ] Confirm `C_DRIVE`/`D_DRIVE` contents restored to intended locations")
$lines.Add("- [ ] Run `scripts/Verify-Win2LinBundle.ps1 -BundlePath <bundle> -Mode Write` (and later `-Mode Verify`) for integrity")
$lines.Add("- [ ] Keep Windows available for 1-2 weeks until validation is complete")
$lines.Add("")

$lines.Add("## Manual actions / known gaps")
$lines.Add("- [ ] Install GPU/drivers/printer/Wi-Fi firmware via your distro's supported method")
$lines.Add("- [ ] Recreate Windows-only apps via alternatives, web apps, or containers (distrobox/toolbox/Flatpak) where appropriate")
$lines.Add("- [ ] Review immutable/atomic distro guidance (no auto-mutation)")
$lines.Add("")

[IO.File]::WriteAllLines($OutputPath, $lines, [Text.UTF8Encoding]::new($false))
Write-Host "Wrote migration report: $OutputPath"

# Win2Lin tools (implemented foundations)

These tools extend the core export scripts into the broader-vision areas. They are **local-first** and **never handle secrets**.

## `scripts/Verify-Win2LinBundle.ps1` (backup/sync, disaster recovery, trust)
Creates or verifies SHA-256 checksums for a bundle.

```powershell
# Write checksums for metadata/logs/manifests (fast)
.\scripts\Verify-Win2LinBundle.ps1 -BundlePath C:\Win2Lin_export\<date> -Mode Write

# Verify
.\scripts\Verify-Win2LinBundle.ps1 -BundlePath C:\Win2Lin_export\<date> -Mode Verify

# Include C_DRIVE/D_DRIVE payload (slow, thorough)
.\scripts\Verify-Win2LinBundle.ps1 -BundlePath C:\Win2Lin_export\<date> -Mode Write -IncludePayload
```

## `scripts/New-Win2LinReport.ps1` (deeper migration, identity bootstrap, accessibility)
Generates `migration-report.md` from `inventory.json` with reinstall/dev hints, re-auth checklist (no secrets), and accessibility reminders.

```powershell
.\scripts\New-Win2LinReport.ps1 -BundlePath C:\Win2Lin_export\<date>
```

## `scripts/New-Win2LinRecoveryKit.ps1` (disaster recovery)
Generates `recovery-checklist.md` for integrity check, restore order, and identity re-bootstrap.

```powershell
.\scripts\New-Win2LinRecoveryKit.ps1 -BundlePath C:\Win2Lin_export\<date>
```

## Data foundations
- `data/app-mappings/windows-to-linux.yml` — app replacement/migration hints
- `data/accessibility/linux-checklist.yml` — accessibility verification checklist (no sensitive inference)
- `data/identity/bootstrap.yml` — separates portable data / recreatable state / auth-required (re-auth only)
- `data/recipes/example-safe-manual.yml` — safe manual recipe example (verified recipes direction)

## Specs (implementation targets)
See `specs/` for enterprise fleet (opt-in/admin-controlled), education labs, OEM kits, backup/sync platform, verified recipe runtime, identity/app-state portability, declarative integrations, and disaster recovery.

# Tests and validation

Win2Lin currently uses lightweight, safety-focused validation rather than a large automated test suite. The goal is to prevent data loss and secret leakage while keeping migration scripts portable.

## Principles

- **No real secrets in tests or fixtures.** Never commit browser passwords/cookies, DPAPI data, private keys, tokens, or personal export contents.
- **Safety first.** Changes to copy/restore logic should be verified against denylist behavior and dry-run/inventory flows.
- **Portability matters.** PowerShell scripts should be checked for parse/lint issues; Bash scripts should be checked with ShellCheck.
- **Real-world distro behavior varies.** Linux support relies on honest detection and graceful degradation; VM/container/manual reports are valuable.

## Current checks

### Static / lint checks

- **ShellCheck** for `scripts/*.sh` (run locally if installed; also runs in CI).
- **PowerShell parser** for `scripts/*.ps1` (basic syntax check; runs in CI).
- **PSScriptAnalyzer** for `scripts/*.ps1` (best-effort in CI/local when available).

Example local commands:

```powershell
Invoke-ScriptAnalyzer -Path .\scripts -Recurse
```

```bash
shellcheck ./scripts/Win2Lin.sh
```

### Safety-focused validation

Contributors should validate, as applicable:

- **Denylist fixtures:** synthetic files/paths that look like sensitive targets (e.g., fake `Login Data`, `Cookies`, `Web Data`, SSH private key names) are used only to confirm they are **not** exported/restored. See [`fixtures/README.md`](./fixtures/README.md).
- **Manifest checks:** when a change affects inventory/copy reporting, verify manifests/log output are generated as expected, contain useful audit information, and do not include secret material.
- **Dry-run/preview behavior:** confirm preview modes do not copy files and that real copy only happens when explicitly requested.
- **No-clobber/restore safety:** Linux restore changes should avoid overwriting user configs unexpectedly and must never restore private keys.

## Manual test matrix (recommended)

### Windows (PowerShell / launcher)

- Inventory mode on a machine/profile with representative folders.
- Dry-run/preview copy with safe sample data.
- Real copy to a local test destination (not inside a source path).
- Path handling with spaces and OneDrive/profile edge cases when relevant.

### Linux (`scripts/Win2Lin.sh`)

- Core restore from a sanitized sample export layout.
- Mode detection: `install`, `limited`, and `restore-only` cases.
- Mutable package-manager families (apt/dnf/pacman/zypper/apk/xbps/eopkg) when changing install logic.
- Immutable/managed cases (rpm-ostree/Fedora Atomic, openSUSE MicroOS transactional systems, Vanilla OS/abroot, Guix, SteamOS caution paths, NixOS) to confirm **no auto system mutation** and clear guidance.

## Future test directions

Planned/improvable areas (contributions welcome):

- Automated denylist regression tests using synthetic fixtures and manifest assertions.
- Scripted sample-export fixtures for Linux restore/no-clobber behavior.
- CI matrix expansion for additional lint rules or PowerShell versions where practical.
- VM/container distro matrix for `Win2Lin.sh` mode detection and restore smoke tests, especially for immutable/transactional/declarative systems.
- Snapshot/golden tests for sanitized manifests and user-facing guidance text where stability is helpful.

## Reporting test results

For distro-specific behavior, open a **Distro test report** issue using the GitHub template. Include sanitized environment details and avoid personal export contents.

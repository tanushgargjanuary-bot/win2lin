# Changelog (Win2Lin)

Format: Keep a Summary, then per-release notes. Security-relevant changes must be called out.

## Unreleased (v1 stabilization — in progress)
### Added
- `scripts/Verify-Win2LinBundle.ps1` auto-checksum step after successful Lite/Advanced copies.
- Pester safety tests (`tests/Win2Lin.Safety.Tests.ps1`, Pester 3.4-compatible) covering verifies, tamper/missing detection, report generation, dry-run, self-copy guard.
- Optional Rust accelerator `rust/win2lin-verify` (same `checksums.sha256` format, `cargo test` + smoke-verified).
- `specs/safety-denylist.md`, `docs/ui-next.md`, `rust/README.md`, `docs/safe-relaxations.md`.
- `data/profiles/{minimal,office,dev}.json` — profile presets (Minimal/Office/Dev) with schema v1 validation.
- Code quality tooling integrated: PSScriptAnalyzer (PowerShell), ShellCheck 0.11.0 (Bash), PyYAML/JSON validation (Python), cargo clippy (Rust).
- `.github/workflows/rust.yml` — cargo test/clippy CI for `rust/win2lin-verify` on Ubuntu + Windows.

### Changed
- Checksum docs in `specs/bundle-format.md`: v1 implemented format + exit codes.
- Lite/Advanced now attempt metadata checksums post-copy (non-fatal if unavailable).
- Lite exporter gained `-Profile Minimal|Office|Dev` (Minimal = Documents+Desktop only).
- Linux helper: improved Flatpak/distrobox/apx guidance (Tier-1 safe installs), pipx user-tools prompt, ShellCheck SC2221/SC2222 fix.
- **`.coderabbit.yaml` switched to strict mode** (`profile: assertive`, `request_changes_workflow: true`, path-specific security instructions, auto-review enabled).
- **PSScriptAnalyzer cleanup:** removed unused `$skipDirsHeavy` variable in `Win2Lin.ps1`.

### Security
- No behavior change to secret handling: never copy/restore passwords, cookies/sessions, credential stores/DPAPI, private keys, or tokens. See `SECURITY.md` and `specs/safety-denylist.md`.
- Code quality tools added to CI (`.github/workflows/ci.yml` + `rust.yml`) for automated lint/static analysis on push/PR.
- PSScriptAnalyzer found 86 warnings (all non-fatal: PSAvoidUsingEmptyCatchBlock = intentional forgiving design; PSUseApprovedVerbs = cosmetic). 0 errors.
- ShellCheck now passes with 0 warnings.

## v0.x (pre-release, script-based)
- Windows exporters (`Win2Lin.bat`, Lite/Advanced PS1), distro-flexible `Win2Lin.sh`, migration report/recovery tooling, app-mapping data, docs/specs scaffolding for broader scope.
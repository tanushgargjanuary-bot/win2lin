# Changelog (Win2Lin)

Format: Keep a Summary, then per-release notes. Security-relevant changes must be called out.

## Unreleased (v1 stabilization — in progress)
### Added
- `scripts/Verify-Win2LinBundle.ps1` auto-checksum step after successful Lite/Advanced copies.
- Pester safety tests (`tests/Win2Lin.Safety.Tests.ps1`, Pester 3.4-compatible) covering verifies, tamper/missing detection, report generation, dry-run, self-copy guard.
- Optional Rust accelerator `rust/win2lin-verify` (same `checksums.sha256` format, `cargo test` + smoke-verified).
- `specs/safety-denylist.md`, `docs/ui-next.md`, `rust/README.md`.

### Changed
- Checksum docs in `specs/bundle-format.md`: v1 implemented format + exit codes.
- Lite/Advanced now attempt metadata checksums post-copy (non-fatal if unavailable).

### Security
- No behavior change to secret handling: never copy/restore passwords, cookies/sessions, credential stores/DPAPI, private keys, or tokens. See `SECURITY.md` and `specs/safety-denylist.md`.

## v0.x (pre-release, script-based)
- Windows exporters (`Win2Lin.bat`, Lite/Advanced PS1), distro-flexible `Win2Lin.sh`, migration report/recovery tooling, app-mapping data, docs/specs scaffolding for broader scope.

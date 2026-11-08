# Safety denylist (v1 — executable)

**Status:** implemented in exporters; covered by `tests/Win2Lin.Safety.Tests.ps1` where feasible.

## Principle
Win2Lin **never copies/restores** material that would preserve credentials, sessions, encryption keys, or private identity secrets. When in doubt, exclude and instruct the user to re-authenticate.

## Never copy/restore (treat as sensitive)
- Browser password/credential stores and session material: `Login Data`, `Cookies`, `Web Data`, `Local Storage`, `Session Storage`, `IndexedDB`, `Preferences` (contains sync tokens), `Secure Preferences`, `Local State`, `History`, `Sessions`, `Network\Cookies`
- DPAPI/keychain-protected blobs, SAM/security hives, `pagefile.sys`/`hiberfil.sys`/`swapfile.sys`
- Private keys/secrets: `id_rsa`, `id_ed25519`, `id_ecdsa`, `id_dsa`, `*.pfx`, `*.p12`, `*.kdbx`, `.aws`, `.azure`, `.gnupg` private material, `*.key` where key material, `.env` files with secrets (do not blindly copy)
- Cloud tokens, API keys, OAuth refresh tokens, MFA seeds, browser extension API keys

## Allowed browser metadata (safe)
- Profile **existence/count**, extension **counts/names**, bookmarks **presence/size** (metadata only)
- User guidance: use **browser sync**, **password manager**, **re-authentication**, bookmarks HTML export/import
- Extension lists should be reviewed; extension settings may contain tokens in rare cases — export only when safe

## Allowed SSH material
- `config`, `known_hosts`, `authorized_keys`, `*.pub` (public only)
- **Never** private keys (`id_*` without `.pub`)

## Enforcement points
- `scripts/Win2Lin-lite.ps1`: copies user folders via `robocopy` with `-XD node_modules .venv ...` and `-XF pagefile/hiberfil/swapfile *.tmp desktop.ini`. Browser profile credential stores are not enumerated as roots (they live under `%LOCALAPPDATA%`, not copied user roots).
- `scripts/Win2Lin.ps1` (advanced): full-path segment/extension denylist (`Local Storage`, `*.ldb`, `Preferences`, `Local State`, `History`, `*.pfx`, `id_rsa`, etc.).
- `scripts/Win2Lin.sh` (Linux): restores only safe files above; never private keys.
- `scripts/Verify-Win2LinBundle.ps1`, `New-Win2LinReport.ps1`, `New-Win2LinRecoveryKit.ps1`: operate on produced bundle + inventory; never read credential stores.

## Tests / fixtures
- `tests/Win2Lin.Safety.Tests.ps1`: checksum verify/tamper/missing, report sections, dry-run no-copy, self-copy guard, no hardcoded secrets, lite roots exclude browser profile paths.
- Fixtures are synthetic only (`tests/fixtures/`); never commit real exports or secrets.

## Changing the denylist
Any change must:
1. Update this file and the relevant script(s).
2. Add/update a regression test.
3. Be treated as a **security-relevant change** in the changelog.

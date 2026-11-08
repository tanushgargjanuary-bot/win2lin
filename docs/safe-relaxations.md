# Safe relaxations (opt-in, explicit, verifiable)

**Principle:** defaults stay safe. Every relaxation is **opt-in, warned, dry-run first, and verifiable**. No silent auto-copy, no plaintext secrets, no silent cloud upload, no silent system mutation.

This doc records the swarm-team (Secrets/Trust, Immutable/Distro, UX/Product) proposals and what Win2Lin v1 implements vs defers.

## Implemented in v1

- **Profiles:** `Minimal` (Documents+Desktop only) vs `Office` (default, today) vs `Dev` (Office + optional code-workspaces hint). Data in `data/profiles/*.json`; Lite supports `-Profile Minimal/Office/Dev`.
- **Linux Tier-1 (safe on all distros, no sudo):** Flatpak `--user` preferred, pipx user tools prompt (`install_user_tools`), distrobox/toolbox/apx recipes in guidance. Works in `restore-only` mode (immutable/transactional/declarative systems).
- **Checksums always:** Light + Advanced write metadata `checksums.sha256` after copy; verify with `Verify-Win2LinBundle.ps1 -Mode Verify` or `rust/win2lin-verify`.
- **Dry-run first** in wizard + scripts; resume where supported; self-copy abort stays.

## Proposed but deferred (needs careful build + review)

### Encrypted secrets (`secrets.age`) — future, not shipped as code yet
- Would encrypt **only user-exported files** the user explicitly adds (`-IncludeSecrets "<path>"`, repeatable, never auto-discovered) via `age -p` passphrase-only; hard-ban browser credential stores/DPAPI blobs.
- `secrets.age` excluded from inventory/manifest/logs/checksums; Linux never auto-installs (decrypt to 0600 temp, per-file `install -m 600`, shred temp).
- Requires: age binary check, passphrase via `Read-Host -AsSecureString` (never argv/history), temp ACL, regression tests proving banned paths rejected.
- **Status:** spec/design only (see previous swarm report). **Do not implement plaintext fallback.**

### Cloud upload (encrypted, opt-in) — future
- rclone `crypt` backend only; plaintext upload refused; dry-run + typed `UPLOAD`; local export → verify → encrypted upload (2-stage). No silent upload.

### Force/Mirror restore (Linux) — future
- `--dry-run` preview, `--force` (backup to `~/.win2lin-backup/<ts>/` then overwrite, typed `FORCE`), `--mirror` (requires `--force` + typed `MIRROR` + prior dry-run). Never overrides immutable no-mutate.

### Mutate opt-in (immutable systems) — future
- Env/flag `WIN2LIN_ALLOW_MUTATE=1` / `--allow-mutate` + typed `I understand` + snapshot check + per-op confirm. Never for SteamOS system writes or full system reconfigure. Safe container/user installs remain the recommended path.

## Never relaxed (hard bans, no opt-in)
- Browser passwords/cookies/session tokens, DPAPI/keychain credential stores, `Login Data`/`Cookies`/`Web Data`/`Preferences`/`*.ldb`, SAM hives, `pagefile/hiberfil/swapfile`
- Direct DPAPI decrypt attempts (Win2Lin does not attempt)
- Silent cloud upload or silent system mutation
- Destructive mirror without dry-run + backup + typed confirmation

# Win2Lin — Project State

**Workspace:** `C:\Users\Tanush Garg\Win2Lin` (single project, git repo, branch `main`)  
**Updated:** 2026-11-09 (local)  
**Status:** v0.x scripts + broad scaffolding/specs committed locally; **not pushed to GitHub yet**

## What exists (implemented)
- `Win2Lin.bat` — double-click wizard
- `scripts/Win2Lin-lite.ps1` — recommended simple Windows exporter (uses `robocopy`, dry-run/copy)
- `scripts/Win2Lin.ps1` — advanced exporter (inventory/manifest/progress features)
- `scripts/Win2Lin.sh` — distro-flexible Linux restore/helper (best-effort)
  - Detects apt/dnf/yum/pacman/zypper/apk/xbps/eopkg/swupd (+ rpm-ostree/transactional/Vanilla/NixOS/Guix/SteamOS handling)
  - **Omarchy** supported (Arch-based/pacman). Trending/new distro families handled with safe modes (no auto-mutation of immutable/atomic/transactional/declarative/managed systems)
  - Core restore universal/safe: no-clobber, restores safe SSH files only (`config`,`known_hosts`,`authorized_keys`,`*.pub`) — **never private keys/passwords/cookies/tokens**
  - Reviewed/fixed: SSH pub no-clobber fallback, `find -maxdepth` fallback, privilege prompt, Nix/Guix precedence on mutable distros; `bash -n` passed
- Desktop copies updated: `OneDrive\Desktop\Win2Lin_*` + `Win2Lin_run.bat`, README

## Scaffolding/specs (foundation, not full feature implementations)
- Roadmap/vision/architecture/docs, CI + issue/PR templates, `SECURITY.md`, `CONTRIBUTING.md`, CodeRabbit config
- App mappings + migration/report templates + bundle-format spec
- Module API + example module
- Packaging/install/checksum/release scaffolding
- UX wizard/report/profiles specs
- Broader-vision specs: enterprise fleet (opt-in/admin-controlled), education labs, OEM transition kits, accessibility-preserving migration, backup/sync, verified recipes, identity/app-state portability (privacy-first), declarative/dotfile integrations, disaster recovery + templates

## Hard invariants (never violate)
- **Never export/copy/restore secrets:** passwords, cookies/session tokens, browser credential stores/DPAPI/keychain data, private keys, MFA/API tokens.
- Local-first, privacy-first, dry-run/preview where possible, verifiable artifacts.
- Conservative system changes; no auto-mutation of immutable/atomic/transactional/declarative/managed systems.
- Default export local (`C:\Win2Lin_export\...`), not OneDrive; refuse self-copy.

## Known gaps / next shippable work
- Real implementations: SHA-256 checksum generation+verification, migration report generator from inventory+mappings, profiles in PS scripts, Pester tests for denylist/self-copy/path mapping, GitHub Release with checksums.
- Full features not built: macOS/Linux->Linux/Win->Win exporters, GUI/TUI app, encryption engine, plugin runtime, published packages, verified cross-distro test matrix.

## Blockers / decisions
- **GitHub push pending:** repo ready; user must confirm name/visibility (suggested `gh repo create win2lin --public --source=. --remote=origin --push`). Enable CodeRabbit app after push.

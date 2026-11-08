# Win2Lin roadmap

This roadmap is a practical plan for growing Win2Lin from a Windows-to-Linux migration helper into a broader, safer migration and environment-portability project. It is intentionally honest: items are marked **Done (v0.x)** only when they exist in the repository today.

## Status legend

- **Done (v0.x):** implemented in the current script-based toolchain.
- **In progress / partial:** scaffolding or behavior exists, but not a complete user-facing capability.
- **Planned:** not implemented yet; may change based on user feedback and safety constraints.

## Current baseline (v0.x)

**Done (v0.x):**
- Windows entry points: `Win2Lin.bat` (double-click wizard), `scripts/Win2Lin-lite.ps1` (robocopy-based), and `scripts/Win2Lin.ps1` (advanced exporter path).
- Basic export workflow: inventory scan and file copy modes, with dry-run/preview guidance in the lite/wizard flow.
- Safe-by-default boundaries stated in scripts/docs: browser passwords/cookies/credential material are not migrated; users are directed to browser sync/password manager re-login.
- Linux helper: `scripts/Win2Lin.sh` provides distro-flexible, best-effort detection and guidance; core restore aims to be portable on common Linux environments.
- Conservative Linux behavior: install/limited/restore-only modes; no automatic mutation of immutable/transactional/declarative/managed systems; no-clobber defaults for safe restore targets; never restores private keys.
- Repository scaffolding present (`docs/`, `modules/`, `specs/`, `templates/`, `tests/`, `packaging/`, `data/`) — useful for future work, but not evidence of a complete platform.

**In progress / partial:**
- Documentation foundation (this roadmap/vision/architecture set).
- “Advanced” exporter capabilities referenced by docs/scripts (e.g., richer inventory/manifests/progress/resume behavior) — treat as partial until verified, tested, and documented with stable output contracts.

**Not done (important):**
- TUI/GUI wizard, plugin runtime, encrypted bundles, verifiable checksums/manifests as a stable cross-tool contract, multi-direction migration engines, broad app-mapping database, and automated browser profile migration beyond safe guidance.

## Phase 0 — Foundation and honesty (now → near term)

**Goal:** make current behavior predictable, inspectable, and safe to build on.

- **Done (v0.x):** script-based Windows export + Linux restore helper; basic inventory/export flow; distro-aware Linux guidance with safe degradation.
- **Planned:**
  - Define a **portable bundle format** (directory layout + metadata contract) so exporters/restorers/tools can interoperate.
  - Add a **verifiable manifest** spec (file list, sizes, hashes/checksums where feasible, timestamps, source/target metadata, redaction rules).
  - Document stable exit codes, logs, and machine-readable report locations.
  - Expand automated tests around path safety, dry-run behavior, exclusions, and Linux restore no-clobber/secret-safety rules.

## Phase 1 — Migration directions (realistic sequencing)

**Goal:** support more directions without pretending one engine fits all.

### 1a. Windows → Linux
- **Done (v0.x):** core user-data export + Linux-side safe restore/guidance.
- **Planned:** stronger inventory, app/profile detection coverage, migration plan/report output, optional resumable copy with checksum verification.

### 1b. Linux → Linux
- **Planned:** export/import of user data and safe config sets between Linux machines/distros; package/app *mapping guidance* (not blind package replay across package managers/immutable systems).
- **Constraints:** must respect distro policy differences (apt/dnf/pacman/zypper/apk/xbps/eopkg vs Flatpak/Snap vs immutable/transactional/declarative systems).

### 1c. macOS → Linux
- **Planned (later):** inventory/export of common user data locations and safe dotfiles; app mapping guidance; explicit handling of macOS-specific app data/sandbox paths.
- **Constraints:** requires macOS-side exporter implementation and careful permission/privacy UX; not part of v0.x.

### 1d. Windows → Windows
- **Planned (later):** PC refresh/migration scenario using the same bundle/manifest/report concepts; profile/data transfer with strict secret exclusions.
- **Constraints:** different system/app state model than Linux restore; must avoid registry/credential exfiltration shortcuts.

## Phase 2 — Deeper migration (opt-in, safety-first)

**Goal:** reduce reinstall/reconfigure work while keeping risk explicit.

- **Developer environments (planned):** inventory and guidance for shells, editors/IDEs, runtimes, package managers, containers/WSL notes, SSH *public* config/known hosts/authorized keys only; optional export of selected project folders. No automatic secret transfer.
- **App mapping (planned):** curated, community-reviewed mappings (Windows/macOS app → Linux alternatives or equivalents), confidence levels, and manual steps. Mappings are advisory, not authoritative.
- **Dotfiles (planned):** selective export/restore of common dotfiles and `~/.config` subsets with previews, diffs, and no-clobber/backup options.
- **Safe browser migration (planned, strict):** bookmarks/favorites export guidance, extension lists, profile *metadata* where safe, and sync instructions. **Never passwords, cookies, session tokens, autofill secrets, or DPAPI/keychain-protected credential stores.**
- **Game saves (planned, opt-in only):** user-selected game/library folders; clear size/time estimates; publisher/platform-specific locations documented as best-effort. No cloud credential handling.

## Phase 3 — UX and reliability

**Goal:** make migrations understandable, resumable, and auditable.

- **Planned:**
  - **TUI/GUI wizard** over the same core engine (not a separate logic fork).
  - **Migration plan + report**: preflight summary, actions taken/skipped, warnings, manual next steps, and a local report artifact.
  - **Profiles/presets**: e.g., “basic files”, “developer”, “media”, “custom” — all reviewable before execution.
  - **Resume + checksums**: resumable transfers with verification where practical; clear behavior on partial copies.
  - **Encryption (opt-in):** encrypt export bundles at rest/in transit workflows chosen by the user; key handling kept local and explicit. No silent cloud upload.

## Phase 4 — Plugin/module ecosystem

**Goal:** let the community extend detection/mapping/restore without weakening safety.

- **Planned:**
  - Module interfaces for inventory collectors, planners, exporters, restorers, and reporters.
  - Data-driven mappings (YAML/JSON) with schema validation, provenance, and review guidelines.
  - Capability/safety boundaries: modules declare what they read/write; secret-handling modules are disallowed by default policy.
  - Compatibility/versioning for bundle and manifest formats.

## Phase 5 — Trust and quality

**Goal:** earn trust through transparency, not claims.

- **Planned:**
  - Threat/privacy model documentation (local-first, no telemetry by default, explicit network actions only when user asks).
  - Reproducible checks: manifest verification, dry-run parity, and golden tests for planners/reporters.
  - Signed releases/checksums for distributed artifacts where applicable.
  - Clear support matrix: “tested”, “best-effort”, and “unsupported/restore-only” — including immutable/managed distros.
  - Security review checklist for any code touching credentials, browser data, SSH material, or encryption.

## Phase 6 — Distribution

**Goal:** make installation easy without compromising auditability.

- **Planned:**
  - Keep source-first distribution (clone/inspect/run) as a first-class path.
  - Package where practical (e.g., PowerShell module/gallery, archives, distro packages/containers for Linux tooling) — only with pinned build/release processes.
  - Optional portable bundles for offline use.
  - Documentation for verifying downloads and reviewing scripts before execution.

## Non-goals / boundaries (current policy)

- No copying browser passwords/cookies/session tokens or DPAPI/keychain-protected secrets.
- No automatic mutation of immutable/transactional/declarative/managed Linux systems.
- No silent cloud upload of exports or manifests.
- No promise of “migrate everything automatically”; complex apps, licensed software, and system-specific state often require manual steps.

# Win2Lin architecture (high level)

This document describes the **current** Win2Lin shape (v0.x scripts) and the **intended** architecture for expanding safely. It is descriptive, not a promise that every planned component exists.

## Goals

- Make migrations **inspectable** (inventory, logs, manifests/reports).
- Keep actions **local-first** and **privacy-first**.
- Enforce **safety boundaries**: no secret exfiltration; conservative/no automatic mutation on managed/immutable Linux systems; dry-run/preview where possible.
- Allow future growth (more migration directions, modules, UX) without forking core logic per interface.

## Current architecture (v0.x)

```text
Windows machine
  ├─ Win2Lin.bat (wizard UX)
  │    └─ invokes PowerShell exporter (Inventory / Dry-run preview / Copy)
  ├─ scripts/Win2Lin-lite.ps1  (simple: inventory.json + robocopy-based copy)
  └─ scripts/Win2Lin.ps1       (advanced path: richer inventory/manifest/progress features as implemented)

            │ writes local export bundle/folder
            ▼

Portable export directory (user-chosen; default local path)
  ├─ inventory.json / logs (lite)
  ├─ robocopy_*.log (lite copy details)
  └─ copied user data (e.g., C_DRIVE/... , D_DRIVE/...) per selected roots

            │ user copies folder to Linux (USB/disk/network by user choice)
            ▼

Linux machine
  └─ scripts/Win2Lin.sh
       ├─ locate export (inventory.json)
       ├─ detect distro/environment (ID/ID_LIKE/VARIANT_ID/PRETTY_NAME + command hints)
       ├─ choose mode: install | limited | restore-only
       ├─ best-effort, confirmed installs only on supported mutable systems (optional)
       └─ core safe restore (no-clobber): selected dotfiles/config/fonts, public SSH files only
          (never private keys/passwords/tokens/cookies)
```

### Current components

| Component | Role | Status |
|---|---|---|
| `Win2Lin.bat` | Double-click wizard; preview before real copy. | Done (v0.x) |
| `scripts/Win2Lin-lite.ps1` | Basic inventory + robocopy copy; local logs/inventory. | Done (v0.x) |
| `scripts/Win2Lin.ps1` | Advanced exporter path (richer inventory/manifest/progress/resume features as present). | Partial / verify per release |
| `scripts/Win2Lin.sh` | Linux restore/helper: distro-flexible detection, safe restore, conservative install guidance. | Done (v0.x) |
| `README.md` + safety notes | User guidance, exclusions, distro behavior, login/sync reminders. | Done (v0.x) |
| `docs/`, `modules/`, `specs/`, `templates/`, `tests/`, `packaging/`, `data/` | Scaffolding/areas for future architecture work. | Present; maturity varies |

## Portable bundle format (intended)

A **portable bundle** is the unit that moves between exporter and restorer. v0.x already uses an export directory; the intended evolution is to formalize it as a contract:

- **Layout:** stable top-level structure for metadata, manifests, logs/reports, and copied payloads (e.g., per-source roots).
- **Metadata:** tool version, source platform, creation time, selected profile/options, redaction/safety policy version.
- **Manifests:** file entries with relative paths, sizes, timestamps, and checksums/hashes where feasible; explicit skipped/excluded items and reasons.
- **Verification:** ability to validate bundle integrity and confirm restore outcomes (planned/partial depending on implementation).
- **Security/privacy:** no secrets in payload or metadata; manifests must not leak credential material; optional encryption at rest is a planned opt-in feature.

The exact schema should be specified under `specs/` and versioned once stabilized (planned).

## Planned logical modules

These map to repository areas and future code organization; they describe responsibilities, not current completeness:

- **Inventory collectors:** discover user data roots, installed apps/profiles (safe metadata), dev environment signals, and platform-specific locations.
- **Planner:** turn inventory + user profile into a reviewable migration plan (what to copy/map/skip, risks, manual steps). Dry-run output should be a first-class artifact.
- **Exporters:** platform-specific (Windows now; Linux/macOS later) writers that produce portable bundles and manifests without violating secret/safety rules.
- **Restorers:** platform-specific restore/guidance engines (Linux now) that apply safe, no-clobber defaults and respect system policy (including immutable/managed systems).
- **Mapping/catalog data:** community-reviewed, data-driven app/config mappings with provenance/confidence; stored/validated via `data/`/`specs/` patterns as designed.
- **Report engine:** produce human-readable and machine-readable reports (plan, actions, skips, warnings, verification results, manual next steps).
- **Interfaces:** CLI now; future TUI/GUI wizard should call the same core planner/export/restore/report interfaces.

## Safety boundaries (architectural invariants)

- **Secrets:** never collect or transfer browser passwords/cookies/session tokens, DPAPI/keychain-protected credentials, private SSH keys, API tokens, or equivalent secrets.
- **System mutation:** no automatic package/system mutation on immutable, transactional, declarative, or managed Linux systems; mutable-system installs require explicit confirmation and best-effort behavior.
- **User data integrity:** prefer dry-run/preview, no-clobber defaults, and clear logs/manifests. Destructive operations require explicit design and user intent (not a default path).
- **Local-first:** exports/manifests remain local unless the user explicitly moves them. No silent cloud upload.

## Extension points (future)

- Add exporters/restorers for **Linux→Linux**, **macOS→Linux**, and **Windows→Windows** using the same bundle/manifest/report contracts.
- Add optional modules for developer environments, app mapping, selective dotfiles, safe browser migration guidance (no secrets), and opt-in game-save handling.
- Introduce verification (checksums/resume), profiles, encryption, and plugin capability policies once the core contracts are stable and tested.

## Related docs

- [`../ROADMAP.md`](../ROADMAP.md) — phased plan and status.
- [`../VISION.md`](../VISION.md) — principles and long-term direction.
- [`README.md`](./README.md) — documentation index.
- [`../README.md`](../README.md) — current usage and safety notes.

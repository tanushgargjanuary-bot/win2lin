# Win2Lin vision

Win2Lin aims to become a **universal, safe migration and environment portability assistant**.

The project starts from a practical pain point — moving from Windows to Linux without losing important files or forgetting critical setup steps — but the long-term direction is broader: help people move *environments* (data, safe configuration, and reinstall/reconfiguration plans) across machines and platforms with clear boundaries and evidence.

## What “universal” means (and does not mean)

- **Means:** a common, inspectable model for inventory → plan → export/bundle → restore/report, with adapters for different platforms and environments over time.
- **Does not mean:** a promise to migrate every app, setting, license, credential, or OS-specific state automatically. Many migrations require manual steps; the tool should make those steps explicit, not hide them.

## Core principles

### 1. Local-first, privacy-first
- Migration data stays on the user’s machines and user-chosen storage by default.
- No telemetry by default. Any network action (if ever added) must be explicit, minimal, and documented.
- Exports/manifests should avoid sensitive locations and accidental cloud-sync paths unless the user intentionally chooses them.

### 2. Never exfiltrate secrets
- Win2Lin must not copy, export, upload, or “helpfully recover” secrets. This includes browser passwords, cookies/session tokens, autofill secrets, DPAPI/keychain-protected credential stores, private SSH keys, API tokens, and similar material.
- Safe alternatives are first-class: browser sync, password managers, re-authentication, and public-only SSH material (`config`, `known_hosts`, `authorized_keys`, `*.pub`) where appropriate.

### 3. Dry-run and preview where possible
- Users should be able to see what will be scanned, copied, skipped, or changed before committing to actions.
- Operations that mutate a target system (especially package installs or config writes) must be opt-in, explained, and conservative.

### 4. Verifiable manifests and reports
- A migration should produce inspectable artifacts: inventories, manifests, checksums where feasible, logs, and human-readable reports.
- Verification matters more than speed claims: users should be able to confirm what was captured, what was restored, and what was skipped.

### 5. Conservative system changes
- Respect platform policy. On Linux, this means no automatic mutation of immutable/transactional/declarative/managed systems; provide guidance instead.
- Prefer no-clobber behavior and backups for user config restores. Never make destructive changes silently.

### 6. Community mappings, transparent trust
- App/config mappings should be data-driven, reviewable, and attributable (provenance, confidence, last-reviewed notes).
- The project should clearly distinguish tested behavior from best-effort guidance and unsupported cases.

## Intended outcomes

- Fewer forgotten files and setup steps during migrations.
- Clear safety boundaries around secrets and system mutation.
- Repeatable migrations through portable bundles, manifests, and reports.
- A foundation that can grow from Windows→Linux scripts into multiple migration directions and modules without compromising trust.

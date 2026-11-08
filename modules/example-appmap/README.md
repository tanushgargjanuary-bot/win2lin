# Example module: Windows→Linux app mapping

This is a **tiny, data-only example module** for the Win2Lin module contract. It references the app-mapping concept used by Win2Lin: suggesting Linux alternatives/workflows for common Windows apps during migration.

## What it does

- Declares `map`/`render` capabilities in [`module.yml`](./module.yml).
- Points to the repository's safe catalog: [`../../data/app-mappings/windows-to-linux.yml`](../../data/app-mappings/windows-to-linux.yml).
- Produces *advisory* suggestions/checklist data only (conceptual `module_output`), suitable for reports or user review.

## Safety

This module is intentionally conservative:

- **No executable hooks** (`hooks: {}`, `safety.executable_hooks: false`).
- **No secrets** (`permissions.secrets: deny`, `safety.handles_secrets: false`). It must never read or export passwords, API tokens, cookies, session data, browser credential stores, DPAPI/keychain secrets, or private SSH/GPG keys.
- **No network / no process / no system mutation**. It does not install packages or modify the OS.
- **Immutable/managed systems:** any guidance derived from mappings should remain manual/conservative (Flatpak, distrobox/toolbox, documented workflows) — never automatic `rpm-ostree` layering, `transactional-update` installs, NixOS/Guix system reconfiguration, `abroot`/managed mutation, etc.
- **Data quality caveat:** package names, repository setup, and availability vary by distro/release. Treat mapping entries as starting points to verify.

## Files

| File | Purpose |
|---|---|
| `module.yml` | Module manifest (identity, compatibility, permissions, safety). |
| `README.md` | This explanation. |

The referenced mapping data lives in `data/app-mappings/windows-to-linux.yml` and includes per-entry cautions (for example, never copy browser passwords/cookies/credential databases).

## How a host might use it (conceptual)

1. Load and validate `module.yml`.
2. Confirm safety/permissions (secrets denied, hooks absent or explicitly opted in).
3. Read safe inputs (optional inventory facts + mapping catalog).
4. Match known Windows app names/hints to `linux_options` and migration guidance.
5. Render advisory suggestions into a migration report/checklist for user review.

This example is **not** an installer and does not claim host support; it exists to make the module contract concrete and reviewable.

# Disaster recovery bundles (spec draft)

**Status:** draft  
**Scope:** minimum safe material to recover a working environment after hardware loss/OS failure.

## Goals
- Recovery profile: essential documents, verified checksums, app inventory, reinstall plan, identity re-bootstrap checklist, restore order.
- “Known-good” verification stamps and periodic integrity checks.
- Emergency report variant: short human checklist + machine-readable manifest.
- Optional split bundles (critical small bundle + large archive).

## Safety
- **Exclude secrets.** Include instructions for password manager/browser/account recovery instead.
- Encryption optional; **key/passphrase loss warnings are blocking**.
- Local-first, user-controlled destinations. No silent cloud upload.
- Prioritize data integrity and safe restore over speed.

## Artifacts
- `recovery-manifest.json`, `recovery-checklist.md`, checksum index, verification log, restore order plan.

# Backup & sync (local-first, adjacent) — spec draft

**Status:** draft  
**Scope:** verifiable, user-controlled backup/restore workflows built on Win2Lin bundles/manifests.

## Goals
- Scheduled local export plans using profiles/manifests.
- Incremental/deduplicated bundle versions (planned) with clear integrity model.
- Verified restore drills (prove selected data restores correctly).
- Optional **user-managed** destinations: external disk, NAS, encrypted container — **never default cloud upload**.

## Safety & constraints
- **Backup ≠ secret capture.** No passwords/cookies/sessions/DPAPI/keychain/private keys. Use password manager/browser sync for credentials.
- **Local-first, privacy-first.** No telemetry by default; transfers explicit.
- **No-clobber by default** for restores; explicit conflict resolution.
- **Encryption optional but careful:** user-controlled keys/passphrases; mandatory loss warnings.
- **Verifiable:** manifests + checksums; integrity checks before/after restore.

## Artifacts
- Versioned bundle manifests, checksum indexes, restore drill reports, conflict logs.

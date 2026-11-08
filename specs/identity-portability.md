# Cross-device identity & app-state portability (spec draft)

**Status:** draft  
**Scope:** help users reconstruct working environments across devices without centralizing secrets.

## Goals
- Portability plans for identity bootstrap: which accounts/apps need sign-in, which support export/import, which require provider-native sync.
- Device-role profiles (home desktop, laptop, lab machine) with safe config subsets.
- App-state portability where vendors provide safe export formats; otherwise precise manual steps.
- Separate **portable data**, **recreatable state**, and **secret/auth state**.

## Safety (critical)
- **No password/token/session/cookie/MFA-secret portability** through Win2Lin.
- **No identity fabrication.** Rely on user re-authentication and approved providers.
- Cross-device transfers use **user-chosen local/encrypted channels only** by explicit action.
- Reports must label what requires re-auth/manual/provider sync.

## Outputs
- Identity/bootstrap checklist in migration report.
- Machine-readable plan entries: `kind: data|recreatable|auth_required|manual|provider_sync`.

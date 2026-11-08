# Enterprise fleet migrations (spec draft)

**Status:** draft / opt-in / admin-controlled  
**Scope:** organization Windows→Linux or device refresh planning and execution with auditability.

## Goals
- Readiness and compatibility reporting at fleet scale.
- Policy-approved export/restore workflows with explicit data boundaries.
- No credential harvesting; no silent endpoint behavior.

## Safety & governance (non-negotiable)
- **Opt-in and approved:** deployment, scopes, and destinations require admin/policy approval and user/admin visibility as applicable.
- **Never exfiltrate secrets:** no passwords, cookies/session tokens, browser credential stores, DPAPI/keychain/private keys, MFA secrets.
- **Data minimization:** collect only policy-scoped, non-sensitive inventory metadata needed for planning.
- **Local-first / controlled transfer:** bundles to IT-managed storage or offline media only by explicit policy.
- **Auditable:** every plan/export/verify/restore action logged with actor/policy context (local logs; no hidden telemetry).

## Capabilities (planned)
- Admin profiles: approved roots, exclusions, encryption required, checksum level, retention.
- Fleet readiness report: app gaps, storage/network constraints, manual-action burden, accessibility risks.
- Cohort rollout + rollback checkpoints + post-migration verification.
- Separation of employee personal data boundaries (configurable).

## Out of scope / prohibited
- Bypassing MDM/EDR/policy controls.
- Extracting accounts/sessions or identity assertions.
- Silent background exfiltration.

## Artifacts
- `fleet-plan.json`, `fleet-report.md/json`, per-device verifiable manifests, signed policy metadata (future, opt-in).

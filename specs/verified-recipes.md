# Verified community migration recipes (spec draft)

**Status:** draft  
**Scope:** trusted, reviewable knowledge for app/config/manual workflows — scaling help without unsafe automation.

## Goals
- Recipe catalog: app migrations, config mappings, manual workflows, distro-specific notes.
- Trust metadata: platform versions, provenance, maintainer, tests performed, confidence, last reviewed, known limitations.
- Verification based on reproducible checks/review, **not popularity alone**.
- Dry-run first; risky steps require confirmation.

## Safety
- **Data/instructions first, not privileged arbitrary code by default.** Executable helpers (if ever introduced) require explicit opt-in, capability limits, sandboxing, and review.
- **No secrets:** recipes must never instruct exporting passwords/cookies/sessions/DPAPI/private keys/tokens.
- **Conservative system changes:** respect immutable/atomic/transactional/declarative/managed systems; no silent mutation.
- **Transparent trust labels:** unverified/best-effort/tested/signed (future) clearly shown.

## Recipe schema (conceptual)
`id`, `version`, `applies_to` (OS/distro/app versions), `intent`, `provenance`, `confidence`, `review`, `steps` (manual/check/optional-command with risk), `verification`, `rollback/notes`, `never_do` (safety bans).

## Integration
- Consumed by migration planner/report engine as **suggestions with provenance**, never blind automation.

# Win2Lin broader vision

**Status:** draft  
**Scope:** long-horizon product directions beyond the current Windows→Linux migration assistant.  
**Related:** [`../VISION.md`](../VISION.md), [`architecture.md`](./architecture.md), [`ux/wizard-spec.md`](./ux/wizard-spec.md), [`ux/migration-report-spec.md`](./ux/migration-report-spec.md), [`../specs/profiles.md`](../specs/profiles.md)

## Purpose

Win2Lin can grow from a migration utility into a broader **safe environment portability platform**. This document proposes bigger opportunities while keeping the core constraints explicit: local-first, privacy-first, no secret exfiltration, dry-run/preview, verifiable artifacts, and conservative system changes.

## Constraints that apply to every vision area

These are guardrails, not optional features:

- **Local-first by default:** data collection, planning, bundle creation, verification, and reports run on user/admin-controlled systems.
- **Privacy-first:** minimal necessary metadata; no telemetry by default; no silent cloud upload. Any network transfer is explicit, documented, and user/admin-controlled.
- **Never exfiltrate secrets:** no passwords, cookies/session tokens, autofill secrets, DPAPI/keychain credentials, private keys, API tokens, or equivalent secrets. Safe alternatives are first-class.
- **Dry-run and preview:** users/admins can inspect planned actions before execution.
- **Verifiable manifests/reports:** inventories, checksums where feasible, logs, and human+machine-readable reports.
- **Conservative system changes:** no-clobber defaults, explicit confirmations, and no automatic mutation of immutable/transactional/declarative/managed systems.
- **Transparent trust:** mappings/recipes carry provenance, confidence, review state, and clear tested vs best-effort labels.

## Near-term expansion (foundation)

Before or alongside broader bets, Win2Lin should deepen the migration core:
- multi-direction migration contracts (Windows→Linux, Linux→Linux, macOS→Linux, Windows→Windows) over the same bundle/report model;
- stronger verification (full checksums, resumable integrity checks, signed manifests as an opt-in future capability);
- app/config mapping catalog with provenance and review workflow;
- accessibility-preserving UX across CLI/TUI/GUI.

## Broader vision areas

### 1. Enterprise fleet migrations (opt-in, admin-controlled)

**Opportunity:** help organizations plan and execute OS refreshes or Windows→Linux transitions with evidence, not ad hoc scripts.

Possible capabilities:
- admin-defined profiles/policies (approved roots, exclusions, encryption requirements, verification levels);
- fleet planning reports: readiness, app compatibility gaps, storage/network constraints, manual-action burden;
- opt-in collection of **non-sensitive, policy-scoped** inventory metadata only where explicitly configured; never employee secrets;
- controlled bundle destinations (IT-managed storage, offline media workflows);
- phased rollout cohorts, rollback checkpoints, and post-migration verification reports.

Constraints:
- no silent endpoint agent behavior; deployment and data flow must be auditable and approved.
- employee personal data boundaries must be configurable and respected.
- no credential harvesting, no browser/session extraction, no MDM bypass instructions.

### 2. Education labs and classrooms

**Opportunity:** make student/staff environment moves and lab rebuilds repeatable.

Possible capabilities:
- lab image transition checklists (Windows lab → Linux lab) with app replacement catalogs for common curricula;
- student profile presets for coursework folders, project exports, and safe IDE settings guidance;
- instructor/admin review mode for shared machines: dry-run reports before reset/reimage;
- offline/USB-first workflows for bandwidth-limited environments.

Constraints:
- student privacy first; avoid collecting unnecessary personal metadata.
- shared-machine workflows must prevent cross-user data leakage.
- no transfer of accounts/passwords; use institution-approved identity and sync systems.

### 3. OEM and preload Linux transition kits

**Opportunity:** partner-friendly migration kits for vendors shipping Linux devices or offering transition programs.

Possible capabilities:
- OEM-branded but inspectable migration/report bundles;
- device-aware restore guidance (drivers, firmware reminders, accessibility settings checklist) without privileged system mutation by default;
- "first boot on Linux" checklist generated from the migration report;
- compatibility evidence pack: what moved, what needs manual setup, known app alternatives.

Constraints:
- no OEM telemetry or hidden data collection through Win2Lin.
- hardware/vendor guidance must be clearly labeled as vendor-specific and reviewable.
- secure boot/firmware/system changes require explicit user intent and documented steps.

### 4. Accessibility-preserving migration

**Opportunity:** treat accessibility setup as critical migration state, not an afterthought.

Possible capabilities:
- detect and report accessibility-relevant signals where safely available (high-level preferences, assistive tool presence, input/display customization hints);
- map to Linux accessibility equivalents/checklists (screen readers, magnification, contrast, keyboard/mouse accommodations, captions) with confidence/provenance;
- prioritize accessibility actions in the migration checklist;
- accessible wizard UX: screen-reader semantics, keyboard-only flow, high contrast, scalable text, plain-language risk prompts.

Constraints:
- do not infer or export sensitive medical/personal attributes; only migration-relevant settings signals and user-confirmed info.
- accessibility mappings must be honest about gaps and manual configuration.

### 5. Backup and sync product (adjacent, not a cloud dependency)

**Opportunity:** evolve verifiable bundles into a user-controlled backup/restore workflow.

Possible capabilities:
- scheduled local export plans using the same profiles and manifests;
- incremental/deduplicated bundle versions (planned, with clear integrity model);
- verified restore drills: prove a bundle can restore selected data;
- optional user-managed destinations (external disk, NAS, encrypted container) — never default cloud upload.

Constraints:
- backup does not mean secret capture; password managers/browser sync remain the right tools for credentials.
- sync/conflict resolution must be explicit and no-clobber by default.
- encryption key management remains user-controlled; loss warnings are mandatory.

### 6. Verified community migration recipes

**Opportunity:** scale knowledge without scaling unsafe automation.

Possible capabilities:
- recipe catalog for app migrations, config mappings, and manual workflows;
- schema for recipe metadata: platform versions, provenance, maintainer, tests performed, confidence, last reviewed, known limitations;
- verification badges based on reproducible checks or maintainer review, not popularity alone;
- local recipe execution in dry-run mode first; risky steps require confirmation.

Constraints:
- recipes are data/instructions with trust labels, not arbitrary privileged code by default.
- no recipe may instruct users to export secrets or weaken safety policy.
- community submissions need review, sandboxing/capability limits where executable helpers are ever introduced.

### 7. Cross-device identity and app-state portability (privacy-first)

**Opportunity:** help users reconstruct working environments across devices without centralizing secrets.

Possible capabilities:
- portability plans for identity bootstrap: which accounts/apps need sign-in, which support export/import, and which require provider-native sync;
- device-role profiles (home desktop, laptop, lab machine) with safe config subsets;
- app-state portability where vendors provide safe export formats; otherwise generate precise manual steps;
- separation of "portable data," "recreatable state," and "secret/auth state."

Constraints:
- no password/token/session portability through Win2Lin.
- identity assertions must not be fabricated; rely on user re-authentication and approved providers.
- cross-device transfers use user-chosen local/encrypted channels only by explicit action.

### 8. Integration with dotfile managers and declarative environments

**Opportunity:** bridge migration bundles with tools users already trust.

Possible capabilities:
- detect safe dotfiles/config and propose export into existing workflows: dotfile repos, chezmoi/yadm-style layouts, Devbox, Nix/Home Manager, Ansible user-level playbooks;
- generate reviewable patches/snippets rather than silently rewriting declarative system configs;
- map developer environment intent (tools, versions, config) into reproducible manifests and manual/declarative next steps.

Constraints:
- no automatic NixOS rebuild, Home Manager switch, Guix system reconfigure, or equivalent system mutation without explicit user action outside Win2Lin's conservative defaults.
- generated declarative config is a draft artifact requiring user review.
- never place secrets in generated config, lockfiles-as-secrets, or environment files.

### 9. Disaster recovery bundles

**Opportunity:** package the minimum safe material needed to recover a working environment after hardware loss or OS failure.

Possible capabilities:
- recovery profile: essential documents, verified checksums, app inventory, reinstall plan, identity re-bootstrap checklist, and restore order;
- "known-good" verification stamps and periodic integrity checks;
- emergency report variant: short human checklist plus machine-readable manifest for automation;
- optional split bundles (critical small bundle + large archive) for faster recovery.

Constraints:
- recovery bundles must still exclude secrets; include instructions for password manager/browser/account recovery instead.
- key/passphrase loss warnings are blocking when encryption is used.
- recovery guidance must prioritize data integrity and safe restore over speed.

## Suggested sequencing

| Horizon | Focus | Why |
|---|---|---|
| Now | Core wizard, profiles, reports, bundle integrity | Establish trust and verifiable contracts |
| Next | App mappings, accessibility, community recipes, dev/declarative integrations | High user value on top of stable core |
| Later | Backup/sync productization, education/OEM kits | Requires mature UX and trust model |
| Careful/opt-in | Enterprise fleet features, cross-device identity workflows | Highest governance/privacy complexity |

## Success measures

- users complete migrations with fewer forgotten files and clearer manual steps;
- reports make every inclusion/exclusion and secret boundary inspectable;
- verification catches corruption/incomplete transfers before restore;
- advanced features (fleet, recipes, integrations) preserve local-first/privacy-first defaults and transparent trust labels.

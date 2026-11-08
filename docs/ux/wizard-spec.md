# Win2Lin migration wizard UX spec

**Status:** draft  
**Scope:** end-user migration experience for Win2Lin, with a shared flow across CLI/TUI now and GUI later.  
**Related:** [`../architecture.md`](../architecture.md), [`../../specs/bundle-format.md`](../../specs/bundle-format.md), [`../../specs/profiles.md`](../../specs/profiles.md), [`migration-report-spec.md`](./migration-report-spec.md), [`../../VISION.md`](../../VISION.md)

## Purpose

The wizard guides a user through a safe migration: understand what will move, preview actions, export a verifiable bundle, verify integrity, and follow a Linux restore guide. The experience must make risks explicit, keep secrets out of the bundle, and remain local-first by default.

## Design principles

- **Local-first, privacy-first:** scan/export/verify run locally. No telemetry by default. Network actions, if ever offered, must be explicit, minimal, and documented.
- **Never exfiltrate secrets:** the wizard must not copy, export, upload, or recover browser passwords/cookies/session tokens, DPAPI/keychain credentials, private SSH keys, API tokens, or equivalent secrets. It must direct users to safe alternatives (browser sync, password managers, re-authentication).
- **Preview before mutation:** every action that copies or writes data has a dry-run/preview path.
- **Inspectable artifacts:** the wizard produces a plan, bundle metadata/manifests/logs, verification results, and a migration report.
- **Conservative by default:** no-clobber restore defaults, no automatic mutation of immutable/transactional/declarative/managed Linux systems, and clear confirmation for risky options.
- **Resume-friendly:** large exports can be interrupted and resumed safely after re-validating roots, policy, and destination.

## User personas and surfaces

| Surface | Status | Primary use | Interaction model |
|---|---|---|---|
| CLI | now | Scriptable, remote-friendly, power users | Flags/subcommands, plain progress, machine-readable output option |
| TUI | now | Guided terminal experience without full GUI dependency | Step panes, keyboard navigation, explicit confirmations, progress/log panel |
| GUI | later | Mainstream users, richer previews and accessibility affordances | Same flow/state machine; native dialogs, charts/previews, assistive technology support |

All surfaces must share the same core planner/export/verify/report engine and the same safety policy. UX differences are presentation only.

## Wizard flow

### 1. Scan

**Goal:** discover what can be migrated and what must be handled manually.

Inputs:
- selected profile (see `specs/profiles.md`)
- optional custom roots/include/exclude adjustments
- destination availability check (space estimate, not inside a source root)

Outputs:
- inventory summary (user roots, sizes/count estimates, detected apps/config signals where safe)
- risk findings (cloud-sync destination, low disk space, very large roots, inaccessible paths)
- explicit exclusions (secrets, caches/build artifacts, system areas as policy dictates)

UX requirements:
- show "What will be scanned" before scan starts.
- show progress with current area and cancellable operation.
- never display secret values; only high-level presence indicators where useful (e.g., "browser profile detected; credentials are not exportable by Win2Lin").

### 2. Preview / Dry-run

**Goal:** let the user review the exact plan before copying.

Outputs:
- plan artifact (human + JSON): selected roots, estimated files/bytes, exclusions with reasons, checksum/encryption/resume settings, manual actions
- sample file list / grouped categories
- risk prompts requiring acknowledgment when applicable

Required confirmations:
- destination path and free-space acknowledgment if tight
- profile/risk level acknowledgment
- any non-default sensitive-adjacent choice (none may weaken secret policy; secret export is not allowed)
- optional encryption key/passphrase handling warning

Dry-run must not create payload copies except optional temporary inspectable plan files in a safe location chosen by the user/tool policy.

### 3. Export

**Goal:** create a portable bundle.

Actions:
- write bundle metadata (`inventory.json`, plan snapshot, producer info, schema/policy versions)
- copy selected payload into stable anchors per bundle format
- write logs and manifests
- optionally compute checksums during copy or in a post-pass
- optionally encrypt selected artifacts or the bundle container per user choice

Progress:
- overall percent/bytes/files, current root, throughput estimate (best-effort)
- clear partial-failure behavior: continue where safe, record failures, mark bundle status `partial`/`failed` as appropriate
- cancellation produces an inspectable checkpoint when resume is enabled

### 4. Verify

**Goal:** prove what was exported and detect transfer/copy errors.

Verification levels:
- **Quick:** bundle structure, required metadata present, manifest readable, no policy violations detected.
- **Standard:** checksums for metadata/manifests and sampled or all payload entries as configured.
- **Full:** verify every recorded payload checksum; compare counts/sizes; report missing/extra/mismatched files.

Outputs:
- verification summary in the wizard
- machine-readable verification result in the bundle/report
- actionable remediation (re-run export, resume, recopy specific roots, check destination media)

Verification is read-only; it must not modify payload.

### 5. Linux restore guide

**Goal:** hand off to Linux with safe, distro-aware instructions.

Actions:
- generate/point to migration report and Linux next-steps checklist
- explain restore modes: mutable install (confirmed, best-effort) vs restore-only/limited guidance for immutable/transactional/declarative/managed systems
- restate "never restore secrets/private keys" and list public-only SSH files if present
- provide app replacement and manual re-authentication steps

The Windows wizard does not mutate Linux systems. Linux-side actions are performed by Linux tooling/manual steps under Linux system policy.

## Profiles

Profiles are safe presets that select scope, exclusions, and review strictness. They are defined in [`../../specs/profiles.md`](../../specs/profiles.md).

Built-in profile intent:
- **Minimal:** essential user documents/settings signals; smallest bundle; strict review.
- **Office:** documents, media used for work, browser migration guidance (no secrets), common productivity app mapping hints.
- **Dev:** Office baseline plus source folders opt-in review, dev tool config signals, WSL/editor/terminal hints; excludes caches/build outputs by default.
- **Gaming:** user saves/screenshots/media opt-in with publisher/platform caveats; excludes large redistributable game installs by default.

Profile rules:
- profiles may add review prompts but must not weaken secret exclusion policy.
- users can customize after selecting a profile; customizations are recorded in the plan/report.
- unknown/custom profile fields are ignored by older consumers when stored.

## Resume and checkpoints

Resume is enabled by default for copy operations above a configurable size threshold; users may force on/off.

Checkpoint artifact (planned/bundle metadata area): records selected roots, exclusions, destination, profile/options, policy/schema versions, checksum/encryption settings, progress cursor/state, and partial status.

Resume safety requirements:
- refuse to resume if destination is inside a source root or resolves unsafely.
- re-validate source roots, profile/policy versions, and secret-exclusion rules before continuing.
- detect source changes where feasible (size/mtime/hash policy); mark ambiguous files for review rather than silently skipping.
- never resume using weaker safety settings than the original run without explicit confirmation.
- keep checkpoint/report state inspectable; do not hide failures.

## Checksums

Checksums provide integrity evidence for transport and restore.

- default algorithm: **SHA-256** (unless a future policy selects stronger/faster alternatives with explicit metadata).
- scope: metadata/manifests by default; payload checksums configurable as sampled, full, or deferred post-pass.
- manifest records path relative to bundle root, hash algorithm, digest, size, and status.
- large bundles may compute checksums incrementally; partial coverage must be labeled.
- verification reports mismatches with actionable file-level details while avoiding unnecessary sensitive content exposure.

## Optional encryption

Encryption is opt-in and local-first. It protects bundles at rest/in transit according to the chosen tool, but it does **not** make secret exfiltration acceptable — secrets must still be excluded before encryption.

Supported design targets:
- **age:** preferred for modern, scriptable public-key/passphrase workflows; good for recipient-based encryption.
- **gpg:** interoperable option for users already managing OpenPGP keys; wizard must explain key trust/recipient selection.
- **7z:** archive/container option for password-based workflows where users accept archive-format tradeoffs.

Risk prompts (required before enabling):
- key/passphrase loss can make the bundle unrecoverable; user must acknowledge backup responsibility.
- encryption does not replace safe storage or transport choices.
- password-based modes are vulnerable to weak passphrases; recommend strong passphrases/keys.
- recipient/key selection errors can expose data to the wrong party or lock the user out.
- encrypted bundles may reduce inspectability; metadata needed for safe handling should remain available where practical or be documented.
- antivirus/indexers/cloud sync behavior may still interact with encrypted files; default destination remains local.

UX requirements:
- show exactly what will be encrypted (whole bundle, payload only, or selected artifacts).
- require explicit confirmation text/checkbox equivalent in GUI/TUI.
- never log secrets, passphrases, or private key material.

## Clear risk prompts

The wizard uses blocking prompts for high-risk choices and non-blocking notices for informational risks.

Blocking examples:
- destination has low free space.
- destination appears inside a scanned source or cloud-sync folder (unless user explicitly confirms with warning).
- resume checkpoint mismatch or safety-policy change.
- enabling encryption.
- proceeding after partial verification failure.

Notice examples:
- detected large excluded caches/build directories.
- app has no known Linux equivalent; manual step required.
- immutable Linux target expected: restore-only guidance applies.

Every prompt states: what will happen, what will not happen, and the safer alternative.

## Accessibility and i18n (GUI-later requirements)

- keyboard-first navigation in TUI; full keyboard/screen-reader semantics in GUI.
- high-contrast-friendly status indicators; do not rely on color alone.
- plain-language risk summaries with expandable technical details.
- translatable strings; avoid embedding locale-specific assumptions in machine artifacts.

## State model (implementation guidance)

```text
Idle -> ScanConfigured -> Scanning -> ScanComplete
ScanComplete -> DryRun -> PreviewReady
PreviewReady -> ExportConfirmed -> Exporting -> ExportComplete|ExportPartial|ExportFailed
ExportComplete|ExportPartial -> Verifying -> Verified|VerifyFailed
Verified|VerifyFailed|ExportPartial -> RestoreGuideReady
Any cancellable state -> Cancelled/Checkpointed (when applicable)
```

Machine-readable artifacts should carry the state/result so CLI/automation can consume them.

## Acceptance criteria

- A user can complete Scan -> Preview/Dry-run -> Export -> Verify -> Linux restore guide without scripting.
- No secrets are copied or included in manifests/logs by design.
- Dry-run shows planned actions and risks before export.
- Export produces inspectable bundle metadata/logs/manifests.
- Verification reports integrity clearly and is read-only.
- Profiles, resume, checksums, and optional encryption are configurable without weakening core safety policy.
- Linux guidance respects immutable/managed-system no-auto-mutation rules.

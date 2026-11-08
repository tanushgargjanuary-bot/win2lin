# OEM / preload Linux transition kits (spec draft)

**Status:** draft  
**Scope:** vendor-friendly, inspectable migration kits for Linux devices/transition programs.

## Goals
- Branded but transparent migration/report bundles.
- Device-aware restore guidance (drivers/firmware reminders, accessibility checklist) — **guidance, not privileged mutation by default**.
- “First boot on Linux” checklist generated from migration report.
- Compatibility evidence: moved, manual setup, alternatives.

## Safety & trust
- **No hidden telemetry/data collection.** Any OEM metadata is explicit and reviewable.
- **No secret export.** No account/password/session transfer.
- **Conservative system changes:** secure boot/firmware/driver changes require explicit user intent and documented steps; no silent privileged actions.
- Vendor-specific guidance labeled with provenance and tested/best-effort status.

## Artifacts
- Inspectable kit manifest, migration report, first-boot checklist, optional signed vendor metadata (future, opt-in).

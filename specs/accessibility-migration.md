# Accessibility-preserving migration (spec draft)

**Status:** draft  
**Scope:** make accessibility setup critical migration state across CLI/TUI/GUI and target OS guidance.

## Goals
- Detect/report accessibility-relevant signals where safely available (high-level preferences, assistive tool presence, input/display customization hints) — **user-confirmed where appropriate**.
- Map to Linux equivalents/checklists (screen readers, magnification, contrast, keyboard/mouse accommodations, captions, input methods) with confidence/provenance.
- Prioritize accessibility actions in migration checklists and reports.
- Accessible Win2Lin UX: screen-reader semantics, keyboard-only flow, high contrast, scalable text, plain-language risk prompts.

## Safety & privacy
- **Do not infer/export sensitive medical/personal attributes.** Only migration-relevant settings signals and user-confirmed info.
- **No secrets.** Accessibility tooling configs may be portable only if safe; never credentials/tokens.
- Honest gap reporting: manual configuration required where mappings are incomplete.

## Outputs
- Accessibility section in migration plan/report (machine + human readable).
- Target-OS checklist with verification steps and provenance labels.

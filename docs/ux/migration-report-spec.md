# Win2Lin migration report spec

**Status:** draft  
**Scope:** human-readable and machine-readable outputs produced during scan/plan/export/verify/restore guidance.  
**Related:** [`../architecture.md`](../architecture.md), [`../../specs/bundle-format.md`](../../specs/bundle-format.md), [`../../specs/profiles.md`](../../specs/profiles.md), [`wizard-spec.md`](./wizard-spec.md), [`../../VISION.md`](../../VISION.md)

## Purpose

A migration report tells the user what was planned, what happened, what was verified, what requires manual action, and what was intentionally never copied. It must be useful both for a human completing a migration and for automation/auditing that needs stable machine-readable fields.

## Output forms

Every reportable run should produce, where applicable:

| Artifact | Audience | Format | Location (bundle-relative or run-relative) |
|---|---|---|---|
| Human report | end user | Markdown (and later HTML/PDF in GUI) | `reports/migration-report.md` |
| Machine report | tools/automation | JSON | `reports/migration-report.json` |
| Plan snapshot | both | JSON (+ optional Markdown summary) | `reports/plan.json` |
| Verification result | both | JSON (+ summary in human report) | `reports/verify.json` |
| Action checklist | end user | Markdown checklist | `reports/checklist.md` |
| Linux next steps | end user | Markdown | `reports/linux-next-steps.md` or template-derived output |

Producers may also emit existing v0.x artifacts (`inventory.json`, `log.txt`, manifests). The report layer is additive and must not require secrets.

## Common metadata

All machine-readable report files include:

```json
{
  "schema_version": 1,
  "producer": {
    "tool": "Win2Lin",
    "component": "wizard|exporter|verifier|restore-guide",
    "version": "string",
    "platform": "windows|linux|macos"
  },
  "created_at": "ISO-8601",
  "run_id": "stable unique id for the run",
  "bundle_id": "stable id when bundle exists",
  "profile": {"id": "dev", "version": "1", "customized": false},
  "policy": {
    "secret_exclusion": "enforced",
    "local_first": true,
    "system_mutation": "not_performed|confirmed_mutable_only|restore_only_guidance"
  }
}
```

Unknown fields must be ignored by consumers. Timestamps should be ISO-8601 with offset or UTC.

## Human-readable report structure

`migration-report.md` must contain these sections in order:

1. **Summary**
   - run date/time, source host (non-sensitive label), selected profile, bundle destination, overall status (`planned`, `completed`, `partial`, `failed`, `verified`, `verify-failed`).
   - high-level counts/sizes: planned, copied, skipped, failed, verified.
2. **What was included**
   - roots/categories copied, with bundle anchors and notable inclusions.
3. **What was excluded and why**
   - caches/build artifacts, system locations, policy exclusions, user exclusions.
4. **Never copied secrets**
   - mandatory section; see below.
5. **Verification**
   - checksum/manifest checks performed, coverage, mismatches, and remediation.
6. **App replacements and migration mapping**
   - detected/specified Windows apps with Linux alternatives, install method guidance by distro family when known, confidence/provenance, and manual steps.
7. **Manual actions**
   - required user actions not safely automatable.
8. **Linux restore guide**
   - restore mode, immutable/managed-system guidance, safe config restore notes, no-clobber behavior.
9. **Risks and warnings**
   - low disk, partial failures, inaccessible paths, unsupported mappings, encryption/key handling reminders.
10. **Evidence and logs**
    - paths to `inventory.json`, manifests, checksums, logs, JSON report files.

## Machine-readable report schema (conceptual)

`migration-report.json`:

```json
{
  "schema_version": 1,
  "status": "completed",
  "summary": {
    "files": {"planned": 0, "copied": 0, "skipped": 0, "failed": 0},
    "bytes": {"planned": 0, "copied": 0},
    "roots": 0,
    "warnings": 0,
    "manual_actions": 0
  },
  "includes": [
    {"id": "documents", "source": "C:/Users/name/Documents", "bundle_path": "C_DRIVE/Users/name/Documents", "status": "copied"}
  ],
  "excludes": [
    {"source": ".../node_modules", "reason": "profile_exclusion_cache", "policy": "safe_default"}
  ],
  "never_copied_secrets": {
    "policy": "enforced",
    "categories": [
      "browser_passwords",
      "browser_cookies_session_tokens",
      "browser_autofill_secrets",
      "dpapi_or_keychain_credentials",
      "private_ssh_keys",
      "api_tokens_and_app_secrets"
    ],
    "alternatives": [
      "browser_sync",
      "password_manager",
      "reauthentication",
      "public_ssh_material_only"
    ]
  },
  "verification": {
    "performed": true,
    "level": "standard",
    "algorithm": "sha256",
    "coverage": "metadata_and_sampled_payload",
    "result": "passed",
    "mismatches": []
  },
  "app_replacements": [
    {
      "source_app": "Example",
      "target_options": ["Alternative"],
      "confidence": "medium",
      "provenance": "community_mapping",
      "manual_steps": ["sign in", "import supported data"]
    }
  ],
  "manual_actions": [
    {"id": "browser-sync", "priority": "high", "action": "Enable browser sync and verify bookmarks/passwords appear", "safe": true}
  ],
  "linux_restore": {
    "mode": "restore-only",
    "system_mutation": "not_performed",
    "notes": ["Immutable/managed systems receive guidance only"]
  },
  "evidence": {
    "inventory": "inventory.json",
    "plan": "reports/plan.json",
    "verify": "reports/verify.json",
    "logs": ["log.txt"]
  }
}
```

## "Never copied secrets" section (mandatory)

This section must appear in every human report and every machine report, even when no secret-related sources were detected.

Required content:
- a clear statement that Win2Lin does not copy/export/upload secrets;
- categories never copied: browser passwords, cookies/session tokens, autofill/credential secrets, DPAPI/keychain-protected credential stores, private SSH keys, GPG private material, API tokens/app secrets, and equivalent credentials;
- safe alternatives: browser sync, password managers, device/app re-authentication, public-only SSH files (`config`, `known_hosts`, `authorized_keys`, `*.pub`) where appropriate;
- note that encryption of a bundle does not justify including secrets.

Machine reports encode this as a stable object so audits can assert policy presence.

## Actionable checklist

`checklist.md` is a concise completion checklist derived from the report. Items must be specific and safe.

Example groups:
- [ ] Verify bundle integrity (`reports/verify.json` passed).
- [ ] Copy bundle to Linux target via trusted local media.
- [ ] Run Linux restore helper in appropriate mode (restore-only on immutable/managed systems).
- [ ] Re-enable browser sync and confirm data appears.
- [ ] Re-authenticate password manager and critical apps.
- [ ] Review app replacements/manual actions with `confidence`/`provenance`.
- [ ] Keep Windows available until migration is confirmed.

Each item may include evidence links/paths and priority.

## App replacements

Mappings must be transparent:
- `confidence`: high/medium/low/unknown.
- `provenance`: tested mapping, community mapping, heuristic, or user-provided.
- `status`: suggested, partial, manual-only, not-applicable.
- `notes`: licensing, feature gaps, data import caveats.

Never claim automatic migration of licenses, DRM, proprietary data formats, or secret-bearing app state unless a separately reviewed, safe mechanism exists.

## Manual actions

Manual actions are first-class outputs, not failures. Each action includes:
- what the user must do;
- why automation is unsafe/unavailable;
- prerequisites;
- verification step ("how to confirm done");
- privacy note when sign-in/sync is involved.

## Error and partial-result reporting

Reports must distinguish:
- **planned/skipped:** intentional;
- **failed:** attempted but unsuccessful;
- **unverified:** not covered by checksum/manifest verification;
- **manual:** requires user action.

Partial exports/reports are valid outputs. They must carry clear status and remediation steps.

## Privacy and redaction

- Reports may include local paths/usernames necessary for troubleshooting; treat reports as sensitive user data.
- Never include secret values, passphrases, private key contents, tokens, or raw credential material.
- Prefer relative bundle paths in portable artifacts; absolute host paths may appear in host-local logs only when needed and clearly labeled.

## Compatibility

- additive schema evolution with `schema_version`;
- consumers accept older known versions and ignore unknown fields;
- v0.x artifacts remain valid inputs; report files can be generated alongside them.
- template rendering (`templates/migration-report.md.tmpl`, `templates/linux-next-steps.md.tmpl`) may be used to produce human outputs, but machine JSON remains canonical for automation.

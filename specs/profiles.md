# Win2Lin migration profiles spec

**Status:** draft  
**Scope:** safe preset schema for migration profiles used by scan/planning/export/reporting surfaces.  
**Related:** [`bundle-format.md`](./bundle-format.md), [`../docs/ux/wizard-spec.md`](../docs/ux/wizard-spec.md), [`../docs/ux/migration-report-spec.md`](../docs/ux/migration-report-spec.md), [`../VISION.md`](../VISION.md)

## Purpose

Profiles are named, reviewable presets that help users choose an appropriate migration scope without manually selecting every path. They reduce omissions and accidental over-collection, but they must never weaken Win2Lin's safety boundaries.

## Safety invariants (non-overridable)

Every profile, built-in or custom, is evaluated under these invariants:

- **No secret exfiltration:** profiles must not include browser passwords, cookies/session tokens, autofill secrets, DPAPI/keychain-protected credentials, private SSH keys, API tokens, or equivalent secrets.
- **Local-first default:** profile execution does not upload data.
- **Dry-run available:** profile-based plans can be previewed before export.
- **Conservative restore posture:** profiles do not authorize automatic mutation of immutable/transactional/declarative/managed Linux systems.
- **No-clobber awareness:** restore implications should favor no-clobber/backup behavior where applicable.
- **Explicit risk prompts:** high-risk inclusions or customizations require confirmation.

A profile that attempts to disable secret exclusions is invalid and must be rejected by schema validation/policy checks.

## Profile schema

Profiles are data files (JSON or YAML in implementation; JSON Schema is the canonical contract). Suggested location: `data/profiles/<id>.json` (built-in) and user config locations for custom profiles.

### Conceptual schema

```json
{
  "schema_version": 1,
  "id": "dev",
  "name": "Developer",
  "version": "1.0.0",
  "status": "builtin",
  "description": "User data plus developer config signals; excludes caches and build outputs by default.",
  "base_profile": "office",
  "risk_level": "medium",
  "review_mode": "expanded",
  "selection": {
    "include_groups": ["documents", "desktop", "pictures", "dev_configs"],
    "optional_groups": ["source_code_workspaces", "virtual_machines"],
    "exclude_groups": ["browser_credentials", "private_keys", "caches", "build_artifacts"],
    "path_rules": [
      {"action": "include", "pattern": "%USERPROFILE%/Documents/**", "reason": "user_documents"},
      {"action": "exclude", "pattern": "**/node_modules/**", "reason": "recreatable_cache"}
    ]
  },
  "checksums": {"mode": "standard", "algorithm": "sha256"},
  "resume": {"enabled": true},
  "encryption": {"supported": true, "default_enabled": false, "providers": ["age", "gpg", "7z"]},
  "app_mapping": {"enabled": true, "include_provenance": true},
  "manual_actions": ["browser_sync", "reauthentication", "dev_tool_signin"],
  "prompts": [
    {"id": "review-source-code", "when": "optional_group_selected:source_code_workspaces", "severity": "confirm"}
  ],
  "reporting": {"human": true, "machine_json": true, "include_never_copied_secrets": true},
  "policy": {
    "allow_secret_exclusions_override": false,
    "allow_system_mutation": false,
    "local_first": true
  },
  "provenance": {
    "maintainer": "Win2Lin",
    "source": "builtin",
    "reviewed_at": "2026-11-08",
    "notes": "Draft preset; mappings and paths require platform validation."
  }
}
```

### Field requirements

| Field | Required | Description |
|---|---|---|
| `schema_version` | yes | Profile schema version for validation/migration. |
| `id` | yes | Stable machine identifier (`[a-z0-9-]+`). |
| `name` | yes | Human label. |
| `version` | yes | SemVer-like preset version. |
| `status` | yes | `builtin`, `community`, `custom`, or `experimental`. |
| `description` | yes | Plain-language purpose and scope. |
| `risk_level` | yes | `low`, `medium`, `high` (user-facing review intensity hint). |
| `selection` | yes | Groups/path rules; must include secret/key exclusion groups. |
| `policy` | yes | Safety policy flags; secret override must be false. |
| `provenance` | recommended | Origin, maintainer, review date, confidence notes. |
| `base_profile` | no | Inheritance from another profile; merged under invariant checks. |
| `checksums`/`resume`/`encryption` | no | Safe defaults and allowed options; defaults may be overridden by user with prompts. |

Unknown fields are ignored by older readers when safe, but policy/invariant fields must be understood before execution.

## Built-in presets

### Minimal

- **Intent:** smallest safe migration for essential personal files.
- **Typical includes:** Documents/Desktop selected conservatively; optionally Pictures/Videos by confirmation.
- **Typical excludes:** caches/build outputs, app data by default except explicitly safe picks, all secrets/private keys.
- **Review mode:** strict.
- **Use when:** user wants a low-risk first pass or limited storage.

### Office

- **Intent:** everyday productivity migration.
- **Typical includes:** Documents, Desktop, Pictures, common office/media user folders, safe app config signals where known.
- **Typical excludes:** secrets/private keys, browser credential stores, large recreatable caches.
- **App mapping:** office suites, PDF tools, mail/calendar clients (guidance/manual sign-in).
- **Review mode:** standard.

### Dev

- **Intent:** productivity migration plus developer environment signals.
- **Base:** usually extends Office.
- **Typical includes:** shell/editor/terminal/git config signals (safe), project/workspace roots only after review, language/tool metadata where safe.
- **Typical excludes:** `node_modules`, virtualenvs, build outputs, package caches, containers/images by default, secrets/tokens/private keys.
- **Prompts:** confirm large source roots, repositories with submodules, local databases, VM images.
- **Review mode:** expanded.

### Gaming

- **Intent:** preserve personal game-related user data with platform caveats.
- **Typical includes:** screenshots/capture folders, save-game candidates only when path confidence is acceptable, controller/profile config where safe.
- **Typical excludes:** full game installations/redistributables by default, launchers' credential stores, anti-cheat/system drivers, secrets.
- **Manual actions:** launcher re-login, cloud-save verification, per-title save compatibility checks.
- **Review mode:** expanded; confidence/provenance required for save mappings.

## Validation rules

An implementation must reject or quarantine a profile when:
- `policy.allow_secret_exclusions_override` is true or missing in a context that requires explicit false.
- selection rules include secret categories or private key paths as export payload.
- path rules target unsafe restore behavior without explicit, reviewed capability (not default).
- inheritance creates a cycle or resolves to an unknown base in strict mode.
- `schema_version` is unsupported and cannot be safely interpreted.

Warnings (not silent passes):
- community/experimental status;
- stale `reviewed_at`;
- low-confidence app/save mappings;
- broad includes with high estimated size.

## Customization and recording

Users may customize a selected preset in the wizard. The effective plan/report must record:
- base profile id/version;
- user-added/removed groups and path rules;
- confirmations for risky choices;
- resulting checksum/resume/encryption settings.

This preserves repeatability and auditability without mutating the built-in preset.

## Trust and provenance

Because profiles influence what is collected, they are part of the trust surface:
- built-in presets are maintained in-repo and reviewed with code/docs.
- community presets must carry provenance, maintainer/contact or source reference, review date, and confidence notes.
- the UI/report should distinguish tested/built-in behavior from community/heuristic mappings.
- profile distribution must not include secrets or instructions to collect secrets.

# Win2Lin modules

Modules are optional, reviewable extensions for Win2Lin. They add **data and guidance** — app mappings, distro hints, report snippets, inventory enrichers — without weakening core safety rules.

**Status:** scaffold. The module contract is defined in [`../specs/module-api.md`](../specs/module-api.md); host loading/execution may be implemented incrementally.

## Principles

- **Data-driven first.** Prefer YAML/JSON/Markdown/templates. Static data is easier to audit, diff, sign, and port across hosts.
- **Executable hooks are opt-in.** Hooks (for example `detect`, `scan`, `map`, `render`) that run scripts/binaries must be explicitly enabled by the user/operator and constrained by declared permissions. Default is no executable code.
- **Never export or handle secrets.** Modules must not access or emit passwords, tokens, cookies, session data, browser credential stores, DPAPI/keychain secrets, or private SSH/GPG keys.
- **No silent system mutation.** Modules do not install packages, layer systems, rebuild declarative configs, or change system state automatically. On immutable/atomic/transactional/declarative/managed systems, provide manual guidance only.
- **Local-first and reviewable.** Treat modules like code/data you are choosing to trust: inspect before enabling, especially if they contain hooks.

## Creating a module

1. Create a directory named after the module id (lowercase slug, e.g., `my-appmap`).
2. Add `module.yml` following [`../specs/module-api.md`](../specs/module-api.md).
3. Prefer `data/` and `templates/` for static content. Keep `hooks/` empty/absent unless executable behavior is necessary and reviewed.
4. Add `README.md` with purpose, scope, data sources/provenance, caveats, and license.
5. Add validation/tests when practical (schema checks, fixture mappings, golden report snippets).

Minimal data-only layout:

```text
modules/my-appmap/
  module.yml
  README.md
  data/
    mappings.yml
```

See [`example-appmap/`](./example-appmap/) for a tiny safe example that references the Windows→Linux app-mapping concept.

## Installing a module

Current scaffold guidance (until a host installer is finalized):

- **Local/dev use:** place the module directory under a trusted location (for example this repo's `modules/` folder) and point a compatible host/tool at it.
- **Manual install:** copy the module directory into the user-approved Win2Lin modules path chosen by the host implementation. Do not copy modules into system locations unless you trust and manage them deliberately.
- **Before enabling:** read `module.yml`, `README.md`, data files, and any `hooks/` scripts. Confirm `permissions.secrets: deny`, `permissions.system_mutation: deny`, and `safety.handles_secrets: false`.

Future hosts may add `win2lin module add/list/validate/enable` commands; those should preserve explicit opt-in and review.

## Sharing a module

- Publish the module directory as source (Git repo, archive, or PR) with a clear license and provenance for data.
- Include `schema_version`, module `version`, compatibility notes (`platforms`/`directions`), and changelog/release notes.
- Do **not** bundle user exports, inventories from real machines, secrets, or environment-specific credentials.
- For app/package mappings, qualify distro-specific package names and caveats (for example AUR, third-party repos, Flatpak IDs, immutable-system guidance).
- If proposing inclusion in Win2Lin, follow normal contribution review and keep changes scoped.

## Review expectations

Reviewers (and users enabling third-party modules) should check:

| Area | Expectation |
|---|---|
| Safety | No secrets; no credential-store copying; no private keys; no silent installs/mutation. |
| Permissions | `secrets`/`system_mutation` denied; filesystem/network/process access minimal and justified. |
| Hooks | Absent for data-only modules; otherwise opt-in, small, readable, timeout-safe, no obfuscation. |
| Correctness | Package IDs/names, platform claims, and directions are qualified; cautions are present. |
| Privacy | No telemetry by default; no unexpected network calls; sample data is synthetic/sanitized. |
| Provenance | Sources for mappings/data are cited or explained; licenses are compatible. |
| Compatibility | Manifest `schema_version`/module `version` set; unknown fields are safe to ignore. |

A module that influences package installation guidance should be treated as **advisory** unless explicitly reviewed and approved by the host/project policy.

## Versioning

- **Manifest contract:** `schema_version` in `module.yml` follows [`../specs/module-api.md`](../specs/module-api.md). Additive evolution should preserve compatibility; breaking changes require a new schema version.
- **Module releases:** use [Semantic Versioning](https://semver.org/) where practical:
  - `MAJOR` — breaking data/output/compatibility changes.
  - `MINOR` — additive mappings/capabilities, backward-compatible.
  - `PATCH` — fixes, clarifications, safe metadata updates.
- **Data freshness:** mappings (package names, Flatpak IDs, distro workflows) can drift. Record an `updated` date or changelog entry and prefer reviewable diffs.
- **Trust model:** hosts may distinguish local/unreviewed modules from reviewed/trusted modules. Trust is a host/policy decision, not something a module can self-assert.

## Validation checklist

- [ ] Manifest parses and follows `specs/module-api.md`.
- [ ] Module has no secrets or secret-harvesting behavior.
- [ ] Hooks, if present, are opt-in and permission-scoped.
- [ ] Guidance respects immutable/managed-system safety (no auto-mutation).
- [ ] README documents purpose, provenance, limitations, and license.

## Related docs

- [`../specs/module-api.md`](../specs/module-api.md) — module contract.
- [`../specs/bundle-format.md`](../specs/bundle-format.md) — export bundle modules may consume.
- [`../data/app-mappings/windows-to-linux.yml`](../data/app-mappings/windows-to-linux.yml) — current data-driven mapping catalog.
- [`../docs/architecture.md`](../docs/architecture.md) — module/mapping/report architecture.

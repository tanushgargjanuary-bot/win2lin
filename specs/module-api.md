# Win2Lin module API (spec scaffold)

**Status:** draft/scaffold (design contract for future implementation)  
**Scope:** optional, reviewable modules that extend Win2Lin planning, mapping, reporting, and guidance without weakening safety boundaries.

This document defines a **simple, safe module contract**. Modules are intended to make Win2Lin extensible (app mappings, distro hints, report sections, checklists, inventory enrichers) while keeping the core local-first and conservative.

## Goals

- Make extensions **data-driven where possible** (YAML/JSON/Markdown/templates) so they are easy to review and portable.
- Keep modules **inspectable**: metadata, declared capabilities, inputs/outputs, and permissions are visible before use.
- Preserve Win2Lin invariants: **no secret exfiltration**, **no silent system mutation**, and conservative behavior on immutable/atomic/transactional/declarative/managed systems.
- Support future host implementations (PowerShell/Bash/other) through a stable conceptual contract; exact host APIs may be versioned later.

## Non-goals

- A general-purpose plugin marketplace with arbitrary unsigned code execution.
- Replacing core bundle format, restore safety rules, or user confirmation flows.
- Automatic package installation or system mutation performed by modules.

## Safety invariants (non-negotiable)

Modules and module hosts MUST follow these rules:

1. **Never export secrets.** Modules MUST NOT collect, copy, emit, cache, or instruct export of passwords, API tokens, cookies, session tokens, browser credential stores (`Login Data`, `Cookies`, `Web Data`-style credential material), DPAPI/keychain-protected secrets, private SSH/GPG/age keys, recovery codes, or equivalent sensitive material.
2. **Data-first.** Prefer static data files and templates over executable hooks. Executable hooks are **opt-in only** and must be explicitly enabled by the user/operator and constrained by declared permissions.
3. **No silent mutation.** Modules MUST NOT mutate the source or target system, install packages, change system configuration, or write outside declared/host-approved output locations without explicit user confirmation through the host.
4. **Immutable/managed systems.** Modules MUST NOT trigger automatic mutation on immutable/atomic/transactional/declarative/managed Linux systems. They may provide guidance (Flatpak, distrobox/toolbox, manual workflows) consistent with core Win2Lin policy.
5. **Least privilege.** Modules receive only the inputs they declare. Hosts SHOULD default-deny undeclared filesystem, network, process, and environment access.
6. **Transparency.** Module output that influences user decisions (app suggestions, commands, package names, cautions) should include provenance/confidence where practical and must remain reviewable.

## Module package layout

A module is a directory containing at minimum `module.yml` (or `module.yaml`/`module.json` in future-compatible hosts). Recommended layout:

```text
<module-id>/
  module.yml          # required manifest (this contract)
  README.md           # recommended: purpose, data sources, review notes
  LICENSE             # recommended for shared modules
  data/               # optional: data-driven mappings/catalog fragments
  templates/          # optional: report/checklist templates
  schemas/            # optional: JSON Schema / validation aids
  hooks/              # optional: executable hook scripts (opt-in, reviewed)
  tests/              # optional: fixtures and validation tests
```

Hosts may load modules from a trusted local path (e.g., repository `modules/` during development, or a user-approved modules directory). Installation and review expectations are described in [`../modules/README.md`](../modules/README.md).

## Manifest (`module.yml`)

The manifest declares identity, compatibility, capabilities, hooks, and permissions. Unknown fields MUST be ignored by readers for forward compatibility.

```yaml
schema_version: 1
id: example-appmap                  # stable, unique, lowercase slug
name: "Example App Mapping"
version: "0.1.0"                   # SemVer recommended
description: "Windows→Linux app suggestions (data-driven example)."
license: "MIT"                      # SPDX identifier or text reference
homepage: "https://..."            # optional
authors:                            # optional
  - name: "Contributor Name"

compat:
  win2lin_api: ">=0.1 <1.0"        # module contract range (host-defined)
  platforms: [windows, linux]       # platforms where module can run
  directions: [windows-to-linux]    # migration directions; e.g. linux-to-linux later

capabilities:
  # Declared features. Hosts enable only supported/allowed capabilities.
  - detect
  - map
  - render

entrypoints:
  # Data-driven entrypoints are preferred.
  data:
    - path: data/mappings.yml
      kind: app-mapping             # host-defined kind
  templates:
    - path: templates/report.snippet.md
      kind: report-snippet

hooks:
  # Executable hooks are OPTIONAL, DISABLED by default, and require explicit opt-in.
  # Data-only modules should omit this section.
  # detect:
  #   command: hooks/detect.ps1
  #   runtime: powershell
  #   opt_in: required

permissions:
  filesystem:
    read: [bundle, inventory, module_data]   # abstract scopes resolved by host
    write: [module_output]                   # never source roots; host-approved only
  network: deny
  process: deny
  secrets: deny                              # MUST be deny; hosts must enforce
  system_mutation: deny                      # MUST be deny

inputs:
  - name: inventory
    type: win2lin.inventory.json
    required: false
  - name: app_mappings
    type: win2lin.app-mapping
    required: false

outputs:
  - name: suggestions
    type: win2lin.app-suggestions
    path: module_output/suggestions.json

safety:
  handles_secrets: false                      # MUST be false
  executable_hooks: false                     # true only when hooks are declared/opt-in
  review_status: draft                        # draft|community-reviewed|trusted (host policy)
  notes:
    - "Provides suggestions only; never installs packages."
```

### Required fields (minimum viable)

- `schema_version` — manifest schema version (integer; start at `1`).
- `id` — stable identifier (lowercase, `[a-z0-9-]+` recommended).
- `name` — human-readable name.
- `version` — module version (SemVer recommended).
- `description` — short purpose statement.
- `compat` — supported `platforms` and/or `directions` (and API range when implemented).
- `permissions.secrets: deny` and `safety.handles_secrets: false` — explicit safety declaration.

Everything else is optional but recommended for reviewability.

## Hooks

Hooks are named extension points a host may invoke. **Data-driven modules should not define executable hooks.** When hooks exist, they are opt-in and sandbox-conscious.

| Hook | Purpose | Typical inputs | Typical outputs | Safety notes |
|---|---|---|---|---|
| `detect` | Detect platform/distro/environment signals relevant to the module. | host context, selected bundle/inventory metadata | structured facts (JSON) | Read-only signals only; no secrets. |
| `scan` | Produce additional *safe* inventory facts (e.g., app presence hints) from approved inputs. | approved inventory/paths | structured findings (JSON) | Must respect exclusions and never read credential stores. |
| `map` | Transform safe inputs into migration suggestions/mappings. | inventory facts, mapping data | suggestions/checklist items | Suggestions only; no installs/mutation. |
| `render` | Render report/checklist fragments from safe data. | normalized module outputs, templates | text/markdown/json | No embedded secrets; deterministic where possible. |

Additional hooks MAY be added in future schema versions. Hosts MUST NOT invoke undeclared hooks.

### Executable hook constraints

If a host supports executable hooks:

- Execution is **disabled by default** and requires explicit user opt-in per module (or per trusted source, by host policy).
- Hooks MUST declare `runtime` and command/path inside the module package.
- Hooks run with **declared permissions only** (sandbox/profile where the platform allows). Network and process spawning should be denied unless explicitly reviewed and allowed by the host — default is deny.
- Hooks communicate via structured stdin/stdout JSON (recommended) or host-defined files in approved output locations. They MUST NOT print or persist secrets.
- Hosts SHOULD enforce timeouts, output size limits, and non-zero exit handling.
- Hook scripts are subject to the same review expectations as code (see `modules/README.md`).

## Inputs and outputs

- **Inputs** are read-only views provided by the host: bundle metadata, `inventory.json`, safe manifests, selected data catalogs, or normalized scan facts. Inputs MUST exclude secrets.
- **Outputs** are structured artifacts (JSON/YAML/Markdown fragments) written to host-approved module output locations, typically inside a report/export workspace — never into arbitrary system paths.
- Schemas/kinds (e.g., `win2lin.inventory.json`, `win2lin.app-mapping`) are intentionally abstract in this scaffold; concrete schemas should be versioned under `specs/` or `schemas/` as they stabilize.

## Permissions model

Permissions are declarative. Hosts enforce them; manifests cannot grant themselves power.

| Permission | Default | Notes |
|---|---|---|
| `filesystem.read` | host-scoped | Abstract scopes such as `bundle`, `inventory`, `module_data`. Avoid raw arbitrary paths. |
| `filesystem.write` | `module_output` only | No writes to source roots, system config, or user home unless a future host explicitly mediates it. |
| `network` | `deny` | Off by default. Remote lookups, if ever allowed, require explicit opt-in and review. |
| `process` | `deny` | No arbitrary subprocesses by default. |
| `secrets` | `deny` | **Required deny.** Modules cannot request secret access. |
| `system_mutation` | `deny` | **Required deny.** No package/system changes. |

## Versioning and compatibility

- Manifest `schema_version` versions this contract. Additive changes keep the same major behavior; breaking changes require a new `schema_version` and migration notes.
- Module `version` uses SemVer when possible. Hosts may pin, warn on major upgrades, or require review.
- `compat.win2lin_api` (future) expresses host/module API compatibility.
- Readers MUST ignore unknown manifest fields and unknown hook names to allow safe evolution.

## Validation checklist (module authors/reviewers)

- [ ] `module.yml` includes `schema_version`, `id`, `version`, `compat`, and safety declarations.
- [ ] `permissions.secrets` and `permissions.system_mutation` are `deny`; `safety.handles_secrets` is `false`.
- [ ] Data files contain no secrets, tokens, cookies, private keys, or credential-store paths used for copying secrets.
- [ ] Suggestions/commands are guidance only; no automatic installs or system mutation.
- [ ] Immutable/managed-system guidance is conservative/manual where applicable.
- [ ] Executable hooks (if any) are opt-in, minimal, reviewed, and constrained.
- [ ] Package names, paths, and platform claims are qualified (distro/release differences noted).
- [ ] License/provenance for mappings/data is documented.
- [ ] Unknown fields/hooks are harmless; consumers ignore what they do not understand.

## Related docs

- [`../modules/README.md`](../modules/README.md) — create/install/share/review/version modules.
- [`bundle-format.md`](./bundle-format.md) — export bundle contract (inputs modules may read).
- [`../data/app-mappings/windows-to-linux.yml`](../data/app-mappings/windows-to-linux.yml) — example of safe, data-driven mapping content.
- [`../docs/architecture.md`](../docs/architecture.md) — planned module/mapping/report responsibilities.

# Win2Lin export bundle format (spec scaffold)

**Status:** draft/scaffold (documentation of observed behavior + planned evolution)  
**Scope:** Windows-side export output consumed by Linux-side restore/reporting.

This document describes the **Win2Lin export bundle**: a directory produced by
Win2Lin Windows exporters (e.g., `scripts/Win2Lin-lite.ps1`,
`scripts/Win2Lin.ps1`) and read by Linux-side helpers/reports.

It is intentionally conservative: scripts and consumers should tolerate missing
optional files, extra files, and future additive fields.

## Goals

- Make exports portable (USB/external disk/network copy) and inspectable.
- Preserve user data with minimal surprises and clear provenance.
- Support safe restore workflows on Linux (including immutable systems where
  system mutation is not automated).
- Enable future checksums, manifests, resumability, and version negotiation.

## Non-goals / safety constraints

- The bundle **must not contain** secrets copied by Win2Lin tooling:
  passwords, browser cookies/session tokens, DPAPI-locked browser credential
  stores (`Login Data`, `Cookies`, `Web Data`-style credential material), or
  private SSH/GPG keys.
- The bundle format does not grant permission to auto-mutate immutable/atomic/
  transactional/declarative/managed Linux systems. Restore/install behavior must
  remain conservative and user-confirmed where applicable.
- Paths inside manifests/logs may include usernames/machine details; treat the
  bundle as sensitive user data.

## Bundle root

Default export root (current scripts):

```text
C:\Win2Lin_export\<date>_<time>\
```

The folder name is user/operator-visible and not a strict schema requirement.
Consumers should identify a bundle by its contents (presence of known files such
as `inventory.json`, `log.txt`, `manifest.csv`, `C_DRIVE/`, etc.), not only by
the directory name.

## Observed/current layout

Depending on exporter and mode, a bundle may contain:

```text
<bundle>/
  inventory.json          # machine/user/inventory metadata (observed in lite + advanced)
  log.txt                 # human-readable run log (observed)
  robocopy_*.log          # robocopy logs per root (observed in lite copy mode)
  manifest.csv            # file-level copy manifest (observed in advanced)
  copy_result.json        # copy summary/result (observed in advanced)
  C_DRIVE/                # copied data anchored from C: roots (observed in advanced; may appear in future lite layouts)
    Users/<user>/...
  D_DRIVE/                # copied data anchored from D: roots when selected/copied
    ...
```

Not every file appears in every run. Inventory-only runs may create metadata/logs
without copying data payload directories.

## Core members

### `inventory.json`

**Purpose:** high-level scan/export metadata and inventory for planning.
**Observed:** produced by both lite and advanced exporters (contents differ).

Recommended/observed characteristics:

- UTF-8 JSON (advanced explicitly writes UTF-8 no BOM; consumers should accept
  UTF-8 with/without BOM where practical).
- Additive fields are allowed over time.
- Should never include secrets (passwords, tokens, cookies, private keys).

Suggested fields (extensible; not all required today):

| Field | Type | Notes |
|---|---|---|
| `schema_version` | integer/string | Bundle/inventory schema version. Future producers should set this. |
| `producer` | object | Tool name, script, version/commit, mode (inventory/copy/dry-run). |
| `created_at` | string | ISO-8601 timestamp, preferably UTC or with offset. |
| `host` | object | Windows machine/user hints, OS version; avoid unnecessary sensitive detail. |
| `source_roots` | array | Selected copy roots and decisions (include/skip reasons). |
| `summary` | object | Counts/sizes/warnings; best-effort. |
| `notes` | string/array | Safety notes, e.g., browser credentials never copied. |

Consumers must ignore unknown fields.

### `manifest.csv` (advanced / optional)

**Purpose:** file-level record of planned/copied items (implementation-specific).
**Observed:** used by the advanced exporter; dry-run may emit a temp manifest for
inspection.

Typical columns (may evolve): source path, destination/bundle-relative path,
size, status/result, skip reason. Exact column names/order are
implementation-defined until formalized; future versions should publish a stable
header or include a manifest descriptor.

### `copy_result.json` (advanced / optional)

**Purpose:** machine-readable copy summary (counts, failures, elapsed time,
resume/checkpoint hints if implemented).

Future-friendly fields:

```json
{
  "schema_version": 1,
  "status": "completed|partial|failed|dry-run",
  "started_at": "...",
  "finished_at": "...",
  "files": {"planned": 0, "copied": 0, "skipped": 0, "failed": 0},
  "bytes": {"planned": 0, "copied": 0},
  "roots": [],
  "errors": [],
  "checkpoint": {"supported": false}
}
```

### Logs (`log.txt`, `robocopy_*.log`)

**Purpose:** human troubleshooting and audit trail.

- `log.txt`: Win2Lin tool log.
- `robocopy_*.log`: robocopy output (lite mode). Robocopy exit codes follow
  robocopy conventions; Win2Lin should summarize them plainly for users.

Logs may contain local paths and usernames; handle as sensitive.

### Payload directories (`C_DRIVE/`, `D_DRIVE/`)

**Purpose:** copied user data, anchored to avoid collisions and preserve origin.

- `C_DRIVE/`: drive-anchored copy of selected C: content (commonly under
  `Users/<user>/...`).
- `D_DRIVE/`: drive-anchored copy of selected D: content, when included.

Rules:

- Do not place exports inside a source root (scripts guard against self-copy
  loops).
- Preserve normal file data; do not synthesize secret stores.
- Path length, permissions/ACL metadata, symlinks/junctions, and alternate data
  streams are Windows/NTFS-specific concerns; current behavior is
  implementation-dependent and should be documented by the producer when relevant.

## Checksums (v1 — implemented)

`scripts/Verify-Win2LinBundle.ps1` (PowerShell) and the optional Rust helper
(`rust/win2lin-verify`, same format) implement SHA-256 bundle verification:

```text
<bundle>/
  checksums.sha256        # UTF-8, no BOM. Lines: "<hex> *<relative-path>"
```

Format rules:
- SHA-256 lowercase hex, two spaces? Compatible `sha256sum` coreutils-style: `<hex> *<relative-path-with-slashes>` (also accepts `<hex>  <path>` / `<hex> <path>` on verify).
- Paths relative to bundle root, `/` separators, sorted, reviewable.
- Default `Write` covers metadata (`inventory.json`, `manifest.csv`, `copy_result.json`,
  `log.txt`, `robocopy_*.log`, `migration-report.md`, etc.). `-IncludePayload` adds `C_DRIVE`/`D_DRIVE`
  payload files (slow for large bundles).
- `Verify` is read-only: reports `OK`/`BAD`/`MISSING` per line; exit `0` if all OK,
  `2` if any BAD/MISSING. Never modifies payload.

Exit codes & stability:
- Checksum write/verify: `0`=OK, `2`=BAD/MISSING, `1`=tool/usage error.

## Versioning

Versioning should be additive and negotiable:

- `schema_version` in JSON metadata/manifests indicates producer format.
- Readers should accept older known versions and ignore unknown additive fields.
- Breaking changes require a new schema version and migration notes.
- A bundle may include both legacy files and newer descriptors during
  transitions.

Suggested compatibility rule:

> Producers write the newest supported schema they implement. Consumers choose
> behavior based on recognized `schema_version`; if absent, use best-effort
> detection from known filenames/headers.

## Resume / checkpoints (future ideas)

Large copies are interruptible; future exporters may support resumable runs.

Possible checkpoint artifact:

```text
<bundle>/
  checkpoint.json
```

Conceptual fields:

- selected roots and exclusion rules
- last completed file/root cursor or per-file state
- manifest/checksum progress
- producer version and compatibility token
- timestamp and final/partial status

Resume safety requirements:

- Never resume into a different destination that overlaps a source.
- Re-validate roots and exclusion/safety rules before continuing.
- Detect changed source files when feasible (size/mtime/hash policy) and mark
  ambiguous cases for review.
- Keep partial state inspectable; do not hide failures.

## Linux restore expectations

Linux consumers (`scripts/Win2Lin.sh`, manual workflows, templates) should:

- Locate bundles by common roots and known members.
- Treat copied data as regular files/directories.
- Restore only safe config candidates by default; never restore private keys or
  browser credential stores.
- Default to **no automatic system mutation** on immutable/atomic/transactional/
  declarative/managed systems; provide manual guidance instead.
- Use `templates/migration-report.md.tmpl` and
  `templates/linux-next-steps.md.tmpl` to track verification and follow-up.

## Validation checklist (for producers/consumers)

- [ ] Bundle has no passwords/cookies/tokens/private keys added by Win2Lin.
- [ ] `inventory.json` is valid UTF-8 JSON and safe to inspect.
- [ ] Logs/manifests are present when expected for the selected mode.
- [ ] Payload directories use stable anchors (`C_DRIVE`, `D_DRIVE`) when used.
- [ ] Unknown files/fields do not crash consumers.
- [ ] Future checksums/versioning/resume features are additive and documented.
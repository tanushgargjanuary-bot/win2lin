# Win2Lin distro package data (community scaffold)

This directory is a **data-only** scaffold for community-contributed, per-distro
package names, install commands, and notes that can complement
`data/app-mappings/windows-to-linux.yml`.

The goal is to make Linux reinstall guidance more accurate **without** turning
Win2Lin into an unsafe auto-installer.

## What belongs here

- Per-distro or per-family package-name overrides (e.g., package names that
  differ from generic mapping defaults).
- Human-reviewed command examples for *mutable* systems, clearly labeled as
  examples/manual guidance.
- Notes about repositories, codecs, package split differences, or naming quirks.
- Compatibility notes for immutable/atomic/transactional/declarative/managed
  systems (Flatpak refs, distrobox/toolbox guidance, manual workflows).

## What does NOT belong here

- Secrets, tokens, passwords, cookies, browser credential stores, or private
  keys.
- Destructive commands (`rm -rf`, disk/partition operations, forced overwrites).
- Silent privilege escalation or unattended system mutation.
- Instructions that bypass the target OS's supported update model.

## Safety model (important)

Win2Lin's Linux-side behavior is intentionally conservative:

- **Mutable systems** (typical apt/dnf/pacman/zypper/apk/xbps/eopkg workflows):
  may support best-effort, *confirmed* install guidance/mode where implemented.
- **Immutable/atomic/transactional/declarative/managed systems**: **never
  auto-mutate**. This includes, but is not limited to, Fedora Atomic / Universal
  Blue / rpm-ostree systems (Bazzite, Bluefin, Aurora, Silverblue, Kinoite),
  openSUSE MicroOS/Aeon/Kalpa transactional workflows, Vanilla OS/abroot-managed
  flows, NixOS/Guix System declarative reconfiguration, and SteamOS-managed
  system areas. For these systems, prefer:
  - **Flatpak** for GUI apps where appropriate.
  - **distrobox/toolbox** for mutable user-space dev environments.
  - **Manual, documented workflows** only when the user understands them.

Community data must not be used to auto-run package mutations on immutable
systems. If a script consumes this data in the future, it must preserve the
"ask before install" and "no auto system mutation on immutable systems" rules.

## Suggested layout (extensible)

Keep files small and reviewable. One possible structure:

```text
data/distro-packages/
  README.md
  families/
    debian-ubuntu.yml      # apt-family notes (Debian, Ubuntu, Mint, Pop!_OS, Zorin, etc.)
    fedora-rhel.yml        # dnf/yum-family notes (Fedora, Nobara/Ultramarine when mutable)
    arch.yml               # pacman-family notes (Arch, CachyOS, Garuda, EndeavourOS, etc.)
    opensuse.yml           # zypper notes; separate immutable transactional guidance
  distros/
    bazzite.yml            # immutable/atomic: Flatpak/distrobox/manual guidance only
    nixos.yml              # declarative: no auto system rebuild; profile/Home Manager notes
    microos.yml            # transactional: no auto transactional-update installs
```

Exact filenames/keys may evolve; consumers should ignore unknown fields.

## Suggested entry shape (example)

```yaml
schema_version: 1
scope:
  kind: distro            # distro | family
  id: fedora
  match:                  # optional hints; not a guarantee
    os_release_id: ["fedora"]
package_manager: dnf
mutability: mutable       # mutable | immutable | transactional | declarative | managed | unknown
apps:
  - mapping_id: dev-vscode
    prefer:               # ordered suggestions
      - method: flatpak
        package: com.visualstudio.code
      - method: dnf
        package: code
        requires_repo: "Microsoft VS Code repo (verify official instructions)"
        notes: "Only for mutable Fedora systems; ask before installing."
  - mapping_id: media-vlc
    prefer:
      - method: flatpak
        package: org.videolan.VLC
      - method: dnf
        package: vlc
        notes: "Codec support may depend on enabled repos and local policy."
notes:
  - "Verify package names on the target release before install."
  - "Do not auto-mutate immutable Fedora Atomic variants."
```

## Contribution checklist

When adding or updating entries:

1. **Be specific**: state distro/family and release assumptions if relevant.
2. **Be safe**: mark mutability honestly; never suggest auto system mutation for
   immutable/transactional/declarative systems.
3. **Be verifiable**: prefer official package names/docs; add notes when a
   third-party repo is required.
4. **Be minimal**: do not add large command scripts; prefer data + short notes.
5. **No secrets**: never include credentials, tokens, or private endpoints.
6. **Review impact**: if data may drive future automation, assume a bug could
   affect real systems and keep guidance conservative.

## Relationship to other Win2Lin files

- `data/app-mappings/windows-to-linux.yml`: cross-distro app alternatives and
  migration strategy (sync/manual/config/reinstall).
- `scripts/Win2Lin.sh`: Linux-side helper with conservative detection and
  no-auto-mutation rules for immutable systems.
- `specs/bundle-format.md`: export bundle layout consumed during restore/reporting.

If package data and script behavior disagree, treat **safety** and **no auto
mutation on immutable systems** as the source of truth until reviewed.
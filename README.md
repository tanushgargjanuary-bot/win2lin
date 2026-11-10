# Win2Lin

**Win2Lin** is a safe, practical toolkit for moving from **Windows to Linux** with less pain. It scans your Windows PC, exports your important files (never passwords), and gives you a clear, step-by-step plan for reinstalling apps and restoring access on Linux.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![GitHub Actions](https://img.shields.io/badge/CI-GitHub%20Actions-2088FF?logo=github-actions&logoColor=white)](.github/workflows/ci.yml)
[![CodeRabbit](https://img.shields.io/badge/CodeRabbit-PR%20Reviews-FF6B35?logo=coderabbit&logoColor=white)](https://github.com/apps/coderabbitai)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](scripts/Win2Lin.ps1)
[![Rust](https://img.shields.io/badge/Rust-Optional%20Accelerator-orange?logo=rust&logoColor=white)](rust/win2lin-verify)

---

## Table of contents

- [Why Win2Lin?](#why-win2lin)
- [What's included](#whats-included)
- [Quick start (Windows)](#quick-start-windows)
- [What gets copied (and what doesn't)](#what-gets-copied-and-what-doesnt)
- [Safety guarantees](#safety-guarantees)
- [Command-line usage](#command-line-usage)
- [Linux support](#linux-support)
- [Limitations](#limitations)
- [Advanced tools](#advanced-tools)
- [Contributing](#contributing)
- [Security](#security)
- [License](#license)

---

## Why Win2Lin?

Switching to Linux is usually easy for **files** and hard for *everything around them*: where configs live, which apps you used, browser logins, and "what did I forget?" Win2Lin makes that process **safer and more repeatable** by:

- Scanning your Windows machine (apps, dev tools, browser profiles, fonts, git repos)
- Copying only your user data (Documents, Desktop, Downloads, Pictures, Videos, Music, D:\)
- Giving you a clear **re-login checklist** (browser sync, password manager, apps)
- Supporting **100+ Linux distros** with honest, safe graceful degradation
- **Never** copying browser passwords, cookies, private keys, or DPAPI secrets

---

## What's included

| File | Purpose | When to use |
|---|---|---|
| `Win2Lin.bat` | Double-click wizard (Inventory / Dry-run / Copy) | **Most users** |
| `scripts/Win2Lin-lite.ps1` | Simple exporter using `robocopy` (built into Windows) | **Recommended** — fewer moving parts |
| `scripts/Win2Lin.ps1` | Advanced exporter (richer inventory, CSV manifest, custom copy engine) | When you want detailed manifests/progress |
| `scripts/Win2Lin.sh` | Linux-side helper (installs common tools, restores safe configs) | After copying the export to Linux |
| `scripts/Verify-Win2LinBundle.ps1` | SHA-256 checksum write/verify | Integrity verification |
| `scripts/New-Win2LinReport.ps1` | Migration report generator | Post-export planning |
| `scripts/New-Win2LinRecoveryKit.ps1` | Disaster recovery checklist | Backup/recovery planning |
| `rust/win2lin-verify/` | Optional Rust accelerator (same checksum format) | CI / large bundles |

---

## Quick start (Windows)

> Run this **on Windows before** you switch.

1. **Download/clone this repo** on your Windows PC.
2. **Turn on browser sync** (Brave/Edge/Chrome): Settings → Sync → sign in.  
   Optional but recommended: export bookmarks as HTML as a backup.
3. **Double-click `Win2Lin.bat`**.
   - Type `1` → **Inventory** (safe, copies nothing)
   - Type `2` → **Dry run preview**, then `Y` to copy for real
4. Copy the export folder (default: `C:\Win2Lin_export\<date>_<time>`) to a USB drive or external disk.
5. Install Linux (dual-boot first if you're unsure). Copy the export folder to your Linux home directory.
6. On Linux, run:
   ```bash
   bash /path/to/Win2Lin.sh ~/Win2Lin_export/<date>_<time>
   ```
7. **Re-login** (in order): browser sync → Google Password Manager → your key apps (e.g. IDEs, dev tools).

---

## What gets copied (and what doesn't)

### Copied (by default)
- Your user folders: **Documents, Desktop, Downloads, Pictures, Videos, Music**
- `D:\` (unless you skip it with `-SkipD`)
- **Never copied:** `node_modules`, `.venv`, `__pycache__`, recycle bin, system volume info (these are better recreated on Linux)

### Never copied (hard safety boundary)
- Browser `Login Data`, `Cookies`, `Web Data`, `Local Storage`, `IndexedDB`, `Preferences`, `Secure Preferences`, `Local State`, `History`, `Sessions`
- DPAPI/keychain-protected credential stores, SAM/security hives
- `pagefile.sys`, `hiberfil.sys`, `swapfile.sys`
- Private SSH keys (`id_rsa`, `id_ed25519`), `*.pfx`, `*.kdbx`, `.aws/.azure/.gnupg` private material
- `C:\Windows`, `C:\Program Files`, `C:\ProgramData`

> **Why?** Windows locks these with DPAPI — they're useless on Linux and copying them would create a security risk. Use **browser sync** and **password manager** instead.

### Browser profiles (metadata only)
The script records **profile counts, extension counts, and sizes** — never password/cookie contents. It also checks whether browser sync folders exist (heuristic, not proof).

---

## Safety guarantees

| Guarantee | Detail |
|---|---|
| **Local-first** | Default export location is `C:\Win2Lin_export\...` (not OneDrive) — no accidental cloud upload |
| **No secret exfiltration** | Passwords, cookies, tokens, private keys are never copied/exported/restored |
| **Self-copy guard** | Destination inside a source folder = hard abort (prevents infinite loops) |
| **Dry-run first** | Every copy path supports preview mode (no files copied) |
| **No destructive mirror** | No `/MIR`/`--Purge`/`--Delete` operations; no-clobber by default |
| **Atomic copies** | Advanced exporter uses temp+rename (`.part.<GUID>`) — incomplete files never become final |
| **Checksums** | SHA-256 metadata checksums written post-copy; `Verify` mode is read-only (exit `0`=OK, `2`=BAD/MISSING) |
| **Immutable Linux** | Never auto-mutates rpm-ostree/Atomic, transactional, NixOS, Guix, Vanilla OS, or SteamOS systems |
| **Read-only verify** | `Verify-Win2LinBundle.ps1 -Mode Verify` never modifies payload |

---

## Command-line usage

### Lite (recommended)

```powershell
# Inventory only
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 -Mode Inventory

# Preview (no files copied)
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 -Mode Copy -DryRun

# Real copy
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 -Mode Copy

# Skip D:\ drive
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 -Mode Copy -SkipD

# Minimal profile (Documents + Desktop only)
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 -Mode Copy -Profile Minimal
```

### Advanced

```powershell
# Inventory + rich metadata
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin.ps1 -Mode Inventory

# Preview
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin.ps1 -Mode Copy -DryRun

# Real copy (resume on, no-clobber)
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin.ps1 -Mode Copy -Resume

# Dev profile with code folder
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin.ps1 -Mode Copy -Profile Dev -IncludePath C:\Projects -DryRun
```

### Tools

```powershell
# Generate migration report from bundle
.\scripts\New-Win2LinReport.ps1 -BundlePath C:\Win2Lin_export\<date>

# Generate recovery checklist
.\scripts\New-Win2LinRecoveryKit.ps1 -BundlePath C:\Win2Lin_export\<date>

# Verify bundle integrity
.\scripts\Verify-Win2LinBundle.ps1 -BundlePath C:\Win2Lin_export\<date> -Mode Verify

# Write full payload checksums (slow, opt-in)
.\scripts\Verify-Win2LinBundle.ps1 -BundlePath C:\Win2Lin_export\<date> -Mode Write -IncludePayload
```

---

## Linux support

`scripts/Win2Lin.sh` aims for **maximum practical portability** with honest, safe graceful degradation. It uses `/etc/os-release` (`ID`, `ID_LIKE`, `VARIANT_ID`, `PRETTY_NAME`) and command/presence hints — **not every new or trending distro has been tested**, but core restore is designed to remain portable.

### Core restore (universal goal)
Locating the export and restoring safe files (`.gitconfig`, selected dot-config dirs with no-clobber, fonts, and safe SSH files only: `config`, `known_hosts`, `authorized_keys`, `*.pub` — **never** private keys/passwords/tokens/cookies) should work on almost any Linux environment that has `bash` plus basic core utilities. If tools like `find`, `cp`, or `python` are missing, it degrades and continues where possible.

### Modes
The script prints a clear mode summary — **`install`** (mutable systems, asks for confirmation before best-effort installs), **`limited`** (best-effort/manual guidance), or **`restore-only`** (no automatic system mutation) — plus core restore.

### Safety rule
Win2Lin **never auto-mutates immutable/atomic/transactional/declarative/managed systems** (no `rpm-ostree` layering, no automatic `transactional-update` package installs, no NixOS system rebuild, no `guix system reconfigure`, no `abroot`/managed system changes). It defaults to skipping system package mutation and giving manual guidance.

### Mutable families (best-effort install mode, confirmed)
- `apt`/`apt-get`: Debian, Ubuntu, Linux Mint, Pop!_OS, Zorin OS, elementary OS, KDE neon, TUXEDO OS
- `dnf`/`yum`: Fedora/RHEL family, including mutable Fedora derivatives (Nobara, Ultramarine)
- `pacman`: Arch family — CachyOS, Garuda, EndeavourOS, blendOS, Manjaro, **Omarchy**
- `zypper`: mutable openSUSE Leap/Tumbleweed/SLE
- `apk`: Alpine/postmarketOS
- `xbps-install`: Void
- `eopkg`: Solus

### Atomic / immutable / transactional / declarative / managed (restore-only or limited guidance)
- **Universal Blue / Fedora Atomic (rpm-ostree/OSTree):** Bazzite, Bluefin, Aurora, Silverblue, Kinoite — no auto `rpm-ostree install`; use Flatpak/distrobox/toolbox/Homebrew or manual
- **openSUSE MicroOS / Aeon / Kalpa (transactional):** no auto `transactional-update`; Flatpak/distrobox/manual
- **Vanilla OS (v2+ / managed):** `abroot`/`apx`; no system mutation; use `apx`, Flatpak, distrobox
- **Guix System / Guix:** no `guix system reconfigure`; user-profile `guix install` or Guix Home
- **SteamOS:** restore-only by default (readonly/managed); Flatpak/distrobox
- **NixOS / Nix variants:** no system rebuild; `nix profile install`, Home Manager, or manual config
- **Clear Linux (`swupd`):** conservative/best-effort bundle names
- **Gentoo (`emerge`):** cautious/manual guidance only

**Beginner-friendly starting points:** Linux Mint 22 (Cinnamon) or Ubuntu 24.04 LTS. Use dual-boot first and keep Windows for 1–2 weeks.

---

## Limitations (honest)

| Area | Current limit | Can relax (future)? |
|---|---|---|
| **Direction** | Windows → Linux only (no Linux→Linux, macOS→Linux, or Windows→Windows exporters) | Yes — via shared bundle contract; each needs own inventory/path mapping |
| **Browser logins** | No passwords/cookies/sessions (DPAPI-locked). Requires browser sync/password-manager re-login | **No — hard safety boundary. Do not relax.** |
| **System state** | No registry/services/drivers auto-migration; GPU/Wi-Fi/printer guidance is manual/distro-dependent | Partly — better guidance/checklists, never silent privileged mutation |
| **Distro automation** | Restore-only for immutable/atomic/transactional/declarative systems | Partly — more recipes/tests, never auto-mutate |
| **Scale/robustness** | Large bundles slow; full payload hashing/resume not polished | Yes — resumable, verified chunked transfers |
| **UX** | CLI/wizard only (no GUI/TUI app) | Yes — via `docs/ui-next.md`; must reuse bundle core |
| **Ecosystem** | No published releases/packages, signatures, CodeRabbit enabled, or distro test matrix | Yes — releases + checksums/signing, CI matrix |
| **Data coverage** | App mappings curated but incomplete; Brave/Edge primary | Yes — grow `data/app-mappings/` with reviewed entries |

**Do not relax:** secret exfiltration, silent cloud upload, auto-mutation of immutable systems, destructive mirroring. Those limits are the product's trust foundation.

### Priority work (v1 → v1.1 → v2)
1. **v1 (now):** tests ✅, checksums ✅, report ✅ → release + checksums/signing + CodeRabbit + distro matrix CI
2. **v1.1:** resumable/verified large copies, hardware/driver checklist, app-mapping growth
3. **v2:** Linux→Linux exporter, TUI/GUI wrapping same core, optional Rust copy/hash accelerator. macOS/Win→Win after that.

---

## Advanced tools

| Tool | Purpose |
|---|---|
| `scripts/Verify-Win2LinBundle.ps1` | SHA-256 checksum write/verify (read-only verify, exit `0`=OK / `2`=BAD/MISSING) |
| `scripts/New-Win2LinReport.ps1` | Migration report from `inventory.json` (safety + identity + accessibility) |
| `scripts/New-Win2LinRecoveryKit.ps1` | Disaster recovery checklist |
| `rust/win2lin-verify` | Optional cross-platform Rust accelerator (same checksum format) |

---

## Contributing

- Open issues/PRs for bugs and improvements.
- `.coderabbit.yaml` is included — install the [CodeRabbit GitHub App](https://github.com/apps/coderabbitai) on your fork for automated PR reviews.
- Local checks:
  - PowerShell: `Invoke-ScriptAnalyzer -Path .\scripts -Recurse` and `Invoke-Pester .\tests`
  - Bash: `shellcheck .\scripts\Win2Lin.sh`
- Read `CONTRIBUTING.md` and `SECURITY.md` before contributing.

## Security

Win2Lin **never** copies, exports, or restores:
- Browser passwords, cookies, session tokens, DPAPI-locked credential stores
- Private SSH/GPG keys, API tokens, MFA secrets
- `pagefile.sys`, `hiberfil.sys`, `swapfile.sys`

Use **browser sync**, **password manager**, and **re-authentication** on Linux instead.

Report vulnerabilities privately — see `SECURITY.md`.

## License

MIT — see [LICENSE](./LICENSE).

---

<p align="center">
  <sub>Built for people who want to switch to Linux without losing their mind — or their data.</sub>
</p># CodeRabbit review trigger

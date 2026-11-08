# Win2Lin

**Win2Lin** helps you move from Windows to Linux with less pain.

It scans your Windows machine, exports your important files, and gives you a clear checklist for reinstalling apps and restoring access on Linux. It **does not** copy browser passwords/cookies (Windows locks them with DPAPI) — use browser sync instead.

## Why this exists

Switching to Linux is usually easy for files and hard for *everything around* them: where configs live, which apps you used, browser logins, and "what did I forget?" This tool makes that process safer and more repeatable.

## What's included

| File | Purpose | When to use |
|---|---|---|
| `Win2Lin.bat` | Double-click wizard (Inventory / Copy preview / Copy) | **Most users** |
| `scripts/Win2Lin-lite.ps1` | Simple exporter using `robocopy` (built into Windows) | **Recommended** if you want fewer moving parts |
| `scripts/Win2Lin.ps1` | Advanced exporter (richer inventory, CSV manifest, custom copy engine) | When you want detailed manifests/progress features |
| `scripts/Win2Lin.sh` | Linux-side helper (installs common tools, restores safe configs) | After copying the export to Linux |

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

## Command-line usage

### Lite (recommended)

```powershell
# Inventory only
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 -Mode Inventory

# Preview (no files copied)
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 -Mode Copy -DryRun

# Real copy
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 -Mode Copy

# Skip D:\
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 -Mode Copy -SkipD
```

### Advanced

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin.ps1 -Mode Inventory
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin.ps1 -Mode Copy -DryRun
powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin.ps1 -Mode Copy -Resume
```

## What gets copied

**Copied (by default):** your user folders — Documents, Desktop, Downloads, Pictures, Videos, Music — and `D:\` (unless you skip it).

**Skipped (common, safer/smaller):** `node_modules`, `.venv`, `__pycache__`, recycle bin/system volume info. These are usually better recreated on Linux.

**Never copied:** browser `Login Data`, `Cookies`, `Web Data`, and other credential/DPAPI-locked material. The Linux side requires you to log in again — that's by design.

## Safety notes

- Default export location is **local** (`C:\Win2Lin_export\...`), not OneDrive, to avoid accidental cloud upload of inventory manifests.
- The scripts refuse to export **inside** a source folder (prevents self-copy loops).
- Use **Dry Run** first. Keep Windows for at least 1–2 weeks after switching.
- This tool is provided as-is. Review the scripts before running, especially if you add custom copy roots.

## Linux support

`scripts/Win2Lin.sh` aims for **maximum practical portability** with honest, safe graceful degradation. It uses **best-effort detection/guidance** from `/etc/os-release` (`ID`, `ID_LIKE`, `VARIANT_ID`, `PRETTY_NAME`) and command/presence hints — **not every new or trending distro has been tested**, but core restore is designed to remain portable.

- **Core restore (universal goal):** locating the export and restoring safe files (`.gitconfig`, selected dot-config dirs with no-clobber, fonts, and safe SSH files only: `config`, `known_hosts`, `authorized_keys`, `*.pub` — **never** private keys/passwords/tokens/cookies) should work on almost any Linux environment that has `bash` plus basic core utilities. If tools like `find`, `cp`, or `python` are missing, it degrades and continues where possible.
- **Modes:** the script prints a clear mode summary — **`install`** (mutable systems, asks for confirmation before best-effort installs), **`limited`** (best-effort/manual guidance), or **`restore-only`** (no automatic system mutation) — plus core restore.
- **Safety rule:** Win2Lin **never auto-mutates immutable/atomic/transactional/declarative/managed systems** (no `rpm-ostree` layering, no automatic `transactional-update` package installs, no NixOS system rebuild, no `guix system reconfigure`, no `abroot`/managed system changes). It defaults to skipping system package mutation and giving manual guidance.

### Mutable families (best-effort install mode, confirmed)

- `apt`/`apt-get`: Debian, Ubuntu, Linux Mint, **Pop!_OS**, **Zorin OS**, **elementary OS**, **KDE neon**, **TUXEDO OS**, and related derivatives.
- `dnf`/`yum`: Fedora/RHEL family, including mutable Fedora derivatives such as **Nobara** and **Ultramarine** when `dnf` is available.
- `pacman`: Arch family, including **CachyOS**, **Garuda**, **EndeavourOS**, **blendOS**, Manjaro, and **Omarchy** (mutable Arch-based systems; installs are always confirmed).
- `zypper`: mutable openSUSE Leap/Tumbleweed/SLE systems.
- `apk`: Alpine/postmarketOS family.
- `xbps-install`: Void.
- `eopkg`: Solus.

### Atomic / immutable / transactional / declarative / managed (restore-only or limited guidance; no auto system mutation)

- **Universal Blue / Fedora Atomic (rpm-ostree/OSTree):** **Bazzite**, **Bluefin**, **Aurora**, Silverblue, Kinoite, etc. No automatic `rpm-ostree install`/layering. Suggest **Flatpak**, **distrobox/toolbox**, Homebrew-on-Linux if relevant, or careful manual `rpm-ostree` workflow.
- **openSUSE MicroOS / Aeon / Kalpa (transactional):** detected via `ID`/`VARIANT_ID`/`ID_LIKE`/`PRETTY_NAME` and/or `transactional-update`. **No automatic `transactional-update` package install.** Suggest Flatpak, distrobox, or a manual transactional workflow.
- **Vanilla OS (v2+ / managed):** may use `abroot`/`apx`; treated as managed/immutable. **No automatic system package mutation.** Suggest `apx`, Flatpak, distrobox, or manual steps.
- **Guix System / Guix:** detected via `guix`, `ID=guix`, or `/gnu/store`. **No automatic system reconfiguration.** Suggest `guix install` (user profile), Guix Home, or manual config; core restore still works.
- **SteamOS:** detected via SteamOS hints (for example `/etc/os-release`, `/etc/steamos-release`, `steamos-readonly`). Treated cautiously because system partitions/readonly/managed state can be involved; defaults to **restore-only/limited guidance**. Suggest Flatpak/distrobox; manage system packages manually only if you understand SteamOS implications.
- **NixOS / Nix variants:** declarative; **no automatic system rebuild/config changes**. Suggest `nix profile install`, Home Manager, or manual Nix config.
- **Clear Linux (`swupd`):** bundle names differ; conservative/best-effort guidance only.
- **Gentoo (`emerge`):** cautious/manual guidance only (package names/USE flags are system-specific).

- **Privileges:** supports root, `sudo`, `doas`, or `pkexec` when available; if none are available, it skips privileged installs with a clear message.
- **Safety details:** asks before installs, makes no destructive changes, avoids clobbering existing user configs by default, and never restores private keys.

On unknown, immutable, minimal, or unusual distros, use **restore-only/manual mode**: the export’s `C_DRIVE`/`D_DRIVE` data is still there, and you can install apps/configs with your distro’s normal tools.

**Beginner-friendly starting points:** Linux Mint 22 (Cinnamon) or Ubuntu 24.04 LTS. Use dual-boot first and keep Windows for 1–2 weeks.

## Code quality & review

- Please open issues/PRs for bugs and improvements.
- This repo includes a `.coderabbit.yaml` config. To enable automated PR reviews, install the [CodeRabbit GitHub App](https://github.com/apps/coderabbitai) on your fork/repo (maintainers can enable it on the upstream repo).
- Local checks you can run (optional, if installed):
  - PowerShell: `Invoke-ScriptAnalyzer -Path .\scripts -Recurse`
  - Bash: `shellcheck .\scripts\Win2Lin.sh`

## License

MIT — see [LICENSE](./LICENSE).

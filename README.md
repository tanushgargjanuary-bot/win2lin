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

`scripts/Win2Lin.sh` is **distro-flexible** and best-effort. It detects common package managers and degrades gracefully:
- `apt` (Debian/Ubuntu/Mint/Pop!_OS)
- `dnf`/`yum` (Fedora/RHEL family)
- `pacman` (Arch/Manjaro/EndeavourOS)
- `zypper` (openSUSE)
- `apk` (Alpine)
- `xbps` (Void)

On unknown distros it skips package installs and still helps you locate/restore files from the export. Package names, NVIDIA drivers, and some apps are distro-specific — install those via your distro’s normal tools.

**Beginner-friendly starting points:** Linux Mint 22 (Cinnamon) or Ubuntu 24.04 LTS. Use dual-boot first and keep Windows for 1–2 weeks.

## Code quality & review

- Please open issues/PRs for bugs and improvements.
- This repo includes a `.coderabbit.yaml` config. To enable automated PR reviews, install the [CodeRabbit GitHub App](https://github.com/apps/coderabbitai) on your fork/repo (maintainers can enable it on the upstream repo).
- Local checks you can run (optional, if installed):
  - PowerShell: `Invoke-ScriptAnalyzer -Path .\scripts -Recurse`
  - Bash: `shellcheck .\scripts\Win2Lin.sh`

## License

MIT — see [LICENSE](./LICENSE).

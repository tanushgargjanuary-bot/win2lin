# Safe installation & usage (Win2Lin)

Win2Lin runs **locally** on your machines (Windows for export, Linux for restore). Install it in a way that lets you **verify what you run**.

## Before you run anything
- Prefer **tagged releases** or a **reviewed commit** over arbitrary branches/links.
- **Verify SHA-256 checksums** for downloaded archives (see [`../packaging/checksums.md`](../packaging/checksums.md)).
- **Review scripts** before execution, especially if you downloaded them. Win2Lin is open source—inspect `*.ps1`, `*.bat`, and `*.sh` for unexpected behavior.
- **Do not** pipe remote scripts directly into a shell/interpreter (avoid `iwr ... | iex`, `curl ... | bash`). Download, verify, review, then run.
- Use the **dry-run/preview** modes before real copy operations.

## Option 1 — Git clone (recommended for reviewability)
```bash
git clone https://github.com/<OWNER>/<REPO>.git Win2Lin
cd Win2Lin
# Optional: check out a specific release tag
# git checkout vX.Y.Z
```
On Windows, you can also use GitHub Desktop or download the source from a **tagged release** page (then verify checksums if using a ZIP).

## Option 2 — Release ZIP (verify + extract)
1. Download the release ZIP and its published SHA-256 checksum from the **official GitHub Releases** page.
2. Verify the checksum (PowerShell `Get-FileHash` / Linux `sha256sum -c` / macOS `shasum -a 256 -c`). See [`../packaging/checksums.md`](../packaging/checksums.md).
3. Extract to a local folder you control (e.g., `C:\Tools\Win2Lin` or `~/Win2Lin`). Avoid extracting into sensitive system directories.
4. Review the included scripts, then run them as documented below.

## Running on Windows (local scripts)
From the repository/extracted folder:

- **Wizard (most users):** double-click [`Win2Lin.bat`](../Win2Lin.bat). It locates and runs the PowerShell scripts with `-ExecutionPolicy Bypass -File` for the local script you chose to run.
  - Option `1` = Inventory (safe, copies nothing)
  - Option `2` = Copy with a dry-run preview first, then confirm for a real copy

- **Lite exporter (simpler, `robocopy`-based):** [`scripts/Win2Lin-lite.ps1`](../scripts/Win2Lin-lite.ps1)
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 -Mode Inventory
  powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 -Mode Copy -DryRun
  powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 -Mode Copy
  ```

- **Advanced exporter (richer inventory/manifest features):** [`scripts/Win2Lin.ps1`](../scripts/Win2Lin.ps1)
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin.ps1 -Mode Inventory
  powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin.ps1 -Mode Copy -DryRun
  powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin.ps1 -Mode Copy -Resume
  ```

Run from a **trusted local path**. If PowerShell blocks scripts by policy, prefer running a reviewed local file with `-ExecutionPolicy Bypass -File` (as above) rather than lowering system-wide policy permanently.

## Running on Linux (restore helper)
After copying the export folder to Linux:
```bash
bash /path/to/Win2Lin.sh ~/Win2Lin_export/<date>_<time>
```
Review [`scripts/Win2Lin.sh`](../scripts/Win2Lin.sh) first. The script is designed to be cautious (e.g., no automatic mutation on immutable/managed systems; no restore of private keys/password material).

## Windows package managers (future)
winget/Chocolatey/Scoop may be supported later. Until then, use **release ZIP + checksum verification** or a reviewed clone. See [`../packaging/README.md`](../packaging/README.md) and [`../packaging/winget/README.md`](../packaging/winget/README.md).

## More information
- Project overview and safety notes: [`../README.md`](../README.md)
- Release process (maintainers): [`../packaging/release-checklist.md`](../packaging/release-checklist.md)
- Checksums: [`../packaging/checksums.md`](../packaging/checksums.md)

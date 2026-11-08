# Packaging & distribution (Win2Lin)

This folder contains release and packaging scaffolding for **Win2Lin**. The goal is to make downloads easy to obtain **and** easy to verify.

## How to distribute

### Primary: GitHub Releases
- Publish **tagged releases** (e.g., `vX.Y.Z`) from a reviewed commit.
- Attach release assets as **ZIP archives** (source snapshot and/or a curated “scripts” bundle). Keep contents predictable (scripts, docs, license).
- Generate and publish **SHA-256 checksums** for every asset (see [`checksums.md`](./checksums.md)). Include checksums in the release notes and/or as a `SHA256SUMS.txt` asset.
- **Optional, later:** add cryptographic signatures (e.g., Sigstore/cosign, minisign, or Authenticode for Windows binaries if any are introduced). Signed artifacts improve trust, but checksums are the minimum baseline today.

### Windows package managers (future notes)
- **winget:** possible future path for a packaged installer/portable manifest. See [`winget/README.md`](./winget/README.md).
- **Chocolatey / Scoop:** possible future community or official packages. Treat these as downstream distributions—pin versions, verify upstream checksums, and document the publisher.
- Until official packages exist, prefer **GitHub Releases + checksum verification**.

### Direct script download safety
> **Security rule:** do not blindly run remote code (e.g., `iwr ... | iex`, `curl ... | bash`) without verification.

If you must download a script directly:
1. **Prefer a tagged release URL** over `main`/`HEAD`.
2. **Download the file** (do not pipe to a shell/interpreter).
3. **Verify the SHA-256 checksum** against the value published with the release (see [`checksums.md`](./checksums.md)).
4. **Review the script** (at minimum skim for unexpected network calls, credential access, or destructive operations).
5. **Run locally** with an explicit interpreter and constrained policy where appropriate (e.g., PowerShell `-ExecutionPolicy Bypass -File .\script.ps1` for a script you reviewed).

Avoid shortening links or unofficial mirrors for security-sensitive downloads.

## Related docs
- [`release-checklist.md`](./release-checklist.md) — maintainer release steps
- [`checksums.md`](./checksums.md) — generating/verifying SHA-256
- [`../docs/install.md`](../docs/install.md) — user-facing safe install paths
- [`winget/README.md`](./winget/README.md) — Windows package manager notes (future)

# Win2Lin — winget packaging (future)

This directory is a placeholder for **Windows Package Manager (winget)** distribution notes/manifests.

## Status
- **Not yet published** as an official winget package (as of this scaffolding). Users should install via **GitHub Releases with SHA-256 verification** or a reviewed local clone (see [`../../docs/install.md`](../../docs/install.md)).

## If/when winget support is added
- Publish manifests to the community repository following current [winget-pkgs](https://github.com/microsoft/winget-pkgs) contribution guidelines (or use a private source as appropriate).
- **Pin exact versions** and ensure the installer/archive URL and SHA-256 hash match the official GitHub Release asset.
- Prefer **signed** installers/artifacts when available; document signature verification.
- Keep package metadata (publisher, name, license, homepage) consistent with the repository.
- Add CI/release automation only after checksums and review gates are reliable.

## Other Windows managers (future)
- **Chocolatey / Scoop:** similar trust model—verify upstream checksums, avoid unofficial repackaging, and document the maintainer of the package.

## Security note
Package managers add convenience but also a supply-chain layer. Treat third-party manifests as separate artifacts: verify they point to official, checksummed releases.

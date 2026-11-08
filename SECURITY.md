# Security Policy

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Use GitHub's private vulnerability reporting for this repository if it is enabled: open the repository's **Security** tab and choose **Report a vulnerability**. If private reporting is not available, contact the maintainers through a private channel listed by the repository owner and include enough detail to reproduce the issue safely.

When reporting, please provide:

- A clear description of the issue and affected component (`Win2Lin.bat`, `scripts/Win2Lin-lite.ps1`, `scripts/Win2Lin.ps1`, `scripts/Win2Lin.sh`, templates/docs, etc.).
- Reproduction steps with sanitized paths and sample data (never real secrets or personal export contents).
- Impact assessment (data exposure, unintended deletion/overwrite, privilege escalation, path traversal, etc.).
- Any suggested mitigation.

We will review reports in good faith and coordinate a fix before public disclosure when practical.

## Security model and data handling

Win2Lin is designed to help migrate **user files and safe configuration** from Windows to Linux. It is **not** a credential migration tool.

### Never copied/exported/restored

Win2Lin must **never** copy, export, or restore:

- Browser passwords, cookies, session data, or credential stores (including `Login Data`, `Cookies`, `Web Data`, and other DPAPI/credential-locked browser material).
- Windows DPAPI secrets or other OS-protected secret material.
- Private keys, tokens, or secrets (including SSH private keys and similar sensitive credentials).

Use browser sync, password managers, and app-specific sign-in flows after migration.

### Export bundles may contain personal files

Export bundles (for example, `C:\Win2Lin_export\<date>_<time>`) can contain **personal documents, photos, configuration files, manifests, and inventory data**. Treat export folders as sensitive:

- Store them on trusted local or encrypted removable media.
- Avoid uploading export bundles to cloud services unless you intentionally reviewed the contents and accept the risk.
- Do not share manifests, logs, or screenshots that reveal personal paths or file names.
- Delete old export bundles securely when they are no longer needed.

## Safe usage expectations

- Review scripts before running, especially if using custom copy roots or modified versions.
- Use **Inventory** and **Dry Run/preview** modes before real copies.
- Keep the original Windows system available until you verify the Linux migration.
- Test changes in non-production environments when contributing code that affects copy/restore behavior.

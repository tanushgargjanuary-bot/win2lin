# Contributing to Win2Lin

Thanks for helping improve Win2Lin. This project handles real user migrations, so changes should prioritize **data safety, privacy, portability, and clear behavior**.

## Before you start

- Read [README.md](./README.md) for user-facing behavior and supported workflows.
- Read [SECURITY.md](./SECURITY.md). Never add code, tests, fixtures, docs, or screenshots that include browser passwords/cookies, DPAPI secrets, private keys, tokens, or personal export contents.
- For bugs/features, check existing issues first. For security issues, follow the private reporting process in `SECURITY.md`.

## Development setup

Win2Lin is primarily script-based (PowerShell + Bash + a small batch launcher). A typical local setup is:

1. Clone the repository.
2. Make changes in a branch/fork.
3. Run local checks available on your platform.
4. Test the affected flow with safe sample data and **Inventory/Dry Run** before any real copy.

### Useful local checks (optional, if installed)

PowerShell:

```powershell
Invoke-ScriptAnalyzer -Path .\scripts -Recurse
```

Bash:

```bash
shellcheck ./scripts/Win2Lin.sh
```

Basic PowerShell parse check (built into PowerShell):

```powershell
Get-ChildItem .\scripts -Filter *.ps1 | ForEach-Object {
  $tokens = $null; $errors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
  if ($errors) { $errors | ForEach-Object { throw $_.Message } }
}
```

## Style and safety guidelines

### General

- Prefer **safe defaults**: preview/dry-run behavior, no destructive operations without explicit confirmation, and no silent data loss.
- Keep changes **practical and portable**. Avoid cleverness that makes migration behavior harder to audit.
- Use clear messages for users, especially when skipping installs/restores for safety.
- Quote paths carefully (spaces and special characters are common in Windows profiles).

### PowerShell (`scripts/*.ps1`, `Win2Lin.bat` interactions)

- Preserve compatibility expectations where practical (Windows PowerShell 5.1 and PowerShell 7+ when feasible).
- Handle OneDrive/profile path edge cases carefully.
- Avoid self-copy/path traversal issues when selecting export roots and copy sources.
- Never collect or copy browser credential/DPAPI secret material.

### Bash (`scripts/Win2Lin.sh`)

- Keep scripts portable across common Linux environments where reasonable; degrade gracefully when tools are missing.
- Never auto-mutate immutable/atomic/transactional/declarative/managed systems (e.g., rpm-ostree layering, automatic transactional-update installs, NixOS/Guix system reconfiguration, abroot/managed mutations).
- Do not restore private keys/tokens/secrets. Only restore safe files intentionally selected by the script.
- Ask before privileged/package-install actions on mutable systems.

## Adding distro mappings or detection behavior

When improving Linux distro handling in `scripts/Win2Lin.sh`:

1. Prefer detection based on `/etc/os-release` fields (`ID`, `ID_LIKE`, `VARIANT_ID`, `PRETTY_NAME`) plus clear command/presence hints when needed.
2. Classify the system honestly:
   - **install**: mutable system where best-effort package installs can be offered after confirmation.
   - **limited**: partial/uncertain environment; provide cautious guidance.
   - **restore-only**: immutable/managed/declarative/unknown-sensitive cases where system mutation must not be automated.
3. Keep core restore portable and non-destructive.
4. Add or update user-facing guidance with manual alternatives (Flatpak, distrobox/toolbox, Homebrew, native package manager commands as appropriate).
5. Test on the target distro if possible and include a Distro Test Report issue/PR notes with sanitized `/etc/os-release` details.

## Adding modules or script capabilities

If you add new export/restore capabilities:

- Define scope clearly: what is copied/restored, what is skipped, and why.
- Add explicit denylist behavior for secrets/sensitive material.
- Preserve dry-run/inventory support where relevant.
- Update docs (`README.md` and/or `tests/README.md`) when user-visible behavior changes.
- Consider manifest/reporting impact so users can audit what happened.

## Testing expectations

There is no heavy test harness yet; contributions should still be verified:

- Run lint/syntax checks relevant to your changes (ShellCheck, PSScriptAnalyzer, PowerShell parser).
- For Windows script changes: test at least Inventory and Dry Run paths with safe sample directories.
- For Linux script changes: test on real or VM/container distros when possible; report mode detection, restore behavior, and guidance.
- For denylist/safety changes: use synthetic fixtures only (no real secrets) and verify secrets are never exported/restored.
- For docs/templates/workflow changes: ensure YAML/Markdown renders cleanly and instructions remain accurate.

## Pull requests

- Keep PRs focused and reviewable.
- Explain the user impact and safety impact.
- Use the PR template checklist.
- Include sanitized logs/output and distro/environment details when relevant.

## Code review / CodeRabbit

This repository includes [`.coderabbit.yaml`](./.coderabbit.yaml). Automated PR reviews require the [CodeRabbit GitHub App](https://github.com/apps/coderabbitai) to be installed on the repository/fork. Maintainers can enable it on the upstream repo.

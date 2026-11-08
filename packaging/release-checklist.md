# Release checklist (Win2Lin)

Use this checklist for each tagged release. Do not skip verification steps.

## 1. Prepare
- [ ] **Version bump:** update any version strings/metadata used by the project (if applicable). Keep version consistent across docs and release tag.
- [ ] **Changelog:** add/update release notes (what changed, migration notes, known issues, security-relevant changes).
- [ ] **Review scope:** confirm only intended files are included; remove accidental secrets, personal paths, or debug artifacts.

## 2. Quality gates
- [ ] **Tests:** run the project’s test suite (see `tests/` and CI configuration) and fix failures.
- [ ] **Lint/static analysis (if installed/configured):**
  - PowerShell: `Invoke-ScriptAnalyzer -Path .\scripts -Recurse`
  - Bash: `shellcheck .\scripts\Win2Lin.sh`
- [ ] **Manual dry-run smoke tests (Windows):**
  - `Win2Lin.bat` → Inventory (safe) completes without errors.
  - Lite: `powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 -Mode Inventory`
  - Lite/Advanced copy **dry-run/preview** paths behave as documented (no unexpected writes).
- [ ] **Docs sanity:** verify [`docs/install.md`](../docs/install.md) matches actual script paths (`Win2Lin.bat`, `scripts/Win2Lin-lite.ps1`, `scripts/Win2Lin.ps1`, `scripts/Win2Lin.sh`).

## 3. Build release assets
- [ ] **Create ZIPs** from a clean checkout (or CI artifact) with stable naming, e.g. `Win2Lin-vX.Y.Z.zip`.
- [ ] **Exclude** unnecessary files if producing a slim bundle (e.g., `.git/`, local exports). Document what’s inside.
- [ ] **Record the commit SHA** used for the release.

## 4. Checksums & integrity
- [ ] **Generate SHA-256 checksums** for every asset (see [`checksums.md`](./checksums.md)).
- [ ] **Verify checksums** locally after upload (download + re-hash) to catch corruption.
- [ ] **Publish checksums** as `SHA256SUMS.txt` (or equivalent) and include them in release notes.
- [ ] **Optional (future):** sign assets/manifests; publish verification instructions.

## 5. Tag & publish
- [ ] **Tag** the release commit: `git tag -a vX.Y.Z -m "Release vX.Y.Z"` (or your convention) and push tags.
- [ ] **Create GitHub Release** for the tag; attach ZIPs and checksum file(s).
- [ ] **Mark pre-release** if not production-ready.

## 6. Announce & follow-up
- [ ] **Announcement:** share release notes (repo README, discussions, or chosen channel) with a clear “verify checksums before running” reminder.
- [ ] **Monitor:** watch for issue reports; be ready to yank/retract guidance if a critical problem is found.
- [ ] **Post-release:** open/track follow-up tasks (winget/Chocolatey/Scoop manifests, signing) if planned.

## Safety reminders
- Never advise users to run downloaded scripts without checksum verification and review.
- Keep export/inventory behavior transparent; releases must not introduce silent data exfiltration.

# UI next (evaluation — CLI first, GUI later)

**Status:** decision draft for v1+  
**Goal:** Win2Lin stays simple and auditable. GUI/TUI is optional and must wrap the same bundle/report/checksum core — never fork migration logic.

## v1 (now): CLI-only, double-click friendly
- `Win2Lin.bat` wizard + `scripts/*.ps1` + `scripts/Win2Lin.sh`.
- Strengths: inspectable, local-first, works with built-in Windows tools (`robocopy` via Lite), easy CodeRabbit/CI review.
- Keep as the **supported path** for v1.

## v2 candidates (evaluate, don't rush)
| Option | Pros | Cons / risks |
|---|---|---|
| **Rust TUI (ratatui)** | Fast, single binary feel, keyboard-first, cross-platform | New maintenance surface (build/sign/AV), must reuse bundle contracts |
| **Tauri (Rust + web UI)** | Modern GUI, Rust core possible | WebView deps, larger bundle, security review |
| **Electron** | Mature ecosystem | Heavy footprint, supply-chain surface |
| **PowerShell TUI (e.g., Positional/PSReadLine)** | No new language, simple | Limited cross-platform, polish ceiling |

## Decision criteria
Ship a GUI/TUI only when:
1. Bundle/manifest/report/checksum contracts are frozen + tested (done in v1 foundations).
2. A narrow Rust core (verify/hash) proves build/distribution/signing/CI cost is acceptable.
3. The UI calls the **same** core (no duplicated safety logic) and passes the Pester + cargo tests.

## Non-goals for UI
- No silent cloud upload, no telemetry by default.
- No secret import/export UI. Re-auth remains provider-native.
- No auto-mutation of immutable/atomic/transactional/declarative/managed Linux.

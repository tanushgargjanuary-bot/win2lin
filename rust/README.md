# Rust (optional, incremental)

Rust is **not** a full rewrite. It exists for small, well-scoped accelerators that share the exact same Win2Lin bundle/checksum format as the PowerShell scripts.

- `win2lin-verify` — cross-platform SHA-256 bundle verifier/writer (`write`/`verify`, exit 0/2/1).
- Primary path remains `scripts/*.ps1` + `scripts/Win2Lin.sh`.
- The Rust helper must pass `cargo test` in CI and produce identical `checksums.sha256` files.

See `win2lin-verify/README.md` for build/use.

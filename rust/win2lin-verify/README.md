# win2lin-verify (optional Rust accelerator)

Cross-platform SHA-256 verify/write for Win2Lin export bundles.
Same file format as `scripts/Verify-Win2LinBundle.ps1` (`checksums.sha256`).

PowerShell scripts remain the **primary** path. This crate is optional,
enabled where a fast portable verifier is useful (CI, Linux, bulk bundles).

## Build
```bash
cargo build --release
```

## Use
```bash
# verify what powershell wrote
./target/release/win2lin-verify verify --bundle C:\Win2Lin_export\20261107_143022

# write metadata checksums (fast, same defaults as PS)
./target/release/win2lin-verify write --bundle .\bundle

# include payload C_DRIVE/D_DRIVE (slow, thorough)
./target/release/win2lin-verify write --bundle .\bundle --include-payload
```

Exit: `0`=OK, `2`=BAD/MISSING, `1`=usage/error. Never modifies payload.

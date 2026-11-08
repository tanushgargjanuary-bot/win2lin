# Checksums (SHA-256)

Win2Lin releases should publish **SHA-256** checksums for every downloadable asset. Verify checksums **before** extracting or running anything.

## Why
- Detects corrupted or incomplete downloads.
- Helps detect tampering when you compare against the checksum published by the official release.

Checksums do **not** replace code review or signatures; use them as a baseline integrity check.

## Generate checksums

### Windows (PowerShell)
For a single file:
```powershell
Get-FileHash -Algorithm SHA256 .\Win2Lin-vX.Y.Z.zip | Format-List
```

For all ZIPs in the current folder and write a `SHA256SUMS.txt`-style file:
```powershell
Get-ChildItem -File *.zip | Get-FileHash -Algorithm SHA256 |
  ForEach-Object { "$($_.Hash.ToLower())  $($_.Path | Split-Path -Leaf)" } |
  Set-Content -Encoding ascii .\SHA256SUMS.txt
```

### Linux (sha256sum)
Single file:
```bash
sha256sum Win2Lin-vX.Y.Z.zip
```

All ZIPs in the current directory:
```bash
sha256sum *.zip > SHA256SUMS.txt
```

### macOS (shasum)
```bash
shasum -a 256 Win2Lin-vX.Y.Z.zip
shasum -a 256 *.zip > SHA256SUMS.txt
```

## Verify checksums

### Windows (PowerShell)
Compare the computed hash to the published value:
```powershell
$expected = 'PASTE_PUBLISHED_SHA256_HERE'.ToLower()
$actual = (Get-FileHash -Algorithm SHA256 .\Win2Lin-vX.Y.Z.zip).Hash.ToLower()
if ($actual -eq $expected) { 'OK: checksum matches' } else { 'MISMATCH: do not use this file' }
```

### Linux
If you have a `SHA256SUMS.txt` file alongside the assets:
```bash
sha256sum -c SHA256SUMS.txt
```
Only lines matching files present will be checked; ensure the filename and hash correspond to the asset you downloaded.

### macOS
```bash
shasum -a 256 -c SHA256SUMS.txt
```

## Safe workflow
1. Download the release asset **and** the published checksum file/values from the same official release page.
2. Verify the checksum.
3. Extract to a known location (not a sensitive system directory).
4. Review scripts before running (especially PowerShell/Bash entry points).
5. Run locally (e.g., `Win2Lin.bat` or `powershell -ExecutionPolicy Bypass -File .\scripts\Win2Lin-lite.ps1 ...`) rather than executing remote content.

If verification fails, **delete the file** and re-download from the official source. Do not proceed.

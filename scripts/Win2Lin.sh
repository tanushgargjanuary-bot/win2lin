#!/usr/bin/env bash
# Win2Lin_script.sh - Forgiving Linux restore (hardened)
# Usage: bash Win2Lin_script.sh [path-to-export-folder]
# If no arg, auto-finds the dated folder under ~/Win2Lin_export or ~/Desktop/Win2Lin_export
set -uo pipefail
EXPORT_DIR="${1:-}"

# auto-find inventory.json if no folder given
if [ -z "$EXPORT_DIR" ]; then
  for base in "$HOME/Win2Lin_export" "$HOME/Desktop/Win2Lin_export"; do
    if [ -f "$base/inventory.json" ]; then EXPORT_DIR="$base"; break; fi
    if [ -d "$base" ]; then
      found=$(find "$base" -maxdepth 2 -name inventory.json 2>/dev/null | head -1 || true)
      if [ -n "$found" ]; then EXPORT_DIR="$(dirname "$found")"; break; fi
    fi
  done
fi

# if provided folder contains dated subfolders, find it
if [ -n "$EXPORT_DIR" ] && [ ! -f "$EXPORT_DIR/inventory.json" ] && [ -d "$EXPORT_DIR" ]; then
  found=$(find "$EXPORT_DIR" -maxdepth 2 -name inventory.json 2>/dev/null | head -1 || true)
  if [ -n "$found" ]; then EXPORT_DIR="$(dirname "$found")"; fi
fi

echo "Export folder: ${EXPORT_DIR:-<none>}"
if [ -z "$EXPORT_DIR" ] || [ ! -f "$EXPORT_DIR/inventory.json" ]; then
  echo "ERROR: inventory.json not found. Copy the WHOLE dated folder (e.g. 20261107_143022), not files inside it."
  echo "Expected: ~/Win2Lin_export/<date>_<time>/inventory.json"
  ls -R "$HOME/Win2Lin_export" 2>/dev/null | head -30 || true
  exit 1
fi

echo ""
echo "I found your backup in: $EXPORT_DIR"
echo ""
echo "I will install (approx 800 MB-1.2 GB):"
echo "  git curl wget python3 pipx nodejs npm flatpak fonts-firacode zstd unzip jq rsync rclone"
echo "  Brave Browser + VS Code via Flatpak"
echo "  Bun (dev runtime for OpenCode)"
echo ""
echo "I will restore: .gitconfig, .config, .opencode, fonts (from exported folders if present)"
echo "I will NOT touch password files. You must re-login in Brave/Edge."
echo "One failure will NOT kill the script - it will continue and report errors."
echo ""
read -r -p "Continue? Type Y to continue, N to see the plan only: " c
if [ "$c" != "Y" ]; then
  echo "Plan shown. Re-run and type Y when ready."
  exit 0
fi

# Detect distro
if command -v apt >/dev/null 2>&1; then
  PKG=apt
elif command -v dnf >/dev/null 2>&1; then
  PKG=dnf
else
  PKG=""
fi
echo "Package manager: $PKG"
echo ""

# 1) Base tools - forgiving: continue on error
if [ "$PKG" = "apt" ]; then
  echo "[apt] updating..."
  sudo apt update || true
  echo "[apt] installing base tools (some may fail, continuing)..."
  sudo apt install -y git curl wget python3 pipx nodejs npm flatpak fonts-firacode zstd unzip jq rsync rclone || true
elif [ "$PKG" = "dnf" ]; then
  echo "[dnf] installing base tools..."
  sudo dnf install -y git curl wget python3 nodejs npm flatpak unzip jq rsync zstd || true
else
  echo "Unknown package manager, skipping install. Install: git curl python3 nodejs flatpak jq rsync rclone"
fi

# 2) Flatpak + Brave/VS Code (prompted, forgiving)
run_flatpak() {
  echo "[flatpak] $1"
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
  flatpak install -y flathub com.brave.Browser || echo "Brave Flatpak failed (install manually via Mint Software Manager)"
  flatpak install -y flathub com.visualstudio.code || echo "VS Code Flatpak failed (you can install from Microsoft site)"
}
read -r -p "Install Brave + VS Code via Flatpak? Type Y/N: " f
if [ "$f" = "Y" ]; then run_flatpak; else echo "Skipped Flatpak apps (install manually later)"; fi

# 3) Bun
run_bun() {
  echo "[bun] installing..."
  curl -fsSL https://bun.sh/install | bash || echo "Bun install failed - check network, or install manually from bun.sh"
}
read -r -p "Install Bun? Type Y/N: " b
if [ "$b" = "Y" ]; then run_bun; else echo "Skipped Bun"; fi

# 4) Restore configs (safe files only)
echo ""
echo "Restoring configs (safe files only)..."
# Find the actual Windows user folder (Linux $USER may differ from Windows username)
WIN_USER_DIR=""
for candidate in "$EXPORT_DIR/C_DRIVE/Users/$USER" "$EXPORT_DIR/C_DRIVE/Users/"*; do
  if [ -d "$candidate" ] && [ "$(basename "$candidate")" != "Public" ] && [ "$(basename "$candidate")" != "Default" ]; then
    WIN_USER_DIR="$candidate"; break
  fi
done
[ -n "$WIN_USER_DIR" ] && echo "Windows user folder: $WIN_USER_DIR" || echo "Windows user folder not auto-detected (configs may need manual restore)"

# .gitconfig
for src in "$WIN_USER_DIR/.gitconfig" "$EXPORT_DIR/C_DRIVE/Users/$USER/.gitconfig" "$EXPORT_DIR/C_DRIVE/home/$USER/.gitconfig"; do
  [ -f "$src" ] && [ ! -f "$HOME/.gitconfig" ] && cp "$src" "$HOME/.gitconfig" 2>/dev/null && echo "Restored .gitconfig" && break
done

for d in .config .opencode .antigravity; do
  for src in "$WIN_USER_DIR/$d" "$EXPORT_DIR/C_DRIVE/Users/$USER/$d" "$EXPORT_DIR/C_DRIVE/home/$USER/$d"; do
    if [ -d "$src" ]; then echo "Found $d at $src - copying to ~/$d"; cp -rn "$src" "$HOME/" 2>/dev/null || true; break; fi
  done
done

# AppData roaming configs (useful hints)
for app in Antigravity opencode Code; do
  for src in "$WIN_USER_DIR/AppData/Roaming/$app" "$EXPORT_DIR/C_DRIVE/Users/$USER/AppData/Roaming/$app"; do
    [ -d "$src" ] && echo "Found $app config at $src (copy manually to ~/.config if needed on Linux)" && break
  done
done

# .ssh: copy only safe public files, never private keys
for sshdir in "$WIN_USER_DIR/.ssh" "$EXPORT_DIR/C_DRIVE/Users/$USER/.ssh"; do
  if [ -d "$sshdir" ]; then
    mkdir -p "$HOME/.ssh"
    cp "$sshdir/config" "$HOME/.ssh/" 2>/dev/null || true
    cp "$sshdir/known_hosts" "$HOME/.ssh/" 2>/dev/null || true
    cp "$sshdir"/*.pub "$HOME/.ssh/" 2>/dev/null || true
    cp "$sshdir/authorized_keys" "$HOME/.ssh/" 2>/dev/null || true
    chmod 700 "$HOME/.ssh" 2>/dev/null || true
    chmod 600 "$HOME/.ssh/config" "$HOME/.ssh/known_hosts" 2>/dev/null || true
    echo "Restored .ssh safe files only (private keys NOT copied - regenerate on Linux)."
    break
  fi
done

# 5) Fonts
for fdir in "$EXPORT_DIR/C_DRIVE/Windows/Fonts" "$EXPORT_DIR/C_DRIVE/Users/$USER/Fonts"; do
  if [ -d "$fdir" ]; then
    mkdir -p "$HOME/.local/share/fonts/win2lin"
    cp "$fdir"/* "$HOME/.local/share/fonts/win2lin/" 2>/dev/null || true
    fc-cache -f >/dev/null 2>&1 || true
    echo "Installed fonts from $fdir"
  fi
done

# 6) Stats (UTF-8 no BOM safe, quoted)
python3 - <<PY || true
import json, os, glob
inv_path = os.path.join("$EXPORT_DIR", "inventory.json")
# glob fallback if env var didn't interpolate (spaces)
import pathlib
if not os.path.exists(inv_path):
    cands = glob.glob(os.path.expanduser("~/Win2Lin_export/*/inventory.json"))
    if cands: inv_path = cands[0]
print("Inventory:", inv_path)
try:
    d = json.load(open(inv_path, encoding='utf-8-sig'))
except Exception as e:
    print("Could not read inventory.json:", e)
    raise SystemExit(0)
print("Drives:", d.get("drives"))
print("Dev tools found:", [t["Tool"] for t in d.get("dev_tools",[]) if t.get("Found")])
print("Browser profiles:", [(b["Browser"], b["ProfileCount"]) for b in d.get("browsers_profile_metadata_only",[])])
print("Apps (count):", len(d.get("installed_apps",[])))
print("Next: re-login in order:")
print("  1. Brave Sync")
print("  2. Edge Sync")
print("  3. Google Password Manager")
print("  4. Antigravity")
print("  5. OpenCode")
print("If sync failed: export Bookmarks HTML in Windows, import in Linux.")
PY

echo ""
echo "Done. C_DRIVE = your old C: (under $EXPORT_DIR/C_DRIVE), D_DRIVE = old D:."
echo "Dual-boot note: keep Windows NTFS mounted read-only if needed, do not delete yet."
echo "NVIDIA on Mint: Settings > Driver Manager > select NVIDIA driver > Apply."

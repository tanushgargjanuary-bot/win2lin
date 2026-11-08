#!/usr/bin/env bash
# Win2Lin.sh - Forgiving Linux restore helper (distro-flexible)
# Usage: bash Win2Lin.sh [path-to-export-folder]
# Tries to work on most Linux distros (apt, dnf, pacman, zypper, apk, xbps). Installs are best-effort and optional.
set -uo pipefail

EXPORT_DIR="${1:-}"
PYTHON_BIN=""

# --- helpers ---
have() { command -v "$1" >/dev/null 2>&1; }
ask_yn() {
  local prompt="${1:-Continue?}" ans
  read -r -p "$prompt [y/N]: " ans || true
  [[ "$ans" == "Y" || "$ans" == "y" ]]
}
run_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; return $?; fi
  if have sudo; then sudo "$@"; return $?; fi
  if have doas; then doas "$@"; return $?; fi
  echo "No sudo/doas/root. Run as root or install manually: $*"
  return 1
}

# --- find export folder ---
if [ -z "$EXPORT_DIR" ]; then
  for base in "$HOME/Win2Lin_export" "$HOME/Desktop/Win2Lin_export" "$PWD/Win2Lin_export" "$PWD"; do
    [ -f "$base/inventory.json" ] && { EXPORT_DIR="$base"; break; }
    if [ -d "$base" ]; then
      found=$(find "$base" -maxdepth 3 -name inventory.json 2>/dev/null | head -1 || true)
      [ -n "$found" ] && { EXPORT_DIR="$(dirname "$found")"; break; }
    fi
  done
fi
if [ -n "$EXPORT_DIR" ] && [ ! -f "$EXPORT_DIR/inventory.json" ] && [ -d "$EXPORT_DIR" ]; then
  found=$(find "$EXPORT_DIR" -maxdepth 3 -name inventory.json 2>/dev/null | head -1 || true)
  [ -n "$found" ] && EXPORT_DIR="$(dirname "$found")"
fi

echo "Export folder: ${EXPORT_DIR:-<none>}"
if [ -z "$EXPORT_DIR" ] || [ ! -f "$EXPORT_DIR/inventory.json" ]; then
  echo "ERROR: inventory.json not found."
  echo "Copy the WHOLE dated folder (e.g. 20261107_143022), not files inside it."
  echo "Try: bash Win2Lin.sh ~/Win2Lin_export/20261107_143022"
  exit 1
fi

# --- detect package manager ---
PKG=""; PKG_NAME=""
if have apt-get; then PKG=apt; PKG_NAME="apt (Debian/Ubuntu/Mint)";
elif have dnf; then PKG=dnf; PKG_NAME="dnf (Fedora/RHEL)";
elif have pacman; then PKG=pacman; PKG_NAME="pacman (Arch/Manjaro)";
elif have zypper; then PKG=zypper; PKG_NAME="zypper (openSUSE)";
elif have apk; then PKG=apk; PKG_NAME="apk (Alpine)";
elif have xbps-install; then PKG=xbps; PKG_NAME="xbps (Void)";
elif have yum; then PKG=yum; PKG_NAME="yum (older RHEL/CentOS)";
fi

echo ""
echo "Found backup: $EXPORT_DIR"
echo "Detected package manager: ${PKG_NAME:-unknown (manual install mode)}"
echo ""
echo "This script can (all optional):"
echo "  - Install common tools (git, curl, python, node, rsync, jq, etc.) if supported"
echo "  - Install Brave/VS Code via Flatpak (if you choose)"
echo "  - Install Bun (if you choose)"
echo "  - Restore safe configs (.gitconfig, .config, .opencode, fonts, public SSH files)"
echo ""
echo "It will NOT copy browser passwords or private keys. Re-login on Linux."
echo "Failures are non-fatal; the script continues."
echo ""
ask_yn "Continue?" || { echo "Stopped. No changes made."; exit 0; }

# --- install base tools (best-effort, distro-flexible) ---
install_base() {
  echo ""
  echo "[tools] Best-effort install via ${PKG_NAME:-manual}..."
  case "$PKG" in
    apt)
      run_root apt-get update || true
      run_root apt-get install -y git curl wget python3 python3-pip nodejs npm flatpak unzip jq rsync rclone zstd || \
      run_root apt-get install -y git curl wget python3 nodejs flatpak unzip jq rsync || true
      ;;
    dnf)
      run_root dnf install -y git curl wget python3 python3-pip nodejs npm flatpak unzip jq rsync rclone zstd || \
      run_root dnf install -y git curl wget python3 nodejs flatpak unzip jq rsync || true
      ;;
    pacman)
      run_root pacman -Sy --noconfirm git curl wget python python-pip nodejs npm flatpak unzip jq rsync rclone zstd || \
      run_root pacman -Sy --noconfirm git curl wget python nodejs npm flatpak unzip jq rsync || true
      ;;
    zypper)
      run_root zypper --non-interactive refresh || true
      run_root zypper --non-interactive install git curl wget python3 python3-pip nodejs npm flatpak unzip jq rsync rclone zstd || \
      run_root zypper --non-interactive install git curl wget python3 nodejs flatpak unzip jq rsync || true
      ;;
    apk)
      run_root apk update || true
      run_root apk add git curl wget python3 py3-pip nodejs npm flatpak unzip jq rsync rclone zstd bash || \
      run_root apk add git curl wget python3 nodejs flatpak unzip jq rsync bash || true
      ;;
    xbps)
      run_root xbps-install -Sy || true
      run_root xbps-install -y git curl wget python3 python3-pip nodejs flatpak unzip jq rsync rclone zstd || \
      run_root xbps-install -y git curl wget python3 nodejs flatpak unzip jq rsync || true
      ;;
    yum)
      run_root yum install -y git curl wget python3 nodejs flatpak unzip jq rsync || true
      ;;
    *)
      echo "Unknown package manager. Install manually (names vary by distro):"
      echo "  git curl wget python3 nodejs npm flatpak unzip jq rsync rclone zstd"
      ;;
  esac
}
if ask_yn "Install common base tools now?"; then install_base; else echo "Skipped base tool install."; fi

# --- Flatpak apps (optional) ---
if have flatpak; then
  if ask_yn "Install Brave + VS Code via Flatpak (Flathub)?"; then
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    flatpak install -y flathub com.brave.Browser || echo "Brave Flatpak failed (install manually for your distro)."
    flatpak install -y flathub com.visualstudio.code || echo "VS Code Flatpak failed (install manually)."
  else
    echo "Skipped Flatpak apps."
  fi
else
  echo "Flatpak not found; skipping Brave/VS Code Flatpak install (install flatpak or use your distro's packages)."
fi

# --- Bun (optional) ---
if ask_yn "Install Bun (dev runtime) from bun.sh?"; then
  if have curl; then
    curl -fsSL https://bun.sh/install | bash || echo "Bun install failed (network or unsupported platform)."
  else
    echo "curl not found; cannot install Bun automatically."
  fi
else
  echo "Skipped Bun."
fi

# --- Restore safe configs ---
echo ""
echo "[restore] Restoring safe configs..."

# Find actual Windows user folder (Linux $USER may differ)
WIN_USER_DIR=""
if [ -d "$EXPORT_DIR/C_DRIVE/Users" ]; then
  for candidate in "$EXPORT_DIR/C_DRIVE/Users/$USER" "$EXPORT_DIR/C_DRIVE/Users"/*; do
    [ -d "$candidate" ] || continue
    base="$(basename "$candidate")"
    [ "$base" = "Public" ] || [ "$base" = "Default" ] || [ "$base" = "All Users" ] && continue
    WIN_USER_DIR="$candidate"; break
  done
fi
[ -n "$WIN_USER_DIR" ] && echo "Windows user folder: $WIN_USER_DIR" || echo "Windows user folder not auto-detected (you can copy configs manually from C_DRIVE/Users/<name>/)."

# .gitconfig
for src in "$WIN_USER_DIR/.gitconfig" "$EXPORT_DIR/C_DRIVE/Users/$USER/.gitconfig"; do
  if [ -f "$src" ] && [ ! -f "$HOME/.gitconfig" ]; then
    cp "$src" "$HOME/.gitconfig" 2>/dev/null && echo "Restored .gitconfig" && break
  fi
done

# dot-config dirs
for d in .config .opencode .antigravity; do
  for src in "$WIN_USER_DIR/$d" "$EXPORT_DIR/C_DRIVE/$d"; do
    if [ -d "$src" ] && [ ! -e "$HOME/$d" ]; then
      cp -rn "$src" "$HOME/" 2>/dev/null && echo "Restored ~/$d (no-clobber)" && break
    elif [ -d "$src" ]; then
      echo "Found $d in export but ~/$d already exists (skipped to avoid overwrite)"
      break
    fi
  done
done

# AppData hints (Windows app configs may need manual adaptation on Linux)
for app in Antigravity opencode Code; do
  src="$WIN_USER_DIR/AppData/Roaming/$app"
  [ -d "$src" ] && echo "Found Windows config: $src (Linux location may differ; copy/adapt manually if needed)"
done

# .ssh: public/safe files only, never private keys
for sshdir in "$WIN_USER_DIR/.ssh" "$EXPORT_DIR/C_DRIVE/Users/$USER/.ssh"; do
  if [ -d "$sshdir" ]; then
    mkdir -p "$HOME/.ssh"
    cp "$sshdir/config" "$HOME/.ssh/" 2>/dev/null || true
    cp "$sshdir/known_hosts" "$HOME/.ssh/" 2>/dev/null || true
    cp "$sshdir"/authorized_keys "$HOME/.ssh/" 2>/dev/null || true
    find "$sshdir" -maxdepth 1 -name "*.pub" -exec cp {} "$HOME/.ssh/" \; 2>/dev/null || true
    chmod 700 "$HOME/.ssh" 2>/dev/null || true
    [ -f "$HOME/.ssh/config" ] && chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
    [ -f "$HOME/.ssh/known_hosts" ] && chmod 600 "$HOME/.ssh/known_hosts" 2>/dev/null || true
    echo "Restored safe .ssh files only (public keys/config/known_hosts). Private keys NOT copied."
    break
  fi
done

# Fonts
for fdir in "$EXPORT_DIR/C_DRIVE/Windows/Fonts" "$WIN_USER_DIR/Fonts"; do
  if [ -d "$fdir" ]; then
    mkdir -p "$HOME/.local/share/fonts/win2lin" 2>/dev/null || true
    cp "$fdir"/* "$HOME/.local/share/fonts/win2lin/" 2>/dev/null || true
    have fc-cache && fc-cache -f >/dev/null 2>&1 || true
    echo "Copied fonts from $fdir"
  fi
done

# --- Summary (python3 or python) ---
if have python3; then PYTHON_BIN=python3; elif have python; then PYTHON_BIN=python; fi
if [ -n "$PYTHON_BIN" ]; then
  "$PYTHON_BIN" - "$EXPORT_DIR" <<'PY' || true
import json, os, sys
export_dir = sys.argv[1]
inv_path = os.path.join(export_dir, "inventory.json")
try:
    d = json.load(open(inv_path, encoding="utf-8-sig"))
except Exception as e:
    print("Could not read inventory.json:", e)
    raise SystemExit(0)
print("Dev tools found (Windows):", [t.get("Tool") for t in d.get("dev_tools",[]) if t.get("Found")])
print("Browser profiles:", [(b.get("Browser"), b.get("ProfileCount")) for b in d.get("browsers_profile_metadata_only",[])])
print("Apps (count):", len(d.get("installed_apps",[])))
print("Next: re-login on Linux (browser sync, password manager, Antigravity/OpenCode).")
print("If sync failed: import Bookmarks HTML backup.")
PY
else
  echo "python not found; skipping inventory summary (inventory.json is still in the export folder)."
fi

echo ""
echo "Done (best-effort)."
echo "C_DRIVE = your old C: at: $EXPORT_DIR/C_DRIVE"
echo "D_DRIVE = your old D: at: $EXPORT_DIR/D_DRIVE"
echo "NVIDIA drivers, gaming launchers, and some apps are distro-specific - install via your distro's tools."
echo "Keep Windows for 1-2 weeks while testing Linux."

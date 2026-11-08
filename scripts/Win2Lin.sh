#!/usr/bin/env bash
# Win2Lin.sh - Forgiving Linux restore helper (portable across most Linux environments)
# Usage: bash Win2Lin.sh [path-to-export-folder]
#
# Portability goal (honest):
# - CORE restore (locate export, restore safe files/configs/fonts/public SSH) should work on
#   almost any Linux with bash + basic coreutils (and degrades if tools like find/cp are missing).
# - Package/app installs are BEST-EFFORT and OPTIONAL. "All distros" is not literally possible to
#   automate safely; immutable/declarative distros get restore-only/manual guidance by default.
#
# Safety: no destructive operations, no clobber by default, NEVER copies private keys/passwords/tokens.
set -uo pipefail

EXPORT_DIR="${1:-}"
PYTHON_BIN=""
DISTRO_ID=""
DISTRO_ID_LIKE=""
DISTRO_PRETTY="unknown"
PKG=""
PKG_NAME="unknown (manual install mode)"
INSTALL_MODE="restore-only"   # install | limited | restore-only
PRIV_CMD=""
IMMUTABLE_HINT=""

# --- helpers ---
have() { command -v "$1" >/dev/null 2>&1; }

ask_yn() {
  local prompt="${1:-Continue?}" ans
  if [ ! -t 0 ]; then
    echo "$prompt [y/N]: (non-interactive; defaulting to no)"
    return 1
  fi
  read -r -p "$prompt [y/N]: " ans || true
  [[ "$ans" == "Y" || "$ans" == "y" ]]
}

detect_priv() {
  if [ "$(id -u)" -eq 0 ]; then PRIV_CMD="root"; return 0; fi
  if have sudo; then PRIV_CMD="sudo"; return 0; fi
  if have doas; then PRIV_CMD="doas"; return 0; fi
  if have pkexec; then PRIV_CMD="pkexec"; return 0; fi
  PRIV_CMD=""
  return 1
}

run_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; return $?; fi
  if [ "$PRIV_CMD" = "sudo" ]; then sudo "$@"; return $?; fi
  if [ "$PRIV_CMD" = "doas" ]; then doas "$@"; return $?; fi
  if [ "$PRIV_CMD" = "pkexec" ]; then pkexec "$@"; return $?; fi
  echo "No root/sudo/doas/pkexec available. Skipping privileged command: $*"
  return 1
}

safe_copy_noclobber_file() {
  # $1 src file, $2 dst file
  local src="$1" dst="$2"
  [ -f "$src" ] || return 1
  if [ -e "$dst" ]; then return 2; fi
  if have cp; then
    cp "$src" "$dst" 2>/dev/null && return 0
  elif have cat; then
    cat "$src" > "$dst" 2>/dev/null && return 0
  fi
  return 1
}

safe_copy_dir_noclobber() {
  # $1 src dir, $2 dst parent (creates $2/basename if missing)
  local src="$1" dst_parent="$2" base dst
  [ -d "$src" ] || return 1
  base="$(basename "$src")"
  dst="$dst_parent/$base"
  if [ -e "$dst" ]; then return 2; fi
  if have cp; then
    # -r is widely supported; -n (no clobber) is GNU/BSD-ish but common. Fallback if needed.
    cp -rn "$src" "$dst_parent/" 2>/dev/null && return 0
    cp -r "$src" "$dst_parent/" 2>/dev/null && return 0
  fi
  return 1
}

find_inventory() {
  # Prints directory containing inventory.json, or empty.
  local base found=""
  if ! have find; then
    # Fallback: check obvious locations only.
    for base in "$1" "$HOME/Win2Lin_export" "$HOME/Desktop/Win2Lin_export" "$PWD/Win2Lin_export" "$PWD"; do
      [ -n "$base" ] && [ -f "$base/inventory.json" ] && { printf '%s' "$base"; return 0; }
    done
    return 1
  fi
  for base in "$1" "$HOME/Win2Lin_export" "$HOME/Desktop/Win2Lin_export" "$PWD/Win2Lin_export" "$PWD"; do
    [ -z "$base" ] && continue
    [ -f "$base/inventory.json" ] && { printf '%s' "$base"; return 0; }
    if [ -d "$base" ]; then
      found=$(find "$base" -maxdepth 3 -name inventory.json 2>/dev/null | head -n 1 2>/dev/null || true)
      if [ -z "$found" ]; then
        # Fallback for find implementations without -maxdepth
        found=$(find "$base" -name inventory.json 2>/dev/null | head -n 1 2>/dev/null || true)
      fi
      [ -n "$found" ] && { dirname "$found" 2>/dev/null || printf '%s' "${found%/*}"; return 0; }
    fi
  done
  return 1
}

# --- distro / environment detection ---
detect_distro() {
  local os_release="/etc/os-release"
  if [ -r "$os_release" ]; then
    # shellcheck disable=SC1090
    . "$os_release" 2>/dev/null || true
    DISTRO_ID="${ID:-}"
    DISTRO_ID_LIKE="${ID_LIKE:-}"
    DISTRO_PRETTY="${PRETTY_NAME:-${NAME:-unknown}}"
  fi
  # Immutable/atomic/declarative hints
  if [ -f /run/ostree-booted ] || have rpm-ostree; then
    IMMUTABLE_HINT="${IMMUTABLE_HINT} rpm-ostree/OSTree(atomic)"
  fi
  if [ "$DISTRO_ID" = "nixos" ] || [ -d /nix/store ]; then
    IMMUTABLE_HINT="${IMMUTABLE_HINT} Nix/NixOS(declarative)"
  fi
  if [ -r /usr/share/clear/version ] || [ "$DISTRO_ID" = "clear-linux-os" ]; then
    IMMUTABLE_HINT="${IMMUTABLE_HINT} Clear-Linux(swupd/stateless)"
  fi
  IMMUTABLE_HINT="$(echo "$IMMUTABLE_HINT" | sed 's/^ *//')"
}

detect_pkg_manager() {
  # Prefer explicit/safer choices for immutable systems.
  if [ -f /run/ostree-booted ] || have rpm-ostree; then
    PKG="rpm-ostree"; PKG_NAME="rpm-ostree (Fedora Atomic/Silverblue/Kinoite/etc.)"; INSTALL_MODE="limited"; return
  fi
  if [ "$DISTRO_ID" = "nixos" ] || { have nix && [ -d /nix/store ]; }; then
    PKG="nix"; PKG_NAME="nix (NixOS/Nix)"; INSTALL_MODE="restore-only"; return
  fi

  if have apt-get || have apt; then PKG="apt"; PKG_NAME="apt (Debian/Ubuntu/Mint/Pop!_OS/etc.)"; INSTALL_MODE="install";
  elif have dnf; then PKG="dnf"; PKG_NAME="dnf (Fedora/RHEL family)"; INSTALL_MODE="install";
  elif have pacman; then PKG="pacman"; PKG_NAME="pacman (Arch/Manjaro/EndeavourOS/etc.)"; INSTALL_MODE="install";
  elif have zypper; then PKG="zypper"; PKG_NAME="zypper (openSUSE/SLE)"; INSTALL_MODE="install";
  elif have apk; then PKG="apk"; PKG_NAME="apk (Alpine/postmarketOS/etc.)"; INSTALL_MODE="install";
  elif have xbps-install; then PKG="xbps"; PKG_NAME="xbps (Void)"; INSTALL_MODE="install";
  elif have swupd; then PKG="swupd"; PKG_NAME="swupd (Clear Linux)"; INSTALL_MODE="limited";
  elif have eopkg; then PKG="eopkg"; PKG_NAME="eopkg (Solus)"; INSTALL_MODE="install";
  elif have emerge; then PKG="emerge"; PKG_NAME="emerge (Gentoo; best-effort/cautious)"; INSTALL_MODE="limited";
  elif have nix-env || have nix; then PKG="nix"; PKG_NAME="nix profile/env (best-effort/manual guidance)"; INSTALL_MODE="limited";
  elif have yum; then PKG="yum"; PKG_NAME="yum (older RHEL/CentOS)"; INSTALL_MODE="install";
  else PKG=""; PKG_NAME="unknown (manual install mode)"; INSTALL_MODE="restore-only";
  fi
}

print_mode_summary() {
  echo ""
  echo "=== Win2Lin environment summary ==="
  echo "Distro: ${DISTRO_PRETTY}"
  [ -n "$DISTRO_ID" ] && echo "ID: $DISTRO_ID${DISTRO_ID_LIKE:+ (like: $DISTRO_ID_LIKE)}"
  [ -n "$IMMUTABLE_HINT" ] && echo "Hints: $IMMUTABLE_HINT"
  echo "Package manager: $PKG_NAME"
  echo "Privilege: ${PRIV_CMD:-none (root/sudo/doas/pkexec not found)}"
  case "$INSTALL_MODE" in
    install) echo "Mode: supported for best-effort installs (optional) + core restore." ;;
    limited) echo "Mode: limited installs (best-effort/manual guidance) + core restore. Review suggestions carefully." ;;
    *) echo "Mode: restore-only/manual installs + core restore. Core file restore should still work if basic tools exist." ;;
  esac
  echo "Core restore dependencies: bash; helpful tools include find, cp/mkdir/chmod, python3/python (optional summary)."
  echo "Note: not literally every distro can be installed/configured automatically; immutable/declarative systems need manual or profile-based steps."
  echo "==================================="
}

# --- locate export ---
detect_distro
detect_pkg_manager
detect_priv || true
print_mode_summary

if [ -z "$EXPORT_DIR" ]; then
  EXPORT_DIR="$(find_inventory "")" || EXPORT_DIR=""
fi
if [ -n "$EXPORT_DIR" ] && [ ! -f "$EXPORT_DIR/inventory.json" ] && [ -d "$EXPORT_DIR" ]; then
  EXPORT_DIR="$(find_inventory "$EXPORT_DIR")" || EXPORT_DIR="$EXPORT_DIR"
fi

echo ""
echo "Export folder: ${EXPORT_DIR:-<none>}"
if [ -z "$EXPORT_DIR" ] || [ ! -f "$EXPORT_DIR/inventory.json" ]; then
  echo "ERROR: inventory.json not found."
  echo "Copy the WHOLE dated folder (e.g. 20261107_143022), not files inside it."
  echo "Try: bash Win2Lin.sh ~/Win2Lin_export/20261107_143022"
  echo "If 'find' is unavailable, pass the exact dated export folder path."
  exit 1
fi

echo ""
echo "This script can (all optional, best-effort):"
echo "  - Install common tools if your environment supports safe automatic installs"
echo "  - Install Brave/VS Code via Flatpak (only if you choose and Flatpak is suitable)"
echo "  - Install Bun (if you choose)"
echo "  - Restore SAFE configs (.gitconfig, selected dot-dirs no-clobber, fonts, public SSH files)"
echo ""
echo "It will NOT copy browser passwords, cookies, private keys, or tokens. Re-login on Linux."
echo "Failures are non-fatal where practical; the script continues."
echo ""
ask_yn "Continue?" || { echo "Stopped. No changes made."; exit 0; }

# --- install base tools (best-effort, distro-flexible) ---
print_install_guidance() {
  case "$PKG" in
    rpm-ostree)
      echo "[tools] rpm-ostree/atomic system detected: NOT layering packages automatically."
      echo "        Prefer: flatpak, toolbox, or distrobox for apps/tools; use rpm-ostree only with care."
      echo "        Core file restore works without package changes."
      ;;
    nix)
      echo "[tools] Nix/NixOS detected: system config is declarative; NOT auto-installing system packages."
      echo "        Options: nix profile install (user), Home Manager, or edit your Nix config manually."
      echo "        Example user tools (verify names): nix profile install nixpkgs#git nixpkgs#curl nixpkgs#python3 nixpkgs#nodejs nixpkgs#jq nixpkgs#rsync"
      ;;
    swupd)
      echo "[tools] Clear Linux uses swupd bundles (best-effort). Bundle names differ from other distros."
      echo "        Example (review first): sudo swupd bundle-add dev-utils os-core-dev git nodejs-basic python3-basic"
      ;;
    emerge)
      echo "[tools] Gentoo/emerge is powerful but package names/USE flags are system-specific."
      echo "        Automatic installs are intentionally cautious. Install manually with emerge as needed."
      ;;
    *)
      echo "[tools] No automatic package manager detected or installs limited. Install manually with your distro's tools."
      echo "        Common tools: git curl wget python3 nodejs npm flatpak unzip jq rsync rclone zstd"
      ;;
  esac
}

install_base() {
  echo ""
  echo "[tools] Best-effort install via ${PKG_NAME}..."
  if [ -z "$PRIV_CMD" ] && [ "$PKG" != "nix" ]; then
    echo "No privilege escalation available; cannot install system packages. Use restore-only/manual mode."
    print_install_guidance
    return 0
  fi
  case "$PKG" in
    apt)
      local APT=apt-get
      have apt-get || APT=apt
      run_root "$APT" update || true
      run_root "$APT" install -y git curl wget python3 python3-pip nodejs npm flatpak unzip jq rsync rclone zstd ca-certificates || \
      run_root "$APT" install -y git curl wget python3 nodejs flatpak unzip jq rsync ca-certificates || true
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
      run_root apk add git curl wget python3 py3-pip nodejs npm flatpak unzip jq rsync rclone zstd bash ca-certificates || \
      run_root apk add git curl wget python3 nodejs flatpak unzip jq rsync bash ca-certificates || true
      ;;
    xbps)
      run_root xbps-install -Sy || true
      run_root xbps-install -y git curl wget python3 python3-pip nodejs flatpak unzip jq rsync rclone zstd ca-certificates || \
      run_root xbps-install -y git curl wget python3 nodejs flatpak unzip jq rsync ca-certificates || true
      ;;
    yum)
      run_root yum install -y git curl wget python3 python3-pip nodejs npm flatpak unzip jq rsync rclone zstd || \
      run_root yum install -y git curl wget python3 nodejs flatpak unzip jq rsync || true
      ;;
    eopkg)
      run_root eopkg update-repo || true
      run_root eopkg install -y git curl wget python3 nodejs flatpak unzip jq rsync || true
      ;;
    swupd)
      echo "Clear Linux/swupd: bundles are coarse-grained. Attempting a conservative best-effort set..."
      run_root swupd bundle-add git curl wget python3-basic nodejs-basic jq rsync || true
      ;;
    emerge)
      echo "Gentoo/emerge: automatic package installation is not performed by default (system-specific)."
      print_install_guidance
      ;;
    rpm-ostree|nix|"")
      print_install_guidance
      ;;
    *)
      print_install_guidance
      ;;
  esac
}

if [ "$INSTALL_MODE" = "restore-only" ] || [ "$PKG" = "rpm-ostree" ] || [ "$PKG" = "nix" ]; then
  echo ""
  echo "Automatic base package install is disabled/limited for this environment."
  print_install_guidance
elif [ -z "$PRIV_CMD" ]; then
  echo ""
  echo "No root/sudo/doas/pkexec available; skipping automatic package installs."
  print_install_guidance
else
  if ask_yn "Install common base tools now (best-effort, optional)?"; then install_base; else echo "Skipped base tool install."; fi
fi

# --- Flatpak apps (optional) ---
if have flatpak; then
  if ask_yn "Install Brave + VS Code via Flatpak (Flathub)?"; then
    flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || \
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    flatpak install -y --user flathub com.brave.Browser 2>/dev/null || \
      flatpak install -y flathub com.brave.Browser 2>/dev/null || \
      echo "Brave Flatpak failed (install manually for your distro)."
    flatpak install -y --user flathub com.visualstudio.code 2>/dev/null || \
      flatpak install -y flathub com.visualstudio.code 2>/dev/null || \
      echo "VS Code Flatpak failed (install manually)."
  else
    echo "Skipped Flatpak apps."
  fi
else
  echo "Flatpak not found; skipping Brave/VS Code Flatpak install."
  if [ "$PKG" = "rpm-ostree" ]; then
    echo "Atomic system note: Flatpak is usually the preferred way to install desktop apps."
  fi
fi

# --- Bun (optional) ---
if ask_yn "Install Bun (dev runtime) from bun.sh?"; then
  if have curl && have bash; then
    curl -fsSL https://bun.sh/install | bash || echo "Bun install failed (network, policy, or unsupported platform)."
  elif have wget && have bash; then
    wget -qO- https://bun.sh/install | bash || echo "Bun install failed (network, policy, or unsupported platform)."
  else
    echo "curl/wget+bash not found; cannot install Bun automatically."
  fi
else
  echo "Skipped Bun."
fi

# --- Restore safe configs ---
echo ""
echo "[restore] Restoring safe configs (core restore works across distros if basic tools are present)..."

# Find actual Windows user folder (Linux $USER may differ)
WIN_USER_DIR=""
if [ -d "$EXPORT_DIR/C_DRIVE/Users" ] && have find; then
  # Prefer matching $USER, else first non-system profile.
  for candidate in "$EXPORT_DIR/C_DRIVE/Users/$USER" "$EXPORT_DIR/C_DRIVE/Users"/*; do
    [ -d "$candidate" ] || continue
    base="$(basename "$candidate" 2>/dev/null || echo "$candidate")"
    case "$base" in
      Public|Default|"All Users"|"Default User"|defaultuser0) continue ;;
    esac
    WIN_USER_DIR="$candidate"; break
  done
elif [ -d "$EXPORT_DIR/C_DRIVE/Users/$USER" ]; then
  WIN_USER_DIR="$EXPORT_DIR/C_DRIVE/Users/$USER"
fi
[ -n "$WIN_USER_DIR" ] && echo "Windows user folder: $WIN_USER_DIR" || echo "Windows user folder not auto-detected (copy configs manually from C_DRIVE/Users/<name>/)."

# .gitconfig (no clobber)
for src in "$WIN_USER_DIR/.gitconfig" "$EXPORT_DIR/C_DRIVE/Users/$USER/.gitconfig"; do
  [ -n "$src" ] || continue
  if [ -f "$src" ] && [ ! -f "$HOME/.gitconfig" ]; then
    if have cp; then cp "$src" "$HOME/.gitconfig" 2>/dev/null && echo "Restored .gitconfig" && break; fi
  fi
done

# dot-config dirs (no clobber)
for d in .config .opencode .antigravity; do
  for src in "$WIN_USER_DIR/$d" "$EXPORT_DIR/C_DRIVE/$d"; do
    [ -n "$src" ] && [ -d "$src" ] || continue
    if [ ! -e "$HOME/$d" ]; then
      if safe_copy_dir_noclobber "$src" "$HOME" >/dev/null; then
        echo "Restored ~/$d (no-clobber)"
      else
        echo "Found $src but could not restore ~/$d (missing cp or permission issue)."
      fi
    else
      echo "Found $d in export but ~/$d already exists (skipped to avoid overwrite)."
    fi
    break
  done
done

# AppData hints (Windows app configs may need manual adaptation on Linux)
if [ -n "$WIN_USER_DIR" ]; then
  for app in Antigravity opencode Code; do
    src="$WIN_USER_DIR/AppData/Roaming/$app"
    [ -d "$src" ] && echo "Found Windows config: $src (Linux location may differ; copy/adapt manually if needed)"
  done
fi

# .ssh: safe files only, never private keys
restore_ssh_safe() {
  local sshdir="$1" pub dst
  [ -d "$sshdir" ] || return 1
  mkdir -p "$HOME/.ssh" 2>/dev/null || return 1
  [ -f "$sshdir/config" ] && [ ! -f "$HOME/.ssh/config" ] && cp "$sshdir/config" "$HOME/.ssh/" 2>/dev/null || true
  [ -f "$sshdir/known_hosts" ] && [ ! -f "$HOME/.ssh/known_hosts" ] && cp "$sshdir/known_hosts" "$HOME/.ssh/" 2>/dev/null || true
  [ -f "$sshdir/authorized_keys" ] && [ ! -f "$HOME/.ssh/authorized_keys" ] && cp "$sshdir/authorized_keys" "$HOME/.ssh/" 2>/dev/null || true

  # Restore only public keys (*.pub), never private key material.
  if have find; then
    while IFS= read -r pub; do
      [ -n "$pub" ] && [ -f "$pub" ] || continue
      dst="$HOME/.ssh/$(basename "$pub" 2>/dev/null)"
      [ -n "$dst" ] && [ ! -e "$dst" ] && cp "$pub" "$dst" 2>/dev/null || true
    done <<EOF
$(find "$sshdir" -maxdepth 1 -type f -name "*.pub" 2>/dev/null)
EOF
  else
    for pub in "$sshdir"/*.pub; do
      [ -f "$pub" ] || continue
      dst="$HOME/.ssh/$(basename "$pub" 2>/dev/null)"
      [ -n "$dst" ] && [ ! -e "$dst" ] && cp "$pub" "$dst" 2>/dev/null || true
    done
  fi

  chmod 700 "$HOME/.ssh" 2>/dev/null || true
  [ -f "$HOME/.ssh/config" ] && chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
  [ -f "$HOME/.ssh/known_hosts" ] && chmod 600 "$HOME/.ssh/known_hosts" 2>/dev/null || true
  [ -f "$HOME/.ssh/authorized_keys" ] && chmod 600 "$HOME/.ssh/authorized_keys" 2>/dev/null || true
  echo "Restored safe .ssh files only (config/known_hosts/authorized_keys/*.pub). Private keys NOT copied."
  return 0
}
for sshdir in "$WIN_USER_DIR/.ssh" "$EXPORT_DIR/C_DRIVE/Users/$USER/.ssh"; do
  [ -n "$sshdir" ] && restore_ssh_safe "$sshdir" && break || true
done

# Fonts (best-effort; paths/permissions vary)
if have cp && have mkdir; then
  for fdir in "$EXPORT_DIR/C_DRIVE/Windows/Fonts" "$WIN_USER_DIR/Fonts"; do
    [ -n "$fdir" ] && [ -d "$fdir" ] || continue
    mkdir -p "$HOME/.local/share/fonts/win2lin" 2>/dev/null || true
    cp "$fdir"/* "$HOME/.local/share/fonts/win2lin/" 2>/dev/null || true
    have fc-cache && fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || have fc-cache && fc-cache -f >/dev/null 2>&1 || true
    echo "Copied fonts from $fdir (best-effort; some Windows fonts may have license/compatibility limits)."
  done
fi

# --- Summary (python3 or python) ---
if have python3; then PYTHON_BIN=python3; elif have python; then PYTHON_BIN=python; fi
if [ -n "$PYTHON_BIN" ]; then
  # Try utf-8-sig-friendly read; keep non-fatal.
  "$PYTHON_BIN" - "$EXPORT_DIR" <<'PY' 2>/dev/null || true
import json, os, sys
export_dir = sys.argv[1]
inv_path = os.path.join(export_dir, "inventory.json")
try:
    with open(inv_path, "r", encoding="utf-8-sig") as f:
        d = json.load(f)
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
echo "Distro: $DISTRO_PRETTY"
echo "Mode: $INSTALL_MODE (package installs are optional/best-effort; core restore is the priority)."
echo "C_DRIVE = your old C: at: $EXPORT_DIR/C_DRIVE"
echo "D_DRIVE = your old D: at: $EXPORT_DIR/D_DRIVE"
echo "NVIDIA drivers, gaming launchers, and some apps are distro/environment-specific - install via your distro's normal tools."
echo "Immutable/declarative systems (rpm-ostree, NixOS, etc.) may require flatpak/toolbox/distrobox/nix profile/home-manager/manual config."
echo "Keep Windows for 1-2 weeks while testing Linux."
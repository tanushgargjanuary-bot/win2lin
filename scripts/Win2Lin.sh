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
DISTRO_VARIANT_ID=""
DISTRO_PRETTY="unknown"
PKG=""
PKG_NAME="unknown (manual install mode)"
INSTALL_MODE="restore-only"   # install | limited | restore-only
PRIV_CMD=""
IMMUTABLE_HINT=""
NO_AUTO_MUTATE=""             # set for atomic/transactional/declarative/managed systems

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
    DISTRO_VARIANT_ID="${VARIANT_ID:-}"
    DISTRO_PRETTY="${PRETTY_NAME:-${NAME:-unknown}}"
  fi

  # Distro-specific hints and friendly names (best-effort; detection uses ID/ID_LIKE/VARIANT_ID/commands)
  case "$DISTRO_ID" in
    omarchy) IMMUTABLE_HINT="${IMMUTABLE_HINT} Omarchy(Arch-based)"; [ "$DISTRO_PRETTY" = "unknown" ] && DISTRO_PRETTY="Omarchy" ;;
    cachyos) IMMUTABLE_HINT="${IMMUTABLE_HINT} CachyOS(Arch-based,mutable)" ;;
    garuda) IMMUTABLE_HINT="${IMMUTABLE_HINT} Garuda(Arch-based,mutable)" ;;
    endeavouros) IMMUTABLE_HINT="${IMMUTABLE_HINT} EndeavourOS(Arch-based,mutable)" ;;
    blendos) IMMUTABLE_HINT="${IMMUTABLE_HINT} blendOS(Arch-based,mutable)" ;;
    nobara) IMMUTABLE_HINT="${IMMUTABLE_HINT} Nobara(Fedora-based,mutable)" ;;
    ultramarine) IMMUTABLE_HINT="${IMMUTABLE_HINT} Ultramarine(Fedora-based,mutable)" ;;
    bazzite|bluefin|aurora) IMMUTABLE_HINT="${IMMUTABLE_HINT} Universal-Blue/Fedora-Atomic(immutable)" ;;
    microos|opensuse-microos|"opensuse-microos"|"opensuse-tumbleweed") : ;; # refined below
    aeon|kalpa) IMMUTABLE_HINT="${IMMUTABLE_HINT} openSUSE-${DISTRO_ID}(transactional/immutable)" ;;
    vanilla) IMMUTABLE_HINT="${IMMUTABLE_HINT} Vanilla-OS(managed/immutable)" ;;
    guix) IMMUTABLE_HINT="${IMMUTABLE_HINT} Guix(declarative/managed)" ;;
    steamos) IMMUTABLE_HINT="${IMMUTABLE_HINT} SteamOS(readonly/cautious)" ;;
    pop) IMMUTABLE_HINT="${IMMUTABLE_HINT} Pop!_OS(apt-based)" ;;
    zorin) IMMUTABLE_HINT="${IMMUTABLE_HINT} Zorin-OS(apt-based)" ;;
    elementary) IMMUTABLE_HINT="${IMMUTABLE_HINT} elementary-OS(apt-based)" ;;
    linuxmint) IMMUTABLE_HINT="${IMMUTABLE_HINT} Linux-Mint(apt-based)" ;;
    neon) IMMUTABLE_HINT="${IMMUTABLE_HINT} KDE-neon(apt-based)" ;;
    tuxedo) IMMUTABLE_HINT="${IMMUTABLE_HINT} TUXEDO-OS(apt-based)" ;;
  esac
  if [ "$DISTRO_ID" = "omarchy" ] || [ -f /etc/omarchy-release ] || have omarchy; then
    case " $IMMUTABLE_HINT " in *"Omarchy"*) ;; *) IMMUTABLE_HINT="${IMMUTABLE_HINT} Omarchy(Arch-based)" ;; esac
    [ "$DISTRO_PRETTY" = "unknown" ] && DISTRO_PRETTY="Omarchy"
  fi
  # openSUSE MicroOS/Aeon/Kalpa variants (transactional)
  case "$DISTRO_ID:$DISTRO_VARIANT_ID:$DISTRO_PRETTY" in
    *microos*|*MicroOS*|*:aeon:*|*Aeon*|*:kalpa:*|*Kalpa*)
      case " $IMMUTABLE_HINT " in *"transactional/immutable"*) ;; *) IMMUTABLE_HINT="${IMMUTABLE_HINT} openSUSE-transactional/immutable" ;; esac
      ;;
  esac

  # Immutable/atomic/declarative/managed hints
  if [ -f /run/ostree-booted ] || have rpm-ostree; then
    IMMUTABLE_HINT="${IMMUTABLE_HINT} rpm-ostree/OSTree(atomic)"
    NO_AUTO_MUTATE=1
  fi
  if [ "$DISTRO_ID" = "nixos" ] || [ -f /etc/NIXOS ]; then
    IMMUTABLE_HINT="${IMMUTABLE_HINT} NixOS(declarative)"
    NO_AUTO_MUTATE=1
  elif [ -d /nix/store ] || have nix-env || have nix; then
    case " $IMMUTABLE_HINT " in *"Nix"*) ;; *) IMMUTABLE_HINT="${IMMUTABLE_HINT} Nix present (user profile/Home Manager possible)" ;; esac
  fi
  if [ "$DISTRO_ID" = "guix" ] || [ -f /etc/guix ]; then
    case " $IMMUTABLE_HINT " in *"Guix"*) ;; *) IMMUTABLE_HINT="${IMMUTABLE_HINT} Guix System(declarative/managed)" ;; esac
    NO_AUTO_MUTATE=1
  elif [ -d /gnu/store ] || have guix; then
    case " $IMMUTABLE_HINT " in *"Guix"*) ;; *) IMMUTABLE_HINT="${IMMUTABLE_HINT} Guix present (user profile/manual possible)" ;; esac
  fi
  if [ "$DISTRO_ID" = "vanilla" ] || have abroot || have apx; then
    case " $IMMUTABLE_HINT " in *"Vanilla"*) ;; *) IMMUTABLE_HINT="${IMMUTABLE_HINT} Vanilla-OS/abroot-apx(managed)" ;; esac
    NO_AUTO_MUTATE=1
  fi
  if [ "$DISTRO_ID" = "steamos" ] || [ -f /etc/steamos-release ] || have steamos-readonly; then
    case " $IMMUTABLE_HINT " in *"SteamOS"*) ;; *) IMMUTABLE_HINT="${IMMUTABLE_HINT} SteamOS(readonly/cautious)" ;; esac
    NO_AUTO_MUTATE=1
  fi
  if have transactional-update; then
    case "$DISTRO_ID:$DISTRO_VARIANT_ID:$DISTRO_ID_LIKE:$DISTRO_PRETTY" in
      *microos*|*MicroOS*|*aeon*|*Aeon*|*kalpa*|*Kalpa*|*transactional*)
        IMMUTABLE_HINT="${IMMUTABLE_HINT} transactional-update(present)"
        NO_AUTO_MUTATE=1
        ;;
    esac
  fi
  if [ -r /usr/share/clear/version ] || [ "$DISTRO_ID" = "clear-linux-os" ]; then
    IMMUTABLE_HINT="${IMMUTABLE_HINT} Clear-Linux(swupd/stateless)"
  fi
  IMMUTABLE_HINT="$(echo "$IMMUTABLE_HINT" | sed 's/^ *//; s/  */ /g')"
}

detect_pkg_manager() {
  # Prefer explicit/safer choices for immutable/atomic/transactional/declarative/managed systems.
  # Never auto-mutate these: rpm-ostree layering, transactional-update pkg install, NixOS rebuild,
  # guix system reconfigure, abroot changes, or SteamOS system writes.
  if [ -f /run/ostree-booted ] || have rpm-ostree; then
    PKG="rpm-ostree"; PKG_NAME="rpm-ostree (Fedora Atomic/Universal Blue: Bazzite, Bluefin, Aurora, Silverblue, Kinoite)"; INSTALL_MODE="limited"; NO_AUTO_MUTATE=1; return
  fi
  if [ "$DISTRO_ID" = "nixos" ] || [ -f /etc/NIXOS ]; then
    PKG="nix"; PKG_NAME="nix (NixOS, declarative)"; INSTALL_MODE="restore-only"; NO_AUTO_MUTATE=1; return
  fi
  if [ "$DISTRO_ID" = "guix" ] || [ -f /etc/guix ]; then
    PKG="guix"; PKG_NAME="guix (Guix System, declarative/managed)"; INSTALL_MODE="restore-only"; NO_AUTO_MUTATE=1; return
  fi
  if [ "$DISTRO_ID" = "vanilla" ] || have abroot || have apx; then
    PKG="vanilla"; PKG_NAME="Vanilla OS / abroot+apx (managed)"; INSTALL_MODE="restore-only"; NO_AUTO_MUTATE=1; return
  fi
  # openSUSE MicroOS/Aeon/Kalpa or transactional systems: do NOT auto-run transactional-update.
  if have transactional-update; then
    case "$DISTRO_ID:$DISTRO_VARIANT_ID:$DISTRO_ID_LIKE:$DISTRO_PRETTY" in
      *microos*|*MicroOS*|*aeon*|*Aeon*|*kalpa*|*Kalpa*|*transactional*)
        PKG="transactional"; PKG_NAME="transactional-update (openSUSE MicroOS/Aeon/Kalpa, immutable/transactional)"; INSTALL_MODE="restore-only"; NO_AUTO_MUTATE=1; return
        ;;
    esac
  fi
  # SteamOS: often Arch-based but system partitions/readonly concerns. Be cautious.
  if [ "$DISTRO_ID" = "steamos" ] || [ -f /etc/steamos-release ] || have steamos-readonly; then
    PKG="steamos"; PKG_NAME="SteamOS (cautious; system may be readonly/managed)"; INSTALL_MODE="restore-only"; NO_AUTO_MUTATE=1; return
  fi

  if have apt-get || have apt; then
    PKG="apt"; INSTALL_MODE="install"
    case "$DISTRO_ID" in
      pop) PKG_NAME="apt (Pop!_OS, Ubuntu-based)" ;;
      zorin) PKG_NAME="apt (Zorin OS, Ubuntu-based)" ;;
      elementary) PKG_NAME="apt (elementary OS, Ubuntu-based)" ;;
      linuxmint) PKG_NAME="apt (Linux Mint, Ubuntu-based)" ;;
      neon) PKG_NAME="apt (KDE neon, Ubuntu-based)" ;;
      tuxedo) PKG_NAME="apt (TUXEDO OS, Ubuntu-based)" ;;
      *) PKG_NAME="apt (Debian/Ubuntu/Mint/Pop!_OS/Zorin/elementary/KDE neon/TUXEDO family)" ;;
    esac
  elif have dnf; then
    PKG="dnf"; INSTALL_MODE="install"
    case "$DISTRO_ID" in
      nobara) PKG_NAME="dnf (Nobara, Fedora-based, mutable)" ;;
      ultramarine) PKG_NAME="dnf (Ultramarine, Fedora-based, mutable)" ;;
      *) PKG_NAME="dnf (Fedora/RHEL family; Nobara/Ultramarine if mutable)" ;;
    esac
  elif have pacman; then
    PKG="pacman"; INSTALL_MODE="install"
    case "$DISTRO_ID" in
      omarchy) PKG_NAME="pacman (Omarchy, Arch-based)" ;;
      cachyos) PKG_NAME="pacman (CachyOS, Arch-based, mutable)" ;;
      garuda) PKG_NAME="pacman (Garuda, Arch-based, mutable)" ;;
      endeavouros) PKG_NAME="pacman (EndeavourOS, Arch-based, mutable)" ;;
      blendos) PKG_NAME="pacman (blendOS, Arch-based, mutable)" ;;
      manjaro) PKG_NAME="pacman (Manjaro, Arch-based)" ;;
      *) PKG_NAME="pacman (Arch/Manjaro/EndeavourOS/CachyOS/Garuda/blendOS/Omarchy family)" ;;
    esac
  elif have zypper; then PKG="zypper"; PKG_NAME="zypper (openSUSE Leap/Tumbleweed/SLE, mutable)"; INSTALL_MODE="install";
  elif have apk; then PKG="apk"; PKG_NAME="apk (Alpine/postmarketOS/etc.)"; INSTALL_MODE="install";
  elif have xbps-install; then PKG="xbps"; PKG_NAME="xbps (Void)"; INSTALL_MODE="install";
  elif have swupd; then PKG="swupd"; PKG_NAME="swupd (Clear Linux)"; INSTALL_MODE="limited";
  elif have eopkg; then PKG="eopkg"; PKG_NAME="eopkg (Solus)"; INSTALL_MODE="install";
  elif have emerge; then PKG="emerge"; PKG_NAME="emerge (Gentoo; best-effort/cautious)"; INSTALL_MODE="limited";
  elif have nix-env || have nix; then PKG="nix"; PKG_NAME="nix profile/env (best-effort/manual guidance)"; INSTALL_MODE="limited"; NO_AUTO_MUTATE=1;
  elif have yum; then PKG="yum"; PKG_NAME="yum (older RHEL/CentOS)"; INSTALL_MODE="install";
  else PKG=""; PKG_NAME="unknown (manual install mode)"; INSTALL_MODE="restore-only";
  fi
}

print_mode_summary() {
  echo ""
  echo "=== Win2Lin environment summary ==="
  echo "Distro: ${DISTRO_PRETTY}"
  [ -n "$DISTRO_ID" ] && echo "ID: $DISTRO_ID${DISTRO_ID_LIKE:+ (like: $DISTRO_ID_LIKE)}${DISTRO_VARIANT_ID:+ variant=$DISTRO_VARIANT_ID}"
  [ -n "$IMMUTABLE_HINT" ] && echo "Hints: $IMMUTABLE_HINT"
  echo "Package manager: $PKG_NAME"
  echo "Privilege: ${PRIV_CMD:-none (root/sudo/doas/pkexec not found)}"
  case "$INSTALL_MODE" in
    install) echo "Mode: install (mutable, best-effort, confirmed before installs) + core restore." ;;
    limited) echo "Mode: limited (best-effort/manual guidance) + core restore. Review suggestions carefully." ;;
    *) echo "Mode: restore-only (no automatic system mutation) + core restore. Core file restore should still work if basic tools exist." ;;
  esac
  echo "Core restore dependencies: bash; helpful tools include find, cp/mkdir/chmod, python3/python (optional summary)."
  echo "Safety: never auto-mutates immutable/atomic/transactional/declarative/managed systems (rpm-ostree layering, transactional-update pkg install, NixOS rebuild, guix system reconfigure, abroot changes)."
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
      echo "[tools] rpm-ostree/atomic system detected (e.g. Bazzite/Bluefin/Aurora/Silverblue/Kinoite): NOT layering packages automatically."
      echo "        Prefer: Flatpak for apps, distrobox/toolbox for CLI/dev tools, Homebrew-on-Linux if you use it."
      echo "        Manual (explicit, use care): rpm-ostree install <pkg> then reboot. Core file restore works without package changes."
      ;;
    transactional)
      echo "[tools] openSUSE MicroOS/Aeon/Kalpa (transactional/immutable) detected: NOT auto-running transactional-update to install packages."
      echo "        Prefer: Flatpak for apps, distrobox for CLI/dev tools."
      echo "        Manual transactional workflow (review carefully): sudo transactional-update pkg install <packages> then reboot."
      echo "        Core file restore works without package changes."
      ;;
    vanilla)
      echo "[tools] Vanilla OS (managed/abroot+apx) detected: NOT mutating system packages automatically."
      echo "        Prefer: apx for managed containers/packages, Flatpak for apps, distrobox if available."
      echo "        Core file restore works without package changes."
      ;;
    guix)
      echo "[tools] Guix System detected (declarative/managed): NOT running guix system reconfigure automatically."
      echo "        Options: guix install <pkg> (user profile), Guix Home, or edit your system/home config manually."
      echo "        Core file restore works without package changes."
      ;;
    steamos)
      echo "[tools] SteamOS detected: system partitions may be readonly/managed (SteamOS updates can affect system state)."
      echo "        Defaulting to restore-only/limited guidance. NOT auto-installing pacman packages."
      echo "        Prefer: Flatpak for apps, distrobox for CLI/dev tools. If you intentionally manage system packages, do so manually and understand SteamOS readonly/deck implications."
      echo "        Core file restore works without package changes."
      ;;
    nix)
      echo "[tools] Nix/NixOS detected: system config is declarative; NOT auto-installing system packages or rebuilding."
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
      echo "        Also consider: distrobox/toolbox/Flatpak on immutable or container-oriented setups."
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
      echo "Note: pacman installs are confirmed by you and intended for mutable Arch-family systems (e.g. CachyOS/Garuda/EndeavourOS/blendOS/Manjaro)."
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
    rpm-ostree|transactional|vanilla|guix|steamos|nix|"")
      print_install_guidance
      ;;
    *)
      print_install_guidance
      ;;
  esac
}

if [ "$INSTALL_MODE" = "restore-only" ] || [ -n "$NO_AUTO_MUTATE" ]; then
  echo ""
  echo "Automatic base package install is disabled for this environment (restore-only/safety)."
  print_install_guidance
elif [ -z "$PRIV_CMD" ]; then
  echo ""
  echo "No root/sudo/doas/pkexec available; skipping automatic package installs."
  print_install_guidance
else
  if ask_yn "Install common base tools now (best-effort, optional, mutable systems only)?"; then
    install_base
  else
    echo "Skipped base tool install."
  fi
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
  case "$PKG" in
    rpm-ostree|transactional|vanilla|steamos)
      echo "Managed/immutable system note: Flatpak and/or distrobox/apx are usually preferred for apps and tools."
      ;;
  esac
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
echo "Mode: $INSTALL_MODE${NO_AUTO_MUTATE:+ (no automatic system mutation)} (core restore is the priority)."
echo "C_DRIVE = your old C: at: $EXPORT_DIR/C_DRIVE"
echo "D_DRIVE = your old D: at: $EXPORT_DIR/D_DRIVE"
echo "NVIDIA drivers, gaming launchers, and some apps are distro/environment-specific - install via your distro's normal tools."
echo "Immutable/atomic/transactional/declarative/managed systems may require Flatpak, distrobox/toolbox, apx, nix profile/Home Manager, guix install/Home config, or careful manual steps."
echo "Keep Windows for 1-2 weeks while testing Linux."
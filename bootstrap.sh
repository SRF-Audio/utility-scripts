#!/usr/bin/env bash
set -euo pipefail

# ── 1. Detect OS flavor ─────────────────────────────────────
detect_os_flavor() {
  source /etc/os-release
  case "$ID" in
    aurora) echo "aurora" ;;
    fedora)
      case "${VARIANT_ID:-unknown}" in
        workstation) echo "fedora-workstation" ;;
        server)      echo "fedora-server"      ;;
        *)           echo "fedora-unknown"     ;;
      esac ;;
    rhel)
      if systemctl get-default | grep -qx 'graphical.target'; then
        echo "rhel-gui";    # GUI/non‑GUI only matters later
      else
        echo "rhel-headless"
      fi ;;
    ubuntu) echo "ubuntu-${VERSION_ID}" ;;
    *)      echo "unsupported" ;;
  esac
}

OS_FLAVOR=$(detect_os_flavor)
echo "🛈 Detected OS flavor: ${OS_FLAVOR}"
[[ $OS_FLAVOR == unsupported ]] && { echo "ERROR: Unsupported OS"; exit 1; }

# ── 2. Install Ansible when missing ─────────────────────────
cmd_exists() { command -v "$1" &>/dev/null; }

install_ansible() {
  case "$OS_FLAVOR" in
    aurora)
      # Aurora ships Homebrew; abort if it vanished
      if ! cmd_exists brew; then
        echo "ERROR: Homebrew not found on Aurora." >&2; exit 1
      fi
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
      brew list ansible &>/dev/null || {
        echo "→ Installing Ansible via Homebrew…"
        brew install ansible
      }
      ;;

    fedora-*|rhel-*)
      PKG_MGR=$(command -v dnf || command -v yum)
      echo "→ Installing ansible-core via $PKG_MGR…"
      sudo "$PKG_MGR" -y install ansible-core
      ;;

    ubuntu-*)
      echo "→ Installing ansible via apt-get…"
      sudo apt-get update -qq
      sudo apt-get -y install ansible
      ;;

    *)
      echo "ERROR: Install routine missing for $OS_FLAVOR" >&2
      exit 1
  esac
}

if cmd_exists ansible-playbook; then
  echo "✓ ansible already present"
else
  install_ansible
fi

echo "✅ ansible is now available"

cd ansible || { echo "ERROR: 'ansible' directory not found"; exit 1; }
ansible-playbook site.yml -vv
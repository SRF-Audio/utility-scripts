#!/usr/bin/env bash
# bootstrap.sh — bring a new machine up from scratch.
#
# Steps:
#   1. Detect OS flavor
#   2. Ensure git is installed
#   3. Clone utility-scripts (if not already present)
#   4. Set up dotfile symlinks
#   5. Install Ansible
#   6. Run the Ansible workstation playbook
#
# The dotfiles step (4) runs before Ansible so the shell environment is
# correct even if Ansible later fails or is run incrementally.
#
# Usage (run from anywhere, even before cloning):
#   curl -fsSL https://raw.githubusercontent.com/SRF-Audio/utility-scripts/main/bootstrap.sh | bash
#   -- or --
#   bash ~/GitHub/utility-scripts/bootstrap.sh

set -euo pipefail

REPO_URL="git@github.com:SRF-Audio/utility-scripts.git"
REPO_DIR="$HOME/GitHub/utility-scripts"

# ── Helpers ───────────────────────────────────────────────────────────────────
cmd_exists() { command -v "$1" &>/dev/null; }
info()  { echo "🛈  $*"; }
ok()    { echo "✅ $*"; }
warn()  { echo "⚠️  $*"; }
die()   { echo "❌ $*" >&2; exit 1; }

# ── 1. Detect OS flavor ───────────────────────────────────────────────────────
detect_os_flavor() {
  # shellcheck source=/dev/null
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
        echo "rhel-gui"
      else
        echo "rhel-headless"
      fi ;;
    ubuntu) echo "ubuntu-${VERSION_ID}" ;;
    *)      echo "unsupported" ;;
  esac
}

OS_FLAVOR=$(detect_os_flavor)
info "Detected OS flavor: ${OS_FLAVOR}"
[[ $OS_FLAVOR == unsupported ]] && die "Unsupported OS"

# ── 2. Ensure git ─────────────────────────────────────────────────────────────
if ! cmd_exists git; then
  info "Installing git…"
  case "$OS_FLAVOR" in
    fedora-*|rhel-*)
      PKG_MGR=$(command -v dnf || command -v yum)
      sudo "$PKG_MGR" -y install git ;;
    ubuntu-*)
      sudo apt-get update -qq && sudo apt-get -y install git ;;
    aurora)
      cmd_exists brew || die "Homebrew not found on Aurora"
      brew install git ;;
  esac
fi
ok "git $(git --version | awk '{print $3}')"

# ── 3. Clone repo if not present ──────────────────────────────────────────────
if [[ -d "$REPO_DIR/.git" ]]; then
  info "Repo already present at $REPO_DIR"
else
  info "Cloning utility-scripts into $REPO_DIR…"
  mkdir -p "$HOME/GitHub"
  git clone "$REPO_URL" "$REPO_DIR"
  ok "Cloned utility-scripts"
fi

# ── 4. Dotfile symlinks ───────────────────────────────────────────────────────
info "Setting up dotfile symlinks…"
setup_symlinks() {
  local repo="$REPO_DIR"
  local backup_dir="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

  _symlink() {
    local src="$1" dest="$2"
    # Already pointing to the right place?
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
      return 0
    fi
    # Back up a regular file before clobbering it
    if [[ -e "$dest" && ! -L "$dest" ]]; then
      mkdir -p "$backup_dir"
      cp -a "$dest" "$backup_dir/$(basename "$dest")"
      echo "    backed up: $dest"
    fi
    rm -rf "$dest"
    ln -s "$src" "$dest"
    echo "    linked: $dest → $src"
  }

  # Prerequisite dirs
  mkdir -p \
    "$HOME/.ssh/config.d" \
    "$HOME/.tmux" \
    "$HOME/.local/bin" \
    "$HOME/.aws" \
    "$HOME/.claude" \
    "$HOME/.claude/projects/-home-sfroeber-GitHub-utility-scripts"

  # Shell
  _symlink "$repo/dotfiles/zshrc"                    "$HOME/.zshrc"
  _symlink "$repo/dotfiles/p10k.zsh"                 "$HOME/.p10k.zsh"
  _symlink "$repo/dotfiles/npmrc"                    "$HOME/.npmrc"

  # tmux
  _symlink "$repo/dotfiles/tmux.conf"                "$HOME/.tmux.conf"
  _symlink "$repo/dotfiles/tmux/theme-home.conf"     "$HOME/.tmux/theme-home.conf"
  _symlink "$repo/dotfiles/tmux/theme-work.conf"     "$HOME/.tmux/theme-work.conf"

  # Git identities
  _symlink "$repo/dotfiles/git/gitconfig-github"      "$HOME/.gitconfig-github"
  _symlink "$repo/dotfiles/git/gitconfig-gitlab"      "$HOME/.gitconfig-gitlab"

  # SSH
  _symlink "$repo/dotfiles/ssh/config"               "$HOME/.ssh/config"
  _symlink "$repo/dotfiles/ssh/config.d/10-defaults.conf" "$HOME/.ssh/config.d/10-defaults.conf"
  _symlink "$repo/dotfiles/ssh/config.d/20-personal.conf" "$HOME/.ssh/config.d/20-personal.conf"
  _symlink "$repo/dotfiles/ssh/config.d/50-work.conf"     "$HOME/.ssh/config.d/50-work.conf"

  # Local bin scripts
  _symlink "$repo/dotfiles/local-bin/tmux-homelab"   "$HOME/.local/bin/tmux-homelab"
  _symlink "$repo/dotfiles/local-bin/tailscale_tmux_status" "$HOME/.local/bin/tailscale_tmux_status"
  _symlink "$repo/dotfiles/local-bin/claude-work"    "$HOME/.local/bin/claude-work"
  chmod +x "$repo/dotfiles/local-bin/tmux-homelab" \
            "$repo/dotfiles/local-bin/tailscale_tmux_status" \
            "$repo/dotfiles/local-bin/claude-work"

  # AWS
  _symlink "$repo/dotfiles/aws/config"               "$HOME/.aws/config"

  # Claude Code
  _symlink "$repo/claude/CLAUDE.md"                  "$HOME/.claude/CLAUDE.md"
  _symlink "$repo/claude/settings.json"              "$HOME/.claude/settings.json"
  _symlink "$repo/claude/commands"                   "$HOME/.claude/commands"
  _symlink "$repo/claude/skills"                     "$HOME/.claude/skills"
  _symlink "$repo/claude/mcp-wrappers"               "$HOME/.claude/mcp-wrappers"
  chmod +x "$repo/claude/mcp-wrappers/"*.sh 2>/dev/null || true

  # Claude project memory (scoped to this repo's working directory)
  _symlink "$repo/claude/memory" \
    "$HOME/.claude/projects/-home-sfroeber-GitHub-utility-scripts/memory"
}

setup_symlinks
ok "Dotfile symlinks in place"

# ── 5. Install Ansible ────────────────────────────────────────────────────────
install_ansible() {
  case "$OS_FLAVOR" in
    aurora)
      cmd_exists brew || die "Homebrew not found on Aurora"
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
      brew list ansible &>/dev/null || {
        info "Installing Ansible via Homebrew…"
        brew install ansible
      } ;;
    fedora-*|rhel-*)
      PKG_MGR=$(command -v dnf || command -v yum)
      info "Installing Ansible via $PKG_MGR…"
      sudo "$PKG_MGR" -y install ansible ;;
    ubuntu-*)
      info "Installing Ansible via apt-get…"
      sudo apt-get update -qq
      sudo apt-get -y install ansible ;;
    *)
      die "No Ansible install routine for $OS_FLAVOR" ;;
  esac
}

if cmd_exists ansible-playbook; then
  ok "Ansible $(ansible --version | head -1 | awk '{print $NF}') already present"
else
  install_ansible
  ok "Ansible installed"
fi

# ── 6. Run Ansible ────────────────────────────────────────────────────────────
info "Running Ansible workstation playbook…"
cd "$REPO_DIR/ansible" || die "'ansible' directory not found in repo"
ansible-playbook playbooks/dotfiles.yml
ansible-playbook playbooks/workstations.yml --limit "$(hostname)"
ansible-playbook playbooks/claude-code-setup.yml

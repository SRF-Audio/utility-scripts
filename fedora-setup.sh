#!/bin/bash
# ------------------------------------------------------------------------------
# Stephen's Fedora Workstation Setup — thin entrypoint.
#
# This just bootstraps git + the repo, then hands off to bootstrap.sh, which
# owns OS detection, dotfile symlinks, Ansible install, and the workstation
# playbook run. Kept for the historical wget one-liner:
#
#   wget "https://raw.githubusercontent.com/SRF-Audio/utility-scripts/main/fedora-setup.sh" -O setup.sh && chmod +x setup.sh && ./setup.sh
# ------------------------------------------------------------------------------
set -euo pipefail

sudo dnf install -y git
git clone https://github.com/SRF-Audio/utility-scripts.git "$HOME/GitHub/utility-scripts" 2>/dev/null || true
bash "$HOME/GitHub/utility-scripts/bootstrap.sh"

rm -f "$HOME/setup.sh"

#!/usr/bin/env bash
# One-time restic backup of /home/sfroeber → Synology NAS
# Synology will then replicate this to Hetzner Storage Box via the existing backup job.
#
# Prerequisites:
#   - restic installed (sudo dnf install restic)
#   - 1Password CLI authenticated (op account list)
#   - ~/.ssh/coachlight-homelab.pem authorized on the NAS (see ~/.ssh/config.d/20-personal.conf)
#
# Usage: ./fedora-workstation-backup.sh

set -euo pipefail

NAS_HOST="srfaudio.rohu-shark.ts.net"
NAS_USER="stephenfroeber"
SSH_KEY="$HOME/.ssh/coachlight-homelab.pem"
SOURCE="$HOME"

# Synology SFTP root is the shares root, NOT the filesystem root.
# /homes/StephenFroeber maps to /volume2/homes/StephenFroeber on disk.
REPO_PATH="/homes/StephenFroeber/fedora-workstation-desktop-backup"

# Fetch password from 1Password
export RESTIC_PASSWORD
RESTIC_PASSWORD=$(op read "op://HomeLab/Synology Restic Repository/password")

export RESTIC_REPOSITORY="sftp:${NAS_HOST}:${REPO_PATH}"

echo "==> Checking SSH connectivity to NAS..."
ssh -i "${SSH_KEY}" -o BatchMode=yes "${NAS_USER}@${NAS_HOST}" 'echo ok' || {
    echo "ERROR: Cannot SSH to ${NAS_HOST}. Verify Tailscale is up and the key is authorized."
    exit 1
}

echo "==> Initializing repository (no-op if already exists)..."
if restic snapshots &>/dev/null; then
    echo "    Repository already exists, skipping init."
else
    restic init
fi

echo "==> Starting backup of ${SOURCE} → ${RESTIC_REPOSITORY}"
echo "    This may take a long time. Ctrl-C is safe — restic resumes from the lock on next run."
echo ""

restic backup \
    --verbose \
    --one-file-system \
    --exclude="${SOURCE}/.cache" \
    --exclude="${SOURCE}/.local/share/Trash" \
    --exclude="${SOURCE}/.npm" \
    --exclude="${SOURCE}/.cargo/registry" \
    --exclude="${SOURCE}/.cargo/git" \
    --exclude="${SOURCE}/.gradle" \
    --exclude="${SOURCE}/.m2" \
    --exclude="${SOURCE}/.var/app" \
    --exclude="node_modules" \
    --exclude="__pycache__" \
    --exclude="*.pyc" \
    --exclude=".venv" \
    --exclude="venv" \
    "${SOURCE}"

echo ""
echo "==> Backup complete. Snapshots in repo:"
restic snapshots

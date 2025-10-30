#!/usr/bin/env bash
set -euo pipefail

# Locale: avoid LC_ALL warnings; fall back to C.UTF-8 if en_US isn't present
if ! locale -a 2>/dev/null | grep -qi 'en_US\.utf8'; then
    export LANG="C.UTF-8"
else
    export LANG="en_US.UTF-8"
fi
unset LC_ALL || true

# Ensure .ssh exists with sane perms even when files are bind-mounted readonly
mkdir -p /home/vscode/.ssh
touch /home/vscode/.ssh/known_hosts || true
chmod 700 /home/vscode/.ssh || true
chmod 600 /home/vscode/.ssh/known_hosts 2>/dev/null || true
chmod 600 /home/vscode/.ssh/config 2>/dev/null || true
chown -R vscode:vscode /home/vscode/.ssh || true

# 1Password agent socket
if [ -S /ssh-agent ]; then
    export SSH_AUTH_SOCK=/ssh-agent
fi

# Preload GitLab host key (best-effort)
if ! grep -q 'gitlab.com' /home/vscode/.ssh/known_hosts 2>/dev/null; then
    ssh-keyscan -T 5 -t ed25519 gitlab.com >> /home/vscode/.ssh/known_hosts || true
fi

# Ensure a .zshrc exists and set a deterministic theme
if [ ! -f "$HOME/.zshrc" ]; then
    cat > "$HOME/.zshrc" <<'ZRC'
export LANG=${LANG:-en_US.UTF-8}
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git)
source $ZSH/oh-my-zsh.sh
ZRC
fi
sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="agnoster"/' "$HOME/.zshrc" || true

# Git identity (best-effort; override via localEnv if present)
git config --global user.name "${GIT_AUTHOR_NAME:-vscode}" || true
git config --global user.email "${GIT_AUTHOR_EMAIL:-vscode@container}" || true

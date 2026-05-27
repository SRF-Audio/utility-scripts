# Claude Code — Global Instructions

## Who I am
- **Stephen Froeber** — platform/infrastructure engineer
- **OS:** Fedora Linux, KDE Plasma
- **Shell:** zsh + Oh My Zsh + Powerlevel10k, always inside tmux
- **Repos:** GitHub (`~/GitHub/`) for personal/homelab, GitLab (`~/GitLab/`) for work

## Homelab
- **Coachlight cluster:** K3s on Proxmox VMs (3 control plane + 3 workers), Tailscale mesh (`rohu-shark.ts.net`)
- **Hetzner:** single-node K3s, Tailscale, ArgoCD + observability stack (kube-prometheus, Loki, MinIO, Alloy)
- **Synology NAS:** `srfaudio.rohu-shark.ts.net` — restic backups to Hetzner Storage Box
- **DNS/VPN:** NextDNS + Tailscale everywhere; 1Password SSH agent for all auth

## Key tools & conventions
- **Secrets:** always `op run` or `op item get` / `op read` — never inline vars, env exports, or `read -rs`
- **K8s:** ArgoCD (GitOps), Helm charts, k9s for interactive inspection
- **IaC:** Ansible in `~/GitHub/utility-scripts/ansible/` — idempotent, tagged, roles-based
- **Dotfiles:** version-controlled in `~/GitHub/utility-scripts/dotfiles/`, symlinked to `~/`
- **Claude config:** version-controlled in `~/GitHub/utility-scripts/claude/`, symlinked to `~/.claude/`
- **Git signing:** SSH commit signing via 1Password (`op-ssh-sign`), GitHub repos only for now

## Preferences
- Terse, direct answers — skip preamble
- Show commands I can run in the terminal (`! <command>` syntax when I need to run something myself)
- Prefer idempotent changes; always back up before replacing existing files
- When modifying Ansible: keep the existing role/tag structure; don't flatten into tasks files

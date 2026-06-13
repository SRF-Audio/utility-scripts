# Claude Code — Global Instructions

## Who I am
- **Stephen Froeber** — platform/infrastructure engineer
- **OS:** Fedora Linux, KDE Plasma
- **Shell:** zsh + Oh My Zsh + Powerlevel10k, always inside tmux
- **Repos:** GitHub (`~/GitHub/`) for personal/homelab, GitLab (`~/GitLab/`) for work

## Machines
**Always know where you are before OS-level/install/system advice:** run `bash ~/.claude/skills/host-env/detect.sh` (host-env skill) — distrobox vs native vs macOS changes package managers, host-tool access, and immutability rules.
- **Desktop** — ASUS PRIME B650M · Ryzen 7 7700X · Radeon 7800XT · 96GB RAM. Primary: native Fedora Workstation (mutable, dnf).
- **Laptop** (`sfroeber-amd-aurora-laptop`) — ROG Zephyrus G16 · Ryzen AI 9 HX 370 · RTX 4070 Laptop · 32GB RAM. Primary: **Fedora distrobox inside Aurora-DX** (immutable host — host tools via `distrobox-host-exec`, never dnf on host).
- Both Linux machines dual-boot **Windows 11 from a 2nd SSD — gaming only**, not separate machines; Claude Code never runs there.
- **Mac Mini** — macOS, rare use: brew, launchd, BSD userland.

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

## Claude config conventions (`claude/` = `~/.claude/`)
- **One skill per domain.** A skill owns everything for its domain: lean SKILL.md (trigger-rich description), bundled scripts, and supporting docs read on demand (e.g. `fitness-coach/` = persona + `strava.py` + `STRAVA.md`). Don't split data access, auth, or personas into sibling skills or memory.
- **Memory = state + lookups only.** `project_*` = evolving facts; `reference_*` = where things live; `feedback_*` = behavioral rules. Procedures, personas, and command lines belong in skills — memory points to skills by name only. A memory that's mostly commands is a skill wanting to be born.
- **MEMORY.md hooks** are one line, "use when" style — they're the entire recall trigger. Prune or update stale state memories on sight; resolved-issue history lives in git, not memory.
- **Settings layers:** `claude/settings.json` = user-global; `<repo>/.claude/settings.json` = tracked, shared; `settings.local.json` = per-machine, gitignored, never committed.
- **Distrobox:** when a session is containerized (see Machines / host-env skill), `op` and other host-only tools need `distrobox-host-exec`; skill scripts should auto-detect (`CONTAINER_ID` env), see `fitness-coach/strava.py`.

## Preferences
- Terse, direct answers — skip preamble
- Show commands I can run in the terminal (`! <command>` syntax when I need to run something myself)
- Prefer idempotent changes; always back up before replacing existing files
- When modifying Ansible: keep the existing role/tag structure; don't flatten into tasks files
- Prefer proven design patterns in architecture
- When you notice something useful, or that we repeat often that could be better handled by creating a skill, say so

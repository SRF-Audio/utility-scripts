---
name: project_workstation_migration
description: "Laptop is migrating off Aurora-DX distrobox to native Fedora Workstation; provisioning built on a branch, cutover pending"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2b3334f9-e523-49e0-9662-2e7746f7d4bf
---

The laptop (`sfroeber-amd-aurora-laptop`, ASUS ROG Zephyrus G16, RTX 4070 +
Radeon 890M) is being moved from **Fedora distrobox on immutable Aurora-DX** to
**native Fedora Workstation**, to remove immutable-workflow friction.

As of 2026-06-24, native provisioning is **built and committed on branch
`workstation-migration`** (commit `d460feb`), not yet merged to main. Six new
atomic Ansible roles drive `playbooks/workstations.yml` (run by `bootstrap.sh`):
`base_packages`, `repos_services` (1Password desktop / VS Code / **docker-ce**),
`nvidia_asus_hw` (akmod-nvidia + container-toolkit + asusctl/supergfxctl via the
**Terra repo** — lukenukem COPR is deprecated — + restored `/etc/asusd/*.ron`),
`flatpak_apps`, `audio` (native PipeWire), `kde`. See the [[host-env]] skill.

Decisions: docker over podman; **maximize dnf/native** (Steam, OBS, creative
apps, browsers native; only proprietary/sandbox apps stay flatpak); power
backend swapped tuned-ppd → **power-profiles-daemon** (asusd's official path).

**A9 cutover work — deferred ON PURPOSE until the actual reinstall** (these
files are symlinked live into the running session, so editing pre-cutover
misreports the machine). Complete teardown list (from a pre-wipe
`grep distrobox|host-exec|CONTAINER_*|/run/host` over tracked dotfiles — all
distrobox-isms are `CONTAINER_ID`-gated, so a half-migrated state is SAFE):
- `dotfiles/zshrc` L33-42 — remove the `CONTAINER_ID` block (tailscale alias +
  `CONTAINER_HOST`/`DOCKER_HOST` podman-socket passthrough); native docker-ce +
  native tailscaled replace it.
- `dotfiles/local-bin/claude-work` L5-8 — dead distrobox `op` branch, trim.
- `claude/skills/fitness-coach/strava.py` L50-53 — dead distrobox-host-exec `op`
  branch, trim.
- host-env `SKILL.md` — flip laptop row + distrobox rules section to native.
- `claude/CLAUDE.md` — laptop Machines entry distrobox→native.
- retire `ansible/old_roles/workstation_prep`; update [[project_claude_dual_profile]].
No Tilt/k3d/kubeconfig host-passthrough strays exist (verified). Do NOT do any
of this until Stephen confirms the reinstall happened.

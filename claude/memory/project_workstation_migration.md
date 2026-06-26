---
name: project_workstation_migration
description: "Laptop Aurora-DX→native Fedora migration COMPLETE as of 2026-06-25; all cleanup done"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2b3334f9-e523-49e0-9662-2e7746f7d4bf
---

The laptop (`sfroeber-amd-fedora-laptop`, ASUS ROG Zephyrus G16, RTX 4070 +
Radeon 890M) is **now running native Fedora KDE Workstation** — Aurora-DX +
distrobox are gone. Migration confirmed 2026-06-25; all dotfile/skill/Ansible
cleanup completed in the same session.

**What was cleaned up (2026-06-25):**
- `ansible/` — all Aurora-DX/distrobox comments removed from roles and playbooks
- `dotfiles/zshrc` — Distrobox CONTAINER_ID block removed
- `dotfiles/local-bin/claude-work` — distrobox `op` branch removed
- `claude/skills/fitness-coach/strava.py` — distrobox-host-exec branch in `_op_cmd()` removed
- `claude/skills/host-env/SKILL.md` — laptop row and rules updated to native Fedora
- `claude/CLAUDE.md` — laptop entry updated (hostname, env); Distrobox convention line removed

Both machines are now identical-stack native Fedora Workstation. No more
container indirection for `op` or host tools on the laptop.

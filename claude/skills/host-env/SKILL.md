---
name: host-env
description: Identify which of Stephen's machines and which environment the current session runs in — desktop (native Fedora Workstation), laptop (Fedora distrobox on immutable Aurora-DX), or Mac Mini (macOS) — and the constraints that follow. Use before any OS-level advice, software install, system configuration, service management, or path/tooling decision that differs by machine or by container-vs-host context.
---

# host-env

Run the detector first; trust its output over assumptions:

```
bash ~/.claude/skills/host-env/detect.sh
```

It fingerprints the machine by CPU model (no hostname dependency), detects
distrobox via `CONTAINER_ID`/`/run/.containerenv`, and immutable hosts via
`ostree-booted` (checked through `/run/host/` when containerized).

## Machines (hardware in CLAUDE.md "Machines")

| Detection result | Where you are | Default environment |
|---|---|---|
| CPU `7700X` | Desktop | Native Fedora Workstation (mutable) |
| CPU `HX 370` | Laptop | Fedora distrobox on Aurora-DX (immutable) |
| `uname -s` = Darwin | Mac Mini | macOS (rare) |

Both Linux machines also dual-boot Windows 11 from a second SSD — gaming
only; Claude Code sessions never run there. If booted to Windows, the Linux
side simply isn't running.

## Rules per environment

**Distrobox on Aurora-DX (laptop default):**
- Inside the container: normal mutable Fedora — `dnf install` is fine and is
  the preferred way to get CLI tooling.
- Host-only tools must go through `distrobox-host-exec`: `op` (1Password
  desktop/session lives on the host), `podman`, `docker`, `tailscale`,
  `flatpak`, `rpm-ostree`, `systemctl`, `journalctl`. Skill scripts should
  auto-detect (`CONTAINER_ID` set → prefix the command), like
  `fitness-coach/strava.py` does.
- Never suggest `dnf` on the host. Host package changes: flatpak for GUI
  apps; `rpm-ostree install` only as a last resort (layered, needs reboot).
- `/home` and `/var/home` are the same place on Atomic hosts — path-keyed
  identity (like Claude Code project dirs) can split across the two
  spellings; prefer `/home/...` consistently.

**Native Fedora Workstation (desktop default):**
- Mutable: `dnf`, direct `systemctl`, no container indirection. No
  `distrobox-host-exec` — it doesn't exist there.

**macOS (Mac Mini, rare):**
- `brew` for packages; `launchd` not systemd; BSD userland — `sed -i`,
  `grep`, `date`, `stat` flags differ from GNU. No `op` wrapper assumptions —
  verify 1Password CLI setup before relying on it.

**Everywhere:** secrets via `op` per CLAUDE.md; if `op` fails inside a
container, route through `distrobox-host-exec op` before debugging anything
else.

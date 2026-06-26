---
name: host-env
description: Identify which of Stephen's machines and which environment the current session runs in — desktop (native Fedora Workstation), laptop (native Fedora Workstation), or Mac Mini (macOS) — and the constraints that follow. Use before any OS-level advice, software install, system configuration, service management, or path/tooling decision that differs by machine or by container-vs-host context.
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
| CPU `HX 370` | Laptop | Native Fedora Workstation (mutable) |
| `uname -s` = Darwin | Mac Mini | macOS (rare) |

Both Linux machines also dual-boot Windows 11 from a second SSD — gaming
only; Claude Code sessions never run there. If booted to Windows, the Linux
side simply isn't running.

## Rules per environment

**Native Fedora Workstation (desktop and laptop):**
- Mutable: `dnf`, direct `systemctl`, no container indirection.
- `op` runs directly — no `distrobox-host-exec` wrapper needed.

**macOS (Mac Mini, rare):**
- `brew` for packages; `launchd` not systemd; BSD userland — `sed -i`,
  `grep`, `date`, `stat` flags differ from GNU. No `op` wrapper assumptions —
  verify 1Password CLI setup before relying on it.

**Everywhere:** secrets via `op` per CLAUDE.md; if `op` fails inside a
container, route through `distrobox-host-exec op` before debugging anything
else.

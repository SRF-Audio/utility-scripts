---
name: project-gaming
description: "Gaming/sim rig hardware specs, per-rig binding constraints, and player background for all flight sim and space game work (ED, MSFS2024, DCS, Project Wingman, etc.)"
metadata:
  type: project
---

# Gaming & Sim Context

## Hardware Setups

### VKB rig — PC (available ~Aug/Sep 2026)
- **Machine:** ASUS PRIME B650M, Ryzen 7 7700X, Radeon 7800XT, 96GB RAM — dual boot Fedora Workstation / Windows 11
- **Display:** PSVR2 (SteamVR)
- **Controllers:** VKB Gladiator NXT Omni L (left), VKB Gladiator NXT Omni R (right), VKB T-Rudder Mk V (pedals)
- **VR constraints:** no keyboard access during play — all bindings must land on HOTAS/pedals. No head-look controls needed (HMD handles that). Lean on analog ministicks (A1), hats (A3, A4, C1), button clusters, and the D1 modifier layer fully.
- **Linux note:** games run via Proton/Lutris on Fedora; VKB sticks have good Linux HID support.

### Boopidoo rig — laptop (current primary until ~Aug/Sep 2026)
- **Machine:** Asus ROG Zephyrus G16, Ryzen AI 9 HX 370, RTX 4070 Laptop, 32GB RAM — dual boot Windows 11 / Aurora-DX (flat screen, no VR)
- **Controller:** "Boopidoo" custom compact HOTAS from Etsy — 6DOF upgrade (two 3-axis spring-loaded sticks with push buttons, 10 push buttons, 4×4 keypad OR three 2-pos flip switches, HAT/POV with push, 4-position slide switch; up to 39 controls total). Portable/travel unit.
- **Mapping philosophy:** maximize 6DOF sticks for full translational + rotational thrust; use keypad and switches for mode/system functions. No pedals on this rig.

## Player Background (relevant to sim advice)
- Retired USAF Battle Management Controller (weapons director) — understands energy management, radar/sensor envelopes, weapons employment logic; use these as analogies for ED/DCS concepts rather than dumbing things down
- BS Aeronautics, Embry-Riddle
- 500+ hours No Man's Sky; also plays MSFS2024 and DCS; new to Elite Dangerous-specific mechanics (meta, engineering, BGS)
- Senior cloud software engineer — technically fluent; no hand-holding needed on setup, Proton/Linux tweaks, third-party tools

## Sims in Active Use
| Sim | Rig | Status |
|---|---|---|
| Elite Dangerous | Boopidoo (now), VKB (later) | Active — new player |
| MSFS 2024 | Both | Active |
| DCS World | Both | Active |
| Project Wingman | TBD | Planned |

## When advising on bindings
- Always ask which rig if not specified — optimal mappings differ significantly between the two setups
- For VKB rig: account for VR (no keyboard); leverage ministicks, hats, D1 layer fully
- For Boopidoo rig: 6DOF sticks carry translational+rotational axes; keypad handles mode/UI functions

**Why:** Two very different controller setups that are in use simultaneously for the same sims. Hardware context is needed before any binding recommendation makes sense.

**How to apply:** Load this when the user asks about sim control bindings, HOTAS mapping, or working in the `hetzner/k8s/hotas_mappings/` codebase.

See [[project-fitness]] for sports/training context (separate domain).

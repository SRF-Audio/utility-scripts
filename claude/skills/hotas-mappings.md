---
name: hotas-mappings
description: Query and update HOTAS controller mappings for all sims and rigs. Handles per-game queries ("what's unmapped?", "what goes on A3 hat?") and cross-game consistency work ("map MSFS like ED"). Runs a 6-phase agent flow to keep context tight and validate before writing.
---

# HOTAS Mappings Skill

## Project root
`/home/sfroeber/GitHub/utility-scripts/hetzner/k8s/hotas_mappings/`

## Quick reference: files and what they cost

| File | Size | Load when |
|---|---|---|
| `tools/_index.json` | tiny | VKB queries, always |
| `tools/_boopidoo_index.json` | tiny | Boopidoo queries, always |
| `tools/{profile}.json` | 30–131 lines | per VKB game mentioned |
| `tools/boopidoo-{game}.json` | varies | per Boopidoo game mentioned |
| `tools/vkb_gladiator_left.csv` | 61 lines | rig=vkb, any question |
| `tools/vkb_gladiator_right.csv` | 58 lines | rig=vkb, any question |
| `tools/elite_dangerous_controls.csv` | 423 lines | "what ED actions are available?" only |
| `configmap.yml` | ~87KB | Write phase only — profile key section, never `index.html` |

**Never load `configmap.yml` for query or advisory work.**

## Profiles

| ID | Sim |
|---|---|
| `ed-flight` | Elite Dangerous — ship flight |
| `ed-galmap` | Elite Dangerous — galaxy map |
| `ed-onfoot` | Elite Dangerous — on foot |
| `ed-srv` | Elite Dangerous — SRV |
| `msfs2024` | MSFS 2024 |
| `dcs-f16` | DCS World — F-16C |

## Rigs

- **vkb** — VKB Gladiator NXT Omni L + R (HOSAS). No keyboard in VR; all bindings on sticks/pedals. Full D1 modifier layer available. Available Aug/Sep 2026. Profile IDs: `ed-flight`, `ed-galmap`, `ed-onfoot`, `ed-srv`, `msfs2024`, `dcs-f16`.
- **boopidoo** — compact custom HOTAS (2× 3-axis sticks, 10 buttons, 4×4 keypad, HAT, 4-pos slide switch). Current primary rig. Data-driven JSON profiles with 4-mode keypad multiplexing. Profile IDs: `boopidoo-ed` (active), `boopidoo-msfs`/`boopidoo-dcs` (future).

---

## 6-Phase Agent Flow

### Phase 1 — ROUTE (inline, no subagent)

Parse from the user's question:
- `rig`: `vkb` | `boopidoo` | `both` — ask if ambiguous
- `game`: one or more profile IDs
- `intent`: `query` | `update`

For cross-game work (e.g. "map MSFS like ED"), set `game` to both profiles.

### Phase 2 — LOAD (Explore subagent)

Spawn an **Explore subagent** with a focused brief: read exactly the files listed below for this request and return a compact structured summary — field IDs mapped to actions, unmapped controls, available Joy_N slots. The subagent must NOT read `configmap.yml`.

Load:
- `tools/_index.json` — always
- `tools/{profile}.json` — for each game
- `tools/vkb_gladiator_{left,right}.csv` — if rig=vkb
- `tools/elite_dangerous_controls.csv` — only if the question is "what actions are available in ED?" (not needed for "what do I have mapped?")

The subagent returns:
1. Current mappings per hand (field ID → action) from each profile JSON
2. Unmapped VKB controls (in CSV but absent from profile JSON)
3. Joy_N gaps (integers in CSV not yet used in profile)

### Phase 3 — ADVISE (main context)

Using the Explore subagent's compact summary, answer the question or draft a proposed JSON diff.

For query-only tasks: **stop here**. No write, no further agents.

For update tasks: produce the proposed additions/changes as a JSON diff showing old and new values for affected fields only.

### Phase 4 — VALIDATE (claude subagent, update path only)

Spawn a **claude subagent** and give it:
- The proposed JSON changes (field ID → value pairs)
- The relevant CSV content (physical location → Joy_N mapping)
- The current profile JSON content

The subagent checks:

**a) Field ID validity** — every proposed key must match `{cluster}_{direction}_{col}` pattern. Valid clusters: `MT`, `A1`, `A2`, `A3`, `A4`, `B1`, `C1`, `D1`, `RFT`, `EN1`, `SW1`, `BASE`. Valid directions: `A`=up, `B`=down, `C`=left, `D`=right, `E`=push/center. Col `_1`=Joy_N (integer string), `_2`=action label. Axes use `AX_{name}` (no `_1`/`_2`).

**b) Joy_N uniqueness** — within a profile's `lh` or `rh` object, no two `_1` fields may hold the same integer. Cross-reference new `_1` values against existing ones in the profile.

**c) Schema validity** — profile JSON must have `name` (string), `version` (string), and at least one of `lh`/`rh` (objects). Every `_2` field should have a corresponding `_1` field (and vice versa) unless it's an axis.

**d) Layer-2 format** — `D1_A_2` must always be `"MODIFIER"`. Secondary (layer-2) bindings in `_2` fields are appended as `"Primary Action (JOY_N SECONDARY ACTION)"` where `JOY_N` is the integer and `SECONDARY ACTION` is uppercase. Example: `"Landing Gear (52 SHIP SPOTLIGHT)"`.

Returns: **PASS** or **FAIL** with a list of specific violations.

### Phase 5 — REVIEW (main context)

Show the user:
1. The proposed diff (field ID, old value → new value)
2. Validator result (PASS or FAIL+issues)
3. Optionally: other nearby unmapped controls that could be filled in the same pass

If FAIL: fix the issues and re-run Phase 4 before proceeding.

**Do not write anything until the user explicitly approves.**

### Phase 6 — WRITE (main context, approved only)

1. **Edit `tools/{profile}.json`** — apply the approved changes

2. **Surgically update `configmap.yml`** — the file has YAML block scalar keys in its `data:` section. Each profile is a key like:
   ```yaml
     ed-flight.json: |
       {
         "name": "ED — Ship Flight",
         ...
       }
   ```
   Locate the line `  {profile}.json: |` and replace the indented JSON block beneath it with the updated content. Stop at the next top-level key (next line starting with `  ` followed by a non-space). Do NOT touch the `index.html` key.

3. **New profile** — if the profile key doesn't exist in `configmap.yml` yet, add it at the end of the `data:` section (before any trailing `---`). Also update `_index.json` key in `configmap.yml` to include the new profile.

4. **Commit**: `git commit -m "hotas: {profile} — {one-line summary of what changed}"`

---

## Field ID reference (VKB Gladiator NXT Omni L/R)

### Left hand (lh)
| Cluster | Controls |
|---|---|
| `AX_X`, `AX_Y`, `AX_TWIST` | Main stick axes (lateral/ahead/vertical thrust) |
| `AX_THROTTLE` | F-throttle (rotZ) |
| `A1_X`, `A1_Y` | A1 ministick axes; `A1_E` = ministick push |
| `MT_A` | Main trigger |
| `A2_A` | A2 button |
| `A3_{A-E}` | A3 4-way hat (A=up, B=down, C=left, D=right, E=push) |
| `A4_{A-E}` | A4 4-way hat |
| `B1_A` | B1 button |
| `C1_{A-E}` | C1 5-way cluster |
| `D1_A` | D1 modifier toggle (always `"MODIFIER"`) |
| `RFT_{A,B}` | RF rocker (A=up, B=down) |
| `EN1_{A,B}` | Encoder 1 (A=CW/up, B=CCW/down) |
| `SW1_{A,B}` | SW1 rocker (A=up, B=down) |
| `BASE_{A,B,C}` | Base buttons (F1, F2/Pause, F3/OpenKneeboard reserved) |

### Right hand (rh)
Same cluster names; axes are `AX_X`=roll, `AX_Y`=pitch, `AX_TWIST`=yaw (if present).

---

## Boopidoo JSON schema (brief)

`tools/boopidoo-{game}.json` keys: `name`, `subtitle`, `version`, `modes[]`, `top_left[]`, `top_right[]`, `push_left`, `push_right`, `left_stick`, `right_stick`, `keypad[]`, `pov{}`, `switch_note`, `contexts[]`, `notes[]`.

Keypad entries use `"type": "mode"` (with `"modes": [T,E,M,C]` array) or `"type": "common"` (single `"fn"`). Empty mode slots are `""`.
Mode objects need `tag`, `name`, `legend`, `joy`, `pos`, `style` — where `style` must be `travel`, `explo`, `mining`, or `combat` to match existing CSS.
Color `cat` values: `flight`, `fire`, `ui`, `panel`, `power`.

When adding new profile: create `tools/boopidoo-{game}.json` + update `tools/_boopidoo_index.json` + add both as keys in `configmap.yml` data section.

---

## Deploy

ArgoCD watches this directory on the Hetzner cluster. Commit + push to `main` triggers automatic sync. No manual kubectl apply needed.

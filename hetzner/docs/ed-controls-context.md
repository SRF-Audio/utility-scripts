# ED Controls Hosting — Context & Status

<!--
AGENT INSTRUCTIONS
==================
This file is the live status tracker for the ED controls hosting project.
- Read this file FIRST before any work on this project.
- Then read ed-controls-plan.md (architecture) and ed-controls-tasks.md (execution).
- Update this file after every change — mark tasks complete, log decisions, flag issues.
- Do NOT touch status.md (that file tracks the Paperless-NGX migration project).
-->

Last updated: 2026-05-17 (plan revised to unified single-app approach; implementation not started)

---

## What This Project Is

Merge the Boopidoo HOTAS reference and the VKB Gladiator HOSAS kneeboard into a
**single unified web app** at `https://elite-controls.rohu-shark.ts.net`. View
switching is query-param based (`?view=boopidoo` / `?view=vkb&side=lh&profile=...`).
No new services, namespaces, or container image pipelines.

Hardware context:
- **Boopidoo** view: laptop rig, flatscreen, custom 6DOF compact HOTAS (current primary)
- **VKB HOSAS** view: PC VR rig (available ~Aug/Sep 2026), VKB Gladiator NXT Omni L+R + T-Rudder Mk V, PSVR2. Used via Open Kneeboard.

---

## Current Status

| Task | Description | Status |
|------|-------------|--------|
| 1 | Write unified `index.html` (Boopidoo + VKB combined) | NOT STARTED |
| 2 | Seed ED VR profiles (`ed-flight`, `ed-onfoot`, `ed-galmap`, `ed-srv`) | NOT STARTED |
| 3 | Update ConfigMap with unified HTML + all JSON files | NOT STARTED |
| 4 | Validation | NOT STARTED |

Tasks 1 and 2 are independent and can be done in parallel. Task 3 requires both 1 and 2.

---

## Key File Paths

### Source (develop here)
- `vkb_hosas/index.html` — unified app source (Task 1 output; replace current VKB-only version)
- `vkb_hosas/assets/fields.json` — VKB field coordinate data (read-only reference)
- `vkb_hosas/profiles/_index.json` — profile list (update in Task 2)
- `vkb_hosas/profiles/ed-vr.json` — rename to `ed-flight.json` in Task 2
- `vkb_hosas/profiles/msfs2024.json` — existing, carry over as-is
- `vkb_hosas/profiles/dcs-f16.json` — existing, carry over as-is

### Deployment target (copy content here after editing source)
- `hetzner/k8s/ed_hotas/configmap.yml` — Task 3 replaces this entirely

### Unchanged k8s files (do not touch)
- `hetzner/k8s/ed_hotas/deployment.yml`
- `hetzner/k8s/ed_hotas/service.yml`
- `hetzner/k8s/ed_hotas/ingress.yml`
- `hetzner/k8s/ed_hotas/namespace.yml`
- `hetzner/k8s/ed_hotas/kustomization.yml`
- `hetzner/argocd/apps/apps/ed-hotas.yml`

---

## Architecture Summary (decisions locked)

- **One deployment** (`ed-hotas`) serves everything — no new services or namespaces
- **ConfigMap** (`ed-hotas-html`) gets new keys: `index.html` (unified app), `fields.json`,
  `_index.json`, and one key per profile JSON — all flat at the nginx document root
- **PNGs** for VKB diagram backgrounds are fetched from `raw.githubusercontent.com` at
  runtime (static assets, no CORS restriction on `background-image`, user is always online)
- **View routing** is purely client-side: JS reads `?view` param on load and on popstate
- **Open Kneeboard** pins URLs like `?view=vkb&side=lh&profile=ed-flight`
- **No container image builds**, no CI/CD pipeline, no GHCR, no ExternalName proxy

---

## Plan Revision Log

### 2026-05-17 — Revised from two-app to unified single-app

Original plan (now scrapped):
- Two separate deployments (Boopidoo + VKB) in separate namespaces
- Container image build pipeline (GitHub Actions → GHCR) for VKB binary PNGs
- ExternalName proxy for cross-namespace ingress routing
- New ArgoCD Application for VKB

Reason for revision: unnecessarily complex. The only blocker was PNG assets; solving
it via GitHub raw eliminates all the complexity.

### 2026-05-17 — Initial planning session
- Analyzed existing Boopidoo deployment (ConfigMap-based nginx, `apps-ed-hotas`, Tailscale ingress)
- Analyzed VKB app structure (multi-file, binary PNGs, query-param routing, profile system)

---

## Irrelevant Docs (do not edit)

These docs are for the Paperless-NGX migration — separate project:
- `hetzner/docs/overview.md`
- `hetzner/docs/status.md`
- `hetzner/docs/migration-runbook.md`

After Task 2 (profile rename), update the "URLs" example in `vkb_hosas/README.md`
from `?profile=ed-vr` to `?profile=ed-flight`.

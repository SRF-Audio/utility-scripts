# ED Controls Hosting — Architecture Plan (Unified App)

<!--
AGENT INSTRUCTIONS
==================
Read all three ED controls docs before doing any work on this project:
  ed-controls-plan.md    (this file — architecture and decisions)
  ed-controls-tasks.md   (execution breakdown, one task per agent session)
  ed-controls-context.md (compacted context + current status)

Update ed-controls-context.md after any change. Update this file if you make
architectural decisions that differ from what is documented here.

Relevant repo paths:
  vkb_hosas/                         — VKB HOSAS web app source + profile JSONs
  hetzner/k8s/ed_hotas/              — k8s manifests (ConfigMap is the deployment target)
  hetzner/argocd/apps/apps/ed-hotas.yml — ArgoCD app (unchanged, no new app needed)
-->

## Goal

Serve a **single unified web app** from `https://elite-controls.rohu-shark.ts.net`
that covers both controller references in one page, with query-param routing between
views and hyperlinks between them. Open Kneeboard pins specific VKB diagram URLs.

| Query params | View |
|---|---|
| (none) or `?view=boopidoo` | Boopidoo HOTAS layout (laptop/flatscreen rig) |
| `?view=vkb` | VKB HOSAS diagram viewer — profile dropdown + side toggle |
| `?view=vkb&side=lh&profile=ed-flight` | Pin this in Open Kneeboard |
| `?view=vkb&side=rh&profile=ed-flight` | Pin this in Open Kneeboard |

---

## Why Unified is Simpler

The original plan deployed two separate apps in separate namespaces, requiring a
container image CI/CD pipeline (for the PNG diagram backgrounds), an ExternalName
proxy service for cross-namespace ingress routing, and a new ArgoCD Application.

The blocker was the two PNG diagram backgrounds (~630 KB total). The fix: reference
them from `raw.githubusercontent.com` instead of serving them from nginx. They're
already in the repo, they're essentially static (only change when VKB releases new
hardware), and `<img>` / CSS `background-image` loads have no CORS restrictions.
The user is online while playing Elite Dangerous, so this is a non-issue.

With PNGs external, **everything else is text** and fits in a ConfigMap trivially.

---

## Architecture

### What Does NOT Change

- `hetzner/k8s/ed_hotas/deployment.yml` — **unchanged**
- `hetzner/k8s/ed_hotas/service.yml` — **unchanged**
- `hetzner/k8s/ed_hotas/ingress.yml` — **unchanged**
- `hetzner/k8s/ed_hotas/namespace.yml` — **unchanged**
- `hetzner/argocd/apps/apps/ed-hotas.yml` — **unchanged** (no new ArgoCD app)
- All other cluster services (Paperless, Postgres, etc.) — **untouched**

### What Changes

- `hetzner/k8s/ed_hotas/configmap.yml` — replace the single `index.html` key with:
  - `index.html` — unified app (Boopidoo + VKB in one page)
  - `fields.json` — VKB field coordinate data
  - `_index.json` — VKB profile list
  - One key per VKB profile JSON (e.g., `ed-flight.json`, `ed-onfoot.json`, …)

- `vkb_hosas/index.html` — updated to be the unified app (source of truth)
- `vkb_hosas/profiles/` — profile JSONs renamed/added (source of truth)

### Deployment Model

```
ConfigMap: ed-hotas-html
├── index.html        → /usr/share/nginx/html/index.html
├── fields.json       → /usr/share/nginx/html/fields.json
├── _index.json       → /usr/share/nginx/html/_index.json
├── ed-flight.json    → /usr/share/nginx/html/ed-flight.json
├── ed-onfoot.json    → /usr/share/nginx/html/ed-onfoot.json
├── ed-galmap.json    → /usr/share/nginx/html/ed-galmap.json
├── ed-srv.json       → /usr/share/nginx/html/ed-srv.json
├── msfs2024.json     → /usr/share/nginx/html/msfs2024.json
└── dcs-f16.json      → /usr/share/nginx/html/dcs-f16.json

Deployment: ed-hotas (unchanged)
  nginx mounts ConfigMap at /usr/share/nginx/html/
  Serves all files with default nginx config — no custom config needed
```

The ConfigMap key names are flat (no slashes) because ConfigMap keys cannot contain
slashes. All files land at the nginx document root. The unified JS fetches resources
from flat paths (`fields.json`, `_index.json`, `${profileId}.json`) rather than the
subdirectory paths used in the original `vkb_hosas/index.html`.

---

## Unified `index.html` Design

### Navigation

A persistent header (same visual style as existing Boopidoo) with two links:

```
[ ELITE CONTROLS ]   [ Boopidoo HOTAS ]  [ VKB Gladiator ]
```

Clicking either link updates the URL via `history.pushState` and re-renders the view.
No page reload. Browser back/forward works. Bookmarks and Open Kneeboard URLs work.

### Boopidoo View (`?view=boopidoo` or no `?view`)

Renders the existing Boopidoo layout (currently 500+ lines of HTML in the ConfigMap).
Content is the same as the current page — no functional changes.

### VKB View (`?view=vkb`)

Renders the VKB diagram viewer (currently `vkb_hosas/index.html`). Key adaptations:
1. Profile JSONs and `fields.json` fetched from flat paths (no `profiles/` prefix).
2. PNG backgrounds fetched from GitHub raw:
   ```javascript
   const ASSET_BASE = 'https://raw.githubusercontent.com/SRF-Audio/utility-scripts/main/vkb_hosas/assets/';
   stage.style.backgroundImage = `url(${ASSET_BASE}${data.image})`;
   ```
3. When `?side` and `?profile` query params are present on page load, the VKB view
   initializes to those values (existing behavior from `vkb_hosas/index.html`).

### Query Param Routing

On page load and on popstate:
1. Read `?view` param.
2. If `view=vkb` (or `view` starts with `vkb`), show VKB section, hide Boopidoo.
3. Otherwise show Boopidoo, hide VKB.

The VKB section additionally reads `?side` and `?profile` to pin a specific view —
used by Open Kneeboard tabs.

---

## Profile Naming

ED VR profiles (VKB HOSAS, used in Open Kneeboard):

| Profile ID | Display Name | Open Kneeboard use |
|---|---|---|
| `ed-flight` | ED — Ship Flight | Primary flight tab (LH + RH) |
| `ed-onfoot` | ED — On Foot | Odyssey FPS tab |
| `ed-galmap` | ED — Galaxy Map | Navigation tab |
| `ed-srv` | ED — SRV | Ground vehicle tab |

Other games (in the profile dropdown, accessible from the VKB view, future tabs):

| Profile ID | Display Name |
|---|---|
| `msfs2024` | MSFS 2024 |
| `dcs-f16` | DCS F-16C |

`vkb_hosas/profiles/ed-vr.json` is renamed to `ed-flight.json`. The `"name"` field
is updated to `"ED — Ship Flight"`.

---

## Source of Truth

`vkb_hosas/` is the development source. `hetzner/k8s/ed_hotas/configmap.yml` is the
deployment target. They must be kept in sync manually:

- `vkb_hosas/index.html` → `configmap.yml` key `index.html`
- `vkb_hosas/assets/fields.json` → `configmap.yml` key `fields.json`
- `vkb_hosas/profiles/_index.json` → `configmap.yml` key `_index.json`
- `vkb_hosas/profiles/<id>.json` → `configmap.yml` key `<id>.json`

When updating, edit the source in `vkb_hosas/`, then copy the content into the
ConfigMap. ArgoCD picks up the diff on push and syncs.

### Adding a New Profile (ongoing workflow)

1. Create `vkb_hosas/profiles/<new-id>.json` with bindings.
2. Update `vkb_hosas/profiles/_index.json` to add the entry.
3. Add a new key to `hetzner/k8s/ed_hotas/configmap.yml` with the profile JSON.
4. Update the `_index.json` key in the ConfigMap to match.
5. Push to `main`. ArgoCD syncs — pod restarts with new profile available.

No image builds, no CI/CD pipeline, no container registry.

---

## Open Questions

- **GHCR / container image**: Not needed. Scrapped entirely.
- **ExternalName proxy**: Not needed. Scrapped entirely.
- **Multiple namespaces**: Not needed. Everything stays in `apps-ed-hotas`.
- **Tailscale proxy + path routing**: Not needed. Single path at `/`.
- **ConfigMap size**: The total ConfigMap will be under 100 KB (all text + JSON).
  Well within the 1 MB limit.
- **GitHub raw PNG latency**: Acceptable — these are static assets cached by the
  browser. On first load the user sees a brief blank diagram background while PNGs load.

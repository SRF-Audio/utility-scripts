# ED Controls Hosting — Execution Tasks

<!--
AGENT INSTRUCTIONS
==================
Each task is designed to be self-contained. Tasks 1 and 2 can be done in parallel.
Task 3 depends on Task 1 (needs the unified index.html to be written first).

Before starting, read:
  ed-controls-plan.md    — architecture, all design decisions
  ed-controls-context.md — current status (check which tasks are done)

After completing a task, update the status table in ed-controls-context.md.
Do NOT modify status.md (that file tracks the Paperless-NGX migration).
-->

---

## Task 1 — Write the Unified `index.html`

**File to create/replace**: `vkb_hosas/index.html`

Write a single HTML file that combines the Boopidoo HOTAS reference and the VKB
HOSAS diagram viewer into one page, switching between them with query params.

### Header (always visible)

A sticky header in the existing Boopidoo dark-theme style (background `#0e0e0e`,
border-bottom `#333`) with:
- Title: "ELITE CONTROLS" (JetBrains Mono, amber/orange)
- Two nav links: "Boopidoo HOTAS" and "VKB Gladiator" that set `?view=boopidoo`
  and `?view=vkb` respectively using `history.pushState`
- Active link highlighted with the amber accent color

### Boopidoo view (`?view=boopidoo` or no `?view` param)

Copy the entire Boopidoo layout from `hetzner/k8s/ed_hotas/configmap.yml` verbatim —
the `<style>` block, `<body>` content, and the zoom `<script>`. Do not alter any of
the binding data. Strip the outer `<!DOCTYPE>/<html>/<head>/<body>` wrappers since
they're now inside the unified document structure; move styles into the unified
`<style>` block (namespace with `.boopidoo-view` wrapper if there are any class name
conflicts with VKB styles).

### VKB view (`?view=vkb`)

Take the VKB viewer from the current `vkb_hosas/index.html`. Adapt it:

1. **Flat fetch paths** — the files are served from the document root, not subdirectories:
   - `fetch('assets/fields.json')` → `fetch('fields.json')`
   - `fetch('profiles/_index.json')` → `fetch('_index.json')`
   - `fetch(\`profiles/${profileId}.json\`)` → `fetch(\`${profileId}.json\`)`

2. **PNG backgrounds from GitHub raw**:
   ```javascript
   const ASSET_BASE = 'https://raw.githubusercontent.com/SRF-Audio/utility-scripts/main/vkb_hosas/assets/';
   // Use in render():
   stage.style.backgroundImage = `url(${ASSET_BASE}${data.image})`;
   ```

3. **URL state**: the VKB view reads `?side` and `?profile` from the URL on init (for
   Open Kneeboard pinning). When the user changes profile/side via the dropdowns, update
   the URL with `history.replaceState` preserving `?view=vkb` alongside `?side` and `?profile`.

### View switching JS

```javascript
function getView() {
  return new URLSearchParams(location.search).get('view') || 'boopidoo';
}

function showView(view) {
  document.getElementById('boopidoo-section').hidden = (view !== 'boopidoo');
  document.getElementById('vkb-section').hidden      = (view !== 'vkb');
  // update active nav link
}

// On load
showView(getView());
window.addEventListener('popstate', () => showView(getView()));
```

Nav links call `history.pushState({}, '', '?view=vkb')` then `showView('vkb')` — no
page reload.

### Important

The zoom script at the bottom of the Boopidoo section (`body.style.zoom = window.innerWidth / BASE`)
should only apply when the Boopidoo view is active, not when VKB is shown. Scope it to
apply/remove based on the current view.

---

## Task 2 — Seed ED VR Profiles

**Files to modify**: `vkb_hosas/profiles/`

1. Rename `ed-vr.json` → `ed-flight.json`. Update `"name"` to `"ED — Ship Flight"`.
   Update `"version"` if present.

2. Create `ed-onfoot.json` — On Foot / Odyssey FPS bindings for VKB HOSAS L+R.
   The LH stick handles movement (strafe = X, forward/back = Y, vertical = twist).
   The RH stick handles look (yaw = X, pitch = Y). Start from what is known; mark
   unknowns with an empty string or omit the key. Include `"version": "0.1-draft"` in
   the name until confirmed in-game.

3. Create `ed-galmap.json` — Galaxy Map mode. Most axes are unused; focus on hat/button
   bindings for map navigation. Start minimal; draft is fine.

4. Create `ed-srv.json` — SRV mode bindings. Reference the SRV Context table in the
   Boopidoo layout (in `hetzner/k8s/ed_hotas/configmap.yml`) for what actions exist,
   then map them to VKB controls as best known.

5. Update `vkb_hosas/profiles/_index.json`:
   ```json
   { "profiles": [
     { "id": "ed-flight", "name": "ED — Ship Flight" },
     { "id": "ed-onfoot", "name": "ED — On Foot" },
     { "id": "ed-galmap", "name": "ED — Galaxy Map" },
     { "id": "ed-srv",    "name": "ED — SRV" },
     { "id": "msfs2024",  "name": "MSFS 2024" },
     { "id": "dcs-f16",   "name": "DCS F-16C" }
   ]}
   ```

---

## Task 3 — Update the ConfigMap

**Prerequisite**: Tasks 1 and 2 complete and committed.

**File to replace**: `hetzner/k8s/ed_hotas/configmap.yml`

Replace the current single-key ConfigMap with a multi-key ConfigMap. The ConfigMap name
stays `ed-hotas-html` so no deployment change is needed.

Structure:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ed-hotas-html
  namespace: apps-ed-hotas
  labels:
    app.kubernetes.io/name: ed-hotas
    app.kubernetes.io/component: webserver
    app.kubernetes.io/managed-by: argocd
data:
  index.html: |
    <full content of vkb_hosas/index.html>
  fields.json: |
    <full content of vkb_hosas/assets/fields.json>
  _index.json: |
    <full content of vkb_hosas/profiles/_index.json>
  ed-flight.json: |
    <full content of vkb_hosas/profiles/ed-flight.json>
  ed-onfoot.json: |
    <full content of vkb_hosas/profiles/ed-onfoot.json>
  ed-galmap.json: |
    <full content of vkb_hosas/profiles/ed-galmap.json>
  ed-srv.json: |
    <full content of vkb_hosas/profiles/ed-srv.json>
  msfs2024.json: |
    <full content of vkb_hosas/profiles/msfs2024.json>
  dcs-f16.json: |
    <full content of vkb_hosas/profiles/dcs-f16.json>
```

Each value is the **exact file content** copied verbatim from the source files.

The nginx-unprivileged container mounts this ConfigMap at `/usr/share/nginx/html/`
(already configured in `deployment.yml`). All keys become files at the document root.
No deployment changes needed.

---

## Task 4 — Validation

After Task 3 is pushed and ArgoCD syncs (verify in ArgoCD UI or with
`kubectl --context hetzner -n apps-ed-hotas get pods`):

- [ ] `https://elite-controls.rohu-shark.ts.net/` loads Boopidoo view by default
- [ ] Nav link "VKB Gladiator" switches to the VKB diagram viewer (no page reload)
- [ ] Nav link "Boopidoo HOTAS" switches back
- [ ] `?view=vkb&side=lh&profile=ed-flight` in URL loads LH diagram with flight bindings
- [ ] `?view=vkb&side=rh&profile=ed-flight` loads RH diagram
- [ ] Profile dropdown shows all 6 profiles from `_index.json`
- [ ] Browser back/forward navigates between views correctly
- [ ] Open Kneeboard test: pin `?view=vkb&side=lh&profile=ed-flight` as a tab

---

## Adding a New Profile (ongoing workflow, post-deployment)

1. Create `vkb_hosas/profiles/<id>.json`
2. Update `vkb_hosas/profiles/_index.json`
3. Add the new key to `hetzner/k8s/ed_hotas/configmap.yml` (copy JSON content verbatim)
4. Update the `_index.json` key in the ConfigMap to match
5. Push → ArgoCD syncs → pod restarts → new profile in dropdown

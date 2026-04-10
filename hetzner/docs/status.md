# Hetzner Migration Status

<!--
AGENT INSTRUCTIONS
==================
This is the live status file for the Hetzner migration project.
- Read all three docs (overview.md, status.md, migration-runbook.md) before any work.
- Update this file after EVERY change — phases, fixes, decisions, open issues.
- Keep the Change Log section up to date with date and summary of what changed.
- When an open issue is resolved, move it from "Open Issues" to the Change Log.
-->

Last updated: 2026-04-10

---

## Phase 0 — Planning & Configuration (COMPLETE)

- [x] Research existing homelab deployment model
- [x] Define Hetzner target architecture
- [x] Create `hetzner/` directory structure
- [x] Write docs (overview, status, migration runbook)
- [x] Create ArgoCD projects (`hetzner-infra`, `hetzner-apps`, `hetzner-db`)
- [x] Create ArgoCD root app (`hetzner/argocd/root.yml`)
- [x] Create ArgoCD operator apps (Tailscale operator + secrets)
- [x] Create ArgoCD platform apps (cluster-primitives, Postgres, Redis + secrets)
- [x] Create ArgoCD app-layer apps (Paperless-NGX + secrets)
- [x] Create Hetzner cluster primitives (local-path StorageClasses + config)
- [x] Create Hetzner Paperless-NGX k8s manifests (Hetzner-specific PVCs + webserver)
- [x] Create Ansible bootstrap playbook and inventory
- [x] Fix kubectl context name (`hetzner_context: hetzner`)
- [x] Add `hetzner/ansible/ansible.cfg` with correct roles path
- [x] Decide and implement URL strategy (see overview.md — `-hetzner` suffix during migration)
- [x] Update Paperless-NGX to use `paperless-hetzner.rohu-shark.ts.net`
- [x] Create `hetzner/k8s/argocd/` — ArgoCD config overrides (URL, insecure mode, ingress)
- [x] Wire ArgoCD overrides into bootstrap playbook

---

## Phase 1 — Provision Hetzner Server (AUTOMATED — run site.yml)

- [ ] Create Hetzner Cloud project (manual — one-time, then add API token to 1Password)
- [ ] Add required 1Password items to HomeLab vault (see site.yml header comments)
- [ ] Run `ansible-playbook -i inventory/hetzner.yml site.yml --tags provision`
      — Uploads SSH key from 1Password to Hetzner Cloud
      — Creates Cloud Firewall (TCP 22 + UDP 41641 inbound only)
      — Provisions CAX31 server with Ubuntu 24.04
      — Creates + attaches 500 GB block volume
      — Updates inventory/hetzner.yml with real IP automatically
- [ ] Run `ansible-playbook -i inventory/hetzner.yml site.yml --tags bootstrap`
      — Hardens sshd (key-only, no passwords)
      — Installs Tailscale and joins tailnet with tag:k8s, tag:server-apps
      — Mounts volume, installs k3s, deploys ArgoCD stack

---

## Phase 2 — Bootstrap k3s and ArgoCD Stack (TODO)

- [ ] Run bootstrap: `cd hetzner/ansible && ansible-playbook -i inventory/hetzner.yml site.yml`
  - Mounts Hetzner volume at `/mnt/hetzner-volume`
  - Installs k3s single-node (context: `hetzner` added to `~/.kube/config`)
  - Deploys ArgoCD + applies Hetzner ArgoCD overrides (URL, insecure mode, ingress)
  - Deploys 1Password Operator
  - Registers GitHub repo with ArgoCD
  - Applies `hetzner/argocd/root.yml` — ArgoCD syncs all apps via waves
- [ ] Verify ArgoCD is accessible at `https://argocd-hetzner.rohu-shark.ts.net`
  - Admin password: `kubectl --context hetzner -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`
- [ ] Verify 1Password Operator is running and syncing secrets
- [ ] Verify Tailscale Operator is running
- [ ] Verify Postgres and Redis are healthy
- [ ] Paperless pod may be in CrashLoop (no data yet — expected, proceed to Phase 3)

---

## Phase 3 — Migrate Paperless-NGX Data (TODO)

See `migration-runbook.md` for full step-by-step procedure.

- [ ] Take Synology NAS snapshot
- [ ] Scale down Paperless-NGX on homelab to 0 replicas
- [ ] Export PostgreSQL dump from homelab
- [ ] Archive paperless volumes from homelab PVCs (data, media, export)
- [ ] Scale down Paperless-NGX on Hetzner
- [ ] Restore archives to Hetzner PVCs via writer pod
- [ ] Restore PostgreSQL dump on Hetzner
- [ ] Scale up Paperless-NGX on Hetzner

---

## Phase 4 — Validation (TODO)

- [ ] Verify Paperless accessible at `https://paperless-hetzner.rohu-shark.ts.net`
- [ ] Confirm document count matches homelab
- [ ] Test document search and OCR
- [ ] Test document ingestion (consume folder)
- [ ] All ArgoCD apps green on Hetzner

---

## Phase 4b — Cutover to Production Hostname (TODO)

When validation passes, rename Paperless from `-hetzner` to production URL:

- [ ] Update `hetzner/k8s/paperless_ngx/configmap.yml` — `PAPERLESS_URL`
- [ ] Update `hetzner/k8s/paperless_ngx/ingress.yml` — `host` and `tls.hosts`
- [ ] Push to `main` — ArgoCD syncs automatically (~3 min)
- [ ] Confirm `https://paperless.rohu-shark.ts.net` routes to Hetzner
- [ ] Scale down homelab Paperless-NGX permanently

---

## Phase 5 — Migration Back to Homelab (FUTURE)

When returning to hardware, reverse the process:

- [ ] Provision homelab cluster (existing Ansible playbooks in `ansible/`)
- [ ] Dump Postgres from Hetzner, archive media back to Synology
- [ ] Bootstrap homelab ArgoCD stack (existing `coachlight-infra-stack.yml`)
- [ ] Restore data on homelab
- [ ] Decommission Hetzner server and block volume

---

## Open Issues

None blocking. All known issues have been resolved or have an accepted approach.

---

## Change Log

### 2026-04-10 (IaC provisioning)

- **Implemented: Phase 1 IaC** — Three new Ansible roles in `hetzner/ansible/roles/`:
  - `hetzner_provision` — creates SSH key resource, Cloud Firewall (TCP 22 + UDP 41641 only),
    CAX31 server with Fedora 43 (ARM64), 500 GB volume, and updates the inventory file with
    the real IP.
  - `hetzner_harden` — writes `/etc/ssh/sshd_config.d/99-harden.conf` drop-in (no password
    auth, key-only). Asserts `authorized_keys` is non-empty before hardening to prevent lockout.
  - `hetzner_tailscale_setup` — installs Tailscale, runs `tailscale up` with `tag:k8s` and
    `tag:server-apps`. OS-agnostic (no Debian assertion unlike proxmox_tailscale_setup).
- **Updated: ansible.cfg** — `roles_path = roles:../../ansible/roles` so hetzner-specific
  roles are found first; shared roles from `ansible/roles/` are the fallback.
- **Updated: hetzner-bootstrap.yml** — volume ID and API server URL now derived from
  `hetzner_provision_artifacts` (falls back to REPLACE_WITH_* placeholders for standalone runs).
  SSH hardening and Tailscale setup added as roles before the volume/k3s tasks. All 1Password
  lookups done directly inline (no intermediary set_fact).
- **Updated: site.yml** — just imports provision + bootstrap playbooks. Each playbook fetches
  its own secrets directly via the 1Password lookup plugin.
- **Created: hetzner/ansible/requirements.yml** — `hetzner.hcloud` collection (isolated from
  the shared ansible/requirements.yml).
- **Updated: inventory/hetzner.yml** — SSH key path set to `~/.ssh/coachlight-homelab.pem`.

### 2026-04-10

- **Identified and fixed: kubectl context name mismatch** — Bootstrap playbook had
  `hetzner_context: default`, which would have named the kubeconfig context `"default"`
  instead of `"hetzner"`. Every `--context hetzner` command in the runbook would have
  failed. Fixed to `hetzner_context: hetzner`.

- **Identified and fixed: Ansible roles path** — No `ansible.cfg` existed where the
  bootstrap would be run from, so roles under `ansible/roles/` would not be found.
  Added `hetzner/ansible/ansible.cfg` with `roles_path = ../../ansible/roles`. Updated
  usage comments to run from `hetzner/ansible/`.

- **Decided: URL strategy** — Use `-hetzner` suffix for both services during migration
  so both clusters can run in parallel for safe validation. Rename Paperless to the
  production hostname at cutover (Phase 4b). ArgoCD keeps `argocd-hetzner` permanently
  (different cluster, different ops tool). See overview.md for full rationale.

- **Implemented: Paperless-NGX `-hetzner` hostname** — Updated
  `hetzner/k8s/paperless_ngx/configmap.yml` and `ingress.yml` to use
  `paperless-hetzner.rohu-shark.ts.net`.

- **Resolved: ArgoCD URL and OAuth** — The `argocd_deploy` Ansible role template
  hardcodes the homelab ArgoCD URL and GitHub OAuth/Dex config. Resolved by creating
  `hetzner/k8s/argocd/` with three manifests applied by the bootstrap playbook
  immediately after `argocd_deploy`:
  - `argocd-cm.yml` — sets `argocd-hetzner` URL, removes Dex config
  - `argocd-cmd-params-cm.yml` — enables insecure mode (HTTP/80 for Tailscale ingress)
  - `ingress.yml` — Tailscale Operator ingress for `argocd-hetzner.rohu-shark.ts.net`

- **Resolved: Missing ArgoCD ingress** — Created `hetzner/k8s/argocd/ingress.yml`.
  Applied by Ansible bootstrap (not managed by ArgoCD itself, to avoid self-referential
  GitOps bootstrap problem).

- **Docs overhauled** — All three docs rewritten to be accurate, complete, and
  agent-ready with embedded instructions for future agents picking up the work.

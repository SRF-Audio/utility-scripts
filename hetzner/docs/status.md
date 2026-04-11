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

Last updated: 2026-04-11 (bootstrap in progress — stopped at volume format; see Open Issues)

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

## Phase 1 — Provision Hetzner Server (COMPLETE)

- [x] Create Hetzner Cloud project + API token → stored in 1Password as `Hetzner → api_token`
- [x] Add required 1Password items to HomeLab vault
- [x] Provision run succeeded (localhost: ok=17, changed=9)
      — SSH key uploaded to Hetzner Cloud
      — Cloud Firewall created (TCP 22 + UDP 41641 inbound only)
      — CAX31 server provisioned with Fedora 43 ARM64
      — 500 GB block volume created and attached
      — inventory/hetzner.yml updated with real IP (178.104.100.13)

---

## Phase 2 — Bootstrap k3s and ArgoCD Stack (IN PROGRESS)

**Stopped at:** volume format — see Open Issues (BOOT-1).

Completed so far (ok=33 on hetzner_node):

- [x] SSH hardening applied (key-only, sshd drop-in config)
- [x] Tailscale installed and joined tailnet (`hetzner-node`, tag:k8s, tag:server-apps)
- [ ] **BLOCKED** Format + mount Hetzner volume (BOOT-1)
- [ ] Install k3s single-node
- [ ] Fetch + merge kubeconfig (context: `hetzner`)
- [ ] Deploy ArgoCD + apply Hetzner overrides
- [ ] Deploy 1Password Operator
- [ ] Register GitHub repo with ArgoCD
- [ ] Apply `hetzner/argocd/root.yml` — ArgoCD syncs all apps

**To resume:** Fix BOOT-1 (see Open Issues), then run the full `site.yml` (not `--tags bootstrap`
alone) so provision artifacts are in memory and `hetzner_volume_id` resolves correctly:

```bash
cd hetzner/ansible && ansible-playbook -i inventory/hetzner.yml site.yml
```

- [ ] Verify ArgoCD is accessible at `https://argocd-hetzner.rohu-shark.ts.net`
  - Admin password: `kubectl --context hetzner -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`
- [ ] Verify 1Password Operator is running and syncing secrets
- [ ] Verify Tailscale Operator is running
- [ ] Verify Postgres and Redis are healthy
- [ ] Paperless pod may be in CrashLoop (no data yet — expected, proceed to Phase 3)

---

## Phase 2b — Bootstrap k3s and ArgoCD Stack — original checklist (TODO)

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

### BOOT-1 — Volume ID not resolved when bootstrap runs without provision (BLOCKING)

**File:** `hetzner/ansible/playbooks/hetzner-bootstrap.yml`

`hetzner_volume_id` is sourced from `hostvars['localhost']['hetzner_provision_artifacts']['volume_id']`,
which is only populated when the provision play runs in the same Ansible process. When running
`--tags bootstrap` alone (e.g. to retry after a failure), the hostvars aren't populated and the
variable falls back to the `REPLACE_WITH_VOLUME_ID` sentinel, causing `mkfs.ext4` to fail.

**Fix options:**

1. **Always run full `site.yml`** — provision is idempotent (server/volume already exist, Hetzner
   API will no-op). This is the simplest fix and the recommended approach going forward.

2. **Read volume ID from the artifacts file** — the provision role writes `.artifacts/hetzner_provision.json`.
   Add a pre-task in the bootstrap play to read this file and set the fact when `hetzner_provision_artifacts`
   is not already populated. More complex but enables true `--tags bootstrap` re-runs.

**Recommended action:** Use option 1 for now (run `site.yml` without tags). Document option 2 as a
future improvement if re-runs become painful.

---

## Change Log

### 2026-04-11 (first live bootstrap attempt — Phase 1 complete, Phase 2 in progress)

**Phase 1 complete:** Server provisioned successfully (178.104.100.13), SSH key uploaded,
firewall created, 500 GB volume attached, inventory updated with real IP.

Bugs encountered and fixed during bootstrap run:

- **Fixed: SSH agent** — Ansible wasn't picking up `~/.ssh/config` `IdentityAgent` setting.
  Added `-o IdentityAgent=~/.1password/agent.sock` explicitly to `ansible_ssh_common_args`
  in `inventory/hetzner.yml`.
- **Fixed: Recursive template loop** — `artifacts_path | default(...)` in role defaults caused
  Ansible argument spec validation to recurse infinitely. Fixed in all three hetzner role
  defaults (`hetzner_tailscale_setup`, `hetzner_provision`, `hetzner_harden`) by removing
  the `artifacts_path` indirection and using `playbook_dir ~ '/.artifacts'` directly.
- **Open: BOOT-1** — Volume ID not resolved on `--tags bootstrap` re-runs. Bootstrap stopped
  at `mkfs.ext4` with `REPLACE_WITH_VOLUME_ID`. Fix: run full `site.yml` next time.

Bootstrap progress before stopping: SSH hardening ✓, Tailscale installed and on tailnet ✓,
volume format ✗ (BOOT-1).

### 2026-04-11 (all audit issues fixed — ready for Phase 1)

Applied all code-level fixes from the 2026-04-10 audit:

- **Fixed HIGH-1** (`hetzner-bootstrap.yml`) — Second play now uses Tailscale IPv4
  (`hostvars['hetzner_node']['hetzner_tailscale_setup_artifacts']['tailscale_ip_v4']`)
  for `hetzner_api_server` instead of the public IP. Port 6443 is firewalled so kubectl
  operations would have timed out without this fix.
- **Fixed HIGH-2** (`hetzner-bootstrap.yml`) — Added `Restrict SSH firewall rule to
  Tailscale CIDR` task (delegated to localhost, `become: false`) after k3s is up.
  SSH is now restricted to `100.64.0.0/10` once Tailscale is active.
- **Fixed HIGH-3** (`hetzner-bootstrap.yml`) — Kubeconfig fetched to
  `~/.kube/hetzner-k3s.yaml` (not `/tmp`) with a follow-up `file` task setting `0600`.
- **Fixed MEDIUM-1** (`hetzner_tailscale_setup/tasks/main.yml`) — Added `| default([])`
  guard to both `TailscaleIPs` extractions to prevent Jinja2 undefined errors.
- **Fixed MEDIUM-2** (`hetzner-bootstrap.yml`) — k3s shell task now uses
  `set -euo pipefail` and `executable: /bin/bash` so a failed `curl` is fatal.
- **Fixed MEDIUM-3** (`hetzner_provision/tasks/main.yml`) — Replaced overly-broad
  `ansible.builtin.replace` with `ansible.builtin.lineinfile` (scoped regexp) for
  inventory IP update.
- **Fixed LOW-1** (`hetzner-bootstrap.yml`) — `blkid` and `mkfs.ext4` now use full
  `/usr/sbin/` paths.

### 2026-04-10 (security and correctness audit)

Full audit of Ansible roles and playbooks. Findings added to Open Issues above.
Doc-only fixes applied immediately:

- **Fixed: overview.md OS entry** — changed "Fedora/Ubuntu" to "Fedora 43 ARM64".
- **Fixed: overview.md Networking section** — added explicit note that the kubeconfig
  must use the Tailscale IPv4 address (not the public IP) because port 6443 is
  firewalled. Describes how the bootstrap playbook should source the IP from
  `hetzner_tailscale_setup_artifacts`.
- **Fixed: migration-runbook.md dump validation** — added `head | grep` check after
  `pg_dump` to abort if the file is not a valid PostgreSQL dump (LOW-2, now closed).
- **Fixed: migration-runbook.md PostgreSQL image tag** — replaced the `:latest`
  guidance with a pre-flight command to pin the exact image tag from the running
  homelab pod, ensuring dump/restore compatibility (MEDIUM-4, now documented).
- **Fixed: overview.md table alignment** — removed stale "(→ prod at cutover)" inline
  note from Key Differences table (covered in URL Strategy section). Corrected blank
  lines around subheadings.

Remaining open issues (HIGH-1 through MEDIUM-3, LOW-1) require code changes to
Ansible roles/playbooks — see Open Issues section for exact fix steps.

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

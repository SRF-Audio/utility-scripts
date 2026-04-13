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

Last updated: 2026-04-13 (Phase 3 runbook — four additional fixes applied, ready to execute)

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

## Phase 2 — Bootstrap k3s and ArgoCD Stack (COMPLETE)

Bootstrap run completed successfully on 2026-04-12. All ArgoCD apps Synced + Healthy.

- [x] SSH hardening applied (key-only, sshd drop-in config)
- [x] Tailscale installed and joined tailnet (`hetzner-node`, tag:k8s, tag:server-apps)
- [x] Format + mount Hetzner volume
- [x] k3s v1.32.3+k3s1 installed single-node, Tailscale IP SAN in TLS cert
- [x] kubeconfig fetched, server URL patched, merged to `~/.kube/config` (context: `hetzner`)
- [x] kubeconfig saved to 1Password (`Hetzner k3s Kubeconfig`, HomeLab vault)
- [x] ArgoCD deployed + Hetzner overrides applied (insecure mode, argocd-hetzner hostname, no Dex)
- [x] hetzner-infra AppProject applied directly (bootstrap prerequisite for 1Password Operator)
- [x] 1Password Operator deployed and healthy (`infra-1password-operator` namespace)
- [x] GitHub repo registered with ArgoCD (SSH deploy key via 1Password)
- [x] Root ArgoCD Application applied — all apps synced via waves

**Verified cluster state (2026-04-12):**

| ArgoCD Application            | Sync     | Health  |
|-------------------------------|----------|---------|
| root                          | Synced   | Healthy |
| 1password-operator            | Synced   | Healthy |
| cluster-primitives            | Synced   | Healthy |
| tailscale-operator            | Synced   | Healthy |
| tailscale-operator-secrets    | Synced   | Healthy |
| postgres                      | Synced   | Healthy |
| paperless-ngx-postgres-secrets| Synced   | Healthy |
| redis                         | Synced   | Healthy |
| paperless-ngx-redis-secrets   | Synced   | Healthy |
| paperless-ngx                 | Synced   | Healthy |
| paperless-ngx-app-secrets     | Synced   | Healthy |

All pods Running. Paperless-NGX webserver is up at `https://paperless-hetzner.rohu-shark.ts.net`
but has **no data** — empty Postgres database, no documents. Phase 3 migrates the data.

**PostgreSQL version on Hetzner: 17.5.** Use `bitnamilegacy/postgresql:latest` for temp
pg_dump/pg_restore pods — both clusters run the identical image digest
(`sha256:42a8200d...`), so compatibility is guaranteed. See migration-runbook.md Steps 2 and 4d.

---

## Phase 3 — Migrate Paperless-NGX Data (READY TO EXECUTE)

Full step-by-step commands are in `migration-runbook.md`. This section is the progress
tracker — check off items as you go.

**Before starting:** Confirm you have both kubectl contexts (`coachlight-k3s-cluster` and
`hetzner`) and Tailscale active on your machine.

**Pre-migration verification (confirmed 2026-04-13):**

- [x] kubectl context for homelab is `coachlight-k3s-cluster` (NOT `homelab`)
- [x] All Hetzner ArgoCD apps Synced + Healthy (re-verified 2026-04-13 — still all green)
- [x] Homelab Paperless-NGX running: webserver + gotenberg + tika all Running (103d uptime)
- [x] Both clusters run identical PostgreSQL image (same SHA256: `42a8200d...`) — no version issue
- [x] Data sizes confirmed: data=313MB, media=646MB, export=~0, consume=115MB (~1.1GB total)
- [x] PVC names, secret names, and service hostnames confirmed matching runbook
- [x] **CRITICAL**: Both ArgoCD apps have `selfHeal: true` — must disable auto-sync before
      scaling down (runbook Step 1 and Step 4a now include this fix)

**Migration steps (see migration-runbook.md for full commands):**

- [ ] Take Synology NAS snapshot (before touching anything)
- [ ] Step 1 — Disable ArgoCD auto-sync on homelab; scale down to 0 replicas (quiesce writes)
- [ ] Step 2 — Export PostgreSQL dump from homelab to `/tmp/paperless-YYYYMMDD-HHMM.sql`
              — verify dump is non-empty and is a valid PostgreSQL dump header
- [ ] Step 3 — Archive Paperless volumes from homelab PVCs (data, media, export, consume)
              — via reader pod + `tar czf` piped to local `/tmp/paperless-*.tar.gz`
              — Expected total: ~1.1 GB
- [ ] Step 4a — Disable ArgoCD auto-sync on Hetzner; scale down Paperless-NGX
- [ ] Step 4b — Create writer pod on Hetzner with all PVCs mounted
- [ ] Step 4c — Push data archives to Hetzner PVCs (`tar xzf` via writer pod)
- [ ] Step 4d — Restore PostgreSQL dump on Hetzner (temp psql pod)
- [ ] Step 5 — Re-enable ArgoCD auto-sync on Hetzner; scale up Paperless-NGX
- [ ] Step 5 — Tail logs and confirm Paperless starts cleanly (no migration errors)

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

None. Phase 3 runbook is audited and corrected. Ready to execute.

---

## Change Log

### 2026-04-13 (Phase 3 runbook — four additional fixes applied)

- **Fixed RUN-4: status.md PostgreSQL image note contradicted runbook** — The Phase 2 section
  said to use `bitnami/postgresql:17.5.0` for temp pods, but the runbook correctly uses
  `bitnamilegacy/postgresql:latest` (per the RUN-2 fix). Updated status.md to match.
- **Fixed RUN-5: `$DUMP_FILE` shell variable not resilient across sessions** — Step 4d
  previously relied on `$DUMP_FILE` being set in the same shell session as Step 2. Added a
  fallback: `DUMP_FILE="${DUMP_FILE:-$(ls -t /tmp/paperless-*.sql | head -1)}"` with an
  explicit abort if no dump file is found, so a new terminal or accidental close doesn't
  silently restore nothing.
- **Fixed RUN-6: no database integrity check after psql restore** — Added a post-restore
  `SELECT COUNT(*) FROM documents_document` check in Step 4d. The step now aborts if the
  table is empty after restore, preventing a silent data-loss scenario.
- **Fixed RUN-7: Synology snapshot was checklist-only, not a runbook step** — Added Step 0
  to migration-runbook.md with `synodiskutil snapshotpair take` command and a DSM UI
  fallback. The step explicitly blocks progress until the snapshot is confirmed.

### 2026-04-13 (Phase 3 runbook audit — three bugs fixed, ready to execute)

Pre-migration research on both live clusters revealed three bugs in the runbook:

- **Fixed RUN-1: wrong kubectl context name** — runbook used `--context homelab` throughout,
  but the actual context name for the homelab cluster is `coachlight-k3s-cluster`. Fixed in
  every step of the runbook.
- **Fixed RUN-2: wrong PostgreSQL image name** — Steps 2 and 4d used `bitnami/postgresql:latest`
  for temp pods, but both clusters run `bitnamilegacy/postgresql:latest`. Both clusters were
  confirmed to be running the exact same image digest (`sha256:42a8200d...`), so
  `pg_dump`/`pg_restore` compatibility is guaranteed. Fixed image name in both steps.
- **Fixed RUN-3: ArgoCD selfHeal not addressed** — Both ArgoCD applications have
  `selfHeal: true` and `automated.prune: true`. A bare `kubectl scale --replicas=0` would
  be reverted by ArgoCD within seconds. Added `kubectl patch application` commands to
  disable auto-sync before each scale-down (Step 1 for homelab, Step 4a for Hetzner), and
  re-enable it after scale-up (Step 5 for Hetzner). Rollback procedure also updated.

Other findings (no changes needed):

- consume volume (115MB) was not included in archive list — added it to Step 3.
- Data sizes: data=313MB, media=646MB, export=~0, consume=115MB (~1.1 GB total).

### 2026-04-12 (Phase 2 COMPLETE — bootstrap run succeeded, all apps healthy)

Full `site.yml` run completed successfully. All 11 ArgoCD Applications Synced + Healthy.
All pods Running. Paperless-NGX webserver is up at `paperless-hetzner.rohu-shark.ts.net`
with an empty database. PostgreSQL 17.5, Redis healthy. Stopping for the night.
Phase 3 (data migration) is next — see Phase 3 section above for the starting checklist.

### 2026-04-12 (BOOT-8 fix — argocd_github_repo_create CRD ordering)

- **Fixed BOOT-8: argocd_github_repo_create fails with missing OnePasswordItem CRD** —
  The `argocd_github_repo_create` role checks for `onepassworditems.onepassword.com` CRD
  before creating an `OnePasswordItem` resource to retrieve the GitHub deploy key. The CRD
  only exists after the 1Password Operator is deployed, but `onepassword_operator_deploy`
  was ordered AFTER `argocd_github_repo_create` due to the incorrect BOOT-3 reasoning.
  **Root cause**: The BOOT-3 comment claimed ArgoCD can't sync the 1Password Operator app
  until the GitHub SSH repo is registered — but the `onepassword_operator_deploy` ArgoCD
  Application uses a **public Helm repo** (`https://1password.github.io/connect-helm-charts/`),
  not the private GitHub repo. The only real prerequisite is the `hetzner-infra` AppProject.
  **Fix**: Added a `k8s_object_manager` step to apply `hetzner-infra-project.yml` directly
  (no ArgoCD sync needed — just `kubectl apply`), then moved `onepassword_operator_deploy`
  before `argocd_github_repo_create`. The operator deploys via ArgoCD (Helm repo is public,
  project now exists), waits up to 5 min for deployments, and then `argocd_github_repo_create`
  runs with the CRD available. `root.yml` is applied last with the GitHub SSH repo registered.

### 2026-04-12 (BOOT-5, BOOT-6, BOOT-7 fixes — k3s TLS, collection path, argocd Dex)

- **Fixed BOOT-5: k3s TLS cert missing Tailscale SAN** — The bootstrap playbook rewrites the
  kubeconfig server URL from `127.0.0.1` to the Tailscale IP, but the k3s serving cert was never
  issued with that IP as a SAN. Fixed in two ways:
  - **Immediate (manual):** On `hetzner-node`, wrote `/etc/rancher/k3s/config.yaml` with
    `tls-san: [100.91.201.40]`, deleted the old serving cert, restarted k3s.
  - **Playbook fix:** Added a "Get Tailscale IP" task before k3s install; `--tls-san` is now
    passed to the install command so future installs are correct from the start.
- **Fixed BOOT-6: hetzner.hcloud collection installed to system Python, not user path** —
  `ansible-galaxy collection install -r requirements.yml --force` reinstalled the collection
  to `~/.ansible/collections` (6.8.0). Also fixed root cause: the initial install was missing
  `-r`, treating the filename as a collection name.
- **Fixed BOOT-7: argocd_deploy Dex template fails on Hetzner** — The `argocd_deploy` role
  unconditionally renders `argocd-config-patch.yml.j2`, which requires `argocd_github_oauth_client_id`.
  Hetzner intentionally has no Dex/GitHub OAuth (managed separately via `hetzner/k8s/argocd/argocd-cm.yml`).
  Added `argocd_deploy_configure_dex` flag (default `true`, preserves homelab behavior). Set to
  `false` in the Hetzner bootstrap.
- **Added: SSH config entry** — Bootstrap playbook now writes a `hetzner-node` entry to
  `~/.ssh/config` (via `blockinfile`) after the Tailscale IP is resolved. `ssh hetzner-node`
  now works after bootstrap runs.

### 2026-04-11 (BOOT-4 fix — k8s_validator sudo on localhost)

- **Fixed: k8s_validator fails with `sudo: a password is required` on localhost** —
  The role's package install tasks (python3, python3-pip via `package` module, and
  kubernetes library via `pip`) all use `become: true`. On the Fedora 43 control machine,
  sudo requires a password, so they fail. Python3 is already present on the control
  machine; the kubernetes library was presumably installed in a prior session.
  - Added `k8s_validator_install_packages: true` default to the role. When `false`,
    all three package install tasks are skipped.
  - Set `k8s_validator_install_packages: false` in the hetzner-bootstrap.yml pre_task
    import.

### 2026-04-11 (BOOT-3 fix — Tailscale IP, k3s_cluster_domain, role execution order)

- **Fixed: hetzner_tailscale_ip always empty** — `hostvars['hetzner_node']['hetzner_tailscale_setup_artifacts']`
  doesn't reliably cross play boundaries. Replaced with a dedicated pre_task that delegates
  `tailscale ip -4` to `hetzner_node` and sets the IP as a host fact via `set_fact`. This also
  fixes `kubeconfig_manager` writing `https://:6443` into `~/.kube/config` on re-runs.
- **Fixed: k3s_cluster_domain not in play scope** — `k8s_object_manager` calls `k8s_validator`
  internally on every invocation. `k3s_cluster_domain` must be a play-level var, not just in
  `import_role vars:`. Added `k3s_cluster_domain: "{{ hetzner_tailscale_ip }}"` to play vars.
- **Fixed: k3s_cluster_name undefined** — `k8s_validator` artifacts reference `k3s_cluster_name`
  without a per-role prefix. Added `k3s_cluster_name: "{{ hetzner_cluster_name }}"` to play vars.
- **Fixed: onepassword_operator_deploy_project** — Default `coachlight-k3s-infra` project doesn't
  exist on Hetzner. Added explicit `onepassword_operator_deploy_project: "hetzner-infra"`.
- **Fixed: role execution order deadlock** — `onepassword_operator_deploy` previously ran before
  `argocd_github_repo_create` and root.yml. It creates an ArgoCD Application and waits 5 min for
  the deployment — but ArgoCD can't sync until the GitHub repo is registered AND the `hetzner-infra`
  project exists (both created by the later steps). Reordered: GitHub repo → root.yml → 1Password.

### 2026-04-11 (BOOT-2 fix — artifacts_path + 1Password kubeconfig saving)

- **Fixed BOOT-2** (`hetzner-bootstrap.yml`) — Added `artifacts_path: "{{ playbook_dir }}/.artifacts"`
  to the "Deploy ArgoCD stack" play vars. `kubeconfig_manager` and `k9s_install` both default to
  `{{ artifacts_path }}` internally; without it Ansible validation fails before the role runs.
- **Added: 1Password kubeconfig save** — Two new pre_tasks after `kubeconfig_manager`:
  - `op_item_create` creates "Hetzner k3s Kubeconfig" (category: server, vault: HomeLab) on first run.
  - `op_item_edit` updates it on re-runs (runs only when `op_item_create_existing_items` is non-empty).
  - Both use `lookup('env', 'OP_SERVICE_ACCOUNT_TOKEN')` for auth and `no_log: true`.
  - Kubeconfig stored as a `concealed` field (`kubeconfig[concealed]`).
- **BOOT-1 resolved** — Phase 2 progressed past volume format (ran full `site.yml`; provision
  was idempotent). k3s installed, kubeconfig fetched. Bootstrap stopped at kubeconfig_manager
  (BOOT-2) before ArgoCD deployment.

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

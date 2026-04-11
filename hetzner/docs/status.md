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

Last updated: 2026-04-10 (security/correctness audit)

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

All issues below were identified in a security/correctness audit on 2026-04-10. Grouped
by severity. Each entry includes the exact files and steps to fix it.

---

### HIGH-1 — Port 6443 firewalled; kubeconfig uses public IP (bootstrap will fail)

**Files:** `hetzner/ansible/playbooks/hetzner-bootstrap.yml`

The Hetzner Cloud Firewall only opens TCP/22 and UDP/41641. Port 6443 (k3s API) is not
open. The bootstrap playbook currently sets `hetzner_api_server` to the public IP:

```yaml
hetzner_api_server: "https://{{ hetzner_server_ip }}:6443"
```

All `kubectl` operations in the second play (ArgoCD deploy, 1Password Operator, root
app) will time out. The fix is to use the node's Tailscale IPv4 instead, which is
available after `hetzner_tailscale_setup` runs.

**Fix steps:**

1. In `hetzner/ansible/playbooks/hetzner-bootstrap.yml`, in the `Deploy ArgoCD stack`
   play's `vars` block, replace:

   ```yaml
   hetzner_server_ip: >-
     {{ hostvars['localhost']['hetzner_provision_artifacts']['server_ip']
        | default('REPLACE_WITH_HETZNER_IP') }}
   hetzner_kubeconfig: /tmp/hetzner-k3s.yaml
   hetzner_context: hetzner
   hetzner_cluster_name: hetzner
   hetzner_api_server: "https://{{ hetzner_server_ip }}:6443"
   ```

   with:

   ```yaml
   hetzner_tailscale_ip: >-
     {{ hostvars['hetzner_node']['hetzner_tailscale_setup_artifacts']['tailscale_ip_v4'] }}
   hetzner_kubeconfig: "{{ lookup('env', 'HOME') }}/.kube/hetzner-k3s.yaml"
   hetzner_context: hetzner
   hetzner_cluster_name: hetzner
   hetzner_api_server: "https://{{ hetzner_tailscale_ip }}:6443"
   ```

   (The `hetzner_server_ip` var can remain if used elsewhere, but must not be used for
   the API server URL.)

2. Update the kubeconfig `replace` pre_task regexp to match `127.0.0.1` and replace
   with `{{ hetzner_tailscale_ip }}` (same logic, different source variable).

3. Verify by running a dry-run of the second play after Tailscale is up:
   `kubectl --context hetzner get nodes`

---

### HIGH-2 — SSH port 22 permanently open to the internet

**Files:** `hetzner/ansible/roles/hetzner_provision/tasks/main.yml`

The Cloud Firewall is created during provisioning with TCP/22 open from `0.0.0.0/0`
and `::/0`. The firewall is never updated after Tailscale is installed. Even with
key-only auth this is unnecessary public attack surface.

**Fix steps:**

Add a task to `hetzner/ansible/playbooks/hetzner-bootstrap.yml` at the end of the
`hetzner` play (after `hetzner_tailscale_setup` confirms the node is on the tailnet)
that calls `hetzner.hcloud.firewall` to update the SSH rule:

```yaml
- name: Restrict SSH to Tailscale CIDR now that Tailscale is active
  hetzner.hcloud.firewall:
    api_token: "{{ lookup('community.general.onepassword',
                           'Hetzner', field='api_token', vault='HomeLab') }}"
    name: "{{ hetzner_provision_firewall_name | default('hetzner-node-fw') }}"
    rules:
      - description: Allow SSH from Tailscale only
        direction: in
        protocol: tcp
        port: "22"
        source_ips:
          - 100.64.0.0/10
      - description: Allow Tailscale
        direction: in
        protocol: udp
        port: "41641"
        source_ips:
          - 0.0.0.0/0
          - ::/0
    state: present
  no_log: true
  delegate_to: localhost
```

`100.64.0.0/10` is the CGNAT range used by Tailscale for all node IPs. Alternatively,
enable Tailscale SSH (`hetzner_tailscale_setup_ssh_enabled: true`) and remove port 22
from the firewall entirely — but that requires ACL changes in the Tailscale admin
console first.

---

### HIGH-3 — Cluster-admin kubeconfig written to world-readable `/tmp`

**Files:** `hetzner/ansible/playbooks/hetzner-bootstrap.yml`

```yaml
- name: Fetch kubeconfig from Hetzner node
  ansible.builtin.fetch:
    src: /etc/rancher/k3s/k3s.yaml
    dest: /tmp/hetzner-k3s.yaml
    flat: true
```

`/tmp` is world-readable on Linux. The fetched file contains the cluster CA certificate,
admin client cert, and private key. Must be written to a private location.

**Fix steps:**

1. Change `dest` to `"{{ lookup('env', 'HOME') }}/.kube/hetzner-k3s.yaml"`.

2. Add a permissions task immediately after the fetch:

   ```yaml
   - name: Restrict kubeconfig permissions
     ansible.builtin.file:
       path: "{{ lookup('env', 'HOME') }}/.kube/hetzner-k3s.yaml"
       mode: "0600"
     delegate_to: localhost
   ```

3. Update `hetzner_kubeconfig` in the second play vars to match
   (also handled by HIGH-1 fix above).

4. After `kubeconfig_manager` merges the context into `~/.kube/config`, optionally
   delete the standalone file:

   ```yaml
   - name: Remove temporary standalone kubeconfig
     ansible.builtin.file:
       path: "{{ hetzner_kubeconfig }}"
       state: absent
     delegate_to: localhost
   ```

---

### MEDIUM-1 — `TailscaleIPs` accessed without `default([])` guard

**File:** `hetzner/ansible/roles/hetzner_tailscale_setup/tasks/main.yml`

If `Self.TailscaleIPs` is absent from the final status JSON, Jinja2 will raise an
undefined error before `first | default('')` can catch it.

**Fix steps:**

Change the two IP extraction tasks from:

```yaml
hetzner_tailscale_setup_ip_v4: >-
  {{ hetzner_tailscale_setup_final.Self.TailscaleIPs
     | select('match', '^[0-9]+\\.') | first | default('') }}
hetzner_tailscale_setup_ip_v6: >-
  {{ hetzner_tailscale_setup_final.Self.TailscaleIPs
     | select('match', '^[a-fA-F0-9]+:') | first | default('') }}
```

to:

```yaml
hetzner_tailscale_setup_ip_v4: >-
  {{ hetzner_tailscale_setup_final.Self.TailscaleIPs | default([])
     | select('match', '^[0-9]+\\.') | first | default('') }}
hetzner_tailscale_setup_ip_v6: >-
  {{ hetzner_tailscale_setup_final.Self.TailscaleIPs | default([])
     | select('match', '^[a-fA-F0-9]+:') | first | default('') }}
```

---

### MEDIUM-2 — k3s install via `curl | sh` without `pipefail`

**File:** `hetzner/ansible/playbooks/hetzner-bootstrap.yml`

`ansible.builtin.shell` runs `/bin/sh -c` which does not set `pipefail`. If `curl`
fails silently (e.g. transient network error, non-200 from get.k3s.io), `sh` receives
empty stdin, the pipe exits 0, and the `creates:` guard treats k3s as already installed
— silently leaving the node without k3s.

**Fix steps:**

Add `executable` and `set -euo pipefail` to the shell task:

```yaml
- name: Install k3s single-node {{ k3s_version }}
  ansible.builtin.shell:
    cmd: |
      set -euo pipefail
      curl -sfL https://get.k3s.io | \
        INSTALL_K3S_VERSION="{{ k3s_version }}" \
        sh -s - server \
          --disable traefik \
          --disable servicelb \
          --default-local-storage-path {{ hetzner_k3s_storage_path }}
    executable: /bin/bash
  args:
    creates: /usr/local/bin/k3s
```

---

### MEDIUM-3 — Inventory `replace` regexp too broad

**File:** `hetzner/ansible/roles/hetzner_provision/tasks/main.yml`

```yaml
regexp: 'ansible_host: .*'
replace: "ansible_host: {{ hetzner_provision_tmp_server_ip }}"
```

This replaces every `ansible_host:` line in the inventory file. Safe today because only
`hetzner_node` has an `ansible_host`, but will silently corrupt the inventory if a
second host is ever added.

**Fix steps:**

Scope the match to the server name. Replace the `ansible.builtin.replace` task with
`ansible.builtin.lineinfile` using `insertafter`:

```yaml
- name: Write server IP to inventory file {{ hetzner_provision_inventory_path }}
  ansible.builtin.lineinfile:
    path: "{{ hetzner_provision_inventory_path }}"
    regexp: '(\s+ansible_host:\s+).*'
    line: '          ansible_host: {{ hetzner_provision_tmp_server_ip }}'
    backrefs: false
```

Or if you prefer to keep `replace`, anchor it to the hetzner_node block:

```yaml
regexp: '(hetzner_node:.*\n\s+ansible_host:).*'
```

(Requires `multiline: true` — consider `lineinfile` instead for reliability.)

---

### MEDIUM-4 — PostgreSQL image pinned to `:latest` in migration runbook

**File:** `hetzner/docs/migration-runbook.md`

The temp pods in Steps 2 and 4d use `--image=bitnami/postgresql:latest`. If the
`:latest` tag resolves to a different version between the dump and restore steps,
pg_dump format compatibility could break.

**Fix steps** (already documented inline in the runbook):

Before starting the migration, run:

```bash
kubectl --context homelab -n db-postgres get pod \
  -l app.kubernetes.io/name=postgresql \
  -o jsonpath='{.items[0].spec.containers[0].image}'
```

Substitute the exact tag (e.g. `bitnami/postgresql:17.2.0`) for `:latest` in both the
dump pod (`pg-dump-tmp`) and the restore pod (`pg-restore-tmp`) commands.

---

### LOW-1 — `blkid` and `mkfs.ext4` called without full paths

**File:** `hetzner/ansible/playbooks/hetzner-bootstrap.yml`

```yaml
ansible.builtin.command: blkid {{ hetzner_volume_device }}
ansible.builtin.command: mkfs.ext4 {{ hetzner_volume_device }}
```

Works on Fedora because `/usr/sbin` is in `PATH`, but not portable.

**Fix:** Use `/usr/sbin/blkid` and `/usr/sbin/mkfs.ext4`.

---

### LOW-2 — PostgreSQL dump validated only by file size

**File:** `hetzner/docs/migration-runbook.md` — already fixed inline (2026-04-10).

The runbook previously only ran `ls -lh` to verify the dump. A redirect failure or
connection error can produce a tiny partial file that passes a size check. The runbook
now adds:

```bash
head -5 "$DUMP_FILE" | grep -q 'PostgreSQL database dump' \
  || { echo "ERROR: $DUMP_FILE does not look like a valid pg_dump output. Aborting."; exit 1; }
```

---

## Change Log

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

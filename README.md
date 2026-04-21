# utility-scripts

To use, run `git clone https://github.com/SRF-Audio/utility-scripts.git && cd utility-scripts && ./bootstrap.sh`

This repo is a list of useful setup scripts for different Linux Distros, and various cloud/kubernetes tools that I use. These allow me to spin up a new VM or container, and quickly bring it back to my preferred configuration.

---

## Quick Start: Cluster Connector

Got a fresh machine and need kubectl/k9s access to both clusters? One command sets everything up permanently:

```bash
cd ansible/
ansible-playbook -i inventories/hosts.yml playbooks/cluster-connector.yml
```

This will:

- Pull `~/.ssh/coachlight-homelab.pem` from 1Password if it's missing
- Fetch the `coachlight-k3s-cluster` kubeconfig live from `k3s-cp-1` (requires homelab to be up)
- Fetch the `hetzner` kubeconfig from 1Password (stored during bootstrap)
- Merge both into `~/.kube/config` as contexts `coachlight-k3s-cluster` and `hetzner`
- Write SSH aliases for all 6 homelab k3s nodes and `hetzner-node` into `~/.ssh/config`
- Install k9s if not already present
- Validate connectivity to both clusters

**Prerequisites:** Tailscale active on `rohu-shark.ts.net` and 1Password CLI authenticated (`op signin` or `OP_SERVICE_ACCOUNT_TOKEN` set).

**One cluster at a time:**

```bash
# Homelab only (cluster must be running)
ansible-playbook -i inventories/hosts.yml playbooks/cluster-connector.yml --tags cluster_connector_homelab

# Hetzner only
ansible-playbook -i inventories/hosts.yml playbooks/cluster-connector.yml --tags cluster_connector_hetzner
```

---

## Hetzner k3s Cluster

Single-node k3s cluster on Hetzner Cloud. All services are Tailscale-only — no public ingress.

**Dashboard:** `https://homepage-hetzner.rohu-shark.ts.net`

| Service       | URL                                    | Notes                               |
| ------------- | -------------------------------------- | ----------------------------------- |
| Homepage      | `homepage-hetzner.rohu-shark.ts.net`   | Dashboard with k8s widget           |
| ArgoCD        | `argocd-hetzner.rohu-shark.ts.net`     | GitOps — `hetzner/argocd/apps/`     |
| Grafana       | `grafana-hetzner.rohu-shark.ts.net`    | Prometheus + Loki dashboards        |
| Prometheus    | `prometheus-hetzner.rohu-shark.ts.net` | 30d retention, kube-prometheus-stack|
| MinIO         | `minio-hetzner.rohu-shark.ts.net`      | S3 backend for Loki                 |
| Paperless-NGX | `paperless-hetzner.rohu-shark.ts.net`  | Document management                 |

**Bootstrap a fresh cluster:**

```bash
cd ansible/
ansible-playbook -i inventories/hosts.yml playbooks/hetzner-bootstrap.yml
```

**GitOps layout:**

```text
hetzner/argocd/apps/      # ArgoCD Applications (root app recurses this)
hetzner/k8s/              # Raw k8s resources (kustomize, applied by ArgoCD apps)
```

**Ingress annotation pattern** (for Homepage service discovery):

```yaml
gethomepage.dev/enabled: "true"
gethomepage.dev/href: "https://<service>-hetzner.rohu-shark.ts.net"   # clickable link
gethomepage.dev/url: "http://<svc>.<namespace>.svc.cluster.local:<port>"  # ping target
```

---

## Synology NAS → Hetzner Backup

Backs up a Synology DS1813+ (9.7TB, `/volume2`) to a Hetzner Storage Box using restic over SFTP. Disaster-recovery copy for a family move — see [`synology-backup/docs/status.md`](synology-backup/docs/status.md) for full project status.

**What gets backed up:** `/volume2/docker`, `/volume2/home-assistant-backup`, `/volume2/homes`, `/volume2/k3s-cluster-storage`, `/volume2/NetBackup`, `/volume2/paperless`, `/volume2/proxmox-backup`, `/volume2/proxmox-cluster-storage`, `/volume2/time-machine`

### Prerequisites

1. **`op` CLI authenticated:**

   ```zsh
   op signin  # or: export OP_SERVICE_ACCOUNT_TOKEN=<token>
   op vault list  # HomeLab must appear
   ```

2. **Ansible collections installed:**

   ```zsh
   cd synology-backup/ansible
   ansible-galaxy collection install -r requirements.yml
   ```

3. **NAS reachable via Tailscale** — `ping srfaudio.rohu-shark.ts.net`

### Deploy / update

```zsh
cd synology-backup/ansible
ansible-playbook -i inventories/hosts.yml playbooks/synology-backup.yml
```

Idempotent — safe to re-run. Deploys restic, scripts, credentials, SSH config, cron jobs. All secrets fetched from 1Password at runtime.

### Start a backup manually

```zsh
ssh stephenfroeber@srfaudio.rohu-shark.ts.net \
  'nohup sudo /usr/local/bin/restic-backup/backup.sh > /dev/null 2>&1 &'
```

### Monitor a running backup

```zsh
# Tail the live log
ssh stephenfroeber@srfaudio.rohu-shark.ts.net \
  'sudo tail -f /var/log/restic-backup/backup.log'

# Check if backup process is running
ssh stephenfroeber@srfaudio.rohu-shark.ts.net \
  'pgrep -a restic'
```

A completed backup ends with a line like:

```text
snapshot abc12345 saved
=== 2026-04-20T14:51:06 [backup] END rc=0 ===
```

### Verify snapshots

```zsh
ssh stephenfroeber@srfaudio.rohu-shark.ts.net \
  'sudo RESTIC_REPOSITORY=sftp:storagebox:restic \
   RESTIC_PASSWORD_FILE=/etc/restic-backup/.restic-password \
   /usr/local/bin/restic snapshots'
```

### Stop a running backup

```zsh
ssh stephenfroeber@srfaudio.rohu-shark.ts.net 'sudo pkill restic'
```

Restic is safe to interrupt — it will not leave a corrupt repository. The next run picks up where it left off (deduplication means already-uploaded data is skipped).

### Schedule

Cron jobs run automatically on the NAS:

| Job             | Schedule           |
| --------------- | ------------------ |
| Backup          | Daily at 02:00     |
| Forget / prune  | Sunday at 03:00    |
| Integrity check | Wednesday at 04:00 |

### 1Password items required

| Item                                                    | Vault   | Fields used                                                |
| ------------------------------------------------------- | ------- | ---------------------------------------------------------- |
| `Synology 1813 SSH Key`                                 | HomeLab | SSH agent key for control host → NAS                       |
| `Hetzner`                                               | HomeLab | `add more/storagebox_host`, `add more/storagebox_username` |
| `Hetzner Storage Box SSH Key`                           | HomeLab | `private key` (SSH Key item, OpenSSH format)               |
| `Synology Restic Repository`                            | HomeLab | `password`                                                 |
| `Synology NAS` (item ID: `oattlsmrtkwf6ppnvvo24shk24`)  | HomeLab | `password` — stephenfroeber sudo password                  |

### Storage Box

- **Host:** `u579903.your-storagebox.de` (BX61, 20TB, fsn1)
- **User:** `u579903`
- SSH key auth configured; public key in `~/.ssh/authorized_keys` on the Storage Box

---

## Contributing

If you find these useful, but see a way to make them better, or more efficient, feel free to open an issue. I appreciate the contribution.

## Notes

### Playbook high level strategy

Below is a pattern I’ve had good luck with on mixed-environment homelabs.  It follows the directory layout and role-centric workflow the Ansible docs call “sample-setup”, adding only enough structure to keep your desktop, hypervisor, VM, k3s and add-on services cleanly separated. ([docs.ansible.com][1])

---

## 1  Inventory: model the *hardware & OS* first

```text
inventories/
└── homelab/
    ├── hosts.ini
    └── group_vars/
        ├── all.yml
        ├── desktops.yml          # KDE Fedora workstations & laptops
        ├── proxmox.yml          # Bare-metal hypervisors
        ├── vms_fedora.yml       # CoreOS / Server VMs
        ├── k3s_control.yml
        └── k3s_worker.yml
```

- **Hosts go in the most specific group only**; use Ansible’s built-in group inheritance (`children=` blocks) if something truly belongs to several groups.
- Put *behaviour* in `group_vars`, secrets in `vault.yml` (or call the 1Password lookup plug-in there).  This keeps secrets out of playbooks and roles.  ([docs.ansible.com][2], [docs.ansible.com][3])

---

## 2  Roles: one concern per role

Roles are how you make the codebase composable and testable.  Each role owns exactly one slice of configuration and can be reused on any host that needs it.  ([docs.ansible.com][4])

| Role name         | What it does                                                             | Typical tags |
| ----------------- | ------------------------------------------------------------------------ | ------------ |
| `common`          | Users, base packages, 1Password CLI, Tailscale client                    | `base`       |
| `updates`         | DNF/Yum/Apt upgrade or `rpm-ostree upgrade` with autoreboot guard        | `updates`    |
| `workstation_kde` | KDE settings, Plasma look-and-feel, Flatpak/pkg install                  | `gui`        |
| `proxmox_host`    | `/etc/hosts`, cluster join, pve-no-subscription repo, zfs tune           | `hypervisor` |
| `coreos_base`     | Ignition tweaks, rpm-ostree layers, podman                               | `vm`         |
| `ssh_keys`        | Generate ED25519 keys, sync public key from 1Password item, distribute   | `ssh`        |
| `k3s_control`     | Install k3s server, configure etcd-external, set node-labels             | `k3s`        |
| `k3s_worker`      | Join worker, taints, GPU runtime, kube-proxy flags                       | `k3s`        |
| `k8s_deploy`      | `k8s` / `helm` module calls that stand up Home-Assistant, InfluxDB, etc. | `apps`       |

*Anything* that may be useful on more than one host belongs in its own role; resist the urge to combine “desktop tweaks” with “OS updates”.

---

## 3  Playbooks: orchestration entry points

Keep playbooks thin—just “which hosts, which roles, in what order”.  Example:

```yaml
# playbooks/site.yml  ← run for the full stack
- name: Workstations
  hosts: desktops
  roles:
    - common
    - workstation_kde
    - ssh_keys
    - updates

- name: Proxmox hypervisors
  hosts: proxmox
  gather_facts: false           # PVE shell is fast; facts optional
  roles:
    - common
    - proxmox_host
    - ssh_keys
    - updates

- name: Fedora / CoreOS VMs
  hosts: vms_fedora
  roles:
    - common
    - coreos_base
    - updates

- name: k3s control plane
  hosts: k3s_control
  roles:
    - k3s_control
    - k8s_deploy            # if you want apps immediately

- name: k3s workers
  hosts: k3s_worker
  roles:
    - k3s_worker
```

### Useful siblings

```text
playbooks/
├── site.yml           # full convergence
├── maintenance.yml    # just updates & reboots
└── k8s.yml            # (re)deploy apps only
```

---

## 4  Granularity & tagging rules of thumb

| Question to ask                                                 | Answer                                                                                  |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **“Could this role ever target a *different* host type?”**      | If *yes*, keep it separate (ex: `ssh_keys`, `updates`).                                 |
| **“Does this task get skipped 90 % of the time?”**              | Give it a tag (`gui`, `apps`) so you can `--tags gui` or `--skip-tags gui`.             |
| **“Do I have >200 lines in a single role’s `tasks/main.yml`?”** | Split into `tasks/update.yml`, `tasks/firewall.yml`, etc. and call with `import_tasks`. |
| **“Is this only called from another role?”**                    | Put it in that role’s `meta/` as a dependency instead of its own top-level playbook.    |

---

## 5  Running it day-to-day

| High-level job                          | Command                                                           |
| --------------------------------------- | ----------------------------------------------------------------- |
| One-shot full converge                  | `ansible-playbook -i inventories/hosts.yml site.yml`              |
| Desktop GUI tweaks only                 | `ansible-playbook site.yml --tags gui --limit desktops`           |
| Patch Tuesday                           | `ansible-playbook playbooks/maintenance.yml --tags updates`       |
| Redeploy apps after editing Helm values | `ansible-playbook site.yml --tags apps`                           |

Because roles carry their own tags, you stay flexible without bloating the playbooks.

---

### Why this tends to scale

- **Separation of concerns** – inventory = *where*, roles = *what*, playbooks = *when/which*.
- **Predictable overrides** – `group_vars` hierarchy means a workstation can inherit `common` defaults but override `dnf_automatic: true`.
- **Idempotence tests** – each role is unit-testable with Molecule (Docker or Vagrant driver) before it ever touches the homelab.
- **Secrets-aware** – 1Password lookup lives only in `group_vars/all/vault.yml`; roles stay secrets-agnostic.

Adopt or drop pieces to taste, but sticking to this pattern will keep “desktop tweaks” from leaking into your hypervisor config and vice-versa—no more *sauce* mixing.

[1]: https://docs.ansible.com/ansible/latest/tips_tricks/sample_setup.html?utm_source=chatgpt.com "Sample Ansible setup"
[2]: https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html?utm_source=chatgpt.com "How to build your inventory - Ansible Documentation"
[3]: https://docs.ansible.com/ansible/2.9/user_guide/playbooks_best_practices.html?utm_source=chatgpt.com "Best Practices - Ansible Documentation"
[4]: https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html?utm_source=chatgpt.com "Roles — Ansible Community Documentation"

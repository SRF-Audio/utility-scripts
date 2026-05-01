# Hetzner Migration Overview

<!--
AGENT INSTRUCTIONS
==================
These docs are the authoritative source of truth for this migration project.
ALWAYS read all three docs (overview.md, status.md, migration-runbook.md) before
doing any work in the hetzner/ directory. ALWAYS update status.md after any change.
If you make architectural decisions, update overview.md too.

Key constraints:
- Never modify anything outside hetzner/ (the top-level ansible/, argocd/, k8s/ are
  homelab config and must not be touched)
- hetzner/ansible/ is a standalone playbook; it reuses roles from ansible/roles/ via
  the roles_path in hetzner/ansible/ansible.cfg
- Run bootstrap from hetzner/ansible/: ansible-playbook -i inventory/hetzner.yml site.yml

kubectl contexts:
- hetzner               → this cluster (use for all kubectl commands in this directory)
- coachlight-k3s-cluster → homelab cluster (reference only; do not modify)
Always pass --context explicitly. The API server is Tailscale-only; ensure local machine
is on the tailnet before running kubectl or ansible against the hetzner node.

MCP tools available in Claude Code:
- github: read GitHub repos/PRs/issues without leaving the conversation
- fetch:  look up ArgoCD, Ansible, k8s, or Hetzner API docs inline
Use Bash (kubectl, ansible-playbook, op) for all write/mutation operations.
-->

## Purpose

Temporary (2–4 month) migration of the Coachlight homelab Paperless-NGX stack to a
single-node k3s cluster on Hetzner Cloud while relocating to the Netherlands.

---

## Target Infrastructure

| Component        | Value                                      |
|------------------|--------------------------------------------|
| Server type      | CAX31 (16 vCPU ARM64, 32 GB RAM)           |
| OS               | Fedora 43 ARM64 (Hetzner Cloud image)      |
| k3s              | Single-node, latest stable                 |
| Block volume     | 500 GB Hetzner attached volume             |
| Volume mount     | `/mnt/hetzner-volume`                      |
| k3s storage path | `/mnt/hetzner-volume/k3s-storage`          |
| Tailnet          | `rohu-shark.ts.net`                        |
| Tailscale tags   | `tag:k8s`, `tag:server-apps`               |

---

## Services Deployed

| Service                  | Namespace                  | Notes                                  |
|--------------------------|----------------------------|----------------------------------------|
| ArgoCD                   | `argocd`                   | GitOps control plane                   |
| 1Password Operator       | `infra-1password-operator` | Secret injection via 1Password         |
| Tailscale Operator       | `infra-tailscale-operator` | Ingress via Tailscale VPN              |
| PostgreSQL (Bitnami)     | `db-postgres`              | Database for Paperless-NGX             |
| Redis (Bitnami)          | `db-redis`                 | Cache/queue for Paperless-NGX          |
| Paperless-NGX            | `apps-paperless-ngx`       | Document management (mission-critical) |
| Gotenberg                | `apps-paperless-ngx`       | Document conversion sidecar            |
| Apache Tika              | `apps-paperless-ngx`       | Content extraction sidecar             |

---

## URL / Hostname Strategy

**Decision**: Use `-hetzner` suffixed hostnames during the migration period. This allows
both clusters to run in parallel, enabling data verification before the homelab is shut
down. Paperless is renamed to the production hostname at cutover (a single kubectl apply).

| Service       | Hetzner hostname                       | Homelab hostname                 |
|---------------|----------------------------------------|----------------------------------|
| ArgoCD        | `argocd-hetzner.rohu-shark.ts.net`     | `argocd.rohu-shark.ts.net`       |
| Paperless-NGX | `paperless-hetzner.rohu-shark.ts.net`  | `paperless.rohu-shark.ts.net`    |

**Cutover**: When ready to decommission homelab Paperless-NGX, update two files and push:

- `hetzner/k8s/paperless_ngx/configmap.yml` — change `PAPERLESS_URL`
- `hetzner/k8s/paperless_ngx/ingress.yml` — change `host` and `tls.hosts`

ArgoCD on Hetzner will automatically sync the change within minutes.

---

## Key Differences from Homelab

| Aspect              | Homelab                            | Hetzner                                  |
|---------------------|------------------------------------|------------------------------------------|
| Storage backend     | Synology NFS (`192.168.226.6`)     | Local-path on attached 500 GB volume     |
| Storage class       | `nfs-synology-retain`              | `local-path-retain`                      |
| PVC access mode     | `ReadWriteMany`                    | `ReadWriteOnce` (single node)            |
| NFS provisioner     | Deployed                           | Not deployed                             |
| Cluster nodes       | Multi-node VM cluster on Proxmox   | Single node                              |
| ArgoCD hostname     | `argocd.rohu-shark.ts.net`         | `argocd-hetzner.rohu-shark.ts.net`       |
| ArgoCD TLS          | Native HTTPS (port 443 backend)    | Insecure mode + Tailscale Operator TLS   |
| ArgoCD OAuth        | GitHub OAuth via Dex               | Disabled — admin password only           |
| Paperless hostname  | `paperless.rohu-shark.ts.net`      | `paperless-hetzner.rohu-shark.ts.net`    |
| Redis replicas      | master + replica                   | master only (single node, saves RAM)     |

---

## Repository Layout

```text
hetzner/
├── docs/                               # Agent-ready records (this directory)
│   ├── overview.md                     # Architecture, decisions, layout (this file)
│   ├── status.md                       # Phase progress, open issues, change log
│   └── migration-runbook.md            # Step-by-step data migration procedure
├── ansible/
│   ├── ansible.cfg                     # roles_path → ../../ansible/roles
│   ├── inventory/hetzner.yml           # Hetzner host + local group
│   ├── playbooks/hetzner-bootstrap.yml # Bootstrap k3s + ArgoCD + overrides
│   └── site.yml                        # Entry point (reads 1Password secrets first)
├── argocd/
│   ├── root.yml                        # Root ArgoCD app (applied by Ansible)
│   └── apps/
│       ├── projects/                   # AppProject definitions (wave 0)
│       ├── operators/                  # Tailscale operator + secrets (waves 10, 20)
│       ├── platform/                   # Storage, Postgres, Redis (waves 20)
│       └── apps/                       # Paperless-NGX (wave 30)
└── k8s/
    ├── argocd/                         # ArgoCD config overrides (applied by Ansible)
    │   ├── argocd-cm.yml               # Hetzner URL, no Dex/OAuth
    │   ├── argocd-cmd-params-cm.yml    # server.insecure: true (for Tailscale ingress)
    │   └── ingress.yml                 # Tailscale ingress → argocd-hetzner hostname
    ├── cluster_primitives/             # local-path StorageClasses + config ConfigMap
    └── paperless_ngx/                  # Hetzner-specific PVCs, configmap, ingress
```

---

## What Is Reused from the Homelab Config

- `k8s/paperless_ngx_secrets/` — OnePasswordItem CRDs (no changes needed)
- `k8s/postgres_secrets/` — OnePasswordItem for PostgreSQL (no changes needed)
- `k8s/redis_secrets/` — OnePasswordItem for Redis (no changes needed)
- `k8s/tailscale_operator/onepassword/` — Tailscale OAuth secret (no changes needed)
- All container images and versions (same Paperless-NGX, Postgres, Redis, Tika, Gotenberg)
- All 1Password vault items and secret names (same HomeLab vault)
- Tailscale operator Helm chart and config (same tailnet, same chart version)
- All Ansible roles under `ansible/roles/`

## What Is New / Modified

- `hetzner/ansible/ansible.cfg` — sets `roles_path = ../../ansible/roles`
- `hetzner/k8s/argocd/` — Hetzner ArgoCD config overrides (new; applied by Ansible)
- `hetzner/k8s/cluster_primitives/` — local-path classes only; `local-path-config`
  ConfigMap redirects storage to mounted Hetzner volume
- `hetzner/k8s/paperless_ngx/pvcs.yml` — `local-path-retain`, `ReadWriteOnce`; names
  cleaned up (no `-nfs` suffix); consume PVC is dynamically provisioned
- `hetzner/k8s/paperless_ngx/configmap.yml` — `PAPERLESS_URL` set to `-hetzner` hostname
- `hetzner/k8s/paperless_ngx/ingress.yml` — `-hetzner` hostname, Tailscale IngressClass
- `hetzner/k8s/paperless_ngx/webserver.yml` — updated PVC claim names
- `hetzner/argocd/` — separate ArgoCD app tree pointing to hetzner paths/projects

---

## Architecture Notes

### Storage

The 500 GB Hetzner block volume is mounted by Ansible at `/mnt/hetzner-volume` during
server setup. k3s is installed with `--default-local-storage-path /mnt/hetzner-volume/k3s-storage`,
and the `local-path-config` ConfigMap in `kube-system` confirms the same path. All PVCs
backed by `local-path-retain` or `local-path-delete` land on the persistent Hetzner volume,
not the ephemeral node disk.

### Bootstrap Order

```text
Ansible (site.yml):
  1. Read 1Password secrets (localhost)
  2. hetzner-bootstrap.yml (localhost → hetzner node):
     a. Format + mount Hetzner volume
     b. Install k3s single-node
     c. Fetch + merge kubeconfig (context: "hetzner")
     d. argocd_deploy role  → installs ArgoCD + homelab-default argocd-cm
     e. Apply hetzner/k8s/argocd/argocd-cm.yml       (overrides URL, removes Dex)
     f. Apply hetzner/k8s/argocd/argocd-cmd-params-cm.yml  (insecure mode)
     g. Apply hetzner/k8s/argocd/ingress.yml          (argocd-hetzner hostname)
     h. onepassword_operator_deploy role
     i. argocd_github_repo_create role
     j. Apply hetzner/argocd/root.yml  →  ArgoCD takes over:
          Wave  0: AppProjects
          Wave 10: Secrets (OnePasswordItems)
          Wave 20: Cluster primitives + Tailscale Operator + Postgres + Redis
          Wave 30: Paperless-NGX (webserver, Tika, Gotenberg)
```

### Networking / Access

All external access via Tailscale VPN. Tailscale Operator provisions IngressClass
`tailscale` used by Paperless-NGX and ArgoCD ingresses. No public ingress controller.
ArgoCD runs in insecure mode (HTTP/80); Tailscale Operator handles TLS termination.
The Hetzner node joins the Tailscale tailnet during Phase 1 bootstrap (automated via
`hetzner_tailscale_setup` role).

**k3s API server access**: The Hetzner Cloud Firewall blocks all ports except TCP/22
and UDP/41641. Port 6443 (k3s API) is not publicly exposed. The kubeconfig for the
`hetzner` context **must use the node's Tailscale IPv4 address** (100.x.x.x) as the
API server URL — not the public IP. The bootstrap playbook derives this from
`hostvars['hetzner_node']['hetzner_tailscale_setup_artifacts']['tailscale_ip_v4']`.
Ensure your local machine is on the same Tailscale tailnet before running the
bootstrap or any `kubectl --context hetzner` commands.

### ArgoCD on Hetzner

- GitHub OAuth/Dex is **disabled**. Use the ArgoCD admin password (retrieve with:
  `kubectl --context hetzner -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`)
- Accessible at `https://argocd-hetzner.rohu-shark.ts.net` (Tailscale only)
- The ArgoCD ingress is applied by Ansible bootstrap; it is NOT managed by ArgoCD itself
  (avoids self-referential GitOps chicken-and-egg)

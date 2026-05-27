---
name: Coachlight K3s Cluster Status
description: Known issues in coachlight-k3s-cluster as of 2026-04-21, with root causes and fix approach
type: project
originSessionId: 37a26656-de7b-48fe-aecb-5899648febcb
---
Cluster is in a degraded-but-mostly-functional state. Paperless-ngx has been migrated to Hetzner. Remaining issues below.

**Why:** Homelab is being wound down / migrated to Hetzner. Not all issues need fixing — only what's blocking operational use.

**How to apply:** When asked to fix cluster issues, refer here first for context; don't treat issues as isolated bugs.

---

## Issue 1: k3s-wkr-3 — NotReady (hard down since 2026-01-22)
- Kubelet stopped posting status. Last heartbeat 2026-01-22T03:45 CST.
- FCOS version is older (`43.20251214.3.0`) vs all other nodes (`43.20260331.3.1`) — missed the auto-update.
- 12 pods are stuck on it (including 1password-connect, argocd-repo-server, netbox-worker).
- **Fix:** Physical intervention required — check the Proxmox VM, reboot it, or cordon/drain and delete the node if decommissioning.

## Issue 2: NetBox — RESOLVED (2026-04-21)
- Migrated from 3 separate 1Password items to a single unified `NetBox` item in HomeLab vault.
- All secret fields (username, password, email, api_token, secret_key, email_password, ldap_bind_password, db-password, redis-password) consolidated into one K8s secret named `netbox` in `infra-netbox`.
- NetBox app is `Synced / Healthy` as of 2026-04-21.

## Issue 3: MinIO (observability) — Degraded (ContainerCreating for 87 days)
- Root cause: OnePasswordItem `minio-credentials` failing — `k3s-observability-minio` not found in HomeLab vault.
- Same pattern as NetBox: item renamed/deleted in 1Password.
- **Fix:** Recreate `k3s-observability-minio` in 1Password HomeLab vault or update item path in `k8s/minio_secrets/`.

## Issue 4: Velero — RESOLVED (2026-04-21)
- Root causes fixed: (1) removed external `velero-plugin-for-csi` initContainer — CSI is built into Velero 1.14+, the external plugin caused duplicate plugin registration crash. (2) Bitnami Docker Hub image `bitnami/kubectl:1.34` doesn't exist — pinned to `bitnamilegacy/kubectl:1.33`. (3) Chart was rendering empty BSL/VSL CRs with missing required fields — suppressed with `configuration.backupStorageLocation: []`, `configuration.volumeSnapshotLocation: []`, `snapshotsEnabled: false`.
- Velero server is `Synced / Healthy`. No backup storage locations configured yet — that's a TODO when the cluster is needed again.

## Issue 5: Omada-Controller — ArgoCD status Unknown (ComparisonError)
- Root cause: Docker Hub rate-limiting / auth returning 403 when ArgoCD tries to check the `mbentley/omada-controller-helm` OCI chart for revision `1.0.0`.
- **The app itself is healthy and running** — this is purely an ArgoCD drift-detection issue.
- **Fix:** Add Docker Hub credentials to ArgoCD, or pin source to digest. Low priority.

## Issue 6: Paperless-ngx — ArgoCD OutOfSync (sync loop every ~5 min)
- `paperless-ngx-secrets` and `paperless-ngx-app-secrets` in a continuous loop.
- Root cause: `SharedResourceWarning` — OnePasswordItems claimed by both apps, ArgoCD fights over ownership.
- Paperless itself is **Healthy** and running on Hetzner now.
- **Fix:** Delete the homelab paperless ArgoCD apps since it's been migrated, or consolidate secret apps into one.

## Issue 7: CoreDNS — DNSConfigForming warning
- `Nameserver limits were exceeded, some nameservers have been omitted` on coredns pod.
- Likely too many upstream DNS servers hitting the 3-nameserver limit.
- **Fix:** Audit CoreDNS configmap; consolidate upstream resolvers to ≤3.

## Issue 8: root ArgoCD app — OutOfSync
- Will resolve as child apps are fixed.

---

## Node Overview (2026-04-20)
- Control plane: k3s-cp-1/2/3 — all Ready, FCOS 43.20260331.3.1
- Workers: k3s-wkr-1/2/4/5/6 — Ready; k3s-wkr-3 — NotReady (down since Jan 22)

## Bitnami Docker Hub deprecation (2026-04-21)
Bitnami stopped pushing new tags to Docker Hub. Any `image: bitnami/<app>:<tag>` reference will fail for new tags. Pattern fix: switch to `bitnamilegacy/<app>:<tag>`. Applied to velero kubectl image and postgres-provision-job. Audit other manifests before next cluster work.

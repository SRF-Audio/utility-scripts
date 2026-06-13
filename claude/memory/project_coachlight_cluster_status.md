---
name: coachlight-k3s-cluster-status
description: "Live issues in the coachlight K3s cluster (winding down for NL move) and the Bitnami Docker Hub deprecation pattern"
metadata:
  type: project
---

Cluster is degraded-but-functional and **being wound down** — workloads
migrated to Hetzner (see [[reference-hetzner-patterns]]). Only fix what blocks
operational use. Status as of 2026-04-21.

## Open issues

- **k3s-wkr-3 NotReady** (hard down since 2026-01-22, missed an FCOS
  auto-update; 12 pods stuck on it). Needs physical intervention: check the
  Proxmox VM, reboot, or cordon/drain and delete if decommissioning.
- **MinIO (observability) degraded** — OnePasswordItem points at
  `k3s-observability-minio` which no longer exists in the HomeLab vault
  (renamed/deleted). Recreate the item or update the path in
  `k8s/minio_secrets/`.
- **Paperless-ngx sync loop** (~5 min) — two ArgoCD apps fight over the same
  OnePasswordItems (`SharedResourceWarning`). Paperless runs on Hetzner now;
  fix is to delete the homelab paperless apps.
- **Omada-controller ComparisonError** — Docker Hub 403 rate-limiting on OCI
  chart check; the app itself is healthy. Low priority: add Docker Hub creds
  to ArgoCD or pin to digest.
- **CoreDNS DNSConfigForming warning** — >3 upstream nameservers; consolidate
  in the CoreDNS configmap.
- **Velero**: server healthy, but no backup storage locations configured —
  TODO if the cluster is needed again.
- Root app OutOfSync resolves as children are fixed.

Nodes (2026-04-20): cp-1/2/3 and wkr-1/2/4/5/6 Ready; wkr-3 NotReady.

## Bitnami Docker Hub deprecation pattern

Bitnami stopped pushing new tags to Docker Hub — `image: bitnami/<app>:<tag>`
fails for newer tags. Fix: `bitnamilegacy/<app>:<tag>`. Already applied to the
velero kubectl image and postgres-provision-job; audit other manifests before
the next cluster work.

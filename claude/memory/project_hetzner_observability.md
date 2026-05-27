---
name: Hetzner Observability Stack
description: Architecture decisions and current state of the Grafana/Prometheus/Loki/Alloy observability stack on the Hetzner k3s cluster
type: project
originSessionId: 2c504704-7ee3-4f9f-808b-70380b5920a3
---
## Stack Components

Deployed via ArgoCD app-of-apps under `hetzner/argocd/apps/observability/`, all in project `hetzner-observability`. Sync waves:

- Wave 10: `minio-secrets` (OnePasswordItem → minio-credentials), `grafana-secrets` (OnePasswordItem → grafana-admin-credentials)
- Wave 20: MinIO (charts.min.io 5.4.0, standalone, local-path-retain 20Gi, loki bucket)
- Wave 25: Loki (grafana/loki 6.55.0, SingleBinary, MinIO S3 backend)
- Wave 30: kube-prometheus-stack (83.6.0, Prometheus + Grafana + node-exporter + kube-state-metrics)
- Wave 35: Alloy (grafana/alloy 1.7.0, DaemonSet log+metric collector)

## Key Architecture Decisions

- **kube-prometheus-stack** chosen over standalone Prometheus chart — includes Prometheus Operator, Grafana, node-exporter, kube-state-metrics in one chart. Compatible with Alloy.
- **Alloy** (not Prometheus Agent or Grafana Agent) — new unified collector. Runs as DaemonSet, tails pod logs to Loki and scrapes own metrics to Prometheus remote_write.
- **MinIO** as Loki's S3 backend (charts.min.io, not bundled minio). Deployed separately at `observability-minio` namespace.
- **Loki SingleBinary** mode: replicas=1, persistence 10Gi local-path-retain, all read/write/backend replicas=0.
- **Grafana** exposed via Tailscale ingress at `grafana-hetzner.rohu-shark.ts.net`. Credentials from 1Password vault item `HomeLab/Grafana`.
- Alertmanager disabled (not yet configured). k3s control plane components disabled (kubeEtcd, kubeScheduler, kubeControllerManager, kubeProxy, kubeCoreDns).

## Namespace Layout

- `observability-minio` — MinIO
- `observability-loki` — Loki
- `observability-monitoring` — kube-prometheus-stack (Prometheus + Grafana)
- `observability-alloy` — Alloy

## 1Password Items Used

- `HomeLab/k3s-observability-minio` → `minio-credentials` secret (keys: `rootUser`, `rootPassword`, `lokiSecretKey`)
- `HomeLab/Grafana` → `grafana-admin-credentials` secret (keys: `username`, `password`)

## Known Fixes Applied

- Loki `bucketNames` must be at `loki.storage.bucketNames` (sibling to `s3:`), not nested inside `s3:`
- `kubeCoreDns: enabled: false` required to avoid kube-system namespace forbidden error in the observability AppProject
- AppProject `hetzner-observability` has `clusterResourceWhitelist` for monitoring.coreos.com/*, MutatingWebhookConfiguration, ValidatingWebhookConfiguration

**Why:** Hetzner single-node k3s cluster needs observability before user migrates workloads from coachlight (Proxmox). Stack designed to be lightweight (single replicas, local storage).

**How to apply:** When adding new observability apps, use `hetzner-observability` project, `observability-*` namespace destinations, and continue wave pattern. All secrets via 1Password operator.

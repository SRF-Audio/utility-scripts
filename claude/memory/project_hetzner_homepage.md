---
name: Hetzner Homepage & Ingress Work
description: Completed setup of Homepage dashboard + Tailscale ingresses for all Hetzner UIs; ingress annotation patterns documented
type: project
originSessionId: fe43b311-23c8-445a-bf3f-3dc365798806
---
# Hetzner Homepage & Tailscale Ingress Setup

**Status as of 2026-04-20 — complete and live.**

## What was built

Homepage deployed at `homepage-hetzner.rohu-shark.ts.net` with Kubernetes widget and service discovery via Ingress annotations. All UIs have Tailscale-only ingresses.

## Ingress annotation pattern

Every service ingress uses three homepage annotations:

```yaml
gethomepage.dev/href: "https://<service>-hetzner.rohu-shark.ts.net"          # clickable link
gethomepage.dev/url: "http://<svc>.<namespace>.svc.cluster.local:<port>"      # used by homepage internally
gethomepage.dev/siteMonitor: "http://<svc>.<namespace>.svc.cluster.local:<port>"  # ping in ms
```

**Why `href` + `url` + `siteMonitor` separately:**
- `url` must be the internal cluster URL — homepage pings it from inside the pod; external Tailscale hostnames are unreachable and show DOWN
- `href` is the external Tailscale URL for the clickable link
- `siteMonitor` is the annotation that shows ping latency in ms on the card

## Service inventory

| Service | Namespace | Internal svc URL |
| --- | --- | --- |
| ArgoCD | `argocd` | `http://argocd-server.argocd.svc.cluster.local:80` |
| Grafana | `observability-monitoring` | `http://hetzner-kube-prometheus-stack-grafana.observability-monitoring.svc.cluster.local:80` |
| Prometheus | `observability-monitoring` | `http://hetzner-kube-prometheus-st-prometheus.observability-monitoring.svc.cluster.local:9090` |
| MinIO console | `observability-minio` | `http://hetzner-minio-console.observability-minio.svc.cluster.local:9001` |
| Paperless-NGX | `apps-paperless-ngx` | `http://paperless-ngx-webserver.apps-paperless-ngx.svc.cluster.local:80` |

## Key architecture notes

- Homepage helm release name is `hetzner-homepage` so the service is `hetzner-homepage` (not `homepage`)
- ArgoCD ingress (`hetzner/k8s/argocd/ingress.yml`) is NOT ArgoCD-managed — Ansible-only; live kubectl patches persist
- `hetzner/k8s/argocd/argocd-cm.yml` has `accounts.homepage: apiKey` for the ArgoCD token
- 1Password item `argocd-homepage-token` in HomeLab vault; field name `token` → secret key `token`
- sysctl DaemonSet in `hetzner/k8s/cluster_primitives/sysctl-inotify.yml` raises `fs.inotify.max_user_instances` to 512 (was 128, caused ArgoCD fsnotify errors)
- ArgoCD health check for Ingresses: considers Healthy if `gethomepage.dev/enabled=true` OR has a Tailscale address — avoids deadlock during initial sync

## Why

Hetzner is the primary cluster going forward (coachlight going down for Netherlands move).

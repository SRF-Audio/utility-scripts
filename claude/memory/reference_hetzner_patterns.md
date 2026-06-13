---
name: reference-hetzner-patterns
description: "Hetzner k3s conventions and gotchas: ArgoCD project/wave/namespace patterns, homepage ingress annotation triple, 1Password operator behavior, NetBox and observability chart specifics"
metadata:
  type: reference
---

# Hetzner cluster patterns

Hetzner is the primary cluster (coachlight winding down for the NL move).
Single-node k3s, ArgoCD app-of-apps, Tailscale ingress everywhere, all secrets
via 1Password operator. Stack: kube-prometheus-stack + Loki (SingleBinary,
MinIO S3 backend) + Alloy DaemonSet, all lightweight single-replica.

## ArgoCD conventions

- App-of-apps under `hetzner/argocd/apps/`; AppProjects per domain
  (`hetzner-infra`, `hetzner-observability`, …). New observability apps: use
  project `hetzner-observability`, `observability-*` namespaces, and continue
  the sync-wave pattern (10 = 1P secrets, 20–35 = workloads in dependency
  order).
- AppProjects need `clusterResourceWhitelist` for `monitoring.coreos.com/*`
  and Mutating/ValidatingWebhookConfiguration where charts ship them.
- **ArgoCD's own ingress (`hetzner/k8s/argocd/ingress.yml`) is Ansible-managed,
  NOT ArgoCD-managed** — live kubectl patches persist.
- Ingress health check: Healthy if `gethomepage.dev/enabled=true` OR it has a
  Tailscale address — avoids initial-sync deadlock.
- sysctl DaemonSet (`hetzner/k8s/cluster_primitives/sysctl-inotify.yml`) raises
  `fs.inotify.max_user_instances` to 512 — ArgoCD fsnotify breaks at the 128
  default.

## Homepage ingress annotation triple

Every service ingress carries three annotations; they are NOT interchangeable:

```yaml
gethomepage.dev/href: "https://<svc>-hetzner.rohu-shark.ts.net"               # clickable link (external)
gethomepage.dev/url: "http://<svc>.<ns>.svc.cluster.local:<port>"             # homepage pings from inside the pod
gethomepage.dev/siteMonitor: "http://<svc>.<ns>.svc.cluster.local:<port>"     # ping latency on the card
```

External Tailscale hostnames are unreachable from the homepage pod — using
them in `url`/`siteMonitor` shows DOWN. Homepage helm release is
`hetzner-homepage` (service name follows). ArgoCD API access: account
`accounts.homepage: apiKey` in `argocd-cm`, token in 1P item
`argocd-homepage-token` (field `token`).

## 1Password operator gotchas

- The operator **does not emit Secret keys for empty-value fields** — unused
  fields a chart still mounts (e.g. NetBox `email_password`,
  `ldap_bind_password`) must hold a non-empty `placeholder` value or the pod
  fails with `couldn't find key X in Secret`.
- The operator uses the 1P **field ID as the Secret key**.
- Prefer one 1P item per app with all fields, mirrored into extra namespaces
  by additional OnePasswordItem CRs when needed (NetBox pattern).

## Chart specifics (verified)

- **Loki:** `bucketNames` lives at `loki.storage.bucketNames` (sibling of
  `s3:`), not nested inside it.
- **kube-prometheus-stack:** `kubeCoreDns.enabled: false` required (kube-system
  forbidden by the AppProject); k3s control-plane component monitors all
  disabled; Alertmanager disabled.
- **NetBox** (chart `netbox-community/netbox` 5.0.0-beta.145): dedicated
  postgres in `db-netbox` (Bitnami chart provisions only one user at init —
  isolation beats superuser hacks); shared redis in `db-redis`.
  `superuser.existingSecret` reads hardcoded keys (`username`, `password`,
  `email`, `api_token`) with NO key-override option; top-level
  `existingSecret` reads `secret_key`, `email_password`, `ldap_bind_password`;
  `externalDatabase.*` and `tasksRedis`/`cachingRedis.*` DO accept
  `existingSecretKey` (use `db-password` / `redis-password`).
- **1P items:** `HomeLab/k3s-observability-minio` (rootUser, rootPassword,
  lokiSecretKey), `HomeLab/Grafana`, `HomeLab/NetBox` (all NetBox creds in one
  item).

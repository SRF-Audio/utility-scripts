---
name: Hetzner NetBox Deployment
description: NetBox IPAM deployed on Hetzner cluster; architecture, secret structure, and lessons from coachlight debugging
type: project
originSessionId: 37a26656-de7b-48fe-aecb-5899648febcb
---
NetBox deployed on Hetzner cluster as of 2026-04-21. Not yet live (pending commit/push + ArgoCD sync). Coachlight instance is live and healthy.

**Why:** NetBox is the IPAM/infrastructure management tool for both clusters.

**How to apply:** Reference this when deploying or troubleshooting NetBox on Hetzner.

---

## Architecture

| Component | Detail |
|---|---|
| ArgoCD project | `hetzner-infra` |
| Namespace | `infra-netbox` |
| Chart | `netbox-community/netbox` version `5.0.0-beta.145` |
| Storage | `local-path-retain` |
| PostgreSQL | Dedicated instance `netbox-postgres` in `db-netbox` (NOT shared with paperless) |
| Redis | Shared `redis-master.db-redis.svc.cluster.local` |
| Ingress | Tailscale, `netbox-hetzner.rohu-shark.ts.net` |

**Why dedicated postgres:** Bitnami chart only provisions one user at init time. Adding a second user requires superuser access which isn't available without `enablePostgresUser: true`. Isolated instance is cleaner.

## Files

- `hetzner/argocd/apps/platform/netbox-secrets.yml` — wave 10, deploys 1P CRD to `infra-netbox`
- `hetzner/argocd/apps/platform/netbox-postgres-secrets.yml` — wave 10, mirrors 1P CRD to `db-netbox`
- `hetzner/argocd/apps/platform/netbox-postgres.yml` — wave 20, dedicated postgres
- `hetzner/argocd/apps/platform/netbox.yml` — wave 30, NetBox helm app
- `hetzner/k8s/netbox/onepassword-netbox.yml` — OnePasswordItem → `netbox` secret in `infra-netbox`
- `hetzner/k8s/netbox-db-secret/onepassword-netbox-db.yml` — mirrors same item into `db-netbox`

## 1Password item: "NetBox" in HomeLab vault

All credentials in one item. Required fields (operator uses field ID as Secret key):

| Field | Purpose |
|---|---|
| `username` | Superuser username |
| `password` | Superuser password |
| `email` | Superuser email |
| `api_token` | Superuser API token |
| `secret_key` | Django SECRET_KEY (50+ chars) |
| `email_password` | SMTP password — set to `placeholder` if unused (operator skips empty fields) |
| `ldap_bind_password` | LDAP password — set to `placeholder` if unused |
| `db-password` | PostgreSQL password |
| `redis-password` | Redis password |

**Critical:** The 1Password operator does NOT emit Secret keys for empty-value fields. `email_password` and `ldap_bind_password` must have non-empty values (e.g. `placeholder`) or the pod will fail to mount with `couldn't find key email_password in Secret`.

## Chart secret field mapping (verified against chart 5.0.0-beta.145)

- `superuser.existingSecret: netbox` — reads `username`, `password`, `email`, `api_token` by hardcoded key names. There is NO `existingSecretKey` companion for superuser — any such field is silently ignored.
- `existingSecret: netbox` (top-level) — reads `secret_key`, `email_password`, `ldap_bind_password` by hardcoded key names.
- `externalDatabase.existingSecretName/existingSecretKey` — these DO take key overrides; use `db-password`.
- `tasksRedis/cachingRedis.existingSecretName/existingSecretKey` — same pattern; use `redis-password`.

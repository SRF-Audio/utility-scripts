# Leantime Deployment via ArgoCD

This deployment follows the GitOps-first pattern using ArgoCD to deploy Leantime directly from its upstream Git repository.

## Overview

- **Application**: Leantime - Project management for lean teams
- **Deployment Method**: ArgoCD Helm-from-Git
- **Upstream Repo**: https://github.com/Leantime/leantime.git
- **Chart Version**: v3.6.0 (pinned)
- **Namespace**: apps-leantime
- **Access**: Tailscale-only via Ingress
- **Secrets**: 1Password Operator

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  ArgoCD Root App (argocd/root.yml)                          │
│  Discovers all apps in argocd/apps/** recursively           │
└─────────────────────────────────────────────────────────────┘
                            │
      ┌─────────────────────┼─────────────────────┐
      │                     │                     │
      ▼                     ▼                     ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ leantime-     │   │ leantime      │   │ leantime-     │
│ secrets       │   │               │   │ ingress       │
│ (wave 10)     │   │ (wave 20)     │   │ (wave 30)     │
└───────────────┘   └───────────────┘   └───────────────┘
      │                     │                     │
      │                     │                     │
      ▼                     ▼                     ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ 1Password     │   │ Helm Chart    │   │ Tailscale     │
│ Operator      │   │ from Git      │   │ Ingress       │
│ creates       │   │ leantime/     │   │ + Homepage    │
│ Secrets       │   │ leantime.git  │   │ annotations   │
└───────────────┘   └───────────────┘   └───────────────┘
```

## Files Created

### ArgoCD Applications
- `argocd/apps/apps/leantime-secrets.yml` - Deploys 1Password CRDs (sync-wave 10)
- `argocd/apps/apps/leantime.yml` - Deploys Leantime Helm chart (sync-wave 20)
- `argocd/apps/apps/leantime-ingress.yml` - Deploys Tailscale ingress (sync-wave 30)

### Kubernetes Manifests
- `k8s/leantime_secrets/` - OnePasswordItem CRDs and kustomization
  - `onepassword-db.yml` - Database credentials
  - `onepassword-app.yml` - App secrets (reserved for future use)
  - `kustomization.yml` - Kustomize manifest
  - `README.md` - Setup instructions

- `k8s/leantime_ingress/` - Tailscale ingress with Homepage annotations
  - `ingress.yml` - Ingress resource

## Prerequisites

Before deploying, ensure the following are in place:

1. **ArgoCD** is installed and the root app is configured
2. **Tailscale Operator** is deployed and configured
3. **1Password Operator** is deployed and configured
4. **1Password Items** are created in the HomeLab vault:
   - Item: `Leantime Database` with fields:
     - `mariadb-root-password`
     - `mariadb-password`
   - Item: `Leantime App Secrets` (can be empty for now)

5. **Storage Class** `nfs-synology-retain` is available in the cluster

## Deployment Details

### Secrets (Sync-Wave 10)

The `leantime-secrets` application deploys OnePasswordItem CRDs that reference items in 1Password. The 1Password Operator materializes these as Kubernetes Secrets:

- `leantime-db`: Contains MariaDB credentials
- `leantime-app`: Reserved for future app-level secrets

### Application (Sync-Wave 20)

The `leantime` application uses ArgoCD's Helm-from-Git feature to render the chart directly from the upstream repository:

**Source Configuration**:
- Repository: `https://github.com/Leantime/leantime.git`
- Revision: `v3.6.0` (immutable tag)
- Path: `helm`

**Key Helm Values**:
- Image tag pinned to `3.6.0`
- Persistence enabled with `nfs-synology-retain` storage class (10Gi)
- Built-in ingress disabled
- MariaDB subchart configured to use `existingSecret: leantime-db`
- Session password set to a generated secure value

**Chart Limitations**:
The upstream Leantime chart does not support `existingSecret` for application-level secrets (session password, SMTP). The session password is therefore included in the Helm values as a generated secure random value. Database credentials properly use the MariaDB subchart's `existingSecret` feature.

### Ingress (Sync-Wave 30)

The `leantime-ingress` application deploys a Tailscale Ingress that:

- Uses `ingressClassName: tailscale`
- Exposes Leantime at `leantime.rohu-shark.ts.net` (MagicDNS)
- Routes to the Leantime service on port 80
- Includes Homepage annotations for service discovery:
  - Name: "Leantime"
  - Group: "Apps"
  - Icon: "leantime.png"

## Access

Once deployed, Leantime will be accessible only from devices on your Tailnet at:

**URL**: https://leantime.rohu-shark.ts.net/

The service will also appear on your Homepage dashboard in the "Apps" group.

## Security

- ✅ No secrets in Git
- ✅ Database credentials managed by 1Password
- ✅ No public ingress (Tailscale-only)
- ✅ Immutable upstream version pinned (v3.6.0)
- ⚠️  Session password in Helm values (chart limitation)

## Verification

After ArgoCD syncs all three applications:

```bash
# Check ArgoCD application status
kubectl get applications -n argocd | grep leantime

# Check secrets created by 1Password Operator
kubectl get secrets -n apps-leantime

# Check the Leantime deployment
kubectl get deployments -n apps-leantime

# Check the MariaDB statefulset
kubectl get statefulsets -n apps-leantime

# Check the Tailscale ingress
kubectl get ingress -n apps-leantime

# Check Tailscale proxy device
kubectl get pods -n apps-leantime | grep ts-
```

All applications should show as `Synced` and `Healthy` in ArgoCD.

## Troubleshooting

### Application won't sync
- Verify 1Password items exist in the HomeLab vault
- Check ArgoCD application events: `kubectl describe application leantime -n argocd`

### Database connection issues
- Verify secrets were created: `kubectl get secrets -n apps-leantime`
- Check secret keys: `kubectl get secret leantime-db -n apps-leantime -o yaml`
- Ensure keys `mariadb-root-password` and `mariadb-password` are present

### Ingress not accessible
- Verify Tailscale Operator is running
- Check ingress status: `kubectl describe ingress leantime -n apps-leantime`
- Look for Tailscale proxy pod: `kubectl get pods -n apps-leantime`
- Check MagicDNS resolution from a Tailnet device

## Future Improvements

1. If the upstream chart adds `existingSecret` support for app secrets, update to use `leantime-app` secret
2. Consider enabling SMTP for email notifications (would need additional 1Password fields)
3. Evaluate S3 storage for user files instead of NFS PVCs

# Coachlight Infra Stack Playbook Refactoring Summary

## Overview

The `coachlight-infra-stack.yml` playbook has been refactored from a monolithic deployment script into a "bootstrap then stop" pattern, where Ansible only bootstraps the essential infrastructure, and ArgoCD manages all subsequent deployments via GitOps.

## What Changed

### Before
The playbook deployed:
1. ArgoCD
2. OnePassword Operator
3. GitHub repo configuration
4. **Tailscale Operator** (via templated Ansible role)
5. **NFS Provisioner** (via direct k8s_object_manager)
6. **Cluster Primitives** (via direct k8s_object_manager)
7. **Synology CSI** (via templated Ansible role)
8. **Homepage** (via templated Ansible role with token generation)
9. **Crafty Controller** (via templated Ansible role)
10. **Omada Controller** (via templated Ansible role)
11. **PostgreSQL + secrets** (via direct k8s_object_manager)
12. **Redis + secrets** (via direct k8s_object_manager)
13. **Paperless-NGX** (via templated Ansible role)
14. k9s installation

### After
The playbook now only:
1. Retrieves kubeconfig from k3s cluster
2. Manages kubeconfig locally
3. Validates k8s cluster connectivity
4. Adds control-plane taints
5. Deploys ArgoCD (via `argocd_deploy` role)
6. Deploys OnePassword Operator (via `onepassword_operator_deploy` role)
7. Creates GitHub repo configuration (via `argocd_github_repo_create` role)
8. **Applies the Root ArgoCD Application** (via `k8s_object_manager` → `argocd/root.yml`)

All other applications are now managed by ArgoCD through the App-of-Apps pattern.

## New Directory Structure

```
argocd/
├── root.yml                          # Root App-of-Apps
├── projects/                         # Argo CD Projects
│   ├── coachlight-k3s-infra-project.yml
│   ├── coachlight-k3s-apps-project.yml
│   ├── coachlight-k3s-db-project.yml
│   └── coachlight-k3s-observability-project.yml
└── apps/                             # Child Applications
    ├── operators/                    # Wave 0: Operators & CRDs
    │   ├── argocd-projects.yml
    │   └── tailscale-operator.yml
    ├── platform/                     # Waves 10-20: Platform Services
    │   ├── postgres-secrets.yml      # Wave 10
    │   ├── redis-secrets.yml         # Wave 10
    │   ├── nfs-provisioner.yml       # Wave 20
    │   ├── cluster-primitives.yml    # Wave 20
    │   ├── synology-csi.yml          # Wave 20
    │   ├── postgres.yml              # Wave 20
    │   ├── redis.yml                 # Wave 20
    │   ├── homepage.yml              # Wave 30
    │   └── omada-controller.yml      # Wave 30
    └── apps/                         # Waves 10-30: Application Workloads
        ├── paperless-ngx-secrets.yml # Wave 10
        ├── crafty-controller.yml     # Wave 30
        └── paperless-ngx.yml         # Wave 30
```

## Sync Wave Strategy

The refactoring implements a strict dependency-based sync wave ordering:

- **Wave 0**: Core operators and projects (deployed before secrets)
  - Argo CD projects
  - Tailscale operator (once credentials are migrated to OnePassword)

- **Wave 10**: Secrets settlement
  - All OnePasswordItem CRDs
  - Ensures secrets exist before anything tries to consume them

- **Wave 20**: Platform services
  - Infrastructure services that may depend on secrets
  - Storage provisioners, databases, caches

- **Wave 30**: Application workloads
  - User-facing applications
  - Services that consume platform services

## Applications Status

| Application | Status | Notes |
|-------------|--------|-------|
| **Argo CD Projects** | ✅ Ready | Wave 0 |
| **NFS Provisioner** | ✅ Ready | Wave 20, no secrets |
| **Cluster Primitives** | ✅ Ready | Wave 20, storage classes |
| **PostgreSQL** | ✅ Ready | Waves 10 & 20, uses existing OnePassword CRDs |
| **Redis** | ✅ Ready | Waves 10 & 20, uses existing OnePassword CRDs |
| **Crafty Controller** | ✅ Ready | Wave 30, uses existing OnePassword CRDs |
| **Paperless-NGX** | ✅ Ready | Waves 10 & 30, uses existing OnePassword CRDs |
| **Omada Controller** | ✅ Ready | Wave 30, no secrets |
| **Tailscale Operator** | ⚠️ Needs Migration | Wave 0, requires OAuth creds via OnePassword |
| **Synology CSI** | ⚠️ Needs Migration | Wave 20, requires NAS creds via OnePassword |
| **Homepage** | ⚠️ Needs Migration | Wave 30, requires API tokens via OnePassword |

## Migration Notes

Three applications require OnePassword CRD setup before they can be enabled:

1. **Tailscale Operator**: Needs `tailscale_oauth_client_id` and `tailscale_oauth_client_secret`
2. **Synology CSI**: Needs NAS host, username, password, and storage path
3. **Homepage**: Needs NextDNS API token, Proxmox API password, and ArgoCD token

See `docs/onepassword-migration-notes.md` for detailed migration instructions.

## Benefits

1. **GitOps-first**: All application deployments are now declarative and version-controlled
2. **Simplified Bootstrap**: Ansible only handles cluster setup and core infrastructure
3. **Automated Sync**: ArgoCD continuously reconciles desired state from Git
4. **Clear Dependencies**: Sync waves enforce proper deployment ordering
5. **Self-Healing**: ArgoCD automatically corrects drift
6. **Centralized Management**: Single root app manages all child applications

## Rollback Strategy

If issues arise, you can:
1. Delete the root application: `kubectl delete application root -n argocd`
2. Manually apply individual applications as needed
3. Or revert to the previous commit and redeploy via Ansible

## Testing Recommendations

1. Test in a dev cluster first
2. Verify sync wave ordering works correctly
3. Check that secrets are created before consuming applications
4. Validate that all applications reach "Healthy" and "Synced" status
5. Test the full bootstrap flow from scratch

## Next Steps

1. Complete OnePassword CRD migration for the three pending applications
2. Test bootstrap flow in development environment
3. Document any additional findings or adjustments needed
4. Consider removing unused Ansible roles after verifying GitOps works

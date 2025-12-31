# ArgoCD vs Ansible Deploy Roles Audit

This document audits all `*_deploy` roles in `ansible/roles/` against ArgoCD Application manifests in `argocd/` to determine which roles are redundant and can be deleted, which need corresponding Argo apps created, and which should be kept.

**Audit Date:** 2025-12-31  
**Scope:** All roles ending in `_deploy`, excluding `argocd_deploy` and `onepassword_operator_deploy` (bootstrap roles)

---

## Summary

| Status | Count | Roles |
|--------|-------|-------|
| **DELETE ROLE** | 2 | `crafty_controller_deploy`, `nfs_provisioner_deploy` |
| **CREATE ARGO APP** | 3 | `frigate_deploy`, `netbox_deploy`, `velero_deploy` |
| **KEEP ROLE** | 4 | `homepage_deploy`, `omada_deploy`, `paperless_ngx_deploy`, `tailscale_operator_deploy` |
| **OUT OF SCOPE** | 1 | `synology_csi_deploy` |

---

## Detailed Analysis

### crafty_controller_deploy

**Role Path:** `ansible/roles/crafty_controller_deploy`

**Corresponding Argo Manifest(s):**
- `argocd/apps/apps/crafty-controller.yml` ✅

**What the role does:**
- Templates an ArgoCD Application manifest from `templates/application.yml.j2`
- Applies the manifest using `k8s_object_manager` role
- Waits for Application to be Synced and not Degraded
- Persists artifacts via `role_artifacts`

**Redundant?** **YES**

**Action:** **DELETE ROLE**

**Notes:**
- The ArgoCD manifest already exists at `argocd/apps/apps/crafty-controller.yml` and is functionally identical
- Role only templates variables that are static (namespace, project, repo URL, path) - all of which are already hardcoded in the existing Argo manifest
- No secrets management, no external resource creation
- No playbook references found

---

### homepage_deploy

**Role Path:** `ansible/roles/homepage_deploy`

**Corresponding Argo Manifest(s):**
- `argocd/apps/platform/homepage.yml` ✅

**What the role does:**
- Templates an ArgoCD Application manifest with sensitive values (NextDNS token, Proxmox password)
- Creates a Secret with ArgoCD homepage token (`homepage-argocd-secret.yml.j2`)
- Applies optional ingress templates from a configurable directory
- Persists artifacts via `role_artifacts`

**Redundant?** **NO**

**Action:** **KEEP ROLE**

**Notes:**
- Role templates sensitive credentials that cannot be in Git:
  - `homepage_nextdns_api_token`
  - `proxmox_api_password`
  - `argocd_homepage_token`
- The existing Argo manifest has placeholder empty strings for these secrets with TODO comments
- The role also handles optional ingress templates dynamically
- **Recommendation:** Eventually migrate secrets to OnePassword CRDs (as noted in the Argo manifest TODOs), then this role could be deleted

---

### nfs_provisioner_deploy

**Role Path:** `ansible/roles/nfs_provisioner_deploy`

**Corresponding Argo Manifest(s):**
- `argocd/apps/platform/nfs-provisioner.yml` ✅

**What the role does:**
- Validates that ArgoCD Application manifest exists at a static path
- Validates that StorageClass manifests exist at static paths
- Applies the ArgoCD Application manifest
- Waits for Application to become Healthy and Synced
- Persists artifacts via `role_artifacts`

**Redundant?** **YES**

**Action:** **DELETE ROLE**

**Notes:**
- The ArgoCD manifest already exists and is static
- Role only validates file existence and applies manifest - no templating, no secrets, no resource creation
- The StorageClass manifests it validates are separate from this role and already exist in `k8s/storageclasses/`
- No playbook references found

---

### omada_deploy

**Role Path:** `ansible/roles/omada_deploy`

**Corresponding Argo Manifest(s):**
- `argocd/apps/platform/omada-controller.yml` ✅

**What the role does:**
- Templates an ArgoCD Application manifest with configurable storage classes, service type, and Tailscale annotations
- Discovers and applies optional ingress templates from a configurable directory
- Persists artifacts via `role_artifacts`

**Redundant?** **NO**

**Action:** **KEEP ROLE**

**Notes:**
- While the Argo manifest exists, the role provides significant flexibility:
  - Configurable storage classes for data and logs
  - Configurable service type
  - Configurable Tailscale annotations and hostname
  - Dynamic ingress template discovery and application
  - Support for values overrides
- The static Argo manifest has hardcoded values that may not suit all deployments
- The role appears to be used for deployment flexibility across different environments
- **Recommendation:** Consider whether the static Argo manifest should be the source of truth, or if this flexibility is needed

---

### paperless_ngx_deploy

**Role Path:** `ansible/roles/paperless_ngx_deploy`

**Corresponding Argo Manifest(s):**
- `argocd/apps/apps/paperless-ngx.yml` ✅
- `argocd/apps/apps/paperless-ngx-secrets.yml` ✅

**What the role does:**
- Templates two ArgoCD Application manifests: one for secrets, one for main app
- Applies secrets Application first, then main Application
- Waits for both Applications to be synced and healthy
- Waits specifically for the webserver Deployment to have available replicas
- Persists artifacts via `role_artifacts`

**Redundant?** **NO**

**Action:** **KEEP ROLE**

**Notes:**
- Both Argo manifests exist in GitOps
- However, the role orchestrates a specific deployment sequence:
  1. Secrets app must deploy and be Healthy first
  2. Then main app deploys
  3. Then waits for specific Deployment readiness
- This orchestration logic is important for ensuring secrets are available before the app starts
- The role provides deployment sequencing that ArgoCD's sync-waves might not fully replace (especially the Deployment-level wait)
- **Recommendation:** Evaluate if ArgoCD sync-waves and health checks are sufficient, or if this orchestration is still needed

---

### tailscale_operator_deploy

**Role Path:** `ansible/roles/tailscale_operator_deploy`

**Corresponding Argo Manifest(s):**
- `argocd/apps/operators/tailscale-operator.yml` ✅
- `argocd/apps/operators/tailscale-operator-secrets.yml` ✅

**What the role does:**
- Templates ArgoCD Application manifest with OAuth client credentials
- Applies manifest using `k8s_object_manager`
- Persists artifacts via `role_artifacts`

**Redundant?** **NO**

**Action:** **KEEP ROLE**

**Notes:**
- Role templates sensitive OAuth credentials that cannot be in Git:
  - `tailscale_operator_deploy_oauth_client_id`
  - `tailscale_operator_deploy_oauth_client_secret`
- The existing Argo manifest uses a different approach: it references a Secret (`tailscale-operator-oauth`) that must exist
- The secrets Application (`tailscale-operator-secrets.yml`) points to `k8s/tailscale_operator/onepassword/` which likely contains OnePasswordItem CRDs
- **Current state:** The role templates credentials into the Application manifest, while the GitOps approach uses OnePassword CRDs
- **Recommendation:** Once OnePassword secrets are fully working, this role can be deleted in favor of the GitOps manifests

---

### frigate_deploy

**Role Path:** `ansible/roles/frigate_deploy`

**Corresponding Argo Manifest(s):**
- **MISSING** ❌

**What the role does:**
- Templates a Frigate ArgoCD Application manifest with storage classes, Tailscale configuration, and ingress settings
- Templates a separate Homepage ingress manifest
- Applies both manifests using `k8s_object_manager`
- Supports configurable Helm chart values and overrides
- Persists artifacts via `role_artifacts`

**Redundant?** N/A (no Argo app exists)

**Action:** **CREATE ARGO APP**

**Notes:**
- No ArgoCD Application manifest exists in `argocd/apps/` for Frigate
- The role templates significant configuration:
  - Helm chart repo: configurable
  - Storage classes for Longhorn (config) and Synology (media)
  - Tailscale service annotations and ingress
  - Dynamic values overrides
- **Required work:**
  1. Create `argocd/apps/apps/frigate.yml` with appropriate configuration
  2. Determine if values should be hardcoded or if flexibility is needed (e.g., for secrets or environment-specific config)
  3. If hardcoded, the role can be deleted after Argo app creation
  4. The Homepage ingress is specific and may need to remain in the role or be moved to a separate Argo app

---

### netbox_deploy

**Role Path:** `ansible/roles/netbox_deploy`

**Corresponding Argo Manifest(s):**
- **MISSING** ❌

**What the role does:**
- Templates a NetBox ArgoCD Application manifest with sensitive credentials (superuser password, secret key)
- Templates a Homepage ingress manifest
- Applies both manifests using `k8s_object_manager`
- Cleans up temporary directory after deployment
- Persists artifacts via `role_artifacts`

**Redundant?** N/A (no Argo app exists)

**Action:** **CREATE ARGO APP**

**Notes:**
- No ArgoCD Application manifest exists in `argocd/apps/` for NetBox
- The role templates **sensitive credentials** that cannot be in Git:
  - `netbox_deploy_superuser_password`
  - `netbox_deploy_secret_key`
- **Required work:**
  1. Create `argocd/apps/platform/netbox.yml` (main app)
  2. Create `argocd/apps/platform/netbox-secrets.yml` pointing to OnePasswordItem CRDs
  3. Create OnePasswordItem CRDs in `k8s/netbox/onepassword/` for superuser password and secret key
  4. After OnePassword secrets are working, the role can be deleted
  5. The Homepage ingress should be moved to a k8s manifest or remain as optional Ansible templating

---

### velero_deploy

**Role Path:** `ansible/roles/velero_deploy`

**Corresponding Argo Manifest(s):**
- **MISSING** ❌

**What the role does:**
- Templates a Velero ArgoCD Application manifest with:
  - CSI plugin configuration
  - Backup storage location (provider, bucket, config)
  - Volume snapshot location (provider, config)
- Applies manifest using `k8s_object_manager`
- Cleans up temporary directory after deployment
- Persists artifacts via `role_artifacts`

**Redundant?** N/A (no Argo app exists)

**Action:** **CREATE ARGO APP**

**Notes:**
- No ArgoCD Application manifest exists in `argocd/apps/` for Velero
- The role templates complex configuration:
  - CSI plugin version
  - Backup storage provider configuration (potentially sensitive)
  - Snapshot location configuration
- **Required work:**
  1. Determine if storage provider credentials are sensitive (likely yes for S3/cloud storage)
  2. If sensitive: Create `argocd/apps/platform/velero.yml` and `argocd/apps/platform/velero-secrets.yml`
  3. If not sensitive or using workload identity: Create single `argocd/apps/platform/velero.yml`
  4. The role may need to be kept if storage config is environment-specific and cannot be hardcoded

---

### synology_csi_deploy

**Role Path:** `ansible/roles/synology_csi_deploy`

**Corresponding Argo Manifest(s):**
- **MISSING** ❌ (no match in `argocd/apps/`)

**What the role does:**
- Templates a Synology CSI ArgoCD Application manifest with:
  - NAS host IP from inventory (`groups['synology_nas']`)
  - NAS credentials (`k3s_synology_csi_nas_username`, `k3s_synology_csi_nas_password`)
  - Storage class configuration
- Applies manifest using `k8s_object_manager`
- Cleans up temporary directory
- Persists artifacts via `role_artifacts`

**Redundant?** N/A (no Argo app exists)

**Action:** **OUT OF SCOPE**

**Notes:**
- This role does NOT follow the naming pattern of other deploy roles (it's infrastructure/storage, not an "app")
- It templates **sensitive credentials** (NAS username/password)
- It dynamically queries inventory for the NAS IP address
- **This is infrastructure provisioning, not app deployment** - it's more similar to `argocd_deploy` and `onepassword_operator_deploy` in nature
- **Recommendation:** Leave this role as-is. It's a infrastructure bootstrap role, not an "app deploy" role. If Argo app is desired:
  1. Create `argocd/apps/platform/synology-csi.yml` and `argocd/apps/platform/synology-csi-secrets.yml`
  2. Create OnePasswordItem CRDs for NAS credentials
  3. Role would still be needed to handle inventory lookups unless those are also moved to OnePassword or ConfigMaps

---

## Actions Required

### 1. Delete Redundant Roles

- [ ] Delete `ansible/roles/crafty_controller_deploy/`
- [ ] Delete `ansible/roles/nfs_provisioner_deploy/`
- [ ] Remove any playbook references (none found in initial search)

### 2. Create Missing Argo Applications

#### Frigate
- [ ] Create `argocd/apps/apps/frigate.yml` with:
  - Chart: blakeblackshear/frigate (or appropriate repo)
  - Storage configuration for Longhorn and optionally Synology
  - Tailscale service and ingress configuration
- [ ] Decide if secrets are needed (if yes, create `frigate-secrets.yml` + OnePassword CRDs)
- [ ] Evaluate if `frigate_deploy` role can be deleted after Argo app exists

#### NetBox
- [ ] Create `argocd/apps/platform/netbox.yml` with base configuration
- [ ] Create `argocd/apps/platform/netbox-secrets.yml` pointing to OnePassword CRDs
- [ ] Create `k8s/netbox/onepassword/` directory with OnePasswordItem CRDs for:
  - Superuser password
  - Secret key
- [ ] Test OnePassword integration before deleting role
- [ ] Handle Homepage ingress separately or in role

#### Velero
- [ ] Assess if backup storage credentials are sensitive
- [ ] Create `argocd/apps/platform/velero.yml` (and optionally `velero-secrets.yml`)
- [ ] If using S3/cloud storage, create OnePasswordItem CRDs for credentials
- [ ] If using workload identity, no secrets needed
- [ ] Evaluate if `velero_deploy` role can be deleted or must be kept for environment-specific config

### 3. Future Migrations (Keep Roles for Now)

These roles should be kept until secrets are migrated to OnePassword CRDs:

#### Homepage
- [ ] Migrate NextDNS API token to OnePasswordItem CRD
- [ ] Migrate Proxmox API password to OnePasswordItem CRD
- [ ] Migrate ArgoCD homepage token to OnePasswordItem CRD
- [ ] Update `argocd/apps/platform/homepage.yml` to reference secrets
- [ ] Then delete `homepage_deploy` role

#### Tailscale Operator
- [ ] Verify OnePassword secrets in `k8s/tailscale_operator/onepassword/` are working
- [ ] Verify `argocd/apps/operators/tailscale-operator.yml` correctly references secret
- [ ] Then delete `tailscale_operator_deploy` role

#### Paperless NGX
- [ ] Verify the deployment orchestration (secrets → main app → wait for deployment) can be fully replaced by ArgoCD sync-waves and health checks
- [ ] Then delete `paperless_ngx_deploy` role

#### Omada Controller
- [ ] Decide if deployment flexibility (storage classes, service types, dynamic ingress) is truly needed
- [ ] If not needed, hardcode values in `argocd/apps/platform/omada-controller.yml`
- [ ] Then delete `omada_deploy` role

---

## References

- **ArgoCD Apps:** `argocd/apps/{apps,operators,platform}/*.yml`
- **ArgoCD Projects:** `argocd/projects/*.yml`
- **Kubernetes Manifests:** `k8s/*/`
- **OnePassword Secrets Pattern:** `k8s/<app>/onepassword/*.yml` (OnePasswordItem CRDs)
- **Role Artifacts Pattern:** All deploy roles call `role_artifacts` to persist outputs

---

## Lessons Learned / Patterns

1. **Secrets Management:** Roles that template sensitive credentials must be kept until OnePassword CRDs are in place
2. **Static vs Dynamic Config:** Roles that only template static configuration (namespace, repo, path) are redundant
3. **Deployment Orchestration:** Roles that provide specific deployment sequencing (e.g., secrets before app) may still be valuable
4. **Ingress Flexibility:** Several roles support dynamic ingress templating from configurable directories - this is a pattern to consider preserving or replacing
5. **Infrastructure vs Apps:** Infrastructure/bootstrap roles (CSI, operators) are different from app deploy roles and should be evaluated separately


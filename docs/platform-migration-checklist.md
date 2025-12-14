# Platform Migration Checklist

**Date:** 2025-12-14  
**Purpose:** Actionable migration plan to align Coachlight k3s deployment with GitOps + 1Password/Tailscale/Homepage conventions

---

## Overview

This checklist provides a phased approach to migrating from the current hybrid deployment model to a fully GitOps-compliant structure. Each item includes:
- **What to change** (description)
- **Where to change it** (file paths and line numbers)
- **Done criteria** (verification commands)

---

## Phase 1: Argo CD Bootstrap Correctness

### ✅ 1.1 Verify Argo CD installation source

**Current State:**  
Argo CD is installed from upstream manifest URL.

**File:** `ansible/roles/argocd_deploy/defaults/main.yml`  
**What to change:** Confirm `argocd_deploy_manifest_src` points to correct version.

**Done Criteria:**
```bash
kubectl get pods -n argocd
kubectl get applications -n argocd
```

---

### ☐ 1.2 Migrate Argo CD Projects to k8s/argocd/

**Current State:**  
Argo CD Projects are in `ansible/roles/argocd_deploy/files/*.yml` and applied by Ansible.

**Files to migrate:**
- `ansible/roles/argocd_deploy/files/coachlight-k3s-infra-project.yml`
- `ansible/roles/argocd_deploy/files/coachlight-k3s-apps-project.yml`
- `ansible/roles/argocd_deploy/files/coachlight-k3s-db-project.yml`
- `ansible/roles/argocd_deploy/files/coachlight-k3s-observability-project.yml`
- `ansible/roles/argocd_deploy/files/argocd-server-tailscale-servicepatch.yml`
- `ansible/roles/argocd_deploy/files/argocd-rbac-homepage-readonly.yml`

**What to change:**
1. Create `k8s/argocd/` directory
2. Move the above files to `k8s/argocd/`
3. Create `k8s/argocd/kustomization.yaml` to reference them
4. Update `argocd_deploy` role to apply `k8s/argocd/` directory instead of individual files

**Done Criteria:**
```bash
ls k8s/argocd/
kubectl get appprojects -n argocd
kubectl get configmap argocd-cm -n argocd -o yaml | grep -i github
kubectl get clusterrolebinding argocd-homepage-readonly
```

---

### ☐ 1.3 Create App-of-Apps pattern (optional)

**Current State:**  
Each app is deployed by a separate Ansible role.

**What to change:**
1. Create `k8s/argocd/root-application.yml` that references all app directories
2. Update `argocd_deploy` role to apply root Application
3. Child Applications would be in their respective `k8s/<app>/application.yml` files

**Note:** This is optional and depends on preference. Current approach (Ansible creates each Application) is acceptable if all Applications are in GitOps structure.

**Done Criteria:**
```bash
kubectl get application root -n argocd
kubectl get applications -n argocd | wc -l  # Should show all apps
```

---

## Phase 2: 1Password Operator Adoption

### ☐ 2.1 Bootstrap 1Password Operator with minimal secrets

**Current State:**  
1Password Operator receives `connect.credentials` and `operator.token.value` as plaintext in Helm values.

**Problem:** This is a bootstrapping chicken-and-egg problem. The operator **must** be seeded with initial credentials to start.

**What to change:**
1. Accept that **initial bootstrap** of 1Password Connect credentials and operator token will come from Ansible (unavoidable)
2. Document this exception clearly
3. Consider storing these in a separate, minimal Secret (not in Helm values) if Helm chart supports `existingSecret`

**Files:**
- `ansible/roles/onepassword_operator_deploy/templates/application.yml.j2` (lines 14-38)

**Done Criteria:**
```bash
kubectl get pods -n infra-1password-operator
kubectl get onepassworditems -n infra-1password-operator  # Should show test item if created
kubectl logs -n infra-1password-operator -l app.kubernetes.io/name=connect-api | grep "successfully"
```

---

### ☐ 2.2 Create OnePasswordItem CRDs for Tailscale Operator secrets

**Current State:**  
Tailscale OAuth credentials are in Helm values (plaintext).

**What to change:**
1. Create `k8s/tailscale_operator_secrets/` directory
2. Create `k8s/tailscale_operator_secrets/onepassworditem.yml`:
   ```yaml
   apiVersion: onepassword.com/v1
   kind: OnePasswordItem
   metadata:
     name: tailscale-oauth
     namespace: infra-tailscale-operator
   spec:
     itemPath: "vaults/HomeLab/items/Tailscale"
   ```
3. Create `k8s/tailscale_operator_secrets/application.yml` (Argo Application to deploy the OnePasswordItem)
4. Update `ansible/roles/tailscale_operator_deploy/templates/infra-tailscale-operator.yml.j2`:
   - Remove `oauth.clientId` and `oauth.clientSecret` from valuesObject
   - Add `oauth.existingSecret: tailscale-oauth` (if chart supports it)
5. Update `tailscale_operator_deploy` role to apply both secrets Application and operator Application

**Files:**
- Create: `k8s/tailscale_operator_secrets/onepassworditem.yml`
- Create: `k8s/tailscale_operator_secrets/application.yml`
- Modify: `ansible/roles/tailscale_operator_deploy/templates/infra-tailscale-operator.yml.j2` (lines 14-16)

**Done Criteria:**
```bash
kubectl get onepassworditems -n infra-tailscale-operator
kubectl get secret tailscale-oauth -n infra-tailscale-operator
kubectl describe secret tailscale-oauth -n infra-tailscale-operator | grep "client-id\|client-secret"
kubectl get pods -n infra-tailscale-operator -l app=operator  # Should be Running
```

---

### ☐ 2.3 Create OnePasswordItem CRDs for Synology CSI secrets

**Current State:**  
Synology NAS credentials are in Helm values (plaintext).

**What to change:**
1. Create `k8s/synology_csi_secrets/` directory
2. Create `k8s/synology_csi_secrets/onepassworditem.yml`:
   ```yaml
   apiVersion: onepassword.com/v1
   kind: OnePasswordItem
   metadata:
     name: synology-nas-credentials
     namespace: infra-synology-csi
   spec:
     itemPath: "vaults/HomeLab/items/tpmiwkdnk3qafsg4u3r6l7simy"
   ```
3. Create `k8s/synology_csi_secrets/application.yml`
4. Update Synology CSI Helm values to reference `existingSecret` instead of inline credentials

**Files:**
- Create: `k8s/synology_csi_secrets/onepassworditem.yml`
- Create: `k8s/synology_csi_secrets/application.yml`
- Modify: `ansible/roles/synology_csi_deploy/templates/synology_csi.yml.j2` (lines 14-20)

**Done Criteria:**
```bash
kubectl get onepassworditems -n infra-synology-csi
kubectl get secret synology-nas-credentials -n infra-synology-csi
kubectl describe secret synology-nas-credentials -n infra-synology-csi | grep "username\|password"
kubectl get storageclass nfs-delete  # Should exist and be default
```

---

### ☐ 2.4 Create OnePasswordItem CRDs for Homepage secrets

**Current State:**  
NextDNS API token and Proxmox API password are in Helm values (plaintext).

**What to change:**
1. Create `k8s/homepage_secrets/` directory
2. Create multiple OnePasswordItem CRDs:
   - `k8s/homepage_secrets/onepassworditem-nextdns.yml` (NextDNS API token)
   - `k8s/homepage_secrets/onepassworditem-proxmox.yml` (Proxmox API password)
   - `k8s/homepage_secrets/onepassworditem-argocd.yml` (Argo CD token, if not already created by argocd_homepage_token)
3. Create `k8s/homepage_secrets/application.yml`
4. Update Homepage Helm values to remove plaintext secrets and reference Kubernetes Secrets created by OnePasswordItem CRDs

**Files:**
- Create: `k8s/homepage_secrets/onepassworditem-nextdns.yml`
- Create: `k8s/homepage_secrets/onepassworditem-proxmox.yml`
- Create: `k8s/homepage_secrets/onepassworditem-argocd.yml`
- Create: `k8s/homepage_secrets/application.yml`
- Modify: `ansible/roles/homepage_deploy/templates/homepage-application.yml.j2` (lines 27-42, 82-86)

**Done Criteria:**
```bash
kubectl get onepassworditems -n infra-homepage
kubectl get secrets -n infra-homepage | grep "nextdns\|proxmox\|argocd"
kubectl logs -n infra-homepage -l app.kubernetes.io/name=homepage | grep -i "error\|fail" | wc -l  # Should be 0 or minimal
```

---

### ☐ 2.5 Create OnePasswordItem CRDs for NetBox secrets

**Current State:**  
NetBox superuser password and secret key are in Helm values (plaintext).

**What to change:**
1. Create `k8s/netbox_secrets/` directory
2. Create `k8s/netbox_secrets/onepassworditem.yml` (single item with both fields, or separate items)
3. Create `k8s/netbox_secrets/application.yml`
4. Update NetBox Helm values to reference `existingSecret` (if chart supports it)

**Files:**
- Create: `k8s/netbox_secrets/onepassworditem.yml`
- Create: `k8s/netbox_secrets/application.yml`
- Modify: `ansible/roles/netbox_deploy/templates/netbox-application.yml.j2` (lines 14-18)

**Done Criteria:**
```bash
kubectl get onepassworditems -n netbox
kubectl get secret netbox-credentials -n netbox
kubectl get pods -n netbox -l app.kubernetes.io/name=netbox  # Should be Running
```

---

## Phase 3: Secrets Folder Normalization

### ☐ 3.1 Document secrets pattern for future apps

**What to change:**
1. Create `docs/secrets-management-pattern.md`
2. Document the standard pattern:
   - Helm chart apps: `k8s/<app>_secrets/onepassworditem.yml` → K8s Secret → `existingSecret` in Helm values
   - Static manifest apps: OnePasswordItem CRDs can live in `k8s/<app>/` (no separate `_secrets` folder required)
3. Include examples from completed migrations (Tailscale, Synology CSI, Homepage, NetBox)

**Done Criteria:**
- [ ] File `docs/secrets-management-pattern.md` exists
- [ ] Pattern is referenced in future deploy role templates

---

### ☐ 3.2 Create standard OnePasswordItem template for deploy roles

**What to change:**
1. Create `ansible/roles/onepassworditem_deploy/` (reusable role)
2. Template: `templates/onepassworditem.yml.j2`
3. Template: `templates/application.yml.j2` (for secrets Application)
4. Parameters:
   - `onepassworditem_deploy_name`
   - `onepassworditem_deploy_namespace`
   - `onepassworditem_deploy_item_path` (e.g., `vaults/HomeLab/items/MyApp`)
   - `onepassworditem_deploy_secret_name` (optional override)

**Done Criteria:**
```bash
ls ansible/roles/onepassworditem_deploy/
grep -r "onepassworditem_deploy" ansible/roles/*/tasks/main.yml | wc -l  # Should show usage in multiple roles
```

---

## Phase 4: Tailscale Exposure Normalization

### ☐ 4.1 Audit all Services for Tailscale annotations

**Current State:**  
Most Helm chart apps have Tailscale annotations. Need to verify consistency.

**What to change:**
1. Scan all Argo Application templates for `service.annotations` or similar
2. Ensure every app with a UI has:
   ```yaml
   tailscale.com/expose: "true"
   tailscale.com/hostname: "<app>"
   tailscale.com/tags: "tag:k8s,tag:<category>"
   ```
3. Document apps that should NOT be exposed via Tailscale (e.g., databases, internal-only services)

**Files to check:**
- `ansible/roles/*/templates/*-application.yml.j2`
- `k8s/*/application.yml` (once created)

**Done Criteria:**
```bash
kubectl get svc -A -o yaml | grep "tailscale.com/expose" | wc -l  # Should match expected count
kubectl get svc -A -o yaml | grep "tailscale.com/hostname" | sort -u
```

---

### ☐ 4.2 Standardize Tailscale tags across apps

**Current State:**  
Tags are inconsistent: `tag:k8s,tag:infra-monitoring`, `tag:k8s,tag:infra-gitops`, `tag:k8s,tag:server-games`, etc.

**What to change:**
1. Define standard tag categories:
   - `tag:k8s` (all k8s services)
   - `tag:infra-platform` (Argo CD, 1Password, Tailscale)
   - `tag:infra-storage` (Synology CSI, Longhorn)
   - `tag:infra-monitoring` (Homepage, Longhorn UI, NetBox)
   - `tag:apps-media` (Frigate)
   - `tag:apps-network` (Omada)
   - `tag:apps-games` (Crafty Controller)
   - `tag:apps-documents` (Paperless-NGX)
2. Update all Tailscale annotations to use standardized tags
3. Document in `docs/tailscale-tagging-scheme.md`

**Done Criteria:**
```bash
kubectl get svc -A -o yaml | grep "tailscale.com/tags" | sort -u
# Verify tags align with documented scheme
```

---

## Phase 5: Homepage Discovery Normalization

### ☐ 5.1 Audit all apps for Homepage dummy Ingress

**Current State:**  
Some apps have dummy Ingress via Homepage deploy role, some have it inline in Helm values, some are missing.

**What to change:**
1. Standardize on **inline dummy Ingress in Helm values** (if chart supports Ingress resource)
2. For apps without Ingress support, create external dummy Ingress in `k8s/<app>/homepage-ingress.yml`
3. Annotations required:
   ```yaml
   gethomepage.dev/enabled: "true"
   gethomepage.dev/name: "<App Display Name>"
   gethomepage.dev/description: "<Short description>"
   gethomepage.dev/group: "<Category>"
   gethomepage.dev/icon: "<icon-name>.png"
   ```

**Files to check:**
- All Argo Application templates
- `ansible/roles/homepage_deploy/templates/ingresses/`
- `ansible/roles/*/templates/*-homepage-ingress.yml.j2`

**Done Criteria:**
```bash
kubectl get ingress -A -o yaml | grep "gethomepage.dev/enabled" | wc -l  # Should match expected count
kubectl logs -n infra-homepage -l app.kubernetes.io/name=homepage | grep "Discovered" | wc -l  # Should show discoveries
```

---

### ☐ 5.2 Migrate Homepage Ingress templates to k8s/

**Current State:**  
Homepage role has `templates/ingresses/*.j2` that are applied dynamically.

**What to change:**
1. Migrate `ansible/roles/homepage_deploy/templates/ingresses/argocd-homepage-ingress.yml.j2` to `k8s/argocd/homepage-ingress.yml`
2. Render it once with Ansible, then treat as static manifest in GitOps
3. Alternatively, include it in Argo CD bootstrap manifests

**Files:**
- Move: `ansible/roles/homepage_deploy/templates/ingresses/argocd-homepage-ingress.yml.j2` → `k8s/argocd/homepage-ingress.yml`
- Update: `ansible/roles/homepage_deploy/tasks/main.yml` (lines 14-35) to remove dynamic Ingress discovery

**Done Criteria:**
```bash
ls k8s/argocd/homepage-ingress.yml
kubectl get ingress argocd-homepage -n argocd
```

---

## Phase 6: Remove Non-GitOps Apply Paths

### ☐ 6.1 Migrate Crafty Controller to Argo CD

**Current State:**  
`crafty_controller_deploy` applies raw manifests directly, bypassing Argo.

**What to change:**

**Option A: Migrate to static manifests in GitOps**
1. Create `k8s/crafty_controller/` directory
2. Move rendered manifests to static YAML files in `k8s/crafty_controller/`:
   - `namespace.yml`
   - `pvc-backups.yml`, `pvc-logs.yml`, `pvc-servers.yml`, `pvc-config.yml`, `pvc-import.yml`
   - `deployment.yml`
   - `service.yml`
   - `ingress.yml` (for Homepage discovery)
3. Move default.json Secret to `k8s/crafty_controller_secrets/onepassworditem.yml`
4. Create `k8s/crafty_controller/application.yml` (Argo Application pointing to `k8s/crafty_controller/`)
5. Update `crafty_controller_deploy` role to:
   - Only render OnePasswordItem (if password is in 1Password)
   - Apply Argo Application
   - Wait for Application to be Synced + Healthy

**Option B: Convert to Helm chart**
1. Create a custom Helm chart for Crafty Controller
2. Package chart and host in Git repo or chart registry
3. Create Argo Application that deploys the Helm chart
4. Handle secrets via `k8s/crafty_controller_secrets/onepassworditem.yml` → `existingSecret`

**Recommendation:** Option A (static manifests) is simpler for a custom app.

**Files:**
- Create: `k8s/crafty_controller/*.yml`
- Create: `k8s/crafty_controller_secrets/onepassworditem.yml`
- Modify: `ansible/roles/crafty_controller_deploy/tasks/main.yml` (entire file)
- Modify: `ansible/playbooks/coachlight-infra-stack.yml` (ensure crafty_controller_deploy creates Argo App, not raw manifests)

**Done Criteria:**
```bash
kubectl get application crafty-controller -n argocd
kubectl get application crafty-controller -n argocd -o jsonpath='{.status.sync.status}'  # Should be "Synced"
kubectl get pods -n apps-crafty-controller
kubectl get onepassworditems -n apps-crafty-controller  # If using 1Password for secret
```

---

### ☐ 6.2 Migrate Paperless-NGX to Argo CD

**Current State:**  
`paperless_ngx_deploy` applies raw manifests directly, bypassing Argo.

**What to change:**

**Option A: Migrate to static manifests in GitOps**
1. Create `k8s/paperless_ngx/` directory
2. Move rendered manifests to static YAML files:
   - `namespace.yml`
   - `configmap.yml`
   - `secret.yml` → migrate to OnePasswordItem
   - `pvcs.yml`
   - `db.yml`, `broker.yml`, `webserver.yml`, `tika.yml`, `gotenberg.yml`
   - `ingress.yml` (for Homepage discovery)
3. Create `k8s/paperless_ngx_secrets/onepassworditem.yml` (if secrets need 1Password)
4. Create `k8s/paperless_ngx/application.yml` (Argo Application)
5. Update `paperless_ngx_deploy` role to only apply Argo Application

**Option B: Use existing Paperless-NGX Helm chart**
1. Research if an official or community Helm chart exists
2. If yes, use it and migrate to Helm-based deployment
3. Handle secrets via OnePasswordItem CRDs

**Recommendation:** Check for existing Helm chart first. If none, use Option A.

**Files:**
- Create: `k8s/paperless_ngx/*.yml`
- Create: `k8s/paperless_ngx_secrets/onepassworditem.yml`
- Modify: `ansible/roles/paperless_ngx_deploy/tasks/main.yml`
- Add: `ansible/playbooks/coachlight-infra-stack.yml` (paperless_ngx_deploy role)

**Done Criteria:**
```bash
kubectl get application paperless-ngx -n argocd
kubectl get application paperless-ngx -n argocd -o jsonpath='{.status.sync.status}'  # Should be "Synced"
kubectl get pods -n paperless-ngx
```

---

## Phase 7: Add Missing Apps to Playbook

### ☐ 7.1 Add Frigate to coachlight-infra-stack.yml

**What to change:**
1. Add `frigate_deploy` role to `ansible/playbooks/coachlight-infra-stack.yml`
2. Position after Homepage (requires storage, Tailscale, Homepage for discovery)
3. Pass required variables (kubeconfig, context, cluster_name, storage class, etc.)

**Files:**
- Modify: `ansible/playbooks/coachlight-infra-stack.yml` (after line 66)

**Done Criteria:**
```bash
kubectl get application frigate -n argocd
kubectl get pods -n apps-frigate
```

---

### ☐ 7.2 Add NetBox to coachlight-infra-stack.yml

**What to change:**
1. Add `netbox_deploy` role to `ansible/playbooks/coachlight-infra-stack.yml`
2. Position after Homepage (infra-monitoring category)
3. Ensure secrets are migrated to OnePasswordItem first (Phase 2.5)

**Files:**
- Modify: `ansible/playbooks/coachlight-infra-stack.yml`

**Done Criteria:**
```bash
kubectl get application netbox -n argocd
kubectl get pods -n netbox
```

---

### ☐ 7.3 Add Longhorn to coachlight-infra-stack.yml

**What to change:**
1. Add `longhorn_deploy` role to `ansible/playbooks/coachlight-infra-stack.yml`
2. Position early (provides storage, similar to Synology CSI)
3. Consider if Longhorn should be deployed **before** or **after** apps that need storage
   - Recommendation: Deploy before apps, after Tailscale Operator

**Files:**
- Modify: `ansible/playbooks/coachlight-infra-stack.yml` (after synology_csi_deploy)

**Done Criteria:**
```bash
kubectl get application longhorn -n argocd
kubectl get storageclass longhorn  # Should exist
kubectl get pods -n infra-longhorn
```

---

### ☐ 7.4 Add Velero to coachlight-infra-stack.yml

**What to change:**
1. Add `velero_deploy` role to `ansible/playbooks/coachlight-infra-stack.yml`
2. Position late (backup/recovery tool, depends on storage being available)
3. Ensure backup storage configuration is correct (may need OnePasswordItem for cloud credentials)

**Files:**
- Modify: `ansible/playbooks/coachlight-infra-stack.yml` (near end, after apps)

**Done Criteria:**
```bash
kubectl get application velero -n argocd
kubectl get pods -n infra-velero
kubectl get backupstoragelocation -n infra-velero
```

---

## Phase 8: Standardize Deploy Role Structure

### ☐ 8.1 Create standard deploy role template

**What to change:**
1. Create `ansible/roles/_deploy_template/` as a reference role
2. Structure:
   ```
   _deploy_template/
   ├── defaults/main.yml          # Default variables
   ├── meta/argument_specs.yml    # Variable definitions
   ├── tasks/
   │   ├── main.yml               # Entry point: include assert.yml, application.yml, wait.yml, artifacts.yml
   │   ├── assert.yml             # Assert required inputs
   │   ├── application.yml        # Render and apply Argo Application
   │   ├── wait.yml               # Wait for Application to be Synced + Healthy
   │   └── artifacts.yml          # Call role_artifacts
   └── templates/
       └── application.yml.j2     # Argo Application template
   ```
3. Emphasize: **Ansible only creates Argo Application; Argo reconciles the rest**

**Done Criteria:**
- [ ] Template role exists
- [ ] At least 2 existing roles refactored to use this pattern

---

### ☐ 8.2 Refactor existing roles to standard structure

**Current roles to refactor:**
- `tailscale_operator_deploy` (partial, missing wait.yml)
- `synology_csi_deploy` (partial, missing wait.yml)
- `frigate_deploy` (has assert, application, but no wait)
- `netbox_deploy` (has assert, application, but wait is inline)
- `velero_deploy` (has assert, application, but no wait)

**What to change:**
1. Split `tasks/main.yml` into modular task files (assert, application, wait, artifacts)
2. Add missing `wait.yml` to poll Application status until Synced + Healthy
3. Ensure consistency in variable naming (e.g., `<role>_kubeconfig`, `<role>_context`)

**Done Criteria:**
- [ ] Each role has modular task files
- [ ] Each role waits for Application health before proceeding
- [ ] Variable naming is consistent with role name prefix

---

## Phase 9: Documentation and Testing

### ☐ 9.1 Update README with new deployment flow

**What to change:**
1. Update `README.md` to document:
   - GitOps structure (`k8s/` directories)
   - 1Password Operator usage for secrets
   - Tailscale exposure pattern
   - Homepage discovery pattern
2. Add "Deploying a New App" guide with step-by-step instructions

**Done Criteria:**
- [ ] README has "GitOps Architecture" section
- [ ] README has "Adding a New App" guide

---

### ☐ 9.2 Create end-to-end deployment test

**What to change:**
1. Create test playbook: `ansible/playbooks/test-full-stack-deploy.yml`
2. Use molecule or similar to test deployment on a local k3s cluster
3. Validate:
   - Argo CD is running
   - All Applications are Synced + Healthy
   - OnePasswordItem CRDs exist
   - Secrets are created from OnePasswordItem
   - Tailscale proxies are running
   - Homepage is discoverable

**Done Criteria:**
```bash
ansible-playbook ansible/site.yml --tags coachlight_infra_stack_deploy
# All tasks green
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.sync.status}{"\t"}{.status.health.status}{"\n"}{end}'
# All apps show "Synced" and "Healthy"
```

---

### ☐ 9.3 Document verification commands

**What to change:**
1. Expand `docs/platform-deploy-order-review.md` Section 10 (Verification Commands)
2. Add app-specific verification for each deployed app
3. Create `docs/troubleshooting.md` with common issues and fixes

**Done Criteria:**
- [ ] `docs/troubleshooting.md` exists
- [ ] Verification commands are tested and confirmed working

---

## Summary of Deliverables

By completing this checklist, the following will be achieved:

### Files Created
- [ ] `k8s/argocd/` directory with bootstrap manifests
- [ ] `k8s/<app>/` directories for static manifest apps
- [ ] `k8s/<app>_secrets/` directories with OnePasswordItem CRDs
- [ ] `docs/secrets-management-pattern.md`
- [ ] `docs/tailscale-tagging-scheme.md`
- [ ] `docs/troubleshooting.md`
- [ ] `ansible/roles/_deploy_template/` reference role
- [ ] `ansible/roles/onepassworditem_deploy/` reusable role (optional)

### Files Modified
- [ ] `ansible/roles/argocd_deploy/` (apply `k8s/argocd/` instead of individual files)
- [ ] `ansible/roles/onepassword_operator_deploy/` (documented bootstrap exception)
- [ ] `ansible/roles/tailscale_operator_deploy/` (use OnePasswordItem for secrets)
- [ ] `ansible/roles/synology_csi_deploy/` (use OnePasswordItem for secrets)
- [ ] `ansible/roles/homepage_deploy/` (use OnePasswordItem for secrets, migrate Ingress templates)
- [ ] `ansible/roles/netbox_deploy/` (use OnePasswordItem for secrets)
- [ ] `ansible/roles/crafty_controller_deploy/` (create Argo Application, migrate to GitOps)
- [ ] `ansible/roles/paperless_ngx_deploy/` (create Argo Application, migrate to GitOps)
- [ ] `ansible/playbooks/coachlight-infra-stack.yml` (add missing roles, order correctly)

### Files Deleted (Optional)
- [ ] `ansible/roles/argocd_deploy/files/*.yml` (moved to `k8s/argocd/`)
- [ ] `ansible/roles/homepage_deploy/templates/ingresses/*.j2` (moved to `k8s/`)

### Verification Passed
- [ ] All Applications are GitOps-managed
- [ ] No plaintext secrets in Helm values (except 1Password Operator bootstrap)
- [ ] All secrets use OnePasswordItem CRDs
- [ ] Tailscale annotations are consistent
- [ ] Homepage discovery works for all UI apps
- [ ] Dependency order is correct (Argo → 1Password → Tailscale → Storage → Apps)

---

## Estimated Effort

| Phase | Estimated Time |
|-------|----------------|
| Phase 1: Argo CD Bootstrap | 2-4 hours |
| Phase 2: 1Password Adoption | 6-8 hours |
| Phase 3: Secrets Normalization | 2-3 hours |
| Phase 4: Tailscale Normalization | 2-3 hours |
| Phase 5: Homepage Normalization | 2-3 hours |
| Phase 6: Remove Non-GitOps Paths | 6-8 hours |
| Phase 7: Add Missing Apps | 2-4 hours |
| Phase 8: Standardize Roles | 4-6 hours |
| Phase 9: Documentation & Testing | 4-6 hours |
| **Total** | **30-45 hours** |

---

## Next Actions

1. Review this checklist with the team
2. Prioritize phases (recommend: Phase 1 → 2 → 6 → 7 → 3-5 → 8-9)
3. Create GitHub issues for each major phase
4. Begin implementation, starting with Phase 1 (Argo CD bootstrap correctness)

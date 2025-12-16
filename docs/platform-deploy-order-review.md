# Platform Deployment Order Review

**Date:** 2025-12-14  
**Purpose:** Comprehensive inventory of the current k3s platform deployment mechanism to align with GitOps + 1Password/Tailscale/Homepage conventions

---

## Executive Summary

This document provides an as-is analysis of the Coachlight k3s cluster deployment architecture. The analysis reveals a **hybrid deployment model** where:

- **Argo CD is bootstrapped by Ansible** ✅
- **Most apps are deployed via Argo Applications created by Ansible roles** ✅ (Partial)
- **Some apps bypass GitOps entirely** ❌ (crafty_controller, paperless_ngx)
- **No `k8s/` GitOps directory structure exists yet** ❌
- **Secrets are managed inconsistently** ⚠️ (mix of plaintext in Helm values, direct K8s Secrets, and 1Password Connect credentials)
- **1Password Operator is deployed early** ✅ (correctly positioned)
- **Tailscale annotations are used consistently** ✅
- **Homepage discovery uses dummy Ingress pattern** ✅ (for some apps)

---

## 1. Current Application Inventory

### 1.1 Apps Deployed via Argo Applications (Created by Ansible)

| App | Type | Argo App Role | Argo Namespace | App Namespace | Secrets Handling | GitOps Path | Deviations |
|-----|------|---------------|----------------|---------------|------------------|-------------|------------|
| **Argo CD** | Static Manifest | `argocd_deploy` | N/A (self) | `argocd` | GitHub OAuth in ConfigMap patch | N/A (upstream manifest) | Uses remote manifest URL, not GitOps repo |
| **1Password Operator** | Helm Chart | `onepassword_operator_deploy` | `argocd` | `infra-1password-operator` | Connect credentials + operator token in valuesObject | N/A | ❌ **Plaintext secrets in Helm values** |
| **Tailscale Operator** | Helm Chart | `tailscale_operator_deploy` | `argocd` | `infra-tailscale-operator` | OAuth client ID/secret in valuesObject | N/A | ❌ **Plaintext secrets in Helm values** |
| **Synology CSI** | Helm Chart | `synology_csi_deploy` | `argocd` | `infra-synology-csi` | NAS username/password in valuesObject | N/A | ❌ **Plaintext secrets in Helm values** |
| **Homepage** | Helm Chart | `homepage_deploy` | `argocd` | `infra-homepage` | NextDNS + Proxmox API tokens in valuesObject, Argo token in Secret | N/A | ❌ **Plaintext secrets in Helm values** |
| **Omada** | Helm Chart | `omada_deploy` | `argocd` | `apps-omada` | None (stateful app) | N/A | ✅ No secrets issues |
| **Frigate** | Helm Chart | `frigate_deploy` | `argocd` | `apps-frigate` | None visible | N/A | ✅ No secrets issues |
| **NetBox** | Helm Chart | `netbox_deploy` | `argocd` | `netbox` | Superuser password + secret key in valuesObject | N/A | ❌ **Plaintext secrets in Helm values** |
| **Velero** | Helm Chart | `velero_deploy` | `argocd` | `infra-velero` | Backup storage config (if any) | N/A | ⚠️ Storage config may contain secrets |
| **Longhorn** | Helm Chart | `longhorn_deploy` | `argocd` | `infra-longhorn` | None (block storage) | N/A | ✅ No secrets issues |

### 1.2 Apps Deployed Directly (Bypass Argo GitOps)

| App | Type | Role | Namespace | Secrets Handling | Deployment Mechanism | Deviations |
|-----|------|------|-----------|------------------|----------------------|------------|
| **Crafty Controller** | Raw Manifests | `crafty_controller_deploy` | `apps-crafty-controller` | Password in rendered Secret manifest | Ansible renders + applies manifests directly via `k8s_object_manager` | ❌ **Bypasses Argo CD completely** |
| **Paperless-NGX** | Raw Manifests | `paperless_ngx_deploy` | `paperless-ngx` | Secrets in rendered Secret manifest | Ansible renders + applies manifests directly via `k8s_object_manager` | ❌ **Bypasses Argo CD completely** |

---

## 2. Current Deployment Flow

### 2.1 Entry Point

**File:** `ansible/site.yml`  
**Lines:** 131-133

```yaml
- name: Deploy Coachlight HomeLab Infra Stack
  import_playbook: playbooks/coachlight-infra-stack.yml
  when: "'coachlight_infra_stack_deploy' in ansible_run_tags"
```

### 2.2 Deployment Sequence

**File:** `ansible/playbooks/coachlight-infra-stack.yml`  
**Lines:** 40-77

Current order:

1. **Pre-tasks:**
   - Retrieve k3s kubeconfig (`k3s_kubeconfig_retriever`)
   - Manage kubeconfig context (`kubeconfig_manager`)
   - Validate cluster connectivity (`k8s_validator`)
   - Apply control-plane taints (lines 28-38)

2. **Roles:**
   - `argocd_deploy` (line 41)
   - `onepassword_operator_deploy` (line 46)
   - `tailscale_operator_deploy` (line 54)
   - `synology_csi_deploy` (line 61)
   - `argocd_homepage_token` (line 65) - generates Homepage Argo token
   - `homepage_deploy` (line 66)
   - `crafty_controller_deploy` (line 73)
   - `omada_deploy` (line 76)

**Not in playbook but have deploy roles:**
- `frigate_deploy`
- `netbox_deploy`
- `velero_deploy`
- `longhorn_deploy`
- `paperless_ngx_deploy`

---

## 3. Secrets Management Analysis

### 3.1 Current Secret Sources

**File:** `ansible/site.yml`  
**Lines:** 14-92

All secrets are fetched from 1Password Connect **at playbook runtime** using `community.general.onepassword` lookup:

- `homelab_become_pass`
- `tailscale_oauth_client_id` / `tailscale_oauth_client_secret`
- `k3s_synology_csi_nas_username` / `k3s_synology_csi_nas_password`
- `argocd_github_oauth_client_id` / `argocd_github_oauth_client_secret`
- `homepage_nextdns_api_token`
- `proxmox_api_password`
- `crafty_controller_deploy_sfroeber_password`
- `argocd_homepage_token_op_service_account_token`
- etc.

These are then:
- ❌ **Embedded as plaintext in Argo Application Helm values** (for Helm chart apps)
- ❌ **Rendered into K8s Secret manifests and applied directly** (for non-Argo apps)

### 3.2 1Password Operator Deployment

**File:** `ansible/roles/onepassword_operator_deploy/templates/application.yml.j2`  
**Lines:** 14-38

The 1Password Operator itself is deployed with:
- `connect.credentials` = base64-encoded 1password-credentials.json (plaintext in values)
- `operator.token.value` = operator access token (plaintext in values)

**Issue:** The operator that should provide secrets is itself receiving secrets as plaintext in Helm values.

### 3.3 OnePasswordItem CRD Usage

**Finding:** ❌ **No OnePasswordItem CRDs found in the repository.**

Expected location: `k8s/<app>_secrets/onepassworditem.yml` (does not exist)

---

## 4. Non-Conforming Deployment Mechanisms

### 4.1 Direct Manifest Application (Bypass Argo)

**crafty_controller_deploy**  
**File:** `ansible/roles/crafty_controller_deploy/tasks/main.yml`  
**Lines:** 47-109

- Renders all manifests (Namespace, Secret, PVCs, Deployment, Service, Ingress) to `{{ artifacts_path }}/rendered-manifests`
- Applies each manifest directly via `k8s_object_manager` role
- No Argo Application created

**paperless_ngx_deploy**  
**File:** `ansible/roles/paperless_ngx_deploy/tasks/main.yml`  
**Lines:** 88-190

- Renders 8+ manifests (Namespace, ConfigMap, Secret, PVCs, Database, Broker, Webserver, Tika, Gotenberg, Ingress)
- Applies each manifest directly via `k8s_object_manager` role
- No Argo Application created

**Impact:** These apps are not tracked by Argo CD, defeating GitOps principles:
- No declarative state in Git
- No drift detection
- No automated sync/prune
- Changes require re-running Ansible

### 4.2 Out-of-Band kubectl/helm Usage

**Finding:** ✅ **No kubectl or helm commands found in role tasks or CI workflows.**

- Shell script `macos-setup.sh` installs kubectl/helm but only for local workstation setup.

---

## 5. GitOps Directory Structure

### 5.1 Expected Structure

According to the rules:

```
k8s/
├── argocd/                          # Argo CD bootstrap manifests
├── <app>/                           # Static manifest apps
│   ├── deployment.yml
│   ├── service.yml
│   └── ...
└── <app>_secrets/                   # OnePasswordItem CRDs for Helm chart apps
    └── onepassworditem.yml
```

### 5.2 Actual State

**Finding:** ❌ **No `k8s/` directory exists in the repository.**

All application definitions are embedded in Ansible role templates:
- `ansible/roles/<app>_deploy/templates/<app>-application.yml.j2`
- `ansible/roles/<app>_deploy/files/*.yml`

**Argo CD bootstrap files:**  
**Location:** `ansible/roles/argocd_deploy/files/`

- `coachlight-k3s-infra-project.yml`
- `coachlight-k3s-apps-project.yml`
- `coachlight-k3s-db-project.yml`
- `coachlight-k3s-observability-project.yml`
- `argocd-server-tailscale-servicepatch.yml`
- `argocd-rbac-homepage-readonly.yml`

These are applied as additional manifests after Argo CD install.

---

## 6. Tailscale Integration

### 6.1 Service Annotations

✅ **Correctly implemented across most apps.**

**Examples:**

**1Password Operator:**  
`ansible/roles/onepassword_operator_deploy/templates/application.yml.j2` (lines 18-21)
```yaml
serviceAnnotations:
  tailscale.com/expose: "true"
  tailscale.com/hostname: "1password"
  tailscale.com/tags: "tag:k8s,tag:infra-gitops"
```

**Homepage:**  
`ansible/roles/homepage_deploy/templates/homepage-application.yml.j2` (lines 16-19)
```yaml
annotations:
  tailscale.com/expose: "true"
  tailscale.com/hostname: "homepage"
  tailscale.com/tags: "tag:k8s,tag:infra-monitoring,tag:server-games"
```

**Longhorn:**  
`ansible/roles/longhorn_deploy/files/longhorn.yml` (lines 30-33)
```yaml
annotations:
  tailscale.com/expose: "true"
  tailscale.com/hostname: "longhorn"
  tailscale.com/tags: "tag:k8s,tag:infra-monitoring"
```

**NetBox:**  
`ansible/roles/netbox_deploy/templates/netbox-application.yml.j2` (lines 43-46)
```yaml
annotations:
  tailscale.com/expose: "true"
  tailscale.com/hostname: "netbox"
  tailscale.com/tags: "tag:k8s,tag:infra-monitoring"
```

---

## 7. Homepage Discovery Integration

### 7.1 Dummy Ingress Pattern

✅ **Correctly implemented for some apps.**

**Example (1Password Operator):**  
`ansible/roles/onepassword_operator_deploy/templates/application.yml.j2` (lines 22-34)
```yaml
ingress:
  enabled: true
  annotations:
    gethomepage.dev/enabled: "true"
    gethomepage.dev/name: "1Password Connect"
    gethomepage.dev/description: "Secrets backend for 1Password Operator"
    gethomepage.dev/group: "Platform"
    gethomepage.dev/icon: "onepassword.png"
  hosts:
    - host: "1password.rohu-shark.ts.net"
      paths:
        - path: /
          pathType: Prefix
```

**Example (Argo CD):**  
`ansible/roles/homepage_deploy/templates/ingresses/argocd-homepage-ingress.yml.j2`

Separate dummy Ingress created by homepage_deploy for Argo CD discovery.

### 7.2 Apps Missing Homepage Discovery

- Synology CSI (no UI)
- Tailscale Operator (no UI)
- Crafty Controller ⚠️ (has UI, has Ingress but may not have proper Homepage annotations)
- Paperless-NGX ⚠️ (has UI, has Ingress with homepage annotations)

---

## 8. Dependency Graph

### 8.1 Hard Dependencies

```
1. Cluster Prerequisites
   └─ Namespaces, control-plane taints

2. Argo CD Bootstrap
   └─ CRDs: Application, AppProject
   └─ Projects: coachlight-k3s-infra, coachlight-k3s-apps, etc.

3. 1Password Operator
   └─ Requires: Argo CD (for Application tracking)
   └─ Provides: OnePasswordItem CRD
   └─ NOTE: Currently receives secrets as plaintext in Helm values

4. Tailscale Operator
   └─ Requires: Argo CD, 1Password Operator (if secrets were migrated)
   └─ Provides: Service annotations for tailnet exposure

5. Synology CSI
   └─ Requires: Argo CD, 1Password Operator (if secrets were migrated)
   └─ Provides: StorageClass "nfs-delete"

6. Homepage
   └─ Requires: Argo CD, 1Password Operator (if secrets were migrated), Tailscale Operator
   └─ Consumes: Argo CD API (for widget), k8s API (for cluster metrics)

7. Application Layer (Crafty, Omada, Frigate, NetBox, etc.)
   └─ Requires: Argo CD, Tailscale Operator, Synology CSI or Longhorn (for storage)
   └─ Depends on: 1Password Operator (if secrets are migrated to OnePasswordItem)

8. Observability (Velero, Longhorn)
   └─ Requires: Argo CD, Tailscale Operator, Synology CSI (for backups)
```

### 8.2 Current Ordering Validation

✅ **Current order is dependency-correct:**

1. Argo CD → 2. 1Password → 3. Tailscale → 4. Synology CSI → 5. Homepage → 6. Apps

**However:**
- 1Password Operator is not yet **used** for app secrets (all secrets are Ansible-managed)
- Apps not in playbook (frigate, netbox, velero, longhorn) need to be added in correct order

---

## 9. Deviation Summary

### 9.1 Must Fix Now (Breaks GitOps or Security Model)

1. **crafty_controller_deploy bypasses Argo CD entirely**
   - File: `ansible/roles/crafty_controller_deploy/tasks/main.yml`
   - Lines: 47-109
   - Fix: Create Argo Application, migrate manifests to `k8s/crafty_controller/` or Helm chart

2. **paperless_ngx_deploy bypasses Argo CD entirely**
   - File: `ansible/roles/paperless_ngx_deploy/tasks/main.yml`
   - Lines: 88-190
   - Fix: Create Argo Application, migrate manifests to `k8s/paperless_ngx/` or Helm chart

3. **Plaintext secrets in Argo Application Helm values (multiple apps)**
   - Files:
     - `ansible/roles/onepassword_operator_deploy/templates/application.yml.j2` (lines 16, 38)
     - `ansible/roles/tailscale_operator_deploy/templates/infra-tailscale-operator.yml.j2` (lines 15-16)
     - `ansible/roles/synology_csi_deploy/templates/synology_csi.yml.j2` (lines 18-19)
     - `ansible/roles/homepage_deploy/templates/homepage-application.yml.j2` (lines 33, 41)
     - `ansible/roles/netbox_deploy/templates/netbox-application.yml.j2` (lines 16, 18)
   - Fix: Create `k8s/<app>_secrets/onepassworditem.yml`, reference `existingSecret` in Helm values

### 9.2 Should Fix Next (Structure Mismatch)

4. **No `k8s/` GitOps directory structure exists**
   - Current: All Argo Applications are Jinja2 templates in Ansible roles
   - Expected: Static manifests in `k8s/<app>/`, secrets in `k8s/<app>_secrets/`
   - Fix: Create `k8s/` structure, migrate static app definitions out of Ansible

5. **1Password Operator not used for app secrets**
   - Current: All secrets fetched from 1Password Connect at Ansible runtime
   - Expected: OnePasswordItem CRDs in cluster fetch secrets at runtime
   - Fix: Create OnePasswordItem CRDs in `k8s/<app>_secrets/` for each app

6. **Roles not in coachlight-infra-stack.yml playbook**
   - Missing: `frigate_deploy`, `netbox_deploy`, `velero_deploy`, `longhorn_deploy`, `paperless_ngx_deploy`
   - Fix: Add to playbook in dependency order

### 9.3 Nice to Have (Cleanup/Refactor)

7. **Inconsistent role structure**
   - Some roles use `templates/*.j2` → render → apply
   - Some roles use `files/*.yml` → apply directly
   - Some roles wait for Application health, some don't
   - Fix: Standardize to consistent `<app>_deploy` pattern (tasks/assert.yml, tasks/application.yml, templates/application.yaml.j2)

8. **argocd_homepage_token is a separate role**
   - Current: Standalone role that creates a token in Argo CD, stores in 1Password, retrieves, and passes to homepage_deploy
   - Could be: Part of homepage_deploy pre-tasks or integrated into Homepage chart via initContainer
   - Fix: Consider consolidating or documenting rationale

9. **Homepage role applies extra Ingress manifests**
   - File: `ansible/roles/homepage_deploy/tasks/main.yml` (lines 14-35)
   - Current: Scans `templates/ingresses/*.j2` and applies each as a dummy Ingress
   - Could be: These could live in `k8s/homepage/` or be part of Homepage chart customization
   - Fix: Migrate dummy Ingresses to GitOps structure

---

## 10. Verification Commands

Once the migration is complete, use these commands to validate the final state:

### 10.1 Argo CD

```bash
# List all Argo Applications
kubectl get applications -n argocd

# Check Application sync status
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.sync.status}{"\t"}{.status.health.status}{"\n"}{end}'

# Verify Application source points to GitOps repo
kubectl get application <app-name> -n argocd -o jsonpath='{.spec.source}'
```

### 10.2 1Password Operator

```bash
# List all OnePasswordItem CRDs
kubectl get onepassworditems -A

# Check if secrets are created from OnePasswordItem
kubectl get secrets -A -o json | jq -r '.items[] | select(.metadata.ownerReferences[]?.kind=="OnePasswordItem") | .metadata.namespace + "/" + .metadata.name'

# Verify 1Password Operator is running
kubectl get pods -n infra-1password-operator
```

### 10.3 Secrets

```bash
# List all secrets (should reference 1Password, not be Ansible-managed)
kubectl get secrets -A

# Check for secrets created by specific apps
kubectl get secrets -n <app-namespace> | grep -i <app>

# Verify no plaintext secrets in Argo Application manifests
kubectl get application <app-name> -n argocd -o yaml | grep -i "password\|secret\|token"
```

### 10.4 Tailscale

```bash
# List services with Tailscale annotations
kubectl get svc -A -o yaml | grep -B5 "tailscale.com"

# Verify Tailscale proxy pods are running
kubectl get pods -n infra-tailscale-operator | grep proxy
```

### 10.5 Homepage Discovery

```bash
# List Ingresses with Homepage annotations
kubectl get ingress -A -o yaml | grep -B5 "gethomepage.dev"

# Verify Homepage can discover services
kubectl logs -n infra-homepage -l app.kubernetes.io/name=homepage | grep -i discover
```

---

## 11. Next Steps

See `docs/platform-migration-checklist.md` for the detailed, actionable migration plan.

# Leantime Secrets - 1Password Setup

This directory contains OnePasswordItem CRDs that reference secrets in the HomeLab vault.

## Required 1Password Items

Before deploying Leantime, create the following items in 1Password:

### 1. Leantime Database (`Leantime Database`)

**Vault**: HomeLab  
**Item Name**: `Leantime Database`

**Required Fields**:
- `mariadb-root-password`: Root password for the MariaDB database
- `mariadb-password`: Password for the `leantime` database user

These fields will be materialized by the 1Password Operator into a Kubernetes Secret named `leantime-db` in the `apps-leantime` namespace.

### 2. Leantime App Secrets (`Leantime App Secrets`)

**Vault**: HomeLab  
**Item Name**: `Leantime App Secrets`

**Status**: Reserved for future use. Can be empty or contain placeholder values for now.

**Note**: The upstream Leantime Helm chart does not currently support `existingSecret` for application-level secrets (session password, SMTP credentials, etc.). This OnePasswordItem is created for future extensibility.

## Verification

After ArgoCD syncs the `leantime-secrets` application (sync-wave 10), verify the secrets were created:

```bash
kubectl get onepassworditems -n apps-leantime
kubectl get secrets -n apps-leantime
```

You should see:
- OnePasswordItems: `leantime-db`, `leantime-app`
- Secrets: `leantime-db`, `leantime-app` (created by 1Password Operator)

## Integration

The `leantime-db` secret is consumed by the MariaDB subchart in the Leantime Helm deployment via:

```yaml
mariadb:
  auth:
    existingSecret: "leantime-db"
```

This ensures database credentials are never stored in Git or ArgoCD manifests.

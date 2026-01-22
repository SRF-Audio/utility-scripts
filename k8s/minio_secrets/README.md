# MinIO 1Password Secrets

This directory contains the `OnePasswordItem` manifest for MinIO credentials.

## Required 1Password Item

Create a 1Password item in the `HomeLab` vault with the following details:

- **Item name**: `k3s-observability-minio`
- **Vault**: `HomeLab`

### Required Fields

The 1Password item must contain the following fields:

| Field Name | Description | Example Value |
|------------|-------------|---------------|
| `rootUser` | MinIO root username | `admin` |
| `rootPassword` | MinIO root password | `<strong-password>` |
| `lokiSecretKey` | Secret key (password) for Loki user | `<strong-password>` |

### Notes

- The `rootUser` and `rootPassword` fields are used by MinIO for the root administrator account
- The `lokiSecretKey` field is the password for the `loki` user (username is hardcoded as "loki")
- The 1Password Operator will create a Kubernetes Secret named `minio-credentials` in the `observability-minio` namespace
- The MinIO Helm chart will reference this secret via the `existingSecret` configuration
- A bucket named `loki` will be automatically created
- The `loki` user will be assigned a policy with read/write access to the `loki` bucket

## Verification

After deploying, verify the resources were created:

```bash
# Check 1Password Operator created the secret
kubectl -n observability-minio get onepassworditems
kubectl -n observability-minio get secrets | grep minio-credentials

# Check MinIO pods are running
kubectl -n observability-minio get pods

# Check persistence
kubectl -n observability-minio get pvc

# Check MinIO logs
kubectl -n observability-minio logs -l app=minio

# Verify provisioning jobs succeeded
kubectl -n observability-minio get jobs
```

## Access MinIO Console

The MinIO Console is exposed via Tailscale Ingress at:

- https://minio.rohu-shark.ts.net

Login with the root credentials from 1Password.

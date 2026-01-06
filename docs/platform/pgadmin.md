# pgAdmin - PostgreSQL Administration Tool

## Overview

pgAdmin is deployed as an infrastructure tool in the `infra-pgadmin` namespace to support PostgreSQL database administration, inspection, and operations tasks in the Coachlight k3s cluster.

## Deployment Details

- **Namespace**: `infra-pgadmin`
- **Helm Chart**: `runix/pgadmin4` (version 1.50.0)
- **ArgoCD Project**: `coachlight-k3s-infra`
- **Storage**: `nfs-synology-retain` (2Gi PVC)
- **Access**: Internal-only via Tailscale ingress

## Access

### URL

pgAdmin is accessible internally via Tailscale:

```
https://pgadmin.rohu-shark.ts.net
```

### Login Credentials

**Email**: Stored in 1Password item `pgAdmin Admin Credentials` field `PGADMIN_DEFAULT_EMAIL`  
**Password**: Stored in 1Password item `pgAdmin Admin Credentials` field `PGADMIN_DEFAULT_PASSWORD`

Credentials are automatically injected into the pgAdmin pod via the 1Password Operator.

## Adding the PostgreSQL Server Connection

After logging in to pgAdmin, you'll need to register the PostgreSQL server to manage it:

1. Click **"Add New Server"** in the pgAdmin dashboard
2. In the **General** tab:
   - **Name**: `Coachlight Postgres` (or any descriptive name)
3. In the **Connection** tab:
   - **Host name/address**: `postgres-postgresql.db-postgres.svc.cluster.local`
   - **Port**: `5432`
   - **Maintenance database**: `postgres`
   - **Username**: `postgres` (or appropriate admin user)
   - **Password**: Retrieve from 1Password or the Postgres secret
4. (Optional) In the **Advanced** tab:
   - **DB restriction**: Leave blank to see all databases
5. Click **Save**

## Usage Guidelines

### Intended Use

pgAdmin is provided for:

- **Emergency database administration**: Manual interventions when needed
- **Debugging and inspection**: Query execution, schema review, performance analysis
- **Platform database operations**: Creating roles, users, and databases during development

### Important Warnings

⚠️ **pgAdmin is NOT for production database provisioning**

- Long-term database provisioning should be handled via GitOps patterns (e.g., Kubernetes Jobs, Ansible roles, or Helm hooks)
- Changes made manually through pgAdmin are **not tracked in version control** and can drift from desired state
- Use pgAdmin for exploration and emergency fixes only

⚠️ **Data persistence**

- pgAdmin configuration (including server definitions and user preferences) is stored on a persistent volume
- The PVC uses the `nfs-synology-retain` storage class to ensure data survives pod restarts

⚠️ **Access control**

- pgAdmin is exposed internally via Tailscale only—no public ingress
- Access requires being on the LAN or connected to the Tailnet

## Troubleshooting

### Pod not starting

Check the ArgoCD application status:

```bash
argocd app get pgadmin
```

Check pod status and logs:

```bash
kubectl -n infra-pgadmin get pods
kubectl -n infra-pgadmin logs <pod-name>
```

### Credentials not working

Verify the 1Password secret is synced:

```bash
kubectl -n infra-pgadmin get secret pgadmin-credentials
kubectl -n infra-pgadmin describe onepassworditem pgadmin-credentials
```

### Cannot connect to PostgreSQL

Verify network connectivity from pgAdmin pod:

```bash
kubectl -n infra-pgadmin exec -it <pod-name> -- ping postgres-postgresql.db-postgres.svc.cluster.local
```

Check PostgreSQL service:

```bash
kubectl -n db-postgres get svc postgres-postgresql
```

### pgAdmin not accessible via Tailscale

Check ingress resource:

```bash
kubectl -n infra-pgadmin get ingress pgadmin
kubectl -n infra-pgadmin describe ingress pgadmin
```

Verify Tailscale operator is functioning:

```bash
kubectl -n infra-tailscale-operator get pods
```

## Related Resources

- **ArgoCD Applications**:
  - `argocd/apps/platform/pgadmin-secrets.yml`
  - `argocd/apps/platform/pgadmin.yml`
- **Kubernetes Manifests**:
  - `k8s/pgadmin/` (OnePassword CRD and namespace)
  - `k8s/resources/ingresses/infra-pgadmin/` (Tailscale ingress)
- **1Password**: `HomeLab` vault, item: `pgAdmin Admin Credentials`

## Future Improvements

- Migrate to GitOps-based database provisioning (bootstrap jobs pattern)
- Consider server definitions ConfigMap for pre-configured PostgreSQL connections
- Explore pgAdmin LDAP/SSO integration for centralized auth (if needed)

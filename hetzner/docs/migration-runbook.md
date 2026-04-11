# Paperless-NGX Migration Runbook: Homelab → Hetzner

<!--
AGENT INSTRUCTIONS
==================
Read overview.md and status.md before working in this file.
Update status.md after completing any phase or step.
This runbook covers Phase 3 (data migration) only.
Phases 1 and 2 (provisioning and bootstrap) are tracked in status.md.
-->

This is the step-by-step procedure for migrating live Paperless-NGX data from the
Coachlight homelab k3s cluster (Synology NFS) to the Hetzner single-node k3s cluster.

**IMPORTANT**: Paperless-NGX stores mission-critical documents. Do NOT skip any
verification steps. Take a full Synology snapshot before beginning.

---

## Homelab PVC Reference

Current homelab PVC names (confirmed via `kubectl get pvc -n apps-paperless-ngx`):

| Volume   | Homelab PVC name            | Hetzner PVC name       |
|----------|-----------------------------|------------------------|
| data     | `paperless-ngx-data-nfs`    | `paperless-ngx-data`   |
| media    | `paperless-ngx-media-nfs`   | `paperless-ngx-media`  |
| export   | `paperless-ngx-export-nfs`  | `paperless-ngx-export` |
| consume  | `paperless-ngx-consume`     | `paperless-ngx-consume`|

The `consume` PVC has no `-nfs` suffix on homelab either (it was manually provisioned
against the Synology NFS, not via the NFS provisioner).

---

## Pre-Migration Checklist

- [ ] Hetzner cluster is bootstrapped and healthy (all ArgoCD apps green except Paperless-NGX)
- [ ] PostgreSQL is running on Hetzner in `db-postgres` namespace
- [ ] Redis is running on Hetzner in `db-redis` namespace
- [ ] `paperless-ngx` ArgoCD app is synced (Paperless pod may CrashLoop — no data yet, OK)
- [ ] Synology NAS snapshot taken
- [ ] You have `kubectl` contexts for both clusters: `homelab` and `hetzner`
- [ ] You have SSH access to the Hetzner node
- [ ] Tailscale is active on both clusters

---

## Step 1 — Stop Paperless-NGX on Homelab

Scale down to 0 replicas to prevent writes during migration.

```bash
kubectl --context homelab -n apps-paperless-ngx scale deployment paperless-ngx-webserver --replicas=0
kubectl --context homelab -n apps-paperless-ngx get pods  # confirm no pods running
```

**Do NOT delete the PVCs. Just scale to zero.**

---

## Step 2 — Export PostgreSQL Database

```bash
# Start a temporary psql client pod on homelab cluster
kubectl --context homelab -n db-postgres run pg-dump-tmp \
  --image=bitnami/postgresql:latest \
  --restart=Never \
  --env="PGPASSWORD=$(kubectl --context homelab -n db-postgres get secret paperless-ngx-secrets \
    -o jsonpath='{.data.PAPERLESS_DBPASS}' | base64 -d)" \
  --command -- sleep 3600

kubectl --context homelab -n db-postgres wait pod/pg-dump-tmp --for=condition=Ready --timeout=60s

# Run pg_dump and save locally
DUMP_FILE="/tmp/paperless-$(date +%Y%m%d-%H%M).sql"
kubectl --context homelab -n db-postgres exec pg-dump-tmp -- \
  pg_dump -h postgres-postgresql.db-postgres.svc.cluster.local \
    -U paperless paperless \
  > "$DUMP_FILE"

# Verify dump is non-empty and is a valid PostgreSQL dump
ls -lh "$DUMP_FILE"
head -5 "$DUMP_FILE" | grep -q 'PostgreSQL database dump' \
  || { echo "ERROR: $DUMP_FILE does not look like a valid pg_dump output. Aborting."; exit 1; }

# Clean up the temp pod
kubectl --context homelab -n db-postgres delete pod pg-dump-tmp
```

---

## Step 3 — Copy Paperless Media and Data Volumes

The Paperless data lives on Synology NFS. Two options depending on network access.

### Option A: Via kubectl cp (works regardless of NFS access)

```bash
# Start a reader pod on homelab with all PVCs mounted
cat <<EOF | kubectl --context homelab apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: paperless-migration-reader
  namespace: apps-paperless-ngx
spec:
  restartPolicy: Never
  containers:
  - name: rsync
    image: alpine:3.20
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /paperless/data
    - name: media
      mountPath: /paperless/media
    - name: export
      mountPath: /paperless/export
    - name: consume
      mountPath: /paperless/consume
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: paperless-ngx-data-nfs
  - name: media
    persistentVolumeClaim:
      claimName: paperless-ngx-media-nfs
  - name: export
    persistentVolumeClaim:
      claimName: paperless-ngx-export-nfs
  - name: consume
    persistentVolumeClaim:
      claimName: paperless-ngx-consume
EOF

kubectl --context homelab -n apps-paperless-ngx wait pod/paperless-migration-reader \
  --for=condition=Ready --timeout=60s

# Archive each volume (media is largest — will take a while)
kubectl --context homelab -n apps-paperless-ngx \
  exec paperless-migration-reader -- tar czf - /paperless/data \
  > /tmp/paperless-data.tar.gz

kubectl --context homelab -n apps-paperless-ngx \
  exec paperless-migration-reader -- tar czf - /paperless/media \
  > /tmp/paperless-media.tar.gz

kubectl --context homelab -n apps-paperless-ngx \
  exec paperless-migration-reader -- tar czf - /paperless/export \
  > /tmp/paperless-export.tar.gz

echo "Archive sizes:"
ls -lh /tmp/paperless-*.tar.gz

kubectl --context homelab -n apps-paperless-ngx delete pod paperless-migration-reader
```

### Option B: Via Synology NFS direct rsync (faster for large media)

If you have SSH access to the Synology NAS, rsync directly. List actual NFS paths first:

```bash
ssh admin@192.168.226.6 "ls /volume2/k3s-cluster-storage/apps-paperless-ngx/"
# Paths follow pattern: apps-paperless-ngx/paperless-ngx-{data,media,export}-nfs-<pvc-uid>/
```

---

## Step 4 — Restore Data on Hetzner

### 4a — Scale down Paperless-NGX on Hetzner

```bash
kubectl --context hetzner -n apps-paperless-ngx scale deployment paperless-ngx-webserver --replicas=0
```

### 4b — Create a writer pod on Hetzner with all PVCs mounted

```bash
cat <<EOF | kubectl --context hetzner apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: paperless-migration-writer
  namespace: apps-paperless-ngx
spec:
  restartPolicy: Never
  containers:
  - name: restore
    image: alpine:3.20
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /paperless/data
    - name: media
      mountPath: /paperless/media
    - name: export
      mountPath: /paperless/export
    - name: consume
      mountPath: /paperless/consume
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: paperless-ngx-data
  - name: media
    persistentVolumeClaim:
      claimName: paperless-ngx-media
  - name: export
    persistentVolumeClaim:
      claimName: paperless-ngx-export
  - name: consume
    persistentVolumeClaim:
      claimName: paperless-ngx-consume
EOF

kubectl --context hetzner -n apps-paperless-ngx wait pod/paperless-migration-writer \
  --for=condition=Ready --timeout=60s
```

### 4c — Push data archives to Hetzner PVCs

The archives contain paths like `paperless/data/...`. Extracting to `/` restores them
to `/paperless/data/...` which matches the volume mount paths in the writer pod.

```bash
cat /tmp/paperless-data.tar.gz | kubectl --context hetzner -n apps-paperless-ngx \
  exec -i paperless-migration-writer -- tar xzf - -C /

cat /tmp/paperless-media.tar.gz | kubectl --context hetzner -n apps-paperless-ngx \
  exec -i paperless-migration-writer -- tar xzf - -C /

cat /tmp/paperless-export.tar.gz | kubectl --context hetzner -n apps-paperless-ngx \
  exec -i paperless-migration-writer -- tar xzf - -C /

kubectl --context hetzner -n apps-paperless-ngx delete pod paperless-migration-writer
```

### 4d — Restore PostgreSQL database on Hetzner

```bash
kubectl --context hetzner -n db-postgres run pg-restore-tmp \
  --image=bitnami/postgresql:latest \
  --restart=Never \
  --env="PGPASSWORD=$(kubectl --context hetzner -n db-postgres get secret paperless-ngx-secrets \
    -o jsonpath='{.data.PAPERLESS_DBPASS}' | base64 -d)" \
  --command -- sleep 3600

kubectl --context hetzner -n db-postgres wait pod/pg-restore-tmp \
  --for=condition=Ready --timeout=60s

# Copy dump to pod (use the exact filename captured in Step 2)
kubectl --context hetzner -n db-postgres cp "$DUMP_FILE" pg-restore-tmp:/tmp/paperless.sql

kubectl --context hetzner -n db-postgres exec pg-restore-tmp -- \
  psql -h postgres-postgresql.db-postgres.svc.cluster.local \
    -U paperless paperless \
    -f /tmp/paperless.sql

kubectl --context hetzner -n db-postgres delete pod pg-restore-tmp
```

---

## Step 5 — Start Paperless-NGX on Hetzner

```bash
kubectl --context hetzner -n apps-paperless-ngx scale deployment paperless-ngx-webserver --replicas=1

kubectl --context hetzner -n apps-paperless-ngx rollout status deployment/paperless-ngx-webserver

kubectl --context hetzner -n apps-paperless-ngx logs -f deployment/paperless-ngx-webserver
```

---

## Step 6 — Verify (Parallel — homelab still up)

Paperless is running at `https://paperless-hetzner.rohu-shark.ts.net` at this point.
The homelab instance is scaled to 0 but data is intact. Verify before committing to cutover.

1. Open `https://paperless-hetzner.rohu-shark.ts.net` (via Tailscale)
2. Log in with existing credentials
3. Verify document count matches homelab (check All Documents count)
4. Test document search
5. Test uploading a test document via the consume folder
6. Check ArgoCD `paperless-ngx` app is healthy at `https://argocd-hetzner.rohu-shark.ts.net`

---

## Step 7 — Cutover to Production Hostname

Once verified, rename Paperless from the `-hetzner` URL to the production URL.
Edit these two files and push to `main`:

**`hetzner/k8s/paperless_ngx/configmap.yml`** — change:

```yaml
PAPERLESS_URL: "https://paperless-hetzner.rohu-shark.ts.net"
```

to:

```yaml
PAPERLESS_URL: "https://paperless.rohu-shark.ts.net"
```

**`hetzner/k8s/paperless_ngx/ingress.yml`** — change both `host` and `tls.hosts[0]`
from `paperless-hetzner.rohu-shark.ts.net` to `paperless.rohu-shark.ts.net`.

ArgoCD will sync within ~3 minutes. The Tailscale Operator will provision the new
hostname automatically. The old `-hetzner` Tailscale device will be deprovisioned.

---

## Step 8 — Cleanup

```bash
# Remove local dump and archive files (sensitive data)
rm "$DUMP_FILE" /tmp/paperless-*.tar.gz

# Scale down homelab Paperless-NGX if not already done
kubectl --context homelab -n apps-paperless-ngx scale deployment paperless-ngx-webserver --replicas=0
```

The homelab PVCs use `nfs-synology-delete` but the data on the Synology NAS persists
as long as the PVCs are not deleted from Kubernetes. Leave them in place until you
confirm the Hetzner migration is stable (a few days of normal use).

---

## Rollback Procedure

If anything goes wrong before or during cutover, roll back to homelab:

```bash
# 1. Scale down Hetzner Paperless-NGX
kubectl --context hetzner -n apps-paperless-ngx scale deployment paperless-ngx-webserver --replicas=0

# 2. Scale up homelab Paperless-NGX
kubectl --context homelab -n apps-paperless-ngx scale deployment paperless-ngx-webserver --replicas=1

# 3. Verify homelab is accessible at paperless.rohu-shark.ts.net
```

The homelab PVCs were never deleted (data intact on Synology). No data loss possible
as long as you scale down Hetzner before scaling up homelab.

---

## Notes

- Both Postgres deployments use the Bitnami PostgreSQL Helm chart `18.1.1`. The temp
  pods in Steps 2 and 4d use `--image=bitnami/postgresql:latest`, which is the canonical
  form for one-shot kubectl runs. **Before running the migration**, confirm the exact
  image tag in use by the running Postgres pod on homelab:
  `kubectl --context homelab -n db-postgres get pod -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].spec.containers[0].image}'`
  Use that same tag (e.g. `bitnami/postgresql:17.2.0`) for both the dump pod and the
  restore pod, replacing `:latest` in the commands above. This guarantees pg_dump format
  compatibility between the two steps.
- Paperless-NGX uses the filesystem for media and PostgreSQL for metadata. Both must
  be migrated together and be consistent with each other (always dump and rsync from
  the same quiesced state — Step 1 ensures this).
- Do not run Paperless-NGX on both clusters simultaneously after cutover (Step 7).
  Prior to cutover, running both is safe since they use different hostnames.

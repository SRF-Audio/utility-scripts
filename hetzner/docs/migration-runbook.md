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

## kubectl Context Reference

| Cluster  | kubectl context          |
|----------|--------------------------|
| Homelab  | `coachlight-k3s-cluster` |
| Hetzner  | `hetzner`                |

All commands below use these exact context names.

---

## Homelab PVC Reference

Current homelab PVC names (confirmed via `kubectl get pvc -n apps-paperless-ngx`):

| Volume   | Homelab PVC name            | Hetzner PVC name       | Actual size |
|----------|-----------------------------|------------------------|-------------|
| data     | `paperless-ngx-data-nfs`    | `paperless-ngx-data`   | 313 MB      |
| media    | `paperless-ngx-media-nfs`   | `paperless-ngx-media`  | 646 MB      |
| export   | `paperless-ngx-export-nfs`  | `paperless-ngx-export` | ~0 MB       |
| consume  | `paperless-ngx-consume`     | `paperless-ngx-consume`| 115 MB      |

Total data to transfer: ~1.1 GB. Transfer via `tar | kubectl exec` should be fast.

The `consume` PVC has no `-nfs` suffix on homelab either (it was manually provisioned
against the Synology NFS, not via the NFS provisioner).

---

## Step 0 — Take Synology NAS Snapshot

Do this before touching anything. The Synology NAS holds the source PVC data; a snapshot
ensures you can recover it even if something goes wrong with the homelab cluster.

```bash
# SSH to NAS and create a snapshot on the k3s-cluster-storage volume
# (adjust share name if yours differs)
ssh admin@192.168.226.6 \
  "synodiskutil snapshotpair take /volume2/k3s-cluster-storage --desc 'pre-paperless-migration'"

# Verify the snapshot exists
ssh admin@192.168.226.6 \
  "synodiskutil snapshotpair list /volume2/k3s-cluster-storage"
```

> **If the `synodiskutil` command is unavailable**, take the snapshot manually via the
> Synology DSM web UI: Storage Manager → Shared Folder → k3s-cluster-storage → Snapshot →
> Take. Confirm the new snapshot appears in the list before continuing.

**Do not proceed to Step 1 until the snapshot is confirmed.**

---

## Pre-Migration Checklist

- [ ] Hetzner cluster is bootstrapped and healthy (all ArgoCD apps green — confirmed 2026-04-12)
- [ ] PostgreSQL is running on Hetzner in `db-postgres` namespace
- [ ] Redis is running on Hetzner in `db-redis` namespace
- [ ] `paperless-ngx` ArgoCD app is synced on Hetzner (Paperless pod Running with empty DB)
- [ ] Synology NAS snapshot taken
- [ ] You have `kubectl` contexts for both clusters: `coachlight-k3s-cluster` and `hetzner`
- [ ] You have SSH access to the Hetzner node
- [ ] Tailscale is active on both clusters

---

## Step 1 — Stop Paperless-NGX on Homelab

Both ArgoCD applications have `selfHeal: true`. You MUST disable auto-sync before scaling
to zero, or ArgoCD will immediately scale it back up.

**IMPORTANT (confirmed 2026-04-13)**: The homelab uses an app-of-apps pattern. The `root`
ArgoCD Application manages the `paperless-ngx` Application object with `selfHeal: true`.
Patching `paperless-ngx` alone is immediately reverted by `root`. You must disable `root`
first — nothing manages `root`, so that patch sticks.

```bash
# Disable auto-sync on root app first (prevents it from reverting the paperless-ngx patch)
kubectl --context coachlight-k3s-cluster -n argocd patch application root \
  --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'

# Now disable auto-sync on paperless-ngx (root can no longer revert this)
kubectl --context coachlight-k3s-cluster -n argocd patch application paperless-ngx \
  --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'

# Verify auto-sync is disabled on paperless-ngx
kubectl --context coachlight-k3s-cluster -n argocd get application paperless-ngx \
  -o jsonpath='{.spec.syncPolicy}' | python3 -m json.tool
# Expected: no "automated" key

# Scale down to 0 replicas to prevent writes during migration
kubectl --context coachlight-k3s-cluster -n apps-paperless-ngx \
  scale deployment paperless-ngx-webserver --replicas=0

# Wait and confirm replica count is 0 and stays 0
sleep 10 && \
kubectl --context coachlight-k3s-cluster -n apps-paperless-ngx get pods && \
kubectl --context coachlight-k3s-cluster -n apps-paperless-ngx \
  get deployment paperless-ngx-webserver -o jsonpath='replicas={.spec.replicas}{"\n"}'
```

**Do NOT delete the PVCs. Just scale to zero.**

---

## Step 2 — Export PostgreSQL Database

Both clusters run the identical PostgreSQL image (`bitnamilegacy/postgresql:latest`,
SHA256 `42a8200d35971f931b869ef5252d996e137c6beb4b8f1b6d2181dc7d1b6f62e0`, confirmed
2026-04-13). Use `bitnamilegacy/postgresql:latest` for the temp pod.

```bash
# Start a temporary psql client pod on homelab cluster
kubectl --context coachlight-k3s-cluster -n db-postgres run pg-dump-tmp \
  --image=bitnamilegacy/postgresql:latest \
  --restart=Never \
  --env="PGPASSWORD=$(kubectl --context coachlight-k3s-cluster -n db-postgres get secret paperless-ngx-secrets \
    -o jsonpath='{.data.PAPERLESS_DBPASS}' | base64 -d)" \
  --command -- sleep 3600

kubectl --context coachlight-k3s-cluster -n db-postgres wait pod/pg-dump-tmp \
  --for=condition=Ready --timeout=60s

# Run pg_dump and save locally
DUMP_FILE="/tmp/paperless-$(date +%Y%m%d-%H%M).sql"
kubectl --context coachlight-k3s-cluster -n db-postgres exec pg-dump-tmp -- \
  pg_dump -h postgres-postgresql.db-postgres.svc.cluster.local \
    -U paperless paperless \
  > "$DUMP_FILE"

# Verify dump is non-empty and is a valid PostgreSQL dump
ls -lh "$DUMP_FILE"
head -5 "$DUMP_FILE" | grep -q 'PostgreSQL database dump' \
  || { echo "ERROR: $DUMP_FILE does not look like a valid pg_dump output. Aborting."; exit 1; }
echo "DUMP OK: $DUMP_FILE"

# Clean up the temp pod
kubectl --context coachlight-k3s-cluster -n db-postgres delete pod pg-dump-tmp
```

**Note**: Keep the same shell session open (or re-export `$DUMP_FILE`) through Step 4d —
the restore step references this variable.

---

## Step 3 — Copy Paperless Media and Data Volumes

### Option A: Via kubectl exec (works regardless of NFS access)

```bash
# Start a reader pod on homelab with all PVCs mounted
cat <<EOF | kubectl --context coachlight-k3s-cluster apply -f -
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

kubectl --context coachlight-k3s-cluster -n apps-paperless-ngx wait \
  pod/paperless-migration-reader --for=condition=Ready --timeout=60s

# Archive each volume (total ~1.1 GB — should complete in a few minutes)
kubectl --context coachlight-k3s-cluster -n apps-paperless-ngx \
  exec paperless-migration-reader -- tar czf - /paperless/data \
  > /tmp/paperless-data.tar.gz

kubectl --context coachlight-k3s-cluster -n apps-paperless-ngx \
  exec paperless-migration-reader -- tar czf - /paperless/media \
  > /tmp/paperless-media.tar.gz

kubectl --context coachlight-k3s-cluster -n apps-paperless-ngx \
  exec paperless-migration-reader -- tar czf - /paperless/export \
  > /tmp/paperless-export.tar.gz

kubectl --context coachlight-k3s-cluster -n apps-paperless-ngx \
  exec paperless-migration-reader -- tar czf - /paperless/consume \
  > /tmp/paperless-consume.tar.gz

echo "Archive sizes:"
ls -lh /tmp/paperless-*.tar.gz

kubectl --context coachlight-k3s-cluster -n apps-paperless-ngx \
  delete pod paperless-migration-reader
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

Same app-of-apps pattern applies — disable `root` first, then `paperless-ngx`.

```bash
# Disable auto-sync on Hetzner root app first
kubectl --context hetzner -n argocd patch application root \
  --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'

# Now disable auto-sync on paperless-ngx
kubectl --context hetzner -n argocd patch application paperless-ngx \
  --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'

# Verify
kubectl --context hetzner -n argocd get application paperless-ngx \
  -o jsonpath='{.spec.syncPolicy}' | python3 -m json.tool

# Scale down
kubectl --context hetzner -n apps-paperless-ngx \
  scale deployment paperless-ngx-webserver --replicas=0

# Wait and confirm it stays at 0
sleep 10 && \
kubectl --context hetzner -n apps-paperless-ngx \
  get deployment paperless-ngx-webserver -o jsonpath='replicas={.spec.replicas}{"\n"}'
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

cat /tmp/paperless-consume.tar.gz | kubectl --context hetzner -n apps-paperless-ngx \
  exec -i paperless-migration-writer -- tar xzf - -C /

kubectl --context hetzner -n apps-paperless-ngx delete pod paperless-migration-writer
```

### 4d — Restore PostgreSQL database on Hetzner

```bash
kubectl --context hetzner -n db-postgres run pg-restore-tmp \
  --image=bitnamilegacy/postgresql:latest \
  --restart=Never \
  --env="PGPASSWORD=$(kubectl --context hetzner -n db-postgres get secret paperless-ngx-secrets \
    -o jsonpath='{.data.PAPERLESS_DBPASS}' | base64 -d)" \
  --command -- sleep 3600

kubectl --context hetzner -n db-postgres wait pod/pg-restore-tmp \
  --for=condition=Ready --timeout=60s

# Resolve dump file — use $DUMP_FILE if still set from Step 2, otherwise pick the latest
DUMP_FILE="${DUMP_FILE:-$(ls -t /tmp/paperless-*.sql 2>/dev/null | head -1)}"
[[ -z "$DUMP_FILE" ]] && { echo "ERROR: no dump file found in /tmp. Aborting."; exit 1; }
echo "Restoring from: $DUMP_FILE"

kubectl --context hetzner -n db-postgres cp "$DUMP_FILE" pg-restore-tmp:/tmp/paperless.sql

# IMPORTANT (confirmed 2026-04-13): Paperless-NGX runs Django migrations on first startup,
# creating the full schema before we restore. Restoring on top of an existing schema causes
# constraint-already-exists errors and leaves documents_document empty. Drop and recreate
# the schema first to get a clean slate.
kubectl --context hetzner -n db-postgres exec pg-restore-tmp -- \
  psql -h postgres-postgresql.db-postgres.svc.cluster.local \
    -U paperless paperless \
    -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO paperless;"

kubectl --context hetzner -n db-postgres exec pg-restore-tmp -- \
  psql -h postgres-postgresql.db-postgres.svc.cluster.local \
    -U paperless paperless \
    -f /tmp/paperless.sql

# Verify restore — row count must be non-zero
DOC_COUNT=$(kubectl --context hetzner -n db-postgres exec pg-restore-tmp -- \
  psql -h postgres-postgresql.db-postgres.svc.cluster.local \
    -U paperless paperless \
    -At -c "SELECT COUNT(*) FROM documents_document;")
echo "Documents restored: $DOC_COUNT"
[[ "$DOC_COUNT" -gt 0 ]] || { echo "ERROR: documents_document is empty after restore. Do not proceed."; exit 1; }

kubectl --context hetzner -n db-postgres delete pod pg-restore-tmp
```

---

## Step 5 — Start Paperless-NGX on Hetzner

Re-enable auto-sync on both `root` and `paperless-ngx` before scaling up, so ArgoCD
fully manages the cluster again.

```bash
# Re-enable auto-sync on root app
kubectl --context hetzner -n argocd patch application root \
  --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true},"syncOptions":["CreateNamespace=true","PrunePropagationPolicy=foreground","PruneLast=true"]}}}'

# Re-enable auto-sync on paperless-ngx
kubectl --context hetzner -n argocd patch application paperless-ngx \
  --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true},"syncOptions":["CreateNamespace=true"]}}}'

# Scale up
kubectl --context hetzner -n apps-paperless-ngx \
  scale deployment paperless-ngx-webserver --replicas=1

kubectl --context hetzner -n apps-paperless-ngx \
  rollout status deployment/paperless-ngx-webserver

# Tail logs — look for active task consumption, no crash loops.
# The XFA form error ("This PDF contains dynamic XFA forms...") is a pre-existing
# document in the consume folder that Paperless has always rejected — not a migration issue.
kubectl --context hetzner -n apps-paperless-ngx \
  logs -f deployment/paperless-ngx-webserver
```

---

## Step 6 — Verify (Parallel — homelab still down)

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

# Leave homelab Paperless-NGX scaled to 0 for now (data on Synology is intact)
# Leave homelab ArgoCD auto-sync disabled (paperless-ngx app)
# Only re-enable or delete after confirming Hetzner is stable for several days
```

The homelab PVCs use `nfs-synology-retain` — the data on the Synology NAS persists
as long as the PVCs are not deleted from Kubernetes. Leave them in place until you
confirm the Hetzner migration is stable (a few days of normal use).

---

## Rollback Procedure

If anything goes wrong before or during cutover, roll back to homelab:

```bash
# 1. Scale down Hetzner Paperless-NGX
kubectl --context hetzner -n apps-paperless-ngx \
  scale deployment paperless-ngx-webserver --replicas=0

# 2. Re-enable auto-sync on homelab root and paperless-ngx apps
kubectl --context coachlight-k3s-cluster -n argocd patch application root \
  --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true},"syncOptions":["CreateNamespace=true","PrunePropagationPolicy=foreground","PruneLast=true"]}}}'

kubectl --context coachlight-k3s-cluster -n argocd patch application paperless-ngx \
  --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true},"syncOptions":["CreateNamespace=true"]}}}'

# 3. Scale up homelab Paperless-NGX
kubectl --context coachlight-k3s-cluster -n apps-paperless-ngx \
  scale deployment paperless-ngx-webserver --replicas=1

# 4. Verify homelab is accessible at paperless.rohu-shark.ts.net
kubectl --context coachlight-k3s-cluster -n apps-paperless-ngx get pods
```

The homelab PVCs were never deleted (data intact on Synology). No data loss possible
as long as you scale down Hetzner before scaling up homelab.

---

## Notes

- Both Postgres deployments use the Bitnami PostgreSQL Helm chart `18.1.1` with
  `bitnamilegacy/postgresql` image. Both clusters pull the identical image digest
  (`sha256:42a8200d35971f931b869ef5252d996e137c6beb4b8f1b6d2181dc7d1b6f62e0`, confirmed
  2026-04-13), so `pg_dump` format compatibility is guaranteed.
- Paperless-NGX uses the filesystem for media and PostgreSQL for metadata. Both must
  be migrated together and be consistent with each other (always dump and rsync from
  the same quiesced state — Step 1 ensures this).
- Do not run Paperless-NGX on both clusters simultaneously after cutover (Step 7).
  Prior to cutover, running both is safe since they use different hostnames.

# Cluster Primitives

This directory contains foundational storage primitives for the Kubernetes cluster, managed via ArgoCD.

## Contents

### StorageClasses

Four StorageClasses are defined to provide explicit, deterministic storage options:

#### Local Storage (Node Disk)
- **local-path-delete**: Uses `rancher.io/local-path` provisioner with `Delete` reclaim policy
- **local-path-retain**: Uses `rancher.io/local-path` provisioner with `Retain` reclaim policy
- Both use `WaitForFirstConsumer` volume binding mode
- Volume expansion disabled

#### NFS Storage (Synology)
- **nfs-synology-delete**: Prepared for `cluster.local/nfs-subdir-external-provisioner` with `Delete` reclaim policy
- **nfs-synology-retain**: Prepared for `cluster.local/nfs-subdir-external-provisioner` with `Retain` reclaim policy
- Both use `Immediate` volume binding mode
- Volume expansion enabled

> **Note**: The NFS StorageClasses reference a provisioner that will be deployed in a future update. They are created now to establish the storage primitive foundation.

### Static Persistent Volumes (PVs)

Nine static PVs are defined for tier-0 workloads with human-readable Synology NFS paths:

#### Paperless PVs
- `pv-paperless-consume` (10Gi) → `/volume2/paperless/consume`
- `pv-paperless-data` (1Gi) → `/volume2/paperless/data`
- `pv-paperless-export` (10Gi) → `/volume2/paperless/export`
- `pv-paperless-media` (50Gi) → `/volume2/paperless/media`

#### Crafty PVs
- `pv-crafty-servers` (200Gi) → `/volume2/crafty/servers`
- `pv-crafty-backups` (20Gi) → `/volume2/crafty/backups`
- `pv-crafty-import` (50Gi) → `/volume2/crafty/import`
- `pv-crafty-config` (10Gi) → `/volume2/crafty/config`
- `pv-crafty-logs` (10Gi) → `/volume2/crafty/logs`

All static PVs:
- Use the `nfs-synology-retain` StorageClass
- Have `Retain` reclaim policy for data safety
- Support `ReadWriteMany` (RWX) access mode
- Use NFS v4 protocol
- Point to NFS server: `192.168.226.6`

## Usage

These resources are deployed via the `cluster-primitives` ArgoCD Application and will remain `Available` until PVCs are created to bind to them in future migrations.

## Deployment

The ArgoCD Application is defined at:
```
argocd/cluster_primitives/cluster_primitives.yml
```

It targets the kustomize root at:
```
k8s/cluster_primitives/
```

## Validation

To validate the manifests locally:

```bash
kustomize build k8s/cluster_primitives
```

To check syntax:

```bash
yamllint k8s/cluster_primitives/
```

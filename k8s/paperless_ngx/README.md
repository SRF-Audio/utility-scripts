# Paperless-NGX Kubernetes Manifests

This directory contains static Kubernetes manifests for deploying Paperless-NGX to a cluster via ArgoCD.

## Components

### Core Services (Required)
- `namespace.yml` - Namespace definition
- `configmap.yml` - ConfigMap for non-secret environment variables
- `onepassword-item.yml` - OnePasswordItem CRD for secrets (requires 1Password Operator)
- `pvcs.yml` - PersistentVolumeClaims for data storage
- `db.yml` - PostgreSQL database
- `broker.yml` - Redis broker
- `webserver.yml` - Paperless-NGX web application
- `ingress.yml` - Ingress for Homepage discovery

### Optional Services
- `tika.yml` - Apache Tika for advanced document parsing
- `gotenberg.yml` - Gotenberg for document conversion

**Note**: The ConfigMap includes Tika and Gotenberg endpoints by default. If you remove these services, Paperless-NGX will log warnings but continue to function normally. To fully disable them, also remove or comment out the corresponding environment variables in `configmap.yml`:
- `PAPERLESS_TIKA_ENABLED`
- `PAPERLESS_TIKA_ENDPOINT`
- `PAPERLESS_TIKA_GOTENBERG_ENDPOINT`

## Secrets

This deployment uses the 1Password Operator to inject secrets. Create a 1Password item at the path specified in `onepassword-item.yml` with the following fields:
- `PAPERLESS_DBNAME` - PostgreSQL database name
- `PAPERLESS_DBUSER` - PostgreSQL username
- `PAPERLESS_DBPASS` - PostgreSQL password
- `PAPERLESS_SECRET_KEY` - Django secret key for Paperless-NGX

## Storage Classes

The manifests assume:
- `local-path` storage class for local I/O-sensitive data (PostgreSQL, Redis, app data)
- `synology-csi-nfs-delete` storage class for bulk storage (media, exports, consume)

Adjust storage classes and sizes in `pvcs.yml` as needed for your environment.

## Deployment

Deploy using the `paperless_ngx_deploy` Ansible role, which creates an ArgoCD Application pointing to this directory.

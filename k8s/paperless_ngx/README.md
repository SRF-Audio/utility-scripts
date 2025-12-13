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

To disable optional services, simply delete or comment out the corresponding files before deploying with ArgoCD.

## Secrets

This deployment uses the 1Password Operator to inject secrets. Create a 1Password item at the path specified in `onepassword-item.yml` with the following fields:
- `PAPERLESS_DBNAME` - PostgreSQL database name
- `PAPERLESS_DBUSER` - PostgreSQL username
- `PAPERLESS_DBPASS` - PostgreSQL password
- `PAPERLESS_SECRET_KEY` - Django secret key for Paperless-NGX

## Storage Classes

The manifests assume:
- `local-path` storage class for local I/O-sensitive data (PostgreSQL, Redis, app data)
- `nfs-delete` storage class for bulk storage (media, exports, consume)

Adjust storage classes and sizes in `pvcs.yml` as needed for your environment.

## Deployment

Deploy using the `paperless_ngx_deploy` Ansible role, which creates an ArgoCD Application pointing to this directory.

# Homepage Kubernetes Manifests

This directory contains raw Kubernetes manifests for deploying Homepage to the cluster.

## Contents

- `namespace.yml` - Creates the `infra-homepage` namespace
- `serviceaccount.yml` - ServiceAccount for Homepage
- `clusterrole.yml` - ClusterRole with permissions to read cluster resources
- `clusterrolebinding.yml` - Binds the ClusterRole to the ServiceAccount
- `configmap.yml` - Homepage configuration (services, widgets, kubernetes mode)
- `deployment.yml` - Homepage Deployment
- `service.yml` - Service with Tailscale annotations for external access
- `onepassworditem-*.yml` - OnePasswordItem CRDs for secret management
- `application.yml` - ArgoCD Application pointing to this directory

## OnePasswordItem CRDs

The following OnePasswordItem CRDs are used to sync secrets from 1Password:

### homepage-argocd-token
- **1Password Path**: `vaults/k8s-homelab/items/argocd-homepage-token`
- **Expected Secret Keys**: `token`
- **Created by**: `argocd_homepage_token` Ansible role
- **Purpose**: ArgoCD API token for the ArgoCD widget

### homepage-nextdns-token
- **1Password Path**: `vaults/k8s-homelab/items/nextdns-api-token`
- **Expected Secret Keys**: `api_token` (or verify actual field name in 1Password)
- **Purpose**: NextDNS API token for the NextDNS widget

### homepage-proxmox-password
- **1Password Path**: `vaults/k8s-homelab/items/proxmox-api-password`
- **Expected Secret Keys**: `password` (or verify actual field name in 1Password)
- **Purpose**: Proxmox API password for the Proxmox widget

> **Note**: The 1Password Operator creates Kubernetes secrets where the keys match the field labels from the 1Password item. If the deployment fails to start due to missing secret keys, verify the actual field names in the 1Password items and update the `deployment.yml` secretKeyRef entries accordingly.

## Deployment

This directory is deployed via ArgoCD using the `homepage_deploy` Ansible role, which applies the `application.yml` manifest. ArgoCD then syncs all other manifests from this directory.

## Environment Variables

The Deployment references the following environment variables from the OnePasswordItem-created secrets:

- `HOMEPAGE_VAR_NEXTDNS_TOKEN` - from `homepage-nextdns-token` secret key `api_token`
- `HOMEPAGE_VAR_PROXMOX_PASSWORD` - from `homepage-proxmox-password` secret key `password`
- `HOMEPAGE_VAR_ARGOCD_TOKEN` - from `homepage-argocd-token` secret key `token`

These variables are used in the ConfigMap's service definitions using Homepage's variable substitution syntax: `{{HOMEPAGE_VAR_*}}`

## Prerequisites

1. 1Password Operator must be deployed and configured
2. 1Password items must exist at the specified paths with the correct field names
3. ArgoCD must be deployed and accessible
4. The `argocd_homepage_token` Ansible role should be run before deploying to ensure the ArgoCD token exists in 1Password

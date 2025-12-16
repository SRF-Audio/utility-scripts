# Homepage Static Manifests

This directory contains static Kubernetes manifests for Homepage configuration that are managed by ArgoCD.

## Files

- `onepassworditem-argocd-token.yaml` - OnePasswordItem CRD that syncs the ArgoCD API token from 1Password into a Kubernetes secret
- `ingress-argocd.yaml` - Ingress for ArgoCD with Homepage discovery annotations to configure the ArgoCD widget

## How It Works

1. The `argocd_homepage_token` Ansible role mints/rotates the ArgoCD token and stores it in 1Password (vault: HomeLab, item: argocd-homepage-token)
2. The OnePasswordItem CRD syncs this token into a secret named `homepage-argocd-token` in the `infra-homepage` namespace
3. Homepage is deployed via Helm and mounts this secret as the environment variable `HOMEPAGE_VAR_ARGOCD_TOKEN`
4. Homepage discovers the ArgoCD ingress via Kubernetes annotations and uses `{{HOMEPAGE_VAR_ARGOCD_TOKEN}}` to authenticate
5. The widget uses the cluster-local URL `http://argocd-server.argocd` to query the ArgoCD API

## Deployment

These manifests should be applied after:
- 1Password Operator is deployed
- ArgoCD is deployed
- Homepage is deployed

They can be applied via:
- ArgoCD Application pointing to this directory
- `kubectl apply -k k8s/homepage/`
- Ansible role (temporary until fully GitOps-native)

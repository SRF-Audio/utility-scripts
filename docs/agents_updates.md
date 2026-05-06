# AGENTS.md Refactoring Notes

## Goal

Adapt the SHIFT work-repo root AGENTS.md for this homelab repo.

## Key Differences (homelab vs SHIFT)

| Aspect | SHIFT (work) | Homelab (this repo) |
|--------|--------------|---------------------|
| Hypervisor | AWS/Azure | Proxmox VE |
| Cloud | AWS, Azure | Hetzner Cloud |
| IaC | Terraform (first-class) | None — no Terraform |
| K8s distro | RKE2 | k3s |
| Storage | Cloud-native (EBS, etc.) | Synology NAS → NFS to Proxmox VMs |
| VCS/CI | GitLab + GitLab CI | GitHub + GitHub Actions |
| MCP servers | gitlab, kubernetes, aws-core, aws-docs | github, fetch |
| Secrets | 1Password (same) | 1Password (same) |
| GitOps | ArgoCD (same) | ArgoCD (same) |
| Networking | Cloud LBs / Istio | Tailscale only, no public ingress |

## Sections to Keep (adapt language)

- Guidance locations and precedence (adjust paths — no `/workspace/`, use relative)
- GitOps Deployment Model (remove RKE2 refs, replace with k3s; remove Terraform provisioning from Ansible's job)
- Pre-commit gate (remove `trivy config` on Terraform; keep for k8s manifests)
- Secrets handling (keep as-is, already 1Password-centric; remove Vault refs)
- Context Engineering and Documentation Discipline (keep entirely — repo-agnostic)
- How to behave as an agent (remove Terraform/Helm subtree routing; adjust for actual dirs)

## Sections to Remove Entirely

- Terraform orchestration references (no Terraform here)
- AWS/Azure references
- GitLab MCP / GitLab CI references
- RKE2-specific language
- `kubernetes` MCP server (using kubectl via bash here)
- `aws-core` / `aws-docs` MCP servers

## Sections to Add or Expand

- MCP server inventory table (github + fetch) — already in current AGENTS.md
- "What is NOT an MCP server" table (kubectl, hcloud, op, ansible, git, ssh)
- Tool usage rules section (Kubernetes, GitHub, Ansible, Hetzner Cloud, SSH — with read/write boundaries)
- Infrastructure Stack summary (Proxmox, Synology NFS, Hetzner, Tailscale, GitHub Actions)
- Subagents section (already exists in current AGENTS.md — keep)

## Current AGENTS.md Structure (what exists today)

1. Role & Scope
2. Environment (Clusters table, Key Tooling, MCP Servers, Subagents)
3. Core Mandates (5 items)
4. Code Quality Standards (Linting, Testing, Hygiene)
5. Delivery Standards (response format)

## Target Structure (merged from work template + homelab context)

1. Title + scope intro + breadcrumbs
2. Guidance locations and precedence
3. MCP server inventory + "not MCP" table
4. Environment (clusters, infrastructure stack, subagents)
5. Tool usage rules (per-tool read/write boundaries)
6. GitOps Deployment Model
7. Secrets handling
8. Pre-commit gate
9. Core mandates (adapted — no Terraform idempotency)
10. Code quality standards (linting table, security guardrails, testing, hygiene)
11. Context Engineering and Documentation Discipline (verbatim from work template)
12. Response format
13. How to behave as an agent

## Source Material

The user provided the SHIFT work-repo root AGENTS.md (pasted in conversation).
The user also provided the SHIFT ansible/AGENTS.md for structural reference.
The current homelab AGENTS.md is at `/home/sfroeber/GitHub/utility-scripts/AGENTS.md`.

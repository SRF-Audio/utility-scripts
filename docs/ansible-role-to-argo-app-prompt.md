## Copilot Spec: Adopt “Root App” GitOps Structure (App-of-Apps) + Per-App Folder Contract

### Goal

Implement a repeatable repository structure where:

* **Ansible bootstraps only**: Argo CD + 1Password Operator + repo scaffolding (already solved via `op` CLI).
* After bootstrap, **Argo CD owns everything else** via a **single Root Application** that watches `./argocd`.
* Each application is added in a consistent way: **one Argo Application manifest + one `./k8s/<app>` folder** (and optional `..._secrets` folder only when the app is Helm-only).

### Non-goals

* Do not rework existing apps in bulk.
* Do not introduce ApplicationSet unless explicitly requested.
* Do not template Argo Applications via Ansible.

---

## Repository Contract (Must Follow)

### 1) Root GitOps Entry Point

Create/ensure this structure exists:

```
argocd/
  root.yml
  projects/
  apps/
    operators/
    platform/
    apps/
k8s/
  <app_name>/
```

**Rules**

* `argocd/root.yml` is the single “App-of-Apps” root Application.
* All Argo `Application` resources (children) live under `argocd/apps/**`.
* Kubernetes manifests (non-Helm) live under `k8s/**`.
* No per-app Argo templates in Ansible.

---

## ArgoCD Root Application Requirements (`argocd/root.yml`)

Create a single Application that:

* Points at this repo and path `argocd/apps`
* Enables automated sync (prune + selfHeal)
* Uses sync options that prevent common bootstrap races

**Must include**:

* `spec.source.path: argocd/apps`
* `spec.destination.namespace: argocd` (or your Argo namespace)
* `spec.syncPolicy.automated.prune: true`
* `spec.syncPolicy.automated.selfHeal: true`
* `syncOptions` (at minimum):

  * `CreateNamespace=true`
  * `PrunePropagationPolicy=foreground`
  * `PruneLast=true`

---

## Child Application Folder Contract (`argocd/apps/**`)

Each deployable thing in the cluster is represented by exactly **one** ArgoCD Application YAML under one of these directories:

```
argocd/apps/operators/
argocd/apps/platform/
argocd/apps/apps/
```

**Placement guidance**

* `operators/`: cluster operators and CRDs (1Password operator, Tailscale operator, cert-manager, etc.)
* `platform/`: shared infra primitives (storage classes, ingress gateway configs, monitoring stack, etc.)
* `apps/`: user workloads (homepage, paperless, crafty, etc.)

---

## Sync Wave Rules (Required)

Sync waves must enforce a **strict, predictable bootstrap order** with an explicit phase for secrets to settle before deploying anything that might consume them (including operators).

### Wave Definitions

* **Wave 0 – Cluster Bootstrap & Core Operators**

  * Argo CD projects
  * Namespaces
  * Core Argo configuration (RBAC, repo config, server patches)
  * Operators that introduce CRDs or cluster-wide controllers
    (including the 1Password Operator itself)

* **Wave 10 – Secrets & Credentials Settlement**

  * All `onepassword.com/*` CRD resources
  * Any secret-producing resources required by:

    * operators
    * platform services
    * application workloads
  * No workloads or operators that *consume* these secrets may be deployed in this wave

* **Wave 20 – Secondary Operators & Platform Services**

  * Operators and controllers that require secrets to exist first
  * Platform services that depend on operators and/or secrets
  * Examples:

    * ingress controllers / gateways
    * storage provisioners
    * observability stacks
    * backup systems (e.g., Velero)

* **Wave 30 – Application Workloads**

  * User-facing and service workloads
  * Applications that consume secrets, platform services, or both

---

### Hard Requirements

* The **1Password Operator must be deployed and healthy in Wave 0** before any `onepassword.com/*` CRDs are applied.
* **All OnePassword CRD resources must be deployed in Wave 10**.
* **No operator, platform service, or application may consume OnePassword-created secrets unless it is deployed in Wave 20 or later**.
* Do not combine secret creation and secret consumption in the same sync wave.

---

## Per-App Implementation Contract (Reusable “Add App” Pattern)

### A) If the app uses Kubernetes manifests (Kustomize or raw YAML)

Create:

```
k8s/<app_name>/
  kustomization.yml  (preferred)
  namespace.yml      (if needed)
  <manifests...>
  onepassword/       (optional)
```

**1Password CRDs location (must follow)**

* OnePassword CRD resources live alongside the app under:

```
k8s/<app_name>/onepassword/
```

**Sync wave (required)**

* All OnePassword CRDs for the app must be deployed in **Wave 10**.
* Any resource that consumes those secrets must be deployed after Wave 10:

  * **Wave 20** if it is an operator or platform service
  * **Wave 30** if it is an application workload

Example:

* `k8s/<app_name>/onepassword/*` → wave **10**
* operator/platform manifests → wave **20**
* application workload manifests → wave **30**

**Argo Application**

* Create `argocd/apps/apps/<app_name>.yml` pointing to `k8s/<app_name>`.

---

### B) If the app is Helm chart only (no k8s manifests folder)

Create:

```
argocd/apps/apps/<app_name>.yml
argocd/apps/apps/<app_name>_secrets/   (ONLY in this case)
  <onepassword CRDs here>
```

**Rule: create `<app_name>_secrets` folder ONLY when:**

* The app is deployed purely via Helm in the Argo Application (no `k8s/<app_name>` path)

**Secrets folder behavior**

* `argocd/apps/apps/<app_name>_secrets/*.yml` contains OnePassword CRD resources needed for the Helm release.
* The secrets Application must always deploy before the Helm Application using the standard waves:

Example:

* `<app_name>_secrets` Application → wave **10**
* `<app_name>` Helm Application → wave **20** (operator/platform) **or** wave **30** (application workload)

---

## Argo Application Manifest Requirements (All Apps)

For every child app `argocd/apps/**/<app_name>.yml`:

**Must include**

* `metadata.annotations.argocd.argoproj.io/sync-wave: "<N>"`
* `spec.project: <appropriate Argo Project>`
* `spec.destination.server: https://kubernetes.default.svc`
* `spec.destination.namespace: <target namespace>`
* `spec.syncPolicy.automated.prune: true`
* `spec.syncPolicy.automated.selfHeal: true`
* `spec.syncPolicy.syncOptions`:

  * `CreateNamespace=true`

**If Helm**

* Put overrides under `spec.source.helm.valuesObject` only (no external values files unless explicitly requested).

---

## Acceptance Criteria

* Root app exists and successfully syncs `argocd/apps/**`.
* Adding a new app follows **exactly one** of the two patterns:

  1. `k8s/<app_name>/...` (+ optional `k8s/<app_name>/onepassword/...`) and one Argo Application
  2. Helm-only Argo Application + `<app_name>_secrets` folder (and only in that case)
* OnePassword CRDs are colocated with the app (either `k8s/<app>/onepassword` or `argocd/apps/apps/<app_name>_secrets`) and always apply before the app consumes the Secrets.
* Sync wave ordering is consistent and enforces the dependency chain.
* No Ansible templating of Argo Applications is introduced.

---

## “Add a New App” Checklist (Copilot must follow each time)

When implementing `<app_name>`:

1. Decide: **manifest-based** (`k8s/<app_name>`) vs **Helm-only**
2. Place OnePassword CRDs:

   * manifest-based → `k8s/<app_name>/onepassword/` in **Wave 10**
   * helm-only → create `argocd/apps/apps/<app_name>_secrets/` in **Wave 10**
3. Create `argocd/apps/apps/<app_name>.yml` (and secrets app if helm-only)
4. Confirm sync waves and namespaces are correct (**Wave 20** for operator/platform, **Wave 30** for application workload)
5. Ensure Helm values overrides live in `valuesObject`

1. **Refactor `coachlight_infra_stack_deploy` playbook to “bootstrap then stop”**

   * Keep: kubeconfig retrieval/management, k8s validation, control-plane taints.
   * Keep Ansible roles only for:

     * `argocd_deploy`
     * `onepassword_operator_deploy` (still Ansible-managed due to templated secret)
     * `argocd_github_repo_create` (repo credentials/scaffolding via `op` CLI)
     * apply **single Root Argo Application**
   * Remove from this playbook: *all* other app/operator deployments and any direct `k8s_object_manager` applications besides the Root app.

2. **Create Root ArgoCD Application (`argocd/root.yml`) and `argocd/apps/` folder structure**

   * Add `argocd/root.yml` that watches `argocd/apps`.
   * Add folder structure:

     * `argocd/apps/operators/`
     * `argocd/apps/platform/`
     * `argocd/apps/apps/`
     * `argocd/projects/` (if you want projects GitOps-managed)
   * Enforce sync wave policy: **0 / 10 / 20 / 30**.

3. **Update `onepassword_operator_deploy` role to be strictly Ansible-managed (no Argo Application templating)**

   * Remove/stop using `templates/application.yml.j2` if it currently deploys the operator via Argo.
   * Ensure the role:

     * Creates the required Kubernetes Secret(s) (templated from vars)
     * Installs the operator chart/manifests directly
     * Waits for readiness (idempotent)
   * Make it the only non-Argo operator exception.

4. **Add “Root App apply” to Ansible (single Argo Application only)**

   * Create `argocd/apps/root.yml` *or* keep as `argocd/root.yml` and apply that exact file from Ansible via `k8s_object_manager`.
   * Remove Ansible-applied Argo apps for `nfs_provisioner`, `cluster_primitives`, `postgres`, `redis`, etc.

5. **Migrate `tailscale_operator_deploy` from Ansible-managed to Argo-managed**

   * Create `argocd/apps/operators/tailscale-operator.yml` (Wave **20** if it requires secrets; otherwise Wave **0**).
   * Create OnePassword CRDs for its OAuth secret in Wave **10** colocated per the contract.
   * Remove the `tailscale_operator_deploy` role from the bootstrap playbook.

6. **Migrate `nfs_provisioner` Argo Application into `argocd/apps/platform/`**

   * Create `argocd/apps/platform/nfs-provisioner.yml` with Wave **20**.
   * Move any NFS-related OnePassword CRDs (if any) into Wave **10** colocated appropriately.
   * Ensure this replaces the current Ansible `k8s_object_manager` apply of `argocd/nfs_provisioner/nfs_provisioner.yml`.

7. **Migrate `cluster_primitives` Argo Application into `argocd/apps/platform/`**

   * Create `argocd/apps/platform/cluster-primitives.yml` with Wave **20**.
   * Ensure any PV/SC manifests live under `k8s/cluster_primitives/` (or equivalent) and are referenced by the Argo app.
   * Remove the Ansible `k8s_object_manager` apply of `argocd/cluster_primitives/cluster_primitives.yml`.

8. **Migrate `synology_csi_deploy` to Argo-managed OR formally deprecate it**

   * If keeping Synology CSI:

     * Create `argocd/apps/platform/synology-csi.yml` (Wave **20**)
     * Any creds → OnePassword CRDs (Wave **10**) colocated with the CSI app.
     * Remove `synology_csi_deploy` from the bootstrap playbook.
   * If dropping Synology CSI:

     * Delete/retire role and existing Argo manifests; document replacement (NFS subdir + local-path, etc.).

9. **Convert “app roles” to pure GitOps apps (Homepage first)**

   * Create:

     * `argocd/apps/apps/homepage.yml` (Wave **30**)
     * `k8s/homepage/` manifests *or* Helm-only definition
     * OnePassword CRDs colocated:

       * `k8s/homepage/onepassword/` (Wave **10**) if manifest-based
       * or `argocd/apps/apps/homepage_secrets/` (Wave **10**) if Helm-only
   * Remove `argocd_homepage_token` and `homepage_deploy` from the playbook (and decide whether to retire the roles).

10. **Convert remaining app roles to GitOps apps (repeatable pattern)**

* One issue per app, each following the exact contract:

  * `crafty_controller` (Wave **30**)
  * `paperless_ngx` (Wave **30**)
  * `omada` (Wave **30** if it’s truly an “app”, or **20** if you treat it as platform)
  * `netbox` (Wave **30**)
  * `frigate` (Wave **30**)
* Each issue must colocate OnePassword CRDs and assign Wave **10**.

11. **Migrate Postgres + Redis Argo apps to match wave + secrets contract**

* Replace current:

  * `argocd/postgres/postgres.yml` + `postgres_secrets.yml`
  * `argocd/redis/redis.yml` + `redis_secrets.yml`
* New structure:

  * `argocd/apps/platform/postgres.yml` (Wave **20**) or `apps/` if you treat DBs as app-layer
  * `argocd/apps/platform/redis.yml` (Wave **20**) similarly
  * Secrets via OnePassword CRDs (Wave **10**) colocated (Helm-only → `<name>_secrets` folder; manifest-based → `k8s/<name>/onepassword/`)
* Remove Ansible `k8s_object_manager` applies for these.

12. **Remove Longhorn from repo and automation**

* Delete or archive `longhorn_deploy` role.
* Remove any Longhorn manifests/Argo apps.
* Confirm storage classes align with your current NFS/local strategy.

13. **Standardize/relocate Argo Projects management**

* Decide whether Argo Projects are:

  * managed by `argocd_deploy` (bootstrap) **or**
  * managed as GitOps under `argocd/projects/` with Wave **0**
* Implement the chosen approach consistently (avoid “some in Ansible, some in Git”).

14. **Add a reusable “New App Checklist” doc file in-repo**

* Add `docs/gitops_app_contract.md` (or similar) containing:

  * folder contract
  * wave system (0/10/20/30)
  * OnePassword CRD colocation rules
  * Helm-only `<app>_secrets` exception rule
* This becomes the canonical reference for future PRs.

If you want the list trimmed to the smallest viable set for the *first milestone*, do issues **1–5**, then **6–8** (platform), then **9** (Homepage) to validate the pattern end-to-end.

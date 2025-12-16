# Ansible Lint and Test Workflow - Path Scoping

This document explains how the `ansible-lint-and-test.yml` workflow implements path-scoped linting to prevent unrelated lint failures from blocking work.

## Overview

The workflow has been modified to:

1. **Automatic triggers (PR/push)**: Only lint and test changed Ansible paths
2. **Manual trigger**: Run full lint/test on all Ansible files (workflow_dispatch)

## Workflow Structure

### Jobs

1. **detect-changes**: Detects which Ansible files, roles, and playbooks have changed
2. **ansible-yamllint**: Runs yamllint on changed YAML files (or all files if manual)
3. **ansible-lint**: Runs ansible-lint on changed roles/playbooks (or all if manual)
4. **ansible-playbook-syntax-setup**: Builds dynamic matrix for syntax checks
5. **ansible-playbook-syntax**: Runs syntax checks on changed playbooks (or all if manual)

### Change Detection Logic

The `detect-changes` job:

- Detects if the trigger is manual (`workflow_dispatch`) or automatic (PR/push)
- Uses `tj-actions/changed-files@v44` to detect changed Ansible YAML files
- Extracts changed roles from file paths matching `ansible/roles/{role_name}/**`
- Extracts changed playbooks from paths matching `ansible/playbooks/*.yml` or `ansible/site.yml`

### Job Conditions

Each lint/test job runs when:

- **yamllint**: Any Ansible YAML files changed OR manual trigger
- **ansible-lint**: Any roles or playbooks changed OR manual trigger
- **playbook-syntax**: Any playbooks changed OR manual trigger

Jobs gracefully skip when no relevant files have changed.

## Test Scenarios

### Scenario 1: Single Role Change

**Change**: Edit `ansible/roles/argocd_deploy/tasks/main.yml`

**Expected behavior**:
- yamllint runs only on that file
- ansible-lint runs only on `ansible/roles/argocd_deploy`
- playbook-syntax skips (no playbooks changed)

### Scenario 2: Single Playbook Change

**Change**: Edit `ansible/playbooks/k3s-cluster-setup.yml`

**Expected behavior**:
- yamllint runs only on that file
- ansible-lint runs only on that playbook
- playbook-syntax runs only for `ansible/playbooks/k3s-cluster-setup.yml`

### Scenario 3: Multiple Roles Change

**Change**: Edit files in:
- `ansible/roles/argocd_deploy/`
- `ansible/roles/tailscale_operator_deploy/`

**Expected behavior**:
- yamllint runs on all changed YAML files
- ansible-lint runs on both roles
- playbook-syntax skips (no playbooks changed)

### Scenario 4: Role and Playbook Change

**Change**: Edit files in:
- `ansible/roles/argocd_deploy/`
- `ansible/playbooks/coachlight-infra-stack.yml`

**Expected behavior**:
- yamllint runs on all changed YAML files
- ansible-lint runs on the role and the playbook
- playbook-syntax runs for the changed playbook

### Scenario 5: Non-Ansible File Change

**Change**: Edit `README.md` or other non-Ansible files

**Expected behavior**:
- Workflow does not trigger (path filter at workflow level)

### Scenario 6: Manual Full Lint

**Action**: Manually trigger workflow from GitHub Actions UI

**Expected behavior**:
- yamllint runs on entire `ansible/` directory
- ansible-lint runs on all roles and playbooks (except `old_roles/`)
- playbook-syntax runs for all 11 playbooks in the matrix

### Scenario 7: Change in old_roles

**Change**: Edit `ansible/old_roles/workstation_prep/tasks/main.yml`

**Expected behavior**:
- Files under `ansible/old_roles/**` are ignored by changed-file detection
- yamllint may run on the file (not filtered at yamllint level)
- ansible-lint skips (old_roles excluded in detection)
- playbook-syntax skips (not a playbook)

## Manual Workflow Trigger

To run a full lint manually:

1. Go to Actions tab in GitHub
2. Select "Ansible – Lint and Test" workflow
3. Click "Run workflow" button
4. Leave `full_lint` checkbox checked (default)
5. Click "Run workflow"

## Benefits

1. **Faster feedback**: Only relevant files are linted
2. **Focused work**: Known lint issues in other areas don't block progress
3. **Reduced noise**: CI logs only show issues related to your changes
4. **Full coverage option**: Manual trigger ensures all files can still be checked

## Limitations

- Changed-file detection requires git history (`fetch-depth: 0`)
- First push to a new branch may not detect files correctly (compare against main)
- Workflow file itself (`ansible-lint-and-test.yml`) changes trigger full paths filter

## Maintenance

When adding new playbooks:

1. Add the playbook file to `ansible/playbooks/`
2. Update the hardcoded matrix in `ansible-playbook-syntax-setup` job
3. Look for the line with all playbook paths in JSON array format
4. Add your new playbook to the array

Example:
```yaml
matrix='["ansible/playbooks/audio-production.yml",...,"ansible/playbooks/your-new-playbook.yml","ansible/site.yml"]'
```

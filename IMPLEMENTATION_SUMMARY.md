# Summary: Scoped Ansible Lint Implementation

## Overview

This PR implements path-scoped linting for Ansible code, ensuring that only changed files are linted on PRs and pushes, while maintaining a manual option for full repository linting.

## Changes Made

### 1. Modified `.github/workflows/ansible-lint-and-test.yml`

**Added**:
- `workflow_dispatch` trigger for manual full-lint runs
- `detect-changes` job that identifies changed Ansible files, roles, and playbooks
- Dynamic matrix generation for playbook syntax checks
- Conditional job execution based on what files changed

**Modified**:
- `ansible-yamllint`: Now lints only changed YAML files (or all files if manual)
- `ansible-lint`: Now lints only changed roles/playbooks (or all if manual)
- `ansible-playbook-syntax`: Now checks only changed playbooks (or all if manual)

**Fixed**:
- Added missing `tailscale_tester.yml` to the full playbook matrix

### 2. Created `.github/workflows/ANSIBLE_LINT_SCOPING.md`

Comprehensive documentation covering:
- Workflow structure and behavior
- Change detection logic
- Test scenarios for all use cases
- Manual trigger instructions
- Maintenance guidelines

## Key Features

### Automatic Scoping (PR/Push)
- Detects changed files using `tj-actions/changed-files@v44`
- Extracts changed roles from paths matching `ansible/roles/{role_name}/**`
- Extracts changed playbooks from paths matching `ansible/playbooks/*.yml` or `ansible/site.yml`
- Runs lint/syntax checks only on affected files
- Skips jobs gracefully when no relevant files changed

### Manual Full Lint (workflow_dispatch)
- Runs yamllint on entire `ansible/` directory
- Runs ansible-lint on all roles and playbooks
- Runs syntax checks on all 11 playbooks
- Triggered via GitHub Actions UI

## Benefits

1. **Faster CI feedback**: Only changed files are processed
2. **Focused development**: Known issues elsewhere don't block progress
3. **Reduced noise**: Logs only show issues related to your changes
4. **Full coverage option**: Manual trigger ensures comprehensive checks remain available

## Testing

✅ Verified bash logic for role/playbook detection  
✅ Tested edge cases (no changes, multiple changes)  
✅ Validated YAML syntax with yamllint  
✅ Documented test scenarios in ANSIBLE_LINT_SCOPING.md

## Acceptance Criteria Met

✅ Editing a single role only lints that role  
✅ Editing a single playbook only syntax-checks that playbook  
✅ Multiple changed paths lint independently  
✅ Full lint runs only when manually triggered  
✅ No unrelated lint failures block focused work

## Design Decisions

1. **`tj-actions/changed-files`**: Reliable, well-maintained GitHub Action
2. **Separate matrix setup job**: Required by GitHub Actions architecture
3. **Job skip conditions**: Prevents unnecessary job execution
4. **Excluded `old_roles/`**: Legacy code doesn't affect change detection
5. **Preserved existing tooling**: Container images, permissions, build logic unchanged

## Migration Notes

- First PR after merge may trigger more linting than expected due to git history comparison
- No changes required to role/playbook code
- Workflow file changes will trigger the workflow due to path filter

## Future Maintenance

When adding new playbooks:
1. Add the playbook file to `ansible/playbooks/`
2. Update the hardcoded matrix in `ansible-playbook-syntax-setup` job (line 244)

## Related Documentation

- `.github/workflows/ANSIBLE_LINT_SCOPING.md` - Detailed workflow documentation
- `.github/instructions/ansible.instructions.md` - Ansible coding standards
- `.github/copilot-instructions.md` - CI lint failure guidelines

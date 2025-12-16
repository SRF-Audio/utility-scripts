# GitHub Copilot Instructions for utility-scripts Repository

This document provides guidance to GitHub Copilot on how to assist with specific workflows and tasks in this repository.

---

## Ansible CI Lint/Test Failures

When asked about a failed `ansible-lint-and-test` workflow run, follow these steps:

### 1. Inspect the Workflow Run

- Open the latest workflow run for the PR or branch referenced by the user
- Identify which job(s) failed: `ansible-yamllint`, `ansible-lint`, or `ansible-playbook-syntax`
- Read the failing step logs carefully to extract:
  - The exact file(s) and line number(s) causing the failure
  - The specific error message or rule violation
  - The type of failure (YAML formatting, ansible-lint rule, syntax error, etc.)

### 2. Classify the Failure

Common failure types include:

- **YAML formatting issues** (yamllint): indentation, line length, trailing spaces, etc.
- **Ansible-lint rule violations**: deprecated syntax, missing FQCNs, non-idempotent tasks, etc.
- **Syntax errors**: invalid YAML, undefined variables, malformed Jinja2 templates, etc.
- **Missing variables**: required role variables not declared in `argument_specs.yml`
- **Idempotency issues**: tasks using `command`/`shell` without proper guards

### 3. Propose Concrete Code Changes

When proposing fixes:

- **Align with Ansible best practices**:
  - Use fully qualified collection names (FQCN) for all modules (e.g., `ansible.builtin.copy`, `community.general.docker_container`)
  - Prefer official Ansible modules over `command`/`shell` wherever possible
  - Ensure idempotency: add `creates:`, `removes:`, or `changed_when:` to `command`/`shell` tasks
  - Use clear, descriptive task names with Jinja2 templating for dynamic values (e.g., `Install package {{ item }}`)

- **Respect this repository's style** (refer to `.github/instructions/ansible.instructions.md`):
  - All role variables must be prefixed with `<ROLE_NAME>_`
  - Every variable must be declared in `meta/argument_specs.yml`
  - Roles must follow the standard structure: `meta/`, `defaults/`, `tasks/`, with optional `files/`, `templates/`, `vars/`, `handlers/`
  - No inline comments in YAML files
  - Set `<ROLE_NAME>_artifacts` at the end of `tasks/main.yml` and call `role_artifacts` role
  - When calling `role_artifacts`, add `# noqa: var-naming` comment before the `vars:` list

- **Avoid introducing new lint violations**:
  - Test your proposed changes mentally against yamllint and ansible-lint rules
  - Ensure proper YAML indentation (2 spaces)
  - Keep lines under reasonable length (typically 160 characters)
  - Use proper quoting for strings when necessary

### 4. Explain the Reasoning

For each proposed change, provide a short explanation covering:

- **What** the error was (e.g., "Missing FQCN for the `copy` module")
- **Why** it's a problem (e.g., "Ansible-lint requires FQCNs for clarity and to avoid namespace conflicts")
- **How** the fix addresses it (e.g., "Changed `copy:` to `ansible.builtin.copy:`")

This helps build understanding rather than just patching blindly.

### 5. Patterns to Prefer

- **Modules over commands**: Use `ansible.builtin.package`, `ansible.builtin.service`, etc. instead of `command: dnf install ...`
- **Small, focused tasks**: Break complex operations into clear, single-purpose tasks
- **Avoid over-parameterization**: Reuse patterns from existing roles in `ansible/roles/` as the style reference
- **Idempotent by default**: Every task should be safe to run multiple times without breaking or recreating resources

### Example Workflow

User asks: *"Analyze the failed `ansible-lint-and-test` workflow for PR #123 and propose a patch."*

Your response should:

1. Reference the specific failed job (e.g., "The `ansible-lint` job failed")
2. Identify the file and issue (e.g., "`ansible/roles/example_role/tasks/main.yml:42` - missing FQCN for `copy` module")
3. Show the exact change needed:
   ```yaml
   # Before:
   - name: Copy config file
     copy:
       src: config.yml
       dest: /etc/app/config.yml

   # After:
   - name: Copy config file
     ansible.builtin.copy:
       src: config.yml
       dest: /etc/app/config.yml
   ```
4. Explain: "The `copy` module needs a fully qualified collection name (FQCN) to pass ansible-lint. Using `ansible.builtin.copy` makes it explicit that we're using the built-in copy module."

---

## General Guidelines

- Always check `.github/instructions/ansible.instructions.md` for repo-specific Ansible style rules
- When in doubt about style, reference existing roles in `ansible/roles/` as examples
- Test proposed changes against both `yamllint` and `ansible-lint` mentally before suggesting them
- Avoid proposing changes to legacy roles in `ansible/old_roles/` unless explicitly requested

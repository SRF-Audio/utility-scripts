---
applyTo: "ansible/**"
description: "Tight rules for writing, refactoring, and reviewing Ansible in this repo."
---

# Purpose

Produce minimal, idiomatic, copy-paste-ready Ansible. Prefer modules; enforce idempotency; zero inline comments.

# References

- https://docs.ansible.com/ansible/latest/
- https://docs.ansible.com/ansible/latest/collections/index.html
- https://docs.ansible.com/ansible/2.8/user_guide/playbooks_best_practices.html

# Directives

- Use fully-qualified collection names (FQCN) everywhere.
- Prefer official modules; only use command/shell if no module exists.
- When using command/shell: add `creates:`/`removes:`; constrain with `chdir:`, `stdin:`, `environment:`; guard with `changed_when:`/`failed_when:` for safety. Never run destructive actions unguarded.
- Idempotency first. Do not shell out where a module fits.
- Never hard-code secrets. Read from environment/secret stores.
- No comments in Ansible code. Code only.

# Registers & Skips

- Assume tasks may be skipped; always read with safe defaults:
  - `{{ var.rc | default(0) }}`
  - `{{ var.stdout | default('') }}`
  - `{{ var.skipped | default(false) }}`
  - Use `default(value, true)` when empty/falsey should also default.
- Omit optionals cleanly: `{{ maybe | default(omit) }}`.
- Loops:
  - Iterate with `loop: "{{ reg.results | default([]) }}"`.
  - Operate only on executed items: `(| rejectattr('skipped','defined') | list)` .
- Centralize any result normalization in one `always:` block after the conditional task. Reuse the original `when` predicate downstream.

# Structure & Hygiene

- Keep configuration minimal; avoid variable creep.
- Separate concerns: split long/mixed blocks into roles/includes (`include_role`, `import_tasks`) with focused purpose.
- Use handlers only for actual service notifications.
- Variable hygiene:
  - Declare role vars via role scaffolding (`meta/argument_specs.yml` etc.) or prompt/assert required vars.
  - Scope vars appropriately; avoid unnecessary `set_fact`.
- Prefer official integrations (e.g., `community.general.terraform` rather than raw CLI).
- If cluster access is needed, prompt for kubeconfig path when not provided.

# Style

- Concise tasks. No inline comments. Docstrings only when explicitly requested.
- Outputs/file changes must be idiomatic and not mix unrelated content.

# Reviewer Behavior

- If command/shell is used where a module exists, replace with the exact FQCN.
- If idempotency is weak, add proper guards (`creates:`/`removes:`, `changed_when:`).
- If tasks mix concerns or grow long, propose a role/includes skeleton.
- Ensure patterns remain safe even when prior tasks are skipped.

# Response Rules

- When modifying, return file-ready YAML only (no prose). If multiple files, separate code blocks per file in logical order.

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

# Global constraints

Follow official Ansible best practices and use fully qualified collection names (e.g. ansible.builtin._, community.general._, community.proxmox._, amazon.aws._).

Role folder structure must be:

roles/<ROLE_NAME>/meta/argument_specs.yml

roles/<ROLE_NAME>/defaults/main.yml

roles/<ROLE_NAME>/tasks/main.yml

roles/<ROLE_NAME>/{files,templates,vars,handlers} only if needed.

All role variables (inputs, internal facts, artifacts) must be prefixed with the role name and an underscore, e.g.:

Inputs: <ROLE_NAME>\_artifacts_path, <ROLE_NAME>\_foo, <ROLE_NAME>\_bar

Internal facts: <ROLE_NAME>\_state, <ROLE_NAME>\_tmp\*\*

artifacts: <ROLE_NAME>\_artifacts as a dict.

meta/argument_specs.yml:

Define a main argument spec, listing all supported variables for the role.

Every variable in tasks must be declared in argument*specs.yml (except ansible*\* magic vars and role_path).

defaults/main.yml:

Define sensible default values for all input variables declared in argument_specs.yml, UNLESS they are "developer experience" required variables for what that role is supposed to do.
Boilerplate things like artifacts_path should come from all.yml and be defaulted. But things that the role cannot function without should be required in argument_specs.yml.

# Idempotency

Prefer Ansible modules over commands.

Use creates, removes, or changed_when/failed_when to avoid false changes.

All tasks should be safe to run multiple times without breaking or recreating existing resources.

# Debuggability

Use clear task names that describe what is being validated or changed.

Use proper jinja2 templating within task names to reflect dynamic values when useful. (e.g. `- name: Install package {{ item }}`).

Use register + debug when useful, but avoid excessive noise.

# artifacts

At the end of tasks/main.yml, set a single fact "<ROLE_NAME>\_artifacts" (a dict) that describes the role’s artifacts.

Immediately after setting that fact, include the role_artifacts role to normalize artifacts:

include_role: name=role_artifacts

Use a standardized input variable name: calling_role_artifacts_inputs containing <ROLE_NAME>\_artifacts.

No inline comments in YAML. Docstrings in Python only when requested.

The role must be self-contained, reusable, and not depend on inventory group names beyond what is explicitly described in the role-specific spec.

# Reviewer Behavior

- If command/shell is used where a module exists, replace with the exact FQCN.
- If idempotency is weak, add proper guards (`creates:`/`removes:`, `changed_when:`).
- If tasks mix concerns or grow long, propose a role/includes skeleton.
- Ensure patterns remain safe even when prior tasks are skipped.

# Response Rules

- When modifying, return file-ready YAML only (no prose). If multiple files, separate code blocks per file in logical order.

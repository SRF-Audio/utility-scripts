---
name: feedback-prefer-native-review-skills
description: "Always invoke native code-review/simplify/security-review over the agent-skills plugin's overlapping equivalents"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 460785ef-fcea-4a13-8426-e313f4fae05f
---

When a request would match both a native skill and one of the `agent-skills` plugin's skills/commands, prefer the native one and don't invoke the plugin's overlapping version:

- Code review → native `code-review` skill, not `agent-skills:review` / `code-review-and-quality`
- Code simplification → native `simplify` skill, not `agent-skills:code-simplify` / `code-simplification`
- Security review of pending changes → native `security-review` skill, not `security-and-hardening`

**Why:** Compared the actual plugin source against the native skills (2026-06-24, see [[project-claude-dual-profile]]'s sibling discussion). The plugin's versions are well-written but pure prompt text with no tooling — no effort levels, no `--fix`/`--comment`, no `ultra` cloud multi-agent review like native `code-review` has. The plugin's `code-simplification` also duplicates its own `review` skill's readability axis, while the native `simplify`/`code-review` split is intentionally non-overlapping ("Quality only — it does not hunt for bugs"). The plugin's `security-and-hardening` is framed for web apps (XSS, payment data, webhooks) — a weaker fit than the native, generically-scoped `security-review` for Ansible/K8s/homelab infra work. User decided (rather than uninstalling the plugin or hand-editing its installed files) to keep the plugin for its ~20 non-overlapping skills (idea-refine, debugging-and-error-recovery, browser-testing-with-devtools, etc.) and just suppress the three that overlap.

**How to apply:** This only matters for *automatic* invocation when a request's intent is ambiguous between the two. If the user explicitly types `/review`, `/code-simplify`, or otherwise names a plugin skill directly, honor that — this rule governs my own judgment calls, not explicit overrides. The plugin (`agent-skills@addy-agent-skills`) is installed project-scoped to `~/GitHub/utility-scripts/ansible` only, so this mostly matters there.

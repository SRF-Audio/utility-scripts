---
name: project-claude-dual-profile
description: "Claude Code home vs work profile setup — Bedrock for GitLab/work, direct API for GitHub/home"
metadata: 
  node_type: memory
  type: project
  originSessionId: 364b57c1-dfd3-44cc-b5c8-7669da3612aa
---

Two Claude Code profiles, split by project dir:

- **Home** (`~/GitHub/`): Direct Anthropic API auth via `/login` (OAuth, stored in `~/.claude/.credentials.json`). Plain `claude` command.
- **Work** (`~/GitLab/`): AWS Bedrock via the `SHIFT - Bedrock` 1Password item. Launch with `claude-work` wrapper script.

**claude-work script:** `~/.local/bin/claude-work` (symlinked from `dotfiles/local-bin/claude-work`)
- Reads `op://Work/6cyhugp6pxj5irh2qkifnferr4/{Access Key,Secret Key}`, auto-detects distrobox (`CONTAINER_ID` env) and routes `op` through `distrobox-host-exec`
- Exports `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` **and** `CLAUDE_CODE_USE_BEDROCK=1`, `AWS_REGION`, `ANTHROPIC_DEFAULT_{SONNET,OPUS,HAIKU}_MODEL` as real shell env vars, then `exec claude "$@"`

**Critical: there is no user-level `settings.local.json`.** Claude Code's settings precedence is enterprise-managed → CLI args → project `.claude/settings.local.json` → project `.claude/settings.json` → user `~/.claude/settings.json`. A file at `~/.claude/settings.local.json` is **never read** — confirmed via `--debug-file`, whose settings-watch log line lists only `~/.claude/settings.json`, the tracked repo `claude/settings.json` it symlinks to, and per-project `.claude/settings*.json`. An earlier session put the Bedrock toggle/model vars there; it silently did nothing, and `claude-work` kept authenticating via the personal OAuth account instead (same `-p "..."` output either way, since both paths return plausible text — output alone doesn't prove which backend served it; check `--debug-file` for `dispatching to bedrock` / `AWS credential resolve` vs `OAuth token check`). **Fix (2026-06-23): moved all Bedrock env vars into the `claude-work` script itself as real exports** — that's the only mechanism guaranteed to apply regardless of cwd. Deleted the dead `~/.claude/settings.local.json` and the `dotfiles/claude/settings.local.json.work-template` it was copied from; that whole file-template approach is gone.

**AWS config:** `~/.aws/config` is symlinked from `dotfiles/aws/config` — safe to version-control (no secrets); only has `[default]` and `[profile shift-bedrock]`. `claude-work` doesn't use AWS profiles at all — it injects static keys as env vars, which take priority over any profile.
**AWS credentials:** Never stored on disk — injected by `claude-work` at launch time.

**Bedrock model IDs (must use the `us.` cross-region inference-profile prefix — bare IDs like `anthropic.claude-sonnet-4-6` are invalid on this account, confirmed via `aws bedrock list-foundation-models` showing no bare entries vs `list-inference-profiles` showing only `us.`/`global.`-prefixed ACTIVE entries):**
- Sonnet: `us.anthropic.claude-sonnet-4-6`
- Opus: `us.anthropic.claude-opus-4-8`
- Haiku: `us.anthropic.claude-haiku-4-5-20251001-v1:0`

**Verifying which backend was actually used:** `claude-work --debug-file /tmp/x.log -p "..."` then `grep -i "bedrock\|oauth" /tmp/x.log` — look for `dispatching to bedrock model=...` and `AWS credential resolve`, not `OAuth token check` immediately preceding the actual request.

**Per-project `.claude/settings.local.json` files in `~/GitLab/*` can override the above** (they ARE read, project-level). `~/GitLab/nexgen/infrastructure/.claude/settings.local.json` previously had its own broken `env`/`aws.profile` block pointing at a nonexistent AWS profile (`shift-products-bedrock` — not in `~/.aws/config` or 1Password, only `shift-bedrock` exists), causing an IMDS-lookup hang. That block was removed entirely since `claude-work`'s own exports now cover it; don't re-add per-project Bedrock env overrides unless a project genuinely needs a different AWS account.

**Lesson:** when "Bedrock isn't working" recurs, first check (a) is the symptom a hang (→ check per-project `.claude/settings.local.json` for a bad `AWS_PROFILE`/`aws.profile`) or (b) silently wrong account (→ check `--debug-file` for `OAuth token check` vs `dispatching to bedrock` — text output looks identical either way). `grep -rl AWS_PROFILE ~/GitLab/*/.claude ~/GitLab/*/*/.claude 2>/dev/null` finds stray per-project overrides fast.

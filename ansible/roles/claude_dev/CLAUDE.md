# CLAUDE.md — claude-env

## Project Purpose

This folder is an Ansible project that provisions a portable Claude Code development environment with MCP server integrations across two machines. The playbook installs runtimes, configures Claude Code, registers MCP servers, and wires 1Password CLI for runtime secrets injection. OAuth tokens (Gmail, etc.) are per-machine and created interactively after provisioning — the playbook does not automate OAuth flows.

## Target Machines

**Desktop (default)**
- OS: Fedora 43 bare metal
- DE: KDE Plasma 6.6.4, Wayland
- CPU: AMD Ryzen 7 7700X (16 threads)
- RAM: 96 GiB
- GPU: AMD Radeon RX 7800 XT
- Full sudo, full systemd, Docker available

**Laptop** (selected with `-e machine_role=laptop`)
- OS: Aurora-DX (Fedora KDE Atomic)
- Provisioning target is a **persistent named Distrobox** container (`fedora-dev`) — a full mutable Fedora userspace
- sudo available inside Distrobox, but no systemd; Docker runs on host, not inside the container
- Run playbook from inside the Distrobox: `distrobox enter fedora-dev && ansible-playbook playbook.yml --ask-become-pass -e machine_role=laptop`

## Architecture Decisions

- **Ansible, not dev containers.** Both machines are Fedora-based. Distrobox on Aurora already provides a mutable Fedora userspace. A dev container would add abstraction without solving a real portability problem.
- **1Password CLI (`op`) for all secrets.** No plaintext secrets anywhere — not in vars, not in templates, not in env files. Secrets are resolved at runtime. Use the Ansible op lookup function.
- **MCP servers that need API keys use wrapper scripts.** The playbook generates a per-server bash wrapper in `~/.claude/mcp-wrappers/<name>.sh` that verifies `op` is authenticated, reads each secret via `op read`, exports them as env vars, then `exec`s the actual MCP server process. Claude Code's config points `"command"` at the wrapper, not the raw binary. Secrets never persist on disk outside 1Password.
- **MCP servers that need browser-based OAuth (Gmail) are installed but not authenticated by the playbook.** The playbook creates credential directories, installs the npm package, and registers the server. The user runs the auth command once per machine after provisioning.
- **Role-based structure, single role for now.** `roles/claude_dev` handles everything. Split into sub-task files for readability. Add new roles only when scope genuinely diverges.

## 1Password Convention

- Vault: `Claude-Dev`
- Item naming: `claude-env-<service>` (e.g., `claude-env-trello`, `claude-env-github`, `claude-env-gmail-oauth-client`)
- Reference format in wrapper scripts: `op://Claude-Dev/claude-env-trello/api-key`
- The `community.general.onepassword_lookup` plugin is available for any tasks that need secrets at playbook runtime (not currently needed — all secrets are injected at MCP server launch time via wrappers).

## MCP Servers to Configure

| Server | Transport | Package / URL | Secrets via 1Password | Interactive Auth? |
|--------|-----------|---------------|----------------------|-------------------|
| gmail | stdio | `npx @gongrzhe/server-gmail-autoauth-mcp` | Gmail OAuth client creds in `claude-env-gmail-oauth-client` | Yes — `npx @gongrzhe/server-gmail-autoauth-mcp auth` |
| trello | stdio | `npx @modelcontextprotocol/server-trello` (or wrapper around it) | `claude-env-trello` fields: `api-key`, `api-token` | No |
| github | http | `https://api.githubcopilot.com/mcp` | `claude-env-github` field: `pat` | No |

More servers will be added over time. The structure must make adding a new server a matter of adding an entry to a variable list and optionally creating a 1Password item.

## Target Directory Layout

```
claude-env/
├── CLAUDE.md                          # this file
├── README.md                          # user-facing setup + quickstart
├── ansible.cfg                        # project-local ansible config
├── requirements.yml                   # ansible-galaxy collection deps
├── .gitignore
├── inventory/
│   └── hosts.yml                      # localhost, machine_role var
├── group_vars/
│   ├── all.yml                        # shared: node version, mcp_servers list, paths
│   ├── desktop.yml                    # desktop overrides (docker enabled, etc.)
│   └── laptop.yml                     # aurora-dx overrides (no docker, etc.)
├── roles/
│   └── claude_dev/
│       ├── defaults/main.yml          # lowest-priority defaults
│       ├── tasks/
│       │   ├── main.yml               # task router (includes sub-files with tags)
│       │   ├── runtime.yml            # node.js, python, uv, verify op CLI
│       │   ├── claude_code.yml        # install/update claude code via npm
│       │   ├── mcp_servers.yml        # dirs, wrapper scripts, claude settings template
│       │   └── shell.yml              # zsh PATH, aliases, completions
│       ├── templates/
│       │   ├── claude_settings.json.j2  # ~/.claude/settings.json with MCP defs
│       │   └── mcp_wrapper.sh.j2      # per-server op-injected launcher
│       ├── handlers/main.yml
│       └── files/                     # static files if needed
└── playbook.yml                       # entry point
```

## Ansible Conventions

- **Minimum version**: Ansible 2.17+ / ansible-core 2.17+.
- **All modules use FQCNs.** `ansible.builtin.dnf`, not `dnf`. `community.general.npm`, not `npm`.
- **Every task must be idempotent.** Use state assertions. If shelling out, use `creates:`, `changed_when:`, or `failed_when:` guards.
- **`ansible-lint` must pass clean** against the default profile.
- **YAML style**: 2-space indent, no tabs, `---` document start marker, `yamllint` clean.
- **Every task has a descriptive `name:`** — no unnamed tasks.
- **Tags**: every task file applies a tag matching its filename (`runtime`, `claude_code`, `mcp_servers`, `shell`). The `main.yml` router uses `include_tasks` with `apply: tags:` so tags propagate correctly.
- **No `ignore_errors: true`** unless there is a documented comment above the task.
- **Variables**: defaults in `roles/claude_dev/defaults/main.yml`. Machine overrides in `group_vars/desktop.yml` or `group_vars/laptop.yml`. Secrets never in any vars file.
- **Galaxy deps**: `community.general` (for `npm` module, `onepassword_lookup`). Pinned to `>=9.0.0`. Listed in `requirements.yml`.

## Template Details

### `claude_settings.json.j2`
Generates `~/.claude/settings.json`. Iterates over the `mcp_servers` list variable. For stdio servers with `op_secrets` defined, the command points at the wrapper script. For stdio servers without secrets, the command is the raw binary/npx. For http servers, emit the URL and headers. Secrets references in headers (like the GitHub PAT) should be resolved at template time via `op read` in a task, or the server should use a wrapper — decide based on whether writing the secret to the JSON file is acceptable.

### `mcp_wrapper.sh.j2`
Generates one script per MCP server that has `op_secrets` defined. The script:
1. `set -euo pipefail`
2. Verifies `op account get` succeeds (fail fast if not signed in)
3. Loops over `op_secrets` dict: `export VAR="$(op read 'op://...')"`
4. `exec`s the actual MCP server command with its args

## Shell Integration

- Target shell: zsh
- Add `~/.local/bin` and `~/.npm-global/bin` to PATH
- Set npm global prefix to `~/.npm-global` (avoids sudo for global installs)
- Source `op` completions if available
- Source `claude` completions if available
- Aliases: `cc` → `claude`, `ccmcp` → `claude mcp list`
- Use `blockinfile` with a marker comment so the block is idempotent

## Security Constraints

- No plaintext secrets in any file, variable, template, or log output.
- Wrapper scripts are `mode 0700`. Config directories are `mode 0700`.
- `.gitignore` must exclude: `*.retry`, `.vault_pass`, `*.secret`, `token.json`, `credentials.json`, `gcp-oauth.keys.json`, `collections/`, `node_modules/`.
- The GitHub MCP server PAT in headers is a known concern — if writing it to `settings.json` on disk is unacceptable, use a wrapper script instead of http transport. Default to the wrapper approach to be safe.

## How to Validate

After the playbook runs:
```bash
claude --version                    # Claude Code installed
claude mcp list                     # all servers registered
op --version                        # 1Password CLI present
node --version                      # Node.js present
cat ~/.claude/settings.json         # MCP config present, no plaintext secrets
ls -la ~/.claude/mcp-wrappers/      # wrapper scripts exist, mode 0700
```

## What This Playbook Does NOT Do

- Run OAuth flows (Gmail auth is interactive, post-provision).
- Manage dotfiles beyond Claude-specific config.
- Install Claude Desktop (no official Linux build).
- Install or configure Docker (assumed pre-existing on desktop, host-side on Aurora).

# Synology NAS → Hetzner Backup: Project Status

**Last updated:** 2026-04-20 (session 3 — Trello alerting implemented)

**Agent context:** This document is the authoritative state of this project. Read it before doing anything else. It captures findings, decisions, and outstanding work so any new agent or conversation can pick up without re-auditing the codebase.

---

## Mission

Create a bit-for-bit backup of a Synology DS1813+ NAS (9.7TB used, /volume2) to Hetzner Storage Box before a family move from the US to the Netherlands. The NAS will be powered off and shipped. The backup exists purely as a disaster recovery copy — no new data will be written to it during transit, and it only needs to be accessed if the NAS is lost, stolen, or destroyed in transit.

**Key dates:**

- 2026-04-20: Project started
- 2026-06-~20: NAS must be packed (estimate — late June)
- 2026-07-22: Fly to Netherlands
- Backup must be running reliably well before late June so there is time to verify it

**Scale:** ~9.7TB source data, mostly pre-compressed media (JPEG, MP4, RAW). Restic will achieve minimal compression (<5%). First snapshot will be ~9.3–9.5TB on disk.

---

## Architecture

**Tool:** Restic v0.17.3 (binary downloaded + SHA256 verified at install time)
**Orchestration:** Ansible (role: `synology_restic_backup`)
**Secrets:** 1Password CLI (`op`) — all secrets fetched at playbook runtime on control host, never hardcoded
**Destination:** Hetzner Storage Box (SFTP, port 23)
**Encryption:** Restic AES-256 at rest; SSH transport in transit

**Schedule (once running):**

- Daily backup: 02:00
- Weekly forget/prune: Sunday 03:00
- Weekly integrity check: Wednesday 04:00

**Key paths on NAS:**

- Config/credentials: `/etc/restic-backup/` (mode 0700)
- Logs: `/var/log/restic-backup/`
- Scripts: `/usr/local/bin/restic-backup/`
- Restore procedure: `/etc/restic-backup/RESTORE_PROCEDURE.txt`

**1Password vault:** HomeLab

**1Password items (fully configured):**

- `op://HomeLab/Synology Restic Repository/password` — restic repo encryption password
- `op://HomeLab/Hetzner Storage Box SSH Key/private key` — ed25519 SSH key (NAS→StorageBox auth); OpenSSH format at `?ssh-format=openssh`
- `op://HomeLab/Hetzner Storage Box SSH Key/public key` — uploaded to Storage Box `~/.ssh/authorized_keys` 2026-04-20; key auth verified working
- `op://HomeLab/Hetzner/add more/storagebox_host` — u579903.your-storagebox.de
- `op://HomeLab/Hetzner/add more/storagebox_username` — u579903

---

## Findings from Initial Audit (2026-04-20)

### Blockers — must resolve before first run

| # | Finding | Status |
|---|---------|--------|
| B1 | Hetzner Storage Box not yet created | ✅ Done 2026-04-20 — BX41 created in fsn1, ID 562357, host u579903.your-storagebox.de, user u579903 |
| B2 | Placeholder credentials hardcoded in playbook vars | ✅ Done 2026-04-20 — hostname + username stored in 1Password; playbook looks them up via community.general.onepassword |
| B3 | No `op` CLI preflight assertion — fails mid-run with cryptic error if 1Password unavailable | ✅ Done 2026-04-20 — two-step preflight in tasks/main.yml: `op --version` + `op account list`, both delegated to localhost; fail with actionable message if either fails |
| B4 | `StrictHostKeyChecking accept-new` on NAS→StorageBox SSH — first connection is unauthenticated TOFU | ✅ Closed as not-applicable — the Storage Box host key is Hetzner-generated, not in 1Password, and `ssh-keyscan` to pre-populate it is itself TOFU. `accept-new` records the key on first connection and enforces it thereafter; the attack window is the initial run only, which is acceptable for this use case. |

### Critical — must resolve before NAS is packed (late June 2026)

| # | Finding | Status |
|---|---------|--------|
| C1 | No failure alerting on cron jobs — backup could fail for weeks silently | ✅ Done 2026-04-20 — all three wrapper scripts rewritten: exit codes captured cleanly, failures call `_alert()`; Trello card creation implemented via `trello_alert.sh`; enable with `synology_restic_backup_trello_alerts_enabled: true` |
| C2 | Restore has never been tested — backup is unverified until at least one restore test is run | ❌ Open — requires first successful backup run |
| C3 | Retention policy is irrelevant for transit use case | ✅ Resolved (decision: keep defaults, no change needed) |

### Important — lower urgency but worth addressing

| # | Finding | Status |
|---|---------|--------|
| I1 | Lock contention is silent — overlapping runs exit 0 without alerting | ✅ Done 2026-04-20 — lock contention now calls `_alert()` and exits 1 in all three scripts |
| I2 | Storage Box free space not monitored | ✅ Done 2026-04-20 — check.sh runs `restic stats --json` after integrity check; alerts when usage exceeds `synology_restic_backup_storage_warn_gib` (default: 16000 GiB ≈ 86% of BX61) |
| I3 | No control-host prerequisites doc/runbook | ✅ Done 2026-04-20 — see `docs/control-host-setup.md` |
| I4 | Restic version not checked against upstream | ✅ Done 2026-04-20 — `tasks/check_restic_version.yml` queries GitHub releases API at play time; emits a `debug` warning if behind; never blocks execution |

---

## Decisions Made

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-20 | Use BX61 (20TB) Storage Box, not BX10 (10TB) | Source is 9.7TB of pre-compressed media; restic compression will be <5%, leaving ~300MB headroom on 10TB — unacceptably tight for a once-in-a-move backup. 20TB gives safe margin. Cost difference is trivial vs. risk. |
| 2026-04-20 | Move Storage Box hostname/username to 1Password instead of hardcoding in playbook | Keeps all secrets in one place; consistent with how repo password and SSH key are already managed |
| 2026-04-20 | Retention policy is correct as-is for transit | NAS will be off during move — no new snapshots will accumulate. The daily/weekly/monthly retention only matters post-arrival. |
| 2026-04-20 | Alert command is a configurable shell string, not a baked-in mechanism | NAS has no pre-configured email relay; a variable keeps the role generic |
| 2026-04-20 | Use Trello for alerting | User checks Trello daily with notifications on; credentials stored in `op://HomeLab/Atlassian/{api_key,token,alert_list_id}`; enabled via `synology_restic_backup_trello_alerts_enabled: true` |
| 2026-04-20 | Restic version check is advisory (warn, not fail) | Upstream releases must be reviewed for breaking changes before upgrading; blocking playbook runs on a patch release would be counterproductive |
| 2026-04-20 | B4 (host key pinning) closed as not-applicable | Storage Box host key is Hetzner-generated, not in 1Password. Pre-populating via ssh-keyscan is itself TOFU and adds no security. `accept-new` is correct — it pins on first use and enforces thereafter. |

---

## What Needs to Happen Next (Ordered)

1. **Enable Trello alerting** — add `synology_restic_backup_trello_alerts_enabled: true` to playbook vars or `group_vars/synology_nas.yml`
2. **Run playbook end-to-end** — `ansible-playbook -i inventories/hosts.yml playbooks/synology-backup.yml`
3. **Verify first snapshot** — `restic snapshots` and `restic check` on the NAS; confirm repo is healthy
4. **Run restore test (C2)** — restore at least one directory to a temp location, verify contents
5. **Pre-pack checklist** — before powering down NAS: confirm last snapshot date, confirm repo health, document restic repo URL and password location for recovery

---

## Conventions

- **Always use `op` CLI for secrets.** Never use `read -rs`, inline flags with passwords, or shell variable workarounds. Use `op run --env-file` or inline `VAR=op://vault/item/field op run --` patterns exclusively.

---

## hcloud Context

- Active context: `Paperless-NGX`
- Existing servers: `hetzner-node` (nbg1, running)
- Storage Boxes: BX61, ID 562357, `u579903.your-storagebox.de`

---

## Repository Layout

```text
synology-backup/
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventories/
│   │   ├── hosts.yml                          # NAS host + connection vars
│   │   └── group_vars/
│   │       ├── all.yml                        # Tailscale preference
│   │       └── synology_nas.yml               # DSM 7 SSH settings
│   └── playbooks/
│       └── synology-backup.yml               # Main playbook
│   └── roles/
│       └── synology_restic_backup/
│           ├── defaults/main.yml             # All role defaults incl. restic version, retention, cron, alerting
│           ├── meta/argument_specs.yml       # Full variable documentation
│           └── tasks/
│               ├── main.yml                  # Entry point: op preflight, version check, secrets, orchestration
│               ├── check_restic_version.yml  # Advisory restic version currency check (I4)
│               ├── install_restic.yml        # Binary download + SHA256 verify
│               ├── configure_ssh.yml         # SSH config + pinned known_hosts for Storage Box (B4)
│               ├── init_repo.yml             # Idempotent repo init
│               ├── configure_trello_alerts.yml  # Trello creds + alert script deploy
│               ├── schedule_jobs.yml         # Cron job deployment
│               └── restore_doc.yml           # Restore procedure doc
│           └── templates/
│               ├── backup.sh.j2              # Alert on failure + lock contention (C1/I1)
│               ├── forget.sh.j2              # Alert on failure + lock contention (C1/I1)
│               ├── check.sh.j2               # Alert on failure + storage space audit (C1/I1/I2)
│               ├── trello_alert.sh.j2        # Creates a Trello card; called by _alert()
│               └── restore_procedure.txt.j2
└── docs/
    ├── status.md                             # This file
    └── control-host-setup.md                 # Control-host prerequisites runbook (I3)
```

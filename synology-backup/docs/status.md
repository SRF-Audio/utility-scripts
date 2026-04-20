# Synology NAS → Hetzner Backup: Project Status

**Last updated:** 2026-04-20 (session 1 — ongoing)
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
| B2 | Placeholder credentials (`uXXXXXX`) hardcoded in playbook vars — need to be moved to 1Password and looked up dynamically | ✅ Done 2026-04-20 — hostname + username stored in 1Password (op://HomeLab/Hetzner/add more/storagebox_host and storagebox_username); playbook now looks them up via community.general.onepassword; no hardcoded values remain |
| B3 | No `op` CLI preflight assertion in playbook — fails mid-run with cryptic error if 1Password unavailable | ❌ Open |
| B4 | `StrictHostKeyChecking accept-new` on NAS→StorageBox SSH — first connection is unauthenticated TOFU; should pin Hetzner host key in playbook | ❌ Open |

### Critical — must resolve before NAS is packed (late June 2026)

| # | Finding | Status |
|---|---------|--------|
| C1 | No failure alerting on cron jobs — backup could fail for weeks silently | ❌ Open |
| C2 | Restore has never been tested — backup is unverified until at least one restore test is run | ❌ Open |
| C3 | Retention policy (7d/4w/3m) is irrelevant for transit use case; only ONE snapshot matters — the last one before packing. Retention settings are fine as-is but this understanding should inform the final pre-pack checklist | ✅ Resolved (decision: keep defaults, no change needed) |

### Important — lower urgency but worth addressing

| # | Finding | Status |
|---|---------|--------|
| I1 | Lock contention is silent — if backup run overlaps next schedule, second run exits without alerting | ❌ Open |
| I2 | Storage Box free space not monitored | ❌ Open |
| I3 | No control-host prerequisites doc/runbook | ❌ Open |
| I4 | Restic version not checked against upstream for security/bug fixes | ❌ Open |

---

## Decisions Made

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-20 | Use BX61 (20TB) Storage Box, not BX10 (10TB) | Source is 9.7TB of pre-compressed media; restic compression will be <5%, leaving ~300MB headroom on 10TB — unacceptably tight for a once-in-a-move backup. 20TB gives safe margin. Cost difference is trivial vs. risk. |
| 2026-04-20 | Move Storage Box hostname/username to 1Password instead of hardcoding in playbook | Keeps all secrets in one place; consistent with how repo password and SSH key are already managed |
| 2026-04-20 | Retention policy is correct as-is for transit | NAS will be off during move — no new snapshots will accumulate. The daily/weekly/monthly retention only matters post-arrival. |

---

## What Needs to Happen Next (Ordered)

1. **Create BX61 Storage Box on Hetzner** via `hcloud` CLI
2. **Create/update 1Password item** with Storage Box hostname and username
3. **Update playbook** to look up hostname + username from 1Password (remove placeholders)
4. **Add `op` CLI preflight check** to playbook (B3)
5. **Pin Hetzner Storage Box host key** in playbook instead of TOFU (B4)
6. **Add failure alerting** on cron jobs (C1) — email or webhook, decide mechanism
7. **Run playbook end-to-end** for the first time
8. **Verify first snapshot** completes and repo is healthy (`restic snapshots`, `restic check`)
9. **Run restore test** — restore at least one directory to a temp location, verify contents (C2)
10. **Pre-pack checklist** — before powering down NAS: confirm last snapshot date, confirm repo health, document restic repo URL and password location for recovery

---

## Conventions

- **Always use `op` CLI for secrets.** Never use `read -rs`, inline flags with passwords, or shell variable workarounds. Use `op run --env-file` or inline `VAR=op://vault/item/field op run --` patterns exclusively.

---

## hcloud Context

- Active context: `Paperless-NGX`
- Existing servers: `hetzner-node` (nbg1, running)
- Storage Boxes: **none** — needs to be created

---

## Repository Layout

```
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
│       └── synology-backup.yml               # Main playbook (has placeholder vars — to be fixed)
│   └── roles/
│       └── synology_restic_backup/
│           ├── defaults/main.yml             # All role defaults incl. restic version, retention, cron
│           ├── meta/argument_specs.yml       # Full variable documentation
│           └── tasks/
│               ├── main.yml                  # Entry point: assertions, secrets, orchestration
│               ├── install_restic.yml        # Binary download + SHA256 verify
│               ├── configure_ssh.yml         # SSH config for Storage Box
│               ├── init_repo.yml             # Idempotent repo init
│               ├── schedule_jobs.yml         # Cron job deployment
│               └── restore_doc.yml           # Restore procedure doc
│           └── templates/
│               ├── backup.sh.j2
│               ├── forget.sh.j2
│               ├── check.sh.j2
│               └── restore_procedure.txt.j2
└── docs/
    └── status.md                             # This file
```

---
name: Synology backup — current status
description: Backup status, known issues, and operational facts for the restic → Hetzner storage box setup
type: project
originSessionId: b8309e0a-260c-440c-a6bf-87c75f44118f
---
Per-share sequential backup deployed 2026-05-01, replacing monolithic single-invocation approach.

**Why:** Every monolithic backup (Apr 20–Apr 30) failed with SSH `Broken pipe` after 4–57 hours — never enough to complete 9.7 TiB. Root cause investigated: Spectrum cable modem (bridge mode) likely drops long-lived TCP connections despite SSH keepalives (60s interval) and Omada gateway NAT timeout (7440s). Inconsistent failure times rule out a fixed timeout; points to stateful connection tracking in the modem.

**Current state (2026-05-01):**
- Per-share backup started 08:20 CDT; each of 9 shares is backed up independently with up to 4 retries each
- 1 existing snapshot: `ce039d56` (654 MiB test from Apr 20)
- 1.5 TB of chunk data on Storage Box from prior failed runs — preserved by restic dedup, will not be re-uploaded
- No successful full snapshot yet for the real data

**How to apply:**
- Monitor with `sudo tail -f /var/log/restic-backup/backup.log` and `restic snapshots`
- Once all 9 shares have snapshots, do a restore test (C2 still open)
- Restic 0.17.3 installed, upstream is 0.18.1 — advisory warning only
- NAS must be packed ~2026-06-20; fly 2026-07-22

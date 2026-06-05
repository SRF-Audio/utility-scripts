---
name: Synology backup — current status
description: Backup status, known issues, and operational facts for the restic → Hetzner storage box setup
type: project
originSessionId: b8309e0a-260c-440c-a6bf-87c75f44118f
---
Per-share sequential backup deployed 2026-05-01, replacing monolithic single-invocation approach.

**Why:** Every monolithic backup (Apr 20–Apr 30) failed with SSH `Broken pipe` after 4–57 hours — never enough to complete 9.7 TiB. Root cause investigated: Spectrum cable modem (bridge mode) likely drops long-lived TCP connections despite SSH keepalives (60s interval) and Omada gateway NAT timeout (7440s). Inconsistent failure times rule out a fixed timeout; points to stateful connection tracking in the modem.

**Current state (2026-06-04):**
- All 9 shares backing up daily; 45 snapshots in repo as of 2026-06-04
- Daily run pattern: docker/home-assistant-backup/homes complete by ~02:18; k3s-cluster-storage takes 3–21 hrs (active data, Spectrum pipe breaks trigger retry loop); remaining 5 shares complete within minutes after k3s
- All runs end with "END — all shares completed successfully" — no ALERTs
- Only open item: C2 restore test (verify contents of at least one share restored to temp location)
- NAS must be packed ~2026-06-20; fly 2026-07-22

**How to apply:**
- Direct SSH: `ssh -i ~/.ssh/coachlight-homelab.pem stephenfroeber@192.168.226.6`
- Manual restic (always include RESTIC_CACHE_DIR — otherwise fills tiny 2.3G root partition): `sudo bash -c "export RESTIC_REPOSITORY=sftp:storagebox:restic; export RESTIC_PASSWORD_FILE=/etc/restic-backup/.restic-password; export RESTIC_CACHE_DIR=/volume2/restic-cache; /usr/local/bin/restic snapshots"`
- Root partition was 100% full 2026-06-04 due to stale `/root/.cache/restic/` (418M); cleared. Now at 85%. Deployed scripts use `/volume2/restic-cache` correctly.
- Log: `sudo tail -f /var/log/restic-backup/backup.log`
- Restic 0.17.3 installed; advisory warning for newer upstream only

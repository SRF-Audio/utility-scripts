# Memory Index

- [Always use op CLI for secrets](feedback_op_cli.md) — Never suggest read -rs, inline flags, or shell vars for credentials; always use `op run` or `op item get`
- [Never view secret values](feedback_never_view_secret_values.md) — Don't print/reveal secrets even to verify them; use length check or checksum instead
- [Flag paid tools before recommending](feedback_flag_paid_tools.md) — State the pricing model (free/paid/usage-based) in the same sentence as any tool, API, or service recommendation
- [Markdownlint on memory files](feedback_markdownlint_memory_files.md) — Ignore markdownlint warnings in memory/; the frontmatter format is required and can't change
- [Ansible SSH to Synology DSM](feedback_ansible_dsm_ssh.md) — PAM/kbd-interactive auth workarounds, paramiko doesn't work, DSM crontab/ssh-keyscan quirks, direct-SSH key path
- [Coachlight K3s cluster status](project_coachlight_cluster_status.md) — Live issues as of 2026-04-21 (wkr-3 down, MinIO secret, paperless sync loop); Bitnami→bitnamilegacy pattern; cluster winding down
- [Synology backup — current status](project_synology_backup_status.md) — Daily per-share restic backups green; C2 restore test still open; NAS packs ~2026-06-20
- [Hetzner cluster patterns](reference_hetzner_patterns.md) — ArgoCD wave/project conventions, homepage ingress annotation triple, 1P operator empty-field gotcha, NetBox/Loki chart specifics
- [Strava API in 1Password](reference_strava_op.md) — Where Strava creds live; the fitness-coach skill's strava.py consumes them; kite-uploader shares the refresh token (rotation warning)
- [MCP server setup](reference_mcp_setup.md) — github/trello via 1P wrappers + fetch; troubleshooting starts with `op signin`
- [Fitness — current state](project_fitness_state.md) — Run rebuild status, bike-shipping/move timeline, sport balance; coaching persona lives in the fitness-coach skill
- [Training plan Jun–Sept 2026](project_training_plan_2026.md) — Phase plan through the O'Fallon→The Hague move; ERAU 100-mile challenge, projected finish ~Aug 5–12
- [Claude dual-profile setup](project_claude_dual_profile.md) — Home=direct API, Work=Bedrock via `claude-work` exports (user-level settings.local.json is never read!)
- [Prefer native review skills](feedback_prefer_native_review_skills.md) — agent-skills plugin overlaps code-review/simplify/security-review; suppress its versions, no fine-grained plugin skill disable exists
- [Workstation migration in-flight](project_workstation_migration.md) — laptop moving Aurora distrobox→native Fedora; roles built on branch `workstation-migration`, cutover/teardown deferred until reinstall confirmed

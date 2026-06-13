---
name: reference-strava-op
description: "Where Strava API credentials live in 1Password, and the refresh-token sharing constraint with the kite uploader"
metadata:
  type: reference
---

Strava API credentials in 1Password:

- **Account:** `my.1password.com` · **Vault:** `HomeLab` · **Item:** `Strava`
- **Section:** `Strava API` — `client_id` (text), `client_secret` (password), `refresh_token` (password)
- e.g. `op read "op://HomeLab/Strava/Strava API/refresh_token" --account my.1password.com`
- Lives in HomeLab (not a personal vault) so the HomeLab-scoped service account token can read it without the desktop app.

The `fitness-coach` skill consumes these (bundled `strava.py` — `auth`/`list`/`detail`/`stats`) and its STRAVA.md documents the OAuth flow, scopes, and troubleshooting — `activity:read_all` is required to read; `activity:write` alone does not grant read.

**Shared-token constraint:** SRF-Audio/kite-sessions-to-strava reads the same three values as env vars `STRAVA_CLIENT_ID/SECRET/REFRESH_TOKEN`. Re-running `strava.py auth` rotates the refresh token — update the uploader's copy afterward.

Note: the token-rotation logic in `strava.py` also writes a rotated refresh token back to 1Password automatically during normal use, so the uploader can drift even without a manual re-auth.

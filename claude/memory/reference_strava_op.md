---
name: reference-strava-op
description: "Where Strava API credentials live in 1Password, and the scope gotcha for reading activities"
metadata: 
  node_type: memory
  type: reference
  originSessionId: dbb4452b-740d-48de-bca4-c8590d8583e4
---

Strava API credentials are stored in 1Password:

- **Account:** `my.1password.com` · **Vault:** `Stephen and Christine` · **Item:** `Strava` (a LOGIN item; its username/password are the website login, kept separate from the API fields)
- **Section:** `Strava API` with fields: `client_id` (text), `client_secret` (password), `refresh_token` (password)
- Read via e.g. `op read "op://Stephen and Christine/Strava/Strava API/refresh_token" --account my.1password.com`

Auth model: OAuth2 refresh-token flow → POST `https://www.strava.com/oauth/token` (`grant_type=refresh_token`) yields a 6h access token.

**Scope gotcha:** reading activities (`GET /athlete/activities`) needs `activity:read_all`; uploading (the kite-sessions-to-strava project) needs `activity:write`. These are separate — write does NOT grant read. The Strava API app's Authorization Callback Domain must be `localhost` for the local OAuth redirect.

Two Claude skills use this: `strava-auth` (mints the refresh token) and `strava-sessions` (views activities), in `~/GitHub/utility-scripts/claude/skills/`. Related upload project: SRF-Audio/kite-sessions-to-strava (reads the same 3 values as env vars `STRAVA_CLIENT_ID/SECRET/REFRESH_TOKEN`).

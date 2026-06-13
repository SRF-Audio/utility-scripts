# Strava data access (strava.py)

Reads Stephen's Strava activities and handles the one-time OAuth setup.
Credentials come from the **Strava** item in 1Password (vault **HomeLab**,
section **Strava API**), read/written only via `op` — nothing is echoed. The
script refreshes the short-lived (6h) access token automatically and caches it
in `~/.cache/strava/token.json` (mode 600).

## Usage

```
python3 ~/.claude/skills/fitness-coach/strava.py <command> [options]
```

### list — recent activities
```
strava.py list            # 30 most recent
strava.py list -n 50      # 50 most recent
strava.py list -s Kitesurf
```
Columns: date, type, distance (km + mi), moving time, name, activity id.

### detail — one activity
```
strava.py detail 12345678901
```
Full stats: distance, times, elevation, speed, HR/power, gear, and laps.
(Get the id from the `list` output.)

### stats — totals per sport over a window
```
strava.py stats            # last 28 days
strava.py stats -d 365     # last year
strava.py stats -s Run
```
Aggregates count, distance, moving time, and elevation per sport type.

All data commands accept `--json` to emit raw Strava JSON instead of a table.

### auth — one-time OAuth setup
```
strava.py auth
```
Prints (and opens) a Strava authorize URL, catches the redirect on
`http://localhost:8721/exchange`, exchanges the code, and writes
`refresh_token` into 1Password. Run once; re-run only to change scopes or
recover from a revoked/unauthorized token.

Options:
- `--scope activity:read_all` — read-only token (default also requests
  `activity:write` so the token is a drop-in superset of the kite-uploader token).
- `--port N` — change the redirect port (default 8721).
- `--no-browser` — just print the URL instead of opening a browser.

#### Auth prerequisites (once, by hand)

1. **Strava API app** — at <https://www.strava.com/settings/api> note your
   *Client ID* and *Client Secret*, and set **Authorization Callback Domain** to
   `localhost` (required for the local redirect).

2. **1Password fields** — in the **Strava** item (vault **HomeLab**), add a
   section named **`Strava API`** with:
   - `client_id` — text
   - `client_secret` — password
   - (`refresh_token` is written by `auth`; you don't add it.)

   Add these via the 1Password app so the secret never lands in shell history.
   The `client_id` (not secret) may instead be set with:
   ```
   op item edit Strava "Strava API.client_id[text]=YOUR_ID" --account my.1password.com
   ```

## Notes & troubleshooting

- **Sport names** match Strava's `sport_type` (e.g. `Kitesurf`, `Run`, `Ride`,
  `Walk`, `Workout`, `WeightTraining`). The filter also matches the legacy
  `type` field and is case-insensitive.
- **Scopes:** reading activities requires `activity:read_all`; write/upload is
  a separate scope — `activity:write` alone is not enough to read. **401
  errors** mean the token lacks read scope — re-run `auth` and approve
  `activity:read_all`.
- **Callback domain mismatch** → Strava error "redirect_uri ... not registered":
  set the app's Authorization Callback Domain to `localhost`.
- **Re-authorizing** issues a new refresh token and may invalidate the previous
  one. Because the default scope includes `activity:write`, the new token also
  covers uploads — if you use the kite-sessions uploader, update its
  `STRAVA_REFRESH_TOKEN` to this new value too.
- **Distrobox:** when running inside a distrobox (`CONTAINER_ID` set), `op` is
  invoked via `distrobox-host-exec` automatically so it can reach the host
  1Password session. Override the command with `STRAVA_OP_CMD` if needed.
- **Overrides** (env vars): `STRAVA_OP_VAULT`, `STRAVA_OP_ITEM`,
  `STRAVA_OP_SECTION`, `STRAVA_OP_ACCOUNT`, `STRAVA_OP_CMD`.
- Standard library only — no `pip install` needed.

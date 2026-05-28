---
name: strava-sessions
description: View the user's Strava fitness sessions (kitesurf, run, ride, workouts, etc.). Lists recent activities, shows full detail for one activity, and summarizes totals per sport over a time window. Reads Strava API credentials from 1Password via `op` and refreshes the access token automatically. Use whenever the user wants to look at, review, summarize, or analyze their Strava activities / training / fitness sessions.
---

# strava-sessions

Reads your Strava activities. Credentials come from the **Strava** item in
1Password (vault *Stephen and Christine*, section *Strava API*); the script
refreshes the short-lived access token automatically and caches it in
`~/.cache/strava-sessions/token.json` (mode 600).

**Setup required first:** run the `strava-auth` skill once to populate
`client_id`, `client_secret`, and an `activity:read_all` `refresh_token` in
1Password. If credentials are missing or unauthorized, this skill says so and
points back to `strava-auth`.

## Usage

```
python3 ~/.claude/skills/strava-sessions/sessions.py <command> [options]
```

### list — recent activities
```
python3 ~/.claude/skills/strava-sessions/sessions.py list            # 30 most recent
python3 ~/.claude/skills/strava-sessions/sessions.py list -n 50      # 50 most recent
python3 ~/.claude/skills/strava-sessions/sessions.py list -s Kitesurf
```
Columns: date, type, distance (km + mi), moving time, name, activity id.

### detail — one activity
```
python3 ~/.claude/skills/strava-sessions/sessions.py detail 12345678901
```
Full stats: distance, times, elevation, speed, HR/power, gear, and laps.
(Get the id from the `list` output.)

### stats — totals per sport over a window
```
python3 ~/.claude/skills/strava-sessions/sessions.py stats            # last 28 days
python3 ~/.claude/skills/strava-sessions/sessions.py stats -d 365     # last year
python3 ~/.claude/skills/strava-sessions/sessions.py stats -s Run
```
Aggregates count, distance, moving time, and elevation per sport type.

All commands accept `--json` to emit raw Strava JSON instead of a table.

## Notes

- **Sport names** match Strava's `sport_type` (e.g. `Kitesurf`, `Run`, `Ride`,
  `Walk`, `Workout`, `WeightTraining`). The filter also matches the legacy
  `type` field and is case-insensitive.
- **401 errors** mean the token lacks read scope — re-run `strava-auth` and
  approve `activity:read_all`.
- **Overrides** (env vars): `STRAVA_OP_VAULT`, `STRAVA_OP_ITEM`,
  `STRAVA_OP_SECTION`, `STRAVA_OP_ACCOUNT`.
- Standard library only — no `pip install` needed.

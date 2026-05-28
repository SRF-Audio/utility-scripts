---
name: strava-auth
description: One-time setup for Strava API access. Performs the OAuth authorization-code flow to mint a refresh token (with activity:read_all scope) and stores client_id/client_secret/refresh_token in the user's 1Password "Strava" item. Use when first configuring Strava access, when the strava-sessions skill reports missing or unauthorized credentials, or when re-authorizing with different scopes.
---

# strava-auth

Mints a Strava **refresh token** via OAuth and stores it in 1Password so the
`strava-sessions` skill can read your activities. This is a **one-time** setup
(re-run only to change scopes or recover from a revoked token).

## How Strava auth works

Strava uses OAuth2. Three values are needed:

- `client_id`, `client_secret` — from your API application at <https://www.strava.com/settings/api>
- `refresh_token` — long-lived; minted **once** by authorizing in a browser. The
  session skill exchanges it for short-lived (6h) access tokens automatically.

Reading activities requires the **`activity:read_all`** scope. (Write/upload is a
separate scope — having `activity:write` alone is not enough to read.)

## Prerequisites (do these once, by hand)

1. **Strava API app** — at <https://www.strava.com/settings/api> note your
   *Client ID* and *Client Secret*, and set **Authorization Callback Domain** to
   `localhost` (required for the local redirect this skill uses).

2. **1Password fields** — in the **Strava** item (vault *Stephen and Christine*),
   add a section named **`Strava API`** with:
   - `client_id` — text
   - `client_secret` — password
   - (`refresh_token` is written by this skill; you don't add it.)

   Add these via the 1Password app so the secret never lands in shell history.
   The `client_id` (not secret) may instead be set with:
   ```
   op item edit Strava "Strava API.client_id[text]=YOUR_ID" --account my.1password.com
   ```

## Run it

```
python3 ~/.claude/skills/strava-auth/auth.py
```

This prints (and opens) an authorize URL, catches the redirect on
`http://localhost:8721/exchange`, exchanges the code, and writes `refresh_token`
into 1Password.

Options:
- `--scope activity:read_all` — read-only token (default also requests
  `activity:write` so the token is a drop-in superset of the kite-uploader token).
- `--port N` — change the redirect port (default 8721).
- `--no-browser` — just print the URL instead of opening a browser.

## Notes & troubleshooting

- **Callback domain mismatch** → Strava error "redirect_uri ... not registered":
  set the app's Authorization Callback Domain to `localhost`.
- **Re-authorizing** issues a new refresh token and may invalidate the previous
  one. Because the default scope includes `activity:write`, the new token also
  covers uploads — if you use the kite-sessions uploader, update its
  `STRAVA_REFRESH_TOKEN` to this new value too.
- **Overrides** (env vars): `STRAVA_OP_VAULT`, `STRAVA_OP_ITEM`,
  `STRAVA_OP_SECTION`, `STRAVA_OP_ACCOUNT`.
- Secrets are only read from / written to 1Password via `op`; nothing is echoed.

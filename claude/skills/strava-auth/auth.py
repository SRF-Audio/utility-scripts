#!/usr/bin/env python3
"""One-time Strava OAuth: mint a refresh token and store it in 1Password.

Reads client_id/client_secret from the 1Password Strava item, runs the OAuth
authorization-code flow (catching the redirect on a local port), exchanges the
code for tokens, and writes the resulting refresh_token back into 1Password.

Secrets are only ever read from / written to 1Password via the `op` CLI; they
are never echoed or passed in on the command line.
"""
import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer

OP_VAULT = os.environ.get("STRAVA_OP_VAULT", "Stephen and Christine")
OP_ITEM = os.environ.get("STRAVA_OP_ITEM", "Strava")
OP_SECTION = os.environ.get("STRAVA_OP_SECTION", "Strava API")
OP_ACCOUNT = os.environ.get("STRAVA_OP_ACCOUNT", "my.1password.com")

AUTHORIZE_URL = "https://www.strava.com/oauth/authorize"
TOKEN_URL = "https://www.strava.com/oauth/token"


def op_read(field):
    ref = f"op://{OP_VAULT}/{OP_ITEM}/{OP_SECTION}/{field}"
    r = subprocess.run(
        ["op", "read", ref, "--account", OP_ACCOUNT],
        capture_output=True, text=True,
    )
    return r.stdout.strip() if r.returncode == 0 else None


def op_write(field, value, concealed=True):
    field_type = "password" if concealed else "text"
    assign = f"{OP_SECTION}.{field}[{field_type}]={value}"
    r = subprocess.run(
        ["op", "item", "edit", OP_ITEM, assign, "--account", OP_ACCOUNT],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        sys.exit(f"op item edit failed: {r.stderr.strip()}")


def post_form(url, data):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        sys.exit(f"Token exchange failed ({e.code}): {e.read().decode(errors='replace')}")


class _Catcher(BaseHTTPRequestHandler):
    code = None
    scope = ""
    error = None

    def do_GET(self):
        params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        if "code" in params:
            _Catcher.code = params["code"][0]
            _Catcher.scope = params.get("scope", [""])[0]
            msg = "Strava authorized. Close this tab and return to the terminal."
        else:
            _Catcher.error = params.get("error", ["unknown"])[0]
            msg = f"Authorization failed: {_Catcher.error}"
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(f"<html><body><h2>{msg}</h2></body></html>".encode())

    def log_message(self, *_):
        pass


def main():
    ap = argparse.ArgumentParser(description="One-time Strava OAuth setup.")
    ap.add_argument("--scope", default="activity:read_all,activity:write",
                    help="Comma-separated Strava scopes (default: activity:read_all,activity:write).")
    ap.add_argument("--port", type=int, default=8721,
                    help="Local port for the OAuth redirect (default: 8721).")
    ap.add_argument("--no-browser", action="store_true",
                    help="Do not auto-open the browser; just print the URL.")
    args = ap.parse_args()

    client_id = op_read("client_id")
    client_secret = op_read("client_secret")
    if not client_id or not client_secret:
        sys.exit(
            f"client_id/client_secret not found in 1Password item '{OP_ITEM}' "
            f"(section '{OP_SECTION}'). Add them first — see SKILL.md."
        )

    redirect_uri = f"http://localhost:{args.port}/exchange"
    auth_url = f"{AUTHORIZE_URL}?" + urllib.parse.urlencode({
        "client_id": client_id,
        "response_type": "code",
        "redirect_uri": redirect_uri,
        "approval_prompt": "force",
        "scope": args.scope,
    })

    print("Authorize this app in your browser:\n")
    print(f"  {auth_url}\n")
    print(f"Listening for the redirect on {redirect_uri} ...")
    if not args.no_browser:
        try:
            webbrowser.open(auth_url)
        except Exception:
            pass

    server = HTTPServer(("127.0.0.1", args.port), _Catcher)
    while _Catcher.code is None and _Catcher.error is None:
        server.handle_request()
    if _Catcher.error:
        sys.exit(f"Authorization failed: {_Catcher.error}")

    print(f"Authorization code received. Scopes granted: {_Catcher.scope or '(none reported)'}")
    if "activity:read" not in _Catcher.scope:
        print("WARNING: no read scope granted — viewing sessions will fail. "
              "Re-run and approve activity:read_all.", file=sys.stderr)

    tok = post_form(TOKEN_URL, {
        "client_id": client_id,
        "client_secret": client_secret,
        "code": _Catcher.code,
        "grant_type": "authorization_code",
    })

    op_write("refresh_token", tok["refresh_token"], concealed=True)
    print(f"\nStored refresh_token in 1Password ('{OP_ITEM}' / section '{OP_SECTION}').")
    athlete = tok.get("athlete") or {}
    if athlete:
        name = f"{athlete.get('firstname', '')} {athlete.get('lastname', '')}".strip()
        print(f"Authorized as: {name} (athlete id {athlete.get('id')})")
    print("Done — you can now use the strava-sessions skill.")


if __name__ == "__main__":
    main()

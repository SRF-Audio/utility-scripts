#!/usr/bin/env python3
"""Strava: one-time OAuth setup and activity viewing.

Credentials (client_id/client_secret/refresh_token) live in 1Password and are
only ever read/written via the `op` CLI — never echoed or passed on the
command line. Short-lived access tokens are cached locally.

Subcommands:
  auth    One-time OAuth: mint a refresh token and store it in 1Password.
  list    Recent activities (optionally filtered by sport).
  detail  Full detail for one activity by id.
  stats   Aggregate totals per sport over a time window.
"""
import argparse
import json
import os
import shlex
import shutil
import stat
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer

OP_VAULT = os.environ.get("STRAVA_OP_VAULT", "HomeLab")
OP_ITEM = os.environ.get("STRAVA_OP_ITEM", "Strava")
OP_SECTION = os.environ.get("STRAVA_OP_SECTION", "Strava API")
OP_ACCOUNT = os.environ.get("STRAVA_OP_ACCOUNT", "my.1password.com")

AUTHORIZE_URL = "https://www.strava.com/oauth/authorize"
TOKEN_URL = "https://www.strava.com/oauth/token"
API = "https://www.strava.com/api/v3"
CACHE = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "strava", "token.json",
)


# --- 1Password -------------------------------------------------------------

def _op_cmd():
    override = os.environ.get("STRAVA_OP_CMD")
    if override:
        return shlex.split(override)
    return ["op"]


OP_CMD = _op_cmd()


def op_read(field):
    ref = f"op://{OP_VAULT}/{OP_ITEM}/{OP_SECTION}/{field}"
    r = subprocess.run(
        OP_CMD + ["read", ref, "--account", OP_ACCOUNT],
        capture_output=True, text=True,
    )
    return r.stdout.strip() if r.returncode == 0 else None


def op_write(field, value, concealed=True, fatal=True):
    field_type = "password" if concealed else "text"
    assign = f"{OP_SECTION}.{field}[{field_type}]={value}"
    r = subprocess.run(
        OP_CMD + ["item", "edit", OP_ITEM, assign, "--account", OP_ACCOUNT],
        capture_output=True, text=True,
    )
    if r.returncode != 0 and fatal:
        sys.exit(f"op item edit failed: {r.stderr.strip()}")


def post_form(url, data, err_prefix="Request failed"):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        sys.exit(f"{err_prefix} ({e.code}): {e.read().decode(errors='replace')}")


# --- token management ------------------------------------------------------

def _cache_load():
    try:
        with open(CACHE) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def _cache_store(access_token, expires_at):
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    with open(CACHE, "w") as f:
        json.dump({"access_token": access_token, "expires_at": expires_at}, f)
    os.chmod(CACHE, stat.S_IRUSR | stat.S_IWUSR)


def get_access_token():
    cached = _cache_load()
    if cached and cached.get("expires_at", 0) - 60 > time.time():
        return cached["access_token"]

    cid, cs, rt = op_read("client_id"), op_read("client_secret"), op_read("refresh_token")
    if not all([cid, cs, rt]):
        sys.exit("Missing client_id/client_secret/refresh_token in 1Password. "
                 "Run `strava.py auth` first.")

    tok = post_form(TOKEN_URL, {
        "client_id": cid, "client_secret": cs,
        "grant_type": "refresh_token", "refresh_token": rt,
    }, err_prefix="Token refresh failed (if this is an auth error, re-run `strava.py auth`)")

    if tok.get("refresh_token") and tok["refresh_token"] != rt:
        op_write("refresh_token", tok["refresh_token"], fatal=False)  # Strava rotated it
    _cache_store(tok["access_token"], tok["expires_at"])
    return tok["access_token"]


# --- auth (one-time OAuth) ---------------------------------------------------

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


def cmd_auth(args):
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
    }, err_prefix="Token exchange failed")

    op_write("refresh_token", tok["refresh_token"], concealed=True)
    print(f"\nStored refresh_token in 1Password ('{OP_ITEM}' / section '{OP_SECTION}').")
    athlete = tok.get("athlete") or {}
    if athlete:
        name = f"{athlete.get('firstname', '')} {athlete.get('lastname', '')}".strip()
        print(f"Authorized as: {name} (athlete id {athlete.get('id')})")
    print("Done — list/detail/stats will work now.")


# --- API -------------------------------------------------------------------

def api_get(token, path, params=None):
    url = f"{API}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        if e.code == 401:
            detail += "\n(401 — token lacks scope or is invalid. Re-run `strava.py auth` and approve activity:read_all.)"
        sys.exit(f"Strava API error {e.code}: {detail}")


def fetch_activities(token, count=None, sport=None, after=None, before=None, max_pages=15):
    out, page = [], 1
    while page <= max_pages:
        params = {"page": page, "per_page": 200}
        if after is not None:
            params["after"] = after
        if before is not None:
            params["before"] = before
        batch = api_get(token, "/athlete/activities", params)
        if not batch:
            break
        for a in batch:
            if sport:
                st = a.get("sport_type") or a.get("type") or ""
                if st.lower() != sport.lower():
                    continue
            out.append(a)
            if count and len(out) >= count:
                return out
        page += 1
    return out


# --- formatting ------------------------------------------------------------

def fmt_dist(m):
    km = (m or 0) / 1000.0
    return f"{km:6.2f} km ({km * 0.621371:5.2f} mi)"


def fmt_time(s):
    s = int(s or 0)
    h, rem = divmod(s, 3600)
    m, sec = divmod(rem, 60)
    return f"{h}:{m:02d}:{sec:02d}" if h else f"{m}:{sec:02d}"


def fmt_date(iso, local=True):
    if not iso:
        return "?"
    return iso.replace("T", " ").rstrip("Z")[:16]


def print_list(acts):
    if not acts:
        print("No activities found.")
        return
    print(f"{'Date':<17} {'Type':<14} {'Distance':>20} {'Time':>9}  Name")
    print("-" * 90)
    for a in acts:
        print(f"{fmt_date(a.get('start_date_local')):<17} "
              f"{(a.get('sport_type') or a.get('type') or '?'):<14} "
              f"{fmt_dist(a.get('distance')):>20} "
              f"{fmt_time(a.get('moving_time')):>9}  "
              f"{a.get('name', '')}  [id {a.get('id')}]")


def print_detail(a):
    rows = [
        ("Name", a.get("name")),
        ("Type", a.get("sport_type") or a.get("type")),
        ("Start (local)", fmt_date(a.get("start_date_local"))),
        ("Distance", fmt_dist(a.get("distance"))),
        ("Moving time", fmt_time(a.get("moving_time"))),
        ("Elapsed time", fmt_time(a.get("elapsed_time"))),
        ("Elevation gain", f"{a.get('total_elevation_gain', 0):.0f} m"),
        ("Avg speed", f"{(a.get('average_speed') or 0) * 3.6:.2f} km/h"),
        ("Max speed", f"{(a.get('max_speed') or 0) * 3.6:.2f} km/h"),
        ("Avg HR", a.get("average_heartrate")),
        ("Max HR", a.get("max_heartrate")),
        ("Avg watts", a.get("average_watts")),
        ("Calories", a.get("calories")),
        ("Gear", (a.get("gear") or {}).get("name")),
        ("Kudos", a.get("kudos_count")),
        ("Activity id", a.get("id")),
    ]
    for label, val in rows:
        if val not in (None, "", 0):
            print(f"{label:>16}: {val}")
    laps = a.get("laps") or []
    if laps:
        print(f"\n  Laps ({len(laps)}):")
        for i, lap in enumerate(laps, 1):
            print(f"   {i:>2}. {fmt_dist(lap.get('distance')):>20}  "
                  f"{fmt_time(lap.get('moving_time')):>9}  "
                  f"{(lap.get('average_speed') or 0) * 3.6:.1f} km/h")


def print_stats(acts, days):
    agg = {}
    for a in acts:
        k = a.get("sport_type") or a.get("type") or "Unknown"
        d = agg.setdefault(k, {"count": 0, "distance": 0.0, "moving": 0, "elev": 0.0})
        d["count"] += 1
        d["distance"] += a.get("distance", 0) or 0
        d["moving"] += a.get("moving_time", 0) or 0
        d["elev"] += a.get("total_elevation_gain", 0) or 0
    if not agg:
        print(f"No activities in the last {days} days.")
        return
    print(f"Summary — last {days} days ({len(acts)} activities)\n")
    print(f"{'Sport':<16}{'#':>4}{'Distance':>16}{'Moving':>12}{'Elev':>10}")
    print("-" * 58)
    for k in sorted(agg, key=lambda x: -agg[x]["distance"]):
        d = agg[k]
        print(f"{k:<16}{d['count']:>4}{d['distance'] / 1000:>13.1f} km"
              f"{fmt_time(d['moving']):>12}{d['elev']:>8.0f} m")


# --- subcommands -----------------------------------------------------------

def cmd_list(token, args):
    acts = fetch_activities(token, count=args.count, sport=args.sport)
    print(json.dumps(acts, indent=2)) if args.json else print_list(acts)


def cmd_detail(token, args):
    a = api_get(token, f"/activities/{args.id}")
    print(json.dumps(a, indent=2)) if args.json else print_detail(a)


def cmd_stats(token, args):
    after = int((datetime.now(timezone.utc) - timedelta(days=args.days)).timestamp())
    acts = fetch_activities(token, sport=args.sport, after=after)
    print(json.dumps(acts, indent=2)) if args.json else print_stats(acts, args.days)


def main():
    ap = argparse.ArgumentParser(description="Strava: OAuth setup and activity viewing.")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_auth = sub.add_parser("auth", help="One-time OAuth setup (mints refresh token).")
    p_auth.add_argument("--scope", default="activity:read_all,activity:write",
                        help="Comma-separated Strava scopes (default: activity:read_all,activity:write).")
    p_auth.add_argument("--port", type=int, default=8721,
                        help="Local port for the OAuth redirect (default: 8721).")
    p_auth.add_argument("--no-browser", action="store_true",
                        help="Do not auto-open the browser; just print the URL.")
    p_auth.set_defaults(func=cmd_auth, needs_token=False)

    p_list = sub.add_parser("list", help="Recent activities.")
    p_list.add_argument("-n", "--count", type=int, default=30)
    p_list.add_argument("-s", "--sport", help="Filter by sport/type (e.g. Kitesurf, Run, Ride).")
    p_list.add_argument("--json", action="store_true")
    p_list.set_defaults(func=cmd_list, needs_token=True)

    p_det = sub.add_parser("detail", help="Full detail for one activity.")
    p_det.add_argument("id")
    p_det.add_argument("--json", action="store_true")
    p_det.set_defaults(func=cmd_detail, needs_token=True)

    p_stat = sub.add_parser("stats", help="Aggregate totals per sport over a window.")
    p_stat.add_argument("-d", "--days", type=int, default=28)
    p_stat.add_argument("-s", "--sport", help="Filter by sport/type.")
    p_stat.add_argument("--json", action="store_true")
    p_stat.set_defaults(func=cmd_stats, needs_token=True)

    args = ap.parse_args()
    if args.needs_token:
        args.func(get_access_token(), args)
    else:
        args.func(args)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""View Strava fitness sessions.

Reads client_id/client_secret/refresh_token from 1Password (via `op`), refreshes
a short-lived access token (cached locally), and queries the Strava API.

Subcommands:
  list    Recent activities (optionally filtered by sport).
  detail  Full detail for one activity by id.
  stats   Aggregate totals per sport over a time window.
"""
import argparse
import json
import os
import stat
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

OP_VAULT = os.environ.get("STRAVA_OP_VAULT", "HomeLab")
OP_ITEM = os.environ.get("STRAVA_OP_ITEM", "Strava")
OP_SECTION = os.environ.get("STRAVA_OP_SECTION", "Strava API")
OP_ACCOUNT = os.environ.get("STRAVA_OP_ACCOUNT", "my.1password.com")

TOKEN_URL = "https://www.strava.com/oauth/token"
API = "https://www.strava.com/api/v3"
CACHE = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "strava-sessions", "token.json",
)


# --- 1Password -------------------------------------------------------------

def op_read(field):
    ref = f"op://{OP_VAULT}/{OP_ITEM}/{OP_SECTION}/{field}"
    r = subprocess.run(
        ["op", "read", ref, "--account", OP_ACCOUNT],
        capture_output=True, text=True,
    )
    return r.stdout.strip() if r.returncode == 0 else None


def op_write(field, value):
    assign = f"{OP_SECTION}.{field}[password]={value}"
    subprocess.run(
        ["op", "item", "edit", OP_ITEM, assign, "--account", OP_ACCOUNT],
        capture_output=True, text=True,
    )


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
                 "Run the strava-auth skill first.")

    body = urllib.parse.urlencode({
        "client_id": cid, "client_secret": cs,
        "grant_type": "refresh_token", "refresh_token": rt,
    }).encode()
    req = urllib.request.Request(TOKEN_URL, data=body, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            tok = json.load(resp)
    except urllib.error.HTTPError as e:
        sys.exit(f"Token refresh failed ({e.code}): {e.read().decode(errors='replace')}\n"
                 "If this is an auth error, re-run the strava-auth skill.")

    if tok.get("refresh_token") and tok["refresh_token"] != rt:
        op_write("refresh_token", tok["refresh_token"])  # Strava rotated it
    _cache_store(tok["access_token"], tok["expires_at"])
    return tok["access_token"]


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
            detail += "\n(401 — token lacks scope or is invalid. Re-run strava-auth with activity:read_all.)"
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
    ap = argparse.ArgumentParser(description="View Strava fitness sessions.")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_list = sub.add_parser("list", help="Recent activities.")
    p_list.add_argument("-n", "--count", type=int, default=30)
    p_list.add_argument("-s", "--sport", help="Filter by sport/type (e.g. Kitesurf, Run, Ride).")
    p_list.add_argument("--json", action="store_true")
    p_list.set_defaults(func=cmd_list)

    p_det = sub.add_parser("detail", help="Full detail for one activity.")
    p_det.add_argument("id")
    p_det.add_argument("--json", action="store_true")
    p_det.set_defaults(func=cmd_detail)

    p_stat = sub.add_parser("stats", help="Aggregate totals per sport over a window.")
    p_stat.add_argument("-d", "--days", type=int, default=28)
    p_stat.add_argument("-s", "--sport", help="Filter by sport/type.")
    p_stat.add_argument("--json", action="store_true")
    p_stat.set_defaults(func=cmd_stats)

    args = ap.parse_args()
    token = get_access_token()
    args.func(token, args)


if __name__ == "__main__":
    main()

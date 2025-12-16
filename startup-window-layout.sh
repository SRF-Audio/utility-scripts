#!/usr/bin/env bash

# This script arranges my windows in a consistent layout for 3 monitors in KDE, using KWin scripting.
# To customize this script, and the list of apps, here are the useful commands to inspect KWin's state:

# * List displays + count (source for absolute screen geometries):
#
#   qdbus-qt6 org.kde.KWin /KWin org.kde.KWin.supportInformation
#
# * List currently open GUI windows (KRunner/WindowsRunner results; 3rd string = app id):
#
#   qdbus-qt6 --literal org.kde.KWin /WindowsRunner org.kde.krunner1.Match ""
#
# * Inspect a specific window (by UUID) for geometry and identifiers:
#
#   qdbus-qt6 org.kde.KWin /KWin org.kde.KWin.getWindowInfo "{UUID}"
#
# * Interactive picker for a window (click a window, then it prints info):
#
#   qdbus-qt6 org.kde.KWin /KWin org.kde.KWin.queryWindowInfo
#
# * Virtual desktop IDs:
#
#   qdbus-qt6 --literal org.kde.KWin /VirtualDesktopManager org.freedesktop.DBus.Properties.Get org.kde.KWin.VirtualDesktopManager desktops
#
# ### The verified loop that printed **app id → geometry** for all open apps
#
# qdbus-qt6 --literal org.kde.KWin /WindowsRunner org.kde.krunner1.Match "" \
# | grep -oP '"\K0_\{[0-9a-f-]{8}-[0-9a-f-]{4}-[0-9a-f-]{4}-[0-9a-f-]{4}-[0-9a-f-]{12}\}(?=",)' \
# | sed 's/^0_//' \
# | sort -u \
# | while read -r U; do
#   qdbus-qt6 org.kde.KWin /KWin org.kde.KWin.getWindowInfo "$U" \
#   | awk '/^desktopFile:/ {app=$2} /^resourceName:/ {res=$2} /^x:/{x=$2} /^y:/{y=$2} /^width:/{w=$2} /^height:/{h=$2} END{print (app!=""?app:res), "x="x, "y="y, "w="w, "h="h}'
# done

set -Eeuo pipefail

LOG_TAG="[kwin-layout]"
log() { printf '%s %s\n' "$LOG_TAG" "$*"; }
die() { printf '%s ERROR: %s\n' "$LOG_TAG" "$*" >&2; exit 1; }

require() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }
require qdbus-qt6
require awk
require grep
require sed
require sort
require mktemp
require tr
require wc
require printf
require date
require sleep

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---- Time gate: only run Mon–Fri, 06:00–15:00 local time
within_allowed_window() {
  local dow hm
  dow="$(date +%u)"    # 1..7 (Mon..Sun)
  hm="$(date +%H%M)"   # HHMM
  [[ "$dow" -ge 1 && "$dow" -le 5 ]] || return 1
  [[ "$hm" -ge 0600 && "$hm" -le 1500 ]] || return 1
  return 0
}

if ! within_allowed_window; then
  log "Outside allowed window (Mon–Fri 0600–1500); exiting."
  exit 0
fi

# ---- Desired layout (app id → x y w h). Duplicate keys allowed (two Firefox windows).
readarray -t TARGETS <<'EOF'
md.obsidian.Obsidian x=5120 y=0 w=1440 h=1280
org.kde.konsole x=5120 y=1280 w=1440 h=1280
code x=2560 y=435 w=2560 h=1396
org.mozilla.firefox x=1280 y=0 w=1280 h=1440
org.mozilla.firefox x=0 y=0 w=1280 h=1440
org.signal.Signal x=1330 y=1440 w=960 h=540
1password x=1330 y=1980 w=960 h=540
com.discordapp.Discord x=370 y=1440 w=960 h=542
com.slack.Slack x=370 y=1980 w=960 h=540
EOF

log "Starting…"

# ---- Build NEED map (app → count)
declare -A NEED
for line in "${TARGETS[@]}"; do
  app=${line%% *}
  NEED["$app"]=$(( ${NEED["$app"]:-0} + 1 ))
done

for a in "${!NEED[@]}"; do log "need $a = ${NEED[$a]}"; done

# ---- Helpers built only from verified primitives

# 1) UUIDs of open windows from WindowsRunner
uuids_from_match() {
  qdbus-qt6 --literal org.kde.KWin /WindowsRunner org.kde.krunner1.Match "" \
  | grep -oP '"\K0_\{[0-9a-f-]{8}-[0-9a-f-]{4}-[0-9a-f-]{4}-[0-9a-f-]{4}-[0-9a-f-]{12}\}(?=",)' \
  | sed 's/^0_//' \
  | sort -u
}

# 2) For a UUID, get app id (prefer desktopFile, else resourceClass, else resourceName)
app_id_from_uuid() {
  local u="$1"
  qdbus-qt6 org.kde.KWin /KWin org.kde.KWin.getWindowInfo "$u" 2>/dev/null \
  | awk '/^desktopFile:/ {df=$2} /^resourceClass:/ {rc=$2} /^resourceName:/ {rn=$2} END{
      if (df!="") print df; else if (rc!="") print rc; else if (rn!="") print rn;
    }'
}

# 3) For a UUID, print geometry line (for post-report)
geom_from_uuid() {
  local u="$1"
  qdbus-qt6 org.kde.KWin /KWin org.kde.KWin.getWindowInfo "$u" 2>/dev/null \
  | awk '
      /^desktopFile:/ {app=$2}
      /^resourceClass:/ {rc=$2}
      /^resourceName:/ {rn=$2}
      /^x:/{x=$2} /^y:/{y=$2} /^width:/{w=$2} /^height:/{h=$2}
      END{
        id=(app!=""?app:(rc!=""?rc:rn));
        if (id!="") printf "%s x=%s y=%s w=%s h=%s\n", id, x, y, w, h;
      }'
}

run_detached() {
  if have_cmd setsid; then
    setsid -f "$@" >/dev/null 2>&1 || true
  else
    nohup "$@" >/dev/null 2>&1 &
  fi
}

launch_app() {
  local app_id="$1"

  case "$app_id" in
    org.mozilla.firefox)
      run_detached firefox --new-window about:blank
      return 0
      ;;
    code)
      run_detached code --new-window
      return 0
      ;;
  esac

  if have_cmd gtk-launch; then
    run_detached gtk-launch "$app_id"
  elif have_cmd xdg-open; then
    run_detached xdg-open "application://$app_id.desktop"
  else
    run_detached "$app_id"
  fi
}

launch_missing_apps() {
  local -n _need_ref=$1
  local -n _have_ref=$2

  for app in "${!_need_ref[@]}"; do
    local need_count="${_need_ref[$app]}"
    local have_count="${_have_ref[$app]:-0}"
    local missing_count=$((need_count - have_count))
    if (( missing_count > 0 )); then
      log "Launching $app x${missing_count} (have $have_count / need $need_count)"
      for ((i=0; i<missing_count; i++)); do
        launch_app "$app"
        sleep 0.2
      done
    fi
  done
}

# ---- Wait loop: compare NEED to actual app ids derived via getWindowInfo
deadline=$((SECONDS+180))
attempt=0
all_ok=false

while (( SECONDS < deadline )); do
  attempt=$((attempt+1))

  mapfile -t UUIDS < <(uuids_from_match) || UUIDS=()
  if ((${#UUIDS[@]}==0)); then
    log "Attempt #$attempt: no UUIDs yet; retrying…"
    sleep 2
    continue
  fi

  declare -A HAVE=()
  OPEN_DEBUG=()
  for u in "${UUIDS[@]}"; do
    id="$(app_id_from_uuid "$u" || true)"
    if [ -n "${id:-}" ]; then
      HAVE["$id"]=$(( ${HAVE["$id"]:-0} + 1 ))
      OPEN_DEBUG+=("$id")
    fi
  done

  log "Attempt #$attempt: open summary:"
  printf '%s\n' "${OPEN_DEBUG[@]}" | sort | uniq -c \
    | awk -v pfx="$LOG_TAG " '{printf "%s%3d %s\n", pfx, $1, $2}'

  launch_missing_apps NEED HAVE

  missing=()
  for app in "${!NEED[@]}"; do
    have_count=${HAVE["$app"]:-0}
    need_count=${NEED["$app"]}
    if (( have_count < need_count )); then
      missing+=("$app:$have_count/$need_count")
    fi
  done

  if ((${#missing[@]}==0)); then
    all_ok=true
    log "All required apps are open."
    break
  fi

  log "Attempt #$attempt: waiting → ${missing[*]}"
  sleep 2
done

if ! $all_ok; then
  die "Timeout; not all required apps appeared."
fi

# ---- Build one KWin script with the placement plan
tmp_js="$(mktemp /tmp/kwin_place_multi_XXXXXX.js)"
{
  echo '(function(){'
  echo '  const plan = {};'
  for line in "${TARGETS[@]}"; do
    app=${line%% *}; rest=${line#* }
    eval "$rest"
    printf "  plan['%s'] = (plan['%s']||[]).concat([{x:%s,y:%s,w:%s,h:%s}]);\n" "$app" "$app" "$x" "$y" "$w" "$h"
  done
  cat <<'JS'
  const list = (workspace.stackingOrder || workspace.windows || []);
  const buckets = {};
  for (let i=0;i<list.length;i++){
    const w=list[i]; if(!w) continue;
    const id = w.desktopFile || w.resourceClass || w.resourceName || '';
    if (!buckets[id]) buckets[id]=[];
    buckets[id].push(w);
  }
  for (const app in plan){
    const targets = plan[app] || [];
    const wins = (buckets[app] || []);
    for (let i=0; i<targets.length && i<wins.length; i++){
      const w = wins[i], g = w.frameGeometry, t = targets[i];
      g.x=t.x; g.y=t.y; g.width=t.w; g.height=t.h; w.frameGeometry=g;
    }
  }
})();
JS
} > "$tmp_js"

log "Applying layout via KWin script: $tmp_js"
qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$tmp_js" >/dev/null || die "loadScript failed"
qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null || die "Scripting.start failed"

# ---- Post-placement report
log "Post-placement report (actual):"
mapfile -t UUIDS2 < <(uuids_from_match) || UUIDS2=()
for u in "${UUIDS2[@]}"; do
  geom_from_uuid "$u"
done | sort | awk -v pfx="$LOG_TAG " '{print pfx $0}'

log "Intended plan:"
for line in "${TARGETS[@]}"; do log "  $line"; done

rm -f "$tmp_js"
log "Done."

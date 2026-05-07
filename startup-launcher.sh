#!/usr/bin/env bash
# Workday morning launcher: opens daily apps on weekdays 06:00–14:59.
# Window placement is handled by KWin Rules (~/.config/kwinrulesrc), not this script.

set -eu

[[ $(date +%u) -le 5 ]] || exit 0
h=$(date +%-H)
(( h >= 6 && h < 15 )) || exit 0

apps=(
  zen-browser
  code
  org.kde.konsole
  md.obsidian.Obsidian
  com.discordapp.Discord
  net.thunderbird.Thunderbird
  org.signal.Signal
  com.slack.Slack
)

for app in "${apps[@]}"; do
  gtk-launch "$app" >/dev/null 2>&1 &
done

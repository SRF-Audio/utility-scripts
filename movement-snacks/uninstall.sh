#!/usr/bin/env bash
# Movement Snacks — uninstall script
# --keep-data preserves ~/.local/share/movement-snacks/ (state.json + HTML)
set -euo pipefail

KEEP_DATA=false
for arg in "$@"; do
    [[ "$arg" == "--keep-data" ]] && KEEP_DATA=true
done

echo "=== Movement Snacks Uninstall ==="

# ── Stop and disable ──────────────────────────────────────────────────────────
systemctl --user stop movement-snacks.timer movement-snacks.service 2>/dev/null || true
systemctl --user disable movement-snacks.timer 2>/dev/null || true

# ── Remove systemd units ──────────────────────────────────────────────────────
rm -f "$HOME/.config/systemd/user/movement-snacks.service"
rm -f "$HOME/.config/systemd/user/movement-snacks.timer"
systemctl --user daemon-reload
echo "Removed systemd units"

# ── Remove scripts ────────────────────────────────────────────────────────────
rm -f "$HOME/.local/bin/movement-snacks.py"
rm -f "$HOME/.local/bin/generate_html.py"
echo "Removed scripts"

# ── Remove config (always) ───────────────────────────────────────────────────
# Note: routines.json customizations live here — back them up before uninstalling
# if you've edited them and want to keep the changes.
rm -rf "$HOME/.config/movement-snacks"
echo "Removed config"

# ── Remove data (conditional) ────────────────────────────────────────────────
if [[ "$KEEP_DATA" == "false" ]]; then
    rm -rf "$HOME/.local/share/movement-snacks"
    echo "Removed data (state.json + HTML)"
else
    echo "Kept data at $HOME/.local/share/movement-snacks"
fi

echo ""
echo "=== Uninstall complete ==="

#!/usr/bin/env bash
# Movement Snacks — install script
# Resolves claude binary, writes config, installs scripts + systemd units,
# generates HTML, enables timer, and runs smoke tests.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/movement-snacks"
DATA_DIR="$HOME/.local/share/movement-snacks"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"

echo "=== Movement Snacks Setup ==="
echo ""

# ── 1. Resolve claude binary ─────────────────────────────────────────────────
CLAUDE_BIN="$(which claude 2>/dev/null || true)"
if [[ -z "$CLAUDE_BIN" ]]; then
    echo "ERROR: 'claude' not found on PATH. Install Claude CLI first." >&2
    exit 1
fi
echo "claude binary: $CLAUDE_BIN"

# ── 2. Create directories ────────────────────────────────────────────────────
mkdir -p "$CONFIG_DIR" "$DATA_DIR/html" "$BIN_DIR" "$SYSTEMD_DIR"

# ── 3. routines.json — install if not present ────────────────────────────────
if [[ ! -f "$CONFIG_DIR/routines.json" ]]; then
    cp "$SCRIPT_DIR/routines.json" "$CONFIG_DIR/routines.json"
    echo "Installed routines.json"
else
    echo "Keeping existing routines.json (delete to reset)"
fi

# ── 4. config.toml — install if not present, else update claude_bin ──────────
if [[ ! -f "$CONFIG_DIR/config.toml" ]]; then
    cat > "$CONFIG_DIR/config.toml" <<TOMLEOF
start_hour = 9
end_hour = 15
active_days = ["Mon","Tue","Wed","Thu","Fri"]
notification_timeout_ms = 15000
claude_bin = "$CLAUDE_BIN"
claude_timeout_seconds = 60
routines_file = "~/.config/movement-snacks/routines.json"
html_output_dir = "~/.local/share/movement-snacks/html"
TOMLEOF
    echo "Installed config.toml"
else
    # Update claude_bin in-place; leave everything else untouched
    python3 - "$CONFIG_DIR/config.toml" "$CLAUDE_BIN" <<'PYEOF'
import sys, re
path, bin_path = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
content = re.sub(
    r'^claude_bin\s*=.*$',
    f'claude_bin = "{bin_path}"',
    content,
    flags=re.MULTILINE,
)
with open(path, 'w') as f:
    f.write(content)
PYEOF
    echo "Updated claude_bin in existing config.toml"
fi

# ── 5. Install Python scripts ────────────────────────────────────────────────
install -m 755 "$SCRIPT_DIR/movement-snacks.py" "$BIN_DIR/movement-snacks.py"
install -m 755 "$SCRIPT_DIR/generate_html.py"   "$BIN_DIR/generate_html.py"
echo "Installed scripts to $BIN_DIR"

# ── 6. Build systemd OnCalendar spec from config ─────────────────────────────
CALENDAR_SPEC="$(python3 - "$CONFIG_DIR/config.toml" <<'PYEOF'
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    c = tomllib.load(f)
start, end = c['start_hour'], c['end_hour']
hours = ','.join(f'{h:02d}' for h in range(start, end))
days = c.get('active_days', ['Mon','Tue','Wed','Thu','Fri'])
day_order = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
indices = [day_order.index(d) for d in days if d in day_order]
if indices and indices == list(range(indices[0], indices[-1] + 1)):
    days_spec = f'{days[0]}..{days[-1]}'
else:
    days_spec = ','.join(days)
print(f'{days_spec} {hours}:00:00')
PYEOF
)"
echo "Timer schedule: $CALENDAR_SPEC"

# ── 7. systemd service ───────────────────────────────────────────────────────
# graphical-session.target ensures DISPLAY/WAYLAND_DISPLAY are imported into
# the user session environment (KDE does this via import-environment at login).
cat > "$SYSTEMD_DIR/movement-snacks.service" <<EOF
[Unit]
Description=Movement Snack hourly notification trigger
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=$BIN_DIR/movement-snacks.py
StandardOutput=journal
StandardError=journal
SyslogIdentifier=movement-snacks
TimeoutStartSec=90
EOF

# ── 8. systemd timer ─────────────────────────────────────────────────────────
cat > "$SYSTEMD_DIR/movement-snacks.timer" <<EOF
[Unit]
Description=Movement Snack hourly trigger timer

[Timer]
OnCalendar=$CALENDAR_SPEC
Persistent=true

[Install]
WantedBy=timers.target
EOF

# ── 9. Generate HTML reference pages ────────────────────────────────────────
echo ""
echo "Generating HTML reference pages..."
"$BIN_DIR/generate_html.py"

# ── 10. Enable and start timer ───────────────────────────────────────────────
systemctl --user daemon-reload
systemctl --user enable --now movement-snacks.timer
echo "Timer enabled and started"

# ── 11. Test: kdialog smoke test ─────────────────────────────────────────────
echo ""
echo "--- kdialog smoke test ---"
if ! command -v kdialog &>/dev/null; then
    echo "WARNING: kdialog not found — install with: sudo dnf install kde-cli-tools"
else
    echo "A test dialog will appear. Click any button to confirm it works."
    kdialog \
        --title "Movement Snacks — Setup Test" \
        --warningyesnocancel "This is the action dialog that will appear each hour.
Click any button to continue setup." \
        --yes-label "✓ Complete" \
        --no-label "View Exercises" \
        --cancel-label "✗ Skip" 2>/dev/null
    KDIALOG_RC=$?
    case $KDIALOG_RC in
        0) echo "OK — 'Complete' button works" ;;
        1) echo "OK — 'View Exercises' button works" ;;
        2) echo "OK — 'Skip' button works" ;;
        *) echo "WARNING: kdialog exited with code $KDIALOG_RC" ;;
    esac
fi

# ── 12. Test: claude CLI ─────────────────────────────────────────────────────
echo ""
echo "--- Claude CLI smoke test (timeout 20s) ---"
# Use -p (print mode) for non-interactive invocation; write to temp file so
# Ctrl+C propagates correctly and we don't block inside $().
CLAUDE_TMP="$(mktemp)"
timeout 20 "$CLAUDE_BIN" -p 'Reply with only the word READY, nothing else.' \
    > "$CLAUDE_TMP" 2>&1
CLAUDE_RC=$?
if [[ $CLAUDE_RC -eq 124 ]]; then
    echo "WARNING: claude timed out after 20s."
    echo "  Check that 'claude -p' works interactively and the Strava skill is configured."
elif [[ $CLAUDE_RC -ne 0 ]]; then
    echo "WARNING: claude exited with code $CLAUDE_RC. Output:"
    head -5 "$CLAUDE_TMP"
    echo "  Strava posts may fail. Check: claude login and fitness-coach skill."
elif grep -qi "READY" "$CLAUDE_TMP"; then
    echo "OK — claude CLI is functional"
else
    echo "WARNING: claude responded but not with 'READY'. Output:"
    head -3 "$CLAUDE_TMP"
fi
rm -f "$CLAUDE_TMP"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== Setup complete ==="
systemctl --user list-timers movement-snacks.timer --no-pager 2>/dev/null || true
echo ""
echo "To test manually:  systemctl --user start movement-snacks.service"
echo "To watch logs:     journalctl --user -u movement-snacks.service -f"
echo "To edit routines:  \$EDITOR $CONFIG_DIR/routines.json  then  generate_html.py"

#!/usr/bin/env python3
"""Movement snack hourly trigger — KDE Plasma, stdlib only."""

import json
import re
import subprocess
import sys
import threading
import time
import tomllib
from pathlib import Path

CONFIG_PATH = Path("~/.config/movement-snacks/config.toml").expanduser()
STATE_PATH = Path("~/.local/share/movement-snacks/state.json").expanduser()


def load_config():
    with open(CONFIG_PATH, "rb") as f:
        return tomllib.load(f)


def load_routines(config):
    p = Path(config["routines_file"]).expanduser()
    with open(p) as f:
        return json.load(f)["routines"]


def load_state():
    if STATE_PATH.exists():
        with open(STATE_PATH) as f:
            return json.load(f)
    return {
        "current_routine_index": 0,
        "last_triggered_iso": None,
        "complete_count": 0,
        "skip_count": 0,
        "view_count": 0,
    }


def save_state(state):
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE_PATH.with_suffix(".tmp")
    with open(tmp, "w") as f:
        json.dump(state, f)
    tmp.rename(STATE_PATH)


def show_dialog(routine, timeout_s):
    """
    Show a kdialog with three action buttons. Blocks until the user responds
    or timeout_s elapses (auto-treated as Skip).

    Exit codes from kdialog --warningyesnocancel:
      0 = Yes  → Complete
      1 = No   → View Exercises
      2 = Cancel → Skip
    timeout (exit 124 from `timeout` cmd) → Skip
    """
    title = f"Movement Snack — {routine['name']}"
    body = "\n".join(
        f"• {ex['name']}  {ex['reps_or_duration']} — {ex['cue']}"
        for ex in routine["exercises"]
    )

    try:
        result = subprocess.run(
            [
                "timeout", str(int(timeout_s)),
                "kdialog",
                "--title", title,
                "--warningyesnocancel", body,
                "--yes-label", "✓ Complete",
                "--no-label", "View Exercises",
                "--cancel-label", "✗ Skip",
            ],
            capture_output=True,
            timeout=int(timeout_s) + 5,
        )
    except subprocess.TimeoutExpired:
        return None

    if result.returncode == 0:
        return "complete"
    if result.returncode == 1:
        return "view"
    # 2 = skip/cancel, 124 = auto-timeout, anything else = error → treat as skip
    return None


def send_error_notification(title, body):
    """Non-blocking passive popup for error feedback (no user interaction needed)."""
    subprocess.Popen(
        ["kdialog", "--passivepopup", f"{title}\n\n{body}", "10"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def sanitize(text):
    """Strip characters that could affect the claude prompt string."""
    return re.sub(r'[\n\r"\\`]', " ", str(text)).strip()


def post_to_strava(config, routine, trigger_iso):
    """
    Launch claude CLI to post Strava activity.
    Returns a non-daemon Thread; process stays alive until it completes or times out.
    """
    exercise_list = " | ".join(
        f"{sanitize(ex['name'])} x{sanitize(ex['reps_or_duration'])}"
        for ex in routine["exercises"]
    )
    prompt = (
        "Post a Strava activity with the following details using the Strava skill:\n"
        f"- Name: Movement Snack — {sanitize(routine['name'])}\n"
        "- Sport type: Weight Training\n"
        f"- Start time: {trigger_iso}\n"
        f"- Description: {exercise_list}\n"
        "Do not ask for confirmation. Post it directly.\n"
        "If the post fails for any reason, write the error to stderr and exit with a non-zero code."
    )

    claude_bin = config.get("claude_bin", "claude")
    proc = subprocess.Popen(
        [claude_bin, "-p", prompt],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        stdin=subprocess.DEVNULL,
    )
    print(f"Launched claude (PID {proc.pid}) for Strava post", flush=True)

    claude_timeout = config.get("claude_timeout_seconds", 60)

    def watch():
        try:
            stdout, stderr = proc.communicate(timeout=claude_timeout)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.communicate()
            msg = f"claude timed out after {claude_timeout}s"
            print(f"Strava post timed out (PID {proc.pid})", file=sys.stderr, flush=True)
            send_error_notification("Movement Snack — Strava Post Failed", msg)
            return

        if proc.returncode != 0:
            err = stderr.decode("utf-8", errors="replace")[:200]
            if not err:
                err = f"claude exited with code {proc.returncode}"
            print(f"Strava post failed (PID {proc.pid}): {err}", file=sys.stderr, flush=True)
            send_error_notification("Movement Snack — Strava Post Failed", err)
        else:
            summary = stdout.decode("utf-8", errors="replace").strip()[:200]
            print(f"Strava post OK (PID {proc.pid}): {summary}", flush=True)

    # Non-daemon: keeps process alive while watcher runs (max claude_timeout_seconds).
    # Killed immediately if systemd sends SIGTERM — acceptable per spec.
    t = threading.Thread(target=watch, daemon=False)
    t.start()
    return t


def open_html(config, routine_id):
    html_dir = Path(
        config.get("html_output_dir", "~/.local/share/movement-snacks/html")
    ).expanduser()
    path = html_dir / f"routine-{routine_id}.html"
    subprocess.Popen(
        ["xdg-open", str(path)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main():
    config = load_config()
    routines = load_routines(config)
    state = load_state()

    trigger_iso = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    idx = state["current_routine_index"] % len(routines)
    routine = routines[idx]
    timeout_s = config.get("notification_timeout_ms", 15000) / 1000

    print(f"[{trigger_iso}] Routine {idx + 1}/{len(routines)}: {routine['name']}", flush=True)

    action = show_dialog(routine, timeout_s)
    print(f"Action: {action or 'skip/timeout'}", flush=True)

    # Advance counter before side effects — ensures progress even if post_to_strava raises.
    state["current_routine_index"] = (idx + 1) % len(routines)
    state["last_triggered_iso"] = trigger_iso
    if action == "complete":
        state["complete_count"] = state.get("complete_count", 0) + 1
    elif action == "view":
        state["view_count"] = state.get("view_count", 0) + 1
    else:
        state["skip_count"] = state.get("skip_count", 0) + 1
    save_state(state)
    print(
        f"State updated — next index: {state['current_routine_index']} "
        f"(complete={state['complete_count']} view={state['view_count']} skip={state['skip_count']})",
        flush=True,
    )

    if action == "complete":
        post_to_strava(config, routine, trigger_iso)
    elif action == "view":
        open_html(config, routine["id"])
    # Process stays alive here until watcher thread (if any) finishes


if __name__ == "__main__":
    main()

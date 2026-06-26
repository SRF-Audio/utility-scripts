#!/usr/bin/env python3
"""Generate local HTML reference pages from routines.json."""

import json
import tomllib
from html import escape
from pathlib import Path

CONFIG_PATH = Path("~/.config/movement-snacks/config.toml").expanduser()

_CSS = """
* { box-sizing: border-box; }
body {
  font-family: system-ui, -apple-system, sans-serif;
  max-width: 780px;
  margin: 2rem auto;
  padding: 0 1.2rem 3rem;
  background: #1a1a2e;
  color: #dde2ea;
  line-height: 1.6;
}
h1 {
  color: #a8d8ea;
  border-bottom: 2px solid #a8d8ea;
  padding-bottom: 0.4rem;
  margin-bottom: 0.3rem;
}
.focus { color: #8899aa; font-style: italic; margin-top: 0; }
.exercise {
  background: #16213e;
  border: 1px solid #2a3a5e;
  border-radius: 8px;
  padding: 1.2rem 1.5rem;
  margin: 1.4rem 0;
}
.exercise-name { color: #f7d794; font-size: 1.15rem; font-weight: 600; margin: 0 0 0.4rem; }
.reps { color: #a29bfe; font-weight: 600; }
.cue { color: #74b9ff; font-style: italic; margin: 0.4rem 0 0.7rem; }
.desc { color: #c8d3de; }
img {
  max-width: 320px;
  width: 100%;
  border-radius: 5px;
  margin-top: 0.9rem;
  display: block;
  opacity: 0.9;
}
footer { margin-top: 2.5rem; color: #556; font-size: 0.85rem; }
"""


def render_page(routine):
    exercises_html = ""
    for ex in routine["exercises"]:
        img_tag = ""
        if ex.get("image_url"):
            img_tag = (
                f'<img src="{escape(ex["image_url"])}" '
                f'alt="{escape(ex["name"])}" loading="lazy">'
            )
        exercises_html += f"""
  <div class="exercise">
    <p class="exercise-name">{escape(ex['name'])}</p>
    <span class="reps">{escape(ex['reps_or_duration'])}</span>
    <p class="cue">"{escape(ex['cue'])}"</p>
    <p class="desc">{escape(ex['description'])}</p>
    {img_tag}
  </div>"""

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Movement Snack — {escape(routine['name'])}</title>
<style>{_CSS}</style>
</head>
<body>
<h1>Movement Snack — {escape(routine['name'])}</h1>
<p class="focus">{escape(routine.get('focus', ''))}</p>
{exercises_html}
<footer>Close this tab when done.</footer>
</body>
</html>
"""


def main():
    with open(CONFIG_PATH, "rb") as f:
        config = tomllib.load(f)

    routines_path = Path(config["routines_file"]).expanduser()
    with open(routines_path) as f:
        routines = json.load(f)["routines"]

    html_dir = Path(config["html_output_dir"]).expanduser()
    html_dir.mkdir(parents=True, exist_ok=True)

    for routine in routines:
        page = render_page(routine)
        out = html_dir / f"routine-{routine['id']}.html"
        out.write_text(page, encoding="utf-8")
        print(f"Wrote {out}")


if __name__ == "__main__":
    main()

# VKB Gladiator binding kneeboard

Static page that overlays JSON-driven labels onto rendered, blanked-out
VKB diagram backgrounds. One profile per game/mode, version-controlled.

## Structure

```
site/
├── index.html                # Single-page viewer
├── assets/
│   ├── bg-lh.png             # Empty LH diagram (PNG, ~330 KB, cached)
│   ├── bg-rh.png             # Empty RH diagram (PNG, ~300 KB, cached)
│   └── fields.json           # All 76 fields × 2 sides, normalized coords
└── profiles/
    ├── _index.json           # List of profiles to populate the dropdown
    ├── ed-flight.json        # ED — Ship Flight
    ├── ed-onfoot.json        # ED — On Foot (Odyssey FPS)
    ├── ed-galmap.json        # ED — Galaxy Map
    ├── ed-srv.json           # ED — SRV
    ├── msfs2024.json
    └── dcs-f16.json
```

## URLs

- `/?side=lh&profile=ed-flight` — pin this in OpenKneeboard
- `/?side=rh&profile=msfs2024`

## Adding a profile

Drop a new JSON file in `profiles/`, add it to `_index.json`. Schema:

```json
{
  "name": "Display name",
  "version": "1.0",
  "lh": { "A1_A_2": "Vertical Thrust", ... },
  "rh": { "AX_X": "Roll", ... }
}
```

Keys are the field IDs from `assets/fields.json`. Only the `_2` (value column)
cells normally need labels — the row symbol cells (˄ ˅ ˂ ˃ ʘ, F1/F2/F3, x/y/twist)
are already in the background image.

## Regenerating assets

If the source VKB PDFs change, re-run `prep.py` (in the project root). It:

1. Loads the source PDFs
2. Clears all form field values and their appearance streams
3. Renders to PNG at 150 dpi via `pdftocairo`
4. Extracts every Widget annotation's name + rectangle
5. Writes `bg-{side}.png` and `fields.json`

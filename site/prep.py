"""
Stage 1: prep — build the static assets the viewer needs.
Run once when the source PDFs change.

Inputs:  the two VKB PDFs
Outputs: assets/bg-lh.png, assets/bg-rh.png, assets/fields.json
"""
import json
import os
import subprocess
from pypdf import PdfReader, PdfWriter
from pypdf.generic import NameObject, TextStringObject

LH_SRC = "/mnt/user-data/uploads/VKB-Gladiator-SCG-OTA-LH-v1_0_bf7bdf6c-2162-4c44-aa6a-34af80c25c34.pdf"
RH_SRC = "/mnt/user-data/uploads/VKB-Gladiator-SCG-RH-v1_0_71140459-4b6c-4cf9-80f9-017d48a7b6f2.pdf"
OUT = "/home/claude/site/assets"
os.makedirs(OUT, exist_ok=True)


def clear_and_extract(src_path, side):
    """Clear all form field values, return field metadata, write a 'blank' PDF."""
    reader = PdfReader(src_path)
    writer = PdfWriter(clone_from=reader)
    page = writer.pages[0]
    mb = page.mediabox
    page_w, page_h = float(mb.width), float(mb.height)

    fields = []
    if "/Annots" in page:
        for annot_ref in page["/Annots"]:
            annot = annot_ref.get_object()
            if annot.get("/Subtype") != "/Widget":
                continue
            name = annot.get("/T")
            rect = annot.get("/Rect")
            if name is None or rect is None:
                continue
            # Skip the row-label cells (the static "˄ ˅ ˂ ˃ ʘ" symbols
            # and the "x/y/twist/throttle" axis name column) — those end in _1.
            # We only need the _2 column (the bind value cells), plus the
            # single-cell controls like B1_A_2.
            name_s = str(name)

            x1, y1, x2, y2 = [float(v) for v in rect]
            fields.append({
                "id": name_s,
                "value_col": name_s.endswith("_2") or "_" not in name_s,
                "norm": {
                    "left":   round(x1 / page_w, 6),
                    "top":    round((page_h - y2) / page_h, 6),
                    "width":  round((x2 - x1) / page_w, 6),
                    "height": round((y2 - y1) / page_h, 6),
                },
            })

            # Clear the value AND its appearance stream so it renders empty.
            annot[NameObject("/V")] = TextStringObject("")
            if "/AP" in annot:
                del annot["/AP"]

    blank_pdf = os.path.join(OUT, f"blank-{side}.pdf")
    with open(blank_pdf, "wb") as f:
        writer.write(f)

    # Render the blank PDF to PNG at 150 dpi.
    bg_png = os.path.join(OUT, f"bg-{side}")
    subprocess.run(
        ["pdftocairo", "-png", "-r", "150", "-singlefile", blank_pdf, bg_png],
        check=True,
    )
    os.remove(blank_pdf)

    return {
        "page_pt": [page_w, page_h],
        "image": f"bg-{side}.png",
        "fields": fields,
    }


data = {
    "lh": clear_and_extract(LH_SRC, "lh"),
    "rh": clear_and_extract(RH_SRC, "rh"),
}

with open(os.path.join(OUT, "fields.json"), "w") as f:
    json.dump(data, f, indent=2)

# Quick report
for side in ("lh", "rh"):
    total = len(data[side]["fields"])
    value_cells = sum(1 for f in data[side]["fields"] if f["value_col"])
    print(f"{side}: {total} fields, {value_cells} value cells")
print("Wrote:", os.listdir(OUT))

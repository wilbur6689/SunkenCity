"""Render every creature of one design sheet with its module's drawers to a
contact sheet, for eyeballing while drawing.

  python tools/fauna_art/preview.py t2 out.png     (t0 | t1 | t2)

Uses the same archetype / palette / cell logic as tools/build_fauna.py, so
what you see is what the builder will write. Each row: 4 frames at 3x, the
creature name, and its archetype key.
"""
import importlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_fauna as bf  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

SHEETS = {"t0": "t0_roof_fauna.json", "t1": "t1_dry_fauna.json", "t2": "t2_shallows_fauna.json"}


def main():
    stage = sys.argv[1]
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / ("fauna_%s_preview.png" % stage)
    importlib.reload(bf)
    design = {k: v for k, v in json.load(open(ROOT / "docs" / "monsters" / SHEETS[stage], encoding="utf-8")).items() if not k.startswith("_")}
    rows = []
    for rec in design.values():
        arch = bf.archetype(rec)
        pal = bf.palette(rec)
        strip = bf.strip(arch, pal, rec)
        rows.append((rec["name"], arch, strip))
    scale = 3
    w = max(r[2].width for r in rows) * scale + 260
    h = sum(r[2].height * scale + 6 for r in rows)
    sheet = Image.new("RGBA", (w, h), (24, 36, 52, 255))
    d = ImageDraw.Draw(sheet)
    y = 0
    for name, arch, strip in rows:
        big = strip.resize((strip.width * scale, strip.height * scale), Image.NEAREST)
        sheet.paste(big, (0, y), big)
        d.text((big.width + 8, y + 2), "%s  [%s]" % (name, arch), fill=(230, 230, 230))
        y += big.height + 6
    sheet.save(out)
    print("wrote", out, "rows", len(rows))


if __name__ == "__main__":
    main()

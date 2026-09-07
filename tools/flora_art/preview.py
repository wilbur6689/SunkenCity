"""Contact sheet for one district's flora: every species x stage, frame 0 and
the full-sway frame, standing on a stone slab, at 1x and 3x.

    python tools/flora_art/preview.py res out.png
"""
import importlib
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402
from PIL import Image  # noqa: E402

SLAB = (92, 90, 88)
SKY = (58, 74, 92)


def render(mod_name):
    mod = importlib.import_module(mod_name)
    rows = []
    for sid, spec in mod.SPECIES.items():
        cells = []
        for stage, (w, h) in enumerate(spec["stages"]):
            oid = sid + ["_seedling", "_midling", ""][stage]
            W, H = w * common.CELL, h * common.CELL
            rng = random.Random(sum(ord(ch) for ch in oid) * 7919 + stage)
            rest = spec["draw"](stage, W, H, rng).img
            pin = spec["pin"](stage, H)
            amp = 1 if spec["slot"] == "grass" else common.amplitude(H - pin)
            frames = common.sway_frames(rest, pin, amp)
            cells.append(frames[0])
            cells.append(frames[len(frames) // 2] if len(frames) > 1 else frames[0])
        rows.append(cells)
    pad = 6
    row_h = [max(c.size[1] for c in r) + pad * 2 for r in rows]
    row_w = [sum(c.size[0] + pad for c in r) + pad for r in rows]
    W = max(row_w)
    H = sum(row_h)
    sheet = Image.new("RGBA", (W, H), SKY + (255,))
    y = 0
    for r, rh in zip(rows, row_h):
        x = pad
        for c in r:
            base_y = y + rh - pad
            for sx in range(x - 2, x + c.size[0] + 2):
                for sy in range(base_y, base_y + 4):
                    if 0 <= sx < W and sy < H:
                        sheet.putpixel((sx, sy), SLAB + (255,))
            sheet.paste(c, (x, base_y - c.size[1]), c)
            x += c.size[0] + pad
        y += rh
    return sheet


if __name__ == "__main__":
    mod, out = sys.argv[1], sys.argv[2]
    sheet = render(mod)
    big = sheet.resize((sheet.size[0] * 3, sheet.size[1] * 3), Image.NEAREST)
    combo = Image.new("RGBA", (sheet.size[0] + big.size[0] + 12, big.size[1]), (30, 30, 34, 255))
    combo.paste(sheet, (0, 0))
    combo.paste(big, (sheet.size[0] + 12, 0))
    combo.save(out)
    print(out, combo.size)

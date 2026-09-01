"""Slice the hand-made monster sheets in docs/Examples/Monsters into game
sprite strips (user request 2026-09-01).

Each source sheet is a 4x2 grid of ~8 walking frames on a dark backdrop
with frame numbers baked under each cell. This: chroma-keys the backdrop,
masks off the label band, crops each frame to its figure, scales to the
game's enemy height, aligns feet on a shared baseline, and packs a
horizontal 8-frame strip into assets/sprites/enemies/.

Run from the repo root:  python tools/convert_monsters.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs" / "Examples" / "Monsters"
OUT = ROOT / "assets" / "sprites" / "enemies"

SHEETS = {  # source -> (strip name, target sprite height in px)
    "Zombie1_walking.png": ("walker.png", 26),
    "Zombie2_walking.png": ("walker_b.png", 26),
}
COLS, ROWS = 4, 2
LABEL_BAND = 0.16  # bottom fraction of each cell holding the baked number


def _scrub_feet(strip):
    """Near-white specks in the foot zone, where only dark shoes live
    (label antialias riding a leg outline survives the blob pass)."""
    spx = strip.load()
    for y in range(strip.height - 7, strip.height):
        for x in range(strip.width):
            r, g, b, a = spx[x, y]
            if a > 0 and min(r, g, b) > 150 and max(r, g, b) - min(r, g, b) < 34:
                spx[x, y] = (0, 0, 0, 0)


def key_out(img, bg, tol=60):
    """Backdrop pixels (within tol of the corner colour) become transparent."""
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) < tol:
                px[x, y] = (0, 0, 0, 0)
    return img


def convert(src, strip_name, target_h):
    sheet = Image.open(SRC / src).convert("RGB")
    bg = sheet.getpixel((4, 4))
    cw, ch = sheet.width // COLS, sheet.height // ROWS
    frames = []
    for row in range(ROWS):
        for col in range(COLS):
            cell = sheet.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
            cell = key_out(cell, bg)
            # blank the label band so the baked number never survives
            for y in range(int(ch * (1.0 - LABEL_BAND)), ch):
                for x in range(cw):
                    cell.putpixel((x, y), (0, 0, 0, 0))
            # despeckle: tiny floating blobs (label antialias survivors)
            cpx = cell.load()
            seen = set()
            for sy in range(cell.height):
                for sx in range(cell.width):
                    if cpx[sx, sy][3] == 0 or (sx, sy) in seen:
                        continue
                    blob = [(sx, sy)]
                    seen.add((sx, sy))
                    i = 0
                    while i < len(blob) and len(blob) <= 6:
                        bx, by = blob[i]
                        i += 1
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                            nx, ny = bx + dx, by + dy
                            if 0 <= nx < cell.width and 0 <= ny < cell.height                                     and cpx[nx, ny][3] > 0 and (nx, ny) not in seen:
                                seen.add((nx, ny))
                                blob.append((nx, ny))
                    if len(blob) <= 6:
                        for bx, by in blob:
                            cpx[bx, by] = (0, 0, 0, 0)
            box = cell.getbbox()
            if box is None:
                continue
            fig = cell.crop(box)
            scale = target_h / fig.height
            fig = fig.resize((max(int(fig.width * scale), 1), target_h), Image.NEAREST)
            frames.append(fig)
    fw = max(f.width for f in frames)
    strip = Image.new("RGBA", (fw * len(frames), target_h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * fw + (fw - f.width) // 2, target_h - f.height), f)
    _scrub_feet(strip)
    out = OUT / strip_name
    strip.save(out)
    print("wrote", out, strip.size, f"({len(frames)} frames of {fw}x{target_h})")


# ---------------------------------------------------------------- variants
# Five more walkers cut from the same cloth (user request 2026-09-01):
# per-class recolours of the two hand-made strips - skin, shirt, pants,
# dress and hair shift per variant while blood stays blood - plus a
# belly-bulge reshape for the two fat ones. Deterministic.

import colorsys


def _classify(r, g, b):
    h, sat, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    if sat < 0.20 and v > 0.45:
        return "shirt", h, sat, v          # pale shirt / highlights
    if 0.14 < h < 0.46 and sat > 0.12:
        return "skin", h, sat, v           # sickly greens
    if 0.52 < h < 0.86:
        return "cloth", h, sat, v          # navy pants / purple dress
    return "warm", h, sat, v               # hair, shoes, blood: hands off


def _recolor(img, skin=None, shirt=None, cloth=None, dark=1.0):
    """Each of skin/shirt/cloth is (hue 0..1, sat mult, val mult) or None."""
    img = img.copy()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            cls, h, sat, v = _classify(r, g, b)
            spec = {"skin": skin, "shirt": shirt, "cloth": cloth}.get(cls)
            if spec is None:
                if dark != 1.0:
                    px[x, y] = (int(r * dark), int(g * dark), int(b * dark), a)
                continue
            nh, sm, vm = spec
            nr, ng, nb = colorsys.hsv_to_rgb(nh, min(sat * sm, 1.0), min(v * vm * dark, 1.0))
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return img


def _fatten(strip, frames, bulge=0.45):
    """Widen the torso rows (shoulder..hip) per frame, feet kept planted."""
    import math
    fw = strip.width // frames
    h = strip.height
    new_fw = int(fw * (1.0 + bulge)) + 2
    out = Image.new("RGBA", (new_fw * frames, h), (0, 0, 0, 0))
    for i in range(frames):
        frame = strip.crop((i * fw, 0, (i + 1) * fw, h))
        wide = Image.new("RGBA", (new_fw, h), (0, 0, 0, 0))
        for y in range(h):
            t = (y - h * 0.25) / (h * 0.55)  # 0 at shoulders, 1 at hips
            f = 1.0 + bulge * math.sin(math.pi * min(max(t, 0.0), 1.0))
            row = frame.crop((0, y, fw, y + 1))
            rw = max(int(fw * f), 1)
            row = row.resize((rw, 1), Image.NEAREST)
            wide.paste(row, ((new_fw - rw) // 2, y), row)
        out.paste(wide, (i * new_fw, 0), wide)
    return out


VARIANTS = [
    # (source strip, out, kwargs for _recolor, fat)
    ("walker.png", "walker_c.png",                       # male: grave-pale, flannel red
     dict(skin=(0.28, 0.4, 1.1), shirt=(0.99, 2.6, 0.75), cloth=(0.62, 0.9, 0.8)), False),
    ("walker.png", "walker_d.png",                       # male: jaundiced, olive drab, khakis
     dict(skin=(0.17, 1.1, 1.0), shirt=(0.22, 1.9, 0.7), cloth=(0.10, 1.6, 0.9)), False),
    ("walker.png", "walker_e.png",                       # male, FAT: bloated blue-grey
     dict(skin=(0.44, 0.55, 0.95), shirt=(0.55, 1.2, 0.85), cloth=(0.0, 0.4, 0.5)), True),
    ("walker_b.png", "walker_f.png",                     # female: ashen, teal dress, dark hair
     dict(skin=(0.24, 0.35, 0.9), cloth=(0.46, 1.1, 0.85), dark=0.92), False),
    ("walker_b.png", "walker_g.png",                     # female, FAT: livid, wine dress
     dict(skin=(0.30, 0.8, 0.85), cloth=(0.93, 1.3, 0.75)), True),
]


def build_floater():
    """The floater rebuilt to match the walker art (user request
    2026-09-01): a bloated body laying flat on its stomach - belly-down
    torso, legs trailing limp behind, one arm dangling - with the real
    walker head raised at the front, looking forward along the water."""
    from PIL import ImageDraw
    strip = Image.open(OUT / "walker.png").convert("RGBA")
    fw, h = strip.width // 8, strip.height
    head = strip.crop((0, 0, fw, 10))
    hb = head.getbbox()
    head = head.crop(hb)
    W, H = 28, 16
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    OUTL = (26, 30, 34)
    shirt, shirt_d = (150, 152, 148), (112, 116, 118)   # sodden shirt
    skin, skin_d = (128, 148, 140), (96, 116, 110)      # waterlogged grey-green
    pants, shoe = (52, 60, 78), (70, 52, 40)
    # bloated torso, belly down (widest amidships)
    d.ellipse([5, 4, 21, 13], fill=shirt, outline=OUTL)
    d.ellipse([8, 8, 19, 14], fill=shirt_d, outline=OUTL)          # sunken belly line
    d.line([7, 5, 19, 5], fill=(178, 180, 176))                    # wet sheen on top
    d.point((10, 6), fill=(120, 40, 40))                           # old wound
    d.rectangle([13, 7, 15, 9], fill=(120, 40, 40))
    # legs trailing behind, limp and together
    d.rectangle([0, 7, 6, 9], fill=pants, outline=OUTL)
    d.rectangle([1, 10, 5, 11], fill=pants, outline=OUTL)
    d.rectangle([0, 6, 1, 8], fill=shoe, outline=OUTL)             # shoes tip up
    d.rectangle([0, 10, 1, 12], fill=shoe, outline=OUTL)
    # one arm dangling into the water
    d.rectangle([16, 12, 17, 15], fill=skin_d, outline=OUTL)
    d.point((16, 15), fill=skin)
    # shoulder hump into the head
    d.ellipse([17, 4, 23, 10], fill=shirt, outline=OUTL)
    img.paste(head, (W - head.width, 0), head)                     # head up, eyes forward
    img = _recolor(img, skin=(0.44, 0.5, 0.95))                    # chill the head to match
    _scrub_feet(img)
    img.save(OUT / "floater.png")
    print("wrote", OUT / "floater.png", img.size)


def build_variants():
    for src, out_name, kw, fat in VARIANTS:
        strip = Image.open(OUT / src).convert("RGBA")
        v = _recolor(strip, **kw)
        if fat:
            v = _fatten(v, 8)
        _scrub_feet(v)
        v.save(OUT / out_name)
        print("wrote", OUT / out_name, v.size, "(fat)" if fat else "")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for src, (name, h) in SHEETS.items():
        convert(src, name, h)
    build_variants()
    build_floater()

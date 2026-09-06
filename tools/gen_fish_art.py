"""Predator fish strips (user request 2026-09-06): three swimmers for the
flooded Shallows and Cold, easy -> hard.

  tropical_fish  12 px cells, 4 frames  - clownfish-bright, small, nippy
  catfish        24 px cells, 4 frames  - flat-headed, whiskered, murky brown
  barracuda      40 px cells, 4 frames  - long silver torpedo, barred, toothy

Square cells so Enemy._frames_of derives the frame count; base art faces
RIGHT (Enemy flips for facing < 0). Deterministic pixel drawing, no source
sheet. Run from the repo root:  python tools/gen_fish_art.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "enemies"
FRAMES = 4


def strip(cell, draw_frame):
    img = Image.new("RGBA", (cell * FRAMES, cell), (0, 0, 0, 0))
    for f in range(FRAMES):
        fr = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        draw_frame(ImageDraw.Draw(fr), fr, f)
        img.paste(fr, (f * cell, 0), fr)
    return img


def outline(img, colour=(10, 12, 16, 255)):
    """1 px dark outline around every opaque pixel (the placeholder-art look)."""
    src = img.copy()
    px = src.load()
    out = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and px[xx, yy][3] != 0 and px[xx, yy] != colour:
                        out[x, y] = colour
                        break


# ---- tropical fish: 12x12, body 8x5, tail fans -----------------------------
def tropical(d, img, f):
    body = (232, 120, 34)
    stripe = (250, 246, 236)
    fin = (255, 190, 70)
    dark = (40, 24, 14)
    # tail (left), wags up/down per frame
    wag = [0, 1, 0, -1][f]
    d.polygon([(1, 5 + wag), (3, 6), (1, 8 + wag)], fill=fin)
    d.polygon([(1, 4 + wag), (3, 6), (1, 7 + wag)], fill=fin)
    # body: rounded oval x 3..10, y 4..8
    d.ellipse([3, 4, 10, 8], fill=body)
    # two pale stripes
    d.line([(5, 4), (5, 8)], fill=stripe)
    d.line([(8, 5), (8, 8)], fill=stripe)
    # dorsal + belly fins
    d.line([(5, 3), (7, 3)], fill=fin)
    d.point((6, 9), fill=fin)
    # eye near the head (right)
    d.point((9, 5), fill=dark)


# ---- catfish: 24x24, body 20x8 with barbels ---------------------------------
def catfish(d, img, f):
    back = (86, 74, 58)
    side = (118, 102, 80)
    belly = (168, 150, 118)
    fin = (72, 62, 48)
    dark = (28, 22, 18)
    wag = [0, 1, 0, -1][f]
    # tail
    d.polygon([(1, 9 + wag), (4, 12), (1, 15 + wag)], fill=fin)
    d.polygon([(1, 10 + wag), (5, 12), (1, 14 + wag)], fill=side)
    # body: long, flat head to the right
    d.ellipse([3, 8, 21, 16], fill=side)
    d.ellipse([12, 8, 22, 15], fill=side)      # broad head
    d.line([(6, 9), (18, 9)], fill=back)        # dark back
    d.line([(5, 15), (19, 15)], fill=belly)     # pale belly
    d.line([(6, 14), (20, 14)], fill=belly)
    # fins
    d.polygon([(9, 8), (12, 5), (13, 8)], fill=fin)   # dorsal
    d.polygon([(10, 16), (12, 18 - (wag if f % 2 else 0)), (14, 16)], fill=fin)  # pectoral
    # mouth line + eye
    d.line([(19, 12), (22, 12)], fill=dark)
    d.point((19, 10), fill=dark)
    # barbels (whiskers) trail from the mouth, drifting per frame
    bx = 22
    d.line([(bx, 12), (bx + 1, 9 - wag)], fill=belly)
    d.line([(bx, 13), (bx + 1, 16 + wag)], fill=belly)
    d.line([(20, 13), (18, 17 + wag)], fill=belly)


# ---- barracuda: 40x40, body 36x8, barred silver, teeth ----------------------
def barracuda(d, img, f):
    silver = (172, 184, 194)
    steel = (120, 134, 148)
    belly = (214, 222, 228)
    bar = (70, 84, 100)
    fin = (96, 108, 122)
    dark = (18, 22, 28)
    tooth = (245, 245, 240)
    y0 = 16
    wag = [0, 1, 0, -1][f]
    # forked tail
    d.polygon([(1, y0 - 4 + wag), (6, y0 + 3), (1, y0 + 10 + wag)], fill=fin)
    d.polygon([(2, y0 - 1 + wag), (6, y0 + 3), (2, y0 + 7 + wag)], fill=steel)
    # torpedo body: thin at tail, deepest at mid, pointed jaw to the right
    d.polygon([(5, y0 + 2), (14, y0 - 1), (27, y0 - 1), (36, y0 + 2), (38, y0 + 3), (36, y0 + 5), (27, y0 + 7), (14, y0 + 7), (5, y0 + 4)], fill=silver)
    d.line([(8, y0 + 6), (33, y0 + 6)], fill=belly)
    d.line([(10, y0), (30, y0)], fill=steel)
    # dark bars along the flank
    for bx in range(11, 30, 4):
        d.line([(bx, y0), (bx, y0 + 3)], fill=bar)
    # fins: two dorsals, a small anal fin
    d.polygon([(14, y0 - 1), (16, y0 - 4), (18, y0 - 1)], fill=fin)
    d.polygon([(24, y0 - 1), (26, y0 - 3), (28, y0 - 1)], fill=fin)
    d.polygon([(24, y0 + 7), (26, y0 + 9), (28, y0 + 7)], fill=fin)
    # jaw: underslung lower jaw, teeth, eye
    d.line([(31, y0 + 4), (38, y0 + 4)], fill=dark)
    for tx in (32, 34, 36):
        d.point((tx, y0 + 3), fill=tooth)
        d.point((tx + 1, y0 + 5), fill=tooth)
    d.point((33, y0 + 1), fill=dark)
    d.point((34, y0 + 1), fill=(240, 200, 60))


def main():
    for name, cell, fn in (("tropical_fish", 12, tropical), ("catfish", 24, catfish), ("barracuda", 40, barracuda)):
        img = strip(cell, fn)
        outline(img)
        img.save(OUT / (name + ".png"))
        print("wrote", name + ".png", img.size)


if __name__ == "__main__":
    main()

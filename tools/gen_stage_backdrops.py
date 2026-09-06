"""Parallax backdrop strips for the deep stages (user request 2026-09-06).

The Dry / Shallows keep the user's painted city plates (assets/backgrounds/
city0N.png, 704 px wide). Below them each stage gets its own strip set here:
five 704-px-wide variants per stage, drawn as chunky 2-px pixel art (a 352-px
canvas scaled x2 NEAREST so the grain matches the plates) and hung by
scripts/world/backdrop.gd from the top of that stage's gap - the strip's
top ~12 rows fade in from transparent, so the fade IS the middle ground.

  cold   - murky teal-grey water, a far skyline in cold fog, thermocline
           haze bands, drifting silt
  dark   - near-black navy, silhouettes barely there, bioluminescent specks
  crush  - black with a dull red pressure haze at the bottom, leaning and
           broken towers, vent bubble columns, a rubble floor

Every variant keeps its first/last 12 canvas px building-free, so plates of
one stage join on fog alone (no seam covers needed). Heights come from the
band rows in scripts/constants.gd / CityGen (mirrored in STAGES below; a
strip a little taller than its band is simply overlapped by the next one).

Run from the repo root:  python tools/gen_stage_backdrops.py   (deterministic)
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "backgrounds"
W = 352            # canvas px (x2 -> 704, the plate width)
CELL = 8           # world px per cell
GAP_ROWS = 12
VARIANTS = 5
EDGE = 12          # building-free canvas px at either edge (seam-safe)

# Stage rows (world rows, gaps spliced in): each strip starts at its gap's
# first row and runs to the next gap's first row (the crush to the ground).
WATERLINE = 104
FLOOR_DEPTHS = [80, 240, 440]
GROUND_BUILD = 720
gaps = [WATERLINE + d + i * GAP_ROWS for i, d in enumerate(FLOOR_DEPTHS)]
ground = GROUND_BUILD + 3 * GAP_ROWS
STAGES = {
    "cold": (gaps[0], gaps[1]),
    "dark": (gaps[1], gaps[2]),
    "crush": (gaps[2], ground),
}

PAL = {
    "cold": {
        "top": (34, 70, 88), "bot": (16, 38, 58),
        "far": (26, 56, 72), "mid": (20, 46, 62), "near": (14, 34, 50),
        "window": (72, 116, 134), "haze": (52, 92, 110), "silt": (90, 130, 146),
    },
    "dark": {
        "top": (10, 17, 30), "bot": (3, 6, 12),
        "far": (8, 14, 25), "mid": (6, 11, 20), "near": (4, 8, 15),
        "window": (18, 40, 48), "glow": [(40, 170, 160), (60, 150, 90), (120, 90, 180)],
    },
    "crush": {
        "top": (7, 5, 12), "bot": (22, 5, 8),
        "far": (12, 8, 16), "mid": (9, 6, 12), "near": (5, 3, 8),
        "vent": (60, 24, 24), "bubble": (70, 60, 72), "ember": (150, 50, 30), "rubble": (14, 9, 12),
    },
}


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def gradient(img, top, bot, h):
    d = ImageDraw.Draw(img)
    for y in range(h):
        d.line([(0, y), (W, y)], fill=(*lerp(top, bot, y / max(1, h - 1)), 255))


def wrap_rect(d, x, y, w, h, c):
    """Rectangle with horizontal wrap so silhouettes tile; clipped to the seam-safe band."""
    x0 = max(x, EDGE)
    x1 = min(x + w, W - EDGE)
    if x1 > x0:
        d.rectangle([x0, y, x1 - 1, y + h - 1], fill=(*c, 255))


def skyline(d, rng, h, colour, base_y, hmin, hmax, wmin, wmax, gap, windows=None, win_p=0.0, lean=0.0):
    """A row of block towers standing on base_y, tops between base_y-hmax and base_y-hmin."""
    x = EDGE + rng.randint(0, 6)
    while x < W - EDGE:
        w = rng.randint(wmin, wmax)
        th = rng.randint(hmin, hmax)
        top = base_y - th
        if lean and rng.random() < lean:
            # a broken tower: leaning body (drifts a px every 6 rows), crown snapped off
            step = rng.choice([-1, 1])
            snapped = rng.randint(0, 8)
            for k in range(snapped, th, 3):
                wrap_rect(d, x + step * (k // 6), top + k, w - (2 if k < snapped + 6 else 0), 3, colour)
        else:
            wrap_rect(d, x, top, w, th, colour)
            if rng.random() < 0.5:  # a roof box / stack
                bw = max(2, w // 3)
                wrap_rect(d, x + rng.randint(0, max(0, w - bw)), top - rng.randint(2, 5), bw, 6, colour)
        if windows is not None and win_p > 0:
            for wy in range(top + 3, base_y - 2, 4):
                for wx in range(x + 2, x + w - 2, 4):
                    if rng.random() < win_p:
                        wrap_rect(d, wx, wy, 2, 2, windows)
        x += w + rng.randint(gap[0], gap[1])


def fade_top(img, rows_px):
    """Alpha ramp over the first rows_px so the gap shows the plate above."""
    px = img.load()
    for y in range(rows_px):
        a = int(255 * (y / rows_px) ** 1.4)
        for x in range(W):
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, a)


def cold(rng, h, p):
    img = Image.new("RGBA", (W, h))
    gradient(img, p["top"], p["bot"], h)
    d = ImageDraw.Draw(img)
    # thermocline haze bands
    for _ in range(rng.randint(4, 7)):
        y = rng.randint(h // 6, h - 10)
        bh = rng.randint(2, 5)
        for k in range(bh):
            t = 0.35 * (1 - abs(k - bh / 2) / (bh / 2 + 0.5))
            c = lerp(lerp(p["top"], p["bot"], y / h), p["haze"], t)
            d.line([(0, y + k), (W, y + k)], fill=(*c, 255))
    base = h - rng.randint(6, 14)
    skyline(d, rng, h, p["far"], base - 30, int(h * 0.55), int(h * 0.92), 18, 40, (2, 9))
    skyline(d, rng, h, p["mid"], base - 10, int(h * 0.35), int(h * 0.75), 14, 34, (3, 10), p["window"], 0.04)
    skyline(d, rng, h, p["near"], base, int(h * 0.2), int(h * 0.55), 12, 28, (4, 12), p["window"], 0.06)
    wrap_rect(d, 0, base, W, h - base, p["near"])
    # drifting silt
    px = img.load()
    for _ in range(int(W * h * 0.004)):
        x, y = rng.randrange(W), rng.randrange(h)
        c = lerp(px[x, y][:3], p["silt"], rng.uniform(0.25, 0.6))
        px[x, y] = (*c, 255)
    fade_top(img, GAP_ROWS * CELL // 2)
    return img


def dark(rng, h, p):
    img = Image.new("RGBA", (W, h))
    gradient(img, p["top"], p["bot"], h)
    d = ImageDraw.Draw(img)
    base = h - rng.randint(4, 10)
    skyline(d, rng, h, p["far"], base - 26, int(h * 0.55), int(h * 0.92), 16, 44, (2, 8))
    skyline(d, rng, h, p["mid"], base - 8, int(h * 0.35), int(h * 0.75), 14, 36, (3, 9), p["window"], 0.015)
    skyline(d, rng, h, p["near"], base, int(h * 0.2), int(h * 0.55), 12, 30, (4, 12), p["window"], 0.025)
    wrap_rect(d, 0, base, W, h - base, p["near"])
    # bioluminescence: sparse specks, a few soft blooms
    px = img.load()
    for _ in range(rng.randint(70, 110)):
        x, y = rng.randrange(W), rng.randrange(GAP_ROWS * CELL // 2, h)
        c = rng.choice(p["glow"])
        px[x, y] = (*lerp(px[x, y][:3], c, 0.8), 255)
        if rng.random() < 0.35:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = (x + dx) % W, y + dy
                if 0 <= yy < h:
                    px[xx, yy] = (*lerp(px[xx, yy][:3], c, 0.3), 255)
    fade_top(img, GAP_ROWS * CELL // 2)
    return img


def crush(rng, h, p):
    img = Image.new("RGBA", (W, h))
    gradient(img, p["top"], p["bot"], h)
    d = ImageDraw.Draw(img)
    base = h - rng.randint(8, 14)
    skyline(d, rng, h, p["far"], base - 26, int(h * 0.5), int(h * 0.9), 16, 40, (2, 8), lean=0.35)
    skyline(d, rng, h, p["mid"], base - 8, int(h * 0.3), int(h * 0.7), 14, 34, (3, 9), lean=0.45)
    skyline(d, rng, h, p["near"], base, int(h * 0.15), int(h * 0.5), 12, 30, (4, 12), lean=0.5)
    # rubble floor: a jagged mound line
    for x in range(W):
        mound = int(4 + 3 * abs(((x * 7) % 23) - 11) / 11 + rng.random() * 2)
        d.line([(x, base - mound), (x, h)], fill=(*p["rubble"], 255))
    # vents: an ember at the floor and a wobbling bubble column above it
    for _ in range(rng.randint(3, 6)):
        vx = rng.randint(EDGE + 4, W - EDGE - 4)
        wrap_rect(d, vx - 1, base - 3, 3, 3, p["ember"])
        for k in range(rng.randint(30, 90)):
            y = base - 4 - k * 2
            if y < GAP_ROWS * CELL // 2:
                break
            x = vx + int(2.5 * ((k * 0.7) % 2 - 1)) + rng.randint(-1, 1)
            if rng.random() < 0.6:
                d.point((x % W, y), fill=(*p["bubble"], 255))
    # pressure haze: dull red pooling in the bottom third
    px = img.load()
    for y in range(h * 2 // 3, h):
        t = (y - h * 2 // 3) / (h / 3) * 0.35
        for x in range(W):
            px[x, y] = (*lerp(px[x, y][:3], p["vent"], t * (0.6 + 0.4 * rng.random())), 255)
    fade_top(img, GAP_ROWS * CELL // 2)
    return img


DRAW = {"cold": cold, "dark": dark, "crush": crush}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (r0, r1) in STAGES.items():
        h = (r1 - r0 + 4) * CELL // 2  # canvas px (x2 later); +4 rows of overlap under the next strip
        for k in range(VARIANTS):
            rng = random.Random(hash((name, k)) & 0xFFFF if False else (k + 1) * 977 + len(name) * 13)
            img = DRAW[name](rng, h, PAL[name])
            img = img.resize((W * 2, h * 2), Image.NEAREST)
            path = OUT / ("%s%02d.png" % (name, k + 1))
            img.save(path)
            print("wrote", path.name, img.size)


if __name__ == "__main__":
    main()

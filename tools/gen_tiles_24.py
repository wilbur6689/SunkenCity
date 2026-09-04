"""24x24 tile atlas for the 8 px cell grid (2026-09-04, half-size blocks).

Same materials, ramps, rows and variant counts as gen_placeholder_art.py /
gen_hd_tiles.py, drawn natively at 24x24 so each 8 px cell carries a complete
texture with 9x the texels. StructureRenderer draws the layers at 1/3 scale
(TILE_ART_SCALE), which is 1 texel per monitor pixel at the default zoom
(3.0) on a 1080p screen.

Outputs:
  assets/tiles/placeholder_blocks_24.png   120x216 atlas (5 variants x 9 rows)
  assets/tiles/placeholder_blocks_24.tres  TileSet: 24px tiles, physics +-12

Run from the repo root:  python tools/gen_tiles_24.py
Deterministic (same seed scheme as the other atlases).
"""
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
T = 24
VARIANTS = 5

RAMPS = {
    "stone":   ((30, 28, 26), [(66, 64, 62), (90, 88, 86), (114, 112, 110), (138, 136, 134)], (166, 164, 162)),
    "wood":    ((40, 26, 14), [(94, 62, 38), (120, 82, 50), (146, 104, 66), (168, 126, 86)], (192, 152, 108)),
    "metal":   ((22, 28, 36), [(60, 70, 82), (80, 92, 106), (100, 114, 130), (120, 136, 152)], (154, 170, 186)),
    "plastic": ((20, 44, 32), [(54, 100, 74), (70, 126, 92), (90, 150, 110), (112, 172, 130)], (142, 196, 156)),
}
ROWS = ["stone", "wood", "metal", "plastic", "water", "ladder", "rope", "void", "woodwall"]
SOLID_ROWS = {0, 1, 2, 3, 7}  # rows carrying physics in the tres


class Tile:
    """TxT RGBA buffer with torus addressing so patterns tile seamlessly."""

    def __init__(self, fill=(0, 0, 0, 0)):
        self.px = [[fill for _ in range(T)] for _ in range(T)]

    def set(self, x, y, c):
        if len(c) == 3:
            c = (*c, 255)
        self.px[y % T][x % T] = c

    def fill(self, c):
        for y in range(T):
            for x in range(T):
                self.set(x, y, c)

    def blit(self, img, ox, oy):
        for y in range(T):
            for x in range(T):
                img.putpixel((ox + x, oy + y), self.px[y][x])


def stone(rng, o, t, h):
    """Cobble: a 4x4 field of 5-6px pebbles (~2 world px each, the old look)."""
    tile = Tile()
    tile.fill(o)
    for gy in range(T // 6):
        for gx in range(T // 6):
            cx = gx * 6 + 3 + (3 if gy % 2 else 0) + rng.randint(-1, 1)
            cy = gy * 6 + 3 + rng.randint(-1, 0)
            rx = rng.uniform(2.3, 3.0)
            ry = rng.uniform(2.0, 2.6)
            base = rng.choice([t[1], t[2], t[2], t[3]])
            cells = []
            for dy in range(-3, 4):
                for dx in range(-3, 4):
                    if (dx / (rx + 0.5)) ** 2 + (dy / (ry + 0.5)) ** 2 <= 1.0:
                        cells.append((dx, dy))
            for dx, dy in cells:
                tile.set(cx + dx, cy + dy, base)
            tl = min(cells, key=lambda c: (c[0] + c[1], c[1]))
            br = max(cells, key=lambda c: (c[0] + c[1], c[1]))
            tile.set(cx + tl[0], cy + tl[1], h if base == t[3] else t[t.index(base) + 1])
            tile.set(cx + br[0], cy + br[1], t[max(t.index(base) - 1, 0)])
    return tile


def wood(rng, o, t, h):
    """Four-ish boards: seam, light top edge, grain streaks, knots, nail heads."""
    tile = Tile()
    layouts = [[8, 8, 8], [7, 9, 8], [8, 7, 9], [9, 8, 7], [8, 9, 7]]
    heights = layouts[rng.randint(0, len(layouts) - 1)]
    y = 0
    for i, hgt in enumerate(heights):
        for x in range(T):
            tile.set(x, y, o)                 # seam
            tile.set(x, y + 1, t[3])          # light top edge
            for yy in range(y + 2, y + hgt):
                tile.set(x, yy, t[2])
        for _ in range(rng.randint(3, 5)):
            gx = rng.randint(0, T - 1)
            gy = rng.randint(y + 2, y + hgt - 1) if hgt > 2 else y + 1
            tone = rng.choice([t[1], t[3]])
            for k in range(rng.randint(2, 5)):
                tile.set(gx + k, gy, tone)
        if rng.random() < 0.4 and hgt > 3:
            kx, ky = rng.randint(2, T - 3), y + rng.randint(2, hgt - 2)
            tile.set(kx, ky, t[0]); tile.set(kx + 1, ky, t[1])
            if ky + 1 < y + hgt:
                tile.set(kx, ky + 1, t[1])
        ex = (i * 7 + rng.randint(0, 4)) % T
        for yy in range(y, y + hgt):
            tile.set(ex, yy, o)
        tile.set(ex + 1, y + 1, h)
        tile.set((ex + 3) % T, y + hgt // 2, t[0])  # nail
        y += hgt
    return tile


def metal(rng, o, t, h):
    """Riveted plates: 12/24 px panels, bevels, corner rivets, scratches."""
    tile = Tile()
    tile.fill(t[2])
    pw, ph = rng.choice([(12, 12), (24, 12), (12, 24), (12, 12), (24, 8)])
    for py in range(0, T, ph):
        for px_ in range(0, T, pw):
            for x in range(px_, px_ + pw):
                tile.set(x, py, o)
                tile.set(x, py + 1, t[3])
                tile.set(x, py + ph - 1, t[1])
            for y in range(py, py + ph):
                tile.set(px_, y, o)
                tile.set(px_ + 1, y, t[3])
                tile.set(px_ + pw - 1, y, t[1])
            for rx_, ry_ in ((px_ + 3, py + 3), (px_ + pw - 4, py + 3),
                             (px_ + 3, py + ph - 4), (px_ + pw - 4, py + ph - 4)):
                if ph >= 8 and pw >= 8:
                    tile.set(rx_, ry_, h)
                    tile.set(rx_ + 1, ry_ + 1, o)
    for _ in range(rng.randint(2, 4)):
        sx, sy = rng.randint(3, T - 8), rng.randint(3, T - 4)
        tone = rng.choice([t[1], t[3]])
        for k in range(rng.randint(3, 6)):
            tile.set(sx + k, sy, tone)
    return tile


def plastic(rng, o, t, h):
    """Moulded plastic: 1px bevel, a specular streak, soft blemishes."""
    tile = Tile()
    tile.fill(t[2])
    for i in range(T):
        tile.set(i, 0, t[3]); tile.set(0, i, t[3])
        tile.set(i, T - 1, t[1]); tile.set(T - 1, i, t[1])
        if i < 5:
            tile.set(i, 1, t[3])
    tile.set(0, 0, h); tile.set(1, 0, h); tile.set(0, 1, h)
    tile.set(T - 1, T - 1, o)
    sx = rng.randint(4, 13)
    for k in range(rng.randint(4, 7)):
        tile.set(sx + k, 4 + k, t[3])
    tile.set(sx, 4, h); tile.set(sx + 1, 5, h)
    for _ in range(rng.randint(3, 6)):
        bx, by = rng.randint(3, T - 4), rng.randint(7, T - 3)
        tone = rng.choice([t[1], t[3]])
        tile.set(bx, by, tone); tile.set(bx + 1, by, tone)
        if rng.random() < 0.5:
            tile.set(bx, by + 1, tone)
    return tile


def water(rng, _o, _t, _h):
    base = (60, 120, 200, 150)
    light = (104, 170, 232, 170)
    dark = (44, 92, 170, 150)
    tile = Tile()
    tile.fill(base)
    for _ in range(rng.randint(4, 7)):
        x, y = rng.randint(0, T - 1), rng.randint(0, T - 1)
        for k in range(rng.randint(3, 6)):
            tile.set(x + k, y, light)
    for _ in range(rng.randint(4, 7)):
        tile.set(rng.randint(0, T - 1), rng.randint(0, T - 1), dark)
    return tile


def ladder(rng, o, t, h):
    """Rails at x 4-6 and 17-19, three rungs; two side-by-side cells read as
    one wide ladder with a middle pair of rails."""
    tile = Tile()
    for y in range(T):
        for x in (4, 5, 6, 17, 18, 19):
            tile.set(x, y, t[1] if x in (4, 5, 17, 18) else t[2])
    for ry in (3, 11, 19):
        for x in range(4, 20):
            tile.set(x, ry, t[3]); tile.set(x, ry + 1, t[2]); tile.set(x, ry + 2, o)
        tile.set(4, ry, h); tile.set(5, ry, h)
    return tile


def rope(rng, o, t, h):
    tile = Tile()
    for y in range(T):
        tw = (y // 2) % 2  # braid twist every 2 rows
        a, b = (t[3], t[2]) if tw == 0 else (t[2], t[3])
        tile.set(10, y, t[1]); tile.set(11, y, a); tile.set(12, y, b); tile.set(13, y, t[1])
    ky = 7 + (rng.randint(0, 1) * 5 if rng.random() < 0.6 else 0)
    for y in range(ky, ky + 5):
        for x in range(8, 16):
            tile.set(x, y, t[1] if y not in (ky + 2,) else t[2])
    tile.set(8, ky, o); tile.set(15, ky + 4, o)
    return tile


def woodwall(rng, o, t, h):
    """Dark vertical panelling: 5-8px boards, deep seams, long grain."""
    tile = Tile()
    layouts = [[8, 8, 8], [7, 10, 7], [10, 7, 7], [8, 7, 9], [7, 9, 8]]
    widths = layouts[rng.randint(0, len(layouts) - 1)]
    x = 0
    for i, wd in enumerate(widths):
        for y in range(T):
            tile.set(x, y, o)
            tile.set(x + 1, y, t[1])
            for xx in range(x + 2, x + wd):
                tile.set(xx, y, t[0])
        for _ in range(rng.randint(3, 5)):
            gy = rng.randint(0, T - 5)
            gx = rng.randint(x + 2, x + wd - 1) if wd > 2 else x + 1
            for k in range(rng.randint(2, 4)):
                tile.set(gx, gy + k, o)
        ey = (i * 7 + rng.randint(0, 5)) % T
        tile.set(x + 1, ey, h)
        x += wd
    return tile


def void(rng, _o, _t, _h):
    tile = Tile((6, 6, 9, 255))
    for _ in range(6):
        tile.set(rng.randrange(T), rng.randrange(T), (12, 12, 16, 255))
    return tile


RECIPES = {"stone": stone, "wood": wood, "metal": metal, "plastic": plastic,
           "water": water, "ladder": ladder, "rope": rope, "void": void,
           "woodwall": woodwall}


def build_atlas():
    img = Image.new("RGBA", (T * VARIANTS, T * len(ROWS)), (0, 0, 0, 0))
    for row, name in enumerate(ROWS):
        ramp = RAMPS.get(name, RAMPS["wood"])
        for col in range(VARIANTS):
            rng = random.Random(1000 * row + col + 7)
            tile = RECIPES[name](rng, *ramp)
            tile.blit(img, col * T, row * T)
    out = ROOT / "assets" / "tiles" / "placeholder_blocks_24.png"
    img.save(out)
    print("wrote", out, img.size)


def build_tres():
    half = T // 2
    lines = [
        '[gd_resource type="TileSet" load_steps=3 format=3]',
        "",
        '[ext_resource type="Texture2D" path="res://assets/tiles/placeholder_blocks_24.png" id="1_blocks"]',
        "",
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_blocks"]',
        'texture = ExtResource("1_blocks")',
        "texture_region_size = Vector2i(%d, %d)" % (T, T),
    ]
    poly = "PackedVector2Array(-%d, -%d, %d, -%d, %d, %d, -%d, %d)" % (half, half, half, half, half, half, half, half)
    for row in range(len(ROWS)):
        for col in range(VARIANTS):
            lines.append("%d:%d/0 = 0" % (col, row))
            if row in SOLID_ROWS:
                lines.append("%d:%d/0/physics_layer_0/polygon_0/points = %s" % (col, row, poly))
    lines += [
        "",
        "[resource]",
        "tile_size = Vector2i(%d, %d)" % (T, T),
        "physics_layer_0/collision_layer = 1",
        "physics_layer_0/collision_mask = 1",
        'sources/0 = SubResource("TileSetAtlasSource_blocks")',
        "",
    ]
    out = ROOT / "assets" / "tiles" / "placeholder_blocks_24.tres"
    out.write_text("\n".join(lines), encoding="utf-8")
    print("wrote", out)


if __name__ == "__main__":
    build_atlas()
    build_tres()

"""Resolution-doubling prototype (2026-09-02): 32x32 tile atlas.

Same materials, ramps, rows and variant counts as gen_placeholder_art.py, but
each tile is 32x32 with genuinely finer features (more pebbles, more boards,
finer grain, denser plating) - NOT an upscale. Rendered by StructureRenderer
at 0.5 scale onto the unchanged 16px block grid, so each block carries 4x the
texels on the doubled 1280x720 canvas.

Outputs:
  assets/tiles/placeholder_blocks_hd.png   160x288 atlas (5 variants x 9 rows)
  assets/tiles/placeholder_blocks_hd.tres  TileSet: 32px tiles, physics +-16

Run from the repo root:  python tools/gen_hd_tiles.py
Deterministic (same seed scheme as the 16px atlas).
"""
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
T = 32
VARIANTS = 5

RAMPS = {
    "stone":   ((30, 28, 26), [(66, 64, 62), (90, 88, 86), (114, 112, 110), (138, 136, 134)], (166, 164, 162)),
    "wood":    ((40, 26, 14), [(94, 62, 38), (120, 82, 50), (146, 104, 66), (168, 126, 86)], (192, 152, 108)),
    "metal":   ((22, 28, 36), [(60, 70, 82), (80, 92, 106), (100, 114, 130), (120, 136, 152)], (154, 170, 186)),
    "plastic": ((20, 44, 32), [(54, 100, 74), (70, 126, 92), (90, 150, 110), (112, 172, 130)], (142, 196, 156)),
}
ROWS = ["stone", "wood", "metal", "plastic", "water", "ladder", "rope", "void", "woodwall"]
SOLID_ROWS = {0, 1, 2, 3, 7}  # rows carrying physics in the tres (matches the 16px set)


class Tile:
    """32x32 RGBA buffer with torus addressing so patterns tile seamlessly."""

    def __init__(self, fill=(0, 0, 0, 0)):
        self.px = [[fill for _ in range(T)] for _ in range(T)]

    def set(self, x, y, c):
        if len(c) == 3:
            c = (*c, 255)
        self.px[y % T][x % T] = c

    def get(self, x, y):
        return self.px[y % T][x % T]

    def fill(self, c):
        for y in range(T):
            for x in range(T):
                self.set(x, y, c)

    def blit(self, img, ox, oy):
        for y in range(T):
            for x in range(T):
                img.putpixel((ox + x, oy + y), self.px[y][x])


def stone(rng, o, t, h):
    """Finer cobble: an 8x8 field of 3-4px pebbles (4x the 16px tile's count)."""
    tile = Tile()
    tile.fill(o)
    for gy in range(T // 4):
        for gx in range(T // 4):
            cx = gx * 4 + 2 + (2 if gy % 2 else 0) + rng.randint(-1, 1)
            cy = gy * 4 + 2 + rng.randint(-1, 0)
            rx = rng.uniform(1.5, 2.1)
            ry = rng.uniform(1.3, 1.8)
            base = rng.choice([t[1], t[2], t[2], t[3]])
            cells = []
            for dy in range(-2, 3):
                for dx in range(-2, 3):
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
    """Six-ish boards with finer grain: long dashes, knots, nail heads."""
    tile = Tile()
    layouts = [[6, 5, 6, 5, 5, 5], [5, 6, 5, 6, 5, 5], [6, 6, 5, 5, 6, 4],
               [5, 5, 6, 5, 6, 5], [4, 6, 6, 5, 5, 6]]
    heights = layouts[rng.randint(0, len(layouts) - 1)]
    y = 0
    for i, hgt in enumerate(heights):
        for x in range(T):
            tile.set(x, y, o)                 # seam
            tile.set(x, y + 1, t[3])          # light top edge
            for yy in range(y + 2, y + hgt):
                tile.set(x, yy, t[2])
        # long grain streaks
        for _ in range(rng.randint(4, 7)):
            gx = rng.randint(0, T - 1)
            gy = rng.randint(y + 2, y + hgt - 1) if hgt > 2 else y + 1
            tone = rng.choice([t[1], t[3]])
            for k in range(rng.randint(2, 6)):
                tile.set(gx + k, gy, tone)
        # a knot on some boards
        if rng.random() < 0.4 and hgt > 3:
            kx, ky = rng.randint(2, T - 3), y + rng.randint(2, hgt - 2)
            tile.set(kx, ky, t[0]); tile.set(kx + 1, ky, t[1])
            tile.set(kx, ky + 1, t[1]) if ky + 1 < y + hgt else None
        # staggered board end + nails beside it
        ex = (i * 9 + rng.randint(0, 5)) % T
        for yy in range(y, y + hgt):
            tile.set(ex, yy, o)
        tile.set(ex + 1, y + 1, h)
        tile.set((ex + 3) % T, y + hgt // 2, t[0])  # nail
        y += hgt
    return tile


def metal(rng, o, t, h):
    """Plates at 4x density: 16/32px panels, bevels, corner rivets, scratches."""
    tile = Tile()
    tile.fill(t[2])
    pw, ph = rng.choice([(16, 16), (32, 16), (16, 32), (16, 16), (32, 8)])
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
    for _ in range(rng.randint(2, 5)):
        sx, sy = rng.randint(3, T - 8), rng.randint(3, T - 4)
        tone = rng.choice([t[1], t[3]])
        for k in range(rng.randint(3, 7)):
            tile.set(sx + k, sy, tone)
    return tile


def plastic(rng, o, t, h):
    """Moulded plastic: 1px bevel, a long specular streak, soft blemishes."""
    tile = Tile()
    tile.fill(t[2])
    for i in range(T):
        tile.set(i, 0, t[3]); tile.set(0, i, t[3])
        tile.set(i, T - 1, t[1]); tile.set(T - 1, i, t[1])
        tile.set(i, 1, t[3]) if i < 6 else None
    tile.set(0, 0, h); tile.set(1, 0, h); tile.set(0, 1, h)
    tile.set(T - 1, T - 1, o)
    sx = rng.randint(5, 18)
    for k in range(rng.randint(5, 9)):
        tile.set(sx + k, 5 + k, t[3])
    tile.set(sx, 5, h); tile.set(sx + 1, 6, h)
    for _ in range(rng.randint(4, 8)):
        bx, by = rng.randint(3, T - 4), rng.randint(9, T - 3)
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
    for _ in range(rng.randint(5, 9)):
        x, y = rng.randint(0, T - 1), rng.randint(0, T - 1)
        for k in range(rng.randint(3, 7)):
            tile.set(x + k, y, light)
    for _ in range(rng.randint(5, 9)):
        tile.set(rng.randint(0, T - 1), rng.randint(0, T - 1), dark)
    return tile


def ladder(rng, o, t, h):
    tile = Tile()
    for y in range(T):
        for x in (6, 7, 8, 9, 22, 23, 24, 25):
            tile.set(x, y, t[1] if x in (6, 7, 22, 23) else t[2])
    for ry in (4, 14, 24):
        for x in range(6, 26):
            tile.set(x, ry, t[3]); tile.set(x, ry + 1, t[2]); tile.set(x, ry + 2, o)
        tile.set(6, ry, h); tile.set(7, ry, h)
    return tile


def rope(rng, o, t, h):
    tile = Tile()
    for y in range(T):
        tw = (y // 2) % 2  # braid twist every 2 rows
        a, b = (t[3], t[2]) if tw == 0 else (t[2], t[3])
        tile.set(14, y, t[1]); tile.set(15, y, a); tile.set(16, y, b); tile.set(17, y, t[1])
    ky = 10 + (rng.randint(0, 1) * 6 if rng.random() < 0.6 else 0)
    for y in range(ky, ky + 6):
        for x in range(12, 20):
            tile.set(x, y, t[1] if y not in (ky + 2, ky + 3) else t[2])
    tile.set(12, ky, o); tile.set(19, ky + 5, o)
    return tile


def woodwall(rng, o, t, h):
    """Dark vertical panelling, finer: 6-10px boards, deep seams, long grain."""
    tile = Tile()
    layouts = [[8, 8, 8, 8], [6, 10, 8, 8], [10, 8, 6, 8], [8, 6, 10, 8], [8, 8, 6, 10]]
    widths = layouts[rng.randint(0, len(layouts) - 1)]
    x = 0
    for i, wd in enumerate(widths):
        for y in range(T):
            tile.set(x, y, o)
            tile.set(x + 1, y, t[1])
            for xx in range(x + 2, x + wd):
                tile.set(xx, y, t[0])
        for _ in range(rng.randint(4, 7)):
            gy = rng.randint(0, T - 6)
            gx = rng.randint(x + 2, x + wd - 1) if wd > 2 else x + 1
            for k in range(rng.randint(2, 5)):
                tile.set(gx, gy + k, o)
        ey = (i * 9 + rng.randint(0, 6)) % T
        tile.set(x + 1, ey, h)
        x += wd
    return tile


def void(rng, _o, _t, _h):
    tile = Tile((6, 6, 9, 255))
    for _ in range(10):
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
    out = ROOT / "assets" / "tiles" / "placeholder_blocks_hd.png"
    img.save(out)
    print("wrote", out, img.size)


def build_tres():
    lines = [
        '[gd_resource type="TileSet" load_steps=3 format=3]',
        "",
        '[ext_resource type="Texture2D" path="res://assets/tiles/placeholder_blocks_hd.png" id="1_blocks"]',
        "",
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_blocks"]',
        'texture = ExtResource("1_blocks")',
        "texture_region_size = Vector2i(32, 32)",
    ]
    poly = "PackedVector2Array(-16, -16, 16, -16, 16, 16, -16, 16)"
    for row in range(len(ROWS)):
        for col in range(VARIANTS):
            lines.append("%d:%d/0 = 0" % (col, row))
            if row in SOLID_ROWS:
                lines.append("%d:%d/0/physics_layer_0/polygon_0/points = %s" % (col, row, poly))
    lines += [
        "",
        "[resource]",
        "tile_size = Vector2i(32, 32)",
        "physics_layer_0/collision_layer = 1",
        "physics_layer_0/collision_mask = 1",
        'sources/0 = SubResource("TileSetAtlasSource_blocks")',
        "",
    ]
    out = ROOT / "assets" / "tiles" / "placeholder_blocks_hd.tres"
    out.write_text("\n".join(lines), encoding="utf-8")
    print("wrote", out)


if __name__ == "__main__":
    build_atlas()
    build_tres()

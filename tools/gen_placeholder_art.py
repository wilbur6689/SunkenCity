"""Generate SunkenCity placeholder art in the Terraria-style spec (docs/technical/TileArt.md).

Outputs:
  assets/tiles/placeholder_blocks.png   80x112 atlas: rows = materials, columns = 5 pattern variants
  assets/sprites/player_placeholder.png 48x24 sheet: frame 0 standing (24px), frame 1 prone (compact)

Run from the repo root:  python tools/gen_placeholder_art.py
Deterministic (seeded per material/variant) so re-running produces identical files.
"""
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
T = 16
VARIANTS = 5

# Material ramps: outline, 4 body tones (~24 lum apart), highlight. Low saturation on purpose —
# the depth color grade (WS-29) supplies the mood tint.
RAMPS = {
    "stone":   ((30, 28, 26), [(66, 64, 62), (90, 88, 86), (114, 112, 110), (138, 136, 134)], (166, 164, 162)),
    "wood":    ((40, 26, 14), [(94, 62, 38), (120, 82, 50), (146, 104, 66), (168, 126, 86)], (192, 152, 108)),
    "metal":   ((22, 28, 36), [(60, 70, 82), (80, 92, 106), (100, 114, 130), (120, 136, 152)], (154, 170, 186)),
    "plastic": ((20, 44, 32), [(54, 100, 74), (70, 126, 92), (90, 150, 110), (112, 172, 130)], (142, 196, 156)),
}
ROWS = ["stone", "wood", "metal", "plastic", "water", "ladder", "rope"]


class Tile:
    """16x16 RGBA pixel buffer with torus addressing so patterns tile seamlessly."""

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


# --- Material recipes -----------------------------------------------------

def stone(rng, o, t, h):
    """Cobble: 3-4px pebbles on a jittered 4px grid, 1px dark gaps, lit top-left / shadow bottom-right."""
    tile = Tile()
    tile.fill(o)
    for gy in range(4):
        for gx in range(4):
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
            # shade: light top-left, dark bottom-right
            tl = min(cells, key=lambda c: (c[0] + c[1], c[1]))
            br = max(cells, key=lambda c: (c[0] + c[1], c[1]))
            tile.set(cx + tl[0], cy + tl[1], h if base == t[3] else t[t.index(base) + 1])
            tile.set(cx + br[0], cy + br[1], t[max(t.index(base) - 1, 0)])
    return tile


def wood(rng, o, t, h):
    """Planks: 3-5px boards, 1px dark seam, 1px light top edge, short grain dashes, staggered board ends."""
    tile = Tile()
    layouts = [[4, 4, 4, 4], [3, 4, 5, 4], [5, 3, 4, 4], [4, 5, 3, 4], [4, 3, 4, 5]]
    heights = layouts[rng.randint(0, len(layouts) - 1)]
    y = 0
    for i, hgt in enumerate(heights):
        for x in range(T):
            tile.set(x, y, o)                 # seam
            tile.set(x, y + 1, t[3])          # light top edge
            for yy in range(y + 2, y + hgt):
                tile.set(x, yy, t[2])
        # grain dashes
        for _ in range(rng.randint(3, 5)):
            gx = rng.randint(0, T - 1)
            gy = rng.randint(y + 2, y + hgt - 1) if hgt > 2 else y + 1
            tone = rng.choice([t[1], t[3]])
            for k in range(rng.randint(1, 3)):
                tile.set(gx + k, gy, tone)
        # board end: 1px vertical seam, staggered per board
        ex = (i * 5 + rng.randint(0, 3)) % T
        for yy in range(y, y + hgt):
            tile.set(ex, yy, o if yy > y else o)
        tile.set(ex + 1, y + 1, h)
        y += hgt
    return tile


def metal(rng, o, t, h):
    """Plates: 8x8 / 16x8 / 8x16 panels with dark seams, bevelled edges, corner rivets, a few scratches."""
    tile = Tile()
    tile.fill(t[2])
    pw, ph = rng.choice([(8, 8), (16, 8), (8, 16), (8, 8), (16, 4)])
    for py in range(0, T, ph):
        for px_ in range(0, T, pw):
            for x in range(px_, px_ + pw):
                tile.set(x, py, o)                  # top seam
                tile.set(x, py + 1, t[3])           # bevel light
                tile.set(x, py + ph - 1, t[1])      # bevel dark
            for y in range(py, py + ph):
                tile.set(px_, y, o)                 # left seam
                tile.set(px_ + 1, y, t[3])
                tile.set(px_ + pw - 1, y, t[1])
            # rivets: highlight + shadow pair, inset 2px from each corner
            for rx_, ry_ in ((px_ + 2, py + 2), (px_ + pw - 3, py + 2), (px_ + 2, py + ph - 3), (px_ + pw - 3, py + ph - 3)):
                if ph >= 6 and pw >= 6:
                    tile.set(rx_, ry_, h)
                    tile.set(rx_ + 1, ry_ + 1, o)
    for _ in range(rng.randint(1, 3)):
        sx, sy = rng.randint(2, 13), rng.randint(2, 13)
        tone = rng.choice([t[1], t[3]])
        for k in range(rng.randint(2, 4)):
            tile.set(sx + k, sy, tone)
    return tile


def plastic(rng, o, t, h):
    """Moulded plastic: smooth body, 1px bevel, a specular streak, sparse soft blemishes."""
    tile = Tile()
    tile.fill(t[2])
    for i in range(T):
        tile.set(i, 0, t[3]); tile.set(0, i, t[3])
        tile.set(i, T - 1, t[1]); tile.set(T - 1, i, t[1])
        tile.set(i, 1, t[3]) if i < 3 else None
    tile.set(0, 0, h); tile.set(1, 0, h); tile.set(0, 1, h)
    tile.set(T - 1, T - 1, o)
    # specular streak (diagonal)
    sx = rng.randint(3, 9)
    for k in range(rng.randint(2, 4)):
        tile.set(sx + k, 3 + k, t[3])
    tile.set(sx, 3, h)
    # blemishes
    for _ in range(rng.randint(2, 4)):
        bx, by = rng.randint(2, 12), rng.randint(5, 13)
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
    for _ in range(rng.randint(2, 4)):
        x, y = rng.randint(0, T - 1), rng.randint(0, T - 1)
        for k in range(rng.randint(2, 4)):
            tile.set(x + k, y, light)
    for _ in range(rng.randint(2, 4)):
        tile.set(rng.randint(0, T - 1), rng.randint(0, T - 1), dark)
    return tile


def ladder(rng, o, t, h):
    tile = Tile()
    for y in range(T):
        for x in (3, 4, 11, 12):
            tile.set(x, y, t[1] if x in (3, 11) else t[2])
    for ry in (2, 7, 12):
        for x in range(3, 13):
            tile.set(x, ry, t[3]); tile.set(x, ry + 1, o)
        tile.set(3, ry, h)
    return tile


def rope(rng, o, t, h):
    tile = Tile()
    for y in range(T):
        a, b = (t[3], t[2]) if y % 2 == 0 else (t[2], t[3])
        tile.set(7, y, a); tile.set(8, y, b)
    ky = 5 + (rng.randint(0, 1) * 3 if rng.random() < 0.6 else 0)
    for y in range(ky, ky + 3):
        for x in range(6, 10):
            tile.set(x, y, t[1] if y != ky + 1 else t[2])
    tile.set(6, ky, o); tile.set(9, ky + 2, o)
    return tile


RECIPES = {"stone": stone, "wood": wood, "metal": metal, "plastic": plastic,
           "water": water, "ladder": ladder, "rope": rope}


def build_atlas():
    img = Image.new("RGBA", (T * VARIANTS, T * len(ROWS)), (0, 0, 0, 0))
    for row, name in enumerate(ROWS):
        ramp = RAMPS.get(name, RAMPS["wood"])
        for col in range(VARIANTS):
            rng = random.Random(1000 * row + col + 7)
            tile = RECIPES[name](rng, *ramp)
            tile.blit(img, col * T, row * T)
    out = ROOT / "assets" / "tiles" / "placeholder_blocks.png"
    img.save(out)
    print("wrote", out, img.size)


# --- Character (WS-02/25 canon: 24px with hair, 21 without, 12x22 hitbox; 16px wide with gear) ---
# Palette sampled from docs/Examples/Character/MainCharacter.png (dark warm browns, slate trousers,
# navy scarf, khaki pack, orange canister), lifted slightly so it reads at 24px.
CHAR = {
    ".": (0, 0, 0, 0),
    "O": (24, 18, 14),      # outline
    "H": (74, 52, 34),      # hair dark
    "h": (104, 76, 50),     # hair light
    "G": (44, 38, 34),      # goggle strap
    "g": (96, 140, 160),    # goggle glass
    "L": (176, 214, 224),   # glass highlight
    "S": (198, 152, 114),   # skin
    "s": (160, 116, 84),    # skin shadow
    "E": (30, 40, 60),      # eye
    "N": (46, 58, 84),      # scarf navy
    "n": (70, 86, 118),     # scarf light
    "T": (122, 106, 72),    # shirt khaki
    "t": (94, 80, 54),      # shirt shadow
    "B": (142, 130, 98),    # backpack
    "b": (106, 96, 70),     # backpack shadow
    "C": (190, 98, 48),     # canister
    "P": (70, 86, 102),     # trousers slate
    "p": (50, 62, 76),      # trousers shadow
}

# Frame 0: standing, facing right, 16 wide x 24 tall (columns 4..19 of the 24px frame).
STAND = [
    "......OOOO......",
    ".....OhhhhO.....",
    "....OhhhHhhO....",
    "....OHGGGGGHO...",
    "....OHGgLgGHO...",
    "....OHHSSSSSO...",
    ".....OSSESSO....",
    ".....OSSSSSO....",
    "......OsssO.....",
    "....OONNNNNO....",
    "...ObONnNNNnO...",
    "..OBbOTTTTTO....",
    "..OBBbOTtTTO....",
    "..OBCBbTTTTO....",
    "..OBCBbTtTTSO...",
    "..OBBbOTTTTsO...",
    "...ObOtTTTTO....",
    "....OOPPPPPO....",
    ".....OPpPPPO....",
    ".....OPpOPPO....",
    ".....OPpO.PpO...",
    ".....OpO..OpO...",
    ".....OSO..OSO...",
    ".....OOO..OOO...",
]

# Frame 1: prone (crawl/swim), head to the right, 24 wide x 8 tall, bottom-aligned in the frame.
PRONE = [
    "........OBBBO..OOOO.....",
    ".......OBCBBbOOhhhhO....",
    "......OObBBbOHhhGGGhO...",
    "...OOOTTTTTTTNNHGgLgHO..",
    ".OOPPPtTTTTTTNNSSSESSO..",
    "OpPPPPPtTTTTTTNnSSSSSO..",
    "OpPPPPpOtTTTTTOOsSssO...",
    ".OOOOOO.OOOOOOO..OOOO...",
]


def build_character():
    img = Image.new("RGBA", (48, 24), (0, 0, 0, 0))
    for y, row in enumerate(STAND):
        for x, ch in enumerate(row):
            c = CHAR[ch]
            if len(c) == 3:
                img.putpixel((4 + x, y), (*c, 255))
    for y, row in enumerate(PRONE):
        for x, ch in enumerate(row):
            c = CHAR[ch]
            if len(c) == 3:
                img.putpixel((24 + x, 24 - len(PRONE) + y), (*c, 255))
    out = ROOT / "assets" / "sprites" / "player_placeholder.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)
    print("wrote", out, img.size)


if __name__ == "__main__":
    build_atlas()
    build_character()

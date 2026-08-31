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


# --- Item icons, object sprites, light texture (M1) --------------------------------------------
from PIL import ImageDraw  # noqa: E402

OUT = (24, 18, 14)
WHITE = (226, 226, 220)
RED = (190, 60, 50)
ORANGE = (220, 130, 50)
BLUE = (90, 140, 190)
PURPLE = (150, 90, 190)
GREEN = (110, 210, 120)


def _ramp(name):
    o, t, h = RAMPS[name]
    return o, t, h


def _box(d, x0, y0, x1, y1, ramp, bevel=True):
    """Filled rect with outline and a 1px light top/left, dark bottom/right bevel."""
    o, t, h = ramp
    d.rectangle([x0, y0, x1, y1], fill=t[2], outline=o)
    if bevel and x1 - x0 > 2 and y1 - y0 > 2:
        d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=t[3])
        d.line([x0 + 1, y0 + 1, x0 + 1, y1 - 1], fill=t[3])
        d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=t[1])
        d.line([x1 - 1, y0 + 1, x1 - 1, y1 - 1], fill=t[1])


def _blob(d, rng, ramp, cx, cy, r):
    o, t, h = ramp
    pts = []
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r + rng.randint(0, 2):
                pts.append((cx + dx, cy + dy))
    for p in pts:
        d.point(p, fill=t[2])
    for p in pts:
        x, y = p
        if (x - 1, y) not in pts or (x, y - 1) not in pts:
            d.point(p, fill=t[3])
        if (x + 1, y) not in pts or (x, y + 1) not in pts:
            d.point(p, fill=t[1])
    for p in pts:
        x, y = p
        if any(q not in pts for q in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
            d.point(p, fill=o)


ICONS = {
    # row 0: materials
    (0, 0): ("blob", "wood"), (1, 0): ("blob", "metal"), (2, 0): ("blob", "plastic"),
    (3, 0): ("cloth", None), (4, 0): ("blob", "stone"), (5, 0): ("ingot", None),
    # row 1: tools
    (0, 1): ("pry", None), (1, 1): ("knife", "scrap"), (2, 1): ("hammer", None), (3, 1): ("knife", "iron"),
    # row 2: consumables / schematic
    (0, 2): ("bandage", None), (1, 2): ("can", None), (2, 2): ("glowstick", None), (3, 2): ("paper", None),
    (4, 2): ("shirt", None),
}


def _draw_icon(d, kind, arg, ox, oy, rng):
    if kind == "blob":
        _blob(d, rng, _ramp(arg), ox + 8, oy + 8, 5)
    elif kind == "cloth":
        d.rectangle([ox + 3, oy + 5, ox + 12, oy + 12], fill=(200, 190, 170), outline=OUT)
        d.line([ox + 4, oy + 8, ox + 11, oy + 8], fill=(170, 160, 140))
        d.rectangle([ox + 5, oy + 3, ox + 10, oy + 5], fill=(200, 190, 170), outline=OUT)
    elif kind == "ingot":
        d.polygon([(ox + 3, oy + 11), (ox + 5, oy + 6), (ox + 12, oy + 6), (ox + 14, oy + 11)], fill=(150, 150, 158), outline=OUT)
        d.line([ox + 6, oy + 7, ox + 11, oy + 7], fill=(200, 200, 208))
    elif kind == "pry":
        d.line([ox + 3, oy + 13, ox + 12, oy + 4], fill=(120, 130, 140), width=2)
        d.line([ox + 12, oy + 4, ox + 13, oy + 7], fill=(120, 130, 140), width=2)
        d.line([ox + 3, oy + 13, ox + 12, oy + 4], fill=(170, 180, 190))
        d.point((ox + 3, oy + 13), fill=OUT)
    elif kind == "knife":
        blade = (200, 205, 215) if arg == "scrap" else (170, 190, 215)
        d.polygon([(ox + 3, oy + 12), (ox + 11, oy + 4), (ox + 13, oy + 6), (ox + 6, oy + 13)], fill=blade, outline=OUT)
        d.rectangle([ox + 2, oy + 11, ox + 5, oy + 14], fill=(110, 76, 48), outline=OUT)
    elif kind == "hammer":
        d.rectangle([ox + 7, oy + 8, ox + 8, oy + 14], fill=(140, 100, 60), outline=OUT)
        d.rectangle([ox + 4, oy + 3, ox + 11, oy + 7], fill=(120, 130, 140), outline=OUT)
        d.line([ox + 5, oy + 4, ox + 10, oy + 4], fill=(170, 180, 190))
    elif kind == "bandage":
        d.rounded_rectangle([ox + 3, oy + 5, ox + 12, oy + 11], radius=2, fill=WHITE, outline=OUT)
        d.point((ox + 7, oy + 8), fill=RED); d.point((ox + 8, oy + 8), fill=RED)
    elif kind == "can":
        d.rectangle([ox + 5, oy + 3, ox + 10, oy + 13], fill=(160, 165, 170), outline=OUT)
        d.rectangle([ox + 5, oy + 6, ox + 10, oy + 10], fill=RED)
        d.line([ox + 6, oy + 4, ox + 9, oy + 4], fill=(210, 215, 220))
    elif kind == "glowstick":
        d.line([ox + 4, oy + 12, ox + 11, oy + 4], fill=GREEN, width=3)
        d.line([ox + 4, oy + 12, ox + 11, oy + 4], fill=(200, 255, 200))
        d.point((ox + 11, oy + 4), fill=OUT); d.point((ox + 4, oy + 12), fill=OUT)
    elif kind == "shirt":
        khaki = (122, 106, 72)
        d.polygon([(ox + 2, oy + 5), (ox + 5, oy + 3), (ox + 10, oy + 3), (ox + 13, oy + 5), (ox + 12, oy + 8),
                   (ox + 11, oy + 7), (ox + 11, oy + 13), (ox + 4, oy + 13), (ox + 4, oy + 7), (ox + 3, oy + 8)],
                  fill=khaki, outline=OUT)
        d.line([ox + 6, oy + 4, ox + 9, oy + 4], fill=(94, 80, 54))
    elif kind == "paper":
        d.rectangle([ox + 4, oy + 2, ox + 12, oy + 13], fill=(225, 220, 200), outline=OUT)
        for y in (5, 7, 9, 11):
            d.line([ox + 6, oy + y, ox + 10, oy + y], fill=BLUE)


def build_icons():
    img = Image.new("RGBA", (6 * T, 3 * T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for (c, r), (kind, arg) in ICONS.items():
        _draw_icon(d, kind, arg, c * T, r * T, random.Random(c * 7 + r * 13))
    out = ROOT / "assets" / "sprites" / "items.png"
    img.save(out)
    print("wrote", out, img.size)


OBJECTS = {  # id: (w, h) in blocks — must match data/objects.json
    "bed_frame": (3, 2), "cabinet": (2, 3), "desk": (3, 2), "chair": (1, 2), "locker": (1, 3),
    "fridge": (2, 3), "med_cart": (2, 2), "pump": (1, 2), "workbench": (3, 2), "forge": (2, 2), "med_station": (2, 2),
    "dive_station": (2, 3), "mod_bench": (3, 2), "chest": (2, 1), "bed": (3, 2), "standing_lamp": (1, 2),
    "breaker": (1, 1), "ceiling_lamp": (1, 1),
    "wood_door": (1, 3),
}


def _draw_object(d, oid, W, H):
    wood, metal, stone, plastic = _ramp("wood"), _ramp("metal"), _ramp("stone"), _ramp("plastic")
    white = (OUT, [(150, 150, 150), (180, 180, 180), (205, 205, 205), (225, 225, 225)], (240, 240, 240))
    if oid in ("bed_frame", "bed"):
        _box(d, 1, H - 8, W - 2, H - 3, metal if oid == "bed_frame" else wood)          # frame
        d.rectangle([2, H - 12, W - 3, H - 8], fill=(170, 165, 150) if oid == "bed_frame" else (200, 195, 180), outline=OUT)  # mattress
        d.rectangle([W - 12, H - 15, W - 4, H - 11], fill=WHITE, outline=OUT)          # pillow
        d.rectangle([1, H - 3, 3, H - 1], fill=OUT); d.rectangle([W - 4, H - 3, W - 2, H - 1], fill=OUT)  # legs
    elif oid == "cabinet":
        _box(d, 1, 1, W - 2, H - 2, wood)
        d.line([W // 2, 3, W // 2, H - 4], fill=OUT)
        d.point((W // 2 - 2, H // 2), fill=metal[2]); d.point((W // 2 + 2, H // 2), fill=metal[2])
        d.line([2, H // 2 + 6, W - 3, H // 2 + 6], fill=wood[1][1])
    elif oid == "desk":
        _box(d, 0, 10, W - 1, 14, wood)
        d.rectangle([1, 15, 3, H - 1], fill=wood[1][1], outline=OUT); d.rectangle([W - 4, 15, W - 2, H - 1], fill=wood[1][1], outline=OUT)
        _box(d, W - 16, 15, W - 5, H - 3, wood); d.point((W - 10, H - 8), fill=metal[2])
        d.rectangle([3, 6, 9, 10], fill=(200, 200, 200), outline=OUT)                   # papers
    elif oid == "chair":
        _box(d, 2, 7, W - 3, 15, wood); d.rectangle([4, 9, W - 5, 13], fill=wood[1][1])
        _box(d, 1, 16, W - 2, 20, wood)
        d.rectangle([2, 21, 3, H - 1], fill=OUT); d.rectangle([W - 4, 21, W - 3, H - 1], fill=OUT)
    elif oid == "locker":
        _box(d, 1, 0, W - 2, H - 1, metal)
        for y in range(6, 14, 2):
            d.line([4, y, W - 5, y], fill=metal[1][1])
        d.point((W - 5, H // 2 + 4), fill=metal[2])
    elif oid == "fridge":
        _box(d, 1, 0, W - 2, H - 1, white)
        d.line([2, 14, W - 3, 14], fill=OUT)
        d.rectangle([W - 6, 5, W - 5, 11], fill=(120, 120, 125)); d.rectangle([W - 6, 18, W - 5, 30], fill=(120, 120, 125))
    elif oid == "med_cart":
        _box(d, 1, 8, W - 2, H - 5, white)
        d.rectangle([W // 2 - 1, 12, W // 2, 19], fill=RED); d.rectangle([W // 2 - 4, 15, W // 2 + 3, 16], fill=RED)
        d.ellipse([2, H - 5, 6, H - 1], fill=OUT); d.ellipse([W - 7, H - 5, W - 3, H - 1], fill=OUT)
        d.rectangle([3, 5, W - 4, 8], fill=(160, 160, 165), outline=OUT)
    elif oid == "pump":
        _box(d, 2, 10, W - 3, H - 1, metal)                                       # body
        d.ellipse([4, 13, 11, 20], outline=metal[1][3]); d.point((7, 16), fill=metal[2])  # impeller
        d.rectangle([6, 2, 9, 10], fill=(70, 110, 150), outline=OUT)              # hose stub
        d.rectangle([5, 0, 10, 3], fill=metal[1][1], outline=OUT)                 # nozzle
        d.point((3, 27), fill=ORANGE); d.point((12, 27), fill=GREEN)              # status leds
    elif oid == "workbench":
        _box(d, 0, 8, W - 1, 12, wood)
        d.rectangle([2, 13, 5, H - 1], fill=wood[1][1], outline=OUT); d.rectangle([W - 6, 13, W - 3, H - 1], fill=wood[1][1], outline=OUT)
        d.rectangle([6, 4, 14, 7], fill=metal[1][2], outline=OUT); d.rectangle([28, 2, 31, 7], fill=metal[1][3], outline=OUT)
        d.rectangle([34, 5, 42, 7], fill=(140, 100, 60), outline=OUT)
    elif oid == "forge":
        _box(d, 0, 4, W - 1, H - 1, stone, bevel=False)
        d.rectangle([6, 14, W - 7, H - 5], fill=(60, 30, 20), outline=OUT)
        d.rectangle([9, 18, W - 10, H - 7], fill=ORANGE); d.point((W // 2, 20), fill=(255, 220, 120))
        d.rectangle([W // 2 - 3, 0, W // 2 + 2, 4], fill=stone[1][1], outline=OUT)
    elif oid == "med_station":
        _box(d, 0, 2, W - 1, H - 1, white)
        d.rectangle([W // 2 - 1, 8, W // 2, 19], fill=RED); d.rectangle([W // 2 - 6, 13, W // 2 + 5, 14], fill=RED)
        d.rectangle([3, 5, 9, 9], fill=BLUE, outline=OUT)
    elif oid == "dive_station":
        _box(d, 0, 6, W - 1, H - 1, metal)
        for i, x in enumerate((4, 12, 20)):
            d.rectangle([x, 12, x + 5, H - 5], fill=(80, 130, 180), outline=OUT); d.rectangle([x + 1, 13, x + 1, H - 8], fill=(150, 200, 240))
        d.rectangle([2, 0, W - 3, 6], fill=metal[1][1], outline=OUT); d.rectangle([W // 2 - 2, 2, W // 2 + 1, 4], fill=GREEN)
    elif oid == "mod_bench":
        _box(d, 0, 8, W - 1, 12, wood)
        d.rectangle([2, 13, 5, H - 1], fill=wood[1][1], outline=OUT); d.rectangle([W - 6, 13, W - 3, H - 1], fill=wood[1][1], outline=OUT)
        d.rectangle([8, 3, 18, 7], fill=metal[1][2], outline=OUT)
        for x in (24, 30, 36):
            d.polygon([(x, 7), (x + 2, 3), (x + 4, 7)], fill=PURPLE, outline=OUT)
    elif oid == "chest":
        _box(d, 1, 3, W - 2, H - 1, wood)
        d.line([2, 8, W - 3, 8], fill=metal[1][2]); d.rectangle([W // 2 - 1, 7, W // 2, 10], fill=metal[1][3], outline=OUT)
    elif oid == "standing_lamp":
        d.rectangle([7, 8, 8, H - 3], fill=metal[1][1]); d.rectangle([4, H - 3, 11, H - 1], fill=metal[1][2], outline=OUT)
        d.polygon([(3, 8), (12, 8), (11, 1), (4, 1)], fill=(230, 200, 140), outline=OUT)
        d.rectangle([6, 3, 9, 6], fill=(255, 240, 200))
    elif oid == "breaker":
        _box(d, 3, 2, W - 4, H - 3, metal)
        d.rectangle([6, 5, 9, 10], fill=(40, 40, 44), outline=OUT)   # switch slot
        d.rectangle([7, 5, 8, 7], fill=ORANGE)                       # lever
        d.point((5, H - 5), fill=GREEN); d.point((10, H - 5), fill=RED)
    elif oid == "ceiling_lamp":
        d.rectangle([6, 0, 9, 3], fill=metal[1][1], outline=OUT)     # mount
        d.polygon([(3, 8), (12, 8), (10, 3), (5, 3)], fill=metal[1][2], outline=OUT)  # shade
        d.rectangle([5, 8, 10, 10], fill=(255, 240, 200), outline=OUT)  # tube
    elif oid == "wood_door":
        _box(d, 2, 0, W - 3, H - 1, wood)
        for y in range(4, H - 4, 8):
            d.rectangle([4, y, W - 5, y + 5], fill=wood[1][3], outline=wood[1][1])
        d.point((W - 6, H // 2), fill=metal[2])


def build_objects():
    out_dir = ROOT / "assets" / "sprites" / "objects"
    out_dir.mkdir(parents=True, exist_ok=True)
    for oid, (w, h) in OBJECTS.items():
        W, H = w * T, h * T
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        _draw_object(ImageDraw.Draw(img), oid, W, H)
        img.save(out_dir / f"{oid}.png")
    print("wrote", len(OBJECTS), "object sprites to", out_dir)


def build_light():
    size = 128
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = size / 2 - 0.5
    for y in range(size):
        for x in range(size):
            dist = ((x - c) ** 2 + (y - c) ** 2) ** 0.5 / (size / 2)
            a = max(0.0, 1.0 - dist) ** 1.6
            img.putpixel((x, y), (255, 255, 255, int(255 * a)))
    out = ROOT / "assets" / "sprites" / "light.png"
    img.save(out)
    print("wrote", out)


# --- Real character sheet from the reference export ------------------------------------------
# Source: docs/Examples/Character/Main_Character_with_red-Idle-spritesheet (48x48 cells, 8 cols;
# row 0 = 8 idle directions [S, SE, E, NE, N, NW, W, SW], rows 2/3 = 6-frame walk east/west).
# Output: assets/sprites/player.png, 32x32 frames, 7 columns x 2 rows:
#   row 0 = east  [idle, walk1..6]      row 1 = west [idle, walk1..6]
REF_SHEET = ROOT / "docs" / "Examples" / "Character" / "Main_Character_with_red-Idle-spritesheet" / "Main_Character_with_red-Idle.png"
FRAME = 32
CELL = 48


def _cell(sheet, col, row):
    x, y = col * CELL, row * CELL
    pad = (CELL - FRAME) // 2
    return sheet.crop((x + pad, y + pad, x + pad + FRAME, y + pad + FRAME))


def build_player_sheet():
    if not REF_SHEET.exists():
        print("skip player sheet: reference not found", REF_SHEET)
        return
    src = Image.open(REF_SHEET).convert("RGBA")
    out = Image.new("RGBA", (7 * FRAME, 2 * FRAME), (0, 0, 0, 0))
    # Source pairing verified visually: idle col 2 + walk row 3 face east (right),
    # idle col 6 + walk row 2 face west (left). (An earlier "compensation" had
    # these swapped, which made the character walk right while facing left.)
    for r, (idle_col, walk_row) in enumerate(((2, 3), (6, 2))):  # east, west
        out.paste(_cell(src, idle_col, 0), (0, r * FRAME))
        for i in range(6):
            out.paste(_cell(src, i, walk_row), ((i + 1) * FRAME, r * FRAME))
    path = ROOT / "assets" / "sprites" / "player.png"
    out.save(path)
    print("wrote", path, out.size)


# --- UI 9-slice textures (palette sampled from docs/Examples/UI Menus mockups) --------------------
UI_DIR = ROOT / "assets" / "ui"
WOOD_EDGE = (24, 8, 8)
WOOD_BEVEL = (184, 144, 104)
WOOD_BEVEL_DK = (140, 96, 64)
WOOD_RIM = (88, 48, 32)
WOOD_FILL = (22, 6, 4)
WELL_FILL = (48, 32, 32)
WELL_FILL_HOVER = (70, 50, 46)
WELL_EDGE = (16, 0, 0)
WELL_RIM = (72, 40, 32)
STEEL_LIGHT = (144, 192, 208)
STEEL_DARK = (32, 56, 64)
STEEL_FILL = (40, 56, 72)
STEEL_WELL = (16, 32, 48)
PLAQUE_DARK = (24, 16, 16)
PLAQUE_WOOD = (56, 40, 32)
PLAQUE_WOOD_LT = (120, 84, 56)


def _frame(size, layers, fill):
    """Square 9-slice: concentric 1px layers from the outside in, then fill."""
    img = Image.new("RGBA", (size, size), (*fill, 255))
    d = ImageDraw.Draw(img)
    for i, c in enumerate(layers):
        d.rectangle([i, i, size - 1 - i, size - 1 - i], outline=(*c, 255))
    return img


def build_ui_textures():
    UI_DIR.mkdir(parents=True, exist_ok=True)
    # Wood frame: dark edge, 2px tan bevel, brown rim, near-black fill (the grid backing)
    _frame(24, [WOOD_EDGE, WOOD_BEVEL, WOOD_BEVEL_DK, WOOD_RIM, WOOD_RIM], WOOD_FILL).save(UI_DIR / "wood_frame.png")
    # Slot well (normal / hover / selected)
    _frame(16, [WELL_EDGE, WELL_RIM], WELL_FILL).save(UI_DIR / "slot.png")
    _frame(16, [WELL_EDGE, WOOD_BEVEL_DK], WELL_FILL_HOVER).save(UI_DIR / "slot_hover.png")
    _frame(16, [WOOD_BEVEL, WOOD_BEVEL_DK], WELL_FILL_HOVER).save(UI_DIR / "slot_selected.png")
    # Steel panel: light border, dark inner line, blue-gray fill
    _frame(16, [STEEL_LIGHT, STEEL_LIGHT, STEEL_DARK], STEEL_FILL).save(UI_DIR / "steel_panel.png")
    # Steel equipment slot / button
    _frame(16, [STEEL_LIGHT, STEEL_DARK], STEEL_WELL).save(UI_DIR / "steel_slot.png")
    _frame(16, [STEEL_LIGHT, STEEL_DARK], STEEL_FILL).save(UI_DIR / "steel_button.png")
    _frame(16, [(200, 230, 240), STEEL_LIGHT], (60, 84, 104)).save(UI_DIR / "steel_button_hover.png")
    _frame(16, [STEEL_DARK, STEEL_DARK], (28, 40, 52)).save(UI_DIR / "steel_button_pressed.png")
    _frame(16, [(70, 80, 90), STEEL_DARK], (34, 44, 54)).save(UI_DIR / "steel_button_disabled.png")
    # Title plaque: pointed wooden banner, 160x20, drawn whole (not 9-sliced)
    W, H = 160, 20
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body = [(8, 0), (W - 9, 0), (W - 1, H // 2), (W - 9, H - 1), (8, H - 1), (0, H // 2)]
    d.polygon(body, fill=(*PLAQUE_DARK, 255), outline=(*WOOD_EDGE, 255))
    inner = [(11, 2), (W - 12, 2), (W - 4, H // 2), (W - 12, H - 3), (11, H - 3), (3, H // 2)]
    d.polygon(inner, fill=(*PLAQUE_WOOD, 255), outline=(*PLAQUE_WOOD_LT, 255))
    d.rectangle([14, 4, W - 15, H - 5], fill=(*PLAQUE_DARK, 255))
    img.save(UI_DIR / "plaque.png")
    # Equipment slot glyphs (16x16, drawn dim): head, suit, accessory, lock
    glyphs = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
    g = ImageDraw.Draw(glyphs)
    dim = (90, 120, 140, 255)
    g.arc([3, 3, 12, 14], 180, 360, fill=dim, width=2); g.line([3, 9, 12, 9], fill=dim)            # head
    g.polygon([(4, 4), (11, 4), (13, 7), (11, 13), (4, 13), (2, 7)], outline=dim)                 # suit
    g.ellipse([4, 4, 11, 11], outline=dim); g.point((7, 7), fill=dim)                              # accessory ring
    g.rectangle([16 * 3 + 4, 7, 16 * 3 + 11, 13], outline=dim); g.arc([16 * 3 + 5, 2, 16 * 3 + 10, 9], 180, 360, fill=dim)  # lock
    for i in (1, 2):
        pass
    # shift glyphs 1 and 2 into their cells
    cell = glyphs.crop((0, 0, 16, 16))
    out = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
    out.paste(cell, (0, 0))
    suit = Image.new("RGBA", (16, 16), (0, 0, 0, 0)); ImageDraw.Draw(suit).polygon([(4, 3), (11, 3), (13, 6), (11, 13), (4, 13), (2, 6)], outline=dim); out.paste(suit, (16, 0))
    acc = Image.new("RGBA", (16, 16), (0, 0, 0, 0)); dd = ImageDraw.Draw(acc); dd.ellipse([4, 4, 11, 11], outline=dim); dd.point((7, 7), fill=dim); out.paste(acc, (32, 0))
    out.paste(glyphs.crop((48, 0, 64, 16)), (48, 0))
    out.save(UI_DIR / "equip_glyphs.png")
    # Character portrait for the inventory panel (front view from the reference art)
    portrait_src = ROOT / "docs" / "Examples" / "Character" / "MainCharacter-front.png"
    if portrait_src.exists():
        p = Image.open(portrait_src).convert("RGBA")
        h = 116
        w = round(p.width * h / p.height)
        p.resize((w, h), Image.LANCZOS).save(UI_DIR / "character_portrait.png")
    print("wrote UI textures to", UI_DIR)


# --- Backgrounds (user art in docs/Examples/Backgrounds, downscaled to the 640x360 world) ---------
BG_SRC = ROOT / "docs" / "Examples" / "Backgrounds"
MENU_BG_SRC = ROOT / "docs" / "Examples" / "UI Menus" / "background01.jpg"
BG_DIR = ROOT / "assets" / "backgrounds"


def build_backgrounds():
    if not BG_SRC.exists():
        print("skip backgrounds: source not found", BG_SRC)
        return
    BG_DIR.mkdir(parents=True, exist_ok=True)
    for i in (1, 2, 3, 4, 5):
        src = BG_SRC / f"City0{i}.jpg"
        if not src.exists():
            continue
        im = Image.open(src).convert("RGB")
        im.resize((im.width // 2, im.height // 2), Image.BOX).save(BG_DIR / f"city0{i}.png")
    for i in (1, 2, 3, 4):
        im = Image.open(BG_SRC / f"Building0{i}_clear.png").convert("RGBA")
        im.resize((im.width // 2, im.height // 2), Image.NEAREST).save(BG_DIR / f"building0{i}.png")
    if MENU_BG_SRC.exists():
        im = Image.open(MENU_BG_SRC).convert("RGB")
        im.resize((im.width // 2, im.height // 2), Image.BOX).save(BG_DIR / "menu_backdrop.png")
    print("wrote backgrounds to", BG_DIR)


if __name__ == "__main__":
    build_atlas()
    build_character()
    build_icons()
    build_objects()
    build_light()
    build_player_sheet()
    build_ui_textures()
    build_backgrounds()

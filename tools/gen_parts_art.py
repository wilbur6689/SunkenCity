"""Found parts, the five new benches and the pot-belly stove: sprites + data.

    python tools/gen_parts_art.py

Writes assets/sprites/objects/<id>.png (8 px per cell, authored: true so the
placeholder generator and pack builders leave them alone) and merges the
object entries into data/objects.json and the bench / stove recipes into
data/recipes.json (entries carry "gen": "parts_v1" and are replaced on re-run;
the station moves are applied to existing recipes by id). Design chart:
docs/CraftingStages.md. Deterministic.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OBJ_DIR = ROOT / "assets" / "sprites" / "objects"
DATA = ROOT / "data"
GEN = "parts_v1"
CELL = 8

OUT = (24, 18, 14, 255)
WOOD = ((92, 62, 36), (140, 98, 58), (186, 140, 88))
DARK = ((30, 30, 34), (52, 52, 58), (90, 90, 98))
METAL = ((95, 100, 108), (140, 146, 154), (190, 195, 202))
IRON = ((70, 82, 100), (112, 128, 150), (165, 180, 200))
STEEL = ((45, 50, 62), (80, 88, 104), (130, 140, 158))
RED = ((120, 30, 25), (190, 55, 45), (230, 110, 95))
YELLOW = ((150, 110, 20), (220, 170, 40), (245, 210, 90))
ORANGE = ((160, 80, 20), (225, 125, 40), (250, 175, 90))
BLUE = ((30, 70, 130), (60, 120, 200), (120, 180, 240))
GREEN = ((40, 100, 50), (80, 160, 90), (140, 210, 150))
WHITE = ((150, 150, 150), (210, 210, 210), (245, 245, 245))
BRASS = ((150, 110, 40), (214, 170, 70), (240, 210, 130))
PAPER = ((170, 165, 150), (220, 214, 196), (245, 240, 225))


class C:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def box(self, x0, y0, x1, y1, ramp, shade=1, bevel=True):
        self.d.rectangle([x0, y0, x1, y1], fill=ramp[shade] + (255,))
        if bevel and x1 - x0 > 2 and y1 - y0 > 2:
            self.d.line([x0, y0, x1, y0], fill=ramp[2] + (255,))
            self.d.line([x0, y0, x0, y1], fill=ramp[2] + (255,))
            self.d.line([x0, y1, x1, y1], fill=ramp[0] + (255,))
            self.d.line([x1, y0, x1, y1], fill=ramp[0] + (255,))

    def line(self, x0, y0, x1, y1, ramp, w=1, shade=1):
        self.d.line([x0, y0, x1, y1], fill=ramp[shade] + (255,), width=w)

    def ellipse(self, x0, y0, x1, y1, ramp, shade=1):
        self.d.ellipse([x0, y0, x1, y1], fill=ramp[shade] + (255,))

    def px(self, x, y, ramp, shade=2):
        self.d.point((x, y), fill=ramp[shade] + (255,))

    def outline(self):
        src = self.img.copy().load()
        out = self.img.load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] == 0:
                    continue
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if not (0 <= nx < self.w and 0 <= ny < self.h) or src[nx, ny][3] == 0:
                        out[x, y] = OUT
                        break
        return self.img


# ---- sprites: every draw(c) works in a (w*8, h*8) canvas, floor at the bottom ----

def legs(c, ramp, xs, y0, y1):
    for x in xs:
        c.box(x, y0, x + 2, y1, ramp, 0, bevel=False)


def drafting_table(c):  # 48x32: tilted board on a frame, lamp, rolled plans
    legs(c, DARK, (4, 40), 18, 31)
    c.box(2, 14, 45, 18, DARK, 1)
    c.d.polygon([(4, 14), (44, 14), (44, 4), (4, 10)], fill=PAPER[1] + (255,))
    c.d.polygon([(4, 14), (44, 14), (44, 4), (4, 10)], outline=WOOD[0] + (255,))
    for i in range(3):
        c.line(10 + i * 9, 8 - i, 30 + i * 6, 6 - i, BLUE, 1, 1)
    c.box(36, 0, 47, 3, PAPER, 2)  # rolled plans
    c.line(6, 3, 6, 9, DARK, 2)      # lamp arm
    c.box(2, 0, 10, 3, YELLOW, 1)


def cast_stove(c):  # 32x32: iron firebox on legs, pipe up, warm door
    c.box(6, 12, 25, 27, IRON, 1)
    c.box(9, 16, 20, 24, DARK, 0)
    c.box(11, 18, 18, 22, ORANGE, 1)
    c.box(4, 10, 27, 12, IRON, 2)
    legs(c, IRON, (6, 22), 27, 31)
    c.box(13, 0, 17, 10, IRON, 0)
    c.box(22, 20, 24, 21, BRASS, 2)


def engine_lathe(c):  # 48x32: bed, headstock, chuck, tailstock
    c.box(2, 22, 45, 26, STEEL, 1)
    legs(c, STEEL, (4, 40), 26, 31)
    c.box(4, 8, 16, 22, IRON, 1)
    c.ellipse(16, 11, 22, 19, METAL, 2)
    c.box(22, 13, 34, 17, STEEL, 0)
    c.box(34, 10, 42, 22, IRON, 1)
    c.box(6, 4, 14, 8, GREEN, 1)  # control box
    c.px(8, 6, RED); c.px(11, 6, YELLOW)


def welding_rig(c):  # 32x32: gas bottles on a cart, torch hose, mask
    c.box(2, 26, 29, 29, DARK, 1)
    c.ellipse(1, 26, 7, 31, DARK, 0)
    c.ellipse(24, 26, 30, 31, DARK, 0)
    c.box(6, 6, 12, 26, GREEN, 1)
    c.box(14, 4, 20, 26, BLUE, 1)
    c.box(7, 2, 11, 6, METAL, 2)
    c.box(15, 0, 19, 4, METAL, 2)
    c.line(20, 8, 28, 14, RED, 1, 1)
    c.line(28, 14, 27, 22, RED, 1, 1)
    c.box(22, 16, 30, 24, DARK, 1)  # mask
    c.box(24, 18, 28, 20, ORANGE, 2)


def generator(c):  # 48x32: yellow gen-set, exhaust, panel
    c.box(2, 10, 45, 29, YELLOW, 1)
    c.box(4, 12, 20, 27, DARK, 1)
    c.box(24, 14, 42, 26, YELLOW, 0)
    c.box(26, 16, 40, 24, DARK, 0)
    c.px(28, 18, GREEN); c.px(31, 18, RED)
    c.box(8, 2, 12, 10, STEEL, 0)
    legs(c, DARK, (4, 40), 29, 31)
    c.line(6, 29, 42, 29, DARK, 1, 0)


def crash_cart(c):  # 32x32: red cart, drawers, defib box
    c.box(4, 8, 27, 26, RED, 1)
    for y in (12, 17, 22):
        c.line(6, y, 25, y, RED, 1, 0)
    c.box(6, 2, 18, 8, WHITE, 2)
    c.box(8, 4, 10, 6, RED, 1)
    c.box(20, 4, 26, 8, DARK, 1)
    c.ellipse(4, 26, 9, 31, DARK, 0)
    c.ellipse(22, 26, 27, 31, DARK, 0)
    c.line(27, 6, 29, 20, METAL, 1, 2)


def site_toolbox(c):  # 32x16: steel box, latch, handle
    c.box(2, 6, 29, 15, RED, 1)
    c.box(2, 6, 29, 8, RED, 0)
    c.line(10, 2, 21, 2, DARK, 2)
    c.line(10, 2, 10, 6, DARK, 1); c.line(21, 2, 21, 6, DARK, 1)
    c.box(14, 8, 17, 10, METAL, 2)


def dive_tanks(c):  # 32x32: two cylinders on a rack, valves, gauge
    c.box(2, 26, 29, 29, METAL, 1)
    c.box(6, 6, 13, 26, YELLOW, 1)
    c.box(17, 6, 24, 26, BLUE, 1)
    c.box(7, 2, 12, 6, METAL, 2)
    c.box(18, 2, 23, 6, METAL, 2)
    c.line(9, 0, 9, 2, BRASS, 1, 2); c.line(20, 0, 20, 2, BRASS, 1, 2)
    c.box(26, 10, 30, 14, WHITE, 2)
    c.px(28, 12, RED)


def hose_reel(c):  # 32x32: red wall-cabinet with a coiled hose
    c.box(2, 2, 29, 29, RED, 1)
    c.box(4, 4, 27, 27, DARK, 0)
    for r in (10, 8, 6, 4):
        c.d.ellipse([15 - r, 15 - r, 15 + r, 15 + r], outline=(200, 190, 170, 255))
    c.box(13, 13, 17, 17, METAL, 1)
    c.box(22, 22, 27, 27, BRASS, 1)  # nozzle


def tool_chest(c):  # 32x32: rolling red chest, drawers, wheels
    c.box(3, 4, 28, 26, RED, 1)
    for y in (8, 12, 16, 20, 24):
        c.line(5, y, 26, y, RED, 0)
        c.box(13, y - 2, 18, y - 1, METAL, 2)
    c.box(3, 2, 28, 4, DARK, 1)
    c.ellipse(4, 26, 9, 31, DARK, 0)
    c.ellipse(22, 26, 27, 31, DARK, 0)


def machine_shop(c):  # 48x32 station: heavy bench, vise, drill press
    c.box(2, 16, 45, 20, STEEL, 1)
    legs(c, STEEL, (4, 40), 20, 31)
    c.box(6, 10, 14, 16, IRON, 1)     # vise
    c.line(2, 12, 6, 12, IRON, 2, 2)
    c.box(30, 0, 36, 16, IRON, 0)     # drill column
    c.box(24, 2, 40, 6, IRON, 1)
    c.box(31, 8, 35, 12, METAL, 2)
    c.box(16, 12, 24, 16, DARK, 1)    # parts tray
    c.px(18, 14, BRASS); c.px(21, 14, BRASS)


def steel_works(c):  # 48x32 station: furnace + crucible + arc glow
    c.box(2, 6, 28, 29, STEEL, 1)
    c.box(6, 12, 24, 26, DARK, 0)
    c.box(9, 16, 21, 24, ORANGE, 1)
    c.box(11, 18, 19, 22, YELLOW, 2)
    c.box(10, 0, 20, 6, STEEL, 0)
    c.box(32, 18, 45, 29, IRON, 1)    # quench tank
    c.box(34, 20, 43, 24, BLUE, 1)
    c.box(36, 8, 40, 18, IRON, 0)     # ladle arm
    c.ellipse(33, 4, 43, 10, METAL, 1)


def pressure_works(c):  # 48x32 station: hydraulic press + gauges + pipes
    c.box(2, 26, 45, 29, STEEL, 1)
    legs(c, STEEL, (4, 40), 29, 31)
    c.box(6, 0, 40, 6, STEEL, 0)
    c.box(10, 6, 14, 26, IRON, 1); c.box(32, 6, 36, 26, IRON, 1)
    c.box(16, 6, 30, 12, IRON, 0)     # ram
    c.box(18, 12, 28, 16, METAL, 2)
    c.box(16, 20, 30, 26, DARK, 1)    # die
    for x in (40, 44):
        c.ellipse(x - 2, 10, x + 2, 14, WHITE, 2)
        c.px(x, 12, RED)
    c.line(40, 14, 40, 26, IRON, 1, 2)


def weapon_bench(c):  # 48x32 station: rack of blades, grinder, ammo press
    c.box(2, 18, 45, 22, WOOD, 1)
    legs(c, WOOD, (4, 40), 22, 31)
    c.box(4, 2, 22, 18, DARK, 1)      # pegboard
    for i, x in enumerate((7, 11, 15, 19)):
        c.line(x, 5, x, 15 - i, METAL, 1, 2)
        c.px(x, 15 - i, WOOD, 1)
    c.ellipse(26, 8, 36, 18, METAL, 1)  # grinder wheel
    c.ellipse(29, 11, 33, 15, DARK, 0)
    c.box(38, 12, 45, 18, IRON, 1)    # press
    c.px(41, 14, BRASS); c.px(43, 14, BRASS)


def pump_works(c):  # 32x32 station: pipe manifold, valves, gauge
    c.box(2, 22, 29, 29, IRON, 1)
    legs(c, IRON, (4, 24), 29, 31)
    c.box(4, 6, 8, 22, IRON, 0); c.box(22, 6, 26, 22, IRON, 0)
    c.box(4, 6, 26, 10, IRON, 0)
    c.ellipse(11, 12, 19, 20, BLUE, 1)   # pump body
    c.ellipse(13, 14, 17, 18, METAL, 2)
    c.box(24, 12, 30, 14, RED, 1)        # valve wheel
    c.ellipse(9, 0, 15, 6, WHITE, 2); c.px(12, 3, RED)


def pot_belly_stove(c):  # 16x32: round belly, door, chimney
    c.box(6, 0, 9, 8, DARK, 0)
    c.ellipse(1, 8, 14, 24, IRON, 1)
    c.ellipse(5, 13, 10, 19, DARK, 0)
    c.px(7, 16, ORANGE, 1)
    c.box(3, 24, 12, 26, IRON, 0)
    legs(c, DARK, (3, 10), 26, 31)


SPRITES = {
    "part_drafting_table": (6, 4, drafting_table), "part_cast_stove": (4, 4, cast_stove),
    "part_engine_lathe": (6, 4, engine_lathe), "part_welding_rig": (4, 4, welding_rig),
    "part_generator": (6, 4, generator), "part_crash_cart": (4, 4, crash_cart),
    "part_site_toolbox": (4, 2, site_toolbox), "part_dive_tanks": (4, 4, dive_tanks),
    "part_hose_reel": (4, 4, hose_reel), "part_tool_chest": (4, 4, tool_chest),
    "machine_shop": (6, 4, machine_shop), "steel_works": (6, 4, steel_works),
    "pressure_works": (6, 4, pressure_works), "weapon_bench": (6, 4, weapon_bench),
    "pump_works": (4, 4, pump_works), "pot_belly_stove": (2, 4, pot_belly_stove),
}

# id: (name, bench it builds, district, band, desc, yields)
PARTS = {
    "part_drafting_table": ("Drafting Table", "workbench", "business", "dry",
        "A flat, square drawing table. The frame of a real workbench.", [("wood", 6, 10), ("scrap_metal", 2, 3)]),
    "part_cast_stove": ("Cast-Iron Stove", "forge", "residential", "shallows",
        "A kitchen firebox heavy enough to hold a forge fire.", [("scrap_metal", 4, 6), ("stone", 2, 3)]),
    "part_engine_lathe": ("Engine Lathe", "machine_shop", "industrial", "cold",
        "A bench lathe. The heart of a machine shop.", [("scrap_metal", 4, 6), ("iron", 2, 3)]),
    "part_welding_rig": ("Welding Rig", "steel_works", "construction", "dark",
        "Gas bottles, torch and mask on a cart. Makes steel work possible.", [("scrap_metal", 3, 5), ("iron", 1, 2), ("plastic", 1, 2)]),
    "part_generator": ("Backup Generator", "pressure_works", "civil", "crush",
        "A hospital's standby generator. Power for a pressure works.", [("scrap_metal", 5, 8), ("iron", 2, 4), ("plastic", 1, 2)]),
    "part_crash_cart": ("Crash Cart", "med_station", "civil", "dry",
        "A stocked emergency cart. The core of a med station.", [("scrap_metal", 2, 4), ("plastic", 2, 3), ("cloth", 1, 2)]),
    "part_site_toolbox": ("Site Toolbox", "weapon_bench", "construction", "dry",
        "A site foreman's steel toolbox. Everything a weapon bench needs.", [("scrap_metal", 3, 5)]),
    "part_dive_tanks": ("Dive Tanks", "dive_station", "commercial", "shallows",
        "A shop's rental tanks and valves. The start of a dive station.", [("scrap_metal", 4, 6), ("plastic", 1, 2)]),
    "part_hose_reel": ("Hose Reel", "pump_works", "civil", "shallows",
        "A fire-hose cabinet with its reel and nozzle. Pipe for a pump works.", [("scrap_metal", 3, 5), ("cloth", 2, 3)]),
    "part_tool_chest": ("Rolling Tool Chest", "mod_bench", "industrial", "cold",
        "Drawers of fine tools. What a modification bench is built around.", [("scrap_metal", 4, 6), ("iron", 1, 2)]),
}
STATIONS = {
    "machine_shop": ("Machine Shop", "Iron-tier tooling: lathe, vise and drill press.", [("scrap_metal", 8, 8), ("iron", 6, 6)]),
    "steel_works": ("Steel Works", "Furnace and quench tank - iron becomes steel here.", [("scrap_metal", 8, 8), ("stone", 8, 8), ("iron", 6, 6)]),
    "pressure_works": ("Pressure Works", "A hydraulic press for the deepest gear.", [("steel", 4, 4), ("iron", 8, 8)]),
    "weapon_bench": ("Weapon Bench", "Grinder, pegboard and press - every weapon and its ammo.", [("wood", 8, 8), ("scrap_metal", 6, 6)]),
    "pump_works": ("Pump Works", "Manifold and valves for pumps, pipes and wiring.", [("scrap_metal", 8, 8), ("plastic", 4, 4)]),
}
BENCH_RECIPES = {
    # bench id: (station it is crafted at, tier, inputs incl. its part)
    "workbench": ("hand", 1, [("wood", 30), ("scrap_metal", 15), ("part_drafting_table", 1)]),
    "forge": ("workbench", 2, [("stone", 10), ("scrap_metal", 20), ("plastic", 10), ("part_cast_stove", 1)]),
    "machine_shop": ("forge", 3, [("iron", 20), ("scrap_metal", 20), ("wood", 10), ("part_engine_lathe", 1)]),
    "steel_works": ("machine_shop", 4, [("iron", 30), ("stone", 20), ("plastic", 10), ("part_welding_rig", 1)]),
    "pressure_works": ("steel_works", 5, [("steel", 20), ("iron", 20), ("plastic", 10), ("part_generator", 1)]),
    "med_station": ("workbench", 2, [("scrap_metal", 4), ("plastic", 4), ("cloth", 2), ("part_crash_cart", 1)]),
    "weapon_bench": ("workbench", 2, [("wood", 20), ("scrap_metal", 20), ("cloth", 5), ("part_site_toolbox", 1)]),
    "dive_station": ("forge", 2, [("scrap_metal", 6), ("plastic", 4), ("cloth", 4), ("part_dive_tanks", 1)]),
    "pump_works": ("forge", 2, [("scrap_metal", 10), ("plastic", 10), ("iron", 4), ("part_hose_reel", 1)]),
    "mod_bench": ("machine_shop", 3, [("scrap_metal", 6), ("wood", 4), ("iron", 4), ("part_tool_chest", 1)]),
}
# Existing recipes that move to a new bench (by recipe id); district weapons move by tag.
MOVES = {
    "weapon_bench": ["scrap_sword", "fire_axe", "iron_sword", "speargun", "speargun_bolt", "pistol_rounds", "rifle_rounds"],
    "pump_works": ["pump", "standing_lamp"],
    "machine_shop": ["iron_knife", "bolt_cutters", "iron_scrap_bench"],
    "steel_works": ["steel", "cutting_torch", "steel_scrap_bench"],
    "pressure_works": ["master_scrap_bench"],
}


def skill_for(yields):
    """Harvest gate by material tier (GL-28): iron yields need Scrapping 2, steel 3."""
    mats = {i for i, _a, _b in yields}
    return 3 if "steel" in mats else (2 if "iron" in mats else 0)


def draw_all():
    OBJ_DIR.mkdir(parents=True, exist_ok=True)
    for oid, (w, h, fn) in SPRITES.items():
        c = C(w * CELL, h * CELL)
        fn(c)
        c.outline().save(OBJ_DIR / (oid + ".png"))
    print("sprites:", len(SPRITES))


def merge_objects():
    p = DATA / "objects.json"
    data = json.loads(p.read_text(encoding="utf-8"))
    objs = [o for o in data["objects"] if o.get("gen") != GEN]
    ids = {o["id"] for o in objs}
    new = []
    for oid, (name, bench, district, band, desc, yields) in PARTS.items():
        w, h, _ = SPRITES[oid]
        new.append({"id": oid, "name": name, "kind": "scrap", "category": "part", "size": [w, h],
                    "zones": [district], "band": band, "needed_for": bench, "part": True,
                    "desc": desc, "weight": 25.0, "scrap_time": 3.0, "tool_tier": 0, "skill": skill_for(yields), "xp": 4,
                    "yields": [{"item": i, "min": a, "max": b} for i, a, b in yields],
                    "authored": True, "gen": GEN})
    for sid, (name, desc, yields) in STATIONS.items():
        w, h, _ = SPRITES[sid]
        new.append({"id": sid, "name": name, "kind": "station", "station": sid, "size": [w, h], "desc": desc,
                    "weight": 45.0, "skill": skill_for(yields), "yields": [{"item": i, "min": a, "max": b} for i, a, b in yields],
                    "authored": True, "gen": GEN})
    new.append({"id": "pot_belly_stove", "name": "Pot-Belly Stove", "kind": "heater", "size": [2, 4],
                "desc": "Lit in a sealed room it slowly boils the water away. Won't sit in an open room.",
                "weight": 30.0, "powered": True, "place_in_water": True,
                "yields": [{"item": "scrap_metal", "min": 6, "max": 6}, {"item": "stone", "min": 4, "max": 4}],
                "authored": True, "gen": GEN})
    for o in new:
        assert o["id"] not in ids, "clash: " + o["id"]
    data["objects"] = objs + new
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("objects +%d" % len(new))


def merge_recipes():
    p = DATA / "recipes.json"
    data = json.loads(p.read_text(encoding="utf-8"))
    recs = [r for r in data["recipes"] if r.get("gen") != GEN]
    by_id = {r["id"]: r for r in recs}
    # Bench recipes: replace the existing station recipes in place (keep order), add the new ones.
    for bench, (station, tier, inputs) in BENCH_RECIPES.items():
        r = {"id": bench, "station": station, "tier": tier, "known": True,
             "output": {"item": bench, "count": 1},
             "inputs": [{"item": i, "count": n} for i, n in inputs], "gen": GEN}
        if bench in by_id:
            recs[recs.index(by_id[bench])] = r
        else:
            recs.append(r)
    recs.append({"id": "pot_belly_stove", "station": "workbench", "tier": 2, "known": True,
                 "output": {"item": "pot_belly_stove", "count": 1},
                 "inputs": [{"item": "scrap_metal", "count": 12}, {"item": "stone", "count": 8}], "gen": GEN,
                 "desc": "Place it in a sealed room and light it: the room dries out, slowly."})
    moved = 0
    for r in recs:
        if r.get("district_weapon"):
            if r["station"] != "weapon_bench":
                r["station"] = "weapon_bench"
                moved += 1
        for st, ids in MOVES.items():
            if r["id"] in ids and r["station"] != st:
                r["station"] = st
                moved += 1
    data["recipes"] = recs
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("recipes: bench recipes %d, moved %d" % (len(BENCH_RECIPES), moved))


if __name__ == "__main__":
    draw_all()
    merge_objects()
    merge_recipes()

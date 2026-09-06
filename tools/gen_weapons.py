"""District weapons (docs/modifiers/Weapons.md): items, ammo, recipes and loot.

    python tools/gen_weapons.py

Merges into data/items.json, data/recipes.json and data/loot.json:
  * one item per roster row (§4) carrying `district_weapon: true` so re-runs
    replace exactly these entries and never touch hand-written ones; the
    pre-existing pistol / smg / rifle only get their new display names;
  * the seven new ammo items (§3) with their `projectile` blocks;
  * a recipe per melee weapon at its band's station (blank canvases for the
    modifier loop) and per ammo type - never for a firearm (LT-18);
  * the §5 placement matrix as weighted `found` entries per district x band
    table (dark / crush rows are created from the generic rows first), and
    the T4-5 firearms into the safe tables.
Deterministic; safe to re-run.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
TAG = "district_weapon"
BANDS = ["dry", "shallows", "cold", "dark", "crush"]
DISTRICTS = ["industrial", "construction", "business", "residential", "commercial", "civil"]
STATION_OF_BAND = {1: "workbench", 2: "workbench", 3: "forge", 4: "forge", 5: "forge"}

# --- Melee roster: id -> (name, class, tool, first band, home district, desc) ---------------
# class: knife / blade / axe / blunt / pierce / pry / powered / reach
# tool: (type, tier) or None
MELEE = {
    "baseball_bat": ("Baseball Bat", "blunt", None, 1, "residential", "Ash and tape. Swings quick, hits fair."),
    "baton": ("Baton", "blunt", None, 1, "civil", "Issue nightstick. Fast, light, forgettable."),
    "crowbar": ("Crowbar", "pry", ("pry", 2), 1, "industrial", "Pries chained doors and skulls alike."),
    "desk_leg": ("Desk Leg", "blunt", None, 1, "business", "Unscrewed in a hurry. Better than nothing."),
    "fire_extinguisher": ("Fire Extinguisher", "blunt", None, 1, "business", "Slow, heavy, and it rings when it lands."),
    "fireplace_poker": ("Fireplace Poker", "pierce", None, 1, "residential", "Wrought iron with a hook. Reaches."),
    "halligan_tool": ("Halligan Tool", "pry", ("pry", 2), 1, "civil", "Fire-crew entry bar: fork, adze and pick."),
    "hatchet": ("Hatchet", "axe", ("axe", 1), 1, "industrial", "One-hand axe. Fells saplings, opens zombies."),
    "kitchen_knife": ("Kitchen Knife", "knife", ("knife", 1), 1, "residential", "A cook's blade. Quick, and fine underwater."),
    "letter_opener": ("Letter Opener", "knife", ("knife", 1), 1, "business", "Brass and pointless - until it isn't."),
    "machete": ("Machete", "blade", None, 1, "commercial", "Hardware-aisle steel. Wide, fast cuts."),
    "nail_puller": ("Nail Puller", "pry", ("pry", 1), 1, "construction", "Cat's paw. Levers boards and doors."),
    "paper_cutter": ("Paper Cutter", "blade", None, 1, "business", "The guillotine arm off an office cutter. Slow, mean."),
    "pipe_wrench": ("Pipe Wrench", "blunt", None, 1, "industrial", "Two kilos of cast iron on a handle."),
    "rebar_club": ("Rebar Club", "blunt", None, 1, "construction", "Bent rebar, taped grip. Sends things flying."),
    "rescue_axe": ("Rescue Axe", "axe", ("axe", 1), 1, "civil", "Short fire axe with a pick. Balanced."),
    "stapler": ("Stapler", "blunt", None, 1, "business", "Industrial stapler. Someone's last stand."),
    "utility_knife": ("Utility Knife", "knife", ("knife", 1), 1, "commercial", "Box cutter. Quick, fine underwater, breaks nothing."),
    "boarding_axe": ("Boarding Axe", "axe", ("axe", 2), 2, "commercial", "Marine axe with a spike. Bites underwater."),
    "breaching_tool": ("Breaching Tool", "pry", ("pry", 2), 2, "business", "Security entry bar. Pries and pounds."),
    "demolition_hammer": ("Demolition Hammer", "powered", ("hammer", 3), 2, "construction", "Powered breaker. Slow wind-up, brutal landing."),
    "security_flashlight": ("Security Flashlight", "blunt", None, 2, "business", "Four D-cells of aluminium. Lights the way, too."),
    "lump_hammer": ("Lump Hammer", "blunt", ("hammer", 2), 2, "residential", "Short sledge. Cracks stone and bone."),
    "cane_machete": ("Cane Machete", "blade", None, 2, "commercial", "Long field blade. Wide sweeps."),
    "pickaxe": ("Pickaxe", "pierce", ("hammer", 2), 2, "industrial", "Digs, breaks stone, punches through ribs."),
    "rescue_saw": ("Rescue Saw", "powered", None, 2, "civil", "Powered rescue saw. Chews through anything soft."),
    "riot_baton": ("Riot Baton", "blunt", None, 2, "business", "Polycarbonate riot stick. Fast and hard."),
    "sledgehammer": ("Sledgehammer", "blunt", ("hammer", 2), 2, "industrial", "Ten pounds on a hickory haft."),
    "spear": ("Spear", "pierce", None, 2, "commercial", "Boar spear. Thrusts work underwater."),
    "splitting_maul": ("Splitting Maul", "axe", ("axe", 2), 2, "industrial", "Axe on one side, sledge on the other."),
    "breaching_hammer": ("Breaching Hammer", "blunt", ("hammer", 3), 3, "industrial", "Entry sledge. Doors, walls, heads."),
    "dive_knife": ("Dive Knife", "knife", ("knife", 2), 3, "commercial", "Titanium dive blade. Made for the water."),
    "harpoon": ("Harpoon", "pierce", None, 3, "commercial", "Barbed hand harpoon. Thrusts hard underwater."),
    "felling_axe": ("Felling Axe", "axe", ("axe", 3), 3, "industrial", "Full-size timber axe. Fells anything."),
    "pinch_bar": ("Pinch Bar", "pry", ("pry", 2), 3, "construction", "Long pry bar. Leverage is damage."),
    "broad_hatchet": ("Broad Hatchet", "axe", ("axe", 2), 3, "residential", "Wide-bit hewing hatchet."),
    "hunting_knife": ("Hunting Knife", "knife", ("knife", 3), 3, "residential", "Drop-point blade. Quick and deep."),
    "industrial_cutter": ("Industrial Cutter", "powered", None, 3, "industrial", "Bench cutter torn off its stand. Spins up, then shreds."),
    "breaching_sledge": ("Breaching Sledge", "blunt", ("hammer", 3), 4, "construction", "Entry team sledge. Sends things through walls."),
    "mattock": ("Mattock", "pierce", ("hammer", 3), 4, "construction", "Pick and adze. Breaks ground, breaks bone."),
    "hydraulic_cutter": ("Hydraulic Cutter", "powered", ("pry", 3), 4, "industrial", "Rescue jaws. Opens vault doors and ribcages."),
    "industrial_saw": ("Industrial Saw", "powered", None, 4, "industrial", "Powered circular saw. Fast, loud, wide."),
    "pole_hook": ("Pole Hook", "reach", None, 4, "construction", "Long pike pole. Hooks and pulls at reach."),
    "rescue_spreader": ("Rescue Spreader", "powered", ("pry", 3), 4, "civil", "Hydraulic spreader. Pries anything, hits like a truck."),
    "breaching_maul": ("Breaching Maul", "blunt", ("hammer", 3), 5, "industrial", "The biggest hammer in the city."),
    "shock_baton": ("Shock Baton", "blunt", None, 5, "business", "Executive-floor security stick. Fast, and it bites."),
    "whaling_harpoon": ("Whaling Harpoon", "pierce", None, 5, "commercial", "Iron whaling iron. Thrusts to the hilt underwater."),
    "tactical_axe": ("Tactical Axe", "axe", ("axe", 3), 5, "business", "Black-anodised breaching axe."),
}

# --- Ranged roster: id -> (name, class, ammo, first band, home district, desc) -------------
# class: pistol / smg / rifle / shotgun / bow / crossbow / nailgun / speargun / harpoongun / flare
RANGED = {
    "rifle_22": (".22 Rifle", "rifle_light", "pistol_rounds", 1, "residential", "Plinker. Light rounds, quiet, cheap."),
    "compact_pistol": ("Compact Pistol", "pistol", "pistol_rounds", 1, "business", "Pocket pistol from a desk drawer."),
    "compound_bow": ("Compound Bow", "bow", "arrows", 1, "commercial", "Sporting compound. Silent; arrows come back."),
    "crossbow": ("Crossbow", "crossbow", "crossbow_bolts", 1, "construction", "Hunting crossbow. Slow to span, hits hard."),
    "flare_gun": ("Flare Gun", "flare", "flares", 1, "industrial", "Fires a burning flare that lights where it lands."),
    "hunting_rifle": ("Hunting Rifle", "rifle", "rifle_rounds", 1, "residential", "Scoped deer rifle. One heavy answer."),
    "nail_gun": ("Nail Gun", "nailgun", "nails", 1, "industrial", "Framing nailer with the safety filed off."),
    "pellet_gun": ("Pellet Gun", "pistol_weak", "pistol_rounds", 1, "commercial", "Air pistol. Stings."),
    "revolver": ("Revolver", "pistol", "pistol_rounds", 1, "business", "Six rounds, no jams."),
    "service_pistol": ("Service Pistol", "pistol", "pistol_rounds", 1, "civil", "Issue sidearm. Reliable."),
    "patrol_shotgun": ("Patrol Shotgun", "shotgun", "shotgun_shells", 2, "civil", "Cruiser gun. Close work."),
    "pump_shotgun": ("Pump Shotgun", "shotgun", "shotgun_shells", 2, "residential", "Bird gun from a hall closet."),
    "rivet_gun": ("Rivet Gun", "nailgun", "rivets", 2, "industrial", "Pneumatic riveter. Hot rivets, fast."),
    "harpoon_gun": ("Harpoon Gun", "harpoongun", "harpoon", 3, "commercial", "Pneumatic harpoon launcher. Underwater artillery."),
    "compound_crossbow": ("Compound Crossbow", "crossbow", "crossbow_bolts", 3, "construction", "Cammed crossbow. Faster, harder."),
    "patrol_rifle": ("Patrol Rifle", "rifle", "rifle_rounds", 3, "civil", "Trunk rifle. Semi-auto."),
    "riot_shotgun": ("Riot Shotgun", "shotgun", "shotgun_shells", 3, "civil", "Short riot gun. Wide pattern."),
    "tactical_pistol": ("Tactical Pistol", "pistol", "pistol_rounds", 3, "business", "Rail, light, big magazine."),
    "assault_carbine": ("Assault Carbine", "carbine", "rifle_rounds", 4, "civil", "Police carbine. Fast follow-ups."),
    "framing_nailer": ("Framing Nailer", "nailgun", "nails", 4, "industrial", "Heavy-duty nailer. Longer nails, more of them."),
    "hunting_magnum": ("Hunting Magnum", "rifle", "rifle_rounds", 4, "residential", "Magnum rifle. Stops anything once."),
    "machine_pistol": ("Machine Pistol", "smg", "pistol_rounds", 4, "business", "Full-auto pocket gun. Empties fast."),
    "semi_auto_rifle": ("Semi-Auto Rifle", "rifle", "rifle_rounds", 4, "industrial", "Ranch rifle. Quick and accurate."),
    "semi_auto_shotgun": ("Semi-Auto Shotgun", "shotgun", "shotgun_shells", 4, "residential", "Gas gun. Fast shells."),
    "tactical_carbine": ("Tactical Carbine", "carbine", "rifle_rounds", 4, "business", "Corporate security carbine."),
    "tactical_shotgun": ("Tactical Shotgun", "shotgun", "shotgun_shells", 4, "civil", "Entry shotgun. Tight, hard pattern."),
    "battle_rifle": ("Battle Rifle", "rifle", "rifle_rounds", 5, "industrial", "Full-power rifle. Heavy, decisive."),
    "combat_shotgun": ("Combat Shotgun", "shotgun", "shotgun_shells", 5, "civil", "Auto shotgun. The last word up close."),
    "dmr": ("Designated Marksman Rifle", "rifle", "rifle_rounds", 5, "civil", "Precision rifle. One round, one drop."),
    "whaling_gun": ("Whaling Gun", "harpoongun", "harpoon", 5, "commercial", "Deck-mounted harpoon gun, carried anyway."),
    "industrial_rivet_gun": ("Industrial Rivet Gun", "nailgun", "rivets", 5, "industrial", "Shipyard riveter. Hot steel at speed."),
    "marksman_rifle": ("Marksman Rifle", "rifle", "rifle_rounds", 5, "construction", "Site security rifle, glassed and tuned."),
    "military_carbine": ("Military Carbine", "carbine", "rifle_rounds", 5, "business", "Executive protection carbine."),
    "sniper_rifle": ("Sniper Rifle", "rifle", "rifle_rounds", 5, "residential", "Private collection long rifle. Slow, final."),
}
# Existing items that keep their ids but take the roster names.
RENAMES = {"pistol": "9mm Pistol", "smg": "Compact SMG", "rifle": "Bolt-Action Rifle", "speargun": "Spear Gun"}
# Table names -> item ids for existing items.
EXISTING = {"Hammer": "hammer", "Pry Bar": "pry_bar", "Bolt Cutters": "bolt_cutters", "Fire Axe": "fire_axe",
            "9mm Pistol": "pistol", "Compact SMG": "smg", "Bolt-Action Rifle": "rifle", "Spear Gun": "speargun"}

AMMO = {
    "shotgun_shells": ("Shotgun Shells", "12-gauge buck. Six pellets a shell.", 0.05, 48, None, None),
    "arrows": ("Arrows", "Field arrows. Fly true, fall slow, come back.", 0.05, 40, {"speed": 40.0, "gravity": 0.35, "retrievable": True}, None),
    "crossbow_bolts": ("Crossbow Bolts", "Short heavy bolts. Retrievable.", 0.06, 40, {"speed": 48.0, "gravity": 0.3, "retrievable": True}, None),
    "nails": ("Nails", "Framing nails. Gone once fired.", 0.01, 200, {"speed": 52.0, "gravity": 0.2, "retrievable": False}, None),
    "rivets": ("Rivets", "Hot rivets. Gone once fired.", 0.02, 200, {"speed": 56.0, "gravity": 0.2, "retrievable": False}, None),
    "flares": ("Flares", "Burning flares. Light where they land.", 0.1, 20, {"speed": 30.0, "gravity": 0.5, "retrievable": True},
               {"drop_light": {"color": [1.0, 0.45, 0.3], "radius_blocks": 6.0}}),
    "harpoon": ("Harpoon Bolt", "Barbed harpoon. Heavy, retrievable.", 0.3, 12, {"speed": 38.0, "gravity": 0.5, "retrievable": True}, None),
}
AMMO_RECIPES = {
    "arrows": ("workbench", 1, 8, [("wood", 2), ("scrap_metal", 1)]),
    "crossbow_bolts": ("workbench", 1, 6, [("wood", 1), ("scrap_metal", 1)]),
    "nails": ("workbench", 1, 20, [("scrap_metal", 1)]),
    "flares": ("workbench", 2, 4, [("plastic", 2), ("cloth", 1)]),
    "rivets": ("forge", 2, 20, [("iron", 1)]),
    "shotgun_shells": ("forge", 2, 8, [("scrap_metal", 3), ("plastic", 1)]),
    "harpoon": ("forge", 3, 2, [("iron", 2)]),
}

# --- Stats -------------------------------------------------------------------------------
MELEE_DMG = {1: 5.0, 2: 8.0, 3: 12.0, 4: 17.0, 5: 23.0}
MELEE_CLASS = {  # class: (damage mult, speed, knockback, water_factor, weight)
    "knife": (0.65, 2.2, 3.0, 0.8, 0.8),
    "blade": (0.9, 1.7, 8.0, 0.55, 1.6),
    "axe": (1.05, 1.1, 16.0, 0.45, 3.0),
    "blunt": (1.0, 1.3, 14.0, 0.5, 2.5),
    "pierce": (0.85, 1.4, 10.0, 0.9, 2.0),
    "pry": (0.9, 1.2, 12.0, 0.5, 3.0),
    "powered": (1.3, 0.9, 12.0, 0.35, 5.0),
    "reach": (0.9, 1.0, 18.0, 0.6, 3.5),
}
DISTRICT_MELEE = {  # (damage, speed, knockback, water_factor add)
    "industrial": (1.15, 1.0, 1.0, 0.0), "construction": (1.0, 1.0, 1.4, 0.0), "business": (0.95, 1.2, 1.0, 0.0),
    "residential": (0.9, 1.0, 1.0, 0.0), "commercial": (1.0, 1.0, 1.0, 0.15), "civil": (1.05, 1.05, 1.1, 0.0),
}
RANGED_CLASS = {  # class: dict of weapon fields by band (damage per shot/pellet), speed, extras
    "pistol": {"dmg": {1: 8, 2: 10, 3: 13, 4: 16, 5: 20}, "speed": 2.0, "reload": 1.0},
    "pistol_weak": {"dmg": {1: 4, 2: 5, 3: 6, 4: 7, 5: 8}, "speed": 1.6, "reload": 1.0},
    "smg": {"dmg": {1: 6, 2: 7, 3: 8, 4: 10, 5: 12}, "speed": 6.0, "reload": 1.8},
    "rifle_light": {"dmg": {1: 7, 2: 9, 3: 11, 4: 13, 5: 16}, "speed": 1.4, "reload": 1.4, "range_blocks": 60},
    "rifle": {"dmg": {1: 18, 2: 22, 3: 27, 4: 32, 5: 40}, "speed": 0.8, "reload": 2.2, "range_blocks": 70},
    "carbine": {"dmg": {1: 12, 2: 14, 3: 17, 4: 20, 5: 24}, "speed": 3.5, "reload": 1.8, "range_blocks": 56},
    "shotgun": {"dmg": {1: 4, 2: 5, 3: 6, 4: 8, 5: 10}, "speed": 0.9, "reload": 2.0, "pellets": 6, "spread": 12.0, "range_blocks": 18},
    "bow": {"dmg": {1: 10, 2: 13, 3: 16, 4: 20, 5: 24}, "speed": 1.0},
    "crossbow": {"dmg": {1: 14, 2: 18, 3: 22, 4: 27, 5: 34}, "speed": 0.6},
    "nailgun": {"dmg": {1: 4, 2: 5, 3: 6, 4: 8, 5: 10}, "speed": 4.5},
    "speargun": {"dmg": {1: 12, 2: 14, 3: 17, 4: 20, 5: 24}, "speed": 0.8},
    "harpoongun": {"dmg": {1: 20, 2: 24, 3: 28, 4: 34, 5: 42}, "speed": 0.5},
    "flare": {"dmg": {1: 3, 2: 3, 3: 4, 4: 4, 5: 5}, "speed": 0.7},
}
PROJECTILE_CLASSES = {"bow", "crossbow", "nailgun", "speargun", "harpoongun", "flare"}
SCRAP_BY_BAND = {
    1: [("scrap_metal", 2), ("wood", 1)], 2: [("scrap_metal", 3)], 3: [("iron", 2)],
    4: [("steel", 1), ("iron", 1)], 5: [("steel", 2)],
}
MELEE_RECIPE = {  # band: inputs (the 5x tool economy)
    1: [("scrap_metal", 5), ("wood", 3)], 2: [("scrap_metal", 10), ("wood", 4)],
    3: [("iron", 15), ("wood", 5)], 4: [("steel", 10), ("iron", 5)], 5: [("steel", 20), ("iron", 5)],
}

# --- Placement matrix (Weapons.md §5) ----------------------------------------------------
MELEE_MATRIX = """
1|Industrial|Hammer, Hatchet, Crowbar, Pipe Wrench, Pry Bar
1|Construction|Hammer, Pry Bar, Nail Puller, Bolt Cutters, Rebar Club
1|Business|Letter Opener, Stapler, Paper Cutter, Desk Leg, Fire Extinguisher
1|Residential|Kitchen Knife, Baseball Bat, Hatchet, Hammer, Fireplace Poker
1|Commercial|Machete, Hatchet, Hammer, Baseball Bat, Utility Knife
1|Civil|Fire Axe, Rescue Axe, Baton, Crowbar, Halligan Tool
2|Industrial|Sledgehammer, Pipe Wrench, Splitting Maul, Pickaxe, Rescue Saw
2|Construction|Sledgehammer, Bolt Cutters, Pickaxe, Rebar Club, Demolition Hammer
2|Business|Riot Baton, Fire Axe, Crowbar, Security Flashlight, Breaching Tool
2|Residential|Splitting Maul, Hatchet, Machete, Pickaxe, Lump Hammer
2|Commercial|Boarding Axe, Spear, Cane Machete, Pickaxe, Crowbar
2|Civil|Rescue Axe, Halligan Tool, Riot Baton, Bolt Cutters, Crowbar
3|Industrial|Breaching Hammer, Felling Axe, Rescue Saw, Sledgehammer, Industrial Cutter
3|Construction|Breaching Hammer, Demolition Hammer, Pinch Bar, Pickaxe, Bolt Cutters
3|Business|Riot Baton, Breaching Tool, Fire Axe, Rescue Saw, Security Flashlight
3|Residential|Hunting Knife, Fire Axe, Pickaxe, Broad Hatchet, Crowbar
3|Commercial|Spear, Boarding Axe, Dive Knife, Harpoon, Cane Machete
3|Civil|Halligan Tool, Rescue Axe, Riot Baton, Breaching Hammer, Rescue Saw
4|Industrial|Industrial Saw, Demolition Hammer, Sledgehammer, Hydraulic Cutter, Felling Axe
4|Construction|Breaching Sledge, Hydraulic Cutter, Demolition Hammer, Mattock, Pole Hook
4|Business|Breaching Tool, Riot Baton, Rescue Saw, Felling Axe
4|Residential|Hunting Knife, Splitting Maul, Felling Axe, Spear
4|Commercial|Harpoon, Dive Knife, Boarding Axe, Pole Hook
4|Civil|Breaching Sledge, Halligan Tool, Rescue Spreader, Rescue Saw
5|Industrial|Hydraulic Cutter, Industrial Saw, Demolition Hammer, Breaching Maul, Rescue Spreader
5|Construction|Breaching Maul, Hydraulic Cutter, Demolition Hammer, Breaching Sledge, Pole Hook
5|Business|Breaching Tool, Rescue Saw, Shock Baton, Tactical Axe
5|Residential|Hunting Knife, Felling Axe, Spear, Demolition Hammer
5|Commercial|Whaling Harpoon, Dive Knife, Boarding Axe, Pole Hook
5|Civil|Rescue Spreader, Breaching Sledge, Halligan Tool, Rescue Saw
"""
RANGED_MATRIX = """
1|Industrial|Nail Gun, Flare Gun
1|Construction|Nail Gun, Crossbow
1|Business|Compact Pistol, Revolver
1|Residential|Hunting Rifle, .22 Rifle
1|Commercial|Compound Bow, Pellet Gun
1|Civil|Flare Gun, Service Pistol
2|Industrial|Rivet Gun, Nail Gun
2|Construction|Crossbow, Compound Bow
2|Business|9mm Pistol, Compact SMG
2|Residential|Pump Shotgun, Hunting Rifle
2|Commercial|Spear Gun, Crossbow
2|Civil|Patrol Shotgun, Service Pistol
3|Industrial|Nail Gun, Hunting Rifle
3|Construction|Compound Crossbow, Compound Bow
3|Business|Tactical Pistol, Compact SMG
3|Residential|Bolt-Action Rifle, Pump Shotgun
3|Commercial|Harpoon Gun, Spear Gun
3|Civil|Patrol Rifle, Riot Shotgun
4|Industrial|Framing Nailer, Semi-Auto Rifle
4|Construction|Compound Crossbow, Bolt-Action Rifle
4|Business|Machine Pistol, Tactical Carbine
4|Residential|Hunting Magnum, Semi-Auto Shotgun, Compound Bow
4|Commercial|Harpoon Gun, Spear Gun
4|Civil|Assault Carbine, Tactical Shotgun
5|Industrial|Industrial Rivet Gun, Battle Rifle
5|Construction|Compound Crossbow, Marksman Rifle
5|Business|Tactical Pistol, Military Carbine
5|Residential|Hunting Magnum, Sniper Rifle, Compound Bow
5|Commercial|Whaling Gun, Spear Gun
5|Civil|Designated Marksman Rifle, Combat Shotgun
"""


def load(name):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def save(name, obj):
    (DATA / name).write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def name_to_id():
    m = {v[0]: k for k, v in MELEE.items()}
    m.update({v[0]: k for k, v in RANGED.items()})
    m.update(EXISTING)
    return m


def parse_matrix(text):
    cells = {}
    for line in text.strip().splitlines():
        t, d, names = line.split("|")
        cells[(int(t), d.lower())] = [n.strip() for n in names.split(",")]
    return cells


def melee_item(mid):
    name, cls, tool, band, district, desc = MELEE[mid]
    dm, spd, kb, wf, wt = MELEE_CLASS[cls]
    ddm, dspd, dkb, dwf = DISTRICT_MELEE[district]
    weapon = {
        "melee": True,
        "damage": round(MELEE_DMG[band] * dm * ddm, 1),
        "speed": round(spd * dspd, 2),
        "knockback": round(kb * dkb, 1),
        "water_factor": round(min(wf + dwf, 0.95), 2),
    }
    it = {"id": mid, "name": name, "category": "weapon", "desc": desc, "weight": round(wt + band * 0.3, 1),
          "stack": 1, "weapon": weapon, "scrap": [{"item": i, "count": c} for i, c in SCRAP_BY_BAND[band]],
          TAG: True, "band": band, "district": district}
    if tool:
        ttype, ttier = tool
        it["tool"] = {"type": ttype, "tier": ttier, "damage": round(weapon["damage"] * 0.6, 1), "speed": weapon["speed"]}
    return it


def ranged_item(rid):
    name, cls, ammo, band, district, desc = RANGED[rid]
    c = RANGED_CLASS[cls]
    weapon = {"damage": float(c["dmg"][band]), "speed": c["speed"]}
    if cls in PROJECTILE_CLASSES:
        weapon["projectile"] = ammo
    else:
        weapon["ammo"] = ammo
        weapon["reload"] = c.get("reload", 1.5)
    for k in ("pellets", "spread", "range_blocks"):
        if k in c:
            weapon[k] = c[k]
    weight = {"pistol": 1.5, "pistol_weak": 1.0, "smg": 3.0, "rifle_light": 2.5, "rifle": 4.0, "carbine": 3.5,
              "shotgun": 3.5, "bow": 1.5, "crossbow": 3.0, "nailgun": 3.0, "speargun": 2.5, "harpoongun": 5.0, "flare": 0.8}[cls]
    it = {"id": rid, "name": name, "category": "weapon", "desc": desc + (" Found only." if cls not in PROJECTILE_CLASSES else ""),
          "weight": weight, "stack": 1, "weapon": weapon,
          "scrap": [{"item": i, "count": c2} for i, c2 in SCRAP_BY_BAND[band]],
          TAG: True, "band": band, "district": district}
    if cls not in PROJECTILE_CLASSES:
        it["found_only"] = True
    return it


def ammo_item(aid):
    name, desc, weight, stack, proj, use = AMMO[aid]
    it = {"id": aid, "name": name, "category": "ammo", "desc": desc, "weight": weight, "stack": stack, TAG: True}
    if proj:
        it["projectile"] = proj
    if use:
        it["use"] = use
    return it


def merge_items():
    data = load("items.json")
    items = [it for it in data["items"] if not it.get(TAG)]
    by_id = {it["id"]: it for it in items}
    for old, new in RENAMES.items():
        if old in by_id:
            by_id[old]["name"] = new
    new_items = [ammo_item(a) for a in AMMO] + [melee_item(m) for m in MELEE] + [ranged_item(r) for r in RANGED]
    for it in new_items:
        assert it["id"] not in by_id, "id clash with a hand-written item: " + it["id"]
    data["items"] = items + new_items
    save("items.json", data)
    return len(new_items)


def merge_recipes():
    data = load("recipes.json")
    recipes = [r for r in data["recipes"] if not r.get(TAG)]
    have = {r["id"] for r in recipes}
    new = []
    for mid, (name, cls, tool, band, district, desc) in MELEE.items():
        rid = mid
        assert rid not in have, rid
        new.append({"id": rid, "station": STATION_OF_BAND[band], "tier": band, "known": True,
                    "output": {"item": mid, "count": 1},
                    "inputs": [{"item": i, "count": c} for i, c in MELEE_RECIPE[band]], TAG: True})
    for aid, (station, tier, count, inputs) in AMMO_RECIPES.items():
        new.append({"id": aid, "station": station, "tier": tier, "known": True,
                    "output": {"item": aid, "count": count},
                    "inputs": [{"item": i, "count": c} for i, c in inputs], TAG: True})
    data["recipes"] = recipes + new
    save("recipes.json", data)
    return len(new)


def merge_loot():
    data = load("loot.json")
    tables = data["tables"]
    ids = name_to_id()
    melee = parse_matrix(MELEE_MATRIX)
    ranged = parse_matrix(RANGED_MATRIX)
    # Strip earlier generated entries, then make sure every district has all five bands.
    for zone in tables:
        for band in list(tables[zone].keys()):
            tables[zone][band] = [e for e in tables[zone][band] if not e.get(TAG)]
    for d in DISTRICTS:
        tables.setdefault(d, {})
        for band in BANDS:
            if band not in tables[d] or not tables[d][band]:
                tables[d][band] = [dict(e) for e in tables["generic"].get(band, [])]
    ammo_of = {rid: v[2] for rid, v in RANGED.items()}
    ammo_of.update({"pistol": "pistol_rounds", "smg": "pistol_rounds", "rifle": "rifle_rounds", "speargun": "speargun_bolt"})
    count = 0
    for (tier, d), names in melee.items():
        band = BANDS[tier - 1]
        for i, n in enumerate(names):
            iid = ids[n]
            tables[d][band].append({"item": iid, "min": 1, "max": 1, "w": 3 if i == 0 else 2, TAG: True})
            count += 1
    for (tier, d), names in ranged.items():
        band = BANDS[tier - 1]
        seen_ammo = set()
        for n in names:
            iid = ids[n]
            tables[d][band].append({"item": iid, "min": 1, "max": 1, "w": 2, TAG: True})
            count += 1
            a = ammo_of[iid]
            if a not in seen_ammo:
                seen_ammo.add(a)
                stack = 12 if a in ("pistol_rounds", "rifle_rounds", "shotgun_shells", "nails", "rivets") else 6
                tables[d][band].append({"item": a, "min": max(2, stack // 3), "max": stack, "w": 3, TAG: True})
    # Safes: the deep firearms.
    for rid, (name, cls, ammo, band, district, desc) in RANGED.items():
        if band >= 4 and cls not in PROJECTILE_CLASSES:
            tables["safe"].setdefault(BANDS[band - 1], []).append({"item": rid, "min": 1, "max": 1, "w": 1, TAG: True})
            count += 1
    save("loot.json", data)
    return count


def main():
    n_items = merge_items()
    n_recipes = merge_recipes()
    n_loot = merge_loot()
    print("items +%d, recipes +%d, loot entries +%d" % (n_items, n_recipes, n_loot))


if __name__ == "__main__":
    main()

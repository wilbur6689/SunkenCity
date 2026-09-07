"""Build the district flora: sway strips + objects.json entries + seed items.

    python tools/build_flora.py            # every district module in tools/flora_art
    python tools/build_flora.py res        # one district

For each species x stage in a district module's SPECIES dict the rest frame is
drawn (deterministic seed per id), turned into a sway strip (frame 0 = rest,
base rows pinned, free end shears left) and written to
assets/sprites/objects/<id>.png. objects.json entries are merged under the
`generated_flora: true` tag: every tagged entry not produced by this run is
dropped, hand-authored (`authored: true`) entries are never touched and an
existing entry with the same id that is NOT tagged is left alone (rename the
species instead). Tree species also get a seed ITEM (`plants` = the seedling
id) and a 16 px icon - an existing icon file is kept (ICONS_FORCE=1 redraws).

Growth: `<id>_seedling` -> `<id>_midling` -> `<id>` (grows_into), every stage
category flora with `district` set so CityGen._stamp_roofs can pick the
tower's own set. Harvest tables scale with the stage (docs/Flora/flora.md 4.3).
"""
from __future__ import annotations

import importlib
import json
import os
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART_DIR = ROOT / "tools" / "flora_art"
sys.path.insert(0, str(ART_DIR))

import common  # noqa: E402  (tools/flora_art/common.py)

OBJECTS = ROOT / "data" / "objects.json"
ITEMS = ROOT / "data" / "items.json"
SPRITES = ROOT / "assets" / "sprites" / "objects"
ICONS = ROOT / "assets" / "sprites" / "icons"
FORCE_ICONS = os.environ.get("ICONS_FORCE") == "1"
TAG = "generated_flora"
STAGE_SUFFIX = ["_seedling", "_midling", ""]
STAGE_LABEL = ["Seedling", "Young", ""]

# spawn bias per stage (flora_weight) by slot: a living roof has young plants
# on it, but the Stage-1 wood economy wants grown trees standing at the start.
WEIGHTS = {"tree": (2, 1, 2), "shrub": (1, 1, 2), "grass": (1, 1, 3)}


def _yield(item, lo, hi):
    return {"item": item, "min": lo, "max": hi}


def harvest(slot, stage, w, h, species_id, spec):
    """Per-stage harvest table + gating (docs/Flora/flora.md 4.3)."""
    seed_id = species_id + "_seed" if spec.get("seed") else None
    if slot == "tree":
        size_class = "large" if h >= 20 else ("medium" if h >= 14 else "small")
        if stage == 0:
            y = [_yield("wood", 1, 2)] + ([_yield(seed_id, 0, 1)] if seed_id else [])
            return dict(yields=y, scrap_time=1.0, weight=2, tool_tier=0, skill=0, xp=2)
        if stage == 1:
            y = [_yield("wood", 3, 8)] + ([_yield(seed_id, 0, 1)] if seed_id else [])
            return dict(yields=y, scrap_time=5.0, weight=30, tool_tier=0, skill=0, xp=6,
                        requires_tool="axe", no_item=True)
        wood = {"large": (25, 40), "medium": (12, 20), "small": (6, 10)}[size_class]
        secs = {"large": 14.0, "medium": 10.0, "small": 7.0}[size_class]
        y = [_yield("wood", *wood)] + ([_yield(seed_id, 1, 3)] if seed_id else [])
        return dict(yields=y, scrap_time=secs, weight=90, tool_tier=1, skill=1, xp=12,
                    requires_tool="axe", no_item=True)
    if slot == "shrub":
        wood = [(1, 1), (1, 2), (2, 4)][stage]
        return dict(yields=[_yield("wood", *wood)], scrap_time=[0.8, 1.2, 1.5][stage],
                    weight=[2, 4, 6][stage], tool_tier=0, skill=0, xp=[1, 2, 2][stage])
    # grass
    y = [_yield("stone", 1, 2)]
    if "clover" in species_id:
        y.append(_yield("organic_material", 0, 1))
    return dict(yields=y, scrap_time=0.5, weight=1, tool_tier=0, skill=0, xp=1)


def build_district(mod_name, lib_objects, lib_items, report):
    mod = importlib.import_module(mod_name)
    district = mod.DISTRICT
    made = {}
    for sid, spec in mod.SPECIES.items():
        slot = spec["slot"]
        for stage, (w, h) in enumerate(spec["stages"]):
            oid = sid + STAGE_SUFFIX[stage]
            W, H = w * common.CELL, h * common.CELL
            rng = random.Random(sum(ord(ch) for ch in oid) * 7919 + stage)
            canvas = spec["draw"](stage, W, H, rng)
            rest = canvas.img
            pin = spec["pin"](stage, H)
            amp = common.amplitude(H - pin)
            if slot == "grass":
                amp = 1
            leaf = mod.LEAF_OF(sid)
            frames = common.sway_frames(rest, pin, amp, glint_pair=(leaf[5], leaf[4]) if leaf else None)
            img = common.strip(frames)
            img.save(SPRITES / f"{oid}.png")
            name = spec["name"] if stage == 2 else f"{spec['name']} {STAGE_LABEL[stage]}"
            weight_bias = getattr(mod, "WEIGHTS", WEIGHTS)[slot][stage]  # a module may bias its own stages (construction: 5:2:1)
            room_type = {"tree": "tree", "shrub": "bush", "grass": "grass"}[slot]
            entry = {
                "id": oid, "name": name, "category": "flora", "kind": "scrap",
                "room_type": room_type, "zones": ["roof"], "district": district, TAG: True,
                "size": [w, h], "flora_weight": weight_bias, "frames": len(frames),
                "grow_chance": 1.0,
            }
            entry.update(harvest(slot, stage, w, h, sid, spec))
            if stage < 2:
                entry["grows_into"] = sid + STAGE_SUFFIX[stage + 1]
            if stage == 0 and spec.get("desc"):
                entry["desc"] = spec["desc"]
            if slot == "tree" and stage == 2:
                entry["desc"] = "Fell it with an axe for wood and its seeds."
            made[oid] = entry
            report.append((oid, W, H, len(frames), common.palette_count(img)))
        if spec.get("seed"):
            seed = spec["seed"]
            item_id = sid + "_seed"
            lib_items[item_id] = {
                "id": item_id, "name": seed["name"], "category": "seed", "stack": 20, "weight": 0.1,
                "plants": sid + "_seedling", TAG: True,
                "desc": f"Plant it in a planter. Under open sky it grows into {spec['name'].lower()} to fell for wood.",
            }
            icon = ICONS / f"{item_id}.png"
            if FORCE_ICONS or not icon.exists():
                common.seed_icon(seed["kind"], seed["tint"]).save(icon)
    lib_objects.update(made)
    return made


def main(argv):
    mods = [a for a in argv if not a.startswith("-")]
    if not mods:
        mods = sorted(p.stem for p in ART_DIR.glob("*.py") if p.stem not in ("common", "preview", "__init__"))
    objects_doc = json.loads(OBJECTS.read_text(encoding="utf-8"))
    items_doc = json.loads(ITEMS.read_text(encoding="utf-8"))
    objs = objects_doc["objects"]
    items = items_doc["items"]
    keep_objs = [o for o in objs if not o.get(TAG)]
    old_tagged = {o["id"] for o in objs if o.get(TAG)}
    keep_items = [it for it in items if not it.get(TAG)]
    new_objs, new_items, report = {}, {}, []
    for m in mods:
        build_district(m, new_objs, new_items, report)
    fixed = {o["id"] for o in keep_objs}
    clash = [oid for oid in new_objs if oid in fixed]
    if clash:
        sys.exit(f"refusing to replace untagged/authored objects: {clash}")
    for oid in sorted(old_tagged - set(new_objs)):
        png = SPRITES / f"{oid}.png"
        if png.exists():
            png.unlink()
        for imp in (SPRITES / f"{oid}.png.import",):
            if imp.exists():
                imp.unlink()
        print(f"  dropped stale {oid}")
    objects_doc["objects"] = keep_objs + [new_objs[k] for k in sorted(new_objs)]
    items_doc["items"] = keep_items + [new_items[k] for k in sorted(new_items)]
    OBJECTS.write_text(json.dumps(objects_doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    ITEMS.write_text(json.dumps(items_doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for (oid, W, H, fr, pal) in report:
        print(f"  {oid:22s} {W:3d}x{H:<3d} frames={fr} colours={pal}")
    print(f"{len(new_objs)} flora objects, {len(new_items)} seed items -> {OBJECTS.name}, {ITEMS.name}")


if __name__ == "__main__":
    main(sys.argv[1:])

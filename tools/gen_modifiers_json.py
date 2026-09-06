"""Build data/modifiers.json (v2, ModifiersImpl.md §4) from the merged name table.

    python tools/gen_modifiers_json.py

Names come from docs/modifiers/Merged_Modifiers.json (name -> id). Stats are the
per-family tables below: a tier-N base modifier is N x `stats_per_tier`; civil
carries explicit overrides so its cold rating steps in whole numbers. A first-
order hybrid blends both parents' tier-N stats at HYBRID_BLEND of their sum.
Deterministic; safe to re-run.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAMES = ROOT / "docs" / "modifiers" / "Merged_Modifiers.json"
OUT = ROOT / "data" / "modifiers.json"

HYBRID_BLEND = 0.7

FAMILIES = {
    # key: (slot, applies, stats_per_tier, label, color, blurb)
    "industrial": ("prefix", ["tool", "weapon"], {"tool_damage": 1.0}, "IND", [0.93, 0.55, 0.25],
                   "Raw damage. Found in the industrial towers."),
    "construction": ("prefix", ["tool", "weapon"], {"knockback": 3.0, "scrap_speed": 0.06}, "CON", [0.9, 0.78, 0.3],
                     "Knockback and demolition speed. Found on the construction sites."),
    "business": ("prefix", ["tool", "weapon"], {"tool_speed": 0.06}, "BUS", [0.4, 0.8, 0.75],
                 "Attack and tool speed. Found in the business district."),
    "residential": ("suffix", ["gear", "tool", "weapon"], {"weight_mult": -0.06, "carry": 2.0}, "RES", [0.75, 0.65, 0.45],
                    "Lighter gear, more carried weight. Found in the residential blocks."),
    "commercial": ("suffix", ["gear", "tool", "weapon"], {"oxygen": 6.0, "swim": 0.04}, "COM", [0.45, 0.7, 0.95],
                   "Air and swim speed. Found in the commercial district."),
    "civil": ("suffix", ["gear", "tool", "weapon"], {"defense": 1.0, "light": 1.0}, "CIV", [0.62, 0.68, 0.78],
              "Defence, cold resistance and light. Found in the civil buildings."),
}
# Explicit per-tier overrides (full stat dicts): civil's cold rating is a gate, not a slider.
OVERRIDES = {
    "civ_3": {"defense": 3.0, "light": 3.0, "cold": 1.0},
    "civ_4": {"defense": 4.0, "light": 4.0, "cold": 1.0},
    "civ_5": {"defense": 5.0, "light": 5.0, "cold": 2.0},
}
FAMILY_IDS = {"industrial": "ind", "construction": "con", "business": "bus",
              "residential": "res", "commercial": "com", "civil": "civ"}
HYBRIDS = {
    # pairroot: (family a, family b, blurb)
    "demolition": ("industrial", "construction", "Damage and knockback: the demolition trade."),
    "works": ("industrial", "business", "Damage and speed: the mill office."),
    "development": ("construction", "business", "Knockback and speed: permits and zoning."),
    "arcade": ("residential", "commercial", "Weight and swim: the high street."),
    "parish": ("residential", "civil", "Weight and defence: the neighbourhood."),
    "customs": ("commercial", "civil", "Air, cold and light: the market hall."),
}
JUNK = [
    {"id": "rusty", "name": "Rusty", "slot": "prefix", "applies": ["tool", "weapon"],
     "stats": {"tool_damage": -1.0, "tool_speed": -0.1}, "learnable": False,
     "desc": "Found-only junk. The bench refuses to learn it."},
]


def tier_stats(fam, tier):
    slot, applies, per, *_ = FAMILIES[fam]
    fid = FAMILY_IDS[fam]
    key = "%s_%d" % (fid, tier)
    if key in OVERRIDES:
        return dict(OVERRIDES[key])
    return {k: round(v * tier, 3) for k, v in per.items()}


def main():
    names = json.loads(NAMES.read_text(encoding="utf-8"))
    by_id = {v: k for k, v in names.items()}
    families = {}
    for fam, (slot, applies, per, label, color, blurb) in FAMILIES.items():
        fid = FAMILY_IDS[fam]
        tiers = []
        for t in range(1, 6):
            mid = "%s_%d" % (fid, t)
            entry = {"id": mid, "name": by_id[mid]}
            if mid in OVERRIDES:
                entry["stats"] = OVERRIDES[mid]
            tiers.append(entry)
        families[fam] = {"slot": slot, "applies": applies, "label": label, "color": color,
                         "desc": blurb, "stats_per_tier": per, "tiers": tiers}
    hybrids = []
    for root, (fa, fb, blurb) in HYBRIDS.items():
        slot = FAMILIES[fa][0]
        assert slot == FAMILIES[fb][0], root
        applies = sorted(set(FAMILIES[fa][1]) | set(FAMILIES[fb][1]), key=["tool", "weapon", "gear"].index)
        for t in range(1, 6):
            mid = "%s_%d" % (root, t)
            merged = {}
            for fam in (fa, fb):
                for k, v in tier_stats(fam, t).items():
                    merged[k] = merged.get(k, 0.0) + v
            stats = {}
            for k, v in merged.items():
                if k == "cold":
                    stats[k] = float(int(v))  # gates stay whole
                else:
                    stats[k] = round(v * HYBRID_BLEND, 3)
            stats = {k: v for k, v in stats.items() if v != 0}
            hybrids.append({"id": mid, "name": by_id[mid], "slot": slot, "tier": t, "applies": applies,
                            "recipe": ["%s_%d" % (FAMILY_IDS[fa], t), "%s_%d" % (FAMILY_IDS[fb], t)],
                            "stats": stats, "desc": blurb})
    data = {
        "_comment": ("Gear modifiers v2 (Modifiers.md / ModifiersImpl.md, 2026-09-05). Generated by "
                     "tools/gen_modifiers_json.py from docs/modifiers/Merged_Modifiers.json - edit the "
                     "stat tables there, not here. 6 district families x 5 depth tiers: a found piece's "
                     "family is the tower's district, its tier the floor's band (dry 1 .. crush 5). "
                     "families[].slot fixes prefix/suffix; tier N stats = N x stats_per_tier unless a tier "
                     "carries `stats`. hybrids[].recipe = two same-tier same-slot base ids from different "
                     "families (bench COMBINE). Two identical ids at tier N combine to the family's tier "
                     "N+1 (rule, not data). junk[] rolls on found tools/weapons and is never learnable. "
                     "Instances carry mods: {prefix: {id}, suffix: {id}} - no power. Rarity: none gray, "
                     "T1-2 green, T3-4 blue, T5 purple, both slots at T5 gold (D2). Stat keys: "
                     "tool_damage/tool_speed/knockback merge into the held tool block; scrap_speed, "
                     "weight_mult, carry, oxygen, swim, defense, cold, light, yield_chance, reveal stack "
                     "like equip stats."),
        "families": families,
        "hybrids": hybrids,
        "junk": JUNK,
    }
    OUT.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    n = sum(len(f["tiers"]) for f in families.values()) + len(hybrids) + len(JUNK)
    print("wrote", OUT, "-", n, "modifier defs")


if __name__ == "__main__":
    main()

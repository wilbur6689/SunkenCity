# Stage Three — Breaking Through

> *Better tools allow the player to open locked doors (and other sealed obstacles), unlocking
> previously unreachable sections.* — GameOverview.md, Main Game Loop

The **iron stage**. The player enters The Cold in a wetsuit, finds the first iron, lights the
Forge, and the tool ladder (GL-09) starts opening what the pry bar could not — including the
**shallow-but-gear-locked pockets** left deliberately behind in Stages One and Two (GL-01).

| | |
|---|---|
| **Band** | The Cold — rows 40–120 below the waterline (`BAND_SHALLOWS_DEPTH`…`BAND_COLD_DEPTH`), ≈ 13 floors |
| **Target time** | ~20–25 h (GL-27, "fat middle") |
| **Entry state** | Wetsuit (cold 1), scrap tank, speargun, Forge built |
| **Exit capability** | **Steel** at the Forge (2 iron + stone) → `cutting_torch`; iron tank; hard-suit schematic in hand |
| **Milestones** | M3 (cold gate, band tables), M4 (sharks, firearms, ammo), M5 (harvest gates, modifiers, Modification Bench) |

**Open questions** (`S3-NN`) close every section below: open-ended prompts meant to add variety and harden playability. Same workflow as `../OpenQuestions.md` — answer on an indented `**A:**` line, mark `[x]` answered or `[~]` deferred.

---

## Where it happens

- **The Cold**: the first band that never sees the sun. Submerged without cold rating ≥ 1 the
  player moves at 65 %; the wetsuit lifts that. Drained rooms are always safe (GL-17).
- **Open water is shark territory from here down** (GD-11): the swim between towers stops being
  free. Sharks menace swimmers only.
- **Locked sections**: `metal_door` (lock tier 2) needs `bolt_cutters`; `vault_door` and `safe`
  (lock tier 3) still wait for the torch or a `vault_key`. Stage Three is built around the
  moment the metal doors in Stage One/Two towers finally open.
- **Structure demolition**: iron tools (tier 2) break **stone** partitions — new routes through
  buildings, and stone for the Forge's steel recipe.

**Open questions**

- [ ] **S3-01.** How should The Cold *feel* different beyond the slow — barnacle overlays, no sun rays, a bluer grade, ice-crackle SFX, breath vapour in dry pockets?
- [ ] **S3-02.** What locked-section archetypes (server room, pharmacy cage, armoury, penthouse) should metal doors guard so opening one is a recognisable payoff?
- [ ] **S3-03.** Should some Cold towers lean office-heavy or hospital-heavy so players learn where iron and medkits concentrate?

## What the player has coming in

Wetsuit, `tank_scrap` (60 s), `speargun`, `scrap_sword`/`fire_axe`, `helmet_lamp`, a Forge, and
usually two or three ability points.

**Open questions**

- [ ] **S3-04.** Is the pistol arriving here a good first-gun moment, or should firearms wait until drained-room combat matters more?
- [ ] **S3-05.** Should the wetsuit change swimming itself (less weight penalty, a warmer grade) so the upgrade is *felt*, not merely permitted?
- [ ] **S3-06.** What does a typical Stage Three dive kit weigh — is 40 slots + soft weight producing the intended "leave things behind" tension?

## The loop at this stage

1. **First iron** — Cold containers roll `iron` 1–2 (`generic.cold` weight 4), scrap 2–4,
   glowsticks, and the first **gear**: `tank_scrap`, `wetsuit`, `dive_watch` (+10 s O2), the first
   `pistol` and `pistol_rounds`. **Harvest gate**: scrapping iron-bearing furniture needs
   **Scrapping 2** (M5 harvest gates by material tier) — Stage Two scrapping pays off here.
2. **Forge** — `bolt_cutters` (3 iron + wood), `iron_sword` (3 iron + cloth, 9 dmg), `iron_knife`
   (schematic; 3 iron + wood, tier-2 knife — the fast underwater melee), `steel` (2 iron + 1 stone).
3. **Dive Station** — `tank_iron` (4 iron + plastic, +60 s → 90 s total).
4. **Break through** — bolt cutters open every metal door in the city: the gear-locked pockets
   near the surface, offices' secure sections, hospital wards. Loot them with 90 s of air and a
   route already mapped.
5. **Learn the Bench** — found gear rolls **modifiers** (`data/modifiers.json`; one prefix + one
   suffix max, rarity = title colour). The **Modification Bench** (6 scrap + 4 wood) turns a
   *Rusty pistol of the Shore* into a decision: use it, or sacrifice it to learn *of the Shore*
   and apply it to a clean crafted piece (LT-09/10).
6. **Save for steel** — 2 iron + 1 stone each; the torch needs 2 steel + 3 scrap + 2 plastic. Iron
   is Cold-and-below only, and everything is one-time: the Cold empties, and the Forge wants more.

**Open questions**

- [ ] **S3-07.** Should bolt cutters have uses beyond doors (cutting chains that hold debris, freeing a stuck elevator cab) so the tool is more than a key?
- [ ] **S3-08.** How does the loop reward backtracking to Stage One/Two towers — remembered locks on the map, a "metal door here" marker?
- [ ] **S3-09.** What mid-stage goal sits between first iron and first steel — a full iron weapon set, a drained shaft, a whole tower cleared?

## Systems in play

- **Cold gate** (CC-16, GL-12): in The Cold the penalty is slow only; damage begins in The Dark
  (`COLD_DPS` 2/s) without a higher rating. **Cold Blood** (Diving tier 3, +1 effective cold) lets
  a wetsuit survive The Dark — an ability that stands in for a suit tier.
- **Tool tiers** (`tool.tier` in `data/items.json`): pry 1 (`pry_bar`) → 2 (`bolt_cutters`) → 3
  (`cutting_torch`). Doors check `lock_tier`; structure checks `STRUCTURE_TIER` (stone 2,
  metal 3). Rare **keys** (`vault_key`, Dark/Crush loot) bypass tier 3 (LT-14).
- **Firearms** are found-only, hitscan, **dead submerged** (GD-08). Pistol 8 dmg / 2 shots/s /
  reload 1.0 on `pistol_rounds` (2 scrap at the Forge). Loud lead above, silent spears below.
- **Modifiers**: ~8 power prefixes (Sharp, Swift, Heavy, Balanced, Rusty…), ~8 aquatic suffixes
  (of the Deep +O2, of Currents +swim, of the Shore −weight, of Warmth +cold, of Sight +light).
  Applied once to an unmodified piece, then locked; blue/purple crafted gear is reachable via a
  single prefix+suffix apply (LT-09 note).
- **Weight** bites hardest here: iron weighs 2.0 per unit, bolt cutters 4.0, the wetsuit 2.0.
  Hauling 20 iron halves swim speed — the raft/forward-camp logistics question (GL-19) is real.

**Open questions**

- [ ] **S3-10.** Should cold *accumulate* (a chill that recovers in dry rooms) rather than switch on at a row, so peeks become a gamble?
- [ ] **S3-11.** How could modifiers add variety beyond numbers — a suffix that makes bolts glow, a prefix that knocks enemies into water?
- [ ] **S3-12.** Should structure demolition leave rubble (temporary debris blocks) that becomes footholds or cover?

## Crafting & recipes unlocked

| Station | Recipe | Cost | Unlocks |
|---|---|---|---|
| Forge | `bolt_cutters` | 3 iron + 1 wood | Metal doors (lock 2); pry tier 2 |
| Forge | `steel` | 2 iron + 1 stone | The Stage Four material |
| Forge | `iron_sword` | 3 iron + 1 cloth | 9 dmg melee, knockback 7 |
| Forge | `iron_knife` (schematic) | 3 iron + 1 wood | tier-2 knife, speed 1.5 — the dive melee |
| Forge | `pistol_rounds` / `rifle_rounds` | 2 scrap / iron + scrap | Keeps found guns alive (LT-16) |
| Dive Station | `tank_iron` | 4 iron + 1 plastic | 90 s total air |
| Forge | `cutting_torch` | 2 steel + 3 scrap + 2 plastic | The Stage Four door (lock 3, metal structure) |

**Open questions**

- [ ] **S3-13.** What iron-tier building parts (bars, grates that pass water but block enemies, reinforced doors) would open new base tactics?
- [ ] **S3-14.** Should ammo need a component (gunpowder from hospital chemicals) so hospitals matter to gun users?
- [ ] **S3-15.** Is one schematic-gated iron item (the knife) the right number, or should every tier have one "found" recipe?

## Loot & materials

| Source | Cold-band tables |
|---|---|
| Generic | iron 1–2 (w4), scrap 2–4, glowsticks 1–3, `tank_scrap`, `wetsuit`, `dive_watch`, `pistol`, `pistol_rounds` 6–12 |
| Residential | food, cloth, wood, plastic |
| Office | scrap metal, plastic, iron |
| Hospital | medkits, bandages |
| Structure | stone from broken partitions (tier-2 tools) — the Forge's steel input |
| Depletion | verified in `m5_smoke`: iron obtainable **above** The Cold (~14) cannot cover the gear chain (25) — you must dive (GL-28, LT-27) |

**Open questions**

- [ ] **S3-16.** What Cold-exclusive loot categories are missing — dive computers, industrial parts, keys to *shallow* vaults you already passed?
- [ ] **S3-17.** Should safes telegraph their tier visually (padlock vs keypad) so players plan tools before the dive?
- [ ] **S3-18.** How do we keep iron scarce but findable — fixed counts per tower, or per-container odds only?

## Dangers

| Threat | Cold stats | Notes |
|---|---|---|
| Walker | 55 HP, 13 dmg, 2.4 b/s, aggro 11 | Dry pockets in the Cold — now two-shot fights with a scrap sword |
| Crawler | 34 HP, 10 dmg, 2.8 b/s, aggro 9 | — |
| **Shark** | 90 HP, 18 dmg, **5.5 b/s**, aggro 14 | Faster than the player (5 b/s); open water only; speargun (12 dmg) or avoid |
| Cold | ×0.65 speed without rating 1 | Wetsuit removes it; a slowed swimmer in shark water is the Stage Three death |
| Bleeding | 35 % per hit | Medkits (heal 60) from the Med Station |
| Red moons | day-scaled | Base under water is safe from walkers; surface bases now face waves of 5–6 |

**Open questions**

- [ ] **S3-19.** What shark behaviours (circling, bump-then-bite, losing interest at a building's edge) make open water tense but fair?
- [ ] **S3-20.** Should Cold walkers be visibly cold-adapted (frost, slower, tougher) to sell the band?
- [ ] **S3-21.** Is there a place for a telegraphed, recoverable trap (debris collapsing when a metal door is cut)?

## Base & water

- **Forward camp in The Cold**: drain a room at row ~60–100, mount a Dive Station and a chest,
  and the surface base becomes a warehouse. Tanks refill there; cold doesn't reach a dry room.
- **Pump-out the elevator shaft** (CT-06): a dry shaft is a rope drop through the whole band and a
  refuel column — the signature Stage Three engineering project.
- Bed placement moves spawn (GL-23) — a bed in the camp turns a shark death from a 10-minute
  swim into a 30-second one.

**Open questions**

- [ ] **S3-22.** Should a drained elevator shaft become a *lift* (counterweighted platform, current lift) as a Stage Three engineering reward?
- [ ] **S3-23.** What makes the Cold camp different from the Shallows camp — a heater object, warmer lights, insulated blocks?
- [ ] **S3-24.** Should beds set spawn only in sealed rooms so respawning into a re-flooded camp can't happen?

## Skills & abilities

Scrapping 2 gates iron harvest; Scrapping 3 will gate steel (Stage Four). Player level 3–5 is
typical by the end of the stage: **Tool Harness** (3rd accessory: tank + dive watch + fins),
**Free Diver**, **Long Reach** for placing seal blocks from further away while pumping. Iron
tools scrap faster (`tool.speed` 1.2–1.5).

**Open questions**

- [ ] **S3-25.** Should Scrapping 2/3 appear as a lock icon on iron/steel furniture so the harvest gate reads as a goal, not a bug?
- [ ] **S3-26.** Would a Combat skill (melee/speargun by use) fit here, where fighting starts to matter?
- [ ] **S3-27.** How does Long Reach interact with underwater placement — is reach the right lever for sealing and pumping?

## Exit gate — what pushes the player down

- **Lock tier 3** — vault doors and **safes** (each band's best rolls, LT-14) stay shut without
  steel (torch) or keys that only drop in The Dark/Crush.
- **The Dark starts at row 120** and *hurts* (2 HP/s) without cold rating 2 — the hard suit
  (`schematic_hard_suit`, Dark/Crush loot) or Cold Blood.
- Iron depletes in the Cold; the steel chain (4 steel for a hard suit, 3 for a rebreather, 2 for
  the torch = 18 iron + 9 stone) is the standing shopping list.

**Open questions**

- [ ] **S3-28.** What signals "The Dark is next" — a Drowned glimpsed in a shaft, total loss of sun, a temperature warning on the HUD?
- [ ] **S3-29.** Should the torch be attainable *before* the hard suit so vault-looting the Cold is its own late-Stage-Three chapter?
- [ ] **S3-30.** Is 18 iron + 9 stone for the steel chain a wall or a project — what interim steel item makes the first ingot worth it?

## Tuning knobs

`BAND_COLD_DEPTH` 120 · `COLD_SLOW_FACTOR` 0.65 · `STRUCTURE_TIER` stone 2 / metal 3 ·
shark row in `data/enemies.json` · `lock_tier` on `metal_door` (2) · iron weight 2.0 ·
`SKILL_XP_PER_LEVEL` 20 · harvest gates (iron → Scrapping 2).

**Open questions**

- [ ] **S3-31.** Should the Cold slow be milder for a suit-less peek (0.8) at the top of the band and harsher deeper in?
- [ ] **S3-32.** Where should shark density sit so a crossing is a decision but never a lottery?

## Design references

GL-01/06/07/08/09/10/11/12/19/28 · CC-16/18 · WS-10/14/22 · GD-07/08/11/12/23 ·
LT-05…LT-11/14/16/18/20/25/26 · CT-06/18.

## Open / feel-check notes

- **Sharks vs. swim speed**: 5.5 b/s vs the player's 5 (fins +20 % → 6). Confirm the chase feels
  escapable-with-fins, lethal-without — the M4 balance/feel pass item.
- **Iron knife is schematic-gated** while the iron sword is known — intentional (the fast dive
  knife is a find), but verify the schematic drops often enough in Cold tables (currently absent
  from `generic.cold`; check zone tables).
- Steel weapons don't exist yet (no steel sword/axe in `data/items.json`); LT-01 promises melee at
  all four tiers — a data-only addition for the balance pass.

**Open questions**

- [ ] **S3-33.** Which Cold tower should be Stage Three's set piece (a mall? a police station — CT-02 expansion) and what does it teach?
- [ ] **S3-34.** What data would confirm "fat middle" pacing — iron per hour, doors opened per session, time between camps?


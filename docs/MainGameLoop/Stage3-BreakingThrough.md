# Stage Three — Breaking Through

> *Better tools allow the player to open locked doors (and other sealed obstacles), unlocking
> previously unreachable sections.* — GameOverview.md, Main Game Loop

The **iron stage**. The player enters The Cold in a wetsuit, finds the first iron, lights the
Forge, and the tool ladder (GL-09) starts opening what the pry bar could not — including the
**shallow-but-gear-locked pockets** left deliberately behind in Stages One and Two (GL-01).

| | |
|---|---|
| **Band** | The Cold — rows 80–240 below the waterline (`BAND_SHALLOWS_DEPTH`…`BAND_COLD_DEPTH`; 40–120 before the 8 px cell of 2026-09-04), ≈ 13 floors |
| **Target time** | ~20–25 h (GL-27, "fat middle") |
| **Entry state** | Wetsuit (cold 1), scrap tank, speargun, Forge built |
| **Exit capability** | **Steel** at the Forge (2 iron + stone) → `cutting_torch`; iron tank; hard-suit schematic in hand |
| **Milestones** | M3 (cold gate, band tables), M4 (sharks, firearms, ammo), M5 (harvest gates, modifiers, Modification Bench) |

**Open questions** (`S3-NN`) close every section below: open-ended prompts meant to add variety and harden playability. Same workflow as `../OpenQuestions.md` — answer on an indented `**A:**` line, mark `[x]` answered or `[~]` deferred.

**Units note (2026-09-05 review):** speeds and radii quoted below in blocks/s or blocks predate the 8 px cell of 2026-09-04; in today's cells every such figure doubles (walk 10 / sprint 14 / swim 10 cells/s, jump 6; enemy speeds are already ×2 in `data/enemies.json`). Ratios are unchanged. Costs and row numbers have been corrected to current data where the review found them stale.

---

## Where it happens

- **The Cold**: the first band that never sees the sun. Submerged without cold rating ≥ 1 the
  player moves at 65 %; the wetsuit lifts that. Drained rooms are always safe (GL-17).
- **Districts** (2026-09-04) make every tower single-zone, so the band has a geography: the
  **industrial** cluster is the iron concentration (`industrial.cold` iron 2–3), **civil** towers
  are the medkit supply, and construction towers never seal (S3-03).
- **Open water is shark territory from here down** (GD-11): the swim between towers stops being
  free. Sharks menace swimmers only.
- **Locked sections**: `metal_door` (lock tier 2) needs `bolt_cutters`; `vault_door` and `safe`
  (lock tier 3) still wait for the torch or a `vault_key`. Stage Three is built around the
  moment the metal doors in Stage One/Two towers finally open.
- **Structure demolition**: iron tools (tier 2) break **stone** partitions — new routes through
  buildings, and stone for the Forge's steel recipe.

**Open questions**

- [x] **S3-01.** How should The Cold *feel* different beyond the slow — barnacle overlays, no sun rays, a bluer grade, ice-crackle SFX, breath vapour in dry pockets?
    **A:** Keep it to the two channels the engine already has: the band colour grade (canon: the depth grade differentiates the five bands) pushed bluer/desaturated for The Cold, and a depth-adaptive audio layer (low-pass, occasional metal creak/ice-crackle stingers). No sun rays is already true — `LightMap` gets no sun there. Barnacle/wear overlays are CT-24 (post-MVP band wear) and breath vapour in dry pockets is polish; both wait.
- [x] **S3-02.** What locked-section archetypes (server room, pharmacy cage, armoury, penthouse) should metal doors guard so opening one is a recognisable payoff?
    **A:** One locked archetype per district, authored as room templates whose wing doorway is a `metal_door` (lock 2) and tagged `locked: true` in `rooms.json`: residential = super's storeroom/penthouse, business = records vault/server room, commercial = stockroom/pharmacy cage, industrial = tool crib, civil = police armoury or hospital pharmacy; construction never seals, so none. The payoff is a biased roll (iron, the first firearm + ammo, an accessory) from a `locked.<zone>` table — data only, no new mechanic. Modifier aspect reserved for the user's modifier pass.
- [x] **S3-03.** Should some Cold towers lean office-heavy or hospital-heavy so players learn where iron and medkits concentrate?
    **A:** Already decided by districts (CT-02 amendment 2026-09-04): a tower's district sets its zone for every floor, so iron concentrates in the industrial cluster (`industrial.cold` iron 2–3 w4) and medkits in civil. The body text should state this as fact; the remaining lever is per-zone table weights, not tower authoring.

## What the player has coming in

Wetsuit, `tank_scrap` (60 s), `speargun`, `scrap_sword`/`fire_axe`, `helmet_lamp`, a Forge, and
usually two or three ability points.

**Open questions**

- [x] **S3-04.** Is the pistol arriving here a good first-gun moment, or should firearms wait until drained-room combat matters more?
    **A:** Yes — the pistol arrives here. The Cold is the first band with 55-HP walkers in dry pockets and locked dry rooms behind metal doors, so a gun has a job the moment it appears; it is found-only (LT-11), dead submerged (GD-08), and its rounds craft at the Forge, so it never undercuts the speargun. Keep `pistol` w1 in `generic.cold` and w2 in `safe.cold`.
- [x] **S3-05.** Should the wetsuit change swimming itself (less weight penalty, a warmer grade) so the upgrade is *felt*, not merely permitted?
    **A:** Felt through presentation, not stats: when the worn cold rating covers the band the grade warms back, the shiver/onset cue (S3-10) never fires, and the paper-doll tint changes. No swim or weight buff — the wetsuit is priced Shallows-cheap (S2-15), and a stat buff would make it a Stage Two swimming upgrade rather than the Cold key.
- [~] **S3-06.** What does a typical Stage Three dive kit weigh — is 40 slots + soft weight producing the intended "leave things behind" tension?
    **A:** Deferred to the M4 balance/feel pass. On paper the numbers land where intended: a typical kit (wetsuit 2 + `tank_scrap` 3 + `bolt_cutters` 4 + `iron_sword` 2.5 + pistol 2 + lamp) is ~15–18 weight, and 20 iron at 2.0 adds 40, hitting `WEIGHT_SWIM_REFERENCE` 60 = half swim speed. Whether that reads as "leave something behind" or as a chore needs the GL-27 feel-check with haul weights logged (S3-34).

## The loop at this stage

1. **First iron** — Cold containers roll `iron` 1–2 (`generic.cold` weight 4), scrap 2–4,
   glowsticks, and the first **gear**: `tank_scrap`, `wetsuit`, `dive_watch` (+10 s O2), the first
   `pistol` and `pistol_rounds`. **Harvest gate**: scrapping iron-bearing furniture needs
   **Scrapping 2** (M5 harvest gates by material tier) — Stage Two scrapping pays off here.
2. **Forge** — `bolt_cutters` (15 iron + 5 wood), `iron_sword` (3 iron + cloth, 9 dmg), `iron_knife`
   (schematic; 15 iron + 5 wood, tier-2 knife — the fast underwater melee), `steel` (2 iron +
   1 stone). Tool recipes run 5x since 2026-09-01.
3. **Dive Station** — `tank_iron` (4 iron + plastic, +60 s → 90 s total).
4. **Break through** — bolt cutters open every metal door in the city: the gear-locked pockets
   near the surface, offices' secure sections, hospital wards. Loot them with 90 s of air and a
   route already mapped.
5. **Learn the Bench** — found gear rolls **modifiers** (`data/modifiers.json`; one prefix + one
   suffix max, rarity = title colour). The **Modification Bench** (6 scrap + 4 wood) turns a
   *Rusty pistol of the Shore* into a decision: use it, or sacrifice it to learn *of the Shore*
   and apply it to a clean crafted piece (LT-09/10).
6. **Save for steel** — 2 iron + 1 stone each; the torch needs 10 steel + 15 scrap + 10 plastic
   (5x tool costs). Iron is Cold-and-below only, and everything is one-time: the Cold empties, and
   the Forge wants more.

**Open questions**

- [x] **S3-07.** Should bolt cutters have uses beyond doors (cutting chains that hold debris, freeing a stuck elevator cab) so the tool is more than a key?
    **A:** Yes, by reusing `lock_tier` rather than a new mechanic: any object with `lock_tier` 2 opens to a tier-2 pry tool, so add chained variants — a chained supply crate, a chained locker, a chained elevator-cab door for Cold-band shafts (the Shallows cab itself stays pry tier 1, S2-03; a movable cab is deferred, S2-37) — as data entries. Bolt cutters stay "a key", but a key to more than doors.
- [x] **S3-08.** How does the loop reward backtracking to Stage One/Two towers — remembered locks on the map, a "metal door here" marker?
    **A:** Auto-pinned lock markers on the map: when a `lock_tier` object is looked at or clicked while locked, `MapReveal` records a marker at its macro cell, drawn on the minimap/`map_view` as the tier-coloured shield (reuse the `_TierBadge` palette grey/green/blue/orange). Opening it greys the marker. Pockets stay depth-true (canon), so the reward for returning is the `locked.<zone>` roll (S3-02), not deeper loot.
- [x] **S3-09.** What mid-stage goal sits between first iron and first steel — a full iron weapon set, a drained shaft, a whole tower cleared?
    **A:** The drained elevator shaft (CT-06) is the named mid-stage goal: it needs the iron tank's 90 s to work floor by floor, produces a refuel column and a rope drop through the band, and precedes steel naturally. An iron weapon set is the emergent secondary; a full tower clear is Stage Five's rhythm.

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

- [x] **S3-10.** Should cold *accumulate* (a chill that recovers in dry rooms) rather than switch on at a row, so peeks become a gamble?
    **A:** No accumulation — keep the row-threshold gate (CC-16/GL-12 canon; a chill meter is a new survival meter, which canon deliberately avoids). Add a 2–3 s onset ramp to `COLD_SLOW_FACTOR` with a shiver cue so a peek reads as a warning, not a wall.
- [x] **S3-11.** How could modifiers add variety beyond numbers — a suffix that makes bolts glow, a prefix that knocks enemies into water?
    **A:** MVP item modifiers stay numeric on the lean stat sheet (LT-05/06/20); *of Sight* already gives light, so non-numeric effects (glowing bolts, knockback into water) are post-MVP data extensions of `data/modifiers.json`. If the user's modifier pass reaches item prefixes/suffixes it overrides this; modifier aspect reserved.
- [x] **S3-12.** Should structure demolition leave rubble (temporary debris blocks) that becomes footholds or cover?
    **A:** No rubble blocks. There is no structural sim (placed blocks float) and temporary decaying blocks would be a new entity class; the break puff plus popped material drops already give demolition feedback. Post-MVP idea only.

## Crafting & recipes unlocked

| Station | Recipe | Cost | Unlocks |
|---|---|---|---|
| Forge | `bolt_cutters` | 15 iron + 5 wood | Metal doors (lock 2); pry tier 2 |
| Forge | `steel` | 2 iron + 1 stone | The Stage Four material |
| Forge | `iron_sword` | 3 iron + 1 cloth | 9 dmg melee, knockback 14 |
| Forge | `iron_knife` (schematic) | 15 iron + 5 wood | tier-2 knife, speed 1.5 — the dive melee |
| Forge | `pistol_rounds` / `rifle_rounds` | 2 scrap / iron + scrap | Keeps found guns alive (LT-16) |
| Dive Station | `tank_iron` | 4 iron + 1 plastic | 90 s total air |
| Forge | `cutting_torch` | 10 steel + 15 scrap + 10 plastic | The Stage Four door (lock 3, metal structure) |
| Forge | `iron_block` (proposed, S3-13) | 1 iron | High-HP placed block — the red-moon wall |

**Open questions**

- [x] **S3-13.** What iron-tier building parts (bars, grates that pass water but block enemies, reinforced doors) would open new base tactics?
    **A:** One iron-tier part in MVP: `iron_block` (Forge, 1 iron) with high placed-block HP as the red-moon wall — it reuses `placed_blocks` HP/hardness and answers the "surface bases face waves of 5–6" line. The water-passing grate (solid to bodies, porous to water and light) needs a new material flag in the sim and waits for post-MVP.
- [x] **S3-14.** Should ammo need a component (gunpowder from hospital chemicals) so hospitals matter to gun users?
    **A:** No component — LT-16 says all ammo crafts from scrap at base, and gunpowder would gate guns behind one district and add a material outside the Wood→Scrap→Iron→Steel ladder (LT-25). Hospitals matter to gun users through medkits and bandages (bleeding on shark bites).
- [x] **S3-15.** Is one schematic-gated iron item (the knife) the right number, or should every tier have one "found" recipe?
    **A:** One found recipe per tier is the rhythm: iron knife (iron), hard suit + rebreather (steel). Fix the data gap the feel-check note flags: `schematic_iron_knife` is absent from every Cold table — add it at w1 to `commercial/industrial/civil.cold` and w2 to `safe.cold`. Keep `bolt_cutters` w1 in `industrial.cold` as the "found shortcut" pattern (cf. S2-04).

## Loot & materials

| Source | Cold-band tables |
|---|---|
| Generic | iron 1–2 (w4), scrap 2–4, glowsticks 1–3, `tank_scrap`, `wetsuit`, `dive_watch`, `pistol`, `pistol_rounds` 6–12 |
| Residential | food, cloth, wood, plastic |
| Business / commercial | scrap metal, plastic, iron, glowsticks |
| Civil (hospital, police) | medkits, bandages, iron; the armoury behind a metal door (S3-33) |
| Industrial | iron 2–3 — "the mine"; found `bolt_cutters` (w1) |
| Construction | scrap 4–6, wood, tools |
| Structure | stone from broken partitions (tier-2 tools) — the Forge's steel input |
| Depletion | verified in `m5_smoke`: iron obtainable **above** The Cold (~14) cannot cover the gear chain (25) — you must dive (GL-28, LT-27) |

**Open questions**

- [x] **S3-16.** What Cold-exclusive loot categories are missing — dive computers, industrial parts, keys to *shallow* vaults you already passed?
    **A:** The Cold's exclusives are the accessory trio (`dive_watch`, `weight_belt`, `compass`), the first firearm, `tank_iron` in safes, and the iron-knife schematic (S3-15). No new categories or materials in MVP; keys stay generic (S4-17 decides labelling). Industrial "parts" are scrap metal and iron by another sprite.
- [x] **S3-17.** Should safes telegraph their tier visually (padlock vs keypad) so players plan tools before the dive?
    **A:** There is only one safe tier (lock 3), so the object is the telegraph: wood door = pry, metal door = cutters, safe/vault = torch or key. Make the hover card show the lock tier as the same colour-coded shield used for scrap tiers (`_TierBadge` on `lock_tier`) with the tool name; no padlock/keypad sprite split.
- [x] **S3-18.** How do we keep iron scarce but findable — fixed counts per tower, or per-container odds only?
    **A:** Per-container odds stay the mechanism, with the industrial district as the guaranteed anchor (iron 2–3 w4 — one cluster per city is "the mine"). Add a gate assertion to `m5_smoke`/`district_smoke`: expected Cold-band iron per world ≥ 2× the gear chain (25), so scarcity never becomes a dead end (GL-29).

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

- [x] **S3-19.** What shark behaviours (circling, bump-then-bite, losing interest at a building's edge) make open water tense but fair?
    **A:** Patrol → chase → leash. Sharks idle along a lane at their seeded row (S3-39), aggro on proximity only (GD-12, no blood scent), chase straight, and disengage when the player enters a tower footprint or leaves range for a few seconds — open water is theirs, interiors are not. No circling or bump-then-bite states in MVP.
- [x] **S3-20.** Should Cold walkers be visibly cold-adapted (frost, slower, tougher) to sell the band?
    **A:** Visual only: a per-band `tint`/variant weight in `data/enemies.json` so Cold walkers roll frost-blue variants; stats already differ per band (GD-23). Cheap, data-driven, and the Monster Editor exposes it.
- [x] **S3-21.** Is there a place for a telegraphed, recoverable trap (debris collapsing when a metal door is cut)?
    **A:** Yes, one — the rusted-door collapse (S3-38) is the band's authored recoverable trap. Recoverable means damage plus a blocked doorway you can clear with tools you already hold.

## Hazards, puzzles & water management

The Cold layers a new predator (sharks), a new tax (the slow), and a new puzzle language
(lock tiers) onto a band twice the Shallows' depth. The hazard space:

- **Monster texture**: sharks own the open water between towers; walkers and crawlers hold
  the dry pockets — the water *inside* buildings is, notably, still empty (the Drowned wait a
  band down). Stage Three's tension is crossings and thresholds, not pursuit.
- **The slow is a trap multiplier**: at ×0.65, every hazard is a third worse. A suit-less
  peek that meets a shark is the band's signature death; the wetsuit doesn't remove danger,
  it restores the player's baseline.
- **Locks are puzzles with a tool answer**: pry 1 → cut 2 → torch 3 is a legible hierarchy,
  and every locked thing seen is a promise. The band works when players keep a mental (or
  map) list of doors they owe a return visit.
- **Demolition opens routing puzzles**: tier-2 tools break stone, so "the door" stops being
  the only answer — go through the wall, the floor, the neighbouring shaft. Route choice
  becomes self-expression.
- **Water management scales up**: the elevator-shaft drain (CT-06) is the first multi-room,
  multi-pump project — sealing doors floor by floor, pumping in sequence, building the band's
  highway home.

**Open questions**

- [x] **S3-35.** Should locked archetypes (S3-02) carry authored micro-puzzles beyond the lock — a server room whose loot terminal needs the floor's breaker found and powered, a pharmacy cage with a second, hidden way in — so "opening" isn't always just the tool check?
    **A:** One pattern, built from existing systems: locked archetypes come in two template variants — cutters-only, or the barred-door + hidden `door_button` pattern (already implemented for pockets). The "second hidden way in" is emergent — tier-2 demolition through stone.
- [x] **S3-36.** How should locked sections *show their prize* (glass walls into the armoury, loot silhouettes through the cage) so a lock is a promise the player logs rather than an obstacle they forget?
    **A:** Locked templates include a glass-block strip (canon palette: fragile, transparent) on the room side so loot silhouettes show through, and the map marker (S3-08) logs the promise.
- [x] **S3-37.** Demolition routing: what makes "through the wall" a considered choice instead of the default — slower but shark-free? stone yields as payment? structure that matters to a future drain?
    **A:** The trade already exists: the door is instant with the right tool; the wall costs time (stone `STRUCTURE_HP` 50/cell, 2-thick, tier-2 damage 5) and pays stone for steel, and the sim's honesty means a hole into a flooded neighbour floods you. No extra pricing.
- [x] **S3-38.** Should decay set booby-traps at this tier — a rusted door that collapses when cut (telegraphed by rust streaks), a debris slide behind a pried hatch — as the band's recoverable authored traps (GL-29)?
    **A:** Yes, one: `metal_door_rusted` (rust-streak sprite) that, when cut, drops a 2×2 debris object and a small hit/knockback; the debris is `kind: scrap` (hammer clears, scrap yield). Data + one interaction hook; schedule after the core loop.
- [x] **S3-39.** Should sharks patrol *learnable* circuits (a lap of the tower gap, visible from windows) so crossings become timeable puzzles — or does predictable patrolling defang open water?
    **A:** Learnable lanes — yes. Predictability is offset by aggro radius 14 and the speed gap, so a mistimed crossing still bites; it turns open water into a puzzle rather than a lottery.
- [x] **S3-40.** What turns the shaft drain into a *puzzle* rather than a wait — door-sealing order that matters, pump placement height, a cab in the way (S2-37) — and should one tower per world be authored to teach it?
    **A:** The puzzle is emergent: each floor's shaft-side doors must be sealed or the wing refills the shaft, and the outlet must sit outside/above. No authored teaching tower (GL-01); the cab (S2-37) stays post-MVP.
- [x] **S3-41.** Should pumping gain a depth constraint here (lift height per pump, relays in series for deep outlets) so water engineering grows a tech curve of its own — or does one-pump-drains-all hold until post-MVP?
    **A:** No lift height or series relays in MVP — one pump tier, `PUMP_RANGE_BLOCKS` 48 the only constraint (WaterPhysics Open Items: tiers TBD). Volume is time. Tiered pump rates are post-MVP.
- [x] **S3-42.** When a big drain lowers a connected body across several rooms, how much of that spread should the player be able to *predict* — is there room for a water-reading affordance (flow hints at breaches, an outlet's reach preview) at this tier?
    **A:** Minimal, honest affordance: while targeting an outlet, highlight the connected body the BFS already computes. Flow hints at breaches wait.

## Base & water

- **Forward camp in The Cold**: drain a room at row ~120–200, mount a Dive Station and a chest,
  and the surface base becomes a warehouse. Tanks refill there; cold doesn't reach a dry room.
- **Pump-out the elevator shaft** (CT-06): a dry shaft is a rope drop through the whole band and a
  refuel column — the signature Stage Three engineering project.
- Bed placement moves spawn (GL-23) — a bed in the camp turns a shark death from a 10-minute
  swim into a 30-second one.

**Open questions**

- [x] **S3-22.** Should a drained elevator shaft become a *lift* (counterweighted platform, current lift) as a Stage Three engineering reward?
    **A:** No lift in MVP (CT-06: no working elevators; GL-18: currents and drained shortcuts are the fast travel). The reward of a dry shaft is the rope drop and re-rigged ladders; a current lift is the WS-16/S5-11 question for Stage Five/post-MVP.
- [x] **S3-23.** What makes the Cold camp different from the Shallows camp — a heater object, warmer lights, insulated blocks?
    **A:** No new objects: cold doesn't reach dry rooms (GL-17), so the camp is mechanically identical and its identity is warm placed lights (warm = safe canon) and the Forge moving down. A heater is a post-MVP cozy object.
- [x] **S3-24.** Should beds set spawn only in sealed rooms so respawning into a re-flooded camp can't happen?
    **A:** No placement restriction — GL-29 wants setbacks recoverable, not prevented. Safety valve: if the bed cell is submerged at respawn, spawn at the nearest air cell above it (surface if none), so a re-flooded camp costs a swim, not a drowning loop.

## Skills & abilities

Scrapping 2 gates iron harvest; Scrapping 3 will gate steel (Stage Four). Player level 3–5 is
typical by the end of the stage: **Tool Harness** (3rd accessory: tank + dive watch + fins),
**Free Diver**, **Long Reach** for placing seal blocks from further away while pumping. Iron
tools scrap faster (`tool.speed` 1.2–1.5).

**Open questions**

- [x] **S3-25.** Should Scrapping 2/3 appear as a lock icon on iron/steel furniture so the harvest gate reads as a goal, not a bug?
    **A:** Already half done — the tier badge (2026-09-02) shows the tool tier on `kind:scrap` cards. Add the skill line ("Scrapping 2") to the card when `skill` gates, so the harvest gate reads as a goal.
- [x] **S3-26.** Would a Combat skill (melee/speargun by use) fit here, where fighting starts to matter?
    **A:** No — CC-18 finalised the MVP skill set at Scrapping / Swimming / Building. A Combat skill is a post-MVP addition.
- [x] **S3-27.** How does Long Reach interact with underwater placement — is reach the right lever for sealing and pumping?
    **A:** Reach is the right lever and applies identically underwater (placement and pump targeting share `REACH_BLOCKS`). Verify Long Reach's "+1 block" became +2 cells in `data/abilities.json` after the half-size migration.

## Exit gate — what pushes the player down

- **Lock tier 3** — vault doors and **safes** (each band's best rolls, LT-14) stay shut without
  steel (torch) or keys that only drop in The Dark/Crush.
- **The Dark starts at row 240** (`BAND_COLD_DEPTH`, 8 px cells) and *hurts* (2 HP/s) without
  cold rating 2 — the hard suit (`schematic_hard_suit`, Dark/Crush loot) or Cold Blood.
- Iron depletes in the Cold; the steel chain (4 steel for a hard suit, 3 for a rebreather, **10**
  for the torch = 17 steel = 34 iron + 17 stone, plus 15 iron for bolt cutters — the 5x tool-cost
  rule of 2026-09-01; retune in the balance pass, S3-56) is the standing shopping list.

**Open questions**

- [x] **S3-28.** What signals "The Dark is next" — a Drowned glimpsed in a shaft, total loss of sun, a temperature warning on the HUD?
    **A:** A HUD cold indicator (a small thermometer/rating glyph beside oxygen) that turns amber on the last Cold floors and red at the Dark row, plus the grade darkening to black-water. The first Drowned is emergent — they seed only below the line — so nothing is authored. Pairs with S4-20 and S2-28.
- [x] **S3-29.** Should the torch be attainable *before* the hard suit so vault-looting the Cold is its own late-Stage-Three chapter?
    **A:** Yes — the torch (10 steel = 20 iron + 10 stone at the 5x tool-cost rule; the doc's older 2-steel figure predates it) is the first steel purchase, ahead of the hard suit whose schematic is Dark loot (w3) or a w1 Cold-safe roll. Vault-looting the Cold's safes is the late-Stage-Three chapter; Stage 4's "Torch first" step agrees.
- [x] **S3-30.** Is 18 iron + 9 stone for the steel chain a wall or a project — what interim steel item makes the first ingot worth it?
    **A:** A project, not a wall: the torch (10 steel since the 5x tool-cost rule — the question's 18 iron + 9 stone is stale; the chain is now torch 10 + suit 4 + rebreather 3 = 17 steel = 34 iron + 17 stone, plus 15 iron for bolt cutters — retune in the balance pass) is the interim item that makes the first ingots worth it, and steel is banked incrementally. No new steel item needed here; steel melee (LT-01) remains the balance-pass data addition.

## Tuning knobs

`BAND_COLD_DEPTH` 240 · `COLD_SLOW_FACTOR` 0.65 · `STRUCTURE_TIER` stone 2 / metal 3 ·
shark row in `data/enemies.json` · `lock_tier` on `metal_door` (2) · iron weight 2.0 ·
`SKILL_XP_PER_LEVEL` 20 · harvest gates (iron → Scrapping 2).

**Open questions**

- [x] **S3-31.** Should the Cold slow be milder for a suit-less peek (0.8) at the top of the band and harsher deeper in?
    **A:** No gradient — flat 0.65 keeps the gate legible (S3-10); the onset ramp softens the peek.
- [x] **S3-32.** Where should shark density sit so a crossing is a decision but never a lottery?
    **A:** Start at one shark per two tower gaps at Cold rows, capped at one per gap, seeded with patrol lanes (S3-39) so a crossing is timeable. Tune the count in the M4 feel pass with the sightings/deaths telemetry (S3-34).

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
  all four tiers — settled as a data-only addition in Stage Four's S4-13 (`steel_sword` /
  `steel_knife` / `steel_axe`), still to be entered.

**Open questions**

- [x] **S3-33.** Which Cold tower should be Stage Three's set piece (a mall? a police station — CT-02 expansion) and what does it teach?
    **A:** No authored tower (GL-01 emergent). The civil district is the set piece by template: a police armoury behind a metal door (first gun + ammo cache) and hospital wards (medkits); it teaches "metal door = payoff" and "civil = meds".
- [x] **S3-34.** What data would confirm "fat middle" pacing — iron per hour, doors opened per session, time between camps?
    **A:** Lightweight session telemetry written to `user://telemetry/`: iron gained per hour, lock opens per tier per hour, bed placements (depth, time), deaths by cause and band, time in each band. This is the GL-27 measurement and an M6 item.

## Transition — Stage Three → Stage Four

The Cold ends in a shopping list: steel. The transition is less a door than a **budget** —
17 steel (34 iron + 17 stone at current costs) covers torch, hard suit, and rebreather, and the
Cold's one-time iron cannot cover it all (GL-28), so the player descends *while still incomplete*. That is deliberate:
Stage Four opens with the torch and the schematic hunt, not with a finished kit.

Expected state at the boundary: `tank_iron` (90 s); wetsuit; bolt cutters; iron sword or
knife; 10 steel banked (the torch) with more owed; a Cold camp around rows 120–200; Scrapping 3
in reach; the map dotted with tier-3 locks the player already wants open.

**Open questions**

- [x] **S3-43.** Should the steel shopping list be *visible* — the Forge showing "steel: 2/9 toward known recipes", schematic costs listed before they're learned — or is discovering the budget part of the stage?
    **A:** Partially visible: the Forge tab already lists grayed steel recipes with costs (clickable to inspect); schematic recipes stay hidden until read (GL-06). No aggregate "steel: 2/9" counter.
- [x] **S3-44.** What is the minimum technology set for surviving The Dark's 2 HP/s clock on entry day — iron tank + a boundary camp? — and should the design guarantee any of it before the band lets you deep enough to die badly?
    **A:** Iron tank (90 s > the 50-s cold clock), a drained boundary camp within the last Cold floors, banked medkits. Not guaranteed (GL-01), but telegraphed by the HUD indicator (S3-28/S3-50).
- [x] **S3-45.** Which resources should the player be *hauling down* rather than finding below — stone for deep Forges, cloth for the hard suit, wood for ladders — and does the weight economy make that hauling a real logistics stage?
    **A:** Stone (deep Forges, steel input) and cloth (hard suit) are the hauled-down resources; plastic secondarily. Wood comes from `broken_ladder` scrap below. At stone 1.5 weight, a Forge's 10 stone is 15 — real but bounded logistics; keep.
- [x] **S3-46.** Where should the hard-suit schematic hunt *begin* — should late Cold tables carry a whisper of it (a torn page, a diver's log naming a vault) so Stage Four opens with a heading, not a blank?
    **A:** No lore items (CC-04 story delivery is deferred): the whisper is `schematic_hard_suit` at w1 in `safe.cold`, so torch-opened Cold safes can start Stage Four with the recipe in hand.
- [x] **S3-47.** What ability/skill audit does the boundary assume — Scrapping 3 for steel harvest, a decision made on the Cold Blood path — and what happens to a player who invested purely in Swimming?
    **A:** Scrapping 3 only gates harvesting steel from furniture/structure; Forge steel needs no skill, so a Swimming build is slower, never stonewalled. Skills level by use, so the correction is natural; no respec (S4-26).
- [x] **S3-48.** Is the torch a Stage Three exit purchase or a Stage Four opener (S3-29 asks the order) — and whichever way, what should the *first* torch use be aimed at so the purchase lands as power, not chore?
    **A:** Exit purchase (late Stage Three), first use aimed at a Cold safe already pinned on the map (S3-08) — a known prize, not a chore.
- [x] **S3-49.** What tells a player The Cold is *done with them* — iron-per-dive falling, every metal door on the map opened — and is that depletion signal legible enough to steer descent without a prompt?
    **A:** Depletion is read on the map and cards: looted containers show empty on hover, opened lock markers grey out, and iron per dive falls. No prompt; the telemetry (S3-34) checks the signal lands.
- [x] **S3-50.** How should the first Dark peek be survivable by design — a boundary camp row that generation guarantees, the 2 HP/s clock readable on the HUD before it starts — so the stage transition is a plan, not a surprise dip into damage?
    **A:** The HUD indicator turns red at the Dark row, damage starts exactly there at 2 HP/s (50 s — retreatable), and rating 2 or Cold Blood removes it. No generation guarantee of a boundary camp (emergent).

## New topics surfaced (review 2026-09-05)

- [ ] **S3-51.** Should locked archetypes get their own `locked.<zone>` loot table or a bonus roll on the zone table?
- [ ] **S3-52.** HUD cold indicator (S3-28): always-on, or only with a `dive_watch` worn?
- [ ] **S3-53.** Found `bolt_cutters` in `industrial.cold` (w1): keep as a shortcut find or remove so the Forge is the sole source?
- [ ] **S3-54.** Lock markers (S3-08): per-character `MapReveal` save and LAN sync?
- [ ] **S3-55.** Rusted-door debris (S3-38): does `kind: scrap` reuse suffice, or does it need a decay timer?
- [ ] **S3-56.** The 5x tool-cost rule (2026-09-01) made the steel chain 17 steel = 34 iron + 17 stone plus 15 iron for bolt cutters and 15 for the iron knife — does the Cold's iron budget (`m5_smoke` depletion check, S3-18) still cover it, or do tool costs / iron weights need a retune?

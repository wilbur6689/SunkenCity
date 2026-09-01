# Stage Two — First Dives

> *Dive underwater to reach the shallow submerged levels of buildings, limited by a basic oxygen
> supply.* — GameOverview.md, Main Game Loop

The player has a base and scrap tools; now they learn the water. This is the **tank-and-pump**
stage: time underwater is the constraint, and drained rooms are the first real progress.

| | |
|---|---|
| **Band** | The Shallows — rows 0–40 below the waterline (`BAND_SHALLOWS_DEPTH`), ≈ 6–7 floors |
| **Target time** | ~15 h (GL-27) |
| **Entry state** | Scrap tools, workbench base, first `tank_scrap` (60 s total air) |
| **Exit capability** | **Wetsuit** (cold rating 1) + a Forge fed by Shallows stone — ready to enter The Cold |
| **Milestones** | M2 (water sim, pumps, lighting), M3 (bands, cold gates), M4 (floaters, speargun) |

**Open questions** (`S2-NN`) close every section below: open-ended prompts meant to add variety and harden playability. Same workflow as `../OpenQuestions.md` — answer on an indented `**A:**` line, mark `[x]` answered or `[~]` deferred.

---

## Where it happens

- The first floors below the waterline in every tower, reached through breaches, broken
  windows, and the **elevator shaft** (CT-06) — flooded shafts are swim tubes and the prime
  pump-out target.
- Flooding is **pure connectivity** (CT-12): the sim ran to equilibrium at gen, so anything
  connected to the ocean is full, and **sealed rooms kept their air** (CT-13). Finding an honest
  air pocket two floors down is the Stage Two "aha" — and the first forward camp.
- Twin-wing towers: ladder stairwells on both sides, elevator shaft down the centre. Submerged
  ladder runs are decayed into gaps (`broken_ladder`): scrap for wood, craft ladders, re-rig the
  climb home.
- Sunlight fades with depth (`LightMap`: sun + BFS point sources; light absorbed faster through
  water). Exteriors are always revealed; interiors are fog-of-war.

**Open questions**

- [ ] **S2-01.** What distinguishes flooded floor types at a glance (zone-specific floating debris, silt, hanging cables) so navigation doesn't lean on the map?
- [ ] **S2-02.** Should some Shallows rooms hold *partial* air — a ceiling pocket in a half-flooded room — as emergent breathing stops between sealed rooms?
- [ ] **S2-03.** What could live in the elevator shaft besides water — a stuck cab as a pry-bar puzzle, a surviving ladder run, a Drowned-free "safe tube" — to make it the highway the design wants?

## What the player has coming in

`pry_bar` / `scrap_knife` / `hammer`, a Workbench, bed, chest, lamp — and the Dive Station
(6 scrap + 4 plastic). The three tank tiers (GL-10) start here:

| Accessory | Recipe (Dive Station) | Air | Total with 30 s lungs |
|---|---|---|---|
| `tank_scrap` | 4 scrap metal + 1 plastic | +30 s | 60 s |
| `tank_iron` | 4 iron + 1 plastic | +60 s | 90 s (Stage Three — iron is Cold-band loot) |
| `rebreather` | schematic; 3 steel + 3 plastic + cloth | +150 s | 3 min (Stage Four/Five) |

Tanks **refill automatically in breathable air** (LT-17) — a drained room is a refuel stop, so the
tank and the pump are two halves of one purchase.

**Open questions**

- [ ] **S2-04.** Should the first tank sometimes be *found* (a hospital O2 bottle) so some seeds shortcut the Dive Station and others don't?
- [ ] **S2-05.** What dive-planning UI does a new diver need — an O2 bar that predicts the round trip, a breadcrumb count, a depth readout — without over-instrumenting?
- [ ] **S2-06.** Should a pump be heavy enough to carry to be a decision, or light so patch-and-pump is tried early and often?

## The loop at this stage

1. **Plan the dive** — 60 s, neutral buoyancy, underwater swim at walk speed (5 b/s; user tuning
   2026-08-31). Carried weight slows swimming, so dive light and stash heavy hauls in a chest at
   the entry point.
2. **Dive, grab, surface** — Shallows containers: scrap metal, plastic, glowsticks, food, cloth.
   Drop `glowstick`s (they **sink** — breadcrumbs, radius-4 light, fog beacons) to mark the route.
3. **Patch and pump** (GL-16, WaterPhysics.md) — find a room with few breaches, seal them with
   blocks (placing into water displaces or destroys it), craft a **pump** (6 scrap + 2 plastic),
   target an outlet cell up to 24 blocks away (`PUMP_RANGE_BLOCKS`), drain it bone dry. It stays
   dry.
4. **Move in** — stations and beds work in drained rooms (GL-17): the first **forward camp**,
   two floors below the waterline, with free air. Fog beacons keep it revealed.
5. **Harvest stone** — Shallows rooms hold stone; 10 stone + 4 scrap builds the **Forge**. Mount it
   at the base (or the camp) and the iron/steel ladder becomes possible — once there is iron.
6. **Feel the ceiling again** — Shallows tables hold **no iron** (`data/loot.json`,
   GL-28 depletion). The Forge sits cold until the player enters The Cold.

**Open questions**

- [ ] **S2-07.** What is the first drained room's payoff beyond air — dry loot that was ruined underwater, a breaker that now works, a window view?
- [ ] **S2-08.** How do we reward route-building (ladders re-rigged, glowstick trails, doors that hold water) as much as looting?
- [ ] **S2-09.** Should patched breaches ever reopen (a wall gives way, red-moon pounding) so camps need maintenance — or is "stays dry" a promise we keep?

## Systems in play

- **Cellular water** (`scripts/world/water_sim.gd`): 8-level cells, flows down and settles,
  awake-set dormancy. Removing a block wakes neighbours; **displace if possible, destroy if
  enclosed** (WS-24) — fill-to-drain with blocks stays a legitimate cheap tactic.
- **Pumps**: targeted outlet (E on pump → click a cell), fixed rate, suction/insertion through the
  connected body via BFS so slope-1 wedges don't freeze. Doors seal water even when their room
  isn't instantiated (records-based queries).
- **Displacement as a weapon/tool**: flooding a floor below is a legitimate fall-safety strategy
  (WS-15); flooding a powered area **trips its breaker** (WS-17).
- **Speargun** (3 scrap + 2 plastic + cloth, Workbench) — the underwater ranged weapon; bolts
  (1 scrap each) are retrievable (GD-08). Melee is slowed underwater (`water_factor` 0.45–0.5),
  knives least (GD-08).
- **Fish schools** appear from the Shallows: passive, grabbed by hand (GD-09), `fish_meat` heals 8
  — the only renewable food (LT-27).
- **Med Station** (4 scrap + 4 plastic + 2 cloth): `medkit` (heal 60, cures bleeding) and
  bandage batches. Stage Two is when bleeding from crawler bites starts to matter on long swims.

**Open questions**

- [ ] **S2-10.** Which extra water behaviours would add variety — slow seepage through wood, a surge when a door opens onto a full room, siphoning between rooms?
- [ ] **S2-11.** Should pumps show fill state and sound so a room draining reads as a satisfying event rather than a bar ticking?
- [ ] **S2-12.** What underwater movement flourishes (ledge grab, wall push-off, drop-weight sprint) would make swimming a skill rather than a speed stat?

## Crafting & recipes unlocked in practice

| Station | Recipes that come online in Stage Two |
|---|---|
| Dive Station | `tank_scrap`, `pump`, `wetsuit` (4 cloth + 3 plastic — see tuning note) |
| Workbench | `stone_block`, `speargun`, `speargun_bolt`, `helmet_lamp` |
| Med Station | `medkit`, `medkit_bandages` |
| Forge (built, mostly idle) | `steel` (2 iron + stone), `bolt_cutters`, `iron_sword`, `pistol_rounds`, `rifle_rounds` — all need iron |
| Modification Bench | Learn/apply modifiers — but modded gear only rolls on **found** loot, and Shallows tables carry no gear yet |

**Open questions**

- [ ] **S2-13.** What is the cheapest genuinely new Stage Two item — a glowstick lantern, a breach patch kit, a rope anchor, a bucket?
- [ ] **S2-14.** Should stone have a Stage Two source other than loot (breaking brick/glass with scrap tools) so the Forge isn't a save-up wall?
- [ ] **S2-15.** Is the wetsuit better as a Stage Two craft (cheap, current data) or a Stage Three reward (iron, GL-11)?

## Loot & materials

| Source | Yields (Shallows tables) |
|---|---|
| Generic | scrap metal 1–3, plastic 1–3, glowsticks, food can, cloth |
| Residential | food, cloth (+ wood, plastic) |
| Office | scrap metal, plastic |
| Hospital | bandages, medkits |
| Furniture / structure | stone from broken stone partitions **needs tool tier 2** (iron) — Stage Two stone comes from scrap and loot, so the Forge is a real save-up |
| Missing on purpose | iron, steel, gear, firearms |

**Open questions**

- [ ] **S2-16.** What should the Shallows hold that the Dry cannot — waterlogged electronics, sealed food, dive gear from a rooftop dive shop?
- [ ] **S2-17.** Should some containers have *floated* to the ceiling so looting rewards looking up?
- [ ] **S2-18.** How is loot signposted underwater — glints, silhouettes, fish gathering around it — given fog and fading light?

## Dangers

| Threat | Shallows stats | Notes |
|---|---|---|
| Walker | 40 HP, 10 dmg, 2.2 b/s, aggro 10 | Dry pockets and drained rooms — clearing a room before pumping it |
| Crawler | 26 HP, 8 dmg, 2.6 b/s, aggro 8 | Vents and 2-block gaps around stairwells |
| Floater | 24 HP, 8 dmg, 1.2 b/s, aggro 9 | Surface entry/exit points; more at night |
| Drowning | 60 s of air, 10 s dash | Still the main killer — one wrong turn in a flooded corridor |
| No sharks, no Drowned | — | The Shallows are shark-free (GD-11); open water is safe swim-planning space |

Firearms don't fire submerged; the speargun and knife are the dive kit. Darkness is visibility
only (GD-18) — glowsticks and the `helmet_lamp` (light 9, head slot) solve it.

**Open questions**

- [ ] **S2-19.** What would make floaters a real Stage Two problem — clustering at breaches, blocking the surface exit when air is low?
- [ ] **S2-20.** Is there room for one passive hazard (a live cable in a flooded office, harmless until the breaker is flipped) that ties power and water together early?
- [ ] **S2-21.** How should almost-drowning feel — is a last-second "surface grab" lunge worth adding, or does the 10 s dash already do the job?

## Base & water

- **Forward camps** emerge from the sim (GL-17): drain a room → breathable, buildable, safe from
  cold (later). Deep progress is made of drained rooms; Stage Two teaches the pattern shallow.
- Backpack recovery (CC-07): a Stage Two death in a flooded room pins the bag to that room's
  ceiling — swim back with a fresh tank; gear stays worn, so the tank is never lost.
- Red moons continue (day 5–10 clock, scaling +0.3 walkers/day, +5 % stats/day). A base below
  the waterline is a **drowned approach** — walkers can't swim to it (GL-15).

**Open questions**

- [ ] **S2-22.** What does a good forward camp look like in the fiction — a drained apartment with the tide line still on the walls, furniture stacked where it floated?
- [ ] **S2-23.** Should water be storable (tanks, barrels) so a flood can be carried to a doorway or a moat refilled?
- [ ] **S2-24.** Can a player flood their own surface base on purpose for a red moon, then pump it out — and is that too strong?

## Skills & abilities

Swimming XP accrues every second in water (0.5/s) — Stage Two is where **Swimming** overtakes
Scrapping. Second/third ability points arrive; **Free Diver** (−20 % O2 drain) is the Stage Two
power pick, effectively a free half-tank; **Tool Harness** opens a third accessory slot (tank +
future fins/watch).

**Open questions**

- [ ] **S2-25.** Should Swimming give visible per-level perks (longer water-jump, faster descent) rather than only XP toward player level?
- [ ] **S2-26.** Is Free Diver too obviously the best pick — how do we make Salvage or Building tempting to a diver?
- [ ] **S2-27.** Should a separate Diving skill exist, leveled by time submerged, or does Swimming carry it?

## Exit gate — what pushes the player down

- **Cold** begins at row 40: submerged without a cold-rated suit the player is slowed to 65 %
  (`COLD_SLOW_FACTOR`) — pushable for a peek, not for looting (GL-12 soft gate).
- The **wetsuit** (cold 1) is the doorway; **iron** — for `tank_iron`, `bolt_cutters`, and the
  metal doors they open — only exists in The Cold and below. The Forge is built and waiting.

**Open questions**

- [ ] **S2-28.** What visible marker says The Cold begins (a colour band on the walls, a shiver, fogged view) before the slow hits?
- [ ] **S2-29.** Should the first Cold peek be *rewarded* — iron visible just below the line — so the gate pulls as much as it pushes?
- [ ] **S2-30.** How do we keep an iron-less Stage Two player from feeling stuck — is a second Shallows goal (the shaft, a fully drained floor) needed?

## Tuning knobs

`BAND_SHALLOWS_DEPTH` 40 · `PUMP_RANGE_BLOCKS` 24 · `COLD_SLOW_FACTOR` 0.65 ·
`UNDERWATER_SWIM_SPEED` 5 b/s · `WEIGHT_SWIM_REFERENCE` 60 / `WEIGHT_SWIM_MIN_FACTOR` 0.3 ·
`ITEM_BUOYANCY_RISE` 3 b/s · glowstick radius 4 · `STRUCTURE_TIER` stone = 2.

**Open questions**

- [ ] **S2-31.** Is 40 rows (≈ 6–7 floors) enough Shallows for ~15 h, or should band depth scale with tower height?
- [ ] **S2-32.** Should pump rate scale by tier so a scrap pump is slow enough that patching first matters?

## Design references

GL-04/05/07/10/13/16/17/20/21 · CC-13 · WS-06/07/09/10/14/15/17/23/24 · GD-05/08/09/10/11/18 ·
LT-17/23/27 · CT-06/12/13/15 · `technical/WaterPhysics.md` (M2 implementation decisions).

## Open / feel-check notes

- **Wetsuit pricing**: GL-11 calls the wetsuit *iron tier*; `data/recipes.json` prices it at
  4 cloth + 3 plastic (Shallows-affordable). Decide in the M4 balance pass whether the cold gate
  should cost iron (harder Stage Two→Three door) or stay cheap (iron gates only tank/tools).
- Boats/raft are at the MVP boundary (GL-19, MVP-overview Open Items) — Stage Two is where a raft
  would first pay off (cargo between towers).
- Pacing target ~15 h is unmeasured (GL-27).

**Open questions**

- [ ] **S2-33.** What does a *bad* Stage Two look like (drowning loops, bags pinned on ceilings) and what safety valve prevents a quit?
- [ ] **S2-34.** Is a raft in scope purely as the cargo answer for this stage?


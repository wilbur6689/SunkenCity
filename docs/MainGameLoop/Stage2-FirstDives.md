# Stage Two — First Dives

> *Dive underwater to reach the shallow submerged levels of buildings, limited by a basic oxygen
> supply.* — GameOverview.md, Main Game Loop

The player has a base and scrap tools; now they learn the water. This is the **tank-and-pump**
stage: time underwater is the constraint, and drained rooms are the first real progress.

| | |
|---|---|
| **Band** | The Shallows — rows 0–80 below the waterline (`BAND_SHALLOWS_DEPTH`; 0–40 before the 8 px cell of 2026-09-04), ≈ 6–7 floors |
| **Target time** | ~15 h (GL-27) |
| **Entry state** | `wood_axe`, bucket and planter farm on the spawn roof (no medical room since 2026-09-04); Workbench with the scrap tools (pry bar / knife / hammer, 5x costs); first `tank_scrap` (60 s total air) |
| **Exit capability** | **Wetsuit** (cold rating 1) + a Forge fed by Shallows stone — ready to enter The Cold |
| **Milestones** | M2 (water sim, pumps, lighting), M3 (bands, cold gates), M4 (floaters, speargun) |

**Open questions** (`S2-NN`) close every section below: open-ended prompts meant to add variety and harden playability. Same workflow as `../OpenQuestions.md` — answer on an indented `**A:**` line, mark `[x]` answered or `[~]` deferred.

**Units note (2026-09-05 review):** speeds and radii quoted below in blocks/s or blocks predate the 8 px cell of 2026-09-04; in today's cells every such figure doubles (walk 10 / sprint 14 / swim 10 cells/s, jump 6; enemy speeds are already ×2 in `data/enemies.json`). Ratios are unchanged. Costs and row numbers have been corrected to current data where the review found them stale.

---

## Where it happens

- The first floors below the waterline in every tower, reached down the stairwells and the
  **elevator shaft** (CT-06) once the `roof_hatch` is levered — flooded shafts are swim tubes and
  the prime pump-out target. Each surface tower keeps a randomized **4–8 dry floors** capped by a
  tier-1 **wood barrier** (the dry cap), and Shallows-band wear breaches are sealed by **`side_vent`**
  grates (pry tier 1), so the first dive usually starts by breaking a cap or prying a vent; deeper
  breaches are the flood inlets.
- Flooding is **pure connectivity** (CT-12): the sim ran to equilibrium at gen, so anything
  connected to the ocean is full, and **sealed rooms kept their air** (CT-13). Finding an honest
  air pocket two floors down is the Stage Two "aha" — and the first forward camp.
- Twin-wing towers: ladder stairwells on both sides, elevator shaft down the centre. Submerged
  ladder runs are decayed into gaps (`broken_ladder`): scrap for wood, craft ladders, re-rig the
  climb home.
- Sunlight fades with depth (`LightMap`: sun + BFS point sources; light absorbed faster through
  water). Exteriors are always revealed; interiors are fog-of-war.

**Open questions**

- [x] **S2-01.** What distinguishes flooded floor types at a glance (zone-specific floating debris, silt, hanging cables) so navigation doesn't lean on the map?
    **A:** Read the zone from what's already there, not new art: district back-wall tint (every floor of a tower shares its district's zone now), `_zone_details` decals per zone, and the zone's own furniture set. Underwater add only two cheap layers — a depth-scaled particulate/silt density and **floated clutter** (S2-17) whose silhouettes are zone-specific by construction. No hanging-cable set for MVP. Modifier aspect reserved for the user's modifier pass.
- [x] **S2-02.** Should some Shallows rooms hold *partial* air — a ceiling pocket in a half-flooded room — as emergent breathing stops between sealed rooms?
    **A:** Yes, but emergent only (CT-12/13). The pressure-less sim already produces them: a room whose only breach is low fills sideways to the breach row and keeps a ceiling pocket above it, so partial air appears wherever the wear pass cut a low breach. Never author them; instead let the wear pass vary breach height so pocket shapes vary, and treat the pocket's waterline as a clue to where the breach is (S2-42).
- [x] **S2-03.** What could live in the elevator shaft besides water — a stuck cab as a pry-bar puzzle, a surviving ladder run, a Drowned-free "safe tube" — to make it the highway the design wants?
    **A:** A **stuck cab** per tower (CT-06 canon), placed at a seeded floor as a `fixed`, no-item object of the `roof_hatch` class (kind `door`, `lock_tier` 1 — pry bar or `wood_tripod`) spanning the shaft; above it the shaft is a rope drop, below a swim tube and the prime pump-out. Prying it open yields a Shallows container roll. No "safe tube" flag — the shaft is already Drowned-free at this band (GD-10/11). Movable-cab physics is S2-37.

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

- [x] **S2-04.** Should the first tank sometimes be *found* (a hospital O2 bottle) so some seeds shortcut the Dive Station and others don't?
    **A:** Yes, as a rare shortcut, never guaranteed: add `tank_scrap` at low weight to `civil/shallows` (a hospital O2 bottle) so a 30 s peek can occasionally win the first tank. Found gear rolls modifiers (M5), so the found bottle is *better* than the crafted one — worth the gamble. The Dive Station is still required for the pump and wetsuit, so the stations lesson isn't skipped. (`safe/shallows` already rolls one but sits behind lock tier 3 — Stage Four backtrack loot, not a shortcut.)
- [x] **S2-05.** What dive-planning UI does a new diver need — an O2 bar that predicts the round trip, a breadcrumb count, a depth readout — without over-instrumenting?
    **A:** Two additions, no more: a **turnaround tick at 50 %** on the existing O2 bar (the round-trip predictor without pathing), and a depth readout in feet below the waterline on the HUD (the F3 label already resolves it). No breadcrumb counter — the hotbar stack count is the glowstick count.
- [x] **S2-06.** Should a pump be heavy enough to carry to be a decision, or light so patch-and-pump is tried early and often?
    **A:** Keep the pump heavy: `objects.json` weight 15 is a quarter of `WEIGHT_SWIM_REFERENCE` 60, a felt slow that doesn't cripple; the pump is picked up (hold LMB) and re-sited room to room, so one pump is a reusable tool, not a consumable. The decision is *where* to carry it, and the cost is the swim, which matches WS-10/14. Confirm the factor in the balance pass.

## The loop at this stage

1. **Plan the dive** — 60 s, neutral buoyancy, underwater swim at walk speed (10 cells/s,
   `UNDERWATER_SWIM_SPEED`; user tuning 2026-08-31). Carried weight slows swimming, so dive light and stash heavy hauls in a chest at
   the entry point.
2. **Dive, grab, surface** — Shallows containers: scrap metal, plastic, glowsticks, food, cloth.
   Drop `glowstick`s (they **sink** — breadcrumbs, `GLOWSTICK_LIGHT` 22 of 30, fog beacons) to mark the route.
3. **Patch and pump** (GL-16, WaterPhysics.md) — find a room with few breaches, seal them with
   blocks (placing into water displaces or destroys it), craft a **pump** at the Dive Station
   (6 scrap + 2 plastic), target an outlet cell up to 48 cells away (`PUMP_RANGE_BLOCKS`), drain
   it bone dry. It stays dry.
4. **Move in** — stations and beds work in drained rooms (GL-17): the first **forward camp**,
   two floors below the waterline, with free air. Fog beacons keep it revealed.
5. **Harvest stone** — Shallows rooms hold stone; 10 stone + 4 scrap builds the **Forge**. Mount it
   at the base (or the camp) and the iron/steel ladder becomes possible — once there is iron.
6. **Feel the ceiling again** — Shallows tables hold **no iron** (`data/loot.json`,
   GL-28 depletion). The Forge sits cold until the player enters The Cold.

**Open questions**

- [x] **S2-07.** What is the first drained room's payoff beyond air — dry loot that was ruined underwater, a breaker that now works, a window view?
    **A:** The payoff is **systems that only work dry**, not dry-bonus loot (LT-27 one-time rolls, no double dipping): the floor's breaker can be re-flipped once the room is dry (WS-17 tripped it), so wired lights come on; stations, beds and firearms all work there (GL-17, GD-08). Pumping a floor with a breaker is therefore the intended first "lights come back on" moment.
- [x] **S2-08.** How do we reward route-building (ladders re-rigged, glowstick trails, doors that hold water) as much as looting?
    **A:** Ladders, ropes and placed lights award **Building XP** like blocks, and player-placed climbables/lights get their own `MapColors` entry so the rigged route home is visible on **M**. Fog beacons already keep lit routes revealed. Nothing else — route-building is its own reward once the map shows it.
- [x] **S2-09.** Should patched breaches ever reopen (a wall gives way, red-moon pounding) so camps need maintenance — or is "stays dry" a promise we keep?
    **A:** "Stays dry" is a promise (CT-13 honesty, GL-29 recoverable). No random reopening; red moons pound player-placed blocks only and converge on the player (GL-15), and walkers can't swim, so a submerged patch is never hit unless the player is standing next to it at the surface. The only maintenance is the player's own mistakes (S2-42).

## Systems in play

- **Cellular water** (`scripts/world/water_sim.gd`): 8-level cells, flows down and settles,
  awake-set dormancy. Removing a block wakes neighbours; **displace if possible, destroy if
  enclosed** (WS-24) — fill-to-drain with blocks stays a legitimate cheap tactic.
- **Pumps**: targeted outlet (interact-click the pump → click a cell), fixed rate (`PUMP_UNITS_PER_TICK` 8 = 60 cells/s), suction/insertion through the
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

- [x] **S2-10.** Which extra water behaviours would add variety — slow seepage through wood, a surge when a door opens onto a full room, siphoning between rooms?
    **A:** No new sim rules for MVP. Seepage through wood breaks the "solid blocks seal" rule (WS-20/24) that makes patching honest; siphoning needs a pressure model the sim deliberately lacks. Variety comes from presenting what the sim already does — the door surge (S2-38) and breach drift (S2-39) — with engineered currents (WS-16) post-MVP.
- [x] **S2-11.** Should pumps show fill state and sound so a room draining reads as a satisfying event rather than a bar ticking?
    **A:** Yes: a running pump loop SFX, an outlet bubble/splash particle at the target cell, "cells moved" on the pump's hover card, and a **room-dry stinger** when the connected body under the intake hits zero. All UI/audio (`Audio.play_sfx`, a `spawn_break_puff`-style CPUParticles) — no sim change.
- [x] **S2-12.** What underwater movement flourishes (ledge grab, wall push-off, drop-weight sprint) would make swimming a skill rather than a speed stat?
    **A:** One flourish: a **wall push-off** — pressing away from a solid while submerged gives a short free burst. Ledge grab already exists (climb grab-and-hang, water-jump onto ledges); a drop-weight sprint is rejected because the soft weight cap (WS-14) and the backpack drop already cover "shed load to move". Tune the burst in the feel pass.

## Crafting & recipes unlocked in practice

| Station | Recipes that come online in Stage Two |
|---|---|
| Dive Station | `tank_scrap`, `pump`, `wetsuit` (4 cloth + 3 plastic — see tuning note) |
| Workbench | `stone_block`, `speargun`, `speargun_bolt`, `helmet_lamp` |
| Med Station | `medkit`, `medkit_bandages` |
| Forge (built, mostly idle) | `steel` (2 iron + stone), `bolt_cutters`, `iron_sword`, `pistol_rounds`, `rifle_rounds` — all need iron |
| Modification Bench | Learn/apply modifiers — but modded gear only rolls on **found** loot, and Shallows tables carry no gear yet |

**Open questions**

- [x] **S2-13.** What is the cheapest genuinely new Stage Two item — a glowstick lantern, a breach patch kit, a rope anchor, a bucket?
    **A:** The bucket already exists (S1-23). The cheapest new Stage Two item is a **`glow_float`** (Workbench, 2 plastic + 1 glowstick): a buoyant glowstick that rises at `ITEM_BUOYANCY_RISE` and pins to the ceiling as a fog beacon — marks air pockets, ceilings where bags pin (CC-07), and the way up. Data only: the `WorldItem` buoyancy path exists; the item gets a `buoyant` flag the sinking glowstick lacks.
- [x] **S2-14.** Should stone have a Stage Two source other than loot (breaking brick/glass with scrap tools) so the Forge isn't a save-up wall?
    **A:** Keep stone out of container tables (they carry none today) and out of scrap-tool reach on structure (`STRUCTURE_TIER` stone 2 stands). Stone's Stage Two source is **objects**: statues (`statue_stone/lion` tier 1, Scrapping 1), plants and counters (tier 0) via `_zone_details`. Raise the `statement`/plant frequency for Shallows-band floors to a target of ≥ 2 stone-yielding objects per submerged floor so the Forge's 10 stone is a 3–5-room project, not a wall.
- [x] **S2-15.** Is the wetsuit better as a Stage Two craft (cheap, current data) or a Stage Three reward (iron, GL-11)?
    **A:** Stage Two craft, kept cheap (4 cloth + 3 plastic). Iron exists only in The Cold and below, so an iron wetsuit would lock The Cold behind its own loot; the canon table makes the Forge, not the suit, Stage Two's door, and `safe/shallows` already rolls wetsuits at scrap tier. **Amend GL-11**: "iron tier" refers to the tank/tools; the wetsuit is scrap-tier and the iron gate is what pulls into The Cold.

## Loot & materials

| Source | Yields (Shallows tables) |
|---|---|
| Generic | scrap metal 1–3, plastic 1–3, glowsticks, food can, cloth |
| Residential | food, cloth (+ wood, plastic) |
| Business / commercial | scrap metal, plastic (the drowned dive shop: `fins`, S2-16) |
| Civil | bandages, medkits, cloth (a hospital O2 bottle: `tank_scrap`, S2-04) |
| Industrial | scrap metal 3–6 |
| Construction | wood 3–5, scrap 3–5, rope 2–4 |
| Stone | comes from **objects** — statues, plants, counters (tier 0–1, `_zone_details`); container tables hold none and stone structure needs tool tier 2 (iron), so the Forge's 10 stone is a several-room project (S2-14) |
| Missing on purpose | iron, steel, gear, firearms |

**Open questions**

- [x] **S2-16.** What should the Shallows hold that the Dry cannot — waterlogged electronics, sealed food, dive gear from a rooftop dive shop?
    **A:** Gear the Dry never has: `fins` at low weight in `commercial/shallows` (the drowned dive shop) and `tank_scrap` in `civil/shallows` (S2-04); rope and glowsticks stay Shallows-concentrated as now; waterlogged electronics are already the `wall_detail` vent/duct decals (scrap). Modifier aspect reserved for the user's modifier pass.
- [x] **S2-17.** Should some containers have *floated* to the ceiling so looting rewards looking up?
    **A:** Yes, for clutter only: in `pockets[].flooded` rooms and submerged floors, `_stamp_room` places a fraction of light, non-fixed `scrap`-kind furniture at the ceiling row (`dy` flipped) — floated chairs, boxes, plants. Containers stay on the floor so loot isn't hidden from new divers; the floated clutter rewards looking up and teaches where bags pin (CC-07).
- [x] **S2-18.** How is loot signposted underwater — glints, silhouettes, fish gathering around it — given fog and fading light?
    **A:** A periodic **glint** particle on unopened containers within the player's light; it stops once looted, so it doubles as the "did I open this?" answer (LT-27 one-time). No fish-gathering behaviour and no silhouette pass — the glint is self-lit so it reads through fading light and fog.

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

- [x] **S2-19.** What would make floaters a real Stage Two problem — clustering at breaches, blocking the surface exit when air is low?
    **A:** Bias floaters toward the **entry hole**: `aggro.gd` drifts surface floaters toward the nearest submerged breach/open cell within a radius of a player's last dive point, so they gather where the player will surface — blocking the exit at low air becomes emergent. Keep their 24 HP; the threat is the timing, not the fight (GD-05 night extras still apply).
- [x] **S2-20.** Is there room for one passive hazard (a live cable in a flooded office, harmless until the breaker is flipped) that ties power and water together early?
    **A:** One: the **live cable**, a wall-mounted `wall_detail`-class object in business/industrial zones. Inert while its floor's breaker is off; flipping the breaker with the cable submerged fires a one-shot shock pulse (damage + knockback) through that water body, then trips the breaker (WS-17). Telegraphed by sparks/hum while powered; non-lethal from full HP (GL-29). Data: object flag + breaker hook.
- [x] **S2-21.** How should almost-drowning feel — is a last-second "surface grab" lunge worth adding, or does the 10 s dash already do the job?
    **A:** No lunge; the 10 s dash (`DROWNING_SECONDS_TO_DEATH`) is the mechanic and the water-jump already gives 2 blocks at the surface. Add feel only: heartbeat SFX and a vignette from 20 % O2, escalating into the drowning tint. Death is already soft (CC-07, gear stays worn).

## Hazards, puzzles & water management

Stage Two's antagonist is the water and its toy is also the water. This section covers the
hazard space around the Dangers table: the puzzles the sim generates, the traps the odds
tables spring, and the management loop (patch → pump → hold) that defines the band.

- **Monster texture**: floaters guard the surface exits, crawlers thread the vents around
  stairwells, walkers wait in the dry pockets you're about to drain. Nothing hunts you *in*
  the water yet (GD-11) — the Shallows are where swimming is learned safely.
- **The trap that matters is the round trip**: 60 s of air reads as plenty on the way in and
  as nothing on the way out with a full bag. Every Shallows corridor is implicitly a trap
  armed by the player's own greed.
- **Puzzles are connectivity**: which breach feeds this room? where did the air pocket come
  from? why won't this room drain? The sim's honesty (CT-12/13) is what makes these solvable
  by observation — bubbles, flow, and the tide line are the clue set.
- **Patch-and-pump is the puzzle *and* the reward**: reading a room's breaches, sealing in
  the right order, and siting the pump well is Stage Two's skill expression; the drained,
  breathable, buildable room is its trophy (GL-16/17).

**Open questions**

- [x] **S2-35.** Should some rooms be lightly authored as *pump puzzles* — breach counts and positions that reward reading the room (seal the ceiling hole first or the drain refills) — or does generation already produce enough of these on its own?
    **A:** No authored pump puzzles (CT-12/13). The wear pass, side vents and construction's 0.95 breach rate already produce the spread; spend the effort on making the room *readable* (S2-39, S2-42) so emergent rooms are solvable by observation.
- [x] **S2-36.** Should generation guarantee an occasional *air-pocket chain* — sealed rooms at swimmable intervals forming a natural breathing route deeper — so dive-planning has terrain to express itself on?
    **A:** Not guaranteed — verified instead. 50 % pocket density × 40 % sealed-dry gives a dry pocket on ~20 % of submerged floors (about one per five), plus the low-breach ceiling pockets (S2-02): a natural chain across 6–7 Shallows floors. Add a `pocket_smoke` check that counts dry pockets per Shallows band rather than authoring a chain.
- [~] **S2-37.** The stuck elevator cab (S2-03): could it be a movable object — pry it open for loot, or flood/drain the shaft to float it like a piston — making the shaft the band's physics toy?
    **A:** Deferred. A cab that floats or pistons needs a multi-cell dynamic body in the sim and entity–flow coupling that MVP doesn't have; the static pry-cab (S2-03) covers Stage Two. Unblocked by the currents pass (WS-16, WaterPhysics open items) post-MVP.
- [x] **S2-38.** What happens when a door opens against a full room — a surge that shoves the player, a brief current, debris damage — and how strongly should loaded doors telegraph (seeping seams, groaning)?
    **A:** Presentation plus one impulse: on door-open the sim already inrushes; add a one-off **surge push** (`SURGE_PUSH` blocks/s applied to bodies in the doorway cells when the level delta is ≥ 4), no debris damage (GL-29). Telegraph loaded doors with seep particles at the seams and a groan SFX on hover — a records-based check of the door cell's neighbour water level, so far doors read too.
- [x] **S2-39.** Should breaches visibly *breathe* (slosh, particulate drift) when connected to the open ocean, so sealed-vs-connected reads at a glance before the first patch is placed?
    **A:** Yes: the wear pass registers breach cells (`World.breaches`); while a breach cell holds water and is not solid it emits a slow particulate drift. Placing a block makes the cell solid, so the drift stops exactly when the seal is real — sealed-vs-connected reads before the first pump is set.
- [x] **S2-40.** Fill-to-drain with blocks versus patch-and-pump: what material/effort pricing keeps both legitimate at this tier without blocks trivially outcompeting the pump the player just learned?
    **A:** Pricing already works: blocks cost 1 material per cell, so filling a 24×10 room is ~240 blocks, while a doorway (6×2) is 12 and a pump is 6 scrap + 2 plastic *once*, reusable. Fill-to-drain stays the pocket/doorway tool, the pump the room tool. No change; re-check after the 2×2 placement brush lands (it changes clicks, not cost).
- [~] **S2-41.** Should moving water move *things* — loose loot drifting toward breaches, dropped bags nudged by a drain in progress — so managing water visibly rearranges the world (and occasionally hides your own glowsticks)?
    **A:** Deferred. Items moved by flow need engineered currents (WS-16) and the "current strength tuning" open item in WaterPhysics; MVP water moves nothing but itself (plus item buoyancy). Hiding a player's own glowsticks is also anti-fun — if it lands, exclude beacons.
- [x] **S2-42.** When a player accidentally re-floods their forward camp (opened the wrong door, broke their own patch), what tells them *why* — a visible inrush from the culprit breach, a camera hint — so the failure trains the skill instead of feeling random?
    **A:** The sim's awake set *is* the inflow front: draw awake cells inside a previously-dry region with a stronger ripple/particle, and post a one-line HUD notice "Water inrush — west" from the first awake cell's direction (with the S2-39 drift naming the breach). No camera hint. Region tracking = the set of cells the last pump dried.

## Base & water

- **Forward camps** emerge from the sim (GL-17): drain a room → breathable, buildable, safe from
  cold (later). Deep progress is made of drained rooms; Stage Two teaches the pattern shallow.
- Backpack recovery (CC-07): a Stage Two death in a flooded room pins the bag to that room's
  ceiling — swim back with a fresh tank; gear stays worn, so the tank is never lost.
- Red moons continue (day 5–10 clock, scaling +0.3 walkers/day, +5 % stats/day). A base below
  the waterline is a **drowned approach** — walkers can't swim to it (GL-15).

**Open questions**

- [x] **S2-22.** What does a good forward camp look like in the fiction — a drained apartment with the tide line still on the walls, furniture stacked where it floated?
    **A:** A **tide-line decal** stamped on back-wall cells at the body's last water row when a room drains (`World` on region-dry), edge puddles the ripple rule already leaves, and the floated clutter (S2-17) now stranded at the ceiling. That is the fiction: a room that visibly *was* under water.
- [x] **S2-23.** Should water be storable (tanks, barrels) so a flood can be carried to a doorway or a moat refilled?
    **A:** No. The bucket (S1-23) is the hand-carry answer and the pump's 48-block outlet already carries water to a doorway or moat; barrels would add an inventory-of-water abstraction the sim doesn't need.
- [x] **S2-24.** Can a player flood their own surface base on purpose for a red moon, then pump it out — and is that too strong?
    **A:** Yes, and it is priced fairly: a flooded base is unusable for the night (stations/bed need air, GL-17), its breaker trips (WS-17), the player must sit in water among night floaters, and pumping it out afterwards is the Stage Two skill exercised. GL-15 already calls drowned approaches a premium defence; this is that.

## Skills & abilities

Swimming XP accrues every second in water (0.5/s) — Stage Two is where **Swimming** overtakes
Scrapping. Second/third ability points arrive; **Free Diver** (−20 % O2 drain) is the Stage Two
power pick, effectively a free half-tank; **Tool Harness** opens a third accessory slot (tank +
future fins/watch).

**Open questions**

- [x] **S2-25.** Should Swimming give visible per-level perks (longer water-jump, faster descent) rather than only XP toward player level?
    **A:** No per-level perks. Canon is gear-first with skills feeding player level → abilities, and Scrapping's only "perk" is a harvest gate; Swimming stays pure XP. Add the skill-up toast (S1-26) so learn-by-doing is legible.
- [x] **S2-26.** Is Free Diver too obviously the best pick — how do we make Salvage or Building tempting to a diver?
    **A:** No change. Free Diver is +6 s on lungs / +12 s on a scrap tank — useful, not dominant; Field Strip's value scales with depletion (GL-28) and Long Reach pays underwater while sealing. Both scale with the stage; record pick rates in the balance pass before touching numbers.
- [x] **S2-27.** Should a separate Diving skill exist, leveled by time submerged, or does Swimming carry it?
    **A:** No separate Diving skill — Swimming already accrues from time in water, and three skills keep player level ÷ 5 honest (mirrors S1-27). The ability *branch* named Diving (Cold Blood) is where dive specialisation lives.

## Exit gate — what pushes the player down

- **Cold** begins at row 80 (`BAND_SHALLOWS_DEPTH`): submerged without a cold-rated suit the player is slowed to 65 %
  (`COLD_SLOW_FACTOR`) — pushable for a peek, not for looting (GL-12 soft gate).
- The **wetsuit** (cold 1) is the doorway; **iron** — for `tank_iron`, `bolt_cutters`, and the
  metal doors they open — only exists in The Cold and below. The Forge is built and waiting.

**Open questions**

- [x] **S2-28.** What visible marker says The Cold begins (a colour band on the walls, a shiver, fogged view) before the slow hits?
    **A:** A depth colour-grade step at row 80 (WS-29: grade only), a one-off shiver — breath particle + SFX — on the crossing, and the HUD depth readout (S2-05) turning blue; this is the same HUD cold indicator Stage Three specifies (S3-28). All hang off `band_at`; the slow then arrives as a consequence the player saw coming.
- [x] **S2-29.** Should the first Cold peek be *rewarded* — iron visible just below the line — so the gate pulls as much as it pushes?
    **A:** Yes: the first Cold floor (the floor whose ceiling resolves to Cold under `floor_band_at`) should roll at least one iron-bearing object in its stairwell-adjacent room, and iron-yield furniture gets a distinct tint so it reads from the Shallows floor above through the stairwell. The peek shows the shopping list; the slow sends you back for the wetsuit.
- [x] **S2-30.** How do we keep an iron-less Stage Two player from feeling stuck — is a second Shallows goal (the shaft, a fully drained floor) needed?
    **A:** Two Shallows goals already exist without iron: the **shaft** (S2-03 cab → pump-out, CT-06) and the barred-door pockets (`door_button` rooms). Since the wetsuit is scrap-tier (S2-15) nothing stonewalls an iron-less player — the Cold is enterable the moment they choose. Being iron-less *is* the pull (GL-28).

## Tuning knobs

`BAND_SHALLOWS_DEPTH` 80 · `PUMP_RANGE_BLOCKS` 48 · `PUMP_UNITS_PER_TICK` 8 · `COLD_SLOW_FACTOR`
0.65 · `UNDERWATER_SWIM_SPEED` 10 cells/s · `WEIGHT_SWIM_REFERENCE` 60 / `WEIGHT_SWIM_MIN_FACTOR`
0.3 · `ITEM_BUOYANCY_RISE` 6 cells/s · `GLOWSTICK_LIGHT` 22 · `ROPE_DROP` 1 · `STRUCTURE_TIER`
stone = 2. Proposed by the review: `SURGE_PUSH` (S2-38), a floater entry-hole bias radius (S2-19),
the O2 turnaround tick fraction (S2-05).

**Open questions**

- [x] **S2-31.** Is 80 rows of 8 px (≈ 6–7 floors) enough Shallows for ~15 h, or should band depth scale with tower height?
    **A:** Keep 80. At 12-row pitch that is 6–7 floors (5–6 in civil/industrial towers) across 52 towers ≈ 300+ submerged floors — ample for 15 h. Bands are physics (cold at a depth) so they stay absolute rows; `floor_band_at` already handles pitch/crown variance. Measure in the GL-27 feel check.
- [x] **S2-32.** Should pump rate scale by tier so a scrap pump is slow enough that patching first matters?
    **A:** No pump tiers in MVP. Rate isn't what teaches patching — connectivity is: an unsealed room is "pumping the ocean" (WaterPhysics open item). So instead the pump's hover card states **"connected body: open to the ocean"** vs "sealed", making the lesson explicit. Iron/steel pumps (range/rate) remain a data-only post-MVP addition.

## Design references

GL-04/05/07/10/13/16/17/20/21 · CC-13 · WS-06/07/09/10/14/15/17/23/24 · GD-05/08/09/10/11/18 ·
LT-17/23/27 · CT-06/12/13/15 · `technical/WaterPhysics.md` (M2 implementation decisions).

## Open / feel-check notes

- **Wetsuit pricing — resolved (S2-15, 2026-09-05)**: the wetsuit stays a scrap-tier Stage Two
  craft (4 cloth + 3 plastic); GL-11's "iron tier" applies to `tank_iron` and the iron tools, and
  the iron gate *pulls* into The Cold rather than locking it. GL-11 needs the amendment line.
- Boats/raft are at the MVP boundary (GL-19, MVP-overview Open Items) — Stage Two is where a raft
  would first pay off (cargo between towers).
- Pacing target ~15 h is unmeasured (GL-27).

**Open questions**

- [x] **S2-33.** What does a *bad* Stage Two look like (drowning loops, bags pinned on ceilings) and what safety valve prevents a quit?
    **A:** The bad stage is a bag pinned in a room you can't reach on a fresh 60 s. Valves already in place: the tank stays worn (CC-07), the bag floats to the ceiling (the shortest swim in the room), respawn at the bed. Add one: a **backpack marker** on the minimap/map per character so a pinned bag is never lost.
- [x] **S2-34.** Is a raft in scope purely as the cargo answer for this stage?
    **A:** No. The districts city puts towers at 5–10-cell gaps, so cargo between towers is a hop, and the chest-at-the-entry pattern covers hauls; the raft's use case is the ocean margins (stations), a Stage Five/post-MVP concern (GL-19).

## Transition — Stage Two → Stage Three

The move into The Cold is the game's first *gear* door (the wetsuit) and its first *economy*
door (a built Forge starving for iron). Done right, the player crosses with the Shallows
mastered — pumping is routine, routes home are rigged, and the cold peek (S2-29) has shown
them exactly what they're saving for.

Expected state at the boundary: wetsuit worn (cold 1); Forge built and idle; a drained forward
camp below the waterline with a bed and chest; speargun + a bolt bundle; a Med Station and
banked medkits; ladders re-rigged on at least one route home; Free Diver or a second tank's
worth of O2 discipline.

**Open questions**

- [x] **S2-43.** Which of those should the design *require* versus merely reward — is the wetsuit alone (as the data currently prices it) too thin a bar for a band with sharks and a speed tax?
    **A:** Require nothing beyond the wetsuit (GL-01 pure capability). The bar is thin on purpose: The Cold's cost is its iron economy and the slow, not an entry check, and at 5–10-cell gaps a shark crossing between towers is a 1–2 s swim at 10 b/s — sharks bite in the margins and long lateral swims, which is a choice.
- [x] **S2-44.** Should a functioning forward camp be a soft prerequisite for The Cold — e.g. Cold dive math that only works from a below-waterline refill stop — so the pump skill is proven before entering the band that punishes skipping it?
    **A:** Soft prerequisite by arithmetic, not by lock: row 80 is 8 s down at 10 b/s, so a Cold dive from the surface on 60 s leaves ~40 s of work; a Shallows camp near row 60 turns transit into seconds. The math nudges toward the camp and the camp's tank refill (LT-17) — that is the proof of pumping, without a gate.
- [x] **S2-45.** What resource stockpile should Stage Three assume on entry (stone banked toward steel, glowsticks, bolts, bandages/medkits, spare pump materials) — and where does a player *see* that they're provisioned?
    **A:** Assume: 10 stone spent on the Forge + ~5 banked toward steel, 10+ glowsticks, ~10 bolts, 5 bandages + 2 medkits, one spare pump's materials (6 scrap + 2 plastic), wood for two ladder runs. Readout = the crafting tab (greyed recipes show the shortfall) and the chest; no new UI (same call as S1-45).
- [x] **S2-46.** What technology audit belongs at this boundary — all five stations built? the Med Station specifically, given shark bites and bleeding — and is any station allowed to still be unbuilt without Stage Three failing?
    **A:** Forge (the stage's exit item) and Dive Station are required in practice; Med Station is strongly advised (bleeding, sharks) but allowed unbuilt because bandages craft at the Workbench; the Modification Bench can wait (no gear rolls before The Cold). No station's absence fails Stage Three — stations are cheap and recipes are data.
- [x] **S2-47.** How does the first shark sighting get staged — ideally *seen from cover* before ever being fought — so open water's new rules are learned by observation, not death?
    **A:** Already free: exteriors are never fogged (WS-20) and sharks patrol open water from row 80 down (GD-11), so the first sighting is a shark passing a Cold-floor window or breach while the player stands inside. Reinforce with a muffled shark stinger when one enters view, and keep spawn columns adjacent to towers so the pass-by happens.
- [x] **S2-48.** What skill floor does The Cold assume (Swimming level, Scrapping 2 approaching for iron furniture) — and if a player arrives under it, does the band merely slow them or actually stonewall them?
    **A:** No hard floor. Scrapping 2 gates iron *furniture* (M5), but `generic.cold` rolls iron 1–2 in containers, so an under-skilled player is slowed to container iron, not stonewalled; Swimming level is irrelevant to entry. Slow, never stonewall — GL-29 in skill form.
- [x] **S2-49.** What still pulls the player *back up* through Stage Two spaces afterwards — Shallows camps as waystations, the surface base as warehouse — and does the hauling loop keep those spaces alive?
    **A:** **Wood.** Trees reach full 5×15 only under open sky, so the roof farm is the only renewable wood and every ladder, chest, planter and tripod below needs it — the hauling loop runs *down* (wood) as well as up (iron). Shallows camps are the refill waystations (LT-17); the surface base is the farm and red-moon-proof warehouse.
- [x] **S2-50.** Which Stage Two lesson must be *certain* before Stage Three (round-trip O2 math? patch-before-pump? door discipline?) — and which failure in The Cold would tell us it wasn't learned?
    **A:** The certain lesson is **round-trip O2 math**; patch-before-pump and door discipline are proven by the existence of a camp. The tell: drowning deaths in The Cold (rather than shark deaths) mean it wasn't learned. Log death cause per band (an `m4_smoke`-adjacent counter / F3 line) so the feel check has data.

## New topics surfaced (review 2026-09-05)

- [ ] **S2-51.** Breach registry: should `World.breaches` (wear-pass cells) be saved and exposed so drift particles, the inrush notice and the pump's "open to the ocean" card all read one source of truth?
- [ ] **S2-52.** The dry-cap wood barrier is now the de-facto first patch lesson — should its breaking be telegraphed (bubbles, a visible water level behind it) so a player doesn't flood their own dry floors blind?
- [ ] **S2-53.** Floated clutter (S2-17) after a drain: do stranded ceiling objects stay pinned, drop as items, or become the room's decor — and is the drop a hazard?
- [ ] **S2-54.** Death-cause telemetry per band (S2-50): what minimal counter/F3 line ships in MVP so the GL-27 feel check has data?
- [ ] **S2-55.** Should the found `tank_scrap`/`fins` in Shallows tables (S2-04/16) be excluded from modifier rolls to protect the Cold's "first modded gear" moment, or is early modded dive gear the better hook?

# Stage Five — The Long Descent

> *Continuous self-improvement (gear, tools, skills, base upgrades) to push as far down as
> possible — ultimately reaching ground level and draining the city.* — GameOverview.md, Main Game Loop

The **mastery stage**: the hard suit is on, and the question changes from "can I survive this
depth?" to "how much of the city can I clear, and how well-kitted can I be doing it?" It ends at
the **city floor**.

**Scope note (2026-09-01):** the MVP / Steam demo ends when the player stands on the floor of The
Crush in a hard suit. **The Drain** — relay stations, band-by-band waterline drops, the central
station, credits + freeplay — stays canon as the story's end goal but ships as the late endgame
*after* the Steam release (`docs/MVP-checklist.md` "Post-release — The Drain").

| | |
|---|---|
| **Band** | The Crush — rows 440+ below the waterline to ground (`BAND_DARK_DEPTH` → city floor; every tower reaches the ground since districts — `GROUND` 720 ≈ 616 rows below `WATERLINE` 104, CT-01; 220+/300 before 2026-09-04) |
| **Target time** | ~15–25 h (GL-27) |
| **Entry state** | Hard suit (cold 2, crush 1), iron tank or rebreather, cutting torch, deep camp |
| **Exit (MVP)** | Standing on the **bare concrete roads** at ground level (CT-08), hard suit on, zero debug — the M6 gate |
| **Exit (post-release)** | Relay stations restored → waterline lowered band by band → central station → credits + freeplay (CC-26/27) |
| **Milestones** | M5 (rebreather, modifiers, abilities tier 3, depletion), M6 Release Readiness (full-run integrity pass); post-release Drain |

**Open questions** (`S5-NN`) close every section below: open-ended prompts meant to add variety and harden playability. Same workflow as `../OpenQuestions.md` — answer on an indented `**A:**` line, mark `[x]` answered or `[~]` deferred.

**Units note (2026-09-05 review):** speeds and radii quoted below in blocks/s or blocks predate the 8 px cell of 2026-09-04; in today's cells every such figure doubles (walk 10 / sprint 14 / swim 10 cells/s, jump 6; enemy speeds are already ×2 in `data/enemies.json`). Ratios are unchanged. Costs and row numbers have been corrected to current data where the review found them stale.

---

## Where it happens

- **The Crush**: `CRUSH_DPS` 25 HP/s without crush rating — the hard suit is the ticket, full
  stop. Cold still applies (rating 2 covers it). Deepest, darkest, densest with iron and
  schematics; the only place `rifle`s, `compass`, and `tool_belt` roll.
- **Ground level** is The Crush's floor: bare concrete roads, nothing below (CT-07/08), the
  **central pump station shell** and the **mega-pump relay station shells** as discoverable
  structures (CT-26; interiors are post-release content).
- **The ocean margins**: beyond the last tower on each side lies open water (`OCEAN_MARGIN`)
  holding the central/relay station shells and surface debris — shark and Drowned country (CT-09).
  The CC-28 bell-curve skyline and submerged edge buildings are gone (districts, 2026-09-04).

**Open questions**

- [x] **S5-01.** What makes ground level worth reaching *in the MVP* — the whole skyline seen from below, a pump-station shell with a readable purpose, a unique dry hall?
    **A:** The summit is a *place*, not content: standing on bare concrete (CT-08) under ~600 ft of tower with the whole skyline stacked overhead, the depth grade at its darkest, and the central pump-station shell visible as a landmark in the ocean margin. No unique dry hall in the MVP — an authored hall is Drain-era content (S5-24/38). The "worth" is the view plus the summit card and world flag (S5-28/44).
- [x] **S5-02.** Should edge buildings (entirely submerged, 5–10 floors) have their own character — leaning, collapsed, coral-grown?
    **A:** Moot since districts (CT-01, 2026-09-04): there are no submerged edge buildings — every tower reaches the ground and the city ends at open-water ocean margins holding the station shells and debris (CT-09). Edge character comes from those shells only; leaning/coral-grown ruins belong to the post-MVP open-water list (CT-09/10).
- [x] **S5-03.** What Crush-only spaces (parking structures, lobbies, sealed subway entrances for post-MVP) add variety to the deepest floors?
    **A:** Add a **ground-floor `lobby` template pool** — pure data (Room Editor, `rooms.json`, depth range pinned to the bottom floor, one pool per district zone: bank lobby, hospital ER, loading dock). Parking structures and subway mouths stay CT-07 post-MVP (nothing below street level). Variety at the floor comes from templates, not new generation code.

## What the player has coming in

Hard suit, torch, bolt cutters, iron tools, speargun, a found rifle or SMG, fins/glow band/dive
watch in 3–4 accessory slots, a Dark forward camp, learned modifiers, Scrapping 3.

**Open questions**

- [x] **S5-04.** Is the rebreather the last O2 step, or should endgame air become effectively unlimited (a compressor camp) so exploration replaces O2 management?
    **A:** The rebreather is the last O2 step (GL-10 canon: ~3 min). Air never becomes unlimited; exploration replaces O2 management through **camps** — tanks refill in any drained space (LT-17), so the camp chain *is* the compressor. A faster-refill compressor object stays on S4-15's post-MVP list.
- [x] **S5-05.** What does the complete kit look like and how does the player know they've reached it — a loadout summary, purple across the board?
    **A:** No dedicated loadout screen. The paper-doll plus rarity title colours (LT-08) are the readout, and "complete" is derived: every slot filled and purple across suit/head/accessories/weapon. The summit card (S5-27) prints a one-line kit summary so the state is named once.
- [~] **S5-06.** Should Stage Five gear carry visible flair (suit trims by rarity) since the paper-doll is the trophy case?
    **A:** Deferred to the art pass after M6. Suit tints already carry safety meaning (warm = safe, CC-22); rarity trims are sprite work with no MVP mechanic behind them. Unblocked when the paper-doll gets its post-Steam art budget.

## The loop at this stage

1. **Breathe longer** — `schematic_rebreather` (Crush, w2) → `rebreather` (3 steel + 3 plastic +
   cloth): +150 s → **3 minutes** of air (GL-10), with *of the Deep* and Free Diver on top. Dives
   stop being sprints.
2. **Clear the Crush** — 90-HP walkers in dry pockets, 110-HP Drowned in the water, 140-HP sharks
   outside. The rifle (18 dmg) rules drained rooms; the speargun (12) rules the water. Ammo crafts
   from scrap/iron at the Forge (LT-16).
3. **Perfect the kit** — every safe (torch/`vault_key`) is a modifier lottery; the Bench turns
   the haul into purple crafted gear: *Sharp Swift* weapons, a hard suit *of Warmth* / *of
   Currents*. Rarity colours (gray → green → blue → purple, LT-08) are the visible score.
4. **Chain camps to the floor** — pump-out rooms at rows 480, 540, 600 (8 px cells). Each is a refuel stop
   (tanks refill in air, LT-17), a bed (spawn), lights. The elevator shaft, drained end to end,
   is the highway home (CT-06).
5. **Touch the ground** — the concrete roads, the pump station shell. In the MVP that is the run's
   summit; save/load along the way is part of the gate (`save_smoke`).
6. **Freeplay / post-release** — build out, clear every tower, replay a new seed (GL-30: no NG+;
   replay = a new city). When the Drain ships: restore relays band by band and watch the
   waterline fall.

**Open questions**

- [x] **S5-07.** What replaces "more depth" as the goal once the floor is reached — tower clears, camp chains, safes opened per seed?
    **A:** Depth is replaced by **clearing**: towers cleared, the camp chain completed, the ability tree finished. This is honest freeplay (GL-30: no NG+, replay = new seed) — the game hands off to self-set goals, made legible by the completion tracking in S5-08.
- [x] **S5-08.** Should the game track and show completion (towers cleared, safes opened, rooms drained) to give freeplay direction?
    **A:** Yes, minimally and record-derived: a per-tower **cleared %** = containers opened + enemy records cleared (both already one-time and saved: LT-27, cleared-stays-cleared), shown as a badge on the M map's tower and "CLEARED" at 100 %. No new world state. Rooms drained are *not* tracked — water is live state, not a checklist.
- [x] **S5-09.** What optional mega-projects (draining an entire tower, a dry shaft from waterline to floor) can the sandbox support today?
    **A:** The **drained elevator shaft** waterline-to-floor is the advertised MVP mega-project: pumps reach 48 blocks, doors and placed blocks seal, the sim never pushes water uphill so a sealed column stays dry. A whole-tower drain is *not* advertised until S5-41 measures it — generated breaches (`CONSTRUCTION_BREACH` 0.95 in construction towers) make it a sealing marathon before it is a pumping one.

## Systems in play

- **Everything, at full strength.** Stage Five is the integration test of the loop —
  harvest (Scrapping 3, Master Scrapper), craft (all five stations), build (deep camps that
  survive red moons by being underwater).
- **Oxygen stack**: 30 lungs + 150 rebreather (+10 dive watch, +*of the Deep*, ×0.8 Free Diver) —
  three-to-four minutes; drowning (10 s) remains the same desperate dash.
- **Weight economy**: hard suit 8 + rifle 4 + torch 5 + cutters 4 + iron haul — the swim halves at
  60 weight (`WEIGHT_SWIM_REFERENCE`) and floors at ×0.3. `weight_belt` (+40 carry, found-only)
  and *of the Shore* are the counters; Stage Five is where the soft cap is felt every dive.
- **Depletion is complete**: all loot is one-time (LT-27); fish (`fish_meat`, heal 8) and red-moon
  straggler drops are the only renewables. A finished world is *finished* — by design.
- **Red moons late**: wave size 3 + 0.3 × day, stats +5 %/day. By day 40 a wave is 15 walkers at
  ×3 stats — but only against a base they can walk to. A submerged base never fights one.

**Open questions**

- [~] **S5-10.** Should late water engineering get new parts (pipes, valves, one-way doors, current generators) as the Stage Five toy box?
    **A:** Deferred post-Steam. The MVP toybox is pump + targeted outlet + seal blocks + doors-as-airlocks; pipes are noted in WaterPhysics as a drop-in replacement for outlet targeting and belong with the Drain's relay work. Unblocked by M6 perf/feel data on the existing parts.
- [x] **S5-11.** Are currents (WS-16) implemented enough for lifts and traps — what is the minimal current toolset for the demo?
    **A:** Currents exist: awake-cell flow pushes bodies at `CURRENT_PUSH` (14 px/s per unit), tuned escapable per WS-16. The minimal demo toolset is zero new parts — a pump outlet aimed up a sealed shaft is the lift. Trap-capable currents are out (escapable is canon).
- [~] **S5-12.** Should red moons evolve late (Drowned in waves, forward camps as targets) so the base game stays alive at 60 h?
    **A:** Deferred until the M4 balance pass and MP-06 wave budget land. Canon holds meanwhile: waves converge on players and damage placed blocks only (GL-15), walkers can't swim, so a submerged camp never fights one. Drowned in waves would need swimmer wave pathing — post-Steam.

## Crafting & recipes unlocked

| Station | Recipe | Cost | Notes |
|---|---|---|---|
| Dive Station | `rebreather` (schematic) | 3 steel + 3 plastic + 1 cloth | +150 s O2 |
| Forge | `rifle_rounds` | 1 iron + 1 scrap | For found rifles |
| Mod Bench | apply prefix + suffix | learned modifiers | One apply per piece, then locked |
| (all) | nothing new is *required* | — | Stage Five upgrades are modifiers, abilities, and logistics, not tiers |

**Open questions**

- [x] **S5-13.** What endgame recipes justify the Forge and Bench at Stage Five — mod-slot expanders, a portable pump, tier-4 ammo?
    **A:** No new required Stage Five recipes. Mod-slot expanders violate the LT-09 lock, a portable pump is already the pump (48-block outlet), and there is no tier above steel. The Forge/Bench earn their place through ammo and the modifier economy; the one real gap is steel melee, owned by S4-13/LT-01.
- [x] **S5-14.** Should the Bench gain a way to learn modifiers never rolled (manuals, terminals) so a build isn't hostage to drops?
    **A:** No. Canon is explicit — no modifier schematics, no rerolling (Loot section, LT-09). Drop-hostage risk is mitigated by Crush safes concentrating modded gear (LT-14) and by Stage Five's length; a manual/terminal path is a post-Steam economy toggle at most.
- [~] **S5-15.** Is there a place for cosmetic crafting (tints, decals, trophies) as the freeplay sink?
    **A:** Deferred post-Steam. Cosmetics are limited to character creation (CC canon); a tint/trophy sink needs the art budget and a freeplay audience. Unblocked with S5-06.

## Loot & materials

| Source | Crush-band tables |
|---|---|
| Generic | iron 3–5 (w3), `schematic_rebreather` (w2), `schematic_hard_suit` (w2), `vault_key` (w2), `compass` (reveal +8 map radius), `tool_belt` (+25 % scrap speed), `smg`, `rifle`, rifle rounds 6–12 |
| Safes | best rolls; purple-tier found gear |
| Structure | metal (torch) → steel/scrap; the Crush is where structure demolition pays (tier 3) |
| Relay / central station shells | landmarks only in MVP (CT-20); loot-less until the Drain ships |

**Open questions**

- [x] **S5-16.** What should the last safes hold that the player can't already make — a per-world unique, a lore item, a world-toggle unlock?
    **A:** Exactly the things the player *can't* make: found-only firearms (`rifle`, `smg`) and the found-only accessories (`compass`, `tool_belt`, `weight_belt`, LT-18) at purple rolls. No per-world unique (LT-19: none in MVP; trophies arrive with relay guardians) and no lore item (CT-27 deferred). No world-toggle unlocks — nothing mechanical unlocks at the floor (S5-29).
- [x] **S5-17.** Should Crush containers be *denser* rather than richer so the floor feels like the city's basement?
    **A:** Denser, not richer. Quality stays the authored per-band table (LT-28); density rises through **more container objects in Crush-depth templates** (data). This also makes the S5-08 clear % feel earned at the bottom.
- [x] **S5-18.** How do we show depletion positively — a "cleared" mark on rooms and towers — rather than as emptiness?
    **A:** Opened containers already stay visibly open; add the S5-08 map badge and CLEARED label so an empty tower reads as *finished*, not looted. No per-room mark — towers are the unit the player thinks in.

## Dangers

| Threat | Crush stats | Notes |
|---|---|---|
| The Drowned | 110 HP, 24 dmg, **7.0 b/s** (14 cells/s) | Nearly twice a hard-suited swimmer's speed (7.5 cells/s) — fight at doors, drain their rooms |
| Shark | 140 HP, 28 dmg, 6.0 b/s, aggro 15 | Open-water crossings between edge towers |
| Walker / Crawler | 90 / 60 HP, 20 / 16 dmg | Dry pockets; three-hit fights with iron weapons, one-magazine with an SMG |
| Crush | 25 HP/s without crush 1 | Losing the hard suit is impossible (gear stays worn on death) — the wall is one-way once passed |
| Drowning | 10 s | 3 minutes of air makes complacency the killer |

**Open questions**

- [x] **S5-19.** What is the Crush's signature threat beyond bigger numbers — a Drowned pack, a shark that follows into lobbies, pressure events?
    **A:** No new type in the MVP roster (GD-16/23 canon). The Crush's signature is the **speed asymmetry** (Drowned vs a hard-suited swimmer) plus shared proximity aggro (`aggro.gd`) — a room's Drowned arrive together. No pressure events. The lairing ambusher is S5-35, post-Steam.
- [~] **S5-20.** Should ground level carry a unique ambient danger tied to the future relay (a live station hum, a guardian's shadow) as a teaser?
    **A:** Deferred with the Drain. A station hum or guardian shadow is an audio/art teaser for content that isn't there; the safe MVP hint is the dormant shell of S5-24.
- [x] **S5-21.** How lethal should a late red moon be at a *surface* base — is abandoning the surface the intended arc?
    **A:** Abandoning the surface as a *home* is the intended arc; keeping it as a **farm** is too. Waves damage placed blocks only (GL-15), so planters/trees/stations survive — the wood farm is never destroyed, only its walls. Recoverable per GL-29. (Verify placed objects are untouched — new topic S5-54.)

## Hazards, puzzles & water management

The Crush runs every hazard system at maximum and asks the player to answer with engineering.
Nothing new gates them; everything old compounds:

- **Monster texture**: Drowned at 7.0 b/s in the interiors, sharks at 6.0 outside, 90-HP
  walkers in the pockets — nearly double a hard-suited swimmer's speed. Every fight is won
  before contact: at a doorway, behind a drained threshold, or not at all.
- **Complacency is the killer**: three-plus minutes of air, gear that can't be lost, camps
  everywhere — the band's deaths come from treating the deepest city like the Shallows.
- **Puzzles become projects**: the drained shaft, the dry floor, the camp chain to the
  concrete. The band's "puzzles" are self-set engineering goals — the design question is
  whether the toolbox (pumps, currents, one-ways) is deep enough to make them interesting.
- **Water management is the endgame**: the pump networks a player builds here are the
  rehearsal for the Drain. The MVP's ceiling is how much *deliberate dryness* one player can
  carve out of the deepest band.

**Open questions**

- [~] **S5-35.** Should the Crush have one signature ambusher of its own — something that lairs in parking structures and lobbies, distinct in silhouette from the scaled rosters — so the deepest band has a face, not just bigger numbers?
    **A:** Deferred post-Steam (GD-14: variants later; GD-16 roster canon). Design note: it wants a *lairing* silhouette distinct from the scaled Drowned, tied to the lobby templates of S5-03.
- [~] **S5-36.** Do silt-outs belong here — a collapse or thrash that zeroes visibility in a room for a minute — as the Crush's recoverable panic-trap, and can fog + lighting sell the effect today?
    **A:** Deferred to post-M6 feel testing. The fog/light system can zero a room's visibility and GL-29 recoverability is satisfied, but the trigger (collapse? thrash?) and duration need play data before authoring.
- [x] **S5-37.** Should Drowned at this tier coordinate loosely (converging on pump noise, cutting off the lit route out) as a soft pack behaviour — or does the proximity-only aggro rule (GD-06) stay absolute to the floor?
    **A:** GD-06 stays absolute to the floor — no noise or pump-sensing model. Shared proximity aggro already produces loose convergence; that is the "pack".
- [~] **S5-38.** What authored puzzle should ground level hold in the MVP — a pump-station antechamber openable by restoring one local breaker, a flooded plaza with a single drainable vault — so touching bottom has one *solved* thing in it, not just a view?
    **A:** Deferred with the Drain: the MVP ground is bare roads (CT-08) and a breaker-opened antechamber is relay content. The one "solved thing" at the bottom in MVP is the lobby template pool (S5-03) and the flag/card.
- [~] **S5-39.** Are parking structures and lobbies (S5-03) the band's puzzle-boxes — car stacks as terrain, torch-cut shortcuts, one-way collapses — and how much of that can generation express with current pieces?
    **A:** Lobbies as templates: yes (S5-03). Car stacks, torch-cut shortcuts and one-way collapses need pieces generation doesn't have; deferred with S5-42.
- [x] **S5-40.** Does deep water need new rules to make Crush engineering distinct — pump rate falling with depth, outlets that must vent *upward*, pressure differences across doors — or is uniform water the right simplicity to ship?
    **A:** Ship uniform water. WaterPhysics canon: no upward pressure, flat pump rate; depth-varying rules would fork the sim for one band. Distinctness comes from scale (S5-09/41), not new rules.
- [~] **S5-41.** What are the sim's real limits on mega-drains (a full tower, a street's connected volume) — and should Stage Five's advertised projects bend to those limits, or drive the sim's next iteration?
    **A:** Measure in the M6 perf pass (`WATER_BUDGET_PER_TICK`, awake set on a full shaft/tower drain). Until then advertised projects bend to the limits — the shaft is promised, the tower is not.
- [~] **S5-42.** Should the player be able to build *deliberate* traps by now — one-way doors that let a Drowned in but not out, drop-flood chambers triggered from a breaker — as the sandbox's answer to the band's monsters?
    **A:** One-way doors and breaker-triggered floods are new parts (S5-10) — deferred. Today's honest trap is sim-native: open a sealed door behind a Drowned to flood or strand it, or drain its room (S4-22).

## Base & water

- **The deep base** at rows 440–600 (8 px cells): everything the surface base had, unreachable by walkers,
  lit by beacons, fed by a drained shaft. GL-14's emergent base at its fullest.
- **Water engineering as endgame play**: pump networks that keep a whole floor dry, displacement
  traps, currents (engineered flow pushes entities — WS-16) as lifts. This is the MVP's sandbox
  ceiling and the natural rehearsal for the Drain's relay repairs.
- **Post-release**: each restored relay (reach → repair with materials → power → activate, CC-26)
  permanently lowers the waterline a band; drained bands become dry city (CT-25); the world
  persists in freeplay after credits (CC-27). Guardians at relays (GD-15) and unique trophies
  (LT-19) arrive with it.

**Open questions**

- [x] **S5-22.** What does the final base want — a dry stack from waterline to floor, a hub with fast vertical routes, a trophy room?
    **A:** A **hub with fast vertical routes**: the drained shaft as highway (CT-06) with a camp per band feeding it. A trophy room rides with cosmetics (S5-15). Modifier aspect reserved for the user's modifier pass.
- [x] **S5-23.** Should players be able to *permanently* dry a tower's shaft or floor (a placed mega-pump) as the MVP's mini-Drain?
    **A:** No placed mega-pump. "Permanent" already exists: a sealed, pumped column stays dry (the sim never pushes water uphill); the mini-Drain *is* the drained shaft (S5-09). Waterline-changing pumps are the Drain's mechanism (CC-26) and ship with it.
- [x] **S5-24.** How should the pump-station shell hint at the post-release Drain (control room, dead panels) without promising unavailable content?
    **A:** The shell is exterior-only in the ocean margin: unbreakable metal/VOID walls, dead-panel decals on its face, and a hover card that reads "Central Pump Station — dormant". No door, no interior, no text that promises a future; the shape and name carry the hint.

## Skills & abilities

Tier 3 across a branch or two by now: Master Scrapper, Cold Blood, Demolitionist. Player level
= total skill levels ÷ 5, so a full tree (9 points = 45 skill levels) is a Stage Five project.
Skills have no cap in data; the tree is the finite goal.

**Open questions**

- [x] **S5-25.** Should skills keep paying beyond the 9-point tree (prestige, minor stat lines) or cap cleanly?
    **A:** Cap cleanly at the 9-point tree. Skills keep levelling (no data cap) and player level keeps counting, but no prestige or post-tree stat lines — the tree is the finite goal.
- [~] **S5-26.** Is a fourth branch (Engineering: pumps, power, currents) the right post-Steam addition for Stage Five?
    **A:** Deferred to the Drain: an Engineering branch (pumps/power/currents) only earns its slot when relay repair is playable. Unblocked by the Drain's design pass (S5-48).
- [x] **S5-27.** What end-of-run summary (time per band, deaths, bags lost, rooms drained) would make a run feel scored?
    **A:** A **summit card** on the first floor-touch: time played, deaths, backpacks lost, towers cleared %, kit line, seed. Needs two new character counters (playtime, deaths/bags); everything else is derived. "Rooms drained" excluded (untracked, S5-08).

## Exit gate

- **MVP**: the M6 gate — *one player, one seed, zero debug commands — roof drop-off to a hard
  suit on the floor of The Crush, saving/loading along the way.* Completion = feet on the ground
  row inside `city_bounds` with crush rating ≥ 1 (S5-43); it sets a world flag and shows the
  summit card (S5-27/28/44).
- **Post-release**: roof drop-off to drained-city credits (`docs/MVP-checklist.md`, Post-release
  section).

**Open questions**

- [x] **S5-28.** What is the MVP's credits moment without the Drain — a landmark reached, a world flag, a title card?
    **A:** A **title card + world flag**, no credits — credits belong to the Drain (CC-27). Text on the order of "You stand on the floor of the city. The pumps are silent." then the summit card; play continues.
- [x] **S5-29.** Should reaching the floor unlock any freeplay convenience, or nothing (GL-18 rules out teleports)?
    **A:** Nothing mechanical (GL-18, no teleports). The flag, badge and card are the whole reward.
- [x] **S5-30.** How do we make "start a new seed" attractive — seed-linked world quirks, a stats compare against the last run?
    **A:** MVP: the card shows the **seed** for sharing (CT-21) — that is the invitation. A run-to-run stats compare needs a meta-store outside world/character saves; post-Steam.

## Tuning knobs

`CRUSH_DPS` 25 · rebreather `oxygen` 150 · `WEIGHT_SWIM_MIN_FACTOR` 0.3 · Drowned/shark Crush
rows · `RED_MOON_WAVE_PER_DAY` 0.3 / `RED_MOON_STAT_PER_DAY` 0.05 · `MATERIAL_STACK` 999 /
`CHEST_SLOTS` 20 · schematic weights (rebreather crush w2). Proposed by the review:
`RED_MOON_WAVE_CAP` 15 / `RED_MOON_STAT_CAP` 3.0 (S5-32), `CRUSH_GRACE_ROWS` 6 (S4-48).

**Open questions**

- [x] **S5-31.** Is 25 HP/s the right hard wall, or should the Crush have a survivable fringe (rows 440–446 in 8 px cells) that shows the wall before it kills?
    **A:** The wall stays absolute — nothing but crush rating 1 stops it (GL-12) — but it is not a gotcha: Stage Four's S4-48 gives the first `CRUSH_GRACE_ROWS` (6, half a floor) below row 440 a damage ramp 5 → 25 HP/s with the hull-groan and gauge, so a dip is retreatable, and the warning channels (S4-28) start above the line. No survivable fringe beyond that half-floor. Row numbers in the question are pre-8 px; the Crush starts at 440.
- [x] **S5-32.** How far should late red-moon scaling go — is a cap needed for 100-hour worlds?
    **A:** Yes, cap. Add `RED_MOON_WAVE_CAP` / `RED_MOON_STAT_CAP` in `constants.gd`, set to the day-40 values (wave 15 per player, stats ×3) as the starting point; tune with MP-06.

## Design references

GL-10/11/12/14/17/18/19/26/27/29/30 · CC-19/26/27/28 · WS-14/16 · GD-13/14/15/23 ·
LT-08/09/14/16/17/18/19/27 · CT-01/06/07/08/20/25/26.

## Open / feel-check notes

- **60–100 h total** (CC-19) is the sum of GL-27's stage targets — none measured yet. The full-run
  integrity pass (M6) is the first real data point.
- **Boats / submersible** (GL-19): the late steel-tier sub is exterior-only and sits at the MVP
  boundary; Stage Five open-water crossings at the city's edges are where it would matter.
- **Endgame emptiness**: with everything one-time and no NG+, freeplay after the floor is
  building and clearing only. Fine for the demo; the Drain (and post-MVP districts, wrecks,
  subways — CT-07/09/10/30) is what fills it.

**Open questions**

- [x] **S5-33.** What is the minimum endgame content for the demo to feel finished — is a landmark plus a run summary enough?
    **A:** Landmark (floor + station shell) + summit card + world flag + tower clear badges. That is the demo's finish; nothing else is needed before the Drain.
- [x] **S5-34.** Which post-release Drain pieces (relay shells, waterline tint bands) can be placed but inert in the MVP to prepare the world?
    **A:** Already placed: the mega-pump/relay shells sit in the ocean margins, and the per-band colour grade marks the future drain bands. Nothing more is placed inert — relay interiors and guardians arrive with the Drain.

## Transition — Stage Five → endgame & The Drain

Stage Five doesn't hand off to a Stage Six — it hands off to **the player's own goals** (MVP
freeplay) and, post-release, to the Drain. The transition design problem is unique: the
summit must feel like an ending *now* and like a beginning *later*, when relays go live in a
world the player already finished.

Expected state at the summit: hard suit + rebreather; a purple-modded core kit; a camp chain
from waterline to floor; every band's locks answerable; the pump-station shell found and
walked.

**Open questions**

- [x] **S5-43.** What defines "run complete" beyond boots on concrete — is touching the floor the flag, or a kit state (rebreather worn), or a place (inside the pump-station shell) — and which one does the M6 gate formally test?
    **A:** **Place + kit**: the player's feet on the ground row inside `city_bounds` while wearing crush rating ≥1. The wall guarantees the suit, so the test is effectively "standing on concrete alive". The M6 gate tests that condition from a fresh roof drop-off; entering the station shell is not required.
- [x] **S5-44.** Should the summit set a world flag with visible effects (a marker on the map, a badge on that save in the world picker) so completion persists somewhere other than memory?
    **A:** Yes: a saved world flag (`summit_reached`, world save extras — no version bump needed if stored sparse), a map marker at the touch cell, and a "floor reached" badge on that world in the picker. LAN: the flag is world-level and fires for the first player to touch (new topic S5-51).
- [~] **S5-45.** What should a completed run leave the player *holding* for the future Drain patch — banked repair materials, mapped relay shells, a camp near each — and should the MVP quietly hint at that shopping list without promising the content?
    **A:** Deferred — depends on the Drain's repair economy. The MVP hints at nothing (no shopping list; S5-24). See S5-47 for the constraint that pass must honour.
- [x] **S5-46.** Which capabilities keep paying in freeplay — is there any post-summit progression (tree completion, collection, mega-projects) or does the game honestly say "you've won, build for joy"?
    **A:** Honest freeplay: "you've won, build for joy" — plus the finite tree, the S5-08 clear badges, and self-set mega-projects. No new post-summit progression.
- [~] **S5-47.** When the Drain ships, what does *re-entry* look like for a summited world — do relays demand resources the old world still contains, and does a depleted (LT-27) world hold enough to finish the Drain it was saving for?
    **A:** Deferred to the Drain design, with a recorded constraint: because worlds deplete (LT-27), relay repair costs must be payable from what a finished world still holds — steel/iron banked in camps, or materials the Drain itself introduces — so a summited save is never a dead end (GL-29).
- [~] **S5-48.** Should these stage docs eventually gain a Stage Six (the Drain as a playable stage with its own bands-in-reverse structure), and which Stage Five systems (camps, pump networks, red moons over drained streets) carry into it unchanged?
    **A:** Yes, a Stage Six doc when the Drain is designed. Camps, pump networks and red moons carry unchanged; what's new is the waterline as a world property (WaterPhysics "City Drain") and guardians (GD-15). Deferred until then.
- [x] **S5-49.** What is the *last new thing* a player should learn in Stage Five — ideally within sight of the floor — so the game is still teaching at hour 60, not coasting?
    **A:** **Water as traversal** — the pump-outlet current used as a lift up the drained shaft home (S5-11). It's the pillar's last lesson (SunkenCity's "dig" is moving water) and it is learned exactly where the floor makes the climb longest.
- [x] **S5-50.** How does the game invite the next seed at the summit — a run summary contrasted with world quirks the player never saw, a seed to share — without cheapening the world they just finished?
    **A:** The summit card carries the seed and the run's numbers; no "quirks you never saw" (seed quirks don't exist yet). The invitation is the seed line and the badge left on the finished world.

## New topics surfaced (review 2026-09-05)

- [ ] **S5-51.** In LAN, does the summit flag fire once per world (first toucher) with a card for everyone, or per character on their own first touch?
- [ ] **S5-52.** Which records define a tower's "cleared %" (containers, enemies, safes — weighted?) and does construction's breach-riddled shell count the same?
- [ ] **S5-53.** Should the ground-floor lobby pool get a distinct pitch (taller atrium) per district, and does the bottom floor need its own `DISTRICT_FLOOR_H` entry?
- [ ] **S5-54.** Do red-moon waves damage placed *objects* (planters, stations, chests) or strictly placed blocks — decides whether the roof farm is wave-proof (S5-21).
- [ ] **S5-55.** Are the ocean-margin station shells reachable on foot along the floor, or swim-only across shark water — and does the summit card mention them?

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
| **Band** | The Crush — rows 220+ below the waterline to ground (`BAND_DARK_DEPTH` → city floor; centre towers reach ≈ 300 rows, CT-01) |
| **Target time** | ~15–25 h (GL-27) |
| **Entry state** | Hard suit (cold 2, crush 1), iron tank or rebreather, cutting torch, deep camp |
| **Exit (MVP)** | Standing on the **bare concrete roads** at ground level (CT-08), hard suit on, zero debug — the M6 gate |
| **Exit (post-release)** | Relay stations restored → waterline lowered band by band → central station → credits + freeplay (CC-26/27) |
| **Milestones** | M5 (rebreather, modifiers, abilities tier 3, depletion), M6 Release Readiness (full-run integrity pass); post-release Drain |

**Open questions** (`S5-NN`) close every section below: open-ended prompts meant to add variety and harden playability. Same workflow as `../OpenQuestions.md` — answer on an indented `**A:**` line, mark `[x]` answered or `[~]` deferred.

---

## Where it happens

- **The Crush**: `CRUSH_DPS` 25 HP/s without crush rating — the hard suit is the ticket, full
  stop. Cold still applies (rating 2 covers it). Deepest, darkest, densest with iron and
  schematics; the only place `rifle`s, `compass`, and `tool_belt` roll.
- **Ground level** is The Crush's floor: bare concrete roads, nothing below (CT-07/08), the
  **central pump station shell** and the **mega-pump relay station shells** as discoverable
  structures (CT-26; interiors are post-release content).
- **The edges of the city**: 5–10-floor buildings entirely submerged, wide open water — shark and
  Drowned country with nothing between towers (CC-28).

**Open questions**

- [ ] **S5-01.** What makes ground level worth reaching *in the MVP* — the whole skyline seen from below, a pump-station shell with a readable purpose, a unique dry hall?
- [ ] **S5-02.** Should edge buildings (entirely submerged, 5–10 floors) have their own character — leaning, collapsed, coral-grown?
- [ ] **S5-03.** What Crush-only spaces (parking structures, lobbies, sealed subway entrances for post-MVP) add variety to the deepest floors?

## What the player has coming in

Hard suit, torch, bolt cutters, iron tools, speargun, a found rifle or SMG, fins/glow band/dive
watch in 3–4 accessory slots, a Dark forward camp, learned modifiers, Scrapping 3.

**Open questions**

- [ ] **S5-04.** Is the rebreather the last O2 step, or should endgame air become effectively unlimited (a compressor camp) so exploration replaces O2 management?
- [ ] **S5-05.** What does the complete kit look like and how does the player know they've reached it — a loadout summary, purple across the board?
- [ ] **S5-06.** Should Stage Five gear carry visible flair (suit trims by rarity) since the paper-doll is the trophy case?

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
4. **Chain camps to the floor** — pump-out rooms at rows 240, 270, 300. Each is a refuel stop
   (tanks refill in air, LT-17), a bed (spawn), lights. The elevator shaft, drained end to end,
   is the highway home (CT-06).
5. **Touch the ground** — the concrete roads, the pump station shell. In the MVP that is the run's
   summit; save/load along the way is part of the gate (`save_smoke`).
6. **Freeplay / post-release** — build out, clear every tower, replay a new seed (GL-30: no NG+;
   replay = a new city). When the Drain ships: restore relays band by band and watch the
   waterline fall.

**Open questions**

- [ ] **S5-07.** What replaces "more depth" as the goal once the floor is reached — tower clears, camp chains, safes opened per seed?
- [ ] **S5-08.** Should the game track and show completion (towers cleared, safes opened, rooms drained) to give freeplay direction?
- [ ] **S5-09.** What optional mega-projects (draining an entire tower, a dry shaft from waterline to floor) can the sandbox support today?

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

- [ ] **S5-10.** Should late water engineering get new parts (pipes, valves, one-way doors, current generators) as the Stage Five toy box?
- [ ] **S5-11.** Are currents (WS-16) implemented enough for lifts and traps — what is the minimal current toolset for the demo?
- [ ] **S5-12.** Should red moons evolve late (Drowned in waves, forward camps as targets) so the base game stays alive at 60 h?

## Crafting & recipes unlocked

| Station | Recipe | Cost | Notes |
|---|---|---|---|
| Dive Station | `rebreather` (schematic) | 3 steel + 3 plastic + 1 cloth | +150 s O2 |
| Forge | `rifle_rounds` | 1 iron + 1 scrap | For found rifles |
| Mod Bench | apply prefix + suffix | learned modifiers | One apply per piece, then locked |
| (all) | nothing new is *required* | — | Stage Five upgrades are modifiers, abilities, and logistics, not tiers |

**Open questions**

- [ ] **S5-13.** What endgame recipes justify the Forge and Bench at Stage Five — mod-slot expanders, a portable pump, tier-4 ammo?
- [ ] **S5-14.** Should the Bench gain a way to learn modifiers never rolled (manuals, terminals) so a build isn't hostage to drops?
- [ ] **S5-15.** Is there a place for cosmetic crafting (tints, decals, trophies) as the freeplay sink?

## Loot & materials

| Source | Crush-band tables |
|---|---|
| Generic | iron 3–5 (w3), `schematic_rebreather` (w2), `schematic_hard_suit` (w2), `vault_key` (w2), `compass` (reveal +8 map radius), `tool_belt` (+25 % scrap speed), `smg`, `rifle`, rifle rounds 6–12 |
| Safes | best rolls; purple-tier found gear |
| Structure | metal (torch) → steel/scrap; the Crush is where structure demolition pays (tier 3) |
| Relay / central station shells | landmarks only in MVP (CT-20); loot-less until the Drain ships |

**Open questions**

- [ ] **S5-16.** What should the last safes hold that the player can't already make — a per-world unique, a lore item, a world-toggle unlock?
- [ ] **S5-17.** Should Crush containers be *denser* rather than richer so the floor feels like the city's basement?
- [ ] **S5-18.** How do we show depletion positively — a "cleared" mark on rooms and towers — rather than as emptiness?

## Dangers

| Threat | Crush stats | Notes |
|---|---|---|
| The Drowned | 110 HP, 24 dmg, **7.0 b/s**, aggro 13 | Nearly twice a hard-suited swimmer's speed (3.75 b/s) — fight at doors, drain their rooms |
| Shark | 140 HP, 28 dmg, 6.0 b/s, aggro 15 | Open-water crossings between edge towers |
| Walker / Crawler | 90 / 60 HP, 20 / 16 dmg | Dry pockets; three-hit fights with iron weapons, one-magazine with an SMG |
| Crush | 25 HP/s without crush 1 | Losing the hard suit is impossible (gear stays worn on death) — the wall is one-way once passed |
| Drowning | 10 s | 3 minutes of air makes complacency the killer |

**Open questions**

- [ ] **S5-19.** What is the Crush's signature threat beyond bigger numbers — a Drowned pack, a shark that follows into lobbies, pressure events?
- [ ] **S5-20.** Should ground level carry a unique ambient danger tied to the future relay (a live station hum, a guardian's shadow) as a teaser?
- [ ] **S5-21.** How lethal should a late red moon be at a *surface* base — is abandoning the surface the intended arc?

## Base & water

- **The deep base** at rows 220–300: everything the surface base had, unreachable by walkers,
  lit by beacons, fed by a drained shaft. GL-14's emergent base at its fullest.
- **Water engineering as endgame play**: pump networks that keep a whole floor dry, displacement
  traps, currents (engineered flow pushes entities — WS-16) as lifts. This is the MVP's sandbox
  ceiling and the natural rehearsal for the Drain's relay repairs.
- **Post-release**: each restored relay (reach → repair with materials → power → activate, CC-26)
  permanently lowers the waterline a band; drained bands become dry city (CT-25); the world
  persists in freeplay after credits (CC-27). Guardians at relays (GD-15) and unique trophies
  (LT-19) arrive with it.

**Open questions**

- [ ] **S5-22.** What does the final base want — a dry stack from waterline to floor, a hub with fast vertical routes, a trophy room?
- [ ] **S5-23.** Should players be able to *permanently* dry a tower's shaft or floor (a placed mega-pump) as the MVP's mini-Drain?
- [ ] **S5-24.** How should the pump-station shell hint at the post-release Drain (control room, dead panels) without promising unavailable content?

## Skills & abilities

Tier 3 across a branch or two by now: Master Scrapper, Cold Blood, Demolitionist. Player level
= total skill levels ÷ 5, so a full tree (9 points = 45 skill levels) is a Stage Five project.
Skills have no cap in data; the tree is the finite goal.

**Open questions**

- [ ] **S5-25.** Should skills keep paying beyond the 9-point tree (prestige, minor stat lines) or cap cleanly?
- [ ] **S5-26.** Is a fourth branch (Engineering: pumps, power, currents) the right post-Steam addition for Stage Five?
- [ ] **S5-27.** What end-of-run summary (time per band, deaths, bags lost, rooms drained) would make a run feel scored?

## Exit gate

- **MVP**: the M6 gate — *one player, one seed, zero debug commands — medical room to a hard
  suit on the floor of The Crush, saving/loading along the way.*
- **Post-release**: medical room to drained-city credits (`docs/MVP-checklist.md`, Post-release
  section).

**Open questions**

- [ ] **S5-28.** What is the MVP's credits moment without the Drain — a landmark reached, a world flag, a title card?
- [ ] **S5-29.** Should reaching the floor unlock any freeplay convenience, or nothing (GL-18 rules out teleports)?
- [ ] **S5-30.** How do we make "start a new seed" attractive — seed-linked world quirks, a stats compare against the last run?

## Tuning knobs

`CRUSH_DPS` 25 · rebreather `oxygen` 150 · `WEIGHT_SWIM_MIN_FACTOR` 0.3 · Drowned/shark Crush
rows · `RED_MOON_WAVE_PER_DAY` 0.3 / `RED_MOON_STAT_PER_DAY` 0.05 · `MATERIAL_STACK` 999 /
`CHEST_SLOTS` 20 · schematic weights (rebreather crush w2).

**Open questions**

- [ ] **S5-31.** Is 25 HP/s the right hard wall, or should the Crush have a survivable fringe (rows 220–230) that shows the wall before it kills?
- [ ] **S5-32.** How far should late red-moon scaling go — is a cap needed for 100-hour worlds?

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

- [ ] **S5-33.** What is the minimum endgame content for the demo to feel finished — is a landmark plus a run summary enough?
- [ ] **S5-34.** Which post-release Drain pieces (relay shells, waterline tint bands) can be placed but inert in the MVP to prepare the world?


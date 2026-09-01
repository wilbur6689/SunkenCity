# Stage Four — Deep Diving Gear

> *Craftable dive equipment lets the player descend even deeper and stay under longer.*
> — GameOverview.md, Main Game Loop

The **steel stage**. Two separate purchases (GL-11) define it: **time** (iron tank → rebreather)
and **depth** (wetsuit → hard suit). The Dark is where the water starts to hurt and where the
city's fastest swimmers live.

| | |
|---|---|
| **Band** | The Dark — rows 120–220 below the waterline (`BAND_COLD_DEPTH`…`BAND_DARK_DEPTH`), ≈ 16 floors |
| **Target time** | ~20–25 h (GL-27) |
| **Entry state** | Iron tank (90 s), wetsuit, bolt cutters, steel trickling from the Forge |
| **Exit capability** | **Hard suit** (cold 2, **crush 1**) — the only thing that survives The Crush |
| **Milestones** | M4 (the Drowned, speargun deep), M5 (steel chain, schematics, abilities tier 2–3, harvest gate steel → Scrapping 3) |

**Open questions** (`S4-NN`) close every section below: open-ended prompts meant to add variety and harden playability. Same workflow as `../OpenQuestions.md` — answer on an indented `**A:**` line, mark `[x]` answered or `[~]` deferred.

---

## Where it happens

- **The Dark** never sees the sun and, submerged, **chills and damages**: ×0.65 speed and
  `COLD_DPS` 2 HP/s without cold rating 2. Cold Blood (+1) on a wetsuit reaches rating 2 — the
  ability path; the hard suit is the gear path.
- **Light is the resource**: sight falloff inside buildings, no sun; the `helmet_lamp` (light 9),
  `glow_band` (light 6, Dark loot), glowsticks, and **placed lights** as fog beacons
  (`World.light_beacons`) turn a black floor into a mapped one (GL-13: disposable → personal →
  infrastructural).
- **The Drowned** are here (GD-13/14): swimmers at 6.5 b/s that move through flooded interiors —
  the first enemy that follows the player *into* the water.
- Vault doors and safes (lock 3) open to the **cutting torch**; metal structure (tier 3) cuts —
  the last walls fall.

**Open questions**

- [ ] **S4-01.** What are The Dark's landmarks — a still-lit relay shell, a flooded atrium with bioluminescence, a collapsed skybridge (post-MVP) — so the black has shape?
- [ ] **S4-02.** Should fog beacons be *findable* (still-working emergency lights) as well as placeable, giving the Dark pre-lit islands?
- [ ] **S4-03.** How much of the Dark should be dry pockets vs flooded — do gun-friendly rooms need guaranteeing per tower?

## What the player has coming in

`tank_iron`, wetsuit, `bolt_cutters`, iron sword/knife, speargun, a found pistol or SMG, a Cold
forward camp, and a Forge making `steel` at 2 iron + 1 stone.

**Open questions**

- [ ] **S4-04.** Is the hard suit's 25 % swim penalty legible — should the suit change swim animation, camera weight and sound?
- [ ] **S4-05.** What should a helmet lamp do beyond radius — a directional cone, colour temperature, a flicker when hit?
- [ ] **S4-06.** Should there be a light budget (lamp battery, glowstick decay), or is light permanently free once owned?

## The loop at this stage

1. **Torch first** — `cutting_torch` (2 steel + 3 scrap + 2 plastic): every safe in the Cold and
   Dark opens. Safes hold each band's best rolls (LT-14) — this is where modded gear, schematics
   and keys concentrate.
2. **Find the suit** — `schematic_hard_suit` rolls in Dark (w1) and Crush (w2) tables. Reading it
   teaches the recipe: **4 steel + 3 cloth + 2 plastic** at the Dive Station. Until then, the
   Dark is a 2 HP/s clock: dive from a drained camp, work fast, retreat to air.
3. **Build the camp deep** — pump out a Dark room (cold doesn't reach dry rooms), place lights
   (beacons), a Dive Station, a bed. The **iron tank refills** there; every Dark dive starts from
   90 s instead of a 5-floor swim.
4. **Hunt the Drowned with the speargun** — 12 dmg bolts, retrievable; the Drowned has 80 HP
   (7 bolts) and out-swims you, so fights happen at chokepoints and doorways, or are avoided.
5. **Feed the Bench** — Dark loot rolls fins (+20 % swim), glow bands, SMGs, iron tanks, and
   modded pieces. Sacrifice-to-learn *of the Deep* / *of Warmth* / *Swift*; apply to the crafted
   hard suit **before** its single apply locks it (LT-09).
6. **Steel for the rebreather** — `schematic_rebreather` is Crush loot (w2); the recipe (3 steel +
   3 plastic + cloth) is often learned only at the Stage Five boundary. Bank steel now.

**Open questions**

- [ ] **S4-07.** What is the Dark's signature moment — hunting a Drowned by its glow, draining a ward and stranding it, lighting a black floor room by room?
- [ ] **S4-08.** Should the Bench or Forge offer a last-resort hard-suit path (many steel, no schematic) to bound the RNG on the critical path?
- [ ] **S4-09.** How do deep camps change dive rhythm — is one camp per ~5 floors the intended cadence, and does gen provide sealable rooms at that spacing?

## Systems in play

- **Suits** (LT-21): defense / cold / crush / swim penalty.

  | Suit | Recipe | Def | Cold | Crush | Swim penalty | Weight |
  |---|---|---|---|---|---|---|
  | `clothes` | start | 0 | 0 | 0 | 0 | 1.0 |
  | `wetsuit` | 4 cloth + 3 plastic | 1 | 1 | 0 | 0 | 2.0 |
  | `hard_suit` | schematic; 4 steel + 3 cloth + 2 plastic | 3 | 2 | **1** | **0.25** | **8.0** |

  The hard suit costs a quarter of your swim speed and 8 weight — the Drowned get faster relative
  to you the moment you can survive their home. Fins and *of Currents* claw it back.
- **Paper-doll gear**: suit tints (wetsuit blue, hard suit orange — warm = safe, CC-22) and the
  held tool are visible (WS-26).
- **Harvest gate**: **steel → Scrapping 3**. Steel-bearing furniture and metal structure need the
  skill as well as the tool — a Stage Three scrapper is ready; a swimmer-first build catches up
  here.
- **Fog beacons**: player-placed lights and dropped glowsticks keep their surroundings revealed
  with no line of sight — the Dark is *mapped* by lighting it.
- **Firearms deep**: SMG (6 dmg × 5/s on pistol rounds) and rifle rounds appear; guns work in
  drained rooms and dry pockets only — the torch + pump make gun territory.

**Open questions**

- [ ] **S4-10.** Should the Drowned sense more than proximity — drawn to light, or to running pumps — for a stealth-lite layer without a noise system?
- [ ] **S4-11.** What new water behaviours belong here — visible thermoclines, pressure leaks from doors, sediment clouds when blocks break?
- [ ] **S4-12.** Should suits have a maintenance beat (hard-suit seals) or stay durability-free per LT-15?

## Crafting & recipes unlocked

| Station | Recipe | Cost | Unlocks |
|---|---|---|---|
| Forge | `cutting_torch` | 2 steel + 3 scrap + 2 plastic | Lock 3 (vault doors, safes); metal structure (tier 3) |
| Dive Station | `hard_suit` (schematic) | 4 steel + 3 cloth + 2 plastic | The Dark without damage; **The Crush at all** |
| Dive Station | `rebreather` (schematic, usually Crush) | 3 steel + 3 plastic + 1 cloth | +150 s → 3 min of air |
| Forge | `rifle_rounds` | 1 iron + 1 scrap | Found rifles (18 dmg) |
| Mod Bench | learn / apply | sacrifice modded gear | Blue/purple crafted suits and weapons |

Full steel budget for the Stage Four/Five kit: torch 2 + hard suit 4 + rebreather 3 = **9 steel =
18 iron + 9 stone**, on top of iron tools and tank — the depletion pressure that empties the Cold
and pulls the player into Dark and Crush iron (2–5 per container).

**Open questions**

- [ ] **S4-13.** What steel-tier melee (steel sword/axe, a diver's knife) and what does steel change besides damage — reach, water factor, knockback?
- [ ] **S4-14.** Should the torch have a light function (weld glow) or a combat use (burn Drowned) to justify its 5 weight?
- [ ] **S4-15.** Which deep base objects (heater, compressor that refills tanks faster, spotlights, sealed doors) make Dark camps feel engineered?

## Loot & materials

| Source | Dark-band tables |
|---|---|
| Generic | iron 2–4 (w4), `tank_iron` (w2), `vault_key`, `fins`, `glow_band`, `schematic_hard_suit`, `pistol`, `smg`, pistol rounds 8–16, rifle rounds 4–8 |
| Safes (torch/key) | the band's best rolls; modded gear concentrates here |
| Zone tables | residential/office/hospital flavour continues; hospital wards are the medkit supply for the 2 HP/s dives |
| Structure | metal (tier 3, torch) — steel/scrap; stone (tier 2) |

**Open questions**

- [ ] **S4-16.** What is the Dark's jackpot beyond firearms — a legendary-feel modded item, a map fragment revealing safes?
- [ ] **S4-17.** Should keys be tied to specific vaults (labelled key, marked door) so a key find becomes a quest without a quest system?
- [ ] **S4-18.** How do accessories stay interesting at 3–4 slots — situational swaps (glow band for the Dark, weight belt for hauls) vs always-on?

## Dangers

| Threat | Dark stats | Notes |
|---|---|---|
| **The Drowned** | 80 HP, 18 dmg, **6.5 b/s**, aggro 12 | Water-only; moves through flooded interiors; bleeds you |
| Shark | 110 HP, 22 dmg, 5.5 b/s, aggro 14 | Open water between towers |
| Walker / Crawler | 70 / 45 HP, 16 / 13 dmg | Dry pockets and drained rooms; hospital wards |
| Cold damage | 2 HP/s submerged without rating 2 | 50 s from full health to dead, before anything touches you |
| Darkness | visibility only (GD-18) | Lamps and beacons; no sanity or buffs |
| Red moons | day-scaled; waves now 6–9 walkers | Surface bases become a chore; deep bases are untouched (walkers don't swim) |

**Open questions**

- [ ] **S4-19.** Which Drowned variants (grabber, ceiling lurker, spitter across dry rooms — GD-14) fit the MVP budget and which should wait?
- [ ] **S4-20.** Should cold damage have a warning stage (shivering, screen frost) before HP loss so the 2 HP/s clock is readable?
- [ ] **S4-21.** How does darkness create tension without buffs — enemy eyeshine, sounds that carry, light that attracts?

## Base & water

- **The deep camp is the base**: Dive Station, Mod Bench, Forge (10 stone + 4 scrap — cheap by
  now), chests, bed, lights. The surface base becomes a lookout and red-moon-proof storage.
- **Water as a weapon**: flooding a Drowned's room does nothing; *draining* it strands them —
  the Drowned are `water_only`. Pump a ward dry and its swimmers are gone. Conversely, breaching
  a powered dry section floods it and trips its breaker (WS-17).
- Backpack recovery deep: a death in the Dark floats the bag to the nearest ceiling — usually the
  same room. Gear stays worn (the hard suit is never lost), so recovery is a dive, not a rebuild.

**Open questions**

- [ ] **S4-22.** Is "drain their room to strand the Drowned" too easy — should they flop toward water or die slowly on dry floor?
- [ ] **S4-23.** Should deep camps need sealing *quality* (wood seeps at depth) so metal blocks matter?
- [ ] **S4-24.** A drained camp during a red moon at depth sees nothing (walkers can't swim) — is that the intended safe haven, or should waves adapt?

## Skills & abilities

Player level 5–7 is typical: **Cold Blood** (+1 cold — a wetsuit survives the Dark; a hard suit
gains headroom), **Rigger's Kit** (4th accessory: tank + fins + watch + glow band),
**Master Scrapper** (25 % double yield — the steel budget shrinks), **Demolitionist** (+50 %
hammer damage for reworking camps). Scrapping 3 unlocks steel harvest.

**Open questions**

- [ ] **S4-25.** Should Cold Blood stay tier 3, or is a cheaper cold ability the right way to let wetsuit players taste the Dark?
- [ ] **S4-26.** Do we need a costly respec once players see tier-3 abilities they didn't path toward?
- [ ] **S4-27.** Which skill should gate steel harvest — Scrapping 3 as now, or Building for structure demolition?

## Exit gate — what pushes the player down

- **The Crush starts at row 220** and is the **hard wall** (GL-12): `CRUSH_DPS` 25 HP/s without
  crush rating 1 — four seconds. Only the hard suit has it. Nothing else in the game is binary
  like this; it is the one true gear gate.
- The rebreather schematic and the best safes are below; the Dark's iron depletes.

**Open questions**

- [ ] **S4-28.** How does the Crush announce its hard wall — a pressure gauge, a groaning-hull sound, a visible boundary in the water?
- [ ] **S4-29.** Should the rebreather schematic be reachable in the Dark so Stage Five starts with air solved?
- [ ] **S4-30.** What is the last thing worth doing in the Dark before descending — a full tower clear, a completed accessory set, a camp at the boundary?

## Tuning knobs

`BAND_DARK_DEPTH` 220 · `COLD_DPS` 2.0 · `CRUSH_DPS` 25.0 · hard suit `swim_penalty` 0.25 /
weight 8.0 · Drowned speed 6.5 · `BEACON_FULL_BLOCKS` 5 · `SIGHT_FULL_BLOCKS` 7 /
`SIGHT_FADE_PER_BLOCK` 1.5 · schematic weights in `data/loot.json` (hard suit: dark w1, crush w2).

**Open questions**

- [ ] **S4-31.** Should COLD_DPS scale with rows into the band rather than a flat 2/s?
- [ ] **S4-32.** Hard suit weight 8 + penalty 0.25 — should one of the two go so the suit feels heroic rather than sluggish?

## Design references

GL-06/09/10/11/12/13/17 · CC-16/18/22 · WS-17/20/26 · GD-08/13/14/18/23 ·
LT-03/05…LT-11/14/18/19/21/29 · CT-24 (band wear visuals post-MVP).

## Open / feel-check notes

- **Schematic dependency**: the hard suit is *required* for Stage Five but its schematic is
  chance loot (w1 in Dark). Confirm a full-run never dead-ends on RNG — either guarantee a
  schematic per world (authored safe) or raise the Dark weight. Same for the rebreather.
- **Hard suit vs Drowned**: 0.75 × 5 = 3.75 b/s swimmer against a 6.5 b/s hunter. Intended
  ("out-swim you", GD-14), but check the escape tools (doorways seal, fins, *of Currents*) feel
  sufficient in the M4 balance pass.
- LT-01 promises melee at all four tiers — no steel melee exists in `data/items.json` yet.

**Open questions**

- [ ] **S4-33.** What single guaranteed schematic placement per world (an authored safe) removes the dead-end risk at least design cost?
- [ ] **S4-34.** Is the Dark the right band for the first mini set-piece (a flooded surgery with a locked-in Drowned)?


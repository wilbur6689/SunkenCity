# Stage Four — Deep Diving Gear

> *Craftable dive equipment lets the player descend even deeper and stay under longer.*
> — GameOverview.md, Main Game Loop

The **steel stage**. Two separate purchases (GL-11) define it: **time** (iron tank → rebreather)
and **depth** (wetsuit → hard suit). The Dark is where the water starts to hurt and where the
city's fastest swimmers live.

| | |
|---|---|
| **Band** | The Dark — rows 240–440 below the waterline (`BAND_COLD_DEPTH`…`BAND_DARK_DEPTH`; 120–220 before the 8 px cell of 2026-09-04), ≈ 16 floors |
| **Target time** | ~20–25 h (GL-27) |
| **Entry state** | Iron tank (90 s), wetsuit, bolt cutters, steel trickling from the Forge |
| **Exit capability** | **Hard suit** (cold 2, **crush 1**) — the only thing that survives The Crush |
| **Milestones** | M4 (the Drowned, speargun deep), M5 (steel chain, schematics, abilities tier 2–3, harvest gate steel → Scrapping 3) |

**Open questions** (`S4-NN`) close every section below: open-ended prompts meant to add variety and harden playability. Same workflow as `../OpenQuestions.md` — answer on an indented `**A:**` line, mark `[x]` answered or `[~]` deferred.

**Units note (2026-09-05 review):** speeds and radii quoted below in blocks/s or blocks predate the 8 px cell of 2026-09-04; in today's cells every such figure doubles (walk 10 / sprint 14 / swim 10 cells/s, jump 6; enemy speeds are already ×2 in `data/enemies.json`). Ratios are unchanged. Costs and row numbers have been corrected to current data where the review found them stale.

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

- [x] **S4-01.** What are The Dark's landmarks — a still-lit relay shell, a flooded atrium with bioluminescence, a collapsed skybridge (post-MVP) — so the black has shape?
    **A:** No new authored landmarks in MVP. The Dark's shape comes from what generation already makes: the pump **relay shell** sitting in the ocean margin at Dark depth (CT-26, inert), **powered wired sections** as lit islands (WS-17, see S4-02), the elevator shaft as the vertical reference, and each district's own pitch/template pool (industrial 20-cell halls, civil wards). Bioluminescence is the CT-24 "pale growth" wear overlay (post-MVP); the collapsed skybridge is post-MVP. Per-district flavour beyond that is reserved for the user's modifier pass.
- [x] **S4-02.** Should fog beacons be *findable* (still-working emergency lights) as well as placeable, giving the Dark pre-lit islands?
    **A:** Yes. Powered wired lights already register as fog beacons while `powered_on` (`World.light_beacons`), so the only addition is generation: a fraction of Dark-band breakers (`DARK_BREAKER_ON_CHANCE`, ~25 %) spawn already ON, giving pre-lit islands that reveal their section on arrival — and trip (go black) if the player floods them (WS-17). Findable light is thus a *power* find, not a new object; it fuses power, water and fog with zero new systems.
- [x] **S4-03.** How much of the Dark should be dry pockets vs flooded — do gun-friendly rooms need guaranteeing per tower?
    **A:** Keep the emergent rule — connectivity flooding plus the 40 % dry roll on submerged pockets (`pockets[].flooded`), no per-tower guarantee of gun-friendly rooms. Guaranteeing dry rooms would undercut the Stage Two skill the band is built on: "the torch + pump make gun territory" is the intended answer, and firearms are the bonus arsenal (LT-11), not the Dark's baseline. District-driven dry/flooded ratios are reserved for the modifier pass.

## What the player has coming in

`tank_iron`, wetsuit, `bolt_cutters`, iron sword/knife, speargun, a found pistol or SMG, a Cold
forward camp, and a Forge making `steel` at 2 iron + 1 stone.

**Open questions**

- [x] **S4-04.** Is the hard suit's 25 % swim penalty legible — should the suit change swim animation, camera weight and sound?
    **A:** Yes, through cheap diegetic channels only: swim animation playback rate scales with the effective swim factor (so the hard suit visibly labours), a low regulator-breath SFX loop while the hard suit is worn submerged, and the existing orange paper-doll tint. No camera weight — WS-18 fixes zoom and forbids contextual camera changes.
- [x] **S4-05.** What should a helmet lamp do beyond radius — a directional cone, colour temperature, a flicker when hit?
    **A:** Directional, as GL-13 already says, implemented cheaply: the helmet lamp's `LightMap` point source is offset `LAMP_CONE_OFFSET` cells toward the facing direction with a small omni halo at the head — a BFS light reads as a cone without a real cone renderer. No flicker-on-hit and no colour temperature in MVP (a warm lamp tint is a CC-22-friendly post-MVP polish).
- [x] **S4-06.** Should there be a light budget (lamp battery, glowstick decay), or is light permanently free once owned?
    **A:** No light budget. A lamp battery is durability under another name (LT-15: none in MVP) and adds a meter the design avoids; glowsticks stay the only consumable light and are spent by *placement*, never by decay (dropped glowsticks are persistent beacons). The Dark's light budget is spatial — where you laid your trail — not temporal.

## The loop at this stage

1. **Torch first** — `cutting_torch` (10 steel + 15 scrap + 10 plastic; 5x tool costs): every safe
   in the Cold and Dark opens. Safes hold each band's best rolls (LT-14) — this is where modded gear, schematics
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

- [x] **S4-07.** What is the Dark's signature moment — hunting a Drowned by its glow, draining a ward and stranding it, lighting a black floor room by room?
    **A:** **Lighting the black floor room by room** — beacon mapping is the one system unique to this band and it is implemented today; the drained, lit, bedded Dark camp is the stage's signature achievement. Drain-to-strand (S4-36) is the tactical set piece *inside* that loop and the Drowned hunt is the punctuation, not the theme.
- [x] **S4-08.** Should the Bench or Forge offer a last-resort hard-suit path (many steel, no schematic) to bound the RNG on the critical path?
    **A:** No station fallback recipe — schematics stay meaningful (GL-06). The critical-path RNG is closed two other ways: the post-roll guarantee in S4-33 and a rare *found* hard suit in Dark safes (S4-16), which needs no recipe to wear. Dark safes already weight `schematic_hard_suit` w3.
- [x] **S4-09.** How do deep camps change dive rhythm — is one camp per ~5 floors the intended cadence, and does gen provide sealable rooms at that spacing?
    **A:** The cadence is set by the **cold clock, not air**: 90 s of iron tank at 10 cells/s covers the whole band, but 50 s to death at 2 HP/s caps a suitless sortie at roughly ±250 cells of a refill room. Intended cadence is two camps per band — an entry camp near row 240 and the boundary camp near 400–440 (S4-49) — with the drained shaft (CT-06) as the highway; pockets (50 % of floors, one doorway each) are the sealable rooms and need no extra spacing guarantee.

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

- [x] **S4-10.** Should the Drowned sense more than proximity — drawn to light, or to running pumps — for a stealth-lite layer without a noise system?
    **A:** Proximity stays the only sense (GD-06), but *light extends it*: a Drowned's aggro radius toward a player carrying an emitting light (helmet lamp, held glowstick) is multiplied by `DROWNED_LIGHT_AGGRO` (~1.5) — one data field on the Drowned only. That gives stealth-lite (kill the lamp to slip past) without a noise system. No pump sensing in MVP; pack/pump coordination is S5-37's question.
- [x] **S4-11.** What new water behaviours belong here — visible thermoclines, pressure leaks from doors, sediment clouds when blocks break?
    **A:** Nothing new mechanically — the sim never pushes water uphill (WaterPhysics) and WS-29 keeps water visuals to a grade. One VFX addition: `spawn_break_puff` underwater tints as a sediment cloud that drifts and fades, with no visibility effect (GD-18). Thermoclines are out (bands are per-row, GL-12); pressure leaks are settled in S4-39.
- [x] **S4-12.** Should suits have a maintenance beat (hard-suit seals) or stay durability-free per LT-15?
    **A:** Durability-free, per LT-15. Seal maintenance would be the one durability sink in the game and would land on the exact item that gates Stage Five; if the post-MVP economy needs a sink, LT-15's world-toggle is the place.

## Crafting & recipes unlocked

| Station | Recipe | Cost | Unlocks |
|---|---|---|---|
| Forge | `cutting_torch` | 10 steel + 15 scrap + 10 plastic | Lock 3 (vault doors, safes); metal structure (tier 3) |
| Dive Station | `hard_suit` (schematic) | 4 steel + 3 cloth + 2 plastic | The Dark without damage; **The Crush at all** |
| Dive Station | `rebreather` (schematic, usually Crush) | 3 steel + 3 plastic + 1 cloth | +150 s → 3 min of air |
| Forge | `rifle_rounds` | 1 iron + 1 scrap | Found rifles (18 dmg) |
| Mod Bench | learn / apply | sacrifice modded gear | Blue/purple crafted suits and weapons |
| Forge (proposed, S4-13) | `steel_sword` / `steel_knife` / `steel_axe` | steel + cloth/wood (price vs 5x tool rule) | LT-01 steel melee: tier-3 tools, best `water_factor` |
| Forge (proposed, S4-15) | craftable `metal_door` | 2 steel | Water-sealing airlock walkers can't break |
| Workbench (proposed, S4-15) | wired spotlight | scrap + plastic | Breaker-powered placed light above the standing lamp |

Full steel budget for the Stage Four/Five kit: torch 10 + hard suit 4 + rebreather 3 = **17 steel =
34 iron + 17 stone** (5x tool costs since 2026-09-01; was 9 steel), on top of iron tools and tank —
the depletion pressure that empties the Cold and pulls the player into Dark and Crush iron (2–5
per container). Retune in the balance pass (S3-56).

**Open questions**

- [x] **S4-13.** What steel-tier melee (steel sword/axe, a diver's knife) and what does steel change besides damage — reach, water factor, knockback?
    **A:** Data-only additions to `data/items.json` for LT-01: `steel_sword` (Forge, 2 steel + 1 cloth; ~13 dmg, knockback 16), `steel_knife` — the diver's knife (1 steel + 1 wood; tier-3 knife, speed 1.6), `steel_axe` (2 steel + 1 wood; tier-3 axe tool + weapon). What steel changes besides damage is **`water_factor`** (steel is the dive-melee tier — the knife nearly unslowed, the sword 0.6) and **tool tier 3**, so the knife/axe double as harvest tools. No reach stat (LT-20 lean sheet). Costs above are pre-multiplier sketches — tool recipes run 5x since 2026-09-01, so price them against `bolt_cutters` (15 iron) in the balance pass.
- [x] **S4-14.** Should the torch have a light function (weld glow) or a combat use (burn Drowned) to justify its 5 weight?
    **A:** The torch glows: while held it emits a small light (`HELD_TORCH_LIGHT`, ~4 of 30) so torch-work in the black is self-lit — justifying its 5 weight and reusing the player-glow source. No burn attack: it already swings as a `pry` tool (`tool.damage` 3) and combat stays with weapons.
- [x] **S4-15.** Which deep base objects (heater, compressor that refills tanks faster, spotlights, sealed doors) make Dark camps feel engineered?
    **A:** Two steel-tier placeables, both engineering not comfort: a craftable **`metal_door`** (Forge, 2 steel; seals water like room doors, lock tier 3 against nothing — its point is an airlock walkers can't break) and a **wired spotlight** (breaker-powered placed light, radius above the standing lamp) so camp power matters. Heater and compressor are rejected — dry rooms are already warm and tanks already refill in air (LT-17), so they would have no mechanic to serve.

## Loot & materials

| Source | Dark-band tables |
|---|---|
| Generic | iron 2–4 (w4), `tank_iron` (w2), `vault_key`, `fins`, `glow_band`, `schematic_hard_suit`, `pistol`, `smg`, pistol rounds 8–16, rifle rounds 4–8 |
| Safes (torch/key) | the band's best rolls; modded gear concentrates here |
| Zone tables | district zones (residential / business / commercial / industrial / civil / construction) continue; civil hospital wards are the medkit supply for the 2 HP/s dives |
| Structure | metal (tier 3, torch) — steel/scrap; stone (tier 2) |

**Open questions**

- [x] **S4-16.** What is the Dark's jackpot beyond firearms — a legendary-feel modded item, a map fragment revealing safes?
    **A:** A **found, modded hard suit** at low weight in Dark safes (w1) — a purple *Swift hard suit of Warmth* is the band's legendary-feel jackpot without breaking LT-19 (no uniques), and it is the LT-10 dilemma at full strength: wear it and skip the schematic, or sacrifice it to learn its mods for your crafted suit. Map fragments are post-MVP.
- [x] **S4-17.** Should keys be tied to specific vaults (labelled key, marked door) so a key find becomes a quest without a quest system?
    **A:** Generic keys in MVP (a `vault_key` opens any tier-3 lock, LT-14). Post-Steam, labelled keys reuse the `door_button` record-link pattern (record `door` = target cell) plus a map pin — a quest without a quest system, but variety work, not core loop.
- [x] **S4-18.** How do accessories stay interesting at 3–4 slots — situational swaps (glow band for the Dark, weight belt for hauls) vs always-on?
    **A:** Situational by pricing, always-on by mechanics: accessories are found-only and light (0.5–1 weight), each answers one band problem (glow band = light, fins = swim, weight belt = hauls, dive watch = air), and swapping is a free bag action — so the interesting choice is the *loadout*, not an active. No cooldown actives and no set effects (LT-22).

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

- [x] **S4-19.** Which Drowned variants (grabber, ceiling lurker, spitter across dry rooms — GD-14) fit the MVP budget and which should wait?
    **A:** MVP ships the base Drowned only (GD-14: variants later). Post-Steam order: **lurker** first (ceiling-clinging ambusher at lamp edge — reuses the floater's rest pose and aggro), then grabber; the spitter (ranged across dry rooms) breaks `water_only` and waits until the roster needs it.
- [x] **S4-20.** Should cold damage have a warning stage (shivering, screen frost) before HP loss so the 2 HP/s clock is readable?
    **A:** Yes, cheaply: a `COLD_GRACE_SECONDS` (3 s) before DPS starts when entering the band under-rated (GL-12 "can be pushed briefly"), a screen-edge frost vignette plus shiver SFX while cold damage runs, and a cold icon on the vitals (the same HUD cold indicator as S3-28). The Cold band's slow is already the first warning stage; this makes the second readable.
- [x] **S4-21.** How does darkness create tension without buffs — enemy eyeshine, sounds that carry, light that attracts?
    **A:** **Eyeshine** — a `glow` flag on the Drowned def renders its eyes as tiny self-lit pixels visible through fog regardless of light — plus a low-passed call when it aggros. Both are tells (S4-37); light attraction (S4-10) makes the lamp a trade. No buffs, per GD-18.

## Hazards, puzzles & water management

The Dark is the first band where the *water* hunts back (the Drowned) and the environment
itself damages (cold DPS). Its hazard design is about light, time, and drainage as tactics:

- **Monster texture**: the Drowned move through flooded interiors — a corridor is no longer
  safe just because it's inside; sharks still own the crossings; walkers hold the dry pockets
  where guns work. Three combat rulesets keyed to water state — the band teaches loadout
  thinking.
- **The clock is the trap**: 2 HP/s submerged (without rating 2) turns every route into
  arithmetic. Most Dark deaths should be *plans that ran long*, not ambushes.
- **Light is the puzzle medium**: fog beacons turn lighting a floor into mapping it; darkness
  hides both loot and Drowned. The glowstick trail out is as load-bearing as the tank.
- **Drainage is a weapon**: the Drowned are water-only — pumping a ward dry strands them
  (S4-22). Water management graduates from logistics to *combat engineering*.

**Open questions**

- [x] **S4-35.** Should some Dark floors be authored *light puzzles* — a breaker chain that lights the whole floor if two or three flooded junction rooms are drained in order — fusing the power, water, and fog systems into one setpiece?
    **A:** Not authored set pieces; a placement rule that produces them emergently: in Dark sections with a breaker, bias the breaker (`BREAKER_FLOODED_ROOM_BIAS`) toward a room generation breaches, so "drain the junction to light the floor" arises from power + water + fog as they already work. Authored breaker chains are post-Steam content.
- [x] **S4-36.** Can drain-to-strand be staged as a *puzzle* rather than a trick — a ward where the Drowned patrols between two pools and the order you cut the water decides whether it's stranded or cornered *with* you?
    **A:** Yes, and it needs no puzzle authoring once S4-22 lands: a stranded Drowned flops toward the *nearest* water, so the order you drain two connected pools decides whether it escapes to the other or dies on the floor between them. Generation already makes two-pool wards (partitions + doors); the puzzle is the behaviour.
- [x] **S4-37.** What are fair warnings at lamp radius — Drowned eyeshine at the light's edge, audio that carries through water, a wake ripple — so black-water ambushes read as "I missed the tell", never "unknowable"?
    **A:** Eyeshine at any light level plus the aggro call (S4-21) are the fair tells; a wake ripple is deferred to the visuals pass (WS-29). Rule: a Drowned may never begin an attack from outside eyeshine range without having called first.
- [x] **S4-38.** Should some vaults and safes sit *behind* water — torch-cutting a vault door releases the flooded room beyond (and anything living in it) into your drained staging area — as the band's telegraphed authored trap?
    **A:** Yes, emergently: vault rooms take their own breach roll at gen, `vault_door` counts as solid for sealing, and EnemyGen seeds Drowned in flooded interiors — so cutting a flooded vault releases its water and occupant. Add the one tell it lacks: a `wet_seam` wall-detail decal on any lock-3 door whose far side is flooded at gen. Recoverable per GL-29 — the staging area floods to a level and pumps again.
- [x] **S4-39.** Do pressure leaks (S4-11) belong at this depth — drained rooms weeping at the seams, needing an occasional patch patrol — or does that violate the "drained stays dry" promise (S2-09) that camps are built on?
    **A:** No pressure leaks. The sim never moves water uphill and "drained stays dry" (S2-09) is the promise every camp is built on; red-moon pounding of player blocks is the only maintenance the game asks for. Leaks are not a Crush idea either (S5-40 inherits this).
- [~] **S4-40.** Should a room's *mid-drain* state be a designed fight arena — the water level falling live, a Drowned's pool shrinking toward a corner — and does the sim's drain rate make that a usable window today?
    **A:** Deferred. At `PUMP_UNITS_PER_TICK` 8 (60 cells/s) a 40×10 room drains in ~7 s — no usable window exists today. It becomes decidable only if pump rates are ever tiered (S2-32 says not in MVP; a slow scrap pump would create the window); revisit after that call and a feel test.
- [x] **S4-41.** Is there room for water-reading depth here — colder layers near breaches, sediment clouds when blocks break acting as smoke — so experienced players read a flooded room like a tracker reads ground?
    **A:** Sediment as VFX only (S4-11); no cold layers (bands are per-row) and no smoke mechanic in MVP. Water-reading depth is a post-MVP layer alongside S5-36 silt-outs.
- [x] **S4-42.** What is the band's recoverable *environmental* trap (no monster involved) — a false ceiling that dumps silt and kills the lights, a floor that gives into a flooded shaft — and how does it telegraph in low light?
    **A:** None new in MVP (canon: no environmental hazards). The band's non-monster trap is the cold clock itself plus the released-vault flood (S4-38). Post-MVP candidate: a silt ceiling that buries placed lights (beacon loss), telegraphed by a sagging-ceiling decal.

## Base & water

- **The deep camp is the base**: Dive Station, Mod Bench, Forge (10 stone + 4 scrap — cheap by
  now), chests, bed, lights. The surface base becomes a lookout and red-moon-proof storage.
- **Water as a weapon**: flooding a Drowned's room does nothing; *draining* it strands them —
  the Drowned are `water_only`. A **stranded** Drowned (S4-22) crawls for the nearest water at
  crawler speed, still bites, and dies on dry floor in ~15 s (`STRAND_DPS`) — draining is a fight
  on your terms, not a kill button. Conversely, breaching a powered dry section floods it and
  trips its breaker (WS-17).
- Backpack recovery deep: a death in the Dark floats the bag to the nearest ceiling — usually the
  same room. Gear stays worn (the hard suit is never lost), so recovery is a dive, not a rebuild.

**Open questions**

- [x] **S4-22.** Is "drain their room to strand the Drowned" too easy — should they flop toward water or die slowly on dry floor?
    **A:** Neither free nor trivial: a Drowned on dry floor enters a `stranded` state — crawls toward the nearest water at crawler speed, still bites, and takes `STRAND_DPS` (dead in ~15 s); reaching water restores it. Draining its room is a fight on your terms, not a kill button, and it is what turns S4-36 into a puzzle.
- [x] **S4-23.** Should deep camps need sealing *quality* (wood seeps at depth) so metal blocks matter?
    **A:** No. Sealing is binary by canon (WS-20: purely solid blocks; WaterPhysics: solid stops flow). Metal blocks matter through HP against red moons and their tier-3 harvest cost, not seepage.
- [x] **S4-24.** A drained camp during a red moon at depth sees nothing (walkers can't swim) — is that the intended safe haven, or should waves adapt?
    **A:** Intended safe haven in MVP. The submerged camp being red-moon-proof is the *reward* for going deep and is what turns the surface base into storage and lookout; waves target player blocks only (canon) and walkers don't swim. Whether late red moons add Drowned against deep camps is S5-12's post-Steam question.

## Skills & abilities

Player level 5–7 is typical: **Cold Blood** (+1 cold — a wetsuit survives the Dark; a hard suit
gains headroom), **Rigger's Kit** (4th accessory: tank + fins + watch + glow band),
**Master Scrapper** (25 % double yield — the steel budget shrinks), **Demolitionist** (+50 %
hammer damage for reworking camps). Scrapping 3 unlocks steel harvest.

**Open questions**

- [x] **S4-25.** Should Cold Blood stay tier 3, or is a cheaper cold ability the right way to let wetsuit players taste the Dark?
    **A:** Cold Blood stays tier 3 (CC-18 tree is implemented). Wetsuit players taste the Dark through the pushable 2 HP/s clock plus S4-20's grace; a cheap cold ability would erase the hard suit's purpose and break the Stage-4-is-steel canon.
- [x] **S4-26.** Do we need a costly respec once players see tier-3 abilities they didn't path toward?
    **A:** No respec in MVP. Nine points, no tier 3 is *required* (the suit covers cold 2; Scrapping 3 is a skill, not an ability), so regret is a preference not a wall. Revisit post-Steam as a costly Bench recipe if playtests show it.
- [x] **S4-27.** Which skill should gate steel harvest — Scrapping 3 as now, or Building for structure demolition?
    **A:** Scrapping 3 gates steel-bearing **furniture**; **structure** demolition gates on tool tier only (torch, `STRUCTURE_TIER` metal 3) — GL-01 says the tool tiers *are* the demolition gate, and Building is the placing skill. Double-gating steel on Building would penalise the swimmer-first build twice.

## Exit gate — what pushes the player down

- **The Crush starts at row 440** (`BAND_DARK_DEPTH`; 220 before the 8 px cell) and is the
  **hard wall** (GL-12): `CRUSH_DPS` 25 HP/s without crush rating 1 — four seconds. Only the hard
  suit has it. Nothing else in the game is binary like this; it is the one true gear gate. The
  first `CRUSH_GRACE_ROWS` (6, half a floor) ramp 5 → 25 HP/s with the hull-groan and gauge so a
  dip is retreatable (S4-48).
- The rebreather schematic and the best safes are below; the Dark's iron depletes.

**Open questions**

- [x] **S4-28.** How does the Crush announce its hard wall — a pressure gauge, a groaning-hull sound, a visible boundary in the water?
    **A:** Three cheap channels: the HUD depth/band readout (S2-05 makes it always-on; whether to gate it behind the dive watch or hard suit is S4-54), a hard step in the depth colour grade at `BAND_DARK_DEPTH` (CT-24), and a low hull-groan audio layer in the last ~20 rows above it. Pairs with S4-48's fringe.
- [x] **S4-29.** Should the rebreather schematic be reachable in the Dark so Stage Five starts with air solved?
    **A:** Yes, narrowly: add `schematic_rebreather` to the Dark **safe** table at w1 (generic Dark tables stay without it). The torch — Stage Four's key — opening a Dark safe can pay out Stage Five's opener, so a thorough Stage Four *can* finish air, while the common line still descends on the iron tank (S4-45).
- [x] **S4-30.** What is the last thing worth doing in the Dark before descending — a full tower clear, a completed accessory set, a camp at the boundary?
    **A:** The **boundary camp** — bed, Dive Station, beacons near rows 400–440 — because Stage Five's camp chain (S5 step 4) starts from it and it makes the one-way Crush wall survivable (respawn at the boundary). Tower clears and full accessory rows are fine to leave.

## Tuning knobs

`BAND_DARK_DEPTH` 440 · `COLD_DPS` 2.0 · `CRUSH_DPS` 25.0 · hard suit `swim_penalty` 0.25 /
weight 8.0 · Drowned speed 13 cells/s · `BEACON_FULL_BLOCKS` 10 · `SIGHT_FULL_BLOCKS` 14 /
`SIGHT_FADE_PER_BLOCK` 1.5 · schematic weights in `data/loot.json` (hard suit: dark w1, crush w2).
Proposed by the review: `COLD_GRACE_SECONDS` 3 (S4-20), `CRUSH_GRACE_ROWS` 6 (S4-48),
`DROWNED_LIGHT_AGGRO` 1.5 (S4-10), `STRAND_DPS` (S4-22), `HELD_TORCH_LIGHT` (S4-14),
`LAMP_CONE_OFFSET` (S4-05), `DARK_BREAKER_ON_CHANCE` 0.25 (S4-02).

**Open questions**

- [x] **S4-31.** Should COLD_DPS scale with rows into the band rather than a flat 2/s?
    **A:** Flat 2/s stays. "50 seconds" is arithmetic a player can hold, and a gradient blurs the boundary the grade and HUD announce; the "push briefly" feel comes from S4-20's grace instead.
- [x] **S4-32.** Hard suit weight 8 + penalty 0.25 — should one of the two go so the suit feels heroic rather than sluggish?
    **A:** The 25 % penalty is the design statement (GD-14: the Drowned out-swim you) and never moves; **weight is the tuning knob**. Keep 8.0 now; the M4 balance pass drops it toward 5.0 if the reference boundary kit (S4-46) pushes the combined swim factor under ~0.5.

## Design references

GL-06/09/10/11/12/13/17 · CC-16/18/22 · WS-17/20/26 · GD-08/13/14/18/23 ·
LT-03/05…LT-11/14/18/19/21/29 · CT-24 (band wear visuals post-MVP).

## Open / feel-check notes

- **Schematic dependency**: the hard suit is *required* for Stage Five but its schematic is
  chance loot (w1 in Dark). Confirm a full-run never dead-ends on RNG — either guarantee a
  schematic per world (authored safe) or raise the Dark weight. Same for the rebreather.
- **Hard suit vs Drowned**: 0.75 × 10 = 7.5 cells/s swimmer against a 13 cells/s hunter. Intended
  ("out-swim you", GD-14), but check the escape tools (doorways seal, fins, *of Currents*) feel
  sufficient in the M4 balance pass.
- LT-01 promises melee at all four tiers — settled in S4-13 (data-only `steel_sword` /
  `steel_knife` / `steel_axe`), still to be entered in `data/items.json`.

**Open questions**

- [x] **S4-33.** What single guaranteed schematic placement per world (an authored safe) removes the dead-end risk at least design cost?
    **A:** A post-roll **guarantee pass in `LootGen`**: after containers are seeded, if no `schematic_hard_suit` landed in any Dark/Crush container, force one into the Dark-band safe nearest `gen.spawn_tower`; same for `schematic_rebreather` in Crush. No authored room, no new template — a gate check (`m5_smoke` or `district_smoke`) asserts both exist per seed.
- [x] **S4-34.** Is the Dark the right band for the first mini set-piece (a flooded surgery with a locked-in Drowned)?
    **A:** Yes, the Dark is the right band, built as a **room template with a seed flag**, not an authored room: civil-district `civ_ward_locked` — a flooded ward behind a lock-3 door, `enemy_seed: drowned` read by EnemyGen, medkit-heavy table. Design settled now; ships post-Steam as content.

## Transition — Stage Four → Stage Five

The Crush wall is the game's only binary gate: crush rating 1 or 25 HP/s. The transition is
therefore the cleanest of the five — **the hard suit is the ticket** — and the design work is
everything *around* that fact: making the suit hunt fair, the boundary legible, and the
player's kit genuinely ready for the band where every system runs at full strength.

Expected state at the boundary: hard suit crafted (schematic found, 4 steel paid), ideally
modded *before* its single apply locks it; torch and cutters carried; a camp near rows
400–440; steel banked toward the rebreather; a working answer to the Drowned (speargun
discipline or avoidance); Scrapping 3; most of an accessory row filled.

**Open questions**

- [x] **S4-43.** Beyond the schematic RNG (S4-33) — what should the *moment* of first wearing the hard suit feel like (the tint change, the swim weight, the sound), given it is the run's single biggest promotion?
    **A:** Diegetic only, no fanfare (GL-01 emergent stages, S1-47's concern): the paper doll turns orange (warm = safe, CC-22), the regulator breath and heavier swim begin (S4-04), and the frost vignette dies the moment the suit is on in the Dark. The promotion is felt as the band stopping hurting.
- [x] **S4-44.** Should the player be nudged to mod the suit before its one apply is spent — a Bench warning, a "still modifiable" glint — or is a locked plain suit the fair price of impatience?
    **A:** One readable rule, no glint or dialog: unmodified gear carries a `desc` line "Unmodified — takes one apply, then locks" shown on hover and in the Bench, with the grey rarity title already meaning the same thing. A locked plain suit is the fair price once the rule has been read.
- [x] **S4-45.** Is descending on the iron tank (90 s) a supported line, with the rebreather found *in* the Crush — or should the air budget make waiting for the rebreather schematic the real boundary, and if so does Stage Five open too slowly?
    **A:** The **iron tank is the supported line**. 90 s + dive watch 10 + Free Diver ×0.8 ≈ 125 s effective; the Crush's first floors are seconds below the boundary camp, and Stage Five's camp chain is the air answer with the rebreather as comfort. Stage Five must open on the hard suit alone — otherwise the boundary sits behind two RNG schematics.
- [x] **S4-46.** What consumable loadout should the first Crush dive assume (medkits against 24-dmg hits, bolts, glowsticks, seal blocks, a spare pump) — and does the weight economy let it all through a 0.75× swim penalty?
    **A:** Reference first-Crush kit: 2 medkits + 3 bandages, 6 bolts, 6 glowsticks, 8 seal blocks, 1 pump, plus hard suit 8 / torch 5 / cutters 4 / speargun 2.5 / steel knife ~1.5 / tank ≈ 25–30 weight before haul. At `WEIGHT_SWIM_REFERENCE` 60 that is ×~0.75, stacked with the suit's ×0.75 → ~0.56 (≈ 5.6 cells/s vs a 13-cell/s Drowned) — consistent with Stage Five's "nearly twice your speed". It goes through; the balance pass verifies the combined factor stays ≥ 0.5.
- [x] **S4-47.** What should a player have *finished* in the Dark before leaving — every tier-3 lock they've mapped, a boundary camp bed, the SMG ammo chain — and what is deliberately fine to leave undone?
    **A:** Finish: the boundary camp with bed (S4-30), Scrapping 3 (Crush structure pays in steel), ~6 steel banked (rebreather 3 + a steel weapon). Fine to leave: full tower clears, mapped tier-3 locks (the torch travels — Crush safes are better), the SMG ammo chain (guns are situational at depth).
- [x] **S4-48.** How does a player safely *test* the wall — a pressure gauge at the boundary rows, a damage tick that visibly starts shallow enough to retreat from — so the one binary gate never reads as a gotcha kill?
    **A:** A **crush fringe**: the first `CRUSH_GRACE_ROWS` (6, half a floor) below `BAND_DARK_DEPTH` ramp crush damage 5 → 25 HP/s with the groan and gauge (S4-28); below it the full 25/s. A diver who dips sees damage start at a rate they can retreat from, so the one binary gate never reads as a gotcha. This settles S5-31: the wall stays absolute (nothing but crush rating stops it), only its first half-floor is retreatable.
- [x] **S4-49.** Should the boundary-camp pattern be guaranteed by generation (a sealable room near row 220 in every district), since Stage Five's camp-chain loop depends on it existing?
    **A:** Yes, softly, with existing pieces: pockets are sealable single-doorway rooms by construction, so bias the pocket roll (`POCKET_CHANCE`) to 100 % on the floor whose ceiling row lies in 400–440 (`floor_band_at`) for at least one tower per district cluster, and assert it in `district_smoke`. No new room type; per-district variation is reserved for the modifier pass.
- [x] **S4-50.** What skill/ability state does Crush balance assume (Cold Blood or hard suit only? Master Scrapper for the steel debt?) — and is a respec (S4-26) needed *because* of this boundary specifically?
    **A:** Crush balance assumes the **hard suit only** (cold 2, crush 1) and Scrapping 3; Cold Blood is headroom, Master Scrapper is economy, no tier-3 ability is required — which is why no respec is needed at this boundary (S4-26).

## New topics surfaced (review 2026-09-05)

- [ ] **S4-51.** Should the `stranded` Drowned (S4-22) drop anything extra or count differently for depletion, since draining now makes kills deliberate?
- [ ] **S4-52.** With light extending Drowned aggro (S4-10), does the helmet lamp need an on/off toggle key, and does a switched-off lamp still count as a fog beacon?
- [ ] **S4-53.** Should the crush fringe (S4-48) also apply to the backpack float path, so a bag lost just below the wall bobs up into reach rather than pinning in lethal rows?
- [ ] **S4-54.** The HUD depth/band readout (S2-05, S4-28): always on, or gated behind the dive watch / hard suit as a found-instrument reward?
- [ ] **S4-55.** Should the guaranteed-schematic pass (S4-33) log its placement to the character map on first Dark entry (a "diver's log" whisper, cf. S3-46), or stay silent?

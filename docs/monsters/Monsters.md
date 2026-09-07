# Monsters — district × stage chart

*2026-09-06. The monster counterpart to [../modifiers/Modifiers.md](../modifiers/Modifiers.md):
one grid of **6 districts × 6 stages (T0 Rooftops through T5 The Crush)**, a shared roster that fills every cell today, and an empty
**unique slot** in every cell to be named later. Numbers in §1–§2 are read from `data/enemies.json`
(`seeding` + per-band `stats`) and `scripts/world/enemy_gen.gd` as they stand; §3–§5 are design
proposals, nothing there is built.*

Stage ↔ band vocabulary (GameOverview "Main Game Loop"): **T0 Rooftops (open air above the crowns,
night-only spawns, 2026-09-06) · T1 The Dry · T2 The Shallows · T3 The Cold · T4 The Dark · T5 The Crush.** A floor's band is its CEILING row's band (`World.floor_band_at`).

## 1. Roster today (shared, district-blind)

Seeding is **district-blind**: `EnemyGen` reads a tower's floor pitch but never its district. Every
monster below can appear in any district that has the right kind of space.

| Monster | Move | Where it seeds | Stages | Drops |
|---|---|---|---|---|
| Walker | ground | dry wing-floors (sealed dry pockets too) | T1–T5 | cloth 0–2 (80 %), scrap metal 1 (35 %) |
| Crawler | ground | dry wing-floors, 30 % of each zombie roll | T1–T5 | cloth 1–2 (70 %) |
| Floater | surface | the open waterline between towers | T2 only | cloth 1–2 (80 %) |
| The Drowned | swim, water-only | flooded wing-floors of The Dark and The Crush | T4–T5 | cloth 1–2 (80 %), scrap metal 1–2 (50 %) |
| Shark | swim, open water only | open water from The Cold down | T3–T5 | fish meat 2–4 |
| Fish School | passive | open water below the surface | T2–T5 | — |
| Tropical Fish | swim, water-only | flooded Shallows/Cold wing-floors (50 % per floor, band-weighted 60/30/10 in the Shallows, 20/40/40 in the Cold) + open water of the Shallows | T2–T3 | fish meat 1 (60 %) |
| Catfish | swim, water-only | same flooded floors + open water of the Shallows and Cold | T2–T3 | fish meat 1–2 |
| Barracuda | swim, water-only, bites bleed | same flooded floors + open water of the Cold | T2–T3 | fish meat 2–3 |
| **T0 rooftop fauna** (24, user design 2026-09-06; `docs/monsters/t0_roof_fauna.json`) | ground or **fly**, all `pounds: false` | **T0 Rooftops, night only**, four per district — Industrial: rooftop rat, ironback roach, scrap mantis, cable leech · Construction: rebar spider, dust beetle, crane rat, brickback · Business: office crow, glasswing bat, window gecko, pigeon swarm · Residential: poison frog, chimney bat, gutter snake, roof cat · Commercial: grease rat, sign bat, dumpster raccoon, grease mantis · Civil: sewer rat, bell bat, statue pigeon, roof lizard. Spawn on roof tops 20–50 blocks from any player outdoors on a roof and not in a sealed room of their own, 4 per player from the tower's district, cleared at dawn | T0 | as designed (scrap, cloth, plastic, stone, wood, organic matter) |
| **T1 district fauna** (24, user design 2026-09-06; `docs/monsters/t1_dry_fauna.json`) | ground / fly, `pounds: false` | **dry floors**, four per district — Industrial: boiler hyena, boiler scorpion, furnace centipede, oil slug · Construction: hammerhead mole, rebar tick, scaffold goat, concrete tortoise · Business: window cicada, suit owl, glass squirrel, elevator wasp · Residential: attic weasel, mold rabbit, chimney possum, ceiling mouse · Commercial: butcher dog, freezer cricket, shopping crab, meat fly · Civil: police horse, archive silverfish, firehouse salamander, chapel snail. Each zombie roll on a dry floor becomes one of the tower district's four with `district_fauna_share.dry` (30 %) | T1 | as designed (cloth, scrap, plastic, stone, organic matter, paper) |
| **T2 district fauna** (24, user design 2026-09-06; `docs/monsters/t2_shallows_fauna.json`) | swim (water-only), some crawl the bottom, two **stationary shooters**, `pounds: false` | **flooded Shallows floors**, four per district — Industrial: rust-crested eel, sludge crab, boiler lamprey, grease viper · Construction: rebar snapping turtle, concrete ray, scaffolding barnacle, silt-dredger catfish · Business: silt stalker, document squid, LED anglerfish, vault moray · Residential: barnacle leech, submerged hound, gutter pike, aquarium betta · Commercial: neon jellyfish, display-case mantis shrimp, cart skeleton crabs, billboard stingray · Civil: drain pipe octopus, sewer gator, culvert hagfish, valve urchin. 30 % of each flooded-floor fish roll becomes one of the tower district's four | T2 | mapped onto scrap / plastic / stone / cloth / paper / organic matter |
| **T2 open-water hunters** (4) | swim | reef shark, depth barracuda, swarm anchovy, chasm lionfish (ranged) along the open water of the Shallows at `open_water_fauna_spacing` | T2 | as above |
| **T1 surface dwellers** (4) | drain eel + minnow school swim (water-only), water strider + mudskipper ride the surface | scattered along the open waterline between towers at `surface_fauna_spacing` | T1 (waterline) | organic matter, scrap |
| Prowler | ground, `pounds: false` | the T0 fallback roster when a roof has no district (none in the city today) | T0 | cloth 1–2 (70 %) |

Per-band stats scale with depth (walker hp 30 → 40 → 55 → 70 → 90 across T1–T5, damage 8 → 20);
a T5 walker is a different fight from a T1 walker but the same monster.

## 2. Likelihood of spawning today

**Interior wing-floors** (one roll per wing per floor, top → bottom, `seeding.wing_*`):

| Floor state | What rolls | Chance | Expected per wing-floor |
|---|---|---|---|
| Dry (any stage) | 0 / 1 / 2 / 3 zombies at weights 0.15 / 0.25 / 0.35 / 0.25 | ≥1 zombie **85 %** | 1.7 zombies: **1.19 walkers + 0.51 crawlers** |
| Flooded, T2–T3 | one predator fish (tropical / catfish / barracuda by band weights) | **50 %** | 0.5 fish (was nothing before 2026-09-06) |
| Flooded, T4–T5 | one Drowned | **80 %** | 0.8 Drowned |

Pity timer (`wing_pity_boost` 0.5, `wing_pity_floors` 2): a quiet floor raises the next floor's
"at least one" chance by +50 % of the gap per quiet floor (dry: 85 % → 92.5 %), and after two quiet
floors the third is guaranteed **when the floor can hold anything**. The drop-off tower's top floor
never seeds.

**Open water** (spacings walked along open-water columns only — gaps + ocean margins):

| Monster | Spacing (cells of open water) | Rough density | Depth |
|---|---|---|---|
| Floater | 50–120 | ~1 per 85 cells | the waterline (T2) |
| Fish School | 40–90 | ~1 per 65 cells | waterline+8 → floor (T2–T5) |
| Shark | 80–160 | ~1 per 120 cells | The Cold +8 → floor (T3–T5) |

## 3. The grid

Columns are the six districts (the modifier families) plus **Open water**, which is not a district
but is where the swimmers live. Each cell lists what seeds there **today** with its chance, then the
**unique slot** — one monster that seeds ONLY in that district at that stage. Every unique slot is
empty; fill the name in and add the entry in §4.

Legend: **W** walker · **C** crawler · **D** the Drowned · **F** floater · **S** shark · **Fi** fish
school · **Tr / Cat / Bar** tropical fish / catfish / barracuda (2026-09-06) · ☐ = unique slot, unnamed.

| Stage | Industrial | Construction | Business | Residential | Commercial | Civil | Open water |
|---|---|---|---|---|---|---|---|
| **T0 Rooftops** (night only) | rooftop rat · ironback roach · scrap mantis · cable leech | rebar spider · dust beetle · crane rat · brickback | office crow · glasswing bat · window gecko · pigeon swarm | poison frog · chimney bat · gutter snake · roof cat | grease rat · sign bat · dumpster raccoon · grease mantis | sewer rat · bell bat · statue pigeon · roof lizard | — · ☐ ______ |
| **T1 Dry** | W/C 70 % · **30 %** boiler hyena · boiler scorpion · furnace centipede · oil slug | W/C · hammerhead mole · rebar tick · scaffold goat · concrete tortoise | W/C · window cicada · suit owl · glass squirrel · elevator wasp | W/C · attic weasel · mold rabbit · chimney possum · ceiling mouse | W/C · butcher dog · freezer cricket · shopping crab · meat fly | W/C · police horse · archive silverfish · firehouse salamander · chapel snail | waterline: drain eel · water strider · minnow school · mudskipper |
| **T2 Shallows** | flooded fish 50 %, **30 %** of it: rust-crested eel · sludge crab · boiler lamprey · grease viper | rebar snapping turtle · concrete ray · scaffolding barnacle · silt-dredger catfish | silt stalker · document squid · LED anglerfish · vault moray | barnacle leech · submerged hound · gutter pike · aquarium betta | neon jellyfish · display-case mantis shrimp · cart skeleton crabs · billboard stingray | drain pipe octopus · sewer gator · culvert hagfish · valve urchin | F · Fi · Tr, Cat · reef shark · depth barracuda · swarm anchovy · chasm lionfish |
| **T3 Cold** | dry: W/C · flooded: fish 50 % (Tr 20 / Cat 40 / Bar 40) · ☐ ______ | dry: W/C · flooded: fish 50 % · ☐ ______ | dry: W/C · flooded: fish 50 % · ☐ ______ | dry: W/C · flooded: fish 50 % · ☐ ______ | dry: W/C · flooded: fish 50 % · ☐ ______ | dry: W/C · flooded: fish 50 % · ☐ ______ | S ~1/120 · Fi ~1/65 · Cat, Bar ~1/100 · ☐ ______ |
| **T4 Dark** | dry: W/C · flooded: D 80 % · ☐ ______ | dry: W/C · flooded: D 80 % · ☐ ______ | dry: W/C · flooded: D 80 % · ☐ ______ | dry: W/C · flooded: D 80 % · ☐ ______ | dry: W/C · flooded: D 80 % · ☐ ______ | dry: W/C · flooded: D 80 % · ☐ ______ | S ~1/120 · Fi ~1/65 · ☐ ______ |
| **T5 Crush** | dry: W/C · flooded: D 80 % · ☐ ______ | dry: W/C · flooded: D 80 % · ☐ ______ | dry: W/C · flooded: D 80 % · ☐ ______ | dry: W/C · flooded: D 80 % · ☐ ______ | dry: W/C · flooded: D 80 % · ☐ ______ | dry: W/C · flooded: D 80 % · ☐ ______ | S ~1/120 · Fi ~1/65 · ☐ ______ |

Slot count: **36 interior + 6 open-water = 42 unique slots, 20 filled** (the whole T0, T1 and T2 rows incl.
their open-water cells, four creatures per slot, built 2026-09-06). Ten shared monsters exist. The editable
version of this grid is the Bestiary Grid artifact (2026-09-06); its saved slots are what gets built.

The flooded floors of T2 and T3 were the **quiet rows** until 2026-09-06; the three predator fish now
fill them (50 % per flooded wing-floor), which closes the "first dives feel safe" question left open on
2026-09-05. The unique slots there are still open for district-specific swimmers.

### 3a. Identity hints per district (mirrors the modifier families)

Prompts only — the names go in the grid, the numbers in §4.

| District | Modifier family says | Monster identity that fits | Watery twist for T4–T5 |
|---|---|---|---|
| Industrial | damage | heavy hitter, slow, armoured (hard hats, welding masks) | pressure-suited brute |
| Construction | knockback + scrap speed | shover / thrower (rebar, debris), knocks players off ledges | anchored to scaffold, lunges |
| Business | speed | fast, thin, erratic (suits, ties) — the sprinter | pale swimmer that darts |
| Residential | weight + carry | swarm — many, weak, from apartments; pockets are theirs | bloated, bursts |
| Commercial | air + swim | the aquatic line — swims well even in T2–T3 flooded floors | ambusher in flooded shops |
| Civil | defense + light + cold | armoured (riot gear, firefighter turnout), resists bleeding, flinches from light | cold-immune, slow, tanky |
| Open water | — | surface: floaters; column: sharks/fish; per stage one apex or one nuisance | T5: something bigger than a shark |

### 3b. Pocket guardians (built 2026-09-06)

The rooms behind the apartment doors are the one place that breaks the "shared density" rule on
purpose: **75 % of pockets hold a single elite** at **2x hp and damage** — one of the tower
district's own creatures for the pocket's state (dry → the T1 uniques, flooded → the T2 ones; a walker
or a barracuda where a district has none yet). Knobs: `seeding.pocket_monster_chance` / `_mult`.

## 4. Likelihood scheme for unique monsters (proposal)

Keep the existing rolls; a unique monster **replaces a share** of the cell's rolls rather than adding
on top, so density stays where the 2026-09-05 pass put it (1.7 zombies per dry wing-floor).

| Stage | Unique share of each zombie/Drowned roll | Reads as |
|---|---|---|
| T1 | 15 % | a rare face on the roofs and top floors |
| T2 | 20 % | one in five |
| T3 | 25 % | one in four |
| T4 | 30 % | common |
| T5 | 35 % | the district's signature threat |

- **Dry floors:** each of the 0–3 zombies rolled is the district's unique with the stage share,
  else walker/crawler at today's 70/30.
- **Flooded T2–T3 floors:** today 0 %. Proposed: the district's unique swimmer at **40 %** per
  flooded wing-floor (half the Drowned's 80 %), pity timer applies. Non-swimming uniques (most
  districts) still leave these floors quiet — only districts whose T2/T3 unique can swim fill them.
- **Flooded T4–T5 floors:** the 80 % Drowned roll becomes the unique with the stage share.
- **Open water:** the stage's unique gets its own spacing walk (start at shark spacing 80–160,
  restricted to that band's depth rows).
- **Red moons:** waves draw from the player's current district × band cell at the same shares, so a
  base in the civil district gets civil monsters at night.

Sanity fence: with these shares a full city seeds roughly the same count as today; the split is
what changes. Re-run `m4_smoke` seeding counts after any share edit.

## 5. Data and code this needs (not built)

1. `data/enemies.json` type entries gain `district` (one of the six, or `"open_water"`) and `stage`
   (1–5); a type with both is a unique, a type with neither is shared. The Monster Editor grows two
   dropdowns; enabling the matching band row is still what lets it seed (GD-23).
2. `seeding` gains `unique_share` (per stage, §4) and `flooded_swimmer_chance` (0.4).
3. `EnemyGen` reads `tower.district` (already on the tower dict) and picks the unique for
   (district, band) before falling back to the shared roll; annex pockets resolve their district
   through the doorway's tower like `LootGen.district_of`.
4. Aggro/AI: new movement or attack verbs (throw, lunge, burst) are per-type flags in `Enemy`, one
   at a time as slots get filled. Sprites: one 8-frame strip per look through the Monster Editor.
5. Gate: `m4_smoke` gains a check that every filled slot seeds at least once in a full city and never
   outside its district × band.

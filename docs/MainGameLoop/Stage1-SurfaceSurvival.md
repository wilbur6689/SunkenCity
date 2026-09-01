# Stage One — Surface Survival

> *The player starts by swimming on the surface between buildings. Buildings are accessible only
> through existing openings (broken windows, rooftop doors, breaches). The player must learn to
> craft basic tools and establish a first base.* — GameOverview.md, Main Game Loop

Stages are **emergent, not scripted** (GL-01): nothing flags "Stage One complete". A player is in
Stage One for as long as 30 seconds of air and scrap-tier tools are all they have.

| | |
|---|---|
| **Band** | The Dry (above the waterline) + the surface itself |
| **Depth** | Rooftops and dry upper floors; open water at the waterline |
| **Target time** | ~10 h (GL-27, "slow start") |
| **Entry state** | Plain clothes, 2 bandages, 1 food item; no tools (LT-30) |
| **Exit capability** | First **scrap air tank** (+30 s) and a working base — the player can afford to go *under* |
| **Milestones** | M0 (movement/oxygen), M1 (the loop), M3 (city + medical room), M4 (dry-band enemies, red moons) |

**Open questions** (`S1-NN`) close every section below: open-ended prompts meant to add variety and harden playability. Same workflow as `../OpenQuestions.md` — answer on an indented `**A:**` line, mark `[x]` answered or `[~]` deferred.

---

## Where it happens

- **The starting medical room** (GL-02, CT-20): the top floor of the tallest tower, authored by
  `CityGen._author_medical_room` — a real bed (default spawn, GL-23), medical gear, storage. The
  player is immune to the virus (GD-22); waking in a hospital is the quiet lore hook.
- **The Dry**: every floor above `waterline_row`. Rooms come from `data/rooms.json` templates
  filtered by zone (residential / office / hospital, mixed per floor — CT-02/03) and depth range.
- **The surface**: auto-tread, lateral movement at walk speed, 2-block water-jump onto ledges
  (WS-07). Between towers is open water only (CT-09); light debris rafts dress the waterline
  (CT-23). Floaters drift here, more at night (GD-05/29).
- **Access is through openings** — broken windows, rooftop doors, breaches (CT-11). Structure
  blocks *can* be broken, but only wood/plastic at this tier (`Constants.STRUCTURE_TIER`); stone
  and metal walls hold until Stage Three/Four tools.

**Open questions**

- [ ] **S1-01.** What makes one rooftop or dry floor feel different from the next on arrival — collapsed sections, rooftop gardens, helipads, water towers, billboard scaffolds — and which of these could double as a resource or a base site?
- [ ] **S1-02.** Should the starting hospital tower be recognisable from the water (signage, helipad, a red cross) so a swimmer can always find home without the map?
- [ ] **S1-03.** What surface-only points of interest (a rooftop tent camp, an abandoned raft, a downed news helicopter) could seed a small story beat and a guaranteed early reward?

## What the player has coming in

Nothing but the room. Every tool is scrapped out of furniture (GL-03):

| Tool | Recipe (hand, anywhere) | Role |
|---|---|---|
| `pry_bar` | 4 scrap metal | **open** — jammed doors (`wood_door`), breaching |
| `scrap_knife` | 2 scrap metal + 1 cloth | **harvest** — the melee fallback, least water-slowed |
| `hammer` | 2 wood + 2 scrap metal | **build** — place/remove blocks, 10 dmg to placed blocks |

Interaction model (`scripts/player/interaction.gd`): LMB short-click interacts, hold ~0.5 s picks
furniture up, RMB hold-to-scrap; **Q** = bare hands. Field scrapping returns
`FIELD_SCRAP_YIELD = 0.5` of the full yield (GL-07) — the haul-it-home decision starts on day one.

**Open questions**

- [ ] **S1-04.** Should the starting kit vary a little by seed or character (a different guaranteed consumable, a note, a key to one nearby room) so first hours don't play identically?
- [ ] **S1-05.** Which of the three starter tools could be *found* in the room on some seeds instead of crafted, shortening the first ten minutes without losing the scrap lesson?
- [ ] **S1-06.** Is there a fourth thing the medical room should teach before the player leaves (bandage recipe, glowstick, quick-stack) so healing and light are known to exist?

## The loop at this stage

1. **Harvest** — scrap the medical room (cloth, wood, plastic, scrap metal). Loot the cabinets:
   Dry-band tables give wood, cloth, food cans, bandages, scrap metal (`data/loot.json`,
   `generic.dry` / `residential.dry` …). Everything is **one-time** (LT-27).
2. **Craft** — hand-craft the three tools, then the **Workbench** (8 wood + 2 scrap). The
   workbench unlocks `chest`, `bed`, `wood_door`, `scrap_block`, `stone_block`, and the other
   four stations (Forge needs 10 stone — usually a Stage Two purchase).
3. **Build base** — the standing rule's third beat. A base is *wherever your bed, storage,
   stations and lights are* (GL-14). Wood blocks/walls, a door, a chest (20 slots, quick-stack),
   a `standing_lamp` (2 wood + 1 plastic + 1 scrap). Placed blocks float Terraria-style (CT-17).
4. **Range outward** — swim the surface to neighbouring towers, enter through breaches, clear
   walkers/crawlers, loot dry floors, drag the good stuff home. Carried weight slows swimming
   (soft cap: half speed at 60 weight, `WEIGHT_SWIM_REFERENCE`).
5. **Feel the ceiling** — 30 s of air (`BASE_OXYGEN_SECONDS`) gets you 2–3 floors down and barely
   back (WS-08). Dry loot depletes; the interesting rooms are under the waterline.

**Open questions**

- [ ] **S1-07.** What is the first surprising discovery — a room only reachable by breaking a glass block, a chest behind a wood partition — that teaches "the hammer opens things" without a tutorial?
- [ ] **S1-08.** How could returning to base feel like a reward rather than a chore in Stage One — quick-stack, a haul-weight readout, a lit doorway at dusk, a chest that fills visibly?
- [ ] **S1-09.** What small repeatable surface activities (fish schools drifting past, debris rafts with salvage, culling night floaters for cloth) keep the stage from being "loot rooms until empty"?

## Systems in play

- **Movement**: walk 5 / sprint 7 / surface swim 5 blocks/s; 3-block jump with the two-jump rule
  between floors (WS-04, enforced by a gen repair pass); crawl through gaps in compact form.
  Water always breaks a fall (WS-15) — the fall-damage escape hatch is built into the setting.
- **Oxygen & drowning**: 30 s baseline, drains only fully submerged, instant refill in air; at
  zero, ~10 s of health drain (GD-20). Stage One dips are *peeks*, not dives.
- **Health**: 100 HP, passive regen 1 HP/s after 8 s out of combat (GL-21); bandages heal 25 and
  stop bleeding; food cans heal 40 (CC-15: food heals, no hunger).
- **Light**: sun above the waterline; **fog of war inside buildings** (WS-20) — interiors reveal by
  line of sight; a placed lamp or dropped glowstick is a **fog beacon** that keeps its surroundings
  revealed. Some dry sections have working wiring: find the **breaker**, flip it, lights come on;
  flooding trips it (WS-17).
- **Map**: fog-of-war minimap (top-right, reveal r=14) and **M** for the full map (CC-25).
- **Day/night**: 600 s cycle (`DAY_LENGTH_SECONDS`). At night surface aggro radii grow ×1.5 and
  extra floaters drift in (up to 5 near a player), dispersing at dawn (GD-29).

**Open questions**

- [ ] **S1-10.** Should night danger ramp over the first few days so the first red moon lands after the player has a wall and a door, not before?
- [ ] **S1-11.** Does the two-jump rule need a visual language (rubble piles, furniture placed as steps) so players read "I can get up there" at a glance?
- [ ] **S1-12.** What would make surface swimming between towers interesting — wind-driven surface drift, floaters as moving cover, debris to cling to — without adding a stamina meter?

## Crafting & recipes available

Hand (known from the start): `pry_bar`, `scrap_knife`, `hammer`, `rope` (2 cloth), `ladder`
(3 wood), `glowstick` (1 plastic), `bandage` (2 cloth), `standing_lamp`, `wood_block`,
`wood_wall`, `workbench`.

Workbench (Stage One-affordable): `chest`, `bed`, `wood_door`, `scrap_block`, `scrap_sword`
(3 scrap + wood + cloth), `fire_axe` (3 scrap + 2 wood), `speargun` (3 scrap + 2 plastic + cloth),
`speargun_bolt` (1 scrap), `helmet_lamp` (2 scrap + 2 plastic), and the stations:
**Dive Station** (6 scrap + 4 plastic), **Med Station** (4 scrap + 4 plastic + 2 cloth),
**Modification Bench** (6 scrap + 4 wood), **Forge** (10 stone + 4 scrap).

Ladders matter early: submerged stairwell ladder runs are broken into gaps with `broken_ladder`
scrap pieces — scrap them for wood, craft and place ladders to climb back up.

**Open questions**

- [ ] **S1-13.** Which one or two extra hand recipes (a torch, a crude raft, a wooden platform, a bucket) would most widen Stage One play without touching the station tiers?
- [ ] **S1-14.** Should the Workbench show a "next thing you could make" hint so harvest → craft pulls forward, or does that spoil discovery?
- [ ] **S1-15.** How should recipe visibility be paced — everything tier-1 listed at once, or entries revealed the first time an ingredient is held?

## Loot & materials

| Source | Yields |
|---|---|
| Residential dry | food cans, cloth, wood, bandages |
| Office dry | scrap metal, plastic, wood (office flavour: metal/electronics, CT-03) |
| Hospital dry | bandages, medkits, cloth |
| Furniture scrap | wood, cloth, plastic, scrap metal; **no iron or steel anywhere above The Cold** (GL-28 depletion design, verified in `m5_smoke`) |
| Zombies | light drops only — cloth, the odd scrap (GD-24) |

The scarcity that ends Stage One is deliberate: scrap metal covers tools and a tank, but the
Forge (10 stone) and every iron recipe demand material that only exists below the waterline.

**Open questions**

- [ ] **S1-16.** What one Dry-band jackpot per world (a found speargun, a compass, a schematic) gives the first hours a "wow" without breaking the iron gate?
- [ ] **S1-17.** Should residential / office / hospital floors be readable at a glance (furniture silhouettes, back-wall colour) so players choose where to loot for what?
- [ ] **S1-18.** How much should be reachable without ever touching water — enough for base + first tank, or deliberately a little short so the first dip is forced?

## Dangers

| Threat | Dry-band stats (`data/enemies.json`) | Notes |
|---|---|---|
| Walker | 30 HP, 8 dmg, 2.2 b/s, aggro 10 | Dry floors; never walks off a ledge (GD-04 edge sense) |
| Crawler | 20 HP, 6 dmg, 2.6 b/s, aggro 8 | Fits 2-block gaps and vents |
| Floater | 24 HP, 8 dmg, 1.2 b/s, aggro 9 | Surface drifter (Shallows table); extra at night |
| Bleeding | 35 % per zombie hit, 1.5 HP/s for 18 s | Bandage/medkit cures instantly (GD-21) |
| Drowning | 10 s to death at zero O2 | The real Stage One killer |
| **Red moon** | first one on day 5–10 (≈ 50–100 min of play) | Waves of 3 walkers/player (+0.3/day) every 25 s through the night, spawning 16–30 blocks out, pounding **player-placed** blocks only (GL-15) |

Combat is melee: scrap knife, scrap sword, fire axe. Firearms are loot-only and none roll in dry
tables. No stealth, no noise — proximity aggro only (GD-06/25/26).

**Open questions**

- [ ] **S1-19.** What non-combat hazards suit the Dry and stay recoverable (GL-29) — weak floors that drop you into water, glass that cuts when broken, rooftop gusts?
- [ ] **S1-20.** Should walkers have surface behaviours — stumbling into water and becoming floaters — that link the two rosters and make ledges tactical?
- [ ] **S1-21.** How does the first red moon announce itself (sky colour hours ahead, a distant moan, a HUD countdown) so the player prepares instead of being ambushed?

## Base & water

- **First base = the medical room** for most players (bed already there). Fortify with wood
  blocks and a door before the first red moon; water moats and drowned approaches are premium
  defences (GL-15).
- **Water is the "dig"**: even in Stage One, placing blocks into water displaces it, or destroys
  it if the pocket is enclosed (WS-24) — the fill-to-drain tactic works before pumps exist.
- Death drops the **backpack** (not worn gear); it floats up unless it hits a ceiling, so a Stage
  One drowning in a flooded stairwell pins the bag to that ceiling (CC-07). Respawn at the bed.

**Open questions**

- [ ] **S1-22.** What makes a first base *pretty* as well as functional — tintable back walls, salvaged furniture placed as decor, a window framing the skyline?
- [ ] **S1-23.** Should players be able to carry water upward early (a bucket) to flood a doorway as a first moat, or is that a Stage Two pump privilege?
- [ ] **S1-24.** Where is the *ideal* first base — the medical room, a rooftop, a drained shallow room — and does world-gen guarantee an obvious candidate near spawn?

## Skills & abilities

Learn-by-doing (CC-18): **Scrapping** (per object scrapped), **Swimming** (0.5 XP/s in water),
**Building** (1 XP/block). 20 XP per skill level; every 5 skill levels = 1 player level = 1 ability
point. Stage One typically banks the first point — **Field Strip** (75 % field yield) is the
natural pick for a scrap-everything opening; **Long Reach** (+1 block) or **Strong Kick** (+10 %
swim) are the alternatives.

**Open questions**

- [ ] **S1-25.** Should the very first ability point come early (e.g. at 3 skill levels) so the tech tree is discovered inside Stage One?
- [ ] **S1-26.** What visible feedback (skill-up toast, faster scrap animation) makes learn-by-doing legible before the numbers matter?
- [ ] **S1-27.** Is there room for a fourth MVP skill (Combat, Diving, Engineering) or does three keep player level ÷ 5 honest?

## Exit gate — what pushes the player down

Capability, not quest (GL-01): a **Dive Station** and a `tank_scrap` (4 scrap + 1 plastic,
+30 s → 60 s of air) turn peeks into dives. Pull factors: dry loot is gone, the Forge needs stone
that only the Shallows have, and the map shows most of the city is below the line.

**Open questions**

- [ ] **S1-28.** What is the *emotional* exit of Stage One — a lit room glimpsed two floors under, a ladder vanishing into black water — and can gen guarantee it near spawn?
- [ ] **S1-29.** Should the scrap tank be craftable at the Workbench so the exit is purely material, or does the Dive Station requirement usefully teach stations?
- [ ] **S1-30.** What should a player who never dives still be able to do for hours — is a surface-only playstyle worth supporting at all?

## Tuning knobs

`BASE_OXYGEN_SECONDS` 30 · `DROWNING_SECONDS_TO_DEATH` 10 · `FIELD_SCRAP_YIELD` 0.5 ·
`WEIGHT_SWIM_REFERENCE` 60 · `DAY_LENGTH_SECONDS` 600 · `RED_MOON_MIN/MAX_DAYS` 5/10 ·
`RED_MOON_BASE_WAVE` 3 · `AGGRO_NIGHT_MULT` 1.5 · `NIGHT_FLOATER_MAX` 5 · `STRUCTURE_TIER`
(wood/plastic 1) · `SCRAP_SPEED_MULT` 2.0 (testing boost — revisit in the balance pass).

**Open questions**

- [ ] **S1-31.** Which knobs would a "gentler first hour" world toggle (CC-20) touch — oxygen, red-moon start day, walker HP — and which must never move?
- [ ] **S1-32.** Is a 10-minute day right for a surface stage where night matters, or should days feel longer above water than the underwater play implies?

## Design references

GL-01/02/03/04/07/14/15/21/22/23 · CC-07/08/11/15/18/22 · WS-04/07/08/12/14/15/17/20/24 ·
GD-01/04/05/06/21/22/24/29 · LT-27/30 · CT-02/03/09/11/17/20/23.

## Open / feel-check notes

- **GL-27 pacing feel-check is still open** — ~10 h for this stage is the target, unmeasured.
- Onboarding is deferred to early access (CC-24); the medical room's furniture set *is* the
  tutorial for now. Watch whether players discover scrap → pry bar unprompted.
- First red moon at 50–100 minutes assumes 10-minute days; if days lengthen, revisit.

**Open questions**

- [ ] **S1-33.** What single metric (time to first tank, deaths before first dive, red moons survived) best tells us Stage One is ~10 h and fun?
- [ ] **S1-34.** Which parts of the medical room should be unscrappable so a new player can't strip their own bed and lose spawn?


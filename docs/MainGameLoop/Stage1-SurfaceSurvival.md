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
| **Entry state** | Plain clothes, 2 bandages, 1 food item (LT-30), dropped off on the centre tower's roof; no tools |
| **Exit capability** | First **scrap air tank** (+30 s) and a working base — the player can afford to go *under* |
| **Milestones** | M0 (movement/oxygen), M1 (the loop), M3 (city, districts, roofs), M4 (dry-band enemies, red moons) |

**Open questions** (`S1-NN`) close every section below: open-ended prompts meant to add variety and harden playability. Same workflow as `../OpenQuestions.md` — answer on an indented `**A:**` line, mark `[x]` answered or `[~]` deferred.

**Units note (2026-09-05 review):** speeds and radii quoted below in blocks/s or blocks predate the 8 px cell of 2026-09-04; in today's cells every such figure doubles (walk 10 / sprint 14 / swim 10 cells/s, jump 6; enemy speeds are already ×2 in `data/enemies.json`). Ratios are unchanged. Costs and row numbers have been corrected to current data where the review found them stale.

---

## Where it happens

- **The spawn roof** (`gen.spawn_tower`, 2026-09-02; GL-02/CT-20 amended): the run starts
  dropped off on the crown of the centre-most tower, roof-locked by the `roof_hatch` (a fixed
  tier-1 door); respawn returns there until a bed is placed (GL-23). The authored medical room and
  starting supplies are gone (2026-09-04) — hospital rooms are civil-district templates only. The
  player is immune to the virus (GD-22).
- **The Dry**: every floor above `waterline_row`, plus each surface tower's randomized **4–8 dry
  floors** under a tier-1 **wood barrier** (the dry cap, 2026-09-02). Rooms come from
  `data/rooms.json` templates filtered by zone and depth range; since districts (2026-09-04) a
  tower's district sets the zone of EVERY floor (residential / business / commercial / industrial /
  civil / construction — CT-02/03 amended).
- **The surface**: auto-tread, lateral movement at walk speed, 2-block water-jump onto ledges
  (WS-07). Between towers is open water only (CT-09); light debris rafts dress the waterline
  (CT-23). Floaters drift here, more at night (GD-05/29).
- **Access is through openings** — the `roof_hatch` (tripod or pry bar), `side_vent` grates on
  Shallows-band breaches (pry tier 1), broken windows, breaches (CT-11). Structure blocks *can*
  be broken, but only wood/plastic at this tier (`Constants.STRUCTURE_TIER`); stone and metal walls
  hold until Stage Three/Four tools.

**Open questions**

- [x] **S1-01.** What makes one rooftop or dry floor feel different from the next on arrival — collapsed sections, rooftop gardens, helipads, water towers, billboard scaffolds — and which of these could double as a resource or a base site?
    **A:** Variety is a data problem, not a code one: give the roof-zone template pool a **district signature** so a crown reads its tower at a glance — residential: trees, planters, laundry, water tanks; commercial: illuminated/logo signs, billboards, helipad; civil: antenna arrays, comm masts, dishes; industrial: stacks, cranes, cooling towers; construction: bare crane over frame. Double duty already exists and stays: trees are the wood farm, helipads/flat crowns are the base pad, rooftop gear is the scrap-metal/plastic source (never iron — GL-28). Requires a district filter on roof templates (S1-53). Modifier aspect reserved for the user's modifier pass.
- [x] **S1-02.** Should the starting hospital tower be recognisable from the water (signage, helipad, a red cross) so a swimmer can always find home without the map?
    **A:** Yes, cheaply: `gen.spawn_tower` gets one guaranteed **landmark roof piece** (the tallest comm mast or lit crown from `roof_gear`, flagged `landmark` in the template) so the home crown is the one silhouette the skyline never repeats, and the map marks spawn. It only matters for the pre-bed hours; once a bed moves spawn (GL-23) the lamp-lit roof at night (S1-08) is the marker. The "hospital tower" framing is retired — there is no medical room.
- [x] **S1-03.** What surface-only points of interest (a rooftop tent camp, an abandoned raft, a downed news helicopter) could seed a small story beat and a guaranteed early reward?
    **A:** No authored story POIs in the MVP — landmarks wait for the story pass (CT-20) and open water stays clean (CT-09). The existing debris rafts (CT-23) get a small `surface.debris` loot table (cloth, plastic, rope, occasionally a `tree_seed`), one-time like everything (LT-27), so the surface has *some* pickup without a system. Tent camps / downed helicopter / raft stories are post-release content.

## What the player has coming in

Nothing but the roof. The first tool is wood; the scrap tools moved behind the Workbench in the
roof-era economy (2026-09-01, tool costs ×5 — GL-03 amended):

| Tool | Recipe | Role |
|---|---|---|
| `wood_axe` | hand: 8 wood + 1 scrap metal | **fell** — the tree tool (`requires_tool: "axe"`); counts as bare hands elsewhere |
| `wood_tripod` | hand: 30 wood + 4 rope | **open** — the metal-free pry tier 1: levers the `roof_hatch` |
| `pry_bar` | Workbench: 20 scrap metal | **open** — jammed doors (`room_door_locked`), hatches, vents |
| `scrap_knife` | Workbench: 10 scrap metal + 5 cloth | **harvest** — the melee fallback, least water-slowed |
| `hammer` | Workbench: 10 wood + 10 scrap metal | **build** — place/remove blocks, 10 dmg to placed blocks |

Interaction model (`scripts/player/interaction.gd`): LMB short-click interacts, hold ~0.5 s picks
furniture up, RMB hold-to-scrap; **Q** = bare hands. Field scrapping returns
`FIELD_SCRAP_YIELD = 0.5` of the full yield (GL-07) — the haul-it-home decision starts on day one.

**Open questions**

- [x] **S1-04.** Should the starting kit vary a little by seed or character (a different guaranteed consumable, a note, a key to one nearby room) so first hours don't play identically?
    **A:** No — the LT-30 kit is fixed (clothes, 2 bandages, 1 food). Variety comes from the seed's roof: tree count, roof gear, neighbour crown heights, which pockets rolled. A fixed kit keeps the first hour gate-testable and the balance honest; cosmetics remain the only per-character difference (canon).
- [x] **S1-05.** Which of the three starter tools could be *found* in the room on some seeds instead of crafted, shortening the first ten minutes without losing the scrap lesson?
    **A:** Nothing is found. The question is stale: the three scrap tools are now Workbench recipes and the starter tool is the hand-crafted **`wood_axe`** (8 wood + 1 scrap) — the roof teaches fell → craft before any scrap tool exists, which is the wood-mastery canon. A found pry bar would skip the tripod, the stage's key; refuse it.
- [x] **S1-06.** Is there a fourth thing the medical room should teach before the player leaves (bandage recipe, glowstick, quick-stack) so healing and light are known to exist?
    **A:** Reframed from "the medical room" to "the roof before the hatch": it should teach four things — **fell** (axe/trees), **farm** (planter/seed), **build** (wood blocks/walls) and **light** (night darkness forces it). The Workbench is intentionally roof-buildable (30 wood + 15 scrap, scrap from roof gear) so `standing_lamp`, `glowstick` and `bandage` are reachable pre-hatch; healing is known to exist via the two starting bandages plus the greyed-but-inspectable bandage recipe (existing behaviour). No fifth lesson.

## The loop at this stage

1. **Harvest** — fell the roof's trees (`wood_axe`), scrap rooftop gear for scrap metal and
   plastic, then, once the hatch is open, the dry floors below (cloth, wood, plastic, scrap
   metal). Dry-band tables give wood, cloth, food cans, bandages, scrap metal (`data/loot.json`,
   `generic.dry` / `residential.dry` …). Loot is **one-time** (LT-27); only wood is farmable.
2. **Craft** — hand-craft the axe, then the **Workbench** (30 wood + 15 scrap — a multi-run
   project). The workbench unlocks the scrap tools, `bed`, `wood_door`, `scrap_block`,
   `stone_block`, and the other four stations (Forge needs 10 stone — usually a Stage Two purchase).
3. **Build base** — the standing rule's third beat. A base is *wherever your bed, storage,
   stations and lights are* (GL-14). Wood blocks/walls, a door, a chest (20 slots, quick-stack),
   a `standing_lamp` (2 wood + 1 plastic + 1 scrap). Placed blocks float Terraria-style (CT-17).
4. **Range outward** — swim the surface to neighbouring towers, enter through breaches, clear
   walkers/crawlers, loot dry floors, drag the good stuff home. Carried weight slows swimming
   (soft cap: half speed at 60 weight, `WEIGHT_SWIM_REFERENCE`).
5. **Feel the ceiling** — 30 s of air (`BASE_OXYGEN_SECONDS`) gets you 2–3 floors down and barely
   back (WS-08). Dry loot depletes; the interesting rooms are under the waterline.

**Open questions**

- [x] **S1-07.** What is the first surprising discovery — a room only reachable by breaking a glass block, a chest behind a wood partition — that teaches "the hammer opens things" without a tutorial?
    **A:** The first discovery is the **deadbolted pocket door** (`room_door_locked`, pry only) beside a tier-1 wood partition: hammering through the wall next to a door you can't open is the "the hammer opens things" lesson with no tutorial. Gen guarantees at least one deadbolted apartment doorway on the spawn tower's dry floors (a forced roll in `_carve_pocket` for `spawn_tower`); everything else stays odds-driven.
- [x] **S1-08.** How could returning to base feel like a reward rather than a chore in Stage One — quick-stack, a haul-weight readout, a lit doorway at dusk, a chest that fills visibly?
    **A:** No new system. Returning home is rewarded by things that already exist or are near-free: chest **quick-stack**, the gain feed, and — thanks to dark nights — the lamp-lit roof visible from the water as a beacon at dusk. Add one small UI line: a **carried-weight readout** in the bag header (the soft cap is felt already; showing the number makes hauling a decision). Chest fill visuals are cosmetic polish, post-MVP.
- [x] **S1-09.** What small repeatable surface activities (fish schools drifting past, debris rafts with salvage, culling night floaters for cloth) keep the stage from being "loot rooms until empty"?
    **A:** Two renewables carry the surface: the **tree farm** (wood + seeds, deterministic two-day grow) and **night floaters** (cloth / odd scrap — GD-24, the GD-29 ambient-spawn exception). Fish schools stay a Shallows introduction (S2). Debris rafts are one-time (S1-03). Stage 1 is "farm, build, cull, then descend" — no new activity systems.

## Systems in play

- **Movement**: walk 10 / sprint 14 / surface swim 10 cells/s; 6-cell jump with the two-jump rule
  between floors (WS-04, enforced by a gen repair pass); crawl through 2-cell gaps in compact form.
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
- **Day/night**: 600 s cycle (`DAY_LENGTH_SECONDS`), now **visible and dark** (2026-09-02). At
  night the surface falls to near-black silhouettes — you need a light to see: a placed
  `standing_lamp`, a dropped `glowstick`, or a worn `helmet_lamp` (a tight moonlit radius keeps you
  from being blind at your feet, but working, harvesting, or fighting after dark wants a real
  light). Aggro radii also grow ×1.5 and extra floaters drift in (up to 5 near a player),
  dispersing at dawn (GD-29) — so the first nights push the player to craft light *and* a wall.

**Open questions**

- [x] **S1-10.** Should night danger ramp over the first few days so the first red moon lands after the player has a wall and a door, not before?
    **A:** Yes. The red moon clock (day 5–10, ≥ 50 min) already lands after a wall is affordable; add a **night-floater ramp**: `NIGHT_FLOATER_MAX` scales from 1 on night 1 to its full 5 over `NIGHT_FLOATER_RAMP_DAYS` (3). `RED_MOON_MIN_DAYS` stays 5. Walkers can't reach a hatch-sealed roof at all (GD-04, fixed hatch), so the early nights are floater-and-darkness pressure by design.
- [x] **S1-11.** Does the two-jump rule need a visual language (rubble piles, furniture placed as steps) so players read "I can get up there" at a glance?
    **A:** Yes, with a fixed vocabulary: the WS-04 repair pass places footholds only from a small `foothold`-tagged object set (rubble pile, crate, overturned desk), so "I can get up there" has three learnable silhouettes. Data-only (a tag in `objects.json` + the repair pass filtering on it).
- [x] **S1-12.** What would make surface swimming between towers interesting — wind-driven surface drift, floaters as moving cover, debris to cling to — without adding a stamina meter?
    **A:** No. Gaps are now 5–10 cells, so an inter-tower swim is seconds; drift, currents and gusts belong to the post-MVP weather pass (canon: light weather post-MVP, WS-16 currents are an engineered tool). Floaters already make night swims tactical. No stamina meter, ever.

## Crafting & recipes available

Hand (known from the start): `wood_axe` (8 wood + 1 scrap), `rope` (2 cloth → 16), `ladder`
(3 wood → 12), `wood_block`, `wood_wall`, `chest` (6 wood + 1 scrap), `workbench` (30 wood +
15 scrap), **`planter`** (6 wood), `planter_box` (15 wood), **`wood_bucket`** (15 wood),
**`wood_tripod`** (30 wood + 4 rope).

**Wood is the key, not just the material** (2026-09-02, design canon — see GameOverview "Main Game
Loop"): Stage One is the **wood-mastery** stage. The run starts roof-locked, the shaft mouth sealed
by the `roof_hatch` (a tier-1 door). The intended opener is the **`wood_tripod`** — a lashed
wood-and-rope A-frame hoist that levers the hatch out, crafted entirely from farmed wood and cloth
with **no metal at all**. So the whole first arc is wood: fell and farm trees → craft wood tools,
a base, and the tripod → hoist the hatch → drop into the top dry floors, where scrap metal (and the
path to everything below) finally begins. (A scrap `pry_bar` still opens the hatch too, for players
who go the metal route — but the tripod is the pure-wood path the stage is built around.)

**The farm loop** (2026-09-02, implemented): the roof-locked start hands the player a stand of
trees. Fell them with the `wood_axe` and they now drop **`tree_seed`** (1–3 from a mature tree,
0–1 from smaller stages) alongside the wood. Craft a **planter pot**, place it under open sky, and
**plant a seed** in it (hold the seed, click the pot) — a sapling sprouts on the rim and advances
one stage each **dawn** (`World._grow_trees`, deterministic): plant on day *N* and it is a full
5×15 **mature tree** on the morning of day *N+2* — a **two-day** grow, and only where the sky is
clear above it (a roof; indoors it stalls at a small stage). Fell the grown tree for 25–40 wood
plus fresh seeds, and the planter stays for the next crop. That closes the renewable-wood loop the
early game needs: **wood is now farmable, so building a base no longer competes with the one-time
scrap pool.** The **`wood_bucket`** carries water by hand — click water to fill it, click an open
cell to pour — for early moats, filling a flooded doorway, or watering the look of a rooftop
garden.

Workbench (Stage One-affordable): `pry_bar` (20 scrap), `scrap_knife` (10 scrap + 5 cloth),
`hammer` (10 wood + 10 scrap), `glowstick` (1 plastic), `bandage` (2 cloth), `standing_lamp`
(2 wood + 1 plastic + 1 scrap), `bed` (6 wood + 4 cloth), `wood_door` (4 wood), `scrap_block`,
`wood_scrap_bench` (30 wood + 5 scrap — bulk-grinds wood-stage furniture), `scrap_sword`
(3 scrap + wood + cloth), `fire_axe` (3 scrap + 2 wood), `speargun` (3 scrap + 2 plastic + cloth),
`speargun_bolt` (1 scrap), `helmet_lamp` (2 scrap + 2 plastic), and the stations:
**Dive Station** (6 scrap + 4 plastic), **Med Station** (4 scrap + 4 plastic + 2 cloth),
**Modification Bench** (6 scrap + 4 wood), **Forge** (10 stone + 4 scrap).

Ladders matter early: submerged stairwell ladder runs are broken into gaps with `broken_ladder`
scrap pieces — scrap them for wood, craft and place ladders to climb back up.

**Open questions**

- [x] **S1-13.** Which one or two extra hand recipes (a torch, a crude raft, a wooden platform, a bucket) would most widen Stage One play without touching the station tiers?
    **A:** Added the **planter pot** + **tree seed** farm loop and the **wooden bucket** (2026-09-02) — see "The farm loop" above. The planter makes wood renewable (harvest → seeds → replant); the bucket carries water by hand. Both are hand recipes, no new station. Starting a farm + base is now the intended gate before diving (LT-27 depletion still holds for scrap metal / stone).
- [x] **S1-14.** Should the Workbench show a "next thing you could make" hint so harvest → craft pulls forward, or does that spoil discovery?
    **A:** No extra hint. Greyed recipes are already clickable and show `desc` lines — that *is* the "next thing you could make" pull. Add nothing; keep discovery.
- [x] **S1-15.** How should recipe visibility be paced — everything tier-1 listed at once, or entries revealed the first time an ingredient is held?
    **A:** Everything tier-1 listed at once (current behaviour), greyed until affordable. Revealing on first-held ingredient adds bookkeeping and hides the pull that S1-14 relies on. **Schematics** are the game's reveal mechanic (canon) and stay the only one.

## Loot & materials

| Source | Yields |
|---|---|
| Roof gear (every crown) | scrap metal, plastic, stone — never iron (GL-28) |
| Residential dry | food cans, cloth, wood, bandages |
| Business / commercial dry | scrap metal, plastic, wood (metal/electronics flavour, CT-03) |
| Civil dry (hospital, police) | bandages, medkits, cloth |
| Industrial / construction dry | scrap metal, wood, rope, tools |
| Furniture scrap | wood, cloth, plastic, scrap metal; **no iron or steel anywhere above The Cold** (GL-28 depletion design, verified in `m5_smoke`) |
| Zombies | light drops only — cloth, the odd scrap (GD-24) |

The scarcity that ends Stage One is deliberate: scrap metal covers tools and a tank, but the
Forge (10 stone) and every iron recipe demand material that only exists below the waterline.

**Open questions**

- [x] **S1-16.** What one Dry-band jackpot per world (a found speargun, a compass, a schematic) gives the first hours a "wow" without breaking the iron gate?
    **A:** One guaranteed **`helmet_lamp`** per world in a dry pocket of a tower neighbouring spawn (it also rolls at low weight in `residential.dry`). It answers the stage's real pressure — dark nights — as a wearable fog beacon, teaches gear slots, and breaks no gate: no iron, no station skip (it's Workbench-craftable anyway). Compass stays Crush-only (S5); wall safes stay `SURFACE_SAFE_CHANCE` rare.
- [x] **S1-17.** Should residential / office / hospital floors be readable at a glance (furniture silhouettes, back-wall colour) so players choose where to loot for what?
    **A:** Yes, at the **tower** level now that a district sets every floor's zone: the roof signature (S1-01) from outside, a per-zone **back-wall tint** inside (one colour per zone in the room-template back wall, mirrored in `MapColors`). Zone-flavoured loot (CT-03) already exists; this just makes it legible. Modifier aspect reserved.
- [x] **S1-18.** How much should be reachable without ever touching water — enough for base + first tank, or deliberately a little short so the first dip is forced?
    **A:** Deliberately a little short. Roof gear + 4–8 dry floors (50 % pockets) fund the base, Workbench, tripod, Dive Station and the first `tank_scrap`; **stone** (Forge) and plastic volume don't exist above the line, so the first dip is forced by material, not by scarcity of scrap. Confirm the dry budget in the GL-27 feel-check.

## Dangers

| Threat | Dry-band stats (`data/enemies.json`) | Notes |
|---|---|---|
| Walker | 30 HP, 8 dmg, 2.2 b/s, aggro 10 | Dry floors; never walks off a ledge (GD-04 edge sense) |
| Crawler | 20 HP, 6 dmg, 2.6 b/s, aggro 8 | Fits 2-block gaps and vents |
| Floater | 24 HP, 8 dmg, 1.2 b/s, aggro 9 | Surface drifter (Shallows table); extra at night |
| Bleeding | 35 % per zombie hit, 1.5 HP/s for 18 s | Bandage/medkit cures instantly (GD-21) |
| Drowning | 10 s to death at zero O2 | The real Stage One killer |
| **Red moon** | first one on day 5–10 (≈ 50–100 min of play) | Waves of 3 walkers/player (+0.3/day) every 25 s through the night, spawning 32–60 cells out, pounding **player-placed** blocks only (GL-15) |

Combat is melee: scrap knife, scrap sword, fire axe. Firearms are loot-only and none roll in dry
tables. No stealth, no noise — proximity aggro only (GD-06/25/26).

**Open questions**

- [x] **S1-19.** What non-combat hazards suit the Dry and stay recoverable (GL-29) — weak floors that drop you into water, glass that cuts when broken, rooftop gusts?
    **A:** None authored in the MVP — canon says no environmental hazards (GameOverview Dangers). The Dry's hazards are the water (falls end in a swim back), night darkness and the dry cap. Weak floors / glass cuts / gusts are post-MVP ideas-list items.
- [x] **S1-20.** Should walkers have surface behaviours — stumbling into water and becoming floaters — that link the two rosters and make ledges tactical?
    **A:** Yes, cheaply: a walker that ends up submerged (knockback off a ledge — GD-04 edge sense means they never walk off) converts after a few seconds into a **floater** record (`drowns_into: "floater"` in `enemies.json`). It links the two rosters, makes knockback weapons and ledges tactical, and needs no new AI.
- [x] **S1-21.** How does the first red moon announce itself (sky colour hours ahead, a distant moan, a HUD countdown) so the player prepares instead of being ambushed?
    **A:** Diegetic only: `RED_MOON_TINT` ramps in over the last daylight hour of the red-moon day, the backdrop moon rises red, and a music stinger fires at moonrise (audio canon). No HUD countdown (GL-01 — no quest-like timers); the day counter on F3 is enough for the curious.

## Hazards, puzzles & water management

The Dangers table above is the combat roster; this section is the wider **hazard design
space** — what can block, trick, teach, or soak a Stage One player besides a bite.

- **Monster texture**: three silhouettes own three spaces — walkers the dry floors, crawlers
  the vents and 2-block gaps, floaters the waterline. Stage One should teach the read: *where
  you are* decides *what hunts you*, before deeper bands complicate it.
- **Environmental danger is the water itself**: a mistimed peek, a flooded stairwell with the
  ladder run decayed, a night swim through drifting floaters. Everything stays recoverable by
  design (GL-29) — falls end in water, drownings end at the bed with a bag to recover.
- **Puzzles at this tier are spatial**: the two-jump rule makes every gap a small problem
  (stack furniture? place a block? craft a ladder?); jammed doors ask for the pry bar; the
  breaker asks "where does this wire go?"; fog of war makes the layout itself the riddle.
- **Traps are emergent, not authored**: the walker behind the unopened door, the floor that
  looks dry above a flooded room, glass underfoot. Nothing is scripted — the odds tables are
  the trap-maker.
- **Water management starts as one block**: placing wood into a doorway to hold water back, or
  into a broken window to keep a room's air, is the whole M2 sim taught with a hammer. The
  first deliberate "I kept that room dry" is Stage One's quiet graduation — pumps make it
  official in Stage Two.

**Open questions**

- [x] **S1-35.** Should any Stage One puzzle be *authored* per world — a breaker two rooms from the lights it powers, a chest visible through an interior window with no direct door — or must all early puzzles stay emergent from generation?
    **A:** Emergent only; no per-world authored puzzles (CT-20). The two gen-level *patterns* — barred door + hidden button, breaker → lights — plus the S1-07 guarantee are the whole authored budget.
- [x] **S1-36.** What teaches "sealed rooms keep their air" *before* the player needs it — a visibly dry room glimpsed below the waterline through glass, bubbles escaping a freshly breached wall?
    **A:** The dry cap is the lesson. Give the cap block a hover `desc` ("holding back the flood below") and let the cap peek (S1-39) show the water beneath; the sealed dry pockets below the line then confirm it in Stage 2. No new visuals.
- [x] **S1-37.** Which telegraphed environmental traps fit the Dry and stay recoverable (GL-29) — sagging floorboards over a flooded floor, debris piles that slide when climbed — and what is their visual warning language?
    **A:** None in MVP — see S1-19.
- [x] **S1-38.** Should closed doors carry fixed odds of a surprise (a walker, a wall of water) so the "open door" verb always has stakes — and can the player scout one (listen at the door, peer through a crack) without adding a stealth system?
    **A:** Odds stay emergent (rooms seed enemies; 40 % of doors found open). No scouting mechanic (GD-06/25), but a diegetic tell: walkers' idle groan SFX audible through a closed door within a few cells (audio canon). That's the whole "listen at the door".
- [x] **S1-39.** What is the intended *first* water-management act — sealing a window ahead of a red moon, blocking a doorway to keep a looted room dry — and should the starting tower guarantee one obvious spot to try it?
    **A:** Two deliberate first acts, both guaranteed by gen: (1) the **bucket** — pour into a doorway and watch it settle; (2) the **cap peek** — break one cell of the dry cap, see the water below, place a wood block back. The peek is *safe* (water never rises), so it's the ideal sandbox for "blocks seal".
- [x] **S1-40.** When a new player floods their own floor by breaking the wrong window, what makes the mistake educational rather than base-ending — does the water find a level they can live with, and how do they learn what went wrong?
    **A:** Bounded by physics: floors above the exterior waterline can't flood; a floor inside the cap but below the line floods only to the exterior level (WS-24), so the mistake is half a room, standable, visibly rushing from the breach they made. Recovery = plug + bucket; S2-42's culprit-breach indicator covers the UI.
- [x] **S1-41.** Should the waterline ever move in Stage One (a storm surge raising it one row for a night) to teach that water is dynamic — or is a fixed line sacred until the Drain?
    **A:** Fixed until the Drain. Storm surges belong to post-MVP weather.
- [x] **S1-42.** Is there a Stage One primer for connectivity (the S2 patch-and-pump lesson) — e.g. a half-flooded floor in the starting tower where one placed block visibly stops the water — so Stage Two's core system is met, not introduced?
    **A:** Yes — S1-39's cap peek *is* the primer. No new gen feature.

## Base & water

- **First base = the spawn roof** for most players (open sky for the farm, a hatch walkers can't
  pass, trees and roof gear to hand). Fortify with wood blocks and a door before the first red
  moon; water moats and drowned approaches are premium defences (GL-15).
- **Water is the "dig"**: even in Stage One, placing blocks into water displaces it, or destroys
  it if the pocket is enclosed (WS-24) — the fill-to-drain tactic works before pumps exist.
- Death drops the **backpack** (not worn gear); it floats up unless it hits a ceiling, so a Stage
  One drowning in a flooded stairwell pins the bag to that ceiling (CC-07). Respawn at the bed.

**Open questions**

- [x] **S1-22.** What makes a first base *pretty* as well as functional — tintable back walls, salvaged furniture placed as decor, a window framing the skyline?
    **A:** MVP prettiness = what exists: salvaged furniture placed as decor (pick up / place), placeable back walls, lamps. Tintable walls, glass windows and trophies are the cosmetic-crafting sink (S5-15, post-Steam). No new content.
- [x] **S1-23.** Should players be able to carry water upward early (a bucket) to flood a doorway as a first moat, or is that a Stage Two pump privilege?
    **A:** Yes — the Stage One **`wood_bucket`** (2026-09-02) carries a cell of water by hand (fill on water, pour into an open cell). It's the manual, one-cell-at-a-time answer; the pump stays the Stage Two scaling tool (24-block reach, continuous drain). A first moat by bucket is slow but possible before diving.
- [x] **S1-24.** Where is the *ideal* first base — the medical room, a rooftop, a drained shallow room — and does world-gen guarantee an obvious candidate near spawn?
    **A:** The **spawn roof** is the ideal first base and gen already guarantees it: open sky for the farm, a hatch that walkers can't pass, trees, and roof-gear scrap. A drained shallow room is the Stage 2 base. The doc's "medical room" is replaced by the roof throughout.

## Skills & abilities

Learn-by-doing (CC-18): **Scrapping** (per object scrapped), **Swimming** (0.5 XP/s in water),
**Building** (1 XP/block). 20 XP per skill level; every 5 skill levels = 1 player level = 1 ability
point. Stage One typically banks the first point — **Field Strip** (75 % field yield) is the
natural pick for a scrap-everything opening; **Long Reach** (+1 block) or **Strong Kick** (+10 %
swim) are the alternatives.

**Open questions**

- [x] **S1-25.** Should the very first ability point come early (e.g. at 3 skill levels) so the tech tree is discovered inside Stage One?
    **A:** Don't bend the ÷5 rule (CC-18 canon). At 8 px cells, Building pays 1 XP per placed cell (4× the old wall), felling trees pays Scrapping, and swimming ticks — the first point lands inside the roof hours anyway. Measure in the feel-check before touching `SKILL_LEVELS_PER_PLAYER_LEVEL`.
- [x] **S1-26.** What visible feedback (skill-up toast, faster scrap animation) makes learn-by-doing legible before the numbers matter?
    **A:** Reuse the HUD gain feed for a **skill-up toast** (skill icon + "Scrapping 2") and add an "ability point available" badge on the Skills tab. No animation-speed changes — scrap speed is a tool/ability stat.
- [x] **S1-27.** Is there room for a fourth MVP skill (Combat, Diving, Engineering) or does three keep player level ÷ 5 honest?
    **A:** No fourth skill in the MVP; three keeps ÷5 honest and the tree is built as 3×3. Engineering is the post-Steam candidate (S5-26); Combat and Diving (S2-27, S3-26) are answered "no" here for consistency.

## Exit gate — what pushes the player down

Capability, not quest (GL-01): a **Dive Station** and a `tank_scrap` (4 scrap + 1 plastic,
+30 s → 60 s of air) turn peeks into dives. Pull factors: dry loot is gone, the Forge needs stone
that only the Shallows have, and the map shows most of the city is below the line.

**Open questions**

- [x] **S1-28.** What is the *emotional* exit of Stage One — a lit room glimpsed two floors under, a ladder vanishing into black water — and can gen guarantee it near spawn?
    **A:** Gen already produces it in every surface tower: the **dry cap** — a wood barrier at the dry line with the drowned tower beneath. Breaking one cell of it shows black water sitting under your floor (the sim never pushes uphill, so nothing rises). "The floor under your floor is the sea" is the exit image; the decayed ladder run vanishing into the flooded stairwell is its companion.
- [x] **S1-29.** Should the scrap tank be craftable at the Workbench so the exit is purely material, or does the Dive Station requirement usefully teach stations?
    **A:** Keep the Dive Station requirement. It teaches stations before Stage 2 needs the pump, and its cost is the material exit anyway. Matches Stage 2's entry state.
- [x] **S1-30.** What should a player who never dives still be able to do for hours — is a surface-only playstyle worth supporting at all?
    **A:** Supported as a *style* (farm, build, cull floaters — the renewables make it indefinite) but not as *progression*: no surface iron, ever (GL-28). Build nothing for it; just ensure the roof loop never requires a dive.

## Tuning knobs

`BASE_OXYGEN_SECONDS` 30 · `DROWNING_SECONDS_TO_DEATH` 10 · `FIELD_SCRAP_YIELD` 0.5 ·
`WEIGHT_SWIM_REFERENCE` 60 · `DAY_LENGTH_SECONDS` 600 · `RED_MOON_MIN/MAX_DAYS` 5/10 ·
`RED_MOON_BASE_WAVE` 3 · `AGGRO_NIGHT_MULT` 1.5 · `NIGHT_FLOATER_MAX` 5 · `STRUCTURE_TIER`
(wood/plastic 1) · `SCRAP_SPEED_MULT` 2.0 (testing boost — revisit in the balance pass).

**Open questions**

- [x] **S1-31.** Which knobs would a "gentler first hour" world toggle (CC-20) touch — oxygen, red-moon start day, walker HP — and which must never move?
    **A:** No toggles in the MVP (CC-20). When world-creation toggles come: red-moon start day, enemy strength, backpack rules (CC-20's list), plus night-floater ramp. Never movable: oxygen, `STRUCTURE_TIER`, GL-28 depletion, the water sim.
- [~] **S1-32.** Is a 10-minute day right for a surface stage where night matters, or should days feel longer above water than the underwater play implies?
    **A:** Deferred to the GL-27 pacing feel-check. Day length now anchors the farm (two dawns = 20 min per tree) and the red-moon window (50–100 min); lengthening days slows wood. Keep 600 s until measured.

## Design references

GL-01/02/03/04/07/14/15/21/22/23 · CC-07/08/11/15/18/22 · WS-04/07/08/12/14/15/17/20/24 ·
GD-01/04/05/06/21/22/24/29 · LT-27/30 · CT-02/03/09/11/17/20/23.

## Open / feel-check notes

- **GL-27 pacing feel-check is still open** — ~10 h for this stage is the target, unmeasured.
- Onboarding is deferred to early access (CC-24); the roof's trees, gear and sealed hatch *are*
  the tutorial for now. Watch whether players discover fell → tripod → hatch unprompted.
- First red moon at 50–100 minutes assumes 10-minute days; if days lengthen, revisit.

**Open questions**

- [x] **S1-33.** What single metric (time to first tank, deaths before first dive, red moons survived) best tells us Stage One is ~10 h and fun?
    **A:** Primary: **time to first `tank_scrap`** (the capability exit), with time-to-hatch-open as the sub-milestone; target ~10 h. Secondary fun signal: deaths before the first dive (< 3). Log both to the F3 stats and the run summary (S5-27).
- [x] **S1-34.** Which parts of the medical room should be unscrappable so a new player can't strip their own bed and lose spawn?
    **A:** Nothing needs protecting: spawn is the roof cell, not a bed, and `roof_hatch`/trees are already fixed/harvest-only. Rule: picking up your own bed reverts spawn to the roof (verify the fallback in `Player` — S1-54).

## Transition — Stage One → Stage Two

The first real dive should feel **earned and chosen**, not stumbled into: the base is walled,
the tools are made, the Dry has given all it usefully has, and the player *decides* to go
under. Since stages are emergent (GL-01), this boundary is a capability checklist, not a
gate — the questions below are about making that checklist legible and worth completing.

Expected state at the boundary: Workbench + Dive Station built; `tank_scrap` (60 s of air);
bed, chest, lamp, and a door behind player-placed walls; all three scrap tools plus a melee
weapon; a first ability point spent; and enough banked wood/scrap/cloth to lose a backpack
without losing the run.

**Open questions**

- [x] **S1-43.** Which parts of that checklist should be *materially required* (the tank is; is anything else?) versus merely wise — and does anything currently force a base to exist at all before diving?
    **A:** Only the tank (hence Dive Station + Workbench) is material; the hatch needs tripod or pry bar. Nothing forces a base (GL-14 emergent) and nothing should — the bed is the one "wise" item that changes the cost of failure.
- [x] **S1-44.** What technologies should count as mandatory unlocks before Stage Two — is a Med Station pre-dive wise (bleeding on long swims), or is Dive Station + tank the honest minimum?
    **A:** Workbench + Dive Station + `tank_scrap` is the honest minimum. Med Station is wise, not required: bandages are Workbench recipes (2 cloth), so bleeding has a Stage 1 answer.
- [x] **S1-45.** What does a healthy Stage Two starting stockpile look like in numbers (wood, scrap, cloth, bandages, glowsticks, ladders) — and should the game surface that readiness anywhere (the Dive Station UI, a bed tooltip)?
    **A:** Target stockpile (balance-pass numbers): ~100 wood, 30 scrap, 20 cloth, 20 plastic, 10 bandages, 6 glowsticks, 24 ladder, 16 rope, one mature tree standing and two seeded planters. Surface it nowhere new (GL-01) — the Dive Station's greyed recipes are the list.
- [x] **S1-46.** What skill/ability state should the transition assume — first ability point spent, Scrapping approaching 2 — and does Stage Two's balance hold if a player arrives with none of it?
    **A:** Assume first point spent (Field Strip or Strong Kick), Scrapping ~3–4, Swimming ~2. Stage 2 holds with none of it: Shallows tables carry no harvest-gated material (the first gate is iron → Scrapping 2 in the Cold), so a zero-skill diver is slower, not stonewalled.
- [x] **S1-47.** Should the first real dive be *marked* at all — a log line, a music shift, the character audibly steadying their breath — or does ceremony fight the emergent-stages rule (GL-01)?
    **A:** Music only — the depth-adaptive underwater layer marks the first dive and every dive after, which keeps it diegetic and non-ceremonial (GL-01). No log line, no VO.
- [x] **S1-48.** What makes a player linger in Stage One past the point of fun (loot-table dregs, red-moon anxiety, hoarding) — and what nudge short of a quest re-aims them at the water?
    **A:** The nudges are systemic and sufficient: one-time dry loot (LT-27), stone-only Forge, a map that's 90 % below the line. Add only a `desc` on the Forge recipe ("stone — found below the waterline"). No quest.
- [x] **S1-49.** What keeps Stage One spaces *relevant* after the transition — the dry base as red-moon shelter, roof trees as the wood farm, the surface as the fast lateral highway — so early investment compounds instead of expiring?
    **A:** The roof stays the **wood farm** (only open-sky trees reach 5×15), the stage-1 scrap bench and planters keep it a working floor, and the surface is the lateral highway. Roof bases are also walker-proof by GD-04 — see S1-51 for whether that's too strong.
- [x] **S1-50.** If a player dives the moment they own a tank (no base, no bed moved, day 2), what actually breaks — and is that speedrun line a style we support or a trap we soften?
    **A:** Supported, not softened. What breaks is only the death cost — roof respawn, bag pinned under the line — and it's recoverable (GL-29): 60 s of air from the roof reaches a Shallows ceiling. Verify in the M6 integrity pass that a tank-only, bed-less run can always recover its bag.

## New topics surfaced (review 2026-09-05)

- [ ] **S1-51.** Roof bases are red-moon-proof by construction (GD-04 no climbing, fixed hatch, 5–10-cell gaps walkers can't cross) — should waves spawn on the player's own crown / top floors, or floaters join waves, or is a wave-safe roof intended?
- [ ] **S1-52.** The metal-free canon vs data: `wood_axe` costs 1 scrap and the tripod needs 4 rope = 8 cloth; roof gear yields neither cloth nor guaranteed scrap. Is the spawn roof guaranteed a scrap piece and a cloth source (night floaters only?), or should the axe be pure wood and rope have a plant-fibre recipe?
- [ ] **S1-53.** Roof templates are one `roof` zone today; per-district roof signatures (S1-01/17) need a district filter on roof stamping.
- [ ] **S1-54.** Does picking up your own bed revert spawn to the roof, and what if the roof cell is later blocked by player blocks?
- [ ] **S1-55.** Should tree seeds appear in any dry loot table (rooftop planters, debris rafts) so a player who fells every roof tree before learning about seeds isn't stuck without wood?

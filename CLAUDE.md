# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

**SunkenCity** (working title; repo: wilbur6689/SunkenCity; formerly TowerDive) is
a **Godot 4.8** 2D side-scrolling block-based survival sandbox (Terraria × 7 Days to Die): a
procedurally generated city deliberately flooded to contain a zombie virus, where the player dives
progressively deeper through submerged skyscrapers. Roadmap: MVP local single-player → LAN
multiplayer (networked architecture from day one) → Steam demo → full commercial release.
The "Key Decisions (Design Canon)" section of `docs/GameOverview.md` records settled design
decisions — treat them as canon. Standing MVP priority: the core loop (harvest → craft → build
base) comes first; do not add other major aspects before it works.

Development has completed **M0–M5** (next: M6 — Release Readiness: integrity/perf/LAN passes;
**The Drain endgame is deferred to post-Steam-release** — story canon, not MVP scope; still open:
the manual pacing feel-check GL-27 and an M4 balance/feel pass). M4 highlights: data-driven enemies
(`data/enemies.json` per-band stat tables; walker/crawler/floater/Drowned/shark + fish schools)
seeded at gen by `EnemyGen` and streamed as records like objects (`World.enemy_records`,
cleared-stays-cleared, saved); shared proximity aggro (`scripts/enemies/aggro.gd`, night radii);
combat through the interaction layer — melee (knives least water-slowed), hitscan firearms
(dead submerged), speargun with retrievable bolts, ammo recipes; bleeding + bandage/medkit +
out-of-combat regen; the death-loop backpack (bag transfers, floats/ceiling-pins, recover on
touch, gear stays worn); red moons on a 5–10 day clock (tint + waves converging on players,
scaling by day, pounding player-placed blocks only, stragglers persist). Gate:
`m4_smoke.tscn`. M5 highlights: gear modifiers (`data/modifiers.json`, per-instance
`mods` on stack dicts, rolled on found loot, rarity-colored titles), the **Modification
Bench** Modify tab (sacrifice-to-learn / apply-to-clean), the **ability tech tree**
(`data/abilities.json`, 3 branches × 3 tiers on the Skills tab; unlocks the two reserved
accessory slots), found-only firearms data items, paper-doll gear (suit tints + held tool),
harvest gates by material tier (iron → Scrapping 2, steel → 3), and verified depletion
pressure (surface iron can't cover the gear chain). The main scene is now
`scenes/ui/title.tscn` — the world picker ↔ character picker (CC-09; separate world/character
saves under `user://saves/`, written by `scripts/data/save_game.gd`; **F5** saves, **F9**
reloads in-game; **Esc** opens the pause menu (`scripts/ui/pause_menu.gd`: Resume,
Music/SFX/Ambient sliders persisted to `user://settings.cfg` via the `Audio` autoload, Save &
Quit to the title — quit from there); dev runs passing
`--seed`/`--shot` skip the title; gate: `title_smoke.tscn`). The game scene is
`scenes/city/city.tscn` — a seeded 2400×400 drowned city (`CityGen`, ~1.5 s, deterministic;
`--seed=N`, `--shot=path[:zoom]` — shots need a window, not --headless) with mega-pump station
shells, surface debris rafts, invisible edge walls (player x-clamp), a WS-04 two-jump repair
pass, and a top-right minimap fed by per-character `MapReveal` (proximity r=14); **M** opens the
full-screen map (`scripts/ui/map_view.gd`: drag pans, wheel zooms on the mouse, built once
then kept fresh from `MapReveal.dirty` + a repaint window; colors shared with the minimap
via `MapColors`). **Interior pockets** (2026-09-01): ~30 % of floors carry an
**apartment doorway** (one per floor, random wing; a 3–4-floor countdown was tried and reverted —
rolls play better; kind `portal`, fixed, no item form) on the back wall beside the stairwell — wood `room_door` through The Shallows (40 % found
open, 20 % deadbolted `room_door_locked` — pry bar), chained `room_door_metal` below (bolt
cutters); one click opens a closed one, the next steps through
to a **room of its own** — carved by `CityGen._carve_pocket` in a **VOID annex** east of the city
(`WorldGrid.M.VOID` = atlas row 7, solid black, unbreakable, opaque to sight; `ANNEX_GAP` of open
air keeps the cliff off-screen, `POCKET_VIEW_MARGIN` of blackness on both lane ends) on the
**same rows as the doorway** (depth/band/loot stay true), stone shell + metal slabs + back walls,
one zone template stamped inside, the matching doorway at its west end linking back (records carry
`link` = the twin's cell + a shared `open`; `World.portal_target`, `Player.travel_to`). 40 % of
submerged pockets stay sealed dry, the rest drown (`pockets[].flooded`, seeded after the
connectivity flood);
`World.city_bounds` is the city proper (maps, edge clamp, wave spawns never enter the annex),
`World.pockets` + `map_cell_for` anchor the minimap/map on the doorway while inside. Gate:
`pocket_smoke.tscn`; dev arg `--at=col,row` teleports before a `--shot`. Towers are
**double-wide twin-wing blocks** (2026-08-31): ladder stairwells on BOTH sides (ladders hug the
room-side wall — 2026-09-01, so enemies chase through wing doorways onto them), an elevator
shaft down the centre, rooms in each wing; the skyline is uniformly high-rise (CT-01 amended
2026-09-01: central 80 % of the map rolls a 50-floor base ±, only the edge fifth tapers under a
30-floor base); submerged ladder runs decay into gaps with
`broken_ladder` scrap pieces — scrap for wood, craft + place ladders to climb back up;
objects stream via `World.object_records` (only the `OBJECT_WINDOW` around the player is
instantiated; queries read records, so far doors still seal water); **F3** toggles the debug
overlay (build, depth, per-system costs, current music track) beside the always-on FPS counter; the hotbar sits
bottom-centre;
room templates live in `data/rooms.json` —
authored visually in the **Room Editor** (`godot --path . res://scenes/tools/room_editor.tscn`:
settings incl. zone + depth range — zones: residential / business / commercial / industrial / civil
(2026-09-01; "Load existing" lists only the selected zone) — block painting, zone-filtered
furniture placed at any height —
`dy` rows above the standing row, honoured by `CityGen`; **Esc** opens the shared pause menu with
editor controls + QUIT TO TITLE, same in the Furniture Editor) or bulk-generated by
`tools/gen_rooms.py`; the generator selects by zone and filters by each room's depth range. The
**Furniture Editor** (`res://scenes/tools/furniture_editor.tscn`) authors `data/objects.json`
entries + their sprite PNGs (pixel canvas with TileArt ramps, zone tags, yields table); bulk sets are
**room-pack modules** in `tools/rooms_pack/*.py` (PIL draw functions + `ITEMS`), validated with
`python tools/rooms_pack/render_check.py <module>` and integrated by `python tools/build_room_packs.py`
(packs `assets/sprites/sets/<module>.png`, merges into `objects.json`); `docs/RoomInventory.md` lists
every room's objects and the 2026-09-01 additions. Room-template variants are authored as
`tools/room_variants/<room>.json` files, checked with `python tools/check_room_variants.py <file>`
(placement rules: bounds, overlaps, wall art hangs, elevated clutter needs support, ≤90 % floor) and
merged with `python tools/merge_room_variants.py` (re-runs replace same ids). The water sim is
`scripts/world/water_sim.gd` (8-level cells, awake-set dormancy — see `WaterPhysics.md` "M2
Implementation Decisions"); lighting is `scripts/world/light_map.gd` (0–15 tile light, sun +
BFS point sources) with **fog of war inside buildings only** (back-wall cells, WS-20): raycast
line of sight (floors/walls occlude) + min(light, sight falloff), drawn by `LightRenderer`;
exteriors are always revealed; player-placed lights and dropped glowsticks are **fog beacons**
(`World.light_beacons`): their surroundings stay revealed with no player line of sight;
breaker objects power wired lights and trip when flooded. `World` owns and ticks water, light,
pumps, and power. The task tracker is `docs/MVP-checklist.md` — check items off as they land.

## Running the Project

- Engine: `C:\Programming\Godot_v4.8\Godot_v4.8-dev2_win64.exe`
- Run the game: `& "C:\Programming\Godot_v4.8\Godot_v4.8-dev2_win64.exe" --path . `
- Open the editor: add `-e`
- Headless validation (use after editing scenes/scripts): `--headless --import` to check assets
  parse; `--headless --quit-after 10` to boot the main scene and surface script errors.
- Gate tests (exit 0 = all checks pass): `--headless res://scenes/test/m0_smoke.tscn` (movement,
  drives the player with `Input.action_press`) and `--headless res://scenes/test/m1_smoke.tscn`
  (the loop; feeds the player's input snapshot directly with `set_multiplayer_authority(2)`). Run
  both after touching the player, World, or data files; extend them when behaviour changes.
  Further gates: `m2/m3/m4/m5/tower/save/pocket/room_editor/furniture_editor_smoke.tscn` — `save_smoke`
  covers the full persistence round trip; run it after touching World state or SaveGame.
  `m4_smoke` covers enemies/combat/death loop/red moons; run it after touching enemies, combat,
  or the interaction layer.
- Skyline shape report: `--headless res://scenes/test/_height_report.tscn` — 10 seeds, floor
  counts of the central 80% vs the edge 20% vs the crown (dev analysis, not a gate).
- Regenerate placeholder art: `python tools/gen_placeholder_art.py` (tiles, character, item icons,
  object sprites, enemy sprites, light texture — deterministic).
- Convert music drops: `python tools/convert_music.py` (WAVs from `docs/Examples/Audio/music`
  → `assets/audio/music/*.ogg`, needs ffmpeg; new tracks also go into `MUSIC_POOLS` in
  `scripts/audio/audio_manager.gd`).

## Code Conventions

- **All design units are blocks** — `Constants.BLOCK_SIZE = 16` px; speeds in blocks/sec. Every
  tuning value lives in `scripts/constants.gd` (autoloaded as `Constants`), never inline.
- Player logic (`scripts/player/player.gd`) keeps an **input-snapshot → state-machine
  separation** so a networked client can later feed the same input fields (LAN-readiness rule).
  Input is read only when `is_multiplayer_authority()`.
- **World queries go through the `World` autoload** (`scripts/world/world.gd`) — `is_solid`,
  `is_water`, `is_climbable`, `water_surface_y`, `surface_has_air`, `rect_is_clear`. Gameplay code
  never touches `TileMapLayer`s directly; M2's water sim replaces World's storage, not its callers.
- Placeholder atlas `assets/tiles/placeholder_blocks.png`: columns = 5 shades, rows = stone, wood,
  metal, plastic, water, ladder, rope (rows 4–6 have no collision).
- Recipes, items, loot tables, and enemy stats must be **data files**, not code (per LT-11):
  `data/items.json`, `data/blocks.json`, `data/objects.json`, `data/recipes.json`, loaded and
  validated by the `Data` autoload (`scripts/data/data.gd`). A block or object id is also an item
  id. Adding content = adding a JSON entry (+ a sprite for objects).
- UI: the character menu (`scripts/ui/inventory_ui.gd`) is an in-game popup window (styled after
  `docs/Examples/UI Menus`, textures generated into `assets/ui/`) with Inventory / Crafting /
  Chest tabs sharing the wood-framed bag grid; `UITheme` (`scripts/ui/ui_theme.gd`) is the
  stylebox factory. Preview any screen without input:
  `godot --path . res://scenes/test/menu_preview.tscn -- --screen=inventory|crafting|chest|skills|modify|world`.
- Backgrounds: user art in `docs/Examples/Backgrounds` (City plates + Building seam covers) is
  downscaled by the art tool into `assets/backgrounds/` and assembled by
  `scripts/world/backdrop.gd` (Parallax2D) hanging from the waterline.
- Interaction model (`scripts/player/interaction.gd`): LMB on a highlighted interactable —
  short click interacts (open storage/doors, flip breakers, bed spawn, station crafting, pump
  targeting), holding ~0.5s picks the object up (storage must be empty); otherwise LMB uses the
  held item — place block/object, hammer hits, consumables, pump-outlet click. RMB =
  hold-to-scrap furniture, place back walls, hammer wall removal. E remains a legacy interact. **Q** toggles bare hands (clears the held item until pressed again
or a hotbar slot is reselected; it no longer drops). Hold-RMB on a bag slot scraps that item
(field yield away from stations; quick tap still takes half). Hammer hits play a swing arc +
impact SFX (`Audio.play_sfx`). Grayed crafting recipes stay clickable to inspect (with `desc`
lines from the data files); only CRAFT is gated. `World.placed_blocks` tracks player blocks (their own HP/hardness); structure
  blocks are ALSO breakable (GL-01 re-amended 2026-08-31) under
  `Constants.STRUCTURE_TIER/HP/DROP` — wood/plastic need tool tier 1, stone 2, metal 3.
- Main scene is currently `scenes/test/test_tower.tscn` — a 15-floor test tower (3 dry, 12
  flooded; themed deep floors, stairwell, sealed door-floods). Rows 0-30 are load-bearing for
  the smoke tests — extend downward, do not reshape them. Gate tests: `m0/m1/m2/tower_smoke.tscn`.

## Fixed Design Constants

These are settled and should be treated as canon in all docs and future code:

- Block size: **16×16 pixels**, representing **2 feet** in-game
- Character: 32px sprite art at 1× (~30px tall; a 1.5× rescale was tried and reverted for feel —
  see the WS-05 note in OpenQuestions.md). Hitbox 12×22 standing, 12×12 compact
- Character is roughly **2.5–3 blocks tall**

## Document Structure & Workflow

- `docs/GameOverview.md` — the source of truth for the game design. High-level only.
- `docs/OpenQuestions.md` — 180 open design questions (30 per overview section), each with a
  stable ID (`CC-`, `WS-`, `GL-`, `GD-`, `LT-`, `CT-` + number) and a checkbox.
  Workflow: answer questions in review sessions, record decisions on an indented `**A:**` line
  under the question, mark `[x]` answered or `[~]` deferred. Fold completed sections' decisions
  back into `GameOverview.md` and into deeper docs under `docs/technical/`.
- `docs/technical/` — in-depth technical design docs, added as design areas get resolved.
  `GameOverview.md`'s "Document Map" section lists the planned topics. First doc:
  `WaterPhysics.md` (cellular tile water, pumps, endgame drain).

When answering design questions, questions cross-reference each other by ID (e.g. GD-19 defers to
GL-12) — check whether a referenced question was already decided before asking again.

## Project Skills (`.claude/skills/`)

- **guided-review** — collaborative one-question-at-a-time design review with countdown numbering
  (`Q{N}` down to `Q1`), 2–4 numbered options per question, recommendation first and set apart by
  a rule, document updated only at section end after a confirmed summary. The user may not have
  slash-command access to it; when they ask to review design questions, follow its process
  directly against `docs/OpenQuestions.md`.
- **guided-testing** — manual one-test-at-a-time QA sessions maintaining a living
  `FUNCTIONAL_TEST_REPORT.md`. Relevant only once the game is runnable.
- **GameAudioPrinciples** — reference tables for game audio design (categories, mixing, adaptive
  music). Its frontmatter contains unrelated boilerplate (`risk: offensive`, security-use warning)
  left over from a template; the content is ordinary game-audio guidance.

## Conventions

- Docs are Markdown; keep the existing section structure and ID schemes stable — other documents
  and future sessions reference them.
- Keep the "Running the Project" commands and engine architecture notes above current as the
  project grows.

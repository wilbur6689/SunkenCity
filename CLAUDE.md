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
Music/SFX/Ambient sliders persisted to `user://settings.cfg` via the `Audio` autoload, a
**UI Size** slider (2026-09-02) under DISPLAY, Save &
Quit to the title — quit from there); dev runs passing
`--seed`/`--shot` skip the title; gate: `title_smoke.tscn`). The game scene is
`scenes/city/city.tscn` — a seeded 4800×800-cell drowned city (8 px cells; `CityGen`, ~2.5 s, deterministic;
`--seed=N`, `--shot=path[:zoom]` — shots need a window, not --headless) with mega-pump station
shells, surface debris rafts, invisible edge walls (player x-clamp), a WS-04 two-jump repair
pass, and a top-right minimap fed by per-character `MapReveal` (proximity r=14 map cells; the map side works on 2×2 macro cells, `Constants.MAP_CELL`); **M** opens the
full-screen map (`scripts/ui/map_view.gd`: drag pans, wheel zooms on the mouse, built once
then kept fresh from `MapReveal.dirty` + a repaint window; colors shared with the minimap
via `MapColors`). **Interior pockets** (2026-09-01; density raised to **50 %** 2026-09-02,
`POCKET_CHANCE`): floors carry an
**apartment doorway** (one per floor, random wing; a 3–4-floor countdown was tried and reverted —
rolls play better; kind `portal`, fixed, no item form) on the back wall beside the stairwell — wood `room_door` through The Shallows (40 % found
open, 20 % deadbolted `room_door_locked` — pry bar), chained `room_door_metal` below (bolt
cutters), and a dry-band **`room_door_barred`** (wood + metal bars, `POCKET_BUTTON_CHANCE` 30 %):
it can't be forced — a hidden `door_button` (kind `button`, wall-mounted, on a free wall cell amid
the room's clutter, its record's `door` = the door cell) is pressed to release it
(`World.release_barred_door`), so the player searches/clears the room for the switch. One click
opens a closed one, the next steps through
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
`pocket_smoke.tscn`; dev arg `--at=col,row` teleports before a `--shot`. **Roofs**
(2026-09-01): every tower top is a `roof` zone — `CityGen._stamp_roofs` stamps roof room
templates across both wings (elevator-shaft mouth stays open sky; wall-mounted pieces skipped),
depth-filtered like interiors: rooftop gear from `tools/rooms_pack/roof_gear.py` (HVAC, cooling
towers, fans/ducts/stacks/pipes, antenna arrays, comm masts, dishes, cabinets, transformers,
switchgear, cable trays, generators, helipads, cranes, davit arms, window-washing rigs, anchors,
illuminated/logo signs, crowns, lightning rods — scrap metal/plastic/stone, NO iron: GL-28
surface-depletion holds) and **trees in three growth stages** on dry roofs only (`tree_sapling` ->
`tree_young` -> `tree_mature` 5x15, ~2.5 rooms tall; each midnight `World._grow_trees()` rolls the
def's `grow_chance` and swaps the record for `grows_into` — drowned or hemmed-in trees wait;
saplings keep an item form so cut groves replant; grown trees are harvest-only wood). **The run
starts dropped off on the centre cluster's roof** (2026-09-02: spawn is **decoupled from the
medical room** — the authored medical room still exists, now placed in a tower NEIGHBOURING the
drop-off as an early discoverable with starting supplies; spawn is the top of the centre-most
spawn-cluster tower, `gen.spawn_tower`, and respawn returns there until the player crafts a bed)
and the early game is roof-locked: every dry crown's
shaft mouth is sealed by `roof_hatch` (fixed, no-item, `lock_tier` 1 door) — roam roofs, harvest
trees, and craft the **`wood_tripod`** (30 wood + 4 rope, hand; a `pry` tier-1 tool — the intended
**metal-free** opener) to lever the hatch into the top floors (a scrap `pry_bar` also works).
**Stage-resource design canon** (2026-09-02, GameOverview "Main Game Loop"): each stage centres on
one resource to master — Stage 1 = **wood** (farm it, and the wood-and-rope tripod is the *key*
down to metal), then scrap/stone → iron → steel → mastery down the bands. Interior rooms sprinkle zone-tagged details via `CityGen._zone_details`: `wall_detail`
pieces (broken-wall decals — kind `decal`, hammer clears, no yields, from
`tools/rooms_pack/interior_details.py`; vents/duct/pipe runs -> scrap metal, mostly
commercial/industrial) and rare `statement` statues (-> stone, residential/commercial/civil);
plants also pay out stone. Zones now include **roof** in both editors. Gate: `roof_smoke.tscn`.
Fixes: `_stamp_room` mirrored blocks no longer spill left of a cropped template (stomped pocket
doorways); `World.remove_object` falls back to identity search and `object_at` validates
instances (freed-node hover crash when overlapping objects were scrapped). **Roof-era economy +
flora tools** (2026-09-01, later same day): hand crafting is wood-tier only — axe (`wood_axe`,
the tree tool: `requires_tool: "axe"` on grown trees, felling time scales with size), wood
block/wall, chest, rope, ladder, and the workbench (now 30 wood + 15 scrap — a multi-run
project); scrap tools (pry bar/knife/hammer) plus glowstick/bandage/lamp moved behind the
workbench, and all tool recipe costs run **5x** (fire axe doubles as an axe tool). Wear-pass
side breaches are standardized 2x2 and sealed by `side_vent` grates (fixed, pry tier 1 — same
lock as the roof hatch, and they seal water); the central 20% of the map is the **spawn
cluster** (2026-09-02): all towers full height (56 floors), gaps of 1–3 blocks, and each tower
rides a 0–5 row stone plinth (**crown lift**) picked so neighbouring roofs differ by 2–5
blocks — a varied but hoppable skyline for the roof-locked early game
(`scenes/test/_cluster_check.tscn` verifies it). The wood wall got its own dark vertical-plank tile
(atlas row 8, `WorldGrid.M.WOODWALL`; tres + `gen_placeholder_art.py` updated). The **Flora
Editor** (`res://scenes/tools/flora_editor.tscn`) authors category-`flora` objects (type, growth
chain `grows_into`/`grow_chance`, `flora_weight` spawn bias, no-item flag, up to 16x32-cell
canvas); `CityGen._stamp_roofs` sprinkles all roof-zone flora by weight, so a saved plant
appears in the next generated world; editor saves set `authored: true` - pack rebuilds keep
their hands off such entries, and `Data.object_texture` loads authored sprites RAW from disk
(the import cache is stale after an in-game save). Gate: `flora_editor_smoke.tscn`. **Room draw planes +
zombie sheets** (2026-09-01): rooms layer back wall (tile layer z -3) -> decals (z -2) ->
wall-mounted pieces/doorways (z -1) -> furniture (z 0) -> player (tree order); backdrop planes
sit at z -10/-11 in both game scenes. The hand-made monster sheets in `docs/Examples/Monsters`
are sliced by `python tools/convert_monsters.py` (chroma-key, label crop, feet-aligned 8-frame
strips) into `assets/sprites/enemies/walker*.png` (7 looks: 5 procedural recolour/bulge
variants incl. 2 fat) and rebuilds the **floater** as a prone bloated body wearing the real
walker head (2026-09-01); walkers animate via
`frames`/`sprite_variants` in `data/enemies.json` (variant picked deterministically per record;
`gen_placeholder_art.py` never overwrites hand-made strips). The **Monster Editor**
(`res://scenes/tools/monster_editor.tscn`) loads every enemy type (grouped by movement mode) and
edits `data/enemies.json` in place: identity/hitbox/flags/frames/variants, the drops table
(drop items validated against the item registry), and the authored per-band stat grid — enabling
a band row is what lets the type seed there (GD-23); an animated sprite preview cycles variants
with a hitbox overlay, arrow keys step frames, and **Edit frame…** opens an overlay pixel
window (frame-palette swatches, pick/paint/erase; BACK returns) - saving a frame writes the
strip and sets `authored_sprites`, which makes the game raw-load the strips and
`convert_monsters.py` keep its hands off. Gate: `monster_editor_smoke.tscn`. **Feel fixes**
(2026-09-01): water plunge drag (`WATER_PLUNGE_DECEL`) - players, items and enemies falling
into water brake within a couple of blocks of the surface instead of coasting to the bottom;
death now plays a 3 s scene (`DEATH_SCENE_SECONDS`: input frozen, HUD cleared, camera closes
to 2x, fade to black, respawn with a fade-in) - `player.dying` guards damage and the HUD. **Material icon surfacing** (2026-09-01): the
hover card shows scrap yields as an ICON row (icon + min-max) instead of text, and a left-side
**gain feed** (HUD) shows icon + running +count for every material gained from harvesting
(`player.notify_gain`, drained per frame). **Harvest drops pop out** (2026-09-02): scrapping a
world object no longer teleports yields into the bag — `interaction._pop_resource` bursts each
yield out as a few `WorldItem`s with an up-and-out velocity (split into ≤3 icons), plus a coloured
`World.spawn_break_puff` debris burst (CPUParticles2D, tinted by `HARVEST_TINT`); the drops
**hover/bob** in place (a sprite offset in `WorldItem`, pickup range unaffected) then, after
`HARVEST_DROP_DELAY`, a **gentle magnet** (`WorldItem.gentle`: eases toward the player at
`ITEM_MAGNET_GENTLE_SPEED`, softer than the mined-block snap) drifts them in to collect.
`notify_gain` now fires on the `WorldItem` pickup. (Bag/station item scrapping — `player.scrap_item` — still credits the bag
directly; only in-world object harvesting pops out.) The **Icon Editor**
(`res://scenes/tools/icon_editor.tscn`) repaints material icons: saves
`assets/sprites/icons/<id>.png` + `authored_icon` in data/items.json; `Data.icon` raw-loads
authored icons. Gate: `icon_editor_smoke.tscn`. **Urban zombie pack** (2026-09-01):
`docs/Examples/Monsters/urban-zombie-sprite-sheet-pixel-art-pack` (4 zombies x 5 clips, real
alpha) converts to square-cell strips `walker_h..k` + `_idle/_attack/_hurt/_dead` companions
(one shared scale per zombie; walker now has 11 looks). Enemies play the clips: idle sway,
attack one-shot on a landed bite, hurt flinch, and a lingering fading corpse on death; frame
counts derive from square cells (width/height), legacy strips fall back to `frames`. All pixel editors gained **Select / Copy / Cut /
Paste** (marquee drag; ghost-follow paste stamps repeatedly - patterns and moving sections);
the Icon Editor covers EVERY icon-bearing item (materials, tools, weapons, armor, ammo),
grouped by category. Side vents gate only Shallows-band breaches - deeper breaches are the
flood inlets (vent-sealing everything left tower interiors dry: a 50-block air fall). **Water
level pass** (2026-09-02): the exterior `WATERLINE` was raised to row **52** (was 64) so the
open water between towers sits ~2 floors below the crowns — a fall off a roof is a short,
swimmable drop instead of an unrecoverable one. Each surface tower (crown above water) also
keeps a **randomized 4-8 dry floors at the top**, independent of the exterior level: a
watertight **wood barrier** (`WorldGrid.M.WOOD`, tier-1 breakable) caps the interior at the dry
line, wear-pass breaches are skipped above it, and the connectivity flood fills only below —
so the pocket stays dry even where it dips under the raised waterline. The capped-below-the-sea
water column is stable (the sim never pushes water uphill, so it sleeps immediately — verified
awake=0 after 500 ticks). Effective dry-floor range is ~5-8 (the crown already gives ~5 above
water). The user's icon sheet
(`docs/Examples/Objects/resources.jpg`, 2 groups x ~120 icons) slices via
`python tools/convert_icons.py` (white-key, band detection, 32x32 NEAREST - user request: keep the sheet's detail): 31 item icons
mapped into `assets/sprites/icons/` (materials, meds, ammo, tools, gear, weapons, schematics,
rope), the rest parked in `icons/extra/` for future items; a file in the icons dir is
authoritative for `Data.icon` (no flag needed - covers block-backed items). `convert_icons.py` **never overwrites an
existing icon** (protects Icon-Editor hand edits; `ICONS_FORCE=1` regenerates) and border-floods
white removal + trims the JPEG halo so no white edges survive. `Weapons.jpg` swords + SMG
(`convert_weapons`) replace scrap_sword/iron_sword/smg; machete, longsword, combat knife and
bone scimitar park in icons/extra. Towers are
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
settings incl. zone + depth range — zones: residential / business / commercial / industrial / civil / roof
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
  Further gates: `m2/m3/m4/m5/tower/save/pocket/roof/room_editor/furniture_editor/flora_editor/monster_editor/icon_editor_smoke.tscn` — `save_smoke`
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
  **Harvest hover** (2026-09-02): the glow (`self_modulate`) only lights an object the player can
  actually harvest *now* — `Interaction.can_harvest` mirrors the `_scrap` gate (held tool tier +
  Scrapping skill vs the object's `tool_tier`/`skill`), refreshed each frame so switching to the
  right tool lights it; the info card still shows for gated objects so its **tier badge** (a
  colour-coded shield in `hud.gd _TierBadge`: grey 0 / green 1 / blue 2 / orange 3, on `kind:scrap`
  objects) explains the gate. The **axe** counts as bare hands when dismantling anything that
  doesn't `requires_tool:"axe"` (it's a tree tool only).
- **Tiered scrap benches** (2026-09-02): five stations that **bulk-grind collected furniture down
  to materials by stage** — `wood`/`metal`/`iron`/`steel`/`master_scrap_bench` (kind `scrapper`,
  `scrap_stage` 1–5). Interact (`world_object` "scrapper" → `Player.bulk_scrap(stage)`) melts every
  bag item that is a `placeable_object` of object-kind `scrap` (plain furniture only — never tools,
  gear, materials, or chests/beds/lamps/stations you carry) whose `Data.item_scrap_stage` matches
  the bench, full yield. An item's stage = the highest material tier it scraps into
  (`Data.MATERIAL_STAGE`: wood/plastic/cloth 1 · scrap_metal/stone 2 · iron 3 · steel 4); the
  **Master bench (stage 5)** takes any tier. Each bench is crafted at that tier's station from that
  tier's material (wood→forge chain). Sprites: tier-tinted grinder in `_draw_object`.
- **Canvas 1920x1080** (2026-09-04, Phase 0 of the half-size-block plan in
  `~/.claude/plans/i-know-we-have-linked-quill.md`): `project.godot` viewport is 1920x1080;
  `UIScale.BASE_SCALE = 1.5` multiplies into `content_scale_factor` so the UI (still laid out in
  1280x720 / 640x360 design frames) keeps its on-screen size, and `Player._apply_zoom` divides by
  `UIScale.content_scale()` (base x slider). `CAMERA_ZOOM_LEVELS` are x1.5 (`[1.5 .. 9.0]`, default
  3.0 = the old 2.0 framing, 640x360 world px on screen). Screenshots before/after are
  pixel-identical. NB: in `canvas_items` stretch the engine renders at the WINDOW resolution
  regardless of the logical canvas, so world crispness is set by tile texel density x zoom, not by
  the viewport size.
- **Half-size blocks, Phase 1** (2026-09-04, plan `~/.claude/plans/i-know-we-have-linked-quill.md`):
  `Constants.BLOCK_SIZE = 8`; every block-count constant doubled, raw-pixel constants
  (hitboxes, `FEET_Y`, item rest offsets) untouched; per-cell rates re-expressed
  (`STRUCTURE_HP` ÷4 per cell, `LightMap.MAX_LIGHT` 30 with unchanged per-cell costs, light seeds
  ×2, `OBSTACLE_SIGHT_TRANSMISSION` √, `WATER_BUDGET_PER_TICK` ×4, `PUMP_UNITS_PER_TICK` 8). World
  tiles: `tools/gen_tiles_24.py` → `placeholder_blocks_24.png/.tres` (24 px tiles, physics ±12)
  drawn at `TILE_ART_SCALE = 8/24`; the 16 px `placeholder_blocks.png` is now only the block ICON
  sheet — icon slicing uses `Data.ICON_PX = 16`, never `BLOCK_SIZE` (items.png, held tools, dropped
  items, ghosts). Fog of war samples a 2×2 macro grid (`LightRenderer.FOG_CELL`), the sight
  raycast steps `World.SIGHT_RAY_STEP_PX` (6.4 px). `World.climbable_center_x` centres on a
  contiguous ladder run (generated ladders are 2 cells wide). Data migrated once by
  `python tools/migrate_half_blocks.py` (idempotent `cell_px: 8` marker): objects.json `size`/
  `radius_blocks` ×2 (sprites/`rect` unchanged: sprite px = size × 8), rooms.json + variant packs
  upscaled (blocks → 2×2 groups, `dy`/`x`/depth ×2), enemies.json `speed`/`aggro`/spacings ×2
  (`size` is px, unchanged), items.json `weapon.knockback` ×2. `SaveGame.VERSION = 2`: v1 files are
  refused and the title greys them out as "(old format)". Test tower is 80 wide / 12-row floors
  (`SLAB_T`/`WALL_T` 2, `DOOR_H` 6, ladders 2 wide, crawl vent 2 rows), rows 0–60 load-bearing;
  `tower/m0/m1/m2/m4_smoke` converted (cells ×2, standing rows 2r+1, px tolerances unchanged,
  water units ×4, light levels ×2) and passing. NOT yet converted (Phases 2–3): `CityGen`/`EnemyGen`
  and their gates (`m3/m5/pocket/roof/save/_cluster_check`), the editors + Python room tools, map/
  minimap macro grid, balance, docs canon — the city scene does not play correctly until Phase 3.
- **Half-size blocks, Phase 2** (2026-09-04): tooling on the cell grid. `build_room_packs.py`
  keeps the pack modules' 16 px art contract (`ART_UNIT`) and writes `size` as cells
  (`CELLS_PER_UNIT = 2`); `render_check.py` caps stay in module blocks. `gen_rooms.py` lays rooms
  on the 2-cell macro grid (10-row height, widths 16-28, 2x2 shelf blocks — run it only to make a
  NEW library, it overwrites rooms.json); `check_room_variants.py` wants 16-28 x 10. Editors:
  Room Editor 24x10 default (12-40 x 8-16, `CELL` = 16 canvas px per 8 px cell, the old lattice
  drawn brighter); Furniture / Flora editors size in cells (defaults 4x4 / 4x6, max 8x8 / 16x32,
  canvas px = cells x `BLOCK_SIZE`); Icon Editor slices the sheet by `Data.ICON_PX`. All five
  editor smokes pass. `docs/RoomInventory.md` still lists the pre-2026-09-04 block sizes (no
  generator exists; regenerate by hand when the doc pass runs).
- **Half-size blocks, Phase 3** (2026-09-04): `CityGen` rewritten on named structural constants
  (cells): `SLAB_T 2`, `FLOOR_H 12` (= `SLAB_T` + `FLOOR_OPEN 10`), `WALL_T 2`, `OUTER_WALL_T 4`,
  `DOOR_H/W 6/2`, `LADDER_W 2`, `STAIR_W 6`, `SHAFT_W 6`, `BREACH 4`, `CRAWL_GAP 2`, `STAND_GAP 3`,
  `JUMP_CELLS 6`, `MIN_ROOM_W 16`, `POCKET_DOOR_INSET 4`; world 4800x800, `WATERLINE 104`,
  `GROUND 720`, tower widths 96-152, cluster gaps 2-6, crown lift 0-10 (steps 4-10), annex
  gap/width/margin 160/840/160, pockets 16-44 wide. Column plan per tower: outer wall x0..x0+3 |
  stair gap x0+4..x0+9 (ladder x0+8..x0+9) | stair wall x0+10..x0+11 | wing x0+12..mid-6 | shaft
  wall mid-5..mid-4 | shaft mid-3..mid+2 | mirrored east. Room stamping snaps furniture to the
  2-cell macro grid (`CityGen.M`); clutter/grass filters want 2x2; the roof hatch is 6x2 anchored
  on the lower slab row; broken-ladder pieces are 2x2, one per two gap rows; `enemy_gen` reads
  `CityGen.FLOOR_H`/`STAND_GAP`. Floor counts, chances and attempt counts are unchanged.
  `World.portal_target` lands the traveller centred on the 2-wide doorway (a body centred on the
  record's west cell overlapped the wall and got unstuck out of the room). Gates converted (cells
  x2, 1600-wide slices, water units x4, light x2, per-cell demolition HP) and passing: `m3`, `m5`,
  `pocket`, `roof`, `save`, `_cluster_check`.
- **Half-size blocks, Phases 4-5** (2026-09-04, overhaul complete): the map side (`MapReveal`,
  minimap, `map_view`, `MapColors`) works on `Constants.MAP_CELL` (2) macro cells via
  `World.map_macro_for` / `World.map_bounds`, so reveal radius, minimap window, map image and the
  character save's map bytes are what they were. Perf: `LightMap.compute_window` reads
  `grid.structure` / `water_sim.levels` directly with closed doors as a cell set and a cached
  per-column sky row (`World.sky_row`, invalidated by `_cell_changed` and door changes) - a full
  relight is ~37 ms (was 105 ms on the 4x window, ~40 ms on the old grid); the player's own glow
  source is quantized to the macro grid so relights fire per 16 px as before (a per-cell key
  relit every 8 px step: interior fps 38 -> 114). `CityGen.flood` is a scanline fill on the byte
  arrays (5.5 s -> 0.55 s; city load ~2.5 s). `--f3` + `--shot` prints the F3 overlay to stdout
  at shot time. Balance: ladder recipe yields 12 (was 3) and rope 16 (was 4) so a physical run
  costs what it did; block recipes are unchanged (mining a wall now pays 1 material per 8 px
  cell = 4x the old wall - the user's call, GL-28 iron pressure unaffected since structure never
  drops iron; retune the Stage 1-2 loops in play). Docs canon updated: GameOverview scale table,
  OpenQuestions WS-01/02/03/04/05/11/12/15/30 + CT-01 amendments, TileArt (24 px atlas), WaterPhysics,
  MVP-checklist, Stage 2-5 band rows. Feel follow-ups (not done): a 2x2 placement brush (building
  is 4x the clicks), a left/right ladder autotile, player walls being 8 px unless built double.
- **UI size slider** (`UIScale` autoload, 2026-09-02): the pause menu's UI Size slider (1.0-2.0,
  1.0 = current/smallest) sets `get_window().content_scale_factor` — the engine-native UI scale
  (correct anchoring for free). Because that also scales the world, `Player._apply_zoom` divides
  the camera zoom by `UIScale.scale` (re-applied each frame in `_update_camera`, skipped while
  `dying`) so the world stays the same size — only the UI grows. Persisted to settings.cfg `[ui]`.
  Tradeoff: content_scale_factor lowers the base render resolution, so a larger UI slightly softens
  the world (still ≥ pre-HD detail at ≤1.5×); hence the 2.0 cap. (A per-CanvasLayer Control-scale
  approach was tried first and abandoned — anchors + scale didn't compose right in this stretch
  setup; `UIScale.register` is a leftover no-op.)
- **Stage-1 farm loop** (2026-09-02): renewable wood. `wood_axe` fells trees which now drop
  **`tree_seed`** (mature 1–3, smaller 0–1) with the wood; the hand-crafted **`planter`** pot
  (20 wood + 5 plastic, kind `planter`) takes a seed (hold seed, click pot → `World.plant_in_planter`
  sprouts a `tree_sapling` one cell above, grows via `_grow_trees`, full 5×15 only under open sky),
  and the planter persists to replant after felling. Growth is now **deterministic** (2026-09-02):
  each **dawn** (`Constants.MORNING_TIME`, not midnight) every stage advances once (records carry a
  `grow_day`, saved/loaded), so a seed planted on day N is a mature tree on the morning of day N+2 —
  a two-day grow (roof gate covers the exact timing). The hand-crafted **`wood_bucket`** (15 wood,
  category `bucket`) carries water: click water to fill (→ `wood_bucket_full`), click an open cell to
  pour (`WaterSim.add/remove_water`), or click a **planter** with a full bucket to **water its plant
  up one growth stage** (`World.water_plant_above`, 2026-09-02 — the planter's own interact handles
  it, since the pot intercepts the click). Interaction categories `seed`/`bucket` in `interaction.gd`;
  icons on the `items.png` sheet (row 8), planter sprite in `_draw_object`. Hover cards (`hud.gd
  _hover_lines`) explain the planter and each scrap bench (kind `planter`/`scrapper`).
- **Visible day/night + dark nights** (2026-09-02): the cycle already ran (`World.time_of_day`,
  `sun_strength()`, `is_night()`; 600 s) but exteriors never darkened. Two parts now: (1) a gentle
  cool wash — `city.gd._process` drives the scene's `CanvasModulate` (world layer only; HUD/UI are
  `CanvasLayer`s) from `sun_strength` toward `Constants.NIGHT_TINT`, red-moon tint multiplied over
  it. NB: the scene already had one `CanvasModulate` — use `$CanvasModulate`, don't add a second
  (only one is in effect). (2) the real darkness — **`World.visibility_at` now darkens exteriors at
  night** (was always full/`WS-20`): they fall to `Constants.NIGHT_AMBIENT_VIS` (~1.7 of 15 =
  silhouettes, not black) unless a light cuts through — a tight `NIGHT_VIEWER_BLOCKS` moonlit radius
  on the player (`_night_moonlight`, fast falloff), any placed light / dropped glowstick (existing
  fog beacons), or a **worn head lamp** (now added to `light_beacons()`). So night on the roof
  genuinely needs a lamp/glowstick/helmet lamp. Interiors are unchanged (LOS+beacon fog, day/night
  agnostic). Dev arg `--time=N` (0=midnight, 0.5=noon) sets `time_of_day` for shots.
- Ladders/ropes (`player.gd`): pressing **down** while over a climbable grabs and descends it
  instead of falling (2026-09-02 — gated on the down key so a fast shaft-drop into water still
  falls); climbing holds at the very top (grab-and-hang from a ledge) and tops out only on up.
  Placing a **rope** drops a run of up to `Constants.ROPE_DROP` (4) cells; clicking anywhere on an
  existing rope extends it from the **bottom** (`World.place_rope`/`can_place_rope`), so you lengthen
  a line from a ledge.
- Main scene is currently `scenes/test/test_tower.tscn` — a 15-floor test tower (3 dry, 12
  flooded; themed deep floors, stairwell, sealed door-floods). Rows 0-30 are load-bearing for
  the smoke tests — extend downward, do not reshape them. Gate tests: `m0/m1/m2/tower_smoke.tscn`.

## Fixed Design Constants

These are settled and should be treated as canon in all docs and future code:

- Block size: **8×8 pixels**, representing **1 foot** in-game (2026-09-04; was 16×16 = 2 ft — every
  old block is now a 2×2 group of cells and all pixel sizes are unchanged)
- Character: 32px sprite art at 1× (~30px tall; a 1.5× rescale was tried and reverted for feel —
  see the WS-05 note in OpenQuestions.md). Hitbox 12×22 standing, 12×12 compact
- Character is roughly **3.75 blocks tall** (the unchanged ~30 px sprite; the 12×22 px hitbox is 1.5×2.75 blocks); a crawl gap is 2 cells (16 px), a standing gap 3, a jump 6

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

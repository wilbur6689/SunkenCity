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
(superseded by the districts city, see below; `district_smoke.tscn` verifies the skyline now). The wood wall got its own dark vertical-plank tile
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
  Further gates: `m2/m3/m4/m5/tower/save/pocket/roof/admin/room_editor/furniture_editor/flora_editor/monster_editor/icon_editor_smoke.tscn` — `save_smoke`
  covers the full persistence round trip; run it after touching World state or SaveGame.
  `m4_smoke` covers enemies/combat/death loop/red moons; run it after touching enemies, combat,
  or the interaction layer.
- Districts gate: `--headless res://scenes/test/district_smoke.tscn` — tower count, district
  plan, skyline, per-district pitch, floor-level bands, and the gen/RAM/save/water budget fence;
  run it after touching `CityGen`, `World.towers`, or the world save.
- LAN gates (2026-09-05): `--headless res://scenes/test/lan_smoke.tscn` (two `Net` instances in
  one process: handshake, refusals, roster, leave/close — 36 checks) and `python
  tools/lan_smoke.py` (two headless processes on localhost: join + hashes + move, rejoin-resume,
  `--net-mutate`, host close; logs in `tools/_lan_smoke/`, ~3 min). Run both after touching
  anything under `scripts/net/`, `Players`, `SaveGame`, or the World mutation entry points.
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
  metal, plastic, water, ladder, rope (rows 4–6 have no collision); the 24 px world atlas
  (`placeholder_blocks_24.png`, `gen_tiles_24.py`) adds void (row 7), woodwall (8) and garbage (9).
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
  targeting), holding ~0.5s picks the object up (storage must be empty) — **hammer in hand only** since 2026-09-06
  (a bare/knife/weapon hold never lifts anything; with a weapon out and a monster in swing range LMB
  skips the object press and attacks — `Interaction._object_press`); otherwise LMB uses the
  held item — place block/object, hammer hits, consumables, pump-outlet click. RMB =
  hold-to-scrap furniture, place back walls, hammer wall removal. E remains a legacy interact. **Q** toggles bare hands (clears the held item until pressed again
or a hotbar slot is reselected; it no longer drops). Hold-RMB on a bag slot scraps that item
(field yield away from stations; quick tap still takes half). Hammer hits play a swing arc +
impact SFX (`Audio.play_sfx`). Grayed crafting recipes stay clickable to inspect (with `desc`
lines from the data files); only CRAFT is gated. `World.placed_blocks` tracks player blocks (their own HP/hardness); structure
  blocks are ALSO breakable (GL-01 re-amended 2026-08-31, again 2026-09-06) under
  `Constants.STRUCTURE_TIER/HP` — every material (wood/plastic/stone/metal) needs only a plain
  hammer (tool tier 1) and differs only in HP; **demolished structure drops nothing** (there is no
  `STRUCTURE_DROP` any more). VOID has no tier and stays unbreakable.
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
  and their gates (`m3/m5/pocket/roof/save`), the editors + Python room tools, map/
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
  `JUMP_CELLS 6`, `MIN_ROOM_W 16`, `POCKET_DOOR_INSET 4`; world 4800x800 (build rows; +36 world
  rows since the stage gaps, 2026-09-06), `WATERLINE 104`,
  `GROUND 720`, tower widths 96-152, cluster gaps 2-6 (5-10 citywide since 2026-09-05), crown lift 0-10 (steps 4-10), annex
  gap/width/margin 160/840/160, pockets 16-44 wide. Column plan per tower: outer wall x0..x0+3 |
  stair gap x0+4..x0+9 (ladder x0+8..x0+9) | stair wall x0+10..x0+11 | wing x0+12..mid-6 | shaft
  wall mid-5..mid-4 | shaft mid-3..mid+2 | mirrored east. Room stamping snaps furniture to the
  2-cell macro grid (`CityGen.M`); clutter/grass filters want 2x2; the roof hatch is 6x2 anchored
  on the lower slab row; broken-ladder pieces are 2x2, one per two gap rows; `enemy_gen` reads
  `CityGen.FLOOR_H`/`STAND_GAP`. Floor counts, chances and attempt counts are unchanged.
  `World.portal_target` lands the traveller centred on the 2-wide doorway (a body centred on the
  record's west cell overlapped the wall and got unstuck out of the room). Gates converted (cells
  x2, 1600-wide slices, water units x4, light x2, per-cell demolition HP) and passing: `m3`, `m5`,
  `pocket`, `roof`, `save`.
- **Districts** (2026-09-04, `docs/DistrictsOverhaul.md`; tracker section M3b in the checklist):
  the city is a flat slab of **52 towers** at jumpable 5–10-cell gaps (`CityGen.TOWER_COUNT`,
  `WORLD_W` 7600; 2–6 gaps were tried first and hid the water in a slit, user request 2026-09-05), run centred between `OCEAN_MARGIN`s), crowns within `SKYLINE_BAND` 10 cells of
  `CROWN_ROW` (neighbours step 4–10), every tower to the ground (plinth = remainder of crown-to-
  ground ÷ pitch). `_assign_districts` reserves the 6 centre slots residential, places five 5–6-
  tower clusters (business/commercial/civil/industrial/construction) with a 1-tower residential
  buffer (every valid start enumerated, shrink on failure), residential fills the rest. A tower's
  district sets its zone for EVERY floor (mixed-use is gone), its pitch (`DISTRICT_FLOOR_H`: 12/12/
  14/14/20/12), its template width filter (`DISTRICT_ROOM_W`; industrial wings are often one open
  room) and a rare triple-wide roll (`TRIPLE_WIDE`, industrial/commercial: `_column_plan` builds N
  wings / N−1 shafts, one hatch per shaft). Construction = metal frame + wood slabs/partitions, back
  walls only below the waterline, `CONSTRUCTION_BREACH` 0.95, never sealed; it keeps the dry cap
  and hatch. Tower dicts carry `district/floor_h/wings/shafts/lift/center`; `FLOOR_H` (12) is only
  the default/minimum. **No authored medical room or supplies** at the start any more (spawn = the
  centre-most centre tower's roof). Stations/relays/debris sit in the ocean margins (gaps are too
  tight). Pockets pack first-fit into an annex sized by `annex_width(world_w)` (~35 % of the city).
  **Floor-level bands:** `World.towers` (summaries, saved) + `World.floor_band_at` resolve a floor to
  its CEILING row's band for enemies (`add_enemy_record`), loot (`LootGen`, `EnemyGen`) and the F3
  label; `band_at` stays per cell for the cold/crush gates. Surface wall safes drop to
  `SURFACE_SAFE_CHANCE` so GL-28 holds on the doubled city. World saves are `WORLD_VERSION` 3
  (compact object records: id table + `PackedInt32Array` + sparse extras — 20 MB → ~1 MB).
  `construction` is a zone everywhere zones are listed (editors, `check_room_variants`,
  `interior_details`, loot tables); its object pack is `tools/rooms_pack/construction_site.py`
  and rooms.json carries `con_site_a..e` plus tall `ind_hall_a..c` (18 open rows; Room Editor cap
  18). Gate: `district_smoke.tscn`; `_cluster_check`/`_height_report` were retired.
- **Ladders build 2 cells wide** (2026-09-05, user request): one `ladder` item places the aimed
  cell + its right neighbour (`World.can_place_block`/`place_block` climb branch, both halves
  player-owned; `World.ladder_pair` resolves either half), pickup/break lifts the pair as one item,
  the ghost is 2 wide. Art: the 24 px atlas ladder row is col 0 = left rail + rung, col 1 = right
  rail + rung, col 2 = lone single (`gen_tiles_24.py`); `StructureRenderer` picks the half by
  neighbour and repaints neighbours on change, so a pair reads as one H per row with a single rung;
  the 16 px block icon is an H too. Covered in `m1_smoke` J2.
- **Old-format saves** (2026-09-05): the title lists them greyed "(old format)" but SELECTABLE, so
  Delete reaches them; DIVE refuses them with a hint; a **Clear old saves (N)** button (visible only
  when some exist, two-click confirm) runs `SaveGame.delete_stale_saves()` over worlds AND
  characters (`world_is_stale`/`character_is_stale`/`stale_saves`). Covered in `title_smoke` D.
- **LAN multiplayer** (2026-09-05, Steps 1–7 of `docs/technical/Multiplayer.md` §11; the build
  contract is `docs/technical/MultiplayerImpl.md`): a **listen server, relay-only** — the host
  runs every player's full `Player._physics_process` (state machine, vitals AND
  `Interaction.tick`) from the client's relayed input snapshot, so placing/mining/scrapping/
  combat/doors/pickups need no request RPCs; on a client `Interaction.view_only` computes only
  target/hover/cursor/ghost and every body is a puppet (`Player.is_puppet()`) interpolating host
  state. `Net` autoload (`scripts/net/net.gd`: `mode` OFFLINE/HOST/CLIENT, `is_server()`,
  `local_player()`, `peers`, ENet host/join, UDP beacon on `LAN_BEACON_PORT`, build-id handshake
  `_hello/_accepted/_refused`, ping/bytes) owns RPC endpoint children created from
  `scripts/net/*.gd` when present: `WorldSync` (cells/water window/records/items/backpacks/clock/
  power/effects, per-peer queues until the client's `_ready_for_world`), `EnemySync` (puppet
  enemies), `Snapshot` (`SaveGame.world_payload` in `NET_CHUNK_BYTES` chunks), `CharSync`
  (host → owner character state, final-state push, `resume_states`), `PlayerSpawn`
  (`City/Players/<peer_id>` bodies via `scripts/city/players.gd`). Per player: child `Sync`
  (`PlayerSync`: 12 B input in, 30 B state out incl. held item/lamp/suit, owner events
  `_ev_*`) and `Actions` (`PlayerActions`: every inventory-UI mutation as a named slot action,
  optimistic on the client, validated on the host). World mutations call `Net.on_*` hooks
  (no-ops offline); `World._physics_process` ticks clock/water/enemies only when
  `Net.is_server()`; object/enemy windows are the union of all players on the host. Title:
  MULTIPLAYER → `scenes/ui/multiplayer_menu.tscn` (Host / Join, LAN host list, `ip:port`);
  pause menu: roster + LEAVE / CLOSE WORLD; F3: `net:`/`sync:` lines. Dev args: `--host[=port]`
  (+ `--seed/--world/--character/--cap`), `--join=ip[:port] --character=name`,
  `--net-probe=SECS` (NETPROBE hash lines, exits through the real leave/close path),
  `--net-drive` (client walks right 2 s), `--net-mutate` (host mutates beside a joiner). NOT
  done: prediction (MP-02), a real two-machine session, client-side m0/m4 gate variants, wave
  budget MP-06, friendly fire; remote SFX aren't heard on the host and water outside every
  client's window stays stale until it comes near.
- **Modifiers v2 + district weapons** (2026-09-05; design `docs/modifiers/Modifiers.md`, build
  contract `ModifiersImpl.md`, tracker `ModifiersChecklist.md`, roster `Weapons.md`): a found
  piece's modifier is decided by **where it sits** — family = the tower's district
  (`LootGen.district_of`; annex pockets resolve through their doorway's tower), tier = the floor's
  band (`ItemMods.TIER_OF_BAND`). Three prefix families (industrial damage / construction
  knockback+scrap speed / business speed) and three suffix families (residential weight+carry /
  commercial air+swim / civil defense+light+cold), 5 tiers each, plus 30 named first-order hybrids
  and the `rusty` junk prefix — `data/modifiers.json` is **generated** by
  `python tools/gen_modifiers_json.py` from `docs/modifiers/Merged_Modifiers.json` (names) and the
  stat tables in that script (edit there, not the JSON). `Data` flattens it to `modifier_defs` /
  `modifier_families` / `modifier_hybrids` with load-time validation. Instances are
  `mods: {prefix: {id}, suffix: {id}}` — **no `power`**; `ItemMods.stat/tool_of/weapon_of` fold the
  tier-authored stats in (weapon prefixes now reach the held weapon block through
  `Interaction`). Rarity (D2) = highest tier: gray / I–II green / III–IV blue / V purple / both at V
  **gold**. The bench library is **stock** (`Player.mod_library` id → count): LEARN +1 per mod and
  destroys the donor, APPLY consumes (unmodified gear only, then locked), **COMBINE**
  (`Player.combine_mods` / `ItemMods.combine_result`, host-validated `PlayerActions.combine_mods`):
  2 × one id → the family's next tier, two districts at one tier → the hybrid, never across slots
  or tiers, tier 5 is the ceiling. Modify tab = the 6 × 5 library grid (family tints, roman tiers,
  hybrid rows, click cycles a cell none → 1 → 2 picks). Old saves: `ItemMods.clean_stack` strips
  unknown ids / `power` on load (bag, equipment, world records, CharSync) and `known_mods` is ignored
  (D3, no version bump). `defense` now mitigates enemy bites (`DEFENSE_PER_POINT`). **District
  weapons:** 55 melee + 38 ranged + 7 ammo, generated by `python tools/gen_weapons.py`
  (items/recipes/loot merged under the `district_weapon: true` tag — re-runs replace only those;
  every district × band loot table stocked from the Weapons.md §5 matrix; melee craftable blank at
  its band's station, firearms `found_only`; `pistol/smg/rifle/speargun` renamed 9mm Pistol /
  Compact SMG / Bolt-Action Rifle / Spear Gun) and `python tools/gen_weapon_icons.py` (16 px
  icons, band-tinted metal; never overwrites an existing icon, `ICONS_FORCE=1` regenerates).
  Mechanics: shotguns (`pellets` + `spread` on the weapon block, one hitscan per pellet), the
  speargun path generalised into `Interaction._fire_projectile` + `SpearBolt` reading the ammo's
  `projectile: {speed, gravity, retrievable}` (bows/crossbows/harpoon guns retrievable, nails/rivets
  not), the flare gun's flare lands as a lit `WorldItem` (fog beacon). Gates: `m5_smoke` G/H
  (grid roll matches district/band, rarity buckets, stock/apply/combine, D3 cleaner), `save_smoke`
  (library + legacy instance), `m4_smoke` G2 (shotgun/bow/nails/flare), `lan_smoke` +
  `tools/lan_smoke.py`; preview `menu_preview --screen=modify`. **Weapon slot** (2026-09-05, user
  request): a seventh paper-doll slot `equipment.weapon` (glyph cell 4 of `assets/ui/equip_glyphs.png`)
  takes anything with a `weapon` block (`Player.slot_fits`, shared with `CharSync.sanitize`). The worn
  weapon is what an EMPTY hand fights with — `held_stack()`/`held_item()` fall back to it when the
  hotbar slot is empty or Q is on (`holding_worn_weapon()`), so the paper doll, `Interaction`, LAN
  held-item replication and tool gates all see it; `drop_held` never sheds it. Being equipment, its
  modifiers count as worn gear through `equip_stat` (a Commercial suffix on a spear gun gives air
  while worn); prefix stats apply to its attacks as for any held weapon. Hotbar weapons still work
  as before. Covered in `m5_smoke` A2.
- **Enemy density doubled + open-water scatter fixed** (2026-09-05, user request): `data/enemies.json`
  `seeding` — `wing_zombie_weights` is now an any-length list (index = zombie count per dry wing-floor,
  `[0.15, 0.25, 0.35, 0.25]` ≈ 1.7 expected, was ≈ 0.85), `wing_drowned_chance` 0.8 (was 0.4),
  open-water spacings halved. `EnemyGen._scatter` walks spacings along **open-water columns only**
  (`_open_columns`: gaps + ocean margins) with 4 row retries — the districts city's 5–10 cell gaps had
  made the old random-column walk land inside towers 95 % of the time (a whole city seeded 2 sharks,
  4 floaters, 5 fish schools). Flooded Shallows/Cold interiors still seed nothing (walkers dry-only,
  the Drowned from The Dark down) — the next lever if the shallows feel empty. **Gunshots**
  (2026-09-05): `assets/audio/sfx/gunshot_1..3.wav` (synthesised, `tools`-less one-off) play per shot;
  the host relays the take to clients via `Net.on_effect("sfx")`. A cosmetic **`Tracer`**
  (`scripts/items/tracer.gd`, `TRACER_SPEED_BLOCKS`) streaks from muzzle to where each pellet stopped
  (`World.spawn_tracer`, replicated as effect kind `tracer`); hitscan resolution is unchanged.
  **Seeding pity timer** (2026-09-05, user request): per tower wing, walking floors top → bottom,
  every quiet floor adds `wing_pity_boost` (0.5) × streak to the next floor's chance of at least one
  spawn, and after `wing_pity_floors` (2) quiet floors the next is guaranteed (dry floors: one
  zombie; Dark/Crush flooded: a Drowned). Flooded Shallows/Cold floors can't seed anything and just
  extend the streak, so a wing there stays quiet by design — the open question if the first dives
  still feel safe.
- **Forge smelting** (2026-09-05, user request): recipe `iron_smelt` — 6 scrap metal + 1 stone → 1
  iron ingot at the forge (tier 1, known). NB GL-28: the surface's scrap now converts to iron at
  6:1, so the "iron above The Cold cannot cover the gear chain" pressure is softened; `m5_smoke` L
  still counts raw iron only. Retune the ratio (or gate it on Scrapping 2) if Stage 2 play shows the
  chain finishing without a dive.
- **Perf pass** (2026-09-05, user report "choppy, worse zoomed out"). Probe: `godot --path . --
  --seed=1 --perf=SECS [--zoom=IDX] [--objwin=WxH] [--enemywin=WxH] [--walk]` (windowed, not
  headless; `scripts/test/perf_probe.gd`) prints `PERF` lines: avg/p95/worst frame ms, mean of every
  `World.perf` timer, live counts. Findings + fixes: (1) the districts city has ~104k object
  records and every 12-cell move rescanned all of them (~100 ms hitch) — records are now bucketed
  (`World.OBJ_BUCKET` 64-cell grid, `_records_in_windows`), the live set (`_live_records`, keyed by
  a per-record `uid` because dictionaries hash by content) handles despawn, and `door_records` /
  `placed_light_records` replace the full scans in `closed_door_cells` / `light_beacons` (the latter
  was also the hidden ~25 ms in every fog recompute): scan 107 → ~3 ms. (2) `WaterRenderer` drew a
  `draw_rect` per visible water cell (8 ms/frame at max zoom-out): it now slices the visible rows of
  `WaterSim.levels` into an R8 texture (rebuilt only when the view moves / water moved / 0.5 s
  keep-alive) and a shader paints fill + bobbing surface; depth bands unchanged: 8 → 0.02 ms.
  (3) streaming in is spread `OBJECT_SPAWN_BUDGET` (24) records per tick via `_spawn_queue`
  (`refresh_objects_around` fills immediately for boot/tests/teleports). (4) `OBJECT_WINDOW` /
  `ENEMY_WINDOW` shrunk to 280×120 (~10 floors; window size barely moves fps once indexed, it sets
  node count/RAM); `test_tower.gd` widens them back so held references survive the smokes.
  (5) dropped `WorldItem`s sleep beyond `ITEM_SLEEP_BLOCKS` (120) from every player and hide when
  their cell's visibility is 0 (re-checked every `ITEM_CULL_SECONDS`); all dropped items stay nodes
  (they are saved), none are unloaded. Result on the RTX 4070 test box: walking at max zoom-out
  44 → 119 fps, p95 49 → 13 ms, worst 122 → 25 ms; default zoom 67 → 120 fps. F3 gained view /
  render-ms / stream / items / memory lines (`hud.gd _refresh_debug`). Remaining per-frame costs:
  fog raycasts 4–9 ms per recompute (10×/s moving), the static relight ~30 ms on a worker thread,
  live enemy AI. No LOD exists or is needed in 2D — windowing + culling is the whole story.
- **Shared map** (2026-09-06, user request; CC-25 amended): the fog-of-war map is ONE per world.
  It saves in the world payload (`"map"`), so the host's F5 keeps everyone's exploration; the host
  reveals for every body it simulates (`World._physics_process`) and streams new cells to clients
  every `NET_MAP_SYNC_TICKS` (`WorldSync._tick_map` → `_map`, from `MapReveal.net_dirty`, tracked
  only while hosting); a joining client gets the whole map in the snapshot and reveals for itself
  locally too. Character files no longer store a map; a legacy per-character map is merged into the
  shared one once on load (`MapReveal.merge_bytes`, `apply_character` / `CharSync`).
- **Tool tier badges + weapons don't dismantle** (2026-09-06, user request): the object card's
  shield (`scripts/ui/tier_badge.gd`, preloaded by `hud.gd` and `inventory_ui.gd` — no class_name)
  now also sits under every item tooltip: tools show "Dismantles tier N and below" (axes: "Fells
  trees (tier N)"), plain weapons show "Weapon: no dismantling". `Interaction._weapon_in_hand()`
  (weapon block, no tool block, in the HOTBAR hand) refuses `_scrap` and `can_harvest`; a worn
  weapon standing in for an empty hand still counts as bare hands. Tool-weapons (fire axe,
  crowbar, sledgehammer …) dismantle at their tool tier. Covered in `m5_smoke` K2.
- **Weapon hotbar slot** (2026-09-06, user request): a slot LEFT of the hotbar (8 px gap, blade
  glyph when empty) shows the worn weapon (`equipment.weapon`). `selected_slot ==
  Constants.WEAPON_HOTBAR` (-1) selects it — key **1**, clicking it, or the wheel (which cycles
  weapon → hotbar 1..10 → weapon); keys 2..0 are hotbar slots 1..9, the tenth is wheel/click only.
  `held_stack()` returns the worn weapon there; `Inventory.remove_from_slot` ignores negative
  indices; `PlayerSync` encodes it as 255, `CharSync.sanitize` clamps from -1, `PlayerActions.
  select_slot` accepts it. `hotbar_select` uses `Player.NO_HOTBAR_KEY` as its "no key" sentinel.
- **Crafting docs** (2026-09-06): `docs/Crafting.md` is GENERATED by `python tools/gen_crafting_doc.py`
  (every bench, recipe, cost, material demand + the bench-overhaul proposal kept in the script);
  `docs/CraftingStages.md` is the design chart for one main bench per stage (Hands → Workbench →
  Forge → Machine Shop → Steel Works → Pressure Works, plus side benches), each costing the next
  stage's materials and a **found part** (a real placed object consumed by the recipe: Desk, Stove,
  Machinist's Table, Welding Cart, Diesel Generator). Neither overhaul is built yet.
- **Found parts, stage benches, floor doors, wet scrapping, the stove** (2026-09-06, user request;
  `docs/CraftingStages.md`): `tools/gen_parts_art.py` draws + writes ten `part: true` objects
  (`needed_for`, `band`, one district each — hover card says which bench they build), five station
  objects (`machine_shop`, `steel_works`, `pressure_works`, `weapon_bench`, `pump_works`; in
  `Data.STATIONS`) and `pot_belly_stove` (kind `heater`), plus the bench recipes (each costs its
  part) and the recipe moves (all `district_weapon` + swords/speargun/ammo → weapon bench; pump +
  lamps → pump works; iron knife/bolt cutters/iron scrap bench → machine shop; steel/torch/steel
  scrap bench → steel works; master scrap bench → pressure works). `CityGen.place_parts(World, gen,
  seed)` (after the door records, before loot) drops `PART_COPIES` (3) of each part into its
  district's towers on a floor of its band via `can_place_object`. **Floor doors:** non-sealed wings
  get wood doors on BOTH doorways at `FLOOR_DOOR_CHANCE` (dry .9 / shallows .8 / cold .7), found
  open below the waterline (`doors[].open` → record), half closed in The Dry. **Wet scrapping:**
  `UNDERWATER_SCRAP_SLOW` (25 %) on the progress rate and `UNDERWATER_SCRAP_YIELD_LOSS` (10 %,
  stochastic rounding) in `roll_yields` when the object's centre is in water. **Stove:**
  `World.room_sealed_cells(cell)` (BFS over non-solid cells, closed doors are walls, [] past
  `STOVE_ROOM_MAX_CELLS`) gates `can_place_object` (`World.last_place_error` → the UI hint) and
  lighting; `World.heaters` tick `_tick_heaters` on the server: `STOVE_UNITS_PER_SECOND` (8) off
  the top water cell of the cached room, seal re-checked every `STOVE_SEAL_CHECK_TICKS`, snuffs
  itself on a breach; lit = `powered_on` (saved/synced as `powered`), warm sprite tint, a light
  source and fog beacon. Gates: `m1` (workbench needs its part), `m2` D2 (stove dries the sealed
  room; open floor refused), `m5` K3 (every part spawns, ≥200 wing doors, bench recipes cost parts,
  moves). `docs/Crafting.md` regenerated.
- **Stage gaps** (2026-09-06, user request): the three SUBMERGED stage boundaries (Shallows/Cold,
  Cold/Dark, Dark/Crush — never the waterline) are open **12-row "middle ground" bands**
  (`Constants.STAGE_GAP_ROWS`). `CityGen` builds the towers on the old gap-free lattice ("build rows":
  `WATERLINE`/`GROUND`/`tower.top + f*floor_h`, `Constants.STAGE_FLOOR_DEPTH_*` 80/240/440), then
  `_insert_stage_gaps` copies the grid into a taller one (800 → 836 rows) with the gap rows spliced in
  before each boundary: inside a tower footprint the gap is bare back wall (stone; metal for
  construction), the inter-tower gaps + ocean margins are plugged with a **heap** of **`WorldGrid.M.GARBAGE`** (gap-wide on top, spreading 1 cell into each footprint per `PLUG_SLOPE` 2 rows — `plug_reach(k)`; user request: a pyramid, not a column)
  (atlas row 9, `gen_tiles_24.py`; `STRUCTURE_TIER` 1 / HP 25; the ONE structure that drops —
  `GARBAGE_DROPS` scrap metal + plastic at `GARBAGE_DROP_CHANCE` each), the annex continues the row
  above. A floor straddling a line is cut in two; objects/doors/sealed rects crossing a gap are dropped
  (a portal takes its twin + pocket), a pocket crossing one just grows 12 rows taller. Everything after
  the splice is in WORLD rows: `CityGen.expand_row/compact_row/stage_gaps/in_stage_gap/ground_row/
  world_h/floor_ceiling/floor_standing_row` (`tower_at`, `band_row`, `place_parts`, `EnemyGen`,
  `floor_blockages(..., world_rows)`, the gates). `Constants.BAND_*_DEPTH` are world-row depths
  (= floor depth + the gaps above it), so **a gap belongs to the shallower band**; `_door_band`, door
  materials, side vents and safe odds compare build rows against `STAGE_FLOOR_DEPTH_*`. The flood
  seeds every open city cell right above each plug (the plugs cut the sea into basins; the Shallows'
  breaches are vent-sealed, so without the seeds the Shallows gaps stayed dry). Relay pylons stand on
  the plugs (`_find_open_span` now refuses back-walled cells — tall industrial floors fit a pylon).
  `World.visibility_at` treats gap rows as exterior (back wall kept, no fog). Backdrops:
  `tools/gen_stage_backdrops.py` writes `assets/backgrounds/{cold,dark,crush}01..05.png` (704 px,
  2-px pixel art: tower-tall layered skylines, thermocline haze + silt / bioluminescence / red
  pressure haze + vents + rubble, a fade over the gap rows) and `BandBackdrop._add_stage_strips` hangs
  them from each gap's first row (the Dry/Shallows plates are unchanged). `SaveGame.WORLD_VERSION` 4
  (the grid is taller). Gate: `district_smoke` (splice geometry, plugs, no crossers, orphan pockets,
  relays on plugs, band of the gap, exterior visibility, hammer digs garbage); `m3/pocket` converted.
- **Pocket guardians** (2026-09-06, user request): every interior pocket rolls `seeding.pocket_monster_chance`
  (0.75) for ONE elite at `pocket_monster_mult` (x2 hp/damage): the tower district's dry uniques in a dry
  pocket (else a walker), its flooded (T2) uniques in a drowned one (else a barracuda) — `EnemyGen`
  after the tower loop, records carry `mult`/`pocket`, `city.gd` passes the mult to `add_enemy_record`.
  Covered in `district_smoke`.
- **Hit feedback** (2026-09-06, user request): every discrete hit on the player (`Player.apply_damage`
  → `_hurt_fx`, ≥ `HURT_FX_MIN_DAMAGE` 1.0, one per `HURT_FX_COOLDOWN` — cold/crush/bleed/drown drains
  tick below it and never strobe) bursts red debris (`World.spawn_break_puff(.., "blood")`,
  `HARVEST_TINT.blood`, replicated as a puff effect), plays `player_hurt_1..3.wav` (synthesised by
  `tools/gen_hit_sfx.py`, relayed via `Net.on_effect("sfx")`) and flashes the screen: `Player.hurt_flash`
  (seconds) is drained by `hud.gd _tick_hurt_flash` into a full-rect red `ColorRect`
  (`HURT_FLASH_ALPHA`, `HURT_FLASH_SECONDS`); a LAN owner gets `PlayerSync.ev_hurt` → `flash_hurt()`.
  Every hit on a monster (`Enemy.hurt`) bursts green ichor (`HARVEST_TINT.ichor`) and plays
  `enemy_hit_1..3.wav`. Covered in `m4_smoke` C.
- **Client-side feedback for host-run actions** (2026-09-06, user report "as a client I hear
  nothing but the host's footsteps; harvesting shows no progress"): the host runs a client's
  actions, and `Interaction._sfx` used to play only for a LOCAL body. Now
  **`Audio.play_world_sfx(base, pos, variants, volume_db)`** plays a simulation sound where it
  happens AND (while hosting) relays the resolved take + volume to every client as effect
  `sfx` (`"name@vol"`, `WorldSync._effect`); `Interaction._sfx`, door/planter/safe sounds in
  `WorldObject.interact`, enemy pounds/shots/fish grabs/hurt, the player hurt take, bag
  scrapping, the pound-break and the red-moon stinger all go through it (the old explicit
  gunshot/hurt/enemy-hit relays are folded in). Sounds every machine derives from replicated
  state (footsteps, splashes, the enemy "died" event) stay on `Audio.play_sfx`. The state
  packet (`ST_BYTES` 31) carries `scrap_progress` as a byte (`Player.puppet_scrap_progress`)
  so the client's HUD scrap bar fills. **Exported builds have no loose PNGs**: `Data.icon`,
  `object_texture` and `Enemy._load_strip` go through `Data.load_texture_fresh(path,
  prefer_raw)` — raw disk read only under the editor binary (`OS.has_feature("editor")`),
  `load()` otherwise — the exported client showed placeholder blobs for every material icon.
  `Audio.sfx_requests` counts requests (headless too); `--net-harvest` (`net_probe.gd`, a
  client or offline) walks to the nearest hand-harvestable object, aims via
  `Player.aim_override` and holds RMB, printing `NETPROBE harvest:` lines (record gone,
  streamed progress, sfx count) — the `harvest` scenario in `tools/lan_smoke.py` asserts it
  (`--only-harvest` runs just that one; passing 2026-09-06: 1.5 s roof bush, 4 relayed sounds).
- **Host boot/join stall** (2026-09-06, found while LAN-testing the above): `WorldSync`'s
  `on_record_*`/`on_cell_changed` hooks now do nothing when nobody can receive (`_anyone()`: no
  READY peer and no LOADING queue) — city generation was `_compact`ing all ~107k records into the
  void (host boot 28 s -> 9 s) and the found-open doors left ~thousands of records dirty, so the
  host's first tick spent 15 s in `_flush_records` (`object_records.has(rec)` compares dictionary
  CONTENTS: O(n) per record — now an `is_same` identity check against `object_cells[cell]`),
  which froze ENet while the first client tried to connect (19 s connect, then dropped).
  `net_probe.gd` prints `NETPROBE stall:` on any wall-clock frame gap > 400 ms (Godot caps the
  process delta, so `delta` never shows it) and `ms=` on every line; `Net._status` prints
  `t=` in the log only. Still there: the water sim's first settle after boot (~3.7 s over the
  first two ticks, `perf.water_ms`) blocks the host briefly.
- **Monsters stood in the floor** (2026-09-06, user report): square-cell strips are taller than
  the type's `size`, and `enemy.tscn` centres the sprite on the body, so the drawn feet (art
  contract: feet near the cell bottom) sat 4–9 px inside the slab. `Enemy._load_strip` now
  records a per-texture foot offset (`Image.get_used_rect()` lowest opaque row vs `half.y`,
  cached by path) for ground/surface modes and `_set_strip` applies it as `sprite.offset.y`
  (corpse too); swim/fly stay centred. The Monster Editor's hitbox overlay mirrors the rule and
  gained the missing `fly` mode (index 3, after swim).
- **Axe chops placed wood** (2026-09-06, user request): `Interaction._axe` — LMB with an axe
  (`wood_axe`; the fire axe when no enemy is in swing range) damages a PLAYER-PLACED block whose
  id is in `Constants.AXE_BLOCKS` (`wood_block`, `wood_wall`) at the axe's tier with the hammer's
  cadence/swing/SFX; structure or non-wood placed blocks get a swing + "An axe only cuts wood you
  placed"; ladders (climb layer) are untouched. RMB with an axe removes a player-placed wood back
  wall. `World.placed_block_id(cell, layer)`. Tooltips/badges: "Fells trees, cuts placed wood
  (tier N)". Covered in `m1_smoke` J3 (not yet run).
- **Named worlds** (2026-09-06, user request): the title's world column has a name field for
  "+ New world" — display name (`SaveGame.clean_world_name`, ≤32 chars, no `|`) lives in the world
  payload as `"name"` (+ `"key"`); the file key is `SaveGame.world_slug` (`[a-z0-9_]`, `_2`/`(2)`
  on collision, `SaveGame.new_world_key`), `world_<seed>` for both when blank (dev args and
  `tools/lan_smoke.py` cleanup unchanged). `City.world_title` feeds `Net._current_world_name`
  (beacon, `_accepted`, the pause roster header, the F5 toast); `Net.start_hosting(...,
  display_name)` / `--host --name=`. No rename yet. `title_smoke` E (not yet run). The JOIN
  screen's `LanBrowser` retries `bind(47121)` every 2 s when the port is busy (another instance on
  the PC, e.g. a headless test client still closing) — "port busy, retrying…"; Godot 4.8 exposes
  no SO_REUSEADDR, so two listeners on one PC still can't coexist.
- **Physics under every simulated body** (2026-09-06, user report: a LAN client "falls through
  floors and stone walls until it hits water"): `StructureRenderer` paints tiles — and with them
  the ONLY collision there is — around the camera, so on the host a remote player away from the
  host's screen stood on nothing (`World.is_water` still caught it in the flooded gaps). The
  renderer now keeps one painted rect per **anchor** (`painted: {key: Rect2i}`): the camera view
  (+`MARGIN`) and, while `Net.is_server()`, an `ENEMY_WINDOW`-sized rect around every body in the
  `player` group (keyed by `peer_id`, the local one too — enemies streamed in beyond the camera's
  window had no floor either); rects grow by delta strips, drop when an anchor leaves, and a cell
  is erased only when no other anchor covers it. `perf.struct_cells` is the sum. A client paints
  only its camera.
- **Wooden Club** (2026-09-06, user request): `wood_club` — a hand-crafted Stage 1 melee weapon
  (6 wood, `station: hand`, known; weapon block damage 3.5 / speed 1.1 / knockback 12 /
  `water_factor` 0.4; scraps to 2 wood; NOT a `district_weapon`, so `gen_weapons.py` leaves it
  alone). Icon drawer `club` in `tools/gen_weapon_icons.py` (`NO_METAL`). `docs/Crafting.md`
  regenerated (113 recipes).
- **Ingredient source popups** (2026-09-06, user request): hovering an ingredient row in the
  Crafting tab's detail panel raises the hover plate with `Data.source_lines(item)` — "Craft:
  <station> (tier n)", a found part's "Found: <district> district towers / Floors: <band> / builds
  the <bench>", "Dig: garbage heaps", "Harvest: rooftop trees (axe)", "Scrap (<zone>): a, b, c
  +N more" per zone from objects.json yields, "Drops: <enemies> in <bands>" (`enemy_bands`), and
  "Loot: containers in <districts> on <bands> floors" from loot.json; wrapped at 46 chars,
  cached. `Data.BAND_LABEL` / `SOURCE_BANDS` (= `BAND_ORDER` + roof). Hover kind `source:<item>`
  in `inventory_ui._update_hover_plate`.
- **District-coloured vents** (2026-09-06, user request): `roof_hatch` and `side_vent` sprites are
  tinted by their tower's district (`Constants.DISTRICT_TINT`: residential amber, business steel
  blue, commercial pink, civil green, industrial rust, construction hi-vis yellow) in
  `WorldObject._ready` via `World.district_at_x` (rgb only; door alpha untouched).
- **Shaft-mouth ladders** (2026-09-06, user request): `CityGen` lays a 2-wide ladder on BOTH
  shaft walls from just under the roof hatch (`top + SLAB_T`) to the top floor's standing row, so
  the drop through a pried vent lands on rungs beside floor 0's shaft doorway (every tower, every
  shaft; the stairwell-decay pass never touches them).
- **Map: players + deaths** (2026-09-06, user request): the full map (`map_view._update_overlays`)
  draws other players as cyan dots with their names, death backpacks (`backpacks` group, incl.
  client replicas) as red dots and this session's own death spots (`Player.death_marks`, filled
  in `_die` on the host and `_ev_died` on a client; not saved) as dim red dots; the minimap draws
  the cyan/red 2x2 dots (`hud._minimap_dot`).
- **Session notices** (2026-09-06, user request): `Net.notice_all(text)` emits `Net.notice` locally
  and, while hosting, `WorldSync.send_notice` relays it reliably to READY clients (`_notice`); the
  HUD shows it on the message line. Fired for "<name> joined the world" (after `peer_ready`),
  "<name> left the world" (before `peer_left`) and "<name> died" (`Player._die`, online only).
- **Puddle evaporation** (2026-09-06, user request "thin water should slowly disappear"): a cell
  that settles at <= `WATER_EVAP_MAX_LEVEL` (2 of 8) joins `WaterSim._thin`; after
  `WATER_EVAP_SECONDS` (30) it loses one level, again per period, while it RESTS ON A FLOOR (solid
  or dry cell below, nothing above) — a body's surface film sits on water and is skipped, so lakes
  and flooded rooms keep their volume (m2 conservation holds). `WATER_EVAP_PER_TICK` (256) entries
  are examined per tick; drying goes through `_touch` so clients get the delta.
- **Corpse no longer recovers its own pack** (2026-09-06, user report "the host kept all their
  stuff"): `Backpack._try_recover` skips bodies with `dying` set — the death scene holds the body
  where it fell for `DEATH_SCENE_SECONDS` (3) while the pack unlocks after `BACKPACK_PICKUP_DELAY`
  (1.5), so the corpse took everything back before the respawn. Any body, host or client.
- **F4 admin panel** (2026-09-06, user request): `scripts/dev/admin.gd` (`class_name Admin`, static
  session flags, host/offline only — a LAN client's body is simulated by the host) behind **F4** in
  `hud.gd` (`_build_admin`; `--f4` opens it at boot for shots): checkboxes **no-clip fly**
  (`Player._admin_fly`: move keys, jump up, crouch down, sprint x2, `ADMIN_FLY_BLOCKS`; no state
  machine/collision, camera + interaction keep running), **no death** (`apply_damage`/`start_bleeding`/
  `_update_oxygen` guards), **reveal map + no fog** (`MapReveal.reveal_all` sets the bits + a
  `full_dirty` repaint flag the map view honours; `World.visibility_at` returns full light; unticking
  restores the fog, the map stays revealed); buttons **give 50 of every crafting resource**
  (`Admin.RESOURCE_IDS`: the 7 materials + rope, not parts) and **teleport to the top of this
  column** (`World.sky_row` → `travel_to`). F3 gains an `admin:` line while any is on. Gate:
  `admin_smoke.tscn` (17 checks).
- **Stats window shows modifier shares** (2026-09-06, user request): the Inventory tab's stats panel
  is a `RichTextLabel` (`inventory_ui.gd _stats_bbcode`): Weight / Carry / Swim / Air / Defense
  always, plus light/cold/crush/scrap speed/double yield/map reveal while non-zero, each followed by
  the worn MODIFIERS' share in green (red when a mod hurts) — "Weight 14.3 (-1.0)", "Carry 68 (+8)".
  Preview: `menu_preview --screen=inventory --worn=res_4` (a rifle with that suffix in the weapon slot).
- **Bestiary Grid fauna** (2026-09-06, user designs): the design sheets are
  `docs/monsters/t0_roof_fauna.json` (T0 Rooftops, 24), `docs/monsters/t1_dry_fauna.json` (T1 The
  Dry, 24 + 4 "open water") and `docs/monsters/t2_shallows_fauna.json` (T2 The Shallows, 24 + 4
  open-water hunters; free-text drops are mapped onto material families by `DROP_FAMILIES`, no trophy
  items; Swims/Glides/Floats/Stationary/"Crawls/Swims" -> swim; `ranged` + `range_blocks` and
  `stationary` flags; extra rules -> `armor` 0.3 (high defense / slime coat / reflects), `stealth` 0.5 +
  `ambush` (semi-invisible / camouflage), `lifesteal` 0.5, `enrage` 0.3). Sprite drawers live in
  **`tools/fauna_art/t0.py` / `t1.py` / `t2.py`** (per-stage modules, `DRAW`/`HITBOX`/`CELL` dicts,
  contract in `fauna_art/common.py`, override the builder's built-ins; preview a sheet with
  `python tools/fauna_art/preview.py t2 out.png`). **Enemy ranged attack** (`Enemy._try_shoot`):
  a type with `ranged` spits at a player within `range_blocks` and line of sight every
  `ENEMY_SHOT_COOLDOWN` (a tracer draws it, damage = its stat); `stationary` swimmers never move;
  `lifesteal` heals on bites/shots. Seeding: `district_fauna.<band>` + `district_fauna_share.<band>`
  now cover the flooded bands too (a share of each flooded-floor fish roll becomes a district unique)
  and `open_water_fauna.<band>` + `open_water_fauna_spacing` scatter hunters per band.
  **`python tools/build_fauna.py`** writes them into `data/enemies.json`
  (types tagged `grid_fauna: true` + `stage` + `district`, replaced on re-run; `mode` from the verb:
  Flies → **`fly`**, Swims → `swim` water-only, Skims / the mudskipper → `surface`, else ground; hitbox
  per archetype; hp/damage/speed LITERAL; a stat row per band — T0 `roof`, T1 `dry`, the surface set
  `dry`+`shallows`; aggro by size 22/24/28; drops parsed from the text — new items `organic_material`
  and `paper` + icons; special rules → `armor` 0.25, `ambush` (no wander until a target), `stealth`
  0.4 (translucent), `enrage` 0.5 (+ `enrage_at` 0.5 for "below half health"), `knockback_resist`
  0.8), plus seeding `roof_night_types_by_district` (T0), `district_fauna.dry` +
  `district_fauna_share.dry` 0.3 (T1: on a dry floor each zombie roll becomes one of the tower
  district's four with that share — `EnemyGen`), `surface_fauna` + `surface_fauna_spacing` (T1 open
  water: swimmers 1–6 rows under the waterline, surface modes on it, along open-water columns), and
  draws 4-frame square strips from ~35 archetype drawers (palette from the "look" text, base art faces
  RIGHT). Engine: `Enemy._move_fly` (no gravity, turns from solids/water, aims above the target),
  `armor`/`enrage`/`knockback_resist` in `hurt`, `ambush` in `_tick_wander`; `World._tick_roof_night`
  picks the T0 roster by `World.district_at_x`, fliers spawn 4 blocks up; the Prowler stays as the
  district-less T0 fallback. Counts: 62 types (`m4`/`monster_editor` smokes); `district_smoke` checks
  the T1 uniques sit in their own district's dry floors, the surface four at the waterline, and the
  T0 night cycle. NB designed numbers are small (hp 2–10, bites 1–4 of 100 health, speed 0.75–4
  blocks/s vs a walker's 4.4): nuisances in numbers — retune in the JSON + re-run the tool. Not
  built from the sheets: slows/poison on hit, playing dead, cackle alerts, charge-ups.
- **Predator fish** (2026-09-06, user request): three `mode: "swim"`, `water_only` types in
  `data/enemies.json` with Shallows + Cold rows only — **`tropical_fish`** (easy: hp 10/14, fast, nippy),
  **`catfish`** (medium: hp 35/45, slow), **`barracuda`** (hardest: hp 60/75, speed 14–15, `bleeds`);
  all drop fish meat. They swim flooded interiors like the Drowned (no `open_water` flag). Seeding
  (`enemies.json seeding`): flooded Shallows/Cold wing-floors — the old quiet rows — roll
  `wing_fish_chance` (0.5, pity-boosted) for one fish from that band's `wing_fish_weights`
  (`EnemyGen._weighted_pick`), and each type is scattered along open water in its bands at
  `pred_fish_spacing` (tropical: shallows, catfish: both, barracuda: cold). Strips are procedural
  square-cell 4-frame swims from `tools/gen_fish_art.py` (12 / 24 / 40 px cells, base art faces RIGHT;
  NB the hand-made shark strip faces left, so it swims tail-first — a known cosmetic bug). Counts in
  `m4`/`monster_editor` smokes are 10 types now; `district_smoke` checks all three seed in their bands
  and indoors.
- **T0 Rooftops** (2026-09-06, user request): a stage ABOVE The Dry. `World.band_at` returns
  **`"roof"`** for cells above the waterline that are outside every tower footprint (the open air over
  the crowns and between towers); inside a footprint (the dry cap), in the annex, or with no
  `World.towers` (the test tower) it is still `"dry"`. `Data.enemy_stats` has a `roof` row first and
  falls back to `dry` for types without one; `aggro.gd` counts roof as a surface band (night radii);
  `ItemMods.TIER_OF_BAND.roof` = 1; the Monster Editor lists the roof band. **Night roof spawns:**
  `World._tick_roof_night` (from `_tick_night`, floater cadence) — every player whose cell is in the
  roof band and NOT inside a sealed room (`room_sealed_cells`, i.e. a house of their own) draws up to
  `seeding.roof_night_max` (4) spawns of `seeding.roof_night_types` onto roof tops
  `roof_night_min/max_blocks` (20–50) away (`_spawn_roof_night`: first roof top in the column via
  `sky_row`, never over open water); records carry `night` + `roof` and clear at dawn. Placeholder
  type **`prowler`** (`data/enemies.json`: ground, fast, roof stats only, **`pounds: false`** —
  `Enemy._handle_block` honours it so a house holds; strips from `tools/gen_prowler_art.py`, a cold
  recolour of walker_h). Gates: `district_smoke` (band + a midnight spawn/dawn clear cycle), `m3`.
  The bestiary grid artifact and `docs/monsters/Monsters.md` carry a T0 row (42 slots).
- **Monster chart** (2026-09-06, user request): `docs/monsters/Monsters.md` is the district × stage
  monster grid (companion to `docs/modifiers/Modifiers.md`): today's six shared monsters with their
  seeding odds read from `data/enemies.json` + `EnemyGen`, then a 6 districts (+ open water) × 5
  stages grid with an EMPTY unique slot per cell (35 slots, 0 filled), identity hints per district,
  and a proposed "unique replaces a share of the roll" likelihood scheme. Seeding is still
  district-blind; nothing in §3–§5 is built.
- **Hotbar tooltips** (2026-09-06, user request): hovering a hotbar slot (or the weapon slot) raises a
  plate above it (`hud.gd _build_hotbar_tip/_update_hotbar_tip`): rarity-coloured name, tool tier
  badge line, modifier lines, description, count × weight; the empty weapon slot explains itself.
  Preview: `menu_preview --screen=inventory --hover=hotbar:N` (N = -1 for the weapon slot). The
  double-encoded em dashes ("â€”") in `data/*.json` descriptions were repaired the same day.
- **Gate runs:** `--quit-after N` counts FRAMES, not seconds - it truncates the input-driven gates
  (`m0/m1/m2/m4/tower`) mid-run while still exiting 0. Run gates with a shell `timeout` only, and
  read the final "N checks, M failures" line; a parse error makes a headless scene hang forever.
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
  is 4x the clicks), player walls being 8 px unless built double. (The left/right ladder autotile
  landed 2026-09-05.)
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
  a line from a ledge. **Rope tops are landing platforms like ladder tops** (2026-09-06, user request:
  `World.is_ladder_top_cell` covers any climbable run's top cell; a fall lands on it, down climbs through;
  covered in `m0_smoke` F).
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
  `WaterPhysics.md` (cellular tile water, pumps, endgame drain). `Multiplayer.md` (2026-09-05) is the
  LAN design: listen server, host owns the world and simulates every player from replicated input
  snapshots, clients own only input + lighting/map/UI, join = the world-save payload as a snapshot,
  then cell/water/object/enemy/item/clock deltas; §4 lists the seams to refactor first, §11 the plan.

- **Flora rebuild, residential set** (2026-09-06, user request): ALL legacy plants are gone
  (`tree_sapling/young/mature`, `roof_bush`, `roof_grass*`, editor experiments + their PNGs and the
  `roof_gear.py` entries; `roof_garden_a/b` templates retargeted). Plants are GENERATED:
  `tools/flora_art/common.py` (ramps, cluster brushes, layered `canopy`, `trunk`/`branch`, `tuft`,
  sel-out `outline_pass`, `sway_frames`) + one module per district (`res.py`: plane / apple / maple /
  hedge / rose / lawn / clover, each `<id>_seedling` → `<id>_midling` → `<id>`), built by
  `python tools/build_flora.py [res]` into `assets/sprites/objects/<id>.png` sway STRIPS + objects.json
  entries tagged `generated_flora` (+ `district`, `frames`; re-runs replace only tagged entries, never
  `authored` ones) and per-species seed items (`res_plane_seed` … `plants` = the seedling id, 16 px icons
  kept unless `ICONS_FORCE=1`). Preview: `python tools/flora_art/preview.py res out.png`. Engine:
  `Data.strip_frames(id)` (PNG width ÷ size px) / `object_strip_texture` — `object_texture` now returns
  the REST frame (icons, editors, cards); `WorldObject` sets `hframes` and ping-pongs at
  `FLORA_SWAY_FPS` (phase per cell, x2 on a red moon, still under water); `CityGen._district_flora`
  picks the tower district's set;
  `World.plant_in_planter(planter, cell, seedling_id)` plants the held seed's `plants` species
  (`Constants.DEFAULT_SEEDLING` for the legacy `tree_seed`, `PLANTER_SLOT_CELLS` 2); the Flora Editor
  loads a strip's rest frame and a save drops `frames`/`generated_flora`. NB adjacent planter-box
  sections block a wide midling (only outer sections grow at once). Gates updated + passing: `roof`
  (lineage/seed checks), `flora_editor`, `district`, `save`. Tracker: `docs/Flora/FloraChecklist.md`
  (status table per district — tick it when a district's module lands). **Business set built the same
  day** (`tools/flora_art/bus.py`: cypress / locust / tub ficus / boxwood sphere / boxwood trough / turf /
  fountain grass; steel `tub()` containers drawn after the outline pass; `_block_canopy` for clipped
  rectangles). Roof-template plants (`roof_garden_a/b`) now resolve to a weighted pick from the tower
  district's pool in `_stamp_roofs`; `roof_smoke` checks district-only placement on the full city.
  **Commercial set** (`com.py`, same day): fan palm (`frond`/`palm_trunk` helpers), magnolia, bougainvillea
  on a trellis (`magenta_tips`), hibiscus, concrete planter bed, monstera, fern. `common.seedling` is the
  shared sprout drawer. **Civil set** (`civ.py`): park oak, linden, weeping birch (`strands` drawn after the
  outline pass so they stay 2 px), rhododendron, memorial yew, meadow tuft, ivy; the 14×30 great-oak landmark
  is deferred until seeding has a rarity roll. **Industrial** (`ind.py`: tree of heaven, pioneer birch, sumac,
  bramble, buddleia, thistle, concrete weeds) and **Construction** (`con.py`: willow, poplar, elder, ragwort,
  rebar ivy, horsetail, moss on rubble; module `WEIGHTS` favour seedlings 5:2:1) complete the six districts;
  `_district_flora` keeps the residential fallback only for a district id with no set, the test tower (no
  district) gets the union. 126 flora objects, 18 seeds. Still open: wild + submerged sets, `flora_smoke` gate,
  the great-oak landmark, the planter-box decision (see the checklist).
- `docs/Flora/flora.md` (2026-09-06) — the flora art bible: lessons from the user's reference sheets,
  universal rules (top-left light, layered cluster canopies, 6-step hue-shifted leaf ramp, tinted
  sel-out outline, ground tuft), the three-stage seedling/midling/full lineage contract, the sway
  strip animation contract (4/2/1 frames, base pinned), and the per-district species roster
  (7 species × 3 stages per district + wild + submerged sets). Nothing from it is built yet.

When answering design questions, questions cross-reference each other by ID (e.g. GD-19 defers to
GL-12) — check whether a referenced question was already decided before asking again.

## Project Skills (`.claude/skills/`)

- **pixel-game-art** — how to draw, generate (PIL drawers), review and fix pixel art for the game:
  scale audit, big-shapes-first workflow, hue-shifted ramps, top-left light, tinted sel-out
  outlines, cluster texture, asymmetry/negative space, ground anchoring, growth lineages, sway
  strips, controlled variation, pipeline rules and a review checklist. Distilled from
  `docs/technical/TileArt.md`, `docs/Flora/flora.md` and `docs/Flora/pixelTips.md`. Use it for any
  sprite, tile, icon or art tool work.
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

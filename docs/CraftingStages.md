# Crafting by stage — benches, costs, and the found part

*Design chart, 2026-09-06 (user request). One main bench per stage; the next
bench costs the materials of the stage it unlocks plus one **found part** —
a piece of furniture the player has to locate, pick up and carry back — so
you explore the next band a little before you are fully equipped for it.
Companion to [Crafting.md](Crafting.md) (the generated recipe table).*

## How the found part works

- Every world object is already an item: hold LMB on a desk and it goes in
  the bag as `desk`. A recipe input can therefore name an object id directly
  (`{"item": "desk", "count": 1}`) — no new mechanic for the basic case.
- The part is **consumed** by the bench recipe. Scrapping it for its yields
  is the trap: the hover card should say "needed for the Forge" on parts.
- Each part is a dedicated object (`part: true`, `needed_for`, `band`, one
  district in `zones`) that `CityGen.place_parts` drops into that district's
  towers on floors of its band — so the "district" column is enforced by the
  generator, not by luck.

## Sideways first

Each part lives in ONE district, so the spine alone sends you across the
skyline before it sends you down: business (drafting table), residential
(stove), industrial (lathe, tool chest), construction (welding rig, toolbox),
civil (crash cart, hose reel, generator), commercial (dive tanks).

## Main benches (the spine)

| Stage | Band | Main bench | Crafted at | Cost (next stage's materials) | Found part | District | Unlocks |
|---|---|---|---|---|---|---|---|
| 0 · Rooftop | The Dry (roofs) | **Hands** | — | — | — | — | wood axe, wood block/wall, rope, ladder, chest, planter, bucket, tripod, the Workbench |
| 1 · Surface Survival | The Dry | **Workbench** | hands | 30 wood · 15 scrap metal | **Drafting Table** (`part_drafting_table`) | business | scrap tools, blocks, doors, lamps, glowsticks, Med Station, Weapon Bench, wood + metal scrap benches, the pot-belly stove |
| 2 · First Dives | The Shallows | **Forge** | Workbench | 10 stone · 20 scrap metal · 10 plastic | **Cast-Iron Stove** (`part_cast_stove`) | residential | scrap → iron smelting, Dive Station, Pump Works |
| 3 · Breaking Through | The Cold | **Machine Shop** ✱ | Forge | 20 iron · 20 scrap metal · 10 wood | **Engine Lathe** (`part_engine_lathe`) | industrial | iron knife, bolt cutters, iron scrap bench, Modification Bench |
| 4 · Deep Diving Gear | The Dark | **Steel Works** ✱ | Machine Shop | 30 iron · 20 stone · 10 plastic | **Welding Rig** (`part_welding_rig`) | construction | iron → steel, cutting torch, steel scrap bench |
| 5 · The Long Descent | The Crush | **Pressure Works** ✱ | Steel Works | 20 steel · 20 iron · 10 plastic | **Backup Generator** (`part_generator`) | civil | master scrap bench, tier-5 recipes |

✱ new bench. Stage 0 has no bench on purpose: the roof-locked opening stays
hand-crafting until the tripod gets you inside.

## Side benches (one stage each)

| Bench | Stage | Crafted at | Cost | Found part | District | Carries |
|---|---|---|---|---|---|---|
| Med Station | 1 · Dry | Workbench | 4 scrap metal · 4 plastic · 2 cloth | **Crash Cart** (`part_crash_cart`) | civil | bandages, medkits |
| Weapon Bench ✱ | 1 · Dry | Workbench | 20 wood · 20 scrap metal · 5 cloth | **Site Toolbox** (`part_site_toolbox`) | construction | every melee weapon, swords, spear gun, every ammo |
| Dive Station | 2 · Shallows | Forge | 6 scrap metal · 4 plastic · 4 cloth | **Dive Tanks** (`part_dive_tanks`) | commercial | suits, tanks, rebreather, hard suit |
| Pump Works ✱ | 2 · Shallows | Forge | 10 scrap metal · 10 plastic · 4 iron | **Hose Reel** (`part_hose_reel`) | civil | pump, standing lamp (wired lights) |
| Modification Bench | 3 · Cold | Machine Shop | 6 scrap metal · 4 wood · 4 iron | **Rolling Tool Chest** (`part_tool_chest`) | industrial | modifier library (learn / combine / apply) |
| Scrap benches (wood → master) | 1 → 5 | the stage's main bench | as before | none | — | bulk-grind furniture of that stage |

Every part is its own object with its own sprite (`tools/gen_parts_art.py`),
placed `PART_COPIES` (3) times per city in its district's towers on a floor of
its band, on free floor space. Parts scrap into the stage's materials if you
must, and the hover card warns you.

## Reading the chart

- **Cost follows the stage it unlocks, not the one you are in.** The Forge
  costs stone and plastic (Shallows materials) and a Stove from a flooded
  kitchen, so a Stage 1 player must dive once to build it. The Machine Shop
  costs iron, which only exists from The Cold down. The Steel Works costs no
  steel (it is what makes steel) but wants a Welding Cart from The Dark.
- **Each part is a one-tower trip, not a hunt.** Desks are everywhere; stoves
  are in every residential tower's kitchens; the industrial parts are one per
  industrial cluster floor or two. The hover card names the bench a part is
  for, and the map marks a picked-up part's tower.
- **Depletion holds (GL-28).** Nothing here adds iron above The Cold; the
  found parts are furniture that already scraps into the stage's material.

## Built 2026-09-06

Everything above is in the game: `tools/gen_parts_art.py` draws the ten parts,
the five new benches and the pot-belly stove (`assets/sprites/objects/`),
writes their objects and the bench recipes (each costing its part), and moves
the recipes to the stage benches; `CityGen.place_parts` drops `PART_COPIES`
of each part into its district's towers on a floor of its band; the hover
card names the bench a part builds. Also landed the same day: wing doors by
band (`FLOOR_DOOR_CHANCE`), the underwater scrapping penalty, and the stove.

## Original build list (kept for the record)

1. Three new station objects (`machine_shop`, `steel_works`, `pressure_works`)
   plus `weapon_bench` and `pump_works`: sprites via the Furniture Editor,
   `kind: station`, `station` keys added to `Data.STATIONS`.
2. Recipes: the bench recipes above (object ids as inputs), then move every
   recipe in `docs/Crafting.md` to its stage bench (the proposal at the bottom
   of that file lists the moves by type).
3. `depth_min` on the room templates that carry the Welding Cart and the
   Diesel Generator; a `needed_for` field on the five part objects so the
   hover card can say so.
4. Gates: `m1_smoke` (Workbench needs a desk), `m5_smoke` chain (Forge →
   Machine Shop → Steel Works → Pressure Works through play), `district_smoke`
   (each part spawns in its band).

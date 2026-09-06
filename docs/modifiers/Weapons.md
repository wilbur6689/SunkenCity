# District weapons — roster and build notes

*2026-09-05. The user's stage × district weapon tables, de-duplicated into a buildable roster.
Companion to [Modifiers.md](Modifiers.md) (found weapons are the modifier supply) and tracked as
Step 7 of [ModifiersChecklist.md](ModifiersChecklist.md). The source tables are kept verbatim in
§5 as the loot placement matrix.*

## 1. What the tables contain

| | Names in the tables | Unique | Already in `items.json` |
|---|---|---|---|
| Melee | 150 cells (30 × 5) | 57 | Hammer, Pry Bar, Bolt Cutters, Fire Axe (+ Scrap/Iron Knife, Scrap/Iron Sword, Wooden Axe, Cutting Torch as neighbours) |
| Ranged | 60 cells (30 × 2) | 38 | Pistol, SMG, Rifle, Speargun |
| Both lists | Compound Bow, Spear Gun | | |

**93 unique names** after merging the two lists. Fourteen are already items or near-items, so the
net new count is ~79 before any scope cut.

The distribution is deliberately repetitive: Crowbar sits in six cells, Rescue Saw in eight,
Demolition Hammer in seven. That is right for loot tables (the same item appears in several
district × band pools at different weights) and wrong for the item registry (one entry per name).
§4 is the registry view, §5 the loot view.

## 2. Rules the roster must obey

1. **No "Heavy".** It is a retired modifier word. "Forged Heavy Axe of the Ward" reads as two
   prefixes, and the title-length budget is already tight. The twelve *Heavy X* entries are renamed
   in §4 (Felling Axe, Pinch Bar, Mattock, Framing Nailer …). Checked: no other item name contains
   a modifier name from `Merged_Modifiers.json`.
2. **Shields are not weapons.** Ballistic Shield and Riot Shield have no attack; they are gear
   (an off-hand accessory with `defense`). Deferred out of this roster — see §6.
3. **Firearms stay found-only** (LT-18 canon) and **dead submerged** (LT-01). The Commercial ranged
   line is spear/harpoon guns for exactly that reason: they are the only ranged weapons that work
   below the waterline. Keep it that way.
4. **Melee from the roster is craftable at its tier's station.** The modifier loop needs blank
   weapons to craft (Modifiers.md "Craft a blank weapon"); a found-only melee roster would leave the
   Scrap/Iron Sword as the only canvases. Firearm blanks are the ~40 % of found pieces that roll
   clean (`ROLL_MOD_CHANCE` 0.6).
5. **Tool overlap uses the Fire Axe pattern**: a `tool` block (type/tier) plus a `weapon` block.
   Hammer, Pry Bar, Crowbar, Bolt Cutters, Hatchet, Pickaxe, Hydraulic Cutter and the knives all
   double as tools; knives keep the "least water-slowed" identity.
6. **One 16 px icon per item** (`assets/sprites/icons/<id>.png`). `icons/extra/` already holds a
   machete, combat knife and two swords from the Weapons sheet; the rest are Icon Editor work or a
   second sheet. Held-tool paper-doll sprites come from the icon.

## 3. Weapon classes and what code they need

| Class | Data | Code today | New work |
|---|---|---|---|
| Melee | `weapon.melee`, `damage`, `speed`, `knockback`, `water_factor` | done (swords, fire axe) | none — data only |
| Hitscan | `weapon.ammo`, `damage`, `speed`, `reload` | done (pistol/SMG/rifle) | **shotguns**: `pellets` + `spread` on the weapon block, one hitscan per pellet |
| Projectile | `weapon.projectile` = an ammo item id | speargun only (`SpearBolt`, retrievable) | generalise: per-projectile `speed`, `gravity`, `retrievable`; **bows / crossbows / nail and rivet guns / harpoon guns / flare gun** reuse it |
| Flare | projectile that becomes a dropped light | – | on landing, spawn a timed fog-beacon light (reuse the glowstick path) |

**Ammo set** (`category: ammo`): `pistol_rounds`, `rifle_rounds`, `speargun_bolt` exist; add
`shotgun_shells`, `arrows` (retrievable), `crossbow_bolts` (retrievable), `nails` (not),
`rivets` (not), `flares` (not), `harpoon` (retrievable, heavy). The .22 Rifle and Pellet Gun are
folded onto `pistol_rounds` at low damage rather than adding two more ammo types.

**Stat identity by district** (the modifier families point the same way): Industrial hits
hardest, Construction knocks back and demolishes fastest, Business swings fastest, Commercial
works underwater, Civil is the balanced all-rounder, Residential is cheap and common.

## 4. Roster (registry view)

Bands = first–last band the name appears in. Districts in order of first appearance.
`Ind Con Bus Res Com Civ`. Renamed entries show the table name in brackets.

### Melee (55 after the shield cut and one merge)

| Name | id | Class / tool | Bands | Districts |
|---|---|---|---|---|
| Baseball Bat | `baseball_bat` | blunt | 1 | Res Com |
| Baton | `baton` | blunt | 1 | Civ |
| Bolt Cutters | `bolt_cutters` | exists (pry 2) | 1–3 | Con Civ |
| Crowbar | `crowbar` | pry 2 | 1–3 | Ind Civ Bus Com Res |
| Desk Leg | `desk_leg` | blunt | 1 | Bus |
| Fire Axe | `fire_axe` | exists (axe 1) | 1–3 | Civ Bus Res |
| Fire Extinguisher | `fire_extinguisher` | blunt, slow | 1 | Bus |
| Fireplace Poker | `fireplace_poker` | pierce | 1 | Res |
| Halligan Tool | `halligan_tool` | pry 2 + blunt | 1–5 | Civ |
| Hammer | `hammer` | exists (hammer 1) | 1 | Ind Con Res Com |
| Hatchet | `hatchet` | axe 1 | 1–2 | Ind Res Com |
| Kitchen Knife | `kitchen_knife` | knife 1 | 1 | Res |
| Letter Opener | `letter_opener` | knife 1 | 1 | Bus |
| Machete | `machete` | blade (icon exists) | 1–2 | Com Res |
| Nail Puller | `nail_puller` | pry 1 | 1 | Con |
| Paper Cutter | `paper_cutter` | blade, slow | 1 | Bus |
| Pipe Wrench | `pipe_wrench` | blunt | 1–2 | Ind |
| Pry Bar | `pry_bar` | exists (pry 1) | 1 | Ind Con |
| Rebar Club | `rebar_club` | blunt | 1–2 | Con |
| Rescue Axe | `rescue_axe` | axe 1 | 1–3 | Civ |
| Stapler | `stapler` | blunt, joke-tier | 1 | Bus |
| Utility Knife | `utility_knife` | knife 1 | 1 | Com |
| Boarding Axe | `boarding_axe` | axe 2, good in water | 2–5 | Com |
| Breaching Tool | `breaching_tool` | pry 2 + blunt | 2–5 | Bus |
| Demolition Hammer | `demolition_hammer` | hammer 3, powered | 2–5 | Con Ind Res |
| Security Flashlight *(Heavy Flashlight)* | `security_flashlight` | blunt + `light` | 2–3 | Bus |
| Lump Hammer *(Heavy Hammer)* | `lump_hammer` | hammer 2 | 2 | Res |
| Cane Machete *(Heavy Machete)* | `cane_machete` | blade | 2–3 | Com |
| Pickaxe | `pickaxe` | pierce, hammer 2 | 2–3 | Ind Con Res Com |
| Rescue Saw | `rescue_saw` | powered blade | 2–5 | Ind Bus Civ |
| Riot Baton | `riot_baton` | blunt, fast | 2–4 | Bus Civ |
| Sledgehammer | `sledgehammer` | blunt, hammer 2 | 2–4 | Ind Con |
| Spear | `spear` | pierce, best in water | 2–5 | Com Res |
| Splitting Maul | `splitting_maul` | axe 2 + blunt | 2–4 | Ind Res |
| Breaching Hammer | `breaching_hammer` | hammer 3 | 3 | Ind Con Civ |
| Dive Knife | `dive_knife` | knife 2, water 0.9 | 3–5 | Com |
| Harpoon | `harpoon` | pierce, water 0.9 | 3–4 | Com |
| Felling Axe *(Heavy Axe)* | `felling_axe` | axe 3 | 3–5 | Ind Bus Res |
| Pinch Bar *(Heavy Crowbar)* | `pinch_bar` | pry 3 | 3 | Con |
| Broad Hatchet *(Heavy Hatchet)* | `broad_hatchet` | axe 2 | 3 | Res |
| Hunting Knife | `hunting_knife` | knife 3 | 3–5 | Res |
| Industrial Cutter | `industrial_cutter` | powered blade | 3 | Ind |
| Breaching Sledge | `breaching_sledge` | blunt, hammer 3 | 4–5 | Con Civ |
| Mattock *(Heavy Pickaxe)* | `mattock` | pierce, hammer 3 | 4 | Con |
| Hydraulic Cutter | `hydraulic_cutter` | pry 3, powered | 4–5 | Ind Con |
| Industrial Saw | `industrial_saw` | powered blade | 4–5 | Ind |
| Pole Hook | `pole_hook` | pierce, reach | 4–5 | Con Com |
| Rescue Spreader | `rescue_spreader` | pry 3, powered | 4–5 | Civ Ind |
| Breaching Maul | `breaching_maul` | blunt, hammer 3 | 5 | Ind Con |
| Shock Baton *(Heavy Baton)* | `shock_baton` | blunt, fast | 5 | Bus |
| Whaling Harpoon *(Heavy Harpoon)* | `whaling_harpoon` | pierce, water 0.9 | 5 | Com |
| Tactical Axe | `tactical_axe` | axe 3 | 5 | Bus |

Merged: *Heavy Sledge* (Con T5) folds into Breaching Sledge — the cell already had Breaching Maul.
Cut to gear: *Ballistic Shield* (Bus 4–5), *Riot Shield* (Civ 4–5). Compound Bow and Spear Gun
move to the ranged list.

### Ranged (38)

| Name | id | Class / ammo | Bands | Districts |
|---|---|---|---|---|
| .22 Rifle | `rifle_22` | hitscan, pistol_rounds | 1 | Res |
| Compact Pistol | `compact_pistol` | hitscan, pistol_rounds | 1 | Bus |
| Compound Bow | `compound_bow` | projectile, arrows | 1–5 | Com Con Res |
| Crossbow | `crossbow` | projectile, crossbow_bolts | 1–2 | Con Com |
| Flare Gun | `flare_gun` | projectile, flares (light) | 1 | Ind Civ |
| Hunting Rifle | `hunting_rifle` | hitscan, rifle_rounds | 1–3 | Res Ind |
| Nail Gun | `nail_gun` | projectile, nails | 1–3 | Ind Con |
| Pellet Gun | `pellet_gun` | hitscan, pistol_rounds, weak | 1 | Com |
| Revolver | `revolver` | hitscan, pistol_rounds | 1 | Bus |
| Service Pistol | `service_pistol` | hitscan, pistol_rounds | 1–2 | Civ |
| 9mm Pistol | `pistol` | exists | 2 | Bus |
| Compact SMG | `smg` | exists | 2–3 | Bus |
| Patrol Shotgun | `patrol_shotgun` | shotgun, shells | 2 | Civ |
| Pump Shotgun | `pump_shotgun` | shotgun, shells | 2–3 | Res |
| Rivet Gun | `rivet_gun` | projectile, rivets | 2 | Ind |
| Spear Gun | `speargun` | exists (projectile) | 2–5 | Com |
| Bolt-Action Rifle | `rifle` | exists → rename | 3–4 | Res Con |
| Harpoon Gun | `harpoon_gun` | projectile, harpoon | 3–4 | Com |
| Compound Crossbow *(Heavy Crossbow)* | `compound_crossbow` | projectile, crossbow_bolts | 3–5 | Con |
| Patrol Rifle | `patrol_rifle` | hitscan, rifle_rounds | 3 | Civ |
| Riot Shotgun | `riot_shotgun` | shotgun, shells | 3 | Civ |
| Tactical Pistol | `tactical_pistol` | hitscan, pistol_rounds | 3–5 | Bus |
| Assault Carbine | `assault_carbine` | hitscan, rifle_rounds, auto | 4 | Civ |
| Framing Nailer *(Heavy Nail Gun)* | `framing_nailer` | projectile, nails | 4 | Ind |
| Hunting Magnum | `hunting_magnum` | hitscan, rifle_rounds | 4–5 | Res |
| Machine Pistol | `machine_pistol` | hitscan, pistol_rounds, auto | 4 | Bus |
| Semi-Auto Rifle | `semi_auto_rifle` | hitscan, rifle_rounds | 4 | Ind |
| Semi-Auto Shotgun | `semi_auto_shotgun` | shotgun, shells | 4 | Res |
| Tactical Carbine | `tactical_carbine` | hitscan, rifle_rounds, auto | 4 | Bus |
| Tactical Shotgun | `tactical_shotgun` | shotgun, shells | 4 | Civ |
| Battle Rifle | `battle_rifle` | hitscan, rifle_rounds | 5 | Ind |
| Combat Shotgun | `combat_shotgun` | shotgun, shells, auto | 5 | Civ |
| Designated Marksman Rifle | `dmr` | hitscan, rifle_rounds | 5 | Civ |
| Whaling Gun *(Heavy Harpoon Gun)* | `whaling_gun` | projectile, harpoon | 5 | Com |
| Industrial Rivet Gun | `industrial_rivet_gun` | projectile, rivets | 5 | Ind |
| Marksman Rifle | `marksman_rifle` | hitscan, rifle_rounds | 5 | Con |
| Military Carbine | `military_carbine` | hitscan, rifle_rounds, auto | 5 | Bus |
| Sniper Rifle | `sniper_rifle` | hitscan, rifle_rounds, slow | 5 | Res |

## 5. Loot placement matrix

The two source tables, unchanged except for the renames in §4 and the shield cut. Each cell
becomes weighted `found` entries in `data/loot.json` under `tables.<district>.<band>`. Suggested
weights: 3 for the cell's first-listed melee, 2 for the rest, 2 per ranged weapon; firearms carry
`found_only` so no recipe can output them.

### Melee

| Band | Industrial | Construction | Business | Residential | Commercial | Civil |
|---|---|---|---|---|---|---|
| T1 Dry | Hammer, Hatchet, Crowbar, Pipe Wrench, Pry Bar | Hammer, Pry Bar, Nail Puller, Bolt Cutters, Rebar Club | Letter Opener, Stapler, Paper Cutter, Desk Leg, Fire Extinguisher | Kitchen Knife, Baseball Bat, Hatchet, Hammer, Fireplace Poker | Machete, Hatchet, Hammer, Baseball Bat, Utility Knife | Fire Axe, Rescue Axe, Baton, Crowbar, Halligan Tool |
| T2 Shallows | Sledgehammer, Pipe Wrench, Splitting Maul, Pickaxe, Rescue Saw | Sledgehammer, Bolt Cutters, Pickaxe, Rebar Club, Demolition Hammer | Riot Baton, Fire Axe, Crowbar, Security Flashlight, Breaching Tool | Splitting Maul, Hatchet, Machete, Pickaxe, Lump Hammer | Boarding Axe, Spear, Cane Machete, Pickaxe, Crowbar | Rescue Axe, Halligan Tool, Riot Baton, Bolt Cutters, Crowbar |
| T3 Cold | Breaching Hammer, Felling Axe, Rescue Saw, Sledgehammer, Industrial Cutter | Breaching Hammer, Demolition Hammer, Pinch Bar, Pickaxe, Bolt Cutters | Riot Baton, Breaching Tool, Fire Axe, Rescue Saw, Security Flashlight | Hunting Knife, Fire Axe, Pickaxe, Broad Hatchet, Crowbar | Spear, Boarding Axe, Dive Knife, Harpoon, Cane Machete | Halligan Tool, Rescue Axe, Riot Baton, Breaching Hammer, Rescue Saw |
| T4 Dark | Industrial Saw, Demolition Hammer, Sledgehammer, Hydraulic Cutter, Felling Axe | Breaching Sledge, Hydraulic Cutter, Demolition Hammer, Mattock, Pole Hook | Breaching Tool, Riot Baton, Rescue Saw, Felling Axe | Hunting Knife, Splitting Maul, Felling Axe, Spear | Harpoon, Dive Knife, Boarding Axe, Pole Hook | Breaching Sledge, Halligan Tool, Rescue Spreader, Rescue Saw |
| T5 Crush | Hydraulic Cutter, Industrial Saw, Demolition Hammer, Breaching Maul, Rescue Spreader | Breaching Maul, Hydraulic Cutter, Demolition Hammer, Breaching Sledge, Pole Hook | Breaching Tool, Rescue Saw, Shock Baton, Tactical Axe | Hunting Knife, Felling Axe, Spear, Demolition Hammer | Whaling Harpoon, Dive Knife, Boarding Axe, Pole Hook | Rescue Spreader, Breaching Sledge, Halligan Tool, Rescue Saw |

Removed from the melee cells: Ballistic Shield and Riot Shield (gear, §6), Compound Bow and Spear
Gun (ranged table). Heavy Sledge merged into Breaching Sledge.

### Ranged

| Band | Industrial | Construction | Business | Residential | Commercial | Civil |
|---|---|---|---|---|---|---|
| T1 Dry | Nail Gun, Flare Gun | Nail Gun, Crossbow | Compact Pistol, Revolver | Hunting Rifle, .22 Rifle | Compound Bow, Pellet Gun | Flare Gun, Service Pistol |
| T2 Shallows | Rivet Gun, Nail Gun | Crossbow, Compound Bow | 9mm Pistol, Compact SMG | Pump Shotgun, Hunting Rifle | Spear Gun, Crossbow | Patrol Shotgun, Service Pistol |
| T3 Cold | Nail Gun, Hunting Rifle | Compound Crossbow, Compound Bow | Tactical Pistol, Compact SMG | Bolt-Action Rifle, Pump Shotgun | Harpoon Gun, Spear Gun | Patrol Rifle, Riot Shotgun |
| T4 Dark | Framing Nailer, Semi-Auto Rifle | Compound Crossbow, Bolt-Action Rifle | Machine Pistol, Tactical Carbine | Hunting Magnum, Semi-Auto Shotgun | Harpoon Gun, Spear Gun | Assault Carbine, Tactical Shotgun |
| T5 Crush | Industrial Rivet Gun, Battle Rifle | Compound Crossbow, Marksman Rifle | Tactical Pistol, Military Carbine | Hunting Magnum, Sniper Rifle | Whaling Gun, Spear Gun | Designated Marksman Rifle, Combat Shotgun |

Residential T4–T5 and Commercial T4–T5 also list Compound Bow and Spear Gun in the source melee
cells; they count as extra ranged entries there.

## 6. Scope recommendation

**Shipped 2026-09-05: the full roster** (user's call) — 55 melee, 38 ranged, 7 ammo, generated by
`tools/gen_weapons.py` (data) and `tools/gen_weapon_icons.py` (16 px icons; existing icons are
never overwritten). Stats come from the per-band × per-class tables in the generator; tune there.
Shields stay deferred; auto-fire is not a flag (every gun fires while held at its `speed`).

Ninety-three items is a big art and balance bill against a design whose stated principle is
"weapons stay simple; modifiers are the deep system". Two cuts to choose between before Step 7
starts:

- **Launch cut (recommended): 36 items** — per district, its three most distinctive melee across
  the bands and its two ranged lines. Everything else in §4 stays authored in this doc as the
  post-launch content patch. Example picks: Industrial = Pipe Wrench, Sledgehammer, Hydraulic
  Cutter + Nail Gun, Battle Rifle; Commercial = Machete, Boarding Axe, Whaling Harpoon + Compound
  Bow, Harpoon Gun; Civil = Halligan Tool, Rescue Axe, Rescue Spreader + Service Pistol, Combat
  Shotgun.
- **Full roster**: all 93, icons batched through the Icon Editor, stats generated from a per-band
  table and hand-tuned only for outliers.

Either way the shields, the flare-gun light and the shotgun spread are the only new mechanics;
everything else is data plus icons.

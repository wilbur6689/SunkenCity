# SunkenCity — Open Design Questions

Companion to [GameOverview.md](GameOverview.md). Each major section of the overview has 30 open
questions to be answered via `/guided-review` sessions, one section at a time.

**How to use:** run `/guided-review docs/OpenQuestions.md` and pick a section. When a question is
answered, check its box and record the decision on an indented **A:** line beneath it. Decisions
get folded back into `GameOverview.md` and the `technical/` docs as sections complete.

- `[ ]` = open `[x]` = answered `[~]` = deferred (tracked for later)

---

## 1. Core Concept & Setting (CC) — ✅ Reviewed 2026-08-30

- [x] **CC-01.** Is "TowerDive" the final title, or a working title?
  - **A:** **SunkenCity** is the working title (repo renamed to match). Final title decision flagged for before any public release.
- [x] **CC-02.** What is the tone — grim survival horror, pulpy adventure, or something lighter?
  - **A:** Tense survival with moments of dread in the deep (darkness, oxygen anxiety, muffled sound); surface/base life stays almost cozy. Core focus: **crafting survival**.
- [x] **CC-03.** What caused the flood — natural disaster, zombie-outbreak fallout, or a deliberate act?
  - **A:** The city was **deliberately flooded** in a failed attempt to contain the zombie virus.
- [~] **CC-04.** Is there a narrative/lore layer explaining the apocalypse, or is the story purely environmental?
  - **A:** Deferred — story development resumes after the MVP and basic game loop are complete.
- [x] **CC-05.** Are there other living survivors or NPCs in the city (traders, quest-givers, rivals)?
  - **A:** No living NPCs in the MVP. Design slot reserved for traders/survivor enclave post-MVP.
- [x] **CC-06.** Single-player only, or is co-op/multiplayer planned (even long-term)?
  - **A:** **LAN multiplayer** (not couch co-op), built in from the beginning — core systems use Godot's multiplayer authority model from day one; one player hosts.
- [x] **CC-07.** What happens on death — permadeath, item drop, respawn penalty?
  - **A:** Backpack drop — inventory (not equipped gear) drops at the death point. The backpack **slowly floats upward unless it hits a ceiling** (dying in a flooded room pins the pack to that room's ceiling); unobstructed packs eventually bob at the surface.
- [x] **CC-08.** Where does the player respawn — a bed/base spawn point like Terraria?
  - **A:** Respawn at base/spawn point. How spawn points are set/moved: see GL-23.
- [x] **CC-09.** Is the world persistent across sessions with a single save per world?
  - **A:** Terraria model: **world saves and character saves are separate**. Any player can keep a world file locally and launch it single-player or host it for LAN; characters choose which world to join.
- [x] **CC-10.** Is the world finite or effectively infinite horizontally?
  - **A:** **Finite bounded city** — a fixed number of tower columns per seed, edged by open ocean. Skyline profile: see CC-28.
- [x] **CC-11.** Is there a day/night cycle, and does it change gameplay?
  - **A:** Yes — day/night with real gameplay meaning on the surface (darkness, riskier swimming, activity changes). See also CC-14 (red moon).
- [x] **CC-12.** Is there weather (storms, fog, rain), and does it affect the water or visibility?
  - **A:** Light weather — rain/fog ambience plus occasional **mechanical storms** (rough surface water, reduced visibility). Post-MVP.
- [x] **CC-13.** Is the water level static, or can it change (tides, storms, player draining)?
  - **A:** Water is **tile-based and behaves like any other block except it flows downward** and settles (cellular simulation). Pumps will move water from one area to another. The global waterline can fall through gameplay (endgame drain). Details: `technical/WaterPhysics.md`.
- [x] **CC-14.** Is there a recurring time-pressure event like 7DtD's horde night?
  - **A:** **Red moon zombie waves every random 5–10 days.** Red moon mechanics to be designed later (Game Dangers section / dedicated pass).
- [x] **CC-15.** Are hunger and thirst survival mechanics included?
  - **A:** No hunger/thirst meters. Food exists for **healing and buffs only**.
- [x] **CC-16.** Are temperature/wetness/cold mechanics included (especially at depth)?
  - **A:** Cold as a **depth mechanic**, not a meter — below depth thresholds players take a slowing debuff (then damage) without the right suit tier. Pairs with pressure (GL-12).
- [x] **CC-17.** Is there character customization (appearance, starting loadout)?
  - **A:** Very light cosmetics at creation: **shirt color, pants color, hair color**. No stat choices.
- [x] **CC-18.** Is player progression gear-only, or are there also levels/skills/attributes?
  - **A:** Gear-first with **learn-by-doing skills**. Skills level individually by use; **player level = total skill levels ÷ 5** (level 5 in 3 skills → player level 3). Each player level grants **1 point in a separate ability tech tree** that unlocks new player abilities (not skill boosts). Tech tree contents: future design topic.
- [x] **CC-19.** What is the target total playtime for a full run (reach ground + drain city)?
  - **A:** **60–100 hours** for a full first run.
- [x] **CC-20.** Will there be difficulty settings, and what do they change?
  - **A:** None in MVP — one tuned baseline. Later: **world-creation toggles** (enemy strength, backpack-drop rules, red moon frequency), not global presets.
- [x] **CC-21.** What platforms are targeted first (PC/Steam?), and is controller support required at launch?
  - **A:** PC/Steam first; keyboard+mouse for MVP; **controller support added when pushing to Steam**. Use Godot input actions from day one to keep that retrofit cheap.
- [x] **CC-22.** What is the art direction beyond pixel scale — palette, color mood, lighting style?
  - **A:** Moody-but-readable pixel art. Desaturated blues/greens deepening to near-black with depth; warm oranges reserved for safety (interiors, bases, surface dusk). **Warm = safe, cold = deep = dangerous.**
- [x] **CC-23.** What is the audio direction — ambient dread, chiptune, realistic underwater muffling?
  - **A:** **Diegetic-first with depth-adaptive layers** — sparse ambient music, muffled/low-passed underwater soundscape, vertical layering for tension; stingers for red moons and storms.
- [~] **CC-24.** How is the player onboarded — tutorial island/rooftop, contextual hints, or none?
  - **A:** Deferred until the Steam early-access release.
- [x] **CC-25.** Is there a map or minimap, and does it fill in as the player explores?
  - **A:** **Fog-of-war world map revealed by exploration**, tracked per character. Lives as a top-right corner minimap for now.
- [x] **CC-26.** Mechanically, how does "draining the city" work at the endgame?
  - **A:** Restore the city's **mega-pump infrastructure** — a central ground-level station plus relay stations at depth intervals; each restored relay drains a horizontal band of the city, lowering the waterline in stages, "like a massive bathtub drain."
- [x] **CC-27.** What happens after the city is drained — credits, sandbox continues, new threats?
  - **A:** **Ending + freeplay** — credits roll and the world is flagged complete; play continues in the drained world but no new content appears.
- [x] **CC-28.** One city per world, or multiple cities/worlds per save?
  - **A:** **One city per world**; a fresh city = a new world/seed. Skyline is a bell curve: largest towers in the center, buildings shorter and gaps wider toward the edges, most outer buildings entirely below the waterline, large open-water areas at the map edges.
- [x] **CC-29.** Are alternate modes planned (creative/build mode, hardcore)?
  - **A:** **Survival only, ever.** No creative or hardcore modes.
- [x] **CC-30.** What is the scope target — small commercial release, hobby project, demo-first?
  - **A:** Staged roadmap: **1)** MVP local single-player → **2)** LAN multiplayer (architecture present from day one per CC-06) → **3)** demo-first commercial release on Steam → **4)** full commercial release.

---

## 2. World Scale & Character (WS)

- [ ] **WS-01.** What is the base game resolution and camera zoom (e.g., 640×360 viewport scaled up)?
- [ ] **WS-02.** How wide is the character sprite in pixels (hitbox vs visual)?
- [ ] **WS-03.** What are the movement speeds — walk, sprint, surface swim, underwater swim?
- [ ] **WS-04.** How high can the player jump, in blocks?
- [ ] **WS-05.** Can the player crouch/crawl through gaps smaller than their standing height?
- [ ] **WS-06.** How does underwater movement control — free 8-directional swim, or gravity-biased?
- [ ] **WS-07.** How does surface swimming differ from being underwater (treading, faster lateral movement)?
- [ ] **WS-08.** What is the baseline oxygen duration in seconds at game start?
- [ ] **WS-09.** Does the player float upward automatically (buoyancy), and can gear change that?
- [ ] **WS-10.** Does carried weight/gear affect swim and dive speed?
- [ ] **WS-11.** How tall is a standard building floor in blocks (e.g., 6 blocks = 12 ft)?
- [ ] **WS-12.** What is the player's interaction/mining reach in blocks?
- [ ] **WS-13.** How many inventory slots does the player have, and does it expand?
- [ ] **WS-14.** Is there a weight/encumbrance system on top of slot limits?
- [ ] **WS-15.** Is there fall damage, and does water entry from height cause damage?
- [ ] **WS-16.** What traversal aids exist — ladders, ropes, stairs, grappling hooks?
- [ ] **WS-17.** How does lighting work — darkness underwater/indoors, placeable and carried lights?
- [ ] **WS-18.** How should the camera behave — lookahead when swimming, zoom changes underwater?
- [ ] **WS-19.** Character controller: `CharacterBody2D` with custom water states, or fully custom physics?
- [ ] **WS-20.** Are there foreground blocks and background walls as separate tile layers (Terraria-style)?
- [ ] **WS-21.** Can the player place and remove background walls?
- [ ] **WS-22.** Do blocks have HP/hardness tiers requiring better tools to break?
- [x] **WS-23.** How is water simulated — cellular per-tile flow, region/volume-based, or hybrid?
  - **A:** (From CC-13) Cellular per-tile flow — water is a block-like tile that flows downward and settles. Details: `technical/WaterPhysics.md`.
- [ ] **WS-24.** Does placing/removing blocks displace or release water in real time?
- [ ] **WS-25.** How are sprites structured — is hair a separate layer over the 21px body?
- [ ] **WS-26.** Is equipped gear (armor, dive suit) visible on the character sprite?
- [ ] **WS-27.** What animation set is needed at minimum (idle, walk, swim, dive, attack, hurt, death)?
- [ ] **WS-28.** What Godot rendering settings ensure crisp pixel art (snapping, filtering, scaling mode)?
- [ ] **WS-29.** Should there be screen-space water effects (distortion, color grading by depth)?
- [ ] **WS-30.** What unit conventions should the technical docs standardize (blocks vs pixels vs feet)?

---

## 3. Main Game Loop (GL)

- [ ] **GL-01.** What exactly gates each stage transition — gear thresholds only, or also milestones/quests?
- [ ] **GL-02.** What is the exact starting scenario — waking on a rooftop, adrift on debris, a wrecked boat?
- [ ] **GL-03.** What are the first craftable tools, and from what starter materials?
- [ ] **GL-04.** Is crafting done by hand anywhere, at stations, or both (tiered)?
- [ ] **GL-05.** What crafting stations exist (workbench, forge, chem station, dive station)?
- [ ] **GL-06.** Are recipes known from the start, unlocked by finding items, or learned from schematics?
- [ ] **GL-07.** How does scrapping work — anywhere from inventory, or requiring a tool/station?
- [ ] **GL-08.** What are the tool/material tiers (e.g., scrap → iron → steel → titanium)?
- [ ] **GL-09.** How are locked doors opened — lockpicks, keys, breaching tools, cutting torches?
- [ ] **GL-10.** What is the oxygen upgrade path (lungs training, air tanks, rebreathers)?
- [ ] **GL-11.** What are the dive gear tiers (mask/fins → wetsuit → hard suit), and what does each unlock?
- [ ] **GL-12.** Is there a pressure mechanic that blocks depth until the right suit, separate from oxygen?
- [ ] **GL-13.** How does the player manage light underwater (glowsticks, dive lamps, base lighting)?
- [ ] **GL-14.** What does a functional base require (bed, storage, crafting, cooking, defenses)?
- [ ] **GL-15.** Do zombies or other threats ever attack the player's base?
- [x] **GL-16.** Can players drain individual rooms/floors mid-game (pumps, patching breaches)?
  - **A:** (From CC-13) Yes — craftable pumps move water from one area to another; patching breaches plus pumping drains rooms/floors.
- [ ] **GL-17.** Can players create air pockets or airlocks as forward dive bases?
- [ ] **GL-18.** Is there fast travel or shortcuts between buildings (ziplines, rope bridges, teleports)?
- [ ] **GL-19.** Are there vehicles (rafts, boats, submersibles), and at what stage?
- [ ] **GL-20.** What is the food loop — fishing, looted canned goods, farming, cooking?
- [ ] **GL-21.** How does healing work — regen, bandages/medkits, food-based?
- [ ] **GL-22.** What does the player lose on death (nothing, inventory, backpack drop to recover)?
- [ ] **GL-23.** How are respawn points set and moved?
- [ ] **GL-24.** Is there an XP/skill system layered on gear progression, or gear-only (per CC-18)?
- [ ] **GL-25.** Are there explicit quests/objectives, or purely emergent goals?
- [ ] **GL-26.** What physically triggers the endgame drain (machine, pump network, story device)?
- [ ] **GL-27.** Roughly how long should each of the five stages last for a typical player?
- [ ] **GL-28.** Besides loot, what pulls the player downward (signals, story breadcrumbs, visible landmarks)?
- [ ] **GL-29.** Are there failure states other than death (base destroyed, flooded base)?
- [ ] **GL-30.** Is there replay support — new game plus, world regeneration, harder seeds?

---

## 4. Game Dangers (GD)

- [ ] **GD-01.** What zombie variants exist (walker, crawler, bloated floater, armored)?
- [ ] **GD-02.** How do zombies spawn — placed at world-gen, dynamic spawning, or both?
- [ ] **GD-03.** Do zombies respawn in cleared buildings, and on what timer?
- [ ] **GD-04.** How smart is zombie AI — pathfinding, breaking blocks/doors, climbing?
- [ ] **GD-05.** How do floating zombies behave — surface hazards drifting between buildings?
- [ ] **GD-06.** What senses do enemies use (sight cones, sound, blood in water)?
- [ ] **GD-07.** What is the combat model — melee-focused, ranged, or balanced mix?
- [ ] **GD-08.** How do weapons behave underwater (guns disabled? spearguns? slowed melee)?
- [ ] **GD-09.** How are small fish caught — rod, net, spear, by hand?
- [ ] **GD-10.** What large fish species exist, and what are their attack behaviors?
- [ ] **GD-11.** Where do sharks live — open water between buildings, specific depth bands?
- [ ] **GD-12.** What triggers shark aggression (blood from injury, splashing, proximity)?
- [ ] **GD-13.** What are mutants, lore-wise — mutated humans, sea life, or something else?
- [ ] **GD-14.** What abilities do mutants have (ranged attacks, ambush, camouflage, grabs)?
- [ ] **GD-15.** Are there boss enemies, and are they tied to depth zones or locations?
- [ ] **GD-16.** Should depth be formalized into named danger zones/tiers (e.g., every N floors)?
- [ ] **GD-17.** What environmental hazards exist (live wires, gas pockets, collapsing debris)?
- [ ] **GD-18.** Is darkness itself a danger (enemies stronger in dark, sanity/visibility)?
- [ ] **GD-19.** Is there pressure or cold damage at depth, distinct from oxygen (per GL-12)?
- [ ] **GD-20.** How does drowning damage work once oxygen runs out (rate, recovery)?
- [ ] **GD-21.** What status effects exist (bleeding, poison, infection, hypothermia)?
- [ ] **GD-22.** Can zombies infect the player, and is there a cure mechanic?
- [ ] **GD-23.** What is the difficulty scaling formula with depth (HP/damage multipliers, new types)?
- [ ] **GD-24.** Do enemies drop loot, and is it distinct from container loot?
- [ ] **GD-25.** Is stealth/avoidance a viable playstyle (sneaking past dry-floor zombies)?
- [ ] **GD-26.** Is there a noise system where actions (mining, gunfire) attract enemies?
- [ ] **GD-27.** How is enemy density tuned per stage so early game isn't overwhelming?
- [ ] **GD-28.** Are there passive/neutral creatures beyond small fish (ambience, secondary resources)?
- [ ] **GD-29.** Does danger on the surface change at night (per CC-11)?
- [ ] **GD-30.** What fills the "other" slot — rival survivors, security systems, drones, sea monsters?

---

## 5. Loot: Weapons, Armor & Tools (LT)

- [ ] **LT-01.** What is the full base weapon list at launch?
- [ ] **LT-02.** What weapon categories exist (melee, ranged, underwater-specific like spearguns)?
- [ ] **LT-03.** What armor slots exist (head, chest, legs, accessory slots)?
- [ ] **LT-04.** What is the tool list (pry bar, pickaxe, hatchet, cutting torch, lockpicks)?
- [ ] **LT-05.** What stat-modifying **prefixes** exist, with examples (e.g., "Sharp", "Rusty")?
- [ ] **LT-06.** What stat-modifying **suffixes** exist, with examples (e.g., "of the Deep")?
- [ ] **LT-07.** Can one item roll both a prefix and a suffix, or only one?
- [ ] **LT-08.** Are there rarity tiers, and how do they interact with modifiers (colors, roll counts)?
- [ ] **LT-09.** Can modifiers be rerolled/reforged, and at what cost?
- [ ] **LT-10.** Do modifiers roll only on found loot, or on crafted items too?
- [ ] **LT-11.** How is the balance set between crafted gear and found gear (which is better when)?
- [ ] **LT-12.** What loot container types exist (cabinets, desks, safes, submerged crates)?
- [ ] **LT-13.** How are loot tables structured — by building type, by depth, or both?
- [ ] **LT-14.** Are some containers locked, requiring tools/keys from GL-09?
- [ ] **LT-15.** Is there item durability, and how does repair work?
- [ ] **LT-16.** What ammo types exist, and how scarce is ammo?
- [ ] **LT-17.** What consumables exist (medkits, O2 refills, buff foods, flares)?
- [ ] **LT-18.** Are there accessories/trinkets with passive effects (swim speed, O2 bonus)?
- [ ] **LT-19.** Are there unique/legendary named items with fixed special effects?
- [ ] **LT-20.** What item stats exist overall (damage, attack speed, crit, knockback, reach)?
- [ ] **LT-21.** What armor stats exist (defense, O2 capacity, swim speed, warmth, pressure rating)?
- [ ] **LT-22.** Are there armor set bonuses for wearing matched pieces?
- [ ] **LT-23.** How does storage work — base chests, item stacking rules, sorting?
- [ ] **LT-24.** Is there a currency/trading economy (per CC-05), or pure barter/scrap value?
- [ ] **LT-25.** Are there material quality tiers within a category (scrap metal vs steel vs titanium)?
- [ ] **LT-26.** Can gear be salvaged back into raw materials, and at what return rate?
- [ ] **LT-27.** Does looted-out loot respawn, or is each container one-time?
- [ ] **LT-28.** What is the depth-based loot quality curve (how fast does loot improve going down)?
- [ ] **LT-29.** Do blueprints/schematics drop as loot to unlock recipes (per GL-06)?
- [ ] **LT-30.** What equipment does the player start with, if anything?

---

## 6. The City & World Generation (CT)

- [ ] **CT-01.** How big is the city — number of buildings, world width, and depth to ground in blocks?
- [ ] **CT-02.** What building types exist (residential, office, hospital, police, mall, industrial)?
- [ ] **CT-03.** Do building types drive their loot tables and enemy types?
- [ ] **CT-04.** How are buildings generated — hand-made templates with variation, or fully procedural?
- [ ] **CT-05.** How are interiors laid out (rooms, corridors, stairwells, elevator shafts)?
- [ ] **CT-06.** Are elevator shafts usable as vertical traversal routes (or even repairable)?
- [ ] **CT-07.** Is there anything below street level (subways, parking garages, sewers)?
- [ ] **CT-08.** Are the streets at ground level explorable terrain with their own content?
- [ ] **CT-09.** What is between buildings — open water only, or debris, wrecks, and ruins?
- [ ] **CT-10.** Are there skybridges or collapsed structures connecting towers?
- [ ] **CT-11.** What rules govern breach/hole generation in buildings (frequency, size, location)?
- [ ] **CT-12.** How is flooding determined — purely by breach connectivity, or partly authored?
- [ ] **CT-13.** How are air pockets generated in flooded floors (sealed rooms holding air)?
- [ ] **CT-14.** What is the block palette per building — wood/stone variants only, or also concrete, glass, metal?
- [ ] **CT-15.** Are glass windows distinct breakable blocks (the "openings" of stage one)?
- [ ] **CT-16.** Are furniture and props placed as scrappable objects, tiles, or both?
- [ ] **CT-17.** Is there structural integrity (unsupported blocks collapse, 7DtD-style)?
- [ ] **CT-18.** Can the player destroy any block, or are structural frames protected?
- [ ] **CT-19.** Is there an unbreakable boundary layer (bedrock equivalent at city floor/edges)?
- [ ] **CT-20.** Are there hand-designed landmark buildings with unique content (one per world)?
- [ ] **CT-21.** Are worlds seed-based and shareable/regenerable?
- [ ] **CT-22.** What bounds the map horizontally — invisible wall, endless ocean, city wall?
  - *Partial (CC-28):* map edges are large open-water areas past the last submerged buildings; the hard-stop mechanism is still open.
- [ ] **CT-23.** What decorates the water surface (debris, buoys, derelict boats, birds)?
- [ ] **CT-24.** Do depth zones get distinct visual theming (light, color, block wear)?
- [ ] **CT-25.** When the city is drained, does the world state permanently change (water gone, new areas)?
- [ ] **CT-26.** Are pump stations / drainage infrastructure discoverable world objects tied to GL-26?
- [ ] **CT-27.** How is the city's story told environmentally (notes, corpses, barricades, graffiti)?
- [ ] **CT-28.** What is the chunk/streaming strategy for a massive vertical world in Godot 4.8?
- [ ] **CT-29.** Is there cartography — does the player map explored floors (per CC-25)?
- [ ] **CT-30.** Do city districts vary like biomes (financial, industrial, residential zones)?

# SunkenCity — Game Overview

*(Working title — final title decision before any public release.)*

A 2D side-scrolling survival sandbox built in **Godot 4.8**, playable solo or over **LAN co-op**.
The player explores a massive, procedurally generated city that was deliberately flooded in a
failed attempt to contain a zombie virus — only the tops of the tallest skyscrapers rise above the
waterline. Progression is vertical and *downward*: the deeper you dive, the greater the danger and
the better the loot.

**Tone:** tense survival with moments of dread in the deep (darkness, oxygen anxiety, muffled
sound), contrasted with an almost cozy surface/base life. The core focus is **crafting survival**.

---

## Inspirations

### Terraria
Terraria is a 2D side-scrolling sandbox game built on a tile/block-based world. Players dig, build,
explore, and fight through a procedurally generated landscape, gathering resources to craft
ever-better tools, weapons, and armor. Its core appeal is the freedom to reshape the world
block-by-block and a progression loop where better gear unlocks deeper, more dangerous areas.
SunkenCity borrows its **2D block-based world, side-scrolling exploration, gear-gated progression,
and its separate world/character save model**.

### 7 Days to Die
7 Days to Die is a first-person survival game set in a zombie apocalypse. Its defining feature is
that nearly every object in the world can be scrapped down into basic raw materials — wood, metal,
plastic, stone, cloth — which feed a deep crafting and base-building system. Survival hinges on
scavenging, fortifying a base, and managing threats that escalate over time. SunkenCity borrows
its **scrap-everything material system, base building, learn-by-doing skills, and recurring horde
events**.

### The Cross
SunkenCity plays like Terraria (2D, blocks, side-scrolling) but loots like 7 Days to Die
(everything breaks down into raw materials). Instead of digging *into the earth*, the player dives
*into a drowned city*.

---

## Core Concept

- **Setting:** A megacity deliberately flooded to contain the zombie virus. The water level sits
  near the tops of the skyscrapers; everything below is submerged. The story of who made that call
  is told later (story development deferred until after the MVP).
- **World:** One finite city per world, procedurally generated from a seed. The skyline is a bell
  curve — the largest towers in the center, buildings getting shorter and farther apart toward the
  edges, most outer buildings entirely underwater, and large open-water areas at the map edges.
- **Materials:** Everything the player finds can be classified/scrapped down to basic parts —
  wood, metal, plastic, stone, cloth, etc.
- **Base building:** Players build and fortify a base using raw materials, starting on the
  rooftops and dry upper floors.
- **Water:** Water is tile-based and behaves like any other block, except it **flows downward**
  and settles (cellular simulation). Pumps can move water from one area to another. See
  [technical/WaterPhysics.md](technical/WaterPhysics.md).
- **Difficulty curve:** Depth *is* difficulty. Deeper floors hold harder enemies and better loot.
- **End goal:** Reach ground level and **drain the entire city** by restoring its mega-pump
  infrastructure — a central ground-level station plus relay stations at depth intervals, each
  restored relay lowering the waterline in stages like a massive bathtub drain. Afterward:
  credits + freeplay in the drained world.

## Key Decisions (Design Canon)

- **Roadmap:** 1) MVP local single-player → 2) LAN multiplayer → 3) Steam demo → 4) full
  commercial release. **LAN networking is architected in from day one** (Godot multiplayer
  authority model; one player hosts). Not couch co-op.
- **Saves:** Terraria model — world saves and character saves are separate. Any player can keep a
  world file locally and launch it single-player or host it; characters choose which world to join.
- **Death:** Backpack (inventory, not equipped gear) drops at the death point and **slowly floats
  upward unless it hits a ceiling**; unobstructed packs eventually bob at the surface. Respawn at
  base.
- **Progression:** Gear-first, with learn-by-doing skills. Skills level individually by use;
  **player level = total skill levels ÷ 5**; each player level grants one point in a separate
  **ability tech tree** that unlocks new player abilities. (Tree contents TBD.)
- **Survival meters:** No hunger or thirst — food is for healing and buffs only. **Cold is a depth
  gate**: below thresholds, a slowing debuff then damage without the right suit tier.
- **Time:** Day/night cycle with surface gameplay effects. **Red moon zombie waves every random
  5–10 days** (mechanics TBD). Light weather post-MVP: ambience plus mechanical storms (rough
  water, low visibility).
- **Modes & difficulty:** Survival only, ever. One tuned baseline difficulty in the MVP;
  world-creation toggles later. No NPCs in the MVP (trader slot reserved post-MVP).
- **Platform:** PC/Steam, keyboard+mouse first; controller support added at the Steam push (input
  actions abstracted from day one).
- **Art:** Moody-but-readable pixel art. Desaturated blues/greens deepening with depth; warm
  oranges reserved for safety. **Warm = safe, cold = deep = dangerous.**
- **Audio:** Diegetic-first with depth-adaptive layers — muffled underwater soundscape, vertical
  layering for tension, stingers for red moons and storms.
- **UX:** Fog-of-war exploration map (per character), shown as a top-right corner minimap for now.
  Character creation cosmetics: shirt, pants, and hair color. Tutorial deferred to early access.
- **Playtime target:** 60–100 hours for a full first run.

---

## World Scale & Character Metrics

| Measurement | Value |
|---|---|
| Block size | 16×16 pixels |
| Block real-world scale | 2 feet per block |
| Character height (with hair) | 24 pixels |
| Character height (without hair) | 21 pixels |
| Character height in blocks | ~2.5–3 blocks tall (~5–6 feet) |

These metrics drive tile map design, building floor heights, doorway sizes, and swim/dive hitboxes.
(Details to live in `technical/` docs.)

---

## Main Game Loop

Progression is staged around **how deep the player can go** and **what they can open**:

1. **Stage One — Surface Survival**
   The player starts by swimming on the surface between buildings. Buildings are accessible only
   through existing openings (broken windows, rooftop doors, breaches). The player must learn to
   craft basic tools and establish a first base.

2. **Stage Two — First Dives**
   Dive underwater to reach the shallow submerged levels of buildings, limited by a basic oxygen
   supply.

3. **Stage Three — Breaking Through**
   Better tools allow the player to open locked doors (and other sealed obstacles), unlocking
   previously unreachable sections.

4. **Stage Four — Deep Diving Gear**
   Craftable dive equipment lets the player descend even deeper and stay under longer.

5. **Stage Five — The Long Descent**
   Continuous self-improvement (gear, tools, skills, base upgrades) to push as far down as
   possible — ultimately reaching ground level and draining the city.

---

## Game Dangers

| Danger | Description |
|---|---|
| **Drowning** | Players have a limited oxygen supply; running out underwater is lethal. |
| **Zombies** | Found in dry sections of buildings. Can't swim well — they float. |
| **Red moon waves** | Every random 5–10 days, a red moon brings a zombie wave event (mechanics TBD). |
| **Cold** | Deep water slows, then damages, players without the right suit tier. |
| **Small fish** | Mostly harmless; serve as a food source. |
| **Large fish** | May attack players. |
| **Mutants** | Found in the deeper underwater zones. |
| **Sharks** | *(To be designed — likely open-water/between-building threat.)* |
| **Other** | *(Placeholder for future threats — environmental hazards, pressure, darkness, etc.)* |

---

## Loot: Weapons, Armor, Tools

- The game has a **standard set** of tools and weapons, each with base stats.
- Weapons and armor can roll **prefixes and suffixes** that modify or improve stats above the
  defaults (Terraria-style modifiers).
- Loot is **randomly found** throughout the abandoned buildings — left behind by the city's former
  inhabitants.
- Better loot is found at greater depths, matching the escalating enemy difficulty.

---

## The City

- Buildings are **procedurally generated** from different wood and stone block types.
- Buildings may contain **holes/breaches** that flood the affected floors, mixing dry and
  submerged sections within a single structure.
- **City profile:** tallest towers at the center; shorter, sparser, mostly submerged buildings
  toward the edges; open water at the map borders (one city per world).
- **Depth scaling:** the farther below the water's surface the player goes, the harder the enemies
  and the better the loot.
- **Endgame:** reach ground level and drain the whole city via the mega-pump relay network.

---

## Document Map

Deeper design and implementation details live in the `technical/` folder. Open design questions
are tracked in [OpenQuestions.md](OpenQuestions.md) *(Core Concept & Setting: ✅ reviewed)*.

- [technical/WaterPhysics.md](technical/WaterPhysics.md) — water simulation, pumps, draining ✅
- World generation (building layouts, flooding, breach placement)
- Material/scrapping system and crafting recipes
- Loot tables and the prefix/suffix modifier system
- Enemy design, red moon events, and depth-based difficulty scaling
- Base building mechanics
- Character controller (swimming, diving, platforming) and LAN networking model
- Skills, player level, and the ability tech tree
- Tile/sprite specifications (16×16 blocks, 24px character)

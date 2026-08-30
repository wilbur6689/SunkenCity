# TowerDive — Game Overview

A 2D side-scrolling survival sandbox built in **Godot 4.8**. The player explores a massive, procedurally generated city that was flooded during a zombie apocalypse — only the tops of the tallest skyscrapers rise above the waterline. Progression is vertical and *downward*: the deeper you dive, the greater the danger and the better the loot.

---

## Inspirations

### Terraria
Terraria is a 2D side-scrolling sandbox game built on a tile/block-based world. Players dig, build, explore, and fight through a procedurally generated landscape, gathering resources to craft ever-better tools, weapons, and armor. Its core appeal is the freedom to reshape the world block-by-block and a progression loop where better gear unlocks deeper, more dangerous areas. TowerDive borrows its **2D block-based world, side-scrolling exploration, and gear-gated progression**.

### 7 Days to Die
7 Days to Die is a first-person survival game set in a zombie apocalypse. Its defining feature is that nearly every object in the world can be scrapped down into basic raw materials — wood, metal, plastic, stone, cloth — which feed a deep crafting and base-building system. Survival hinges on scavenging, fortifying a base, and managing threats that escalate over time. TowerDive borrows its **scrap-everything material system, base building, and zombie-apocalypse survival tone**.

### The Cross
TowerDive plays like Terraria (2D, blocks, side-scrolling) but loots like 7 Days to Die (everything breaks down into raw materials). Instead of digging *into the earth*, the player dives *into a drowned city*.

---

## Core Concept

- **Setting:** A flooded megacity after a zombie apocalypse. The water level sits near the tops of the skyscrapers; everything below is submerged.
- **World:** Procedurally generated skyscrapers made of block tiles. Buildings may have holes/breaches that flood the affected floors.
- **Materials:** Everything the player finds can be classified/scrapped down to basic parts — wood, metal, plastic, stone, cloth, etc.
- **Base building:** Players build and fortify a base using raw materials, starting on the rooftops and dry upper floors.
- **Difficulty curve:** Depth *is* difficulty. Deeper floors hold harder enemies and better loot.
- **End goal:** Reach the ground level of the city and **drain the entire city**.

---

## World Scale & Character Metrics

| Measurement | Value |
|---|---|
| Block size | 16×16 pixels |
| Block real-world scale | 2 feet per block |
| Character height (with hair) | 24 pixels |
| Character height (without hair) | 21 pixels |
| Character height in blocks | ~2.5–3 blocks tall (~5–6 feet) |

These metrics drive tile map design, building floor heights, doorway sizes, and swim/dive hitboxes. (Details to live in `technical/` docs.)

---

## Main Game Loop

Progression is staged around **how deep the player can go** and **what they can open**:

1. **Stage One — Surface Survival**
   The player starts by swimming on the surface between buildings. Buildings are accessible only through existing openings (broken windows, rooftop doors, breaches). The player must learn to craft basic tools and establish a first base.

2. **Stage Two — First Dives**
   Dive underwater to reach the shallow submerged levels of buildings, limited by a basic oxygen supply.

3. **Stage Three — Breaking Through**
   Better tools allow the player to open locked doors (and other sealed obstacles), unlocking previously unreachable sections.

4. **Stage Four — Deep Diving Gear**
   Craftable dive equipment lets the player descend even deeper and stay under longer.

5. **Stage Five — The Long Descent**
   Continuous self-improvement (gear, tools, base upgrades) to push as far down as possible — ultimately reaching ground level and draining the city.

---

## Game Dangers

| Danger | Description |
|---|---|
| **Drowning** | Players have a limited oxygen supply; running out underwater is lethal. |
| **Zombies** | Found in dry sections of buildings. Can't swim well — they float. |
| **Small fish** | Mostly harmless; serve as a food source. |
| **Large fish** | May attack players. |
| **Mutants** | Found in the deeper underwater zones. |
| **Sharks** | *(To be designed — likely open-water/between-building threat.)* |
| **Other** | *(Placeholder for future threats — environmental hazards, pressure, darkness, etc.)* |

---

## Loot: Weapons, Armor, Tools

- The game has a **standard set** of tools and weapons, each with base stats.
- Weapons and armor can roll **prefixes and suffixes** that modify or improve stats above the defaults (Terraria-style modifiers).
- Loot is **randomly found** throughout the abandoned buildings — left behind by the city's former inhabitants.
- Better loot is found at greater depths, matching the escalating enemy difficulty.

---

## The City

- Buildings are **procedurally generated** from different wood and stone block types.
- Buildings may contain **holes/breaches** that flood the affected floors, mixing dry and submerged sections within a single structure.
- **Depth scaling:** the farther below the water's surface the player goes, the harder the enemies and the better the loot.
- **Endgame:** reach ground level and drain the whole city.

---

## Document Map

Deeper design and implementation details will live in the `technical/` folder as the project grows. Planned topics:

- World generation (building layouts, flooding, breach placement)
- Water & oxygen simulation
- Material/scrapping system and crafting recipes
- Loot tables and the prefix/suffix modifier system
- Enemy design and depth-based difficulty scaling
- Base building mechanics
- Character controller (swimming, diving, platforming)
- Tile/sprite specifications (16×16 blocks, 24px character)

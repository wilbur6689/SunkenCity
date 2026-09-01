# SunkenCity — MVP Overview

What the MVP is, everything decided to be in it, what is explicitly out, and how we know it's
done. Sources: the completed design review in [OpenQuestions.md](OpenQuestions.md) and the canon
in [GameOverview.md](GameOverview.md).

## What the MVP Is

**Roadmap step 1: a complete, playable, local single-player game** — a player can start in the
medical room, learn the loop, and dive through all five depth bands to the city floor in a hard
suit. Built lean, but built *whole*: every stage of the game loop exists in simple form. (Restoring
the relay network and draining the city — the story's end goal — is the post-Steam-release
endgame, not MVP scope.)

**Standing rule:** the core loop — **harvest → craft → build base** — comes first. No other major
aspect is started until that loop works end-to-end.

**Architecture rule:** even though the MVP ships single-player, all core systems are built on
Godot's multiplayer authority model from day one (server-authoritative world state, movement, and
water sim) so roadmap step 2 (LAN) is an unlock, not a rewrite.

---

## MVP Feature Scope

### The Loop (build first)

| System | MVP shape |
|---|---|
| Harvesting | Scrap furniture/objects in place; reduced yield in field, full yield at base stations; skill-gated material types; **everything one-time** — depletion drives descent |
| Crafting | Hand-craft basics anywhere + five stations: Workbench, Forge, Med Station, Dive Station, Modification Bench; tiers Wood → Scrap → Iron → Steel; advanced recipes from found schematics; **recipes fully data-driven** |
| Building | Player-placed blocks (float freely, no integrity sim), doors, ropes, ladders, chests (quick-stack), bed (spawn point), lights, pumps, pipes |

### World

- Seed-based city: ~40 towers, ~2,500×400 blocks, bell-curve skyline, whole world in RAM
  (chunks schedule rendering/sim only).
- Room-template generation — with the authoring workflow: **proc-gen rooms → curate keepers →
  assemble from the curated library**, then wear (breaches ↑ with depth), flooding by pure
  connectivity.
- Five room zones (residential, business, commercial, industrial, civil — hospital renamed
  2026-09-01), **mixed-use per floor**; elevator-shaft
  highways; authored starting hospital + relay stations; bare concrete roads at ground level;
  invisible wall edges; light surface debris.
- Block palette: concrete, steel, brick, wood, glass. **Structure unbreakable**; breakable =
  contents, glass, interior partitions, player blocks (HP + hardness tiers).

### Water (the pillar)

- Cellular tile water: flows down, settles, displace-or-destroy placement, wakes on change.
- **Currents push entities** (engineered traversal); pumps move water; patch + pump = drained
  rooms; **any drained space is breathable and buildable** (forward camps); tanks refill free in
  breathable air.
- Endgame: mega-pump relay stations per band + central ground station — each restoration
  permanently lowers the waterline, bathtub-drain style.

### Character & Presentation

- 640×360, integer-scaled, nearest, snapping; lights render at native res; depth color grade
  (no distortion); hybrid lighting (tile propagation + Godot accents); building breakers power
  area lights, flooding trips them.
- `CharacterBody2D` state machine; walk 5 / sprint 7 / surface swim 5 / underwater 4 blocks/s;
  3-block jump (two-jump rule); crawl through 2-block gaps; 12px hitbox; neutral buoyancy;
  auto-tread + water-jump; carried weight slows swimming (soft cap, ~40 slots); water negates
  fall damage; 4-block reach.
- Layered paper-doll sprite (shirt/pants/hair tints), limited visible gear, lean 7-state
  animation set; fog-of-war minimap (top-right); day/night cycle.

### Survival & Progression

- 30s baseline oxygen → ~10s drowning dash; cold soft gate + crush hard wall by suit tier;
  bleeding (bandages); slow out-of-combat regen; food = healing only (loot + raw fish, no
  cooking); no hunger/thirst/durability.
- Skills level by use → player level = total ÷ 5 → ability tech tree points. *(Tech tree
  contents: to be designed during MVP — see Open Items.)*
- Death: backpack drops and floats up unless it hits a ceiling; respawn at bed/medical room.

### Danger

- Zombies: Walker, Crawler, Floater — world-gen seeded, cleared-stays-cleared, dumb physical AI,
  proximity aggro, uniform density, per-band stat tables.
- The Drowned in The Dark/The Crush; sharks in open water from The Cold down.
- **Red moon waves** every random 5–10 days (converge on players, damage player-placed blocks,
  scale by day count, leave re-seeding stragglers). Night: bigger aggro radii + extra floaters.
- Five bands: The Dry, The Shallows, The Cold, The Dark, The Crush.

### Loot & Gear

- Containers by room template, tables keyed type × band, safes locked (torch/key).
- Modifiers: found gear rolls (8 prefixes + 8 suffixes, one of each max); rarity = title-text
  color; Modification Bench: sacrifice-to-learn, apply to unmodified gear only.
- Melee + speargun craftable per tier; **firearms loot-only**; 3 ammo types craftable;
  ~6 found-only accessories; Suit + Head + 2 Accessory slots; lean stat sheet.
- Gear ladder: tools (pry bar → bolt cutters → cutting torch), tanks (+30s/+60s/~3min),
  suits (wetsuit → hard suit), lights (glowstick → helmet lamp → placed).

### Explicitly OUT of the MVP (post-MVP list)

Story/lore delivery & environmental storytelling · tutorial/onboarding · NPCs/traders/currency ·
cooking & buff foods · bosses/guardians & unique items · environmental hazards (electrified
water) · weather/storms · fishing rod · skybridges, debris fields, wrecks between towers ·
below-street level · districts · band wear-tile visuals · water distortion shader · controller
support · difficulty/world toggles · teleportation · durability · creative mode · grappling hook ·
set bonuses · working elevators · cosmetic surface fauna.

*(Boats and the submersible sit at the MVP boundary — see Open Items.)*

---

## Proposed Build Order (milestones)

> Proposed structure — refine as we go. Each milestone has a hard gate: it is not done until its
> criteria are demonstrably true in a build.

- **M0 — Skeleton:** Godot project with the rendering stack; a hand-placed test tower; character
  controller with all movement states (land, swim, dive, crawl, rope/ladder); oxygen + drowning.
  *Done when: you can run, jump, dive through a flooded test tower, and drown in it.*
- **M1 — The Loop** *(the standing-rule milestone)***:** scrappable objects, inventory + weight,
  hand-crafting, all five stations, block/door/rope/chest/bed placement, data-driven recipes,
  starter tools.
  *Done when: wake in the test room → scrap it → craft the three starter tools → build and light
  a small base with working spawn — with no debug commands.*
- **M2 — Living Water:** cellular water sim with displacement, currents, pumps + pipes; patch
  and drain a room; breathable forward camps; tank refills.
  *Done when: you can breach-flood a dry room, then patch, pump, and move into it.*
- **M3 — The City:** world generator (templates, assembly, wear, connectivity flooding), the
  authoring pipeline (proc-gen → curate → library), all five bands with cold/crush gates, seeds,
  minimap, save/load.
  *Done when: a fresh seed generates a full explorable city that saves and loads.*
- **M4 — Danger:** the three zombies, Drowned, sharks; per-band tables; combat (melee, firearms,
  speargun); bleeding + healing; death/backpack loop; red moons; day/night.
  *Done when: a red moon can kill you, your backpack floats to a ceiling, and you can go get it
  back.*
- **M5 — The Long Game:** loot tables + modifiers + Modification Bench; schematics; skills +
  player level + tech tree; gear ladder (tanks, suits, tools); depletion pressure.
  *Done when: progression from scrap knife to hard suit works purely through play.*
- **M6 — Release Readiness:** full-run integrity pass, performance pass, LAN smoke test.
  *Done when: one player, one seed, zero debug commands — medical room to a hard suit on the
  floor of The Crush.*
- **Post-release — The Drain** *(deferred 2026-09-01)***:** relay stations + central station,
  band-by-band waterline drops, ending + freeplay. Still the story's end goal; ships as the late
  endgame after the Steam release, not in the MVP.

## Definition of Done (MVP complete)

The MVP is complete when **a new player on a fresh seed can play from the medical room to a hard
suit on the floor of The Crush entirely through the systems above** — no debug tools, no
missing-content walls — and:

1. Every M0–M6 gate has been demonstrated in a single build.
2. A full playthrough is possible at the target pacing order (surface → shallows → cold → dark →
   crush), gated only by gear/skills (never by bugs or absent content).
3. The world saves/loads reliably mid-run at any point.
4. Performance holds the frame budget on the dev machine with the full city in RAM.
5. Systems are server-authoritative such that enabling a second player is an interface task, not
   an engine task (validated by a smoke test, even if LAN ships in phase 2).

## Open Items (to settle during MVP development)

- **Ability tech tree contents** (CC-18) — needed by M5.
- **Boats/raft in or out of MVP?** (GL-19 set the ladder but not the phase; the sub is
  naturally post-M6 polish.)
- Current strength tuning: escapable vs trap-capable (WaterPhysics open item).
- Fill-level granularity for water cells (prototype at M2).
- Red moon wave mechanics detail (design pass before M4).
- Exact numbers for per-band tables, loot tables, and the 8+8 modifier list (spreadsheets at
  M4/M5).

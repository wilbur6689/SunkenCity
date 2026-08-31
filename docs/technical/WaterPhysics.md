# SunkenCity — Water Physics

Technical design for water simulation, pumping, and the endgame drain.
Source decisions: CC-13, CC-26, WS-23, GL-16 in [../OpenQuestions.md](../OpenQuestions.md).

## Overview

**Water management is a core pillar of SunkenCity** (per the design canon): moving water around is
a central player strategy that opens otherwise-inaccessible areas. The game's "dig" is *moving
water*.

Water is a **tile-based substance that lives in the block grid**: it occupies cells like any other
block, but instead of being static it **flows downward and settles**. All water gameplay — floods
through breaches, draining rooms, pumping, currents, and the citywide endgame drain — emerges from
the same cellular rules. There is no separate "ocean" system; the sea between buildings is just a
very large body of settled water tiles.

Design intent (from the overview):

- Building structure is unbreakable (GL-01), so water routing always follows real openings —
  windows, doors, vents, generated breaches — never player tunnels.
- Any drained space is breathable and buildable (GL-17): forward dive camps emerge from the sim.
- Breach a wall below the waterline → the affected floors flood.
- Patch the breach and pump the water out → the room/floor becomes dry, usable space.
- The endgame mega-pump relay network drains the whole city in horizontal bands, "like a massive
  bathtub drain" — the same flow rules at city scale.

## Cellular Simulation Model

*(Proposed baseline — refine during prototyping.)*

- **Water cells** occupy the same grid as blocks (16×16 px = 2 ft). A cell holds a fill level
  (e.g., 0–8 units) rather than a boolean, so partial tiles and smooth surfaces are possible.
- **Flow rules, evaluated per simulation tick:**
  1. **Down:** water moves into an empty/partially-filled cell directly below, up to capacity.
  2. **Spread:** if blocked below, water equalizes sideways with lower-filled neighbors.
  3. **Settle:** cells at equilibrium go dormant (no per-tick cost) until a neighbor changes —
     a placed/removed block, a new water cell, a pump.
- **Block interaction:** solid blocks stop flow. Only **foreground solid blocks** matter —
  background walls are cosmetic (WS-20) and never seal water. Removing a block wakes adjacent
  water. Placing a block into water: **displace if possible, destroy if enclosed** (WS-24) —
  filling a sealed pocket with blocks is a legitimate early-game drain tactic.
- **Air pockets:** a sealed room is simply a region water cannot path into; no separate air
  simulation is needed for the MVP. (Oxygen is a player meter, not a room property — revisit if
  air-pocket gameplay needs more.)
- **No upward pressure in MVP:** water never flows up; connected-vessel effects are out of scope
  unless prototyping shows they're needed.

### Performance

- **Dormancy is the core optimization:** the ocean at rest costs nothing; only "awake" cells near
  recent changes simulate.
- Budget simulation per-chunk and cap awake-cell updates per tick; distant chunks settle
  instantly (teleport water to equilibrium) rather than animating.
- Large connected settled bodies can be represented as **regions with a single surface level**
  instead of per-cell data — hybrid optimization to evaluate once the naive version is measured.

## Pumps

- Craftable **pump blocks** move water from an intake to an outlet (piped or paired blocks — TBD)
  at a fixed rate (cells/second), letting players drain a room into the ocean or a lower area.
- Pump gameplay = **patch the breaches, then pump**; a room with an open hole below the waterline
  refills as fast as it drains.
- Power requirements, pipe routing, and pump tiers: to be designed with the crafting system
  (GL section).

## Currents (Flow as Traversal)

- Flowing water **exerts force on entities** — the player, floating items, dropped backpacks.
- Players can engineer currents (pipes, channels, deliberate breaches, pump outlets) that **push
  the player into otherwise unreachable areas** — traversal by plumbing (WS-16).
- Implementation sketch: awake cells with net flow apply a directional force to overlapping
  bodies, proportional to flow rate; settled water applies none.
- Tuning question for prototyping: can a strong current overcome full swim speed (a trap!), or is
  it always escapable?

## Interaction with Building Power

- Some dry building sections have functional wiring: the player locates and flips a **breaker**
  to power that area's lights (WS-17; more powered devices TBD).
- **Flooding a powered area trips its breaker off.** Draining and re-flipping restores it —
  another water-management decision layer (and a foundation for live-wire hazards, GD-17).

## Endgame: The City Drain

- The city has derelict **mega-pump infrastructure**: a central ground-level station plus **relay
  stations at depth intervals**.
- Restoring/powering a relay **drains a horizontal band** of the city — the global waterline drops
  by that band, permanently (world-state change, saved with the world).
- Implementation sketch: the global waterline is a world property; a completed relay lowers it,
  and the simulation removes/settles water above the new line over time (visible drain, bathtub
  style) rather than instantly.
- After the final relay: credits + freeplay in the drained world (CC-27).

## LAN Multiplayer Considerations

- The **host is authoritative** over the water simulation (as over all world state).
- Clients receive water state changes, not the simulation: settled regions sync cheaply (surface
  levels); only awake cells near players need active replication.
- Determinism is *not* required across machines if only the host simulates — prefer that over
  lockstep.

## M2 Implementation Decisions (2026-08-31)

- **8 fill levels per cell** (`WaterSim`, bounded grid, integer-conserved units).
- Flow: down, then sideways equalization when the difference is ≥ 2 (half-difference moves);
  settled cells leave the awake set entirely.
- **Pumps use a targeted outlet** (E on the pump, click a cell within 24 blocks) instead of
  pipes — pipes can replace the targeting without touching the sim.
- Pump suction and output both work through bounded BFS on the connected body/airspace
  ("pressure-lite"): suction takes from the body's surface (and reaches puddles across the
  drained floor — deliberate, gameplay-first per GL-16); output merges into the nearest free
  space, so a rising receiving pool never stalls the outlet.
- Doors count as solid for sealing (airlocks work); background walls never seal (WS-20).
- Placement into water: bounded-BFS displacement (WS-24); shallow films (level ≤ 2) don't
  block furniture placement.
- **Known limitation:** the diff ≥ 2 spread rule freezes slope-1 gradients, so a sustained
  point source builds a static pyramid (and a point drain a static wedge). The pump paths
  sidestep this via BFS; free-falling pours still show it. Candidate fix: a "fresh-water
  ripple" pass that lets just-received units walk downhill with diff ≥ 1.

## Open Items

- Pyramid/wedge relaxation for free pours (see limitation above).
- Instant-settle for distant regions — with M3 chunking.
- Whether large-body region optimization is needed for target world sizes.
- Pump mechanics detail (pipes vs. paired blocks, power, tiers).
- Current strength tuning: escapable vs. trap-capable flows.
- Visuals: surface waves, flow animation, depth-based color grade (WS-29: grade only, no
  distortion for now).

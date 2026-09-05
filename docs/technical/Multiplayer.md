# SunkenCity — LAN Multiplayer

*Technical design, 2026-09-05. Roadmap step 2 (GameOverview "Roadmap": MVP → **LAN** → Steam demo
→ release). Canon this doc builds on: CC-06 (LAN, not couch co-op; one player hosts; Godot's
multiplayer authority model from day one), CC-09 (Terraria model — world saves and character
saves are separate; any player can host a world file, characters choose which world to join),
WS-19 (server-authoritative movement), GL-23 (bed spawn per character), GL-15 (red-moon waves
converge on each player), CT-28 (the whole world in RAM on the host; joining clients get one full
sync, then deltas), MVP-overview M6 (LAN smoke test). Units are cells (8 px = 1 ft).*

---

## 1. Goal and scope

A **listen server**: one player hosts the world in their own game process and plays in it; other
players on the same LAN join with their own character files. Nothing here changes single-player —
single-player is the host with zero clients, which is exactly how the game already runs (the
`World` autoload is the authority layer, and `Player` reads input only when it is the multiplayer
authority of its node).

In scope for the first LAN release:

- Host / join from the title screen (LAN browser via UDP broadcast, or a typed address).
- 2–4 players (cap is an open item, §10).
- Shared world: blocks, water, objects, containers, enemies, items, clock, red moons.
- Per-character: inventory, gear, skills, vitals, spawn bed, map reveal, camera and UI.
- Host saves the world; each client's character is saved to the client's own machine.

Out of scope: internet play / NAT traversal, dedicated servers, anti-cheat, voice, spectating.
Steam networking is a later transport swap behind the same `Net` layer (§3).

---

## 2. Topology and transport

| Piece | Choice |
|---|---|
| Transport | `ENetMultiplayerPeer` (UDP, reliable + unreliable channels), Godot's high-level `MultiplayerAPI` with `@rpc` |
| Model | Listen server. Peer id 1 = host = the World authority. Clients get their ENet peer id. |
| Discovery | Host broadcasts a small UDP beacon (`SUNKENCITY <version> <world name> <player count>`) on `LAN_BEACON_PORT` every second; the Join screen listens and lists hosts. A typed `ip:port` always works. |
| Port | `Constants.LAN_PORT` (single tuning surface, WS-03). |
| Version gate | The beacon and the join handshake carry the build id; mismatched builds are refused with a message, not a desync. |

A new autoload **`Net`** (`scripts/net/net.gd`) owns the peer, the beacon, the peer→character
table, and the join handshake. Everything else asks `Net.is_server()` / `Net.local_peer()` rather
than touching `multiplayer` directly, so a Steam transport later replaces one file.

---

## 3. Authority model

**The host owns the world; each client owns only its own input.** This is the model the code was
written for (CC-06) and it keeps the simulation in one place:

| State | Owner | Clients hold |
|---|---|---|
| Grid (structure / back / climb), placed-block ledger, structure damage | Host (`World`) | A full replica, updated by cell deltas |
| Water levels + awake set | Host (`WaterSim`) | A replica of levels; **clients never tick the sim** |
| Object records (doors, breakers, pumps, storage contents, growth clocks, portal links) | Host | Replica records; nodes instantiated from records inside the client's own window |
| Enemy records + enemy simulation | Host | Interpolated replicas |
| Dropped items, backpacks, spear bolts | Host | Replicas |
| Clock (`time_of_day`, `day_count`), night, red moons, pumps, power | Host | Replicated values |
| Player body: position, velocity, state machine, hitbox form | Host simulates from the owner's input snapshot | Owner predicts (§5), others interpolate |
| Player input snapshot (`input_dir`, `wants_*`, `aim_position`, `hotbar_select`) | **The owning client** | — |
| Inventory, equipment, skills, vitals, known recipes/mods, selected slot | Host (validates every change) | Replica for the UI |
| Lighting + fog of war (`LightMap`, `LightRenderer`) | **Local**, computed from the grid replica | — |
| Map reveal (`MapReveal`), minimap, full map, camera, HUD, audio, particles | **Local** | — |

Why the host simulates player bodies rather than trusting clients: WS-19 decided
server-authoritative movement, the state machine already consumes only the snapshot, and every
world query it makes (`is_solid`, `is_water`, `water_surface_y`, …) goes through `World`, so the
same code runs on both ends against the same data.

---

## 4. What already fits, what has to change

The codebase was built "LAN-ready" and most of it is. The audit (2026-09-05) found these seams.

**Already right**

- `Player._physics_process` reads input only under `is_multiplayer_authority()`; the rest of the
  loop consumes the snapshot. The gates already drive players this way
  (`set_multiplayer_authority(2)` + snapshot fields in `m1_smoke`).
- Every world mutation is a `World` method with a matching `can_*` check
  (`can_place_block`/`place_block`, `can_place_object`/`place_object`, `damage_block`,
  `place_rope`, `pickup_climbable`, `erase_back_wall`, `plant_in_planter`,
  `water_plant_above`, `release_barred_door`, `remove_object`, `set_spawn`, `portal_target`,
  `spawn_item`, `spawn_backpack`, `add_enemy_record`, `remove_enemy`, `pound`). These are the
  request/validate/apply funnel (§6) — nothing in gameplay code touches `TileMapLayer`s.
- Enemies, items and backpacks already look for **every** player through the `"player"` node
  group (`Aggro.acquire`, `enemy.gd`, `world_item.gd`, `backpack.gd`); red-moon waves converge on
  each player.
- World state is already serialisable end to end (`SaveGame.save_world`: zstd grid layers +
  water, compact object records, enemies, items, clock, pockets, towers). The join snapshot is
  that payload.
- Object and enemy nodes are windowed views over records (`OBJECT_WINDOW`, `ENEMY_WINDOW`), so a
  client can instantiate its own view from replicated records.

**Must change before any packet is sent**

- `city.gd` owns a single `$Player`; the HUD, inventory UI, map view, pause menu, light renderer
  and audio director all do `get_first_node_in_group("player")`. Introduce `Net.local_player()`
  and a `Players` spawner (a `MultiplayerSpawner` under `city.tscn`) that instantiates one
  `Player` per peer with `set_multiplayer_authority(peer_id)`; UI/camera/light/audio bind to the
  local one only.
- `World.spawn_position` is global. Spawn becomes per character (`Player.spawn_feet`, set by that
  character's bed per GL-23; default = the drop-off roof), saved in the character file.
- `World.refresh_objects_around(pos)` / the light and enemy windows centre on one position. On the
  host they become the **union of all players' windows** (objects/enemies near anyone run as
  nodes); on a client they centre on the local player only.
- `Interaction` calls `World.place_block(...)` etc. directly. On a client those calls become RPC
  requests (§6). Keep the call sites; put the switch inside `World` so the interaction layer stays
  unaware of networking.
- `Player.inventory`/`skills`/`equipment` are mutated from many places (crafting UI, scrapping,
  pickups, `bulk_scrap`, `scrap_item`). Route them through a small set of `Player` methods so the
  host can validate and replicate them as one unit (§7).
- `World` clock/red-moon/tree-growth/pump/power ticks run in `_physics_process` unconditionally.
  Guard them with `Net.is_server()`; clients apply replicated values.
- `WaterSim.tick()` must not run on clients; `WaterRenderer` reads levels either way.
- `SaveGame` autosave-on-quit (`NOTIFICATION_WM_CLOSE_REQUEST`) and F5/F9: host saves the
  world; a client saves only its character; F9 (reload) is host-only.
- The pause menu already leaves the tree running (it is an overlay, not `get_tree().paused`);
  keep it that way — pausing the host would freeze everyone. Music/SFX sliders stay local.

---

## 5. Players: input relay, simulation, prediction

Per physics tick (60 Hz):

1. **Client → host (unreliable, sequenced):** the input snapshot for tick *n* — `input_dir`
   (quantised to a byte pair), the `wants_*` bits packed into one byte, `aim_position` (cell +
   sub-cell), `hotbar_select`. ~12 bytes.
2. **Host:** writes the snapshot into that peer's `Player` and runs the normal
   `_physics_process` for every player. Late or missing input repeats the last snapshot.
3. **Host → all (unreliable):** per player: position, velocity, `state`, `compact`, facing,
   swing/anim phase, `in_water`/`submerged` flags, health, oxygen. ~40 bytes per player.
4. **Clients:** remote players interpolate between the last two host states (one tick of
   delay). The **local** player runs its own state machine on the replica grid as **prediction**
   and reconciles: if the host's authoritative position for tick *n* differs from the predicted
   one by more than `NET_RECONCILE_CELLS`, snap and replay the buffered inputs since *n*. On a LAN
   (< 5 ms) mismatches are rare and the snap is sub-pixel; the replay buffer is 8 ticks.

Phase order: build **input relay + host simulation with no prediction first** (the client's
body simply follows host state one tick late — playable on LAN and trivially correct), then add
prediction only if the feel demands it. The state machine is already deterministic given the
snapshot and the grid, which is what makes prediction a bolt-on rather than a rewrite.

Death/respawn, `travel_to` (pocket doorways), `dying` scene: host decides, client plays the
cinematic locally on the replicated flag.

---

## 6. World mutations: request → validate → apply → broadcast

Clients never write the grid, records, items or enemies. Every `World` mutation entry point
becomes:

```
client:  World.place_block(id, cell)      -> if not Net.is_server(): rpc_id(1, "_rq_place_block", id, cell); return
host:    _rq_place_block(id, cell)        -> peer = multiplayer.get_remote_sender_id()
                                             player = Net.player_of(peer)
                                             if can_place_block(id, cell, player) and player.inventory.has(id):
                                                 place_block(id, cell); player.inventory.remove(id, 1)
host:    place_block(...)                 -> mutates, then Net.broadcast_cells([...])
```

The existing `can_*` functions are the validation. Reach, tool tier, skill gates, held item and
inventory counts are all checked **on the host against the host's copy of that player**, which is
what makes the host authoritative without any new rules.

Delta streams (host → all, reliable unless noted):

| Stream | Payload | Notes |
|---|---|---|
| Cells | `[(cell, layer, value)]` batched per tick | Structure/back/climb writes, placed-block ledger, structure damage (crack overlay) |
| Water | Levels of cells the sim changed this tick, **clipped to any player's water window**; a full window resync every `NET_WATER_RESYNC_TICKS` (unreliable for the per-tick set) | Clients only draw water; far regions stay as they were at join until the client comes near, then resync |
| Objects | Record add / remove / replace (id, cell, placed flag, `link`, `door`, `grow_day`), state change (`open`, `powered`, `unlocked`, `outlet`), storage slot changes | Same fields as the compact save; a storage change sends the whole slot array of that container |
| Enemies | Spawn/despawn (type, pos, mult, band), per-tick pos + hp for enemies inside any player's window (unreliable), death/corpse | Client nodes are visual only: no AI, no contact damage checks |
| Items | Spawn (id, count, pos, velocity), pickup (who), backpack spawn/take | Magnet targets resolved on the host |
| Clock | `time_of_day`, `day_count`, night, red-moon flag/next day, once per second + on change | Clients run the day tint from the replicated value |
| Pumps / power | Outlet targets, breaker trips, powered set | Rare, reliable |
| Growth | Tree stage swaps (`_grow_trees`) | Just object replaces |

Batching: one packet per tick per stream at most; cell and water deltas share a packet.

Lighting is never sent: each client relights its own window from its grid replica and the
replicated beacon list (`World.light_beacons` — placed lights, glowsticks, worn head lamps of
**all** players, which therefore replicates as part of player equipment).

---

## 7. Per-character state

Inventory, equipment, skills, vitals, known recipes and mods, selected slot, bare-hands flag,
spawn bed and map reveal belong to the character, but only the map reveal is client-owned:

- The **host** owns and validates the character's game state (it must — pickups, crafting,
  scrapping, damage and death all happen in the host's simulation). Changes replicate to the
  owning client only (`rpc_id(peer)`), as whole-inventory diffs on change (`Inventory.changed`
  already exists as the trigger).
- UI actions (drag/drop, craft, scrap, equip, quick-stack, station tabs) are **requests** from the
  client to the host with the slot indices; the host applies through `Player`/`Inventory` methods
  and the replicated result drives the client's UI. Grayed recipes and hover cards read the
  replica, so nothing in the UI needs to know it is remote.
- **Map reveal** is local (`MapReveal` on the client, revealed by the local player's replicated
  position), saved by the client with its character. It never touches the host.
- **Saving:** on leave, save, or disconnect the host sends the client its final character state;
  the client writes `user://saves/chars/<name>.char` locally (`SaveGame.save_character` already
  takes a player + world key). The host also keeps that state in the world's peer table until the
  character reconnects, so a dropped connection resumes where it was.
- Spawn: GL-23 — each character's bed. Default for a joining character with no bed in this world
  is the world's drop-off roof.

---

## 8. Joining a world

1. Title: a **MULTIPLAYER** button (between DIVE and QUIT) opens the Multiplayer screen, two
   panels in the title's picker style. **HOST:** world picker (saved / new seed, old-format rows
   greyed like the title), character picker, port (default `LAN_PORT`), player cap, `HOST ON
   LAN` — boots the city exactly like DIVE and starts the beacon. **JOIN:** the live LAN host list
   (world, players/cap, build, address), an `ip:port` field for hosts the broadcast can't reach,
   a character picker (local files only; new characters allowed), `JOIN`, and a status line
   (connecting → handshake → "downloading world N %" → in game, refusals in plain words). Both
   panels reuse the title's delete / old-format handling; `BACK` returns. In game, the pause
   menu lists players (name, ping) with `LEAVE` / host `CLOSE WORLD`, and F3 shows peer id, ping
   and bytes/s. The character file stays on the client's machine.
2. Handshake: client sends build id + character name; host refuses on build mismatch or duplicate
   name, otherwise assigns the peer.
3. **Snapshot:** the host sends the world exactly as `SaveGame.save_world` serialises it (grid
   layers + water zstd, compact object records, enemies, items, clock, pockets, towers; ~4 MB on
   the districts city) in `NET_CHUNK_BYTES` reliable chunks with a progress bar on the client.
   The client rebuilds `World` through the same path `city.gd._boot_loaded` uses today — one code
   path for "load from disk" and "load from host".
4. The host spawns the client's `Player`, applies the character state the client uploaded
   (inventory/gear/skills from its own file) after validating item ids against `Data`, places it
   at its spawn, and starts the delta streams to that peer.
5. While a client is mid-snapshot the host queues that peer's deltas and flushes them after.

Sending the seed and regenerating on the client was considered and rejected: generation is
deterministic (CT-21) but the world has been played in, and any divergence between two
generations would be fatal and invisible. One snapshot path is safer and already exists.

---

## 9. Leaving, disconnects, host quit

- Client leaves / times out: host saves the peer's character state into the world's peer table,
  sends it to the client if still connected, removes the `Player`. Its dropped backpack (if dead)
  stays in the world like any other.
- Host quits: `save_and_exit_to_title` saves the world and every connected character's state
  (pushed to each client so they save locally), then disconnects all with a "host closed the
  world" message. There is no host migration.
- Pause: none in multiplayer; the Esc menu stays the overlay it already is. "Save & Quit" on a
  client = leave.

---

## 10. Open items

| # | Question | Notes |
|---|---|---|
| MP-01 | Player cap | **[x] 4** (`NET_MAX_PLAYERS`, host included; the Host panel offers 2–4, the beacon advertises `count/cap`, the server keeps two spare slots so an over-cap joiner is refused with words). |
| MP-02 | Prediction from day one or after the relay works? | **[x] Relay first** (built 2026-09-05, see §12): the client body follows host state one tick late. Prediction stays a Step 8 bolt-on, decided only after a real two-machine session says the delay is felt. |
| MP-03 | Friendly fire | Melee/hitscan against players: off by default; a world toggle later (difficulty/world toggles are post-MVP). |
| MP-04 | Shared vs per-character map reveal | Per character today (CC-25). A shared "team map" is a later toggle. |
| MP-05 | Pocket doorways with two players inside different pockets | Records already carry per-pocket anchors; the minimap/map anchor must use the **local** player's pocket. Verify the map side has no globals. |
| MP-06 | Red-moon wave budget with N players | Waves converge per player; cap total wave size per night or scale per player — a balance pass. |
| MP-07 | Container conflicts | **[x] As built:** `PlayerActions.container_move/storage_move/quick_stack` requests are applied on the host in arrival order, last write wins per slot; the chest's slot array replicates through the record stream and both UIs refresh from it. |
| MP-08 | Time-of-day authority on join | **[x] As built:** the client takes the host's clock from the snapshot, advances it cosmetically between `_clock` syncs (once a second and on day / red-moon change); the tint can jump once on join. |
| MP-09 | Steam transport | Same `Net` API over Steam networking sockets for the demo; LAN discovery becomes the friends list. |

---

## 11. Implementation plan (M6 → "LAN" milestone)

Each step is gated; single-player must stay green after every one (`m0`–`m5`, `district`,
`save`, `title` gates).

1. **Seams (no networking yet):** `Net` autoload stub (`is_server()` = true, `local_player()`),
   `Players` spawner replacing `$Player`, per-character spawn, local-player accessor everywhere
   `get_first_node_in_group("player")` is used for UI/camera/light/audio, host-only guards on the
   World ticks, inventory/skills mutation funnel on `Player`. *Gate:* all existing gates pass.
2. **Transport + lobby:** ENet host/join, beacon, title Host/Join screens, build-id handshake,
   peer table. *Gate:* `lan_smoke.tscn` — host and client `MultiplayerAPI`s in one process on
   localhost (`SceneTree.set_multiplayer` per subtree) connect and exchange the handshake.
3. **Join snapshot:** serialise/deserialise through the `SaveGame` payload in chunks; client boots
   `city.tscn` from it. *Gate:* the client's grid hash equals the host's after join.
4. **Players:** input relay, host simulation, state replication, remote-player interpolation,
   spawner with per-peer authority. *Gate:* the client player walks, jumps, swims, climbs on the
   host and the client sees the same positions (the `m0` movement checks driven from the client).
5. **World deltas:** cells, water window, objects, items, clock. *Gate:* the client places and
   mines a block, opens a door, floods a room by opening it, picks up a drop; host and client
   grids/records stay hash-equal.
6. **Enemies + combat:** host AI, replicated positions, hit requests, death loop and backpacks.
   *Gate:* `m4` combat checks from the client side.
7. **Per-character state + saves:** inventory/skills/vitals replication, client-side character
   save, disconnect/resume, host quit. *Gate:* the `save_smoke` round trip with a client's
   character written on the client.
8. **Prediction (if needed) and a two-machine LAN play session**, then docs: fold decisions into
   GameOverview "Key Decisions" and answer MP-01…09 above.

Constants to add (all in `scripts/constants.gd`): `LAN_PORT`, `LAN_BEACON_PORT`,
`NET_TICK_HZ` (60, = physics), `NET_CHUNK_BYTES`, `NET_WATER_RESYNC_TICKS`,
`NET_RECONCILE_CELLS`, `NET_INPUT_BUFFER` (8), `NET_MAX_PLAYERS`.

---

## 12. As built (2026-09-05)

Steps 1–7 landed in one pass (five agents in parallel against
[MultiplayerImpl.md](MultiplayerImpl.md), the implementation contract). The one design change:
**relay-only, the host runs everything.** A client sends its input snapshot; the host runs that
player's whole `Player._physics_process` — state machine, vitals, *and* `Interaction.tick` — so
placing, mining, scrapping, combat, doors, planting and pickups all happen on the host with no
request twins (§6's `_rq_*` layer exists only for prediction, which is not built). The only
client → host requests are UI-originated character actions (`PlayerActions`: bag/chest/craft/
equip/mods/abilities) and session control. On a client `Interaction` is view-only (target, hover,
cursor, ghost).

Pieces: `Net` autoload (ENet listen server / client, UDP beacon, build-id handshake, peer table,
ping/bytes) with RPC endpoint children `Net/WorldSync` (cells, water window, records, items,
backpacks, clock, power, effects, per-peer queues until `_ready_for_world`), `Net/EnemySync`
(record add/remove/events, per-tick state, resync, visual bolts), `Net/Snapshot` (the
`SaveGame.world_payload` dict in 32 KB chunks, ~4 MB / 130 chunks / 0.6 s on localhost),
`Net/CharSync` (host → owner character state, final-state push, resume table), `Net/PlayerSpawn`
(`City/Players/<peer_id>` bodies, spawn acks); per player `Sync` (12 B input, 30 B state, owner
events) and `Actions`. Puppets carry a head-lamp bit and suit id so fog beacons and tints work
for remote bodies. Title: MULTIPLAYER → Host / Join screen; pause menu: roster, LEAVE / CLOSE
WORLD; F3: peer, ping, KB/s, sync counters.

Verification: `lan_smoke.tscn` (36 handshake checks in one process) and `python
tools/lan_smoke.py` — two headless processes on localhost: join (hashes equal, 2 players, the
client walks), rejoin (the same character resumes at its last position), `--net-mutate` (host
places/mines/pours/plants/edits a chest; hashes equal), host close (the client lands on the
title with the reason). All single-player gates stay green.

Not done: prediction (MP-02), a real two-machine session, the client-side m0/m4 gate variants,
the red-moon wave budget (MP-06), friendly fire (MP-03), Steam transport (MP-09). Known gaps:
water that flows outside every client's window stays stale there until a resync; SFX of remote
players are not heard on the host; a remote body's gear beyond lamp/suit/held item isn't drawn.

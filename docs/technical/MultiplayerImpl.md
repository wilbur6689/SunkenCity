# SunkenCity — LAN Multiplayer: implementation contract

*2026-09-05. The build-side companion of [Multiplayer.md](Multiplayer.md) (the design). This file
fixes the file layout, node paths, API names and message shapes so the pieces — built in
parallel — fit together. When the design and this file disagree, this file wins for code; update
the design doc's "Open items" afterwards.*

## 0. The one simplification: relay-only, host runs everything

The design's §6 (`_rq_*` request twins for every World mutation) exists for **client-side
prediction**. The first LAN release ships **relay-only** (§5 "phase order"): a client sends its
input snapshot, the **host runs the client's `Player._physics_process` — including
`Interaction.tick`** — against the host's world, and streams the result back. Consequences:

- `World.place_block`, `damage_block`, `_scrap`, melee, guns, spear, door/bed/breaker/pump
  interact, planting, buckets, pickups: **all run on the host from the replicated snapshot.** No
  request twins are needed for them. `World` mutation entry points stay as they are.
- On a client, `Interaction.tick` runs in **view-only** mode: it computes `target_cell`, hover,
  cursor, ghost (local feedback) and performs no action.
- The only client → host **requests** are things that originate in client-side UI: inventory /
  crafting / chest / skills / modify tab actions (`PlayerActions`, §7), and session control.
- Prediction (Step 8) is a later bolt-on; `NET_RECONCILE_CELLS` / `NET_INPUT_BUFFER` are reserved.

## 1. Files and ownership

| File | Owner (agent) | Role |
|---|---|---|
| `scripts/net/net.gd` (autoload `Net`) | B (transport) | mode, peer table, ENet host/join, beacon, handshake, hooks fan-out (stub exists) |
| `scripts/net/lan_browser.gd` | B | client-side beacon listener (`RefCounted`/Node used by the menu) |
| `scripts/ui/multiplayer_menu.gd` + `scenes/ui/multiplayer_menu.tscn` | B | HOST / JOIN screen |
| `scripts/ui/title.gd`, `scripts/ui/pause_menu.gd`, `scripts/ui/hud.gd` (F3 lines only) | B | MULTIPLAYER button, players list / LEAVE / CLOSE WORLD, net stats |
| `scripts/test/lan_smoke.gd` + `scenes/test/lan_smoke.tscn` | B | two `Net` instances in one process, handshake + refusal checks |
| `scripts/net/snapshot.gd` (`Net/Snapshot`) | C | chunked world payload host → client |
| `scripts/data/save_game.gd` (`world_payload()` refactor + character bits) | C (world), G (character) | one payload builder for disk and network |
| `scripts/city/city.gd` boot-from-snapshot + dev args `--host/--join/--net-probe` | C | client boot path, probes |
| `scripts/city/players.gd` (`City/Players`) | Phase 1 creates; C/D use | per-peer `Player` container |
| `scripts/net/player_sync.gd` (child `Sync` of every `Player`) | D | input relay, state stream, owner events |
| `scripts/player/player.gd`, `scripts/player/interaction.gd` | D (sim/puppet split, view-only); G (small: equipment/skills funnels) | |
| `scripts/net/world_sync.gd` (`Net/WorldSync`) | E | cells, water, objects, items, backpacks, clock, power, effects |
| `scripts/world/world.gd` (everything except the enemy section), `water_sim.gd`, `world_object.gd`, `world_item.gd`, `backpack.gd` | E | hook calls → real broadcasts, client-side apply |
| `scripts/net/enemy_sync.gd` (`Net/EnemySync`) | F | enemy records + per-tick state |
| `scripts/enemies/enemy.gd`, `aggro.gd`, `spear_bolt.gd`, `world.gd` enemy section (`add_enemy_record` … `_enemy_in_window`) | F | puppet enemies on clients |
| `scripts/net/char_sync.gd` (`Net/CharSync`), `scripts/player/player_actions.gd` (child `Actions` of every `Player`) | G | character state replication, UI action requests, saves, leave/close |
| `scripts/ui/inventory_ui.gd` | G | route every mutation through `PlayerActions` |
| `scripts/constants.gd` | shared (append only) | `LAN_*`, `NET_*` (already added) |

Rules: edit shared files with targeted string replacements, never whole-file rewrites. Add new
behaviour in your own file and call it from a one-line hook in the shared file. Never rename or
re-indent code you don't own.

## 2. `Net` API (stub is in place; B grows it)

```
enum Mode { OFFLINE, HOST, CLIENT }      Net.mode
enum PeerState { CONNECTING, LOADING, READY }
Net.BUILD_ID: String                     "<config/version>/w<WORLD_VERSION>/c<VERSION>"
Net.is_server() -> bool                  OFFLINE or HOST
Net.is_client() -> bool
Net.is_online() -> bool
Net.local_peer() -> int                  1 offline / host
Net.local_player() -> Player             registered local player, else first "player" group node
Net.register_local_player(p)
Net.player_of(peer_id) -> Player
Net.players() -> Array                   every live Player node (both ends)
Net.peers: Dictionary                    peer_id -> {name, player, state, ping_ms, char_state, bytes_in, bytes_out}
Net.ready_peers() -> Array               peers in READY (deltas go to these)
Net.peer_state(peer_id) -> PeerState
Net.pending_snapshot: Dictionary         client: the world payload city.gd boots from
Net.host(port, cap, world_name) -> Error
Net.join(address, port, character_name) -> Error
Net.leave(reason)                        client: disconnect; host: same as close_world
Net.close_world()                        host: push char states, disconnect all
signals: peer_accepted(peer_id, name), peer_left(peer_id), joined(peer_id), join_failed(reason),
         disconnected(reason), snapshot_progress(fraction), snapshot_ready(data)
hooks (World -> Net -> sync nodes, no-ops unless HOST): on_cell_changed, on_record_added/removed/
         changed/replaced, on_item_spawned/removed, on_backpack_spawned/removed, on_power_changed,
         on_effect, on_enemy_added/removed/event
```

Child nodes `Net/WorldSync`, `Net/EnemySync`, `Net/Snapshot`, `Net/CharSync` are created by
`Net._ready()` **when their script file exists** (so each lands independently). All `@rpc`
methods live on these children or on per-player child nodes — never on `World` or `City`.

`Net` must work as a **plain node too** (not only as the autoload): `lan_smoke` instantiates two
of them under separate subtrees with their own `SceneMultiplayer` (`get_tree().set_multiplayer(api,
path)`), so use `multiplayer` (the node's API), never `get_tree().get_multiplayer()` with no path.

## 3. Handshake and join sequence (B + C + D + G)

1. Client: `Net.join(addr, port, char_name)` → `ENetMultiplayerPeer.create_client`; on
   `connected_to_server` sends `Net._hello(BUILD_ID, char_name, char_dict)` (reliable, to 1).
   `char_dict` = `SaveGame.read_character(char_name)` (may be `{}` for a new character).
2. Host `_hello`: refuse (`Net._refused(reason)` then disconnect the peer) on build mismatch, full
   (`peers.size() >= cap`, host counts), duplicate character name, or `World` not ready
   (wait: re-check on a timer up to 10 s, then refuse). Otherwise `peers[id] = {name, state:
   LOADING, char_state: char_dict, ...}`, sends `Net._accepted(peer_id, world_name)`, emits
   `peer_accepted`, then calls `Net.snapshot.send_to(peer_id)`.
3. Snapshot (C): `SaveGame.world_payload(world_name, seed)` → `var_to_bytes` → chunks of
   `NET_CHUNK_BYTES` via `Snapshot._chunk(index, total, bytes)` (reliable). Client reassembles,
   emits `snapshot_progress` per chunk, `snapshot_ready(data)` at the end. The menu (B) sets
   `Net.pending_snapshot = data` and changes scene to `city.tscn`.
4. Client `city.gd` (C): `_boot_loaded(Net.pending_snapshot)` (same path as disk loads) with
   `Net.is_client()` true: no generation, no LootGen/EnemyGen, water/clock ticks off. Then
   `Net.world_sync.rpc_id(1, "_ready_for_world")`.
5. Host `_ready_for_world` (E): sets `peers[id].state = READY`, flushes queued deltas, then
   `Net.world_sync` tells everyone to spawn the new peer's player and tells the new peer to spawn
   every existing player (`_spawn_player(peer_id, name, feet)`, reliable) — D provides
   `Players.spawn_for` and the spawn RPC lives in `WorldSync`. Host applies `char_state` to the
   new `Player` through `SaveGame.apply_character` (G validates item ids against `Data`), places
   it at its spawn (character's bed in this world, else `World.spawn_position`).
6. From then on: D's input/state streams, E/F deltas, G's character replication.

Deltas for a LOADING peer are queued in `WorldSync`/`EnemySync` per peer (from the moment the
payload was built) and flushed on READY.

## 4. Node paths and naming

- Players: `City/Players/<peer_id>` (node name = `str(peer_id)`). `Players` script
  `scripts/city/players.gd`: `spawn_for(peer_id, character_name) -> Player`,
  `remove_for(peer_id)`, `player_of(peer_id)`. It sets `player.peer_id`, `player.character_name`,
  `set_multiplayer_authority(peer_id)`, enables the camera only for the local peer, registers the
  local one with `Net`. Test scenes keep their own `$Player` (authority 1, default).
- Per-player child nodes are added in `Player._ready()` by code (not the tscn), so the test
  tower's player has them too: `Sync` (`PlayerSync`, D) and `Actions` (`PlayerActions`, G).
- Items and backpacks carry `net_id: int` (host-assigned, incrementing; `World` keeps
  `next_net_id`); enemy records carry `nid: int`. Clients map ids → nodes/records.
- Object records are addressed by their **cell** (unique per record: `World.object_cells`).

## 5. Player simulation split (D)

- `Player.peer_id: int = 1`, `Player.character_name: String`, `Player.spawn_feet: Vector2`
  (Phase 1), `Player.is_local() -> bool` (`peer_id == Net.local_peer()`),
  `Player.is_puppet() -> bool` (`Net.is_client()` — every player on a client is a puppet).
- Host / offline: `_physics_process` unchanged for every player; `_read_input()` only under
  `is_multiplayer_authority()` (the local one); remote players' snapshots arrive via `Sync._in`.
- Client: local puppet reads input (authority), packs it, `Sync.rpc_id(1, "_in", ...)`
  unreliable-ordered; all puppets apply the latest host state (position/velocity/state/compact/
  facing/anim/in_water/submerged/health/oxygen/bleed/dying) and interpolate toward it; they skip
  the state machine, `move_and_slide`, vitals, oxygen and `interaction` actions. The local puppet
  still runs camera, sprite/anim, `interaction.tick` **view-only**, zoom, hotbar wheel.
- Snapshot payload (client → host): `input_dir` as two int8, `wants_*` bits in one byte,
  `aim_position` as Vector2, `selected_slot`, `bare_hands` (absolute, not the one-frame
  `hotbar_select`/`wants_drop`). Host writes the fields and repeats the last snapshot when none
  arrived this tick (one-frame flags `wants_jump/interact` are consumed once).
- Owner events (host → owning peer, reliable, on `Sync`): `_ev_message(text)`, `_ev_gain(id, n)`,
  `_ev_container(cell)` (open the storage UI on the record at `cell`), `_ev_crafting(station)`,
  `_ev_travel(feet)`, `_ev_died()`, `_ev_respawn(feet)`. Local `message`/`container_opened`/
  `crafting_opened` signals are emitted on the owning client from these.
- Visual-only side effects on the host for **remote** players (hover glow, cursor, ghost, SFX)
  are skipped: `Interaction` gets `view_only` (client) and `is_local` (host: skip visuals for
  remote players).

## 6. World deltas (E) and enemies (F)

- `World._cell_changed(cell)` is the single funnel for structure/back/climb writes; it calls
  `Net.on_cell_changed(cell)`. `_damage_structure` and `placed_blocks` edits that don't change
  the cell value must call the hook too. A cell delta carries `[cell, structure, back, climb,
  placed_entry_or_null, damage_or_null]`; batched per tick, reliable.
- Water: `WaterSim` records the cells it changed this tick (`changed: Dictionary` cleared each
  tick); host sends `[cell, level]` pairs clipped to any READY peer's window (unreliable) and a
  full window resync every `NET_WATER_RESYNC_TICKS`; client writes `levels` directly, never ticks.
- Records: add / remove / change / replace carry the compact save fields (id, cell, placed,
  open, powered, unlocked, outlet, link, door, grow_day, storage slots). Client applies to
  `World.object_records` and refreshes any instantiated node (`World.refresh_record_node(rec)`
  — E adds it; `restore_state` exists).
- Items: `spawn(net_id, id, count, pos, vel)`, `remove(net_id, taker_peer)`, resync of positions
  every `NET_ITEM_RESYNC_TICKS`; backpacks likewise. Clients simulate item physics locally for
  smoothness but never pick up.
- Clock: `time_of_day, day_count, next_red_moon_day, red_moon_active` once per
  `NET_CLOCK_SYNC_TICKS` and on change; clients set the fields directly.
- Power: `World.update_power()` on the host → `Net.on_power_changed()` → powered set + breaker
  states to clients. Effects: `on_effect("puff", pos, item_id)`.
- **As built (E, 2026-09-05, `scripts/net/world_sync.gd`):** `_cells(packed)` — flat
  `[cell, structure, back, climb, {layer: ledger entry}|null, crack hp|null] × N`, one reliable
  packet per tick; `_water(PackedInt32Array [index, level]…)` unreliable_ordered per peer, clipped to
  `WorldSync.WATER_WINDOW` (200×120 cells) around that peer's player, `_water_rect(rect, bytes)`
  reliable every `NET_WATER_RESYNC_TICKS` (also when a tick's delta would exceed
  `WATER_DELTA_CAP` pairs); `_rec_add(dict)`, `_rec_remove(cell, id)`, `_rec_change(cell, dict)`
  (coalesced per record per tick), `_rec_replace(old_cell, old_id, dict)` (the host suppresses the
  inner add hook, so growth is ONE delta); `_item_spawn(net_id, id, count, pos, vel)`,
  `_item_remove(net_id, taker_peer)`, `_item_pos([net_id, pos, vel]…)` unreliable_ordered every
  `NET_ITEM_RESYNC_TICKS`, `_pack_spawn(net_id, slots, pos)`, `_pack_remove(net_id, taker_peer)`;
  `_clock(time_of_day, day_count, next_red_moon_day, red_moon_active)`; `_power(lights, breakers)`
  as `[[cell, on]…]`; `_effect(kind, pos, arg)` unreliable. READY (`_ready_for_world`) replays the
  peer's queue, then `_items_reset()` + the live item/backpack roster (the snapshot carries no net
  ids), `_power`, `_clock`, and schedules its first water window. Client apply lives in
  `World.apply_*_replica` / `add|remove|change_record_replica` / `refresh_record_node`;
  `WorldObject.apply_replica_state` is the node-side write. `WaterSim.track` + `changed` is the
  change set. Host dev arg `--net-mutate` mutates beside a joining peer 2 s after READY (basin
  + mined block + planter + chest edit + item) so `lan_smoke` proves the streams. Water that flows
  out of every peer's window (off a roof into the ocean) is stale on clients by design, so a
  global water hash only agrees while the moving water stays near a player.
- Enemies: `add(nid, type, pos, mult, hp)`, `remove(nid)`, `event(nid, "hurt"|"died"|"anim:x")`,
  per-tick `[nid, pos, hp, facing]` for records inside any READY peer's window (unreliable).
  Client enemy nodes: `Enemy.puppet = true` → no AI, no touch, no pound; position from stream.

## 7. Character state and requests (G)

- `PlayerActions` (child `Actions`): `move_slot(a, b)`, `split_slot(a, b)`, `drop_slot(i, n)`,
  `craft(recipe_id)`, `scrap_slot(i, n)`, `equip(slot_name, bag_index)`, `unequip(slot_name)`,
  `use_slot(i)`, `quick_stack(cell)`, `container_move(cell, from_container, i, j)`,
  `learn_mods(i)`, `apply_mods(i, prefix, suffix)`, `unlock_ability(id)`, `bulk_scrap_at(cell)`.
  Each: on the host/offline apply immediately (existing `Player`/`Inventory` code); on a client
  `rpc_id(1, "_act", name, args)` and apply locally as optimistic feedback — the host's replica
  overwrites. Host validates the sender is that player's peer.
- `CharSync`: host → owner `_char_state(dict)` on `inventory.changed` / equipment / skills /
  known_* changes, coalesced to at most once per tick; dict shape = `SaveGame` character fields
  minus `maps`/`positions`. The client applies with `SaveGame.apply_character`-like code without
  moving the body.
- Saves: client saves its character locally from the replica on leave / F5 / host push (host
  sends `_final_state(dict)` before disconnecting); the host keeps `peers[id].char_state` for
  resume. F9 is host-only. `NOTIFICATION_WM_CLOSE_REQUEST` on a client saves the character and
  leaves.

## 8. Dev args and probes (C, B)

- `--host[=port]` boots `city.tscn` as host (with `--seed=`/`--world=` and `--character=`) and
  starts the beacon; `--join=ip[:port]` + `--character=name` joins from the title without UI.
- `--net-probe=SECS`: every second print one line `NETPROBE t=<sec> mode=<host|client>
  peers=<n> players=<n> grid=<hash> water=<hash> records=<n> enemies=<n> items=<n>
  lp=<x,y>` (hashes = `hash(grid.structure) ^ hash(grid.back) ^ hash(grid.climb)`, water =
  `hash(water_sim.levels)`), and quit after SECS. `--net-drive` on a client holds `move_right`
  for the first 2 s after spawn (`Input.action_press`), so a driver can verify the local
  player moved on both ends. The host prints `NETHOST ready port=<p>` once the world is up.
- `tools/lan_smoke.py` (Phase 3): launches a headless host and client on localhost, waits for
  both to finish, compares the final probe lines (hashes equal, players = 2 on both, the client's
  `lp` moved), exit 0/1.

## 9. As built — deviations from §1 (2026-09-05)

| Item | As built |
|---|---|
| `Net/PlayerSpawn` (`scripts/net/player_spawn.gd`) | Added: spawn/despawn bodies on `Net.peer_ready`/`peer_left`; `_spawn_player`, `_despawn_player`, `_spawn_ack` (a body's state streams to a peer only after that peer acked its spawn — reliable spawns otherwise queue behind the READY flush while unreliable state overtakes them). |
| `Net.peer_ready(peer_id)` signal | Added; emitted by `WorldSync._ready_for_world`. |
| `scripts/ui/save_pickers.gd` | The title's world/character pickers, shared with the Multiplayer screen. |
| `scripts/net/net_probe.gd` | `--net-probe` / `--net-drive`; quits through the real leave / close path so saves and final states are exercised. |
| State packet | 30 B: `[28]` u16 suit item index; flags byte `[17]` bit 8 = worn head lamp (`puppet_lamp`, `puppet_suit` on remote bodies). |
| `WorldSync --net-mutate` | Host dev aid: 2 s after a peer is READY, places/mines blocks, pours water into a basin, adds a planter, edits a chest, spawns an item beside that player. |
| Client boot | `city.gd` still spawns the local body at boot on a client (a parked puppet); `_spawn_player` reuses it. |
| `Players` | Player bodies get mutual collision exceptions (two bodies on one spawn cell walled each other in). |
| Enemy snapshot | The join payload carries no `nid`s: `EnemySync._reset` re-lists every record with host ids on READY. |
| `Net._teardown` | Leaves an `OfflineMultiplayerPeer` in place (a null peer makes `is_multiplayer_authority()` error on every body). |
| Title dev args | `--host`/`--join` fire once per process (`_dev_args_used`); a `--net-probe` process that lands on the title with a disconnect notice prints `NETPROBE disconnected: …` and exits. |

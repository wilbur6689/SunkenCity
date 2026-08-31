# Audio — asset inventory & event mapping

Sources live in `docs/Examples/Audio/` (gitignored — several exceed GitHub's
100MB limit — and `.gdignore`d so Godot doesn't import ~460MB of WAV).
Game-ready files live in `assets/audio/` and ARE committed:

- `sfx/` — mono 44.1kHz 16-bit WAV one-shots, peak-normalized per set,
  cut from the multi-take library files by silence-split analysis
  (`tools/` scratch scripts; cuts padded, 10ms fade-in / 60ms fade-out)
- `music/`, `ambient/` — OGG Vorbis (q5 / q4). Ambient tracks are loops:
  the audio manager sets `stream.loop = true` at load.

## SFX one-shots → game events

| Files (variants) | Source | Plays when |
|---|---|---|
| `door_open` | Cabin Door Open | door opens (the big creak) |
| `door_creak_1..4` | Apartment Door variations | door closes / random pick per door toggle |
| `door_latch` | Apartment Door take 1 | locked/blocked door, breaker box flip |
| `container_close` | Pizza Box Close | closing a chest/storage screen |
| `creak_plastic_1..3` | Drain Pipe Creak | scrapping plastic furniture (loop while holding RMB) |
| `dismantle_rattle` | DismantleRattle (user-cut) | scrap tick / object pickup long-press completes |
| `wood_hit_1..2` | Shelf Kick (sharp attacks) | hammer hit, melee hit on wood |
| `wood_break_1..4` | Shelf Kick (break-aparts) | furniture scrap completes, wood block breaks |
| `wood_small_1..3` | Shelf Kick (small bits) | light debris, partial scrap stage |
| `wood_crash_1..4` | Wood Crash Debris | big furniture collapses, slab/debris falls |
| `wood_place_1..6` | Planks Pile (short knocks) | placing a block or furniture |
| `debris_roll_1..2` | Planks Pile (long rolls) | dropped items tumbling, scrap yield spill |
| `footstep_wood_1..12` | Barefoot Wood Walk | walking (alternate randomly, ±5% pitch) |
| `footstep_scuff_1..2` | Barefoot Wood Walk (long) | landing from a jump, turning scuff |
| `footstep_soft_1..8` | Slow Soft steps (quiet set) | crawling / slow walk |
| `splash_1..5` | Hand Splash Singular | entering/exiting water, swim strokes, pump outlet |

Still missing (add to `docs/Examples/Audio/sfx/` any time): metal & stone
footsteps/impacts, underwater muffled movement, breathing/oxygen warning, UI
clicks, item pickup blip, pump running loop, breaker hum. The long
"Wood, Friction, Squeaky" stressed-wood file was analyzed but removed from
the folder before export — re-add it if wanted as the scrapping loop bed.

## Music / ambient

| File | Use |
|---|---|
| `music/adventure01..04.ogg` | exploration rotation (band-agnostic for now) |
| `music/threat01..02.ogg` | danger stingers — red moon / enemy aggro (M4) |
| `ambient/underwater_inside.ogg` | loop while submerged inside a building (back-wall cells) |
| `ambient/underwater_outside.ogg` | loop while submerged in open water |

Planned wiring (audio manager, next audio pass): bus layout `Master > Music /
Ambient / SFX`; crossfade ambient by submerged+interior state; positional 2D
SFX via `AudioStreamPlayer2D` at the event cell; low-pass filter on the SFX
bus while the listener is underwater (GameAudioPrinciples: mixing table).

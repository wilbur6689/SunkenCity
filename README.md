# SunkenCity

*(Working title — formerly TowerDive.)*

A 2D side-scrolling, block-based survival sandbox built in **Godot 4.8** — Terraria × 7 Days to
Die. A megacity was deliberately flooded to contain a zombie virus; only the tallest skyscrapers
break the surface. Scrap everything, craft, build a base on the rooftops, then dive progressively
deeper through the submerged towers — where depth *is* difficulty — to reach ground level and
drain the city.

**Water is the pillar.** It's a cellular tile simulation: it flows, settles, floods through
breaches, and can be pumped, piped, and drained. Moving water is this game's "dig".

## Status

Pre-alpha, **M0 (Skeleton)** of the MVP milestone plan. Roadmap: local single-player MVP →
LAN co-op → Steam demo → commercial release. Not yet playable beyond a test tower.

## Running

Requires Godot 4.8 (currently developed against `4.8-dev2`).

```
godot --path .          # run the game (main scene: scenes/test/test_tower.tscn)
godot --path . -e       # open the editor
godot --path . --headless --import          # validate assets
godot --path . --headless --quit-after 10   # boot the main scene, surface script errors
```

Controls: **A/D** or arrows move · **Space** jump · **Shift** sprint · **C** crouch · **E** interact ·
**Tab/I** inventory.

## Layout

| Path | Contents |
|---|---|
| `scenes/` | Scenes (`scenes/test/` holds the M0 test environment) |
| `scripts/` | GDScript; `constants.gd` is the single tuning surface (all units in blocks, `BLOCK_SIZE = 16`) |
| `assets/` | Sprites, tilesets (placeholder art for now) |
| `data/` | Data-driven definitions: items, recipes, loot tables, enemy stats |
| `docs/` | Design docs — start with [`docs/GameOverview.md`](docs/GameOverview.md) |

## Documentation

- [`docs/GameOverview.md`](docs/GameOverview.md) — the design source of truth and its settled canon
- [`docs/MVP-overview.md`](docs/MVP-overview.md) — MVP scope, build order (M0–M6), definition of done
- [`docs/MVP-checklist.md`](docs/MVP-checklist.md) — live task tracker
- [`docs/OpenQuestions.md`](docs/OpenQuestions.md) — the 180-question design review (all sections complete)
- [`docs/technical/`](docs/technical/) — deep dives, starting with water physics

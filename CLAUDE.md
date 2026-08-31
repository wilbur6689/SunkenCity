# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

**SunkenCity** (working title; repo: wilbur6689/SunkenCity; formerly TowerDive) is
a **Godot 4.8** 2D side-scrolling block-based survival sandbox (Terraria × 7 Days to Die): a
procedurally generated city deliberately flooded to contain a zombie virus, where the player dives
progressively deeper through submerged skyscrapers. Roadmap: MVP local single-player → LAN
multiplayer (networked architecture from day one) → Steam demo → full commercial release.
The "Key Decisions (Design Canon)" section of `docs/GameOverview.md` records settled design
decisions — treat them as canon. Standing MVP priority: the core loop (harvest → craft → build
base) comes first; do not add other major aspects before it works.

Development is at the end of **M0** of the milestone plan in `docs/MVP-overview.md` (all M0 items
land; the gate passes headless, manual feel pass pending); next is **M1 — The Loop**. The task
tracker is `docs/MVP-checklist.md` — check items off there as they land.

## Running the Project

- Engine: `C:\Programming\Godot_v4.8\Godot_v4.8-dev2_win64.exe`
- Run the game: `& "C:\Programming\Godot_v4.8\Godot_v4.8-dev2_win64.exe" --path . `
- Open the editor: add `-e`
- Headless validation (use after editing scenes/scripts): `--headless --import` to check assets
  parse; `--headless --quit-after 10` to boot the main scene and surface script errors.
- M0 gate test: `--headless res://scenes/test/m0_smoke.tscn` (exit 0 = all checks pass). Drives the
  player with `Input.action_press`; extend it when controller behaviour changes.

## Code Conventions

- **All design units are blocks** — `Constants.BLOCK_SIZE = 16` px; speeds in blocks/sec. Every
  tuning value lives in `scripts/constants.gd` (autoloaded as `Constants`), never inline.
- Player logic (`scripts/player/player.gd`) keeps an **input-snapshot → state-machine
  separation** so a networked client can later feed the same input fields (LAN-readiness rule).
  Input is read only when `is_multiplayer_authority()`.
- **World queries go through the `World` autoload** (`scripts/world/world.gd`) — `is_solid`,
  `is_water`, `is_climbable`, `water_surface_y`, `surface_has_air`, `rect_is_clear`. Gameplay code
  never touches `TileMapLayer`s directly; M2's water sim replaces World's storage, not its callers.
- Placeholder atlas `assets/tiles/placeholder_blocks.png`: columns = 5 shades, rows = stone, wood,
  metal, plastic, water, ladder, rope (rows 4–6 have no collision).
- Recipes, items, loot tables, and enemy stats must be **data files**, not code (per LT-11).
- Main scene is currently `scenes/test/test_tower.tscn` (M0 test environment).

## Fixed Design Constants

These are settled and should be treated as canon in all docs and future code:

- Block size: **16×16 pixels**, representing **2 feet** in-game
- Character height: **24 pixels** with hair, **21 pixels** without
- Character is roughly **2.5–3 blocks tall**

## Document Structure & Workflow

- `docs/GameOverview.md` — the source of truth for the game design. High-level only.
- `docs/OpenQuestions.md` — 180 open design questions (30 per overview section), each with a
  stable ID (`CC-`, `WS-`, `GL-`, `GD-`, `LT-`, `CT-` + number) and a checkbox.
  Workflow: answer questions in review sessions, record decisions on an indented `**A:**` line
  under the question, mark `[x]` answered or `[~]` deferred. Fold completed sections' decisions
  back into `GameOverview.md` and into deeper docs under `docs/technical/`.
- `docs/technical/` — in-depth technical design docs, added as design areas get resolved.
  `GameOverview.md`'s "Document Map" section lists the planned topics. First doc:
  `WaterPhysics.md` (cellular tile water, pumps, endgame drain).

When answering design questions, questions cross-reference each other by ID (e.g. GD-19 defers to
GL-12) — check whether a referenced question was already decided before asking again.

## Project Skills (`.claude/skills/`)

- **guided-review** — collaborative one-question-at-a-time design review with countdown numbering
  (`Q{N}` down to `Q1`), 2–4 numbered options per question, recommendation first and set apart by
  a rule, document updated only at section end after a confirmed summary. The user may not have
  slash-command access to it; when they ask to review design questions, follow its process
  directly against `docs/OpenQuestions.md`.
- **guided-testing** — manual one-test-at-a-time QA sessions maintaining a living
  `FUNCTIONAL_TEST_REPORT.md`. Relevant only once the game is runnable.
- **GameAudioPrinciples** — reference tables for game audio design (categories, mixing, adaptive
  music). Its frontmatter contains unrelated boilerplate (`risk: offensive`, security-use warning)
  left over from a template; the content is ordinary game-audio guidance.

## Conventions

- Docs are Markdown; keep the existing section structure and ID schemes stable — other documents
  and future sessions reference them.
- Keep the "Running the Project" commands and engine architecture notes above current as the
  project grows.

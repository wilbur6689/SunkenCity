# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

TowerDive is in the **design/pre-production phase**. There is no Godot project, code, or build
system yet — the repository currently contains only design documents and skills. The game will be
built in **Godot 4.8** as a 2D side-scrolling block-based survival sandbox (Terraria × 7 Days to
Die): a procedurally generated city flooded during a zombie apocalypse, where the player dives
progressively deeper through submerged skyscrapers.

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
  `GameOverview.md`'s "Document Map" section lists the planned topics.

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
- Once the Godot project is created, add build/run/test commands and engine architecture notes
  here.

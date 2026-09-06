# SunkenCity — Modifiers

*Design session 2026-09-05. Substantially revises the modifier system in
[GameOverview.md](GameOverview.md) and [MVP-overview.md](MVP-overview.md) — see **Canon Changes**
at the bottom before implementing. Builds on [Districts.md](Districts.md).*

Terraria's depth comes from long crafting chains — each material feeds the next, and a late-game
item is visibly the sum of everything you gathered to reach it. SunkenCity puts that chain in
**modifiers** rather than in the weapons themselves.

Weapons stay simple. What you put on them is the deep system.

---

## The Loop

1. **Find** a modded weapon in the world. Loot rolls modifiers as it always has.
2. **Sacrifice** it at the Modification Bench. The weapon is destroyed; its modifiers are added to
   your **library**.
3. **Combine** library modifiers into higher-tier and hybrid modifiers.
4. **Craft** a blank weapon.
5. **Apply** one prefix and/or one suffix from the library to that blank. The library entries are
   **consumed**.

Found gear is *use it or sacrifice it*. Crafted gear is the only blank canvas. Once a weapon is
modded, it is locked — but that costs a craft now, not a rare item, so committing is cheap and
experimenting is viable.

**Everything happens at the Modification Bench.** No field swapping. A dive loadout is a decision
made at base, and changing your mind means going home.

---

## The Grid

**6 districts × 5 depth bands = 30 base modifiers.**

- **District = family.** Residential, commercial, business, civil, industrial, and construction
  each own a modifier family with its own flavor and stat identity.
- **Band = tier.** The tier of a modifier is set by the depth it was found at. The Dry yields
  tier 1; The Crush yields tier 5.

So "I need a tier-4 industrial prefix" translates directly into "dive the industrial district down
to The Dark." Districts become mechanically load-bearing rather than cosmetic, and the library
doubles as a map of where you have and have not been.

**One modifier per cell to start.** The structure supports several per cell if recipe authoring
wants more room later.

---

## The Library

The library is a **stock count, not a checklist.** Sacrificing adds an entry; combining and
applying consume entries. Nothing is permanently unlocked — a modifier you have used is gone until
you find another.

This makes duplicates valuable, makes every modifier on a weapon the visible end of a chain of
sacrificed loot, and keeps looting relevant for the whole run.

---

## Combining

All combining is **recipe-based and deterministic** — no rolling. Players can plan toward a result.

### Vertical (same family)

**Two of the same tier, same family → one of the next tier up.** Tier 3 + tier 3 = tier 4.

Costs compound: a tier-5 modifier is **16 tier-1s** deep. Across all six families that is 96 base
modifiers, which is a serious sink against one-time loot — see Open Items.

### Horizontal (cross-family)

**Two modifiers of the same tier from different families → a new, named hybrid.** Industrial T3 +
Civil T3 produces something neither ladder contains on its own.

Hybrids can themselves be combined further, so the tree branches rather than merely climbing.
This is what makes the system a web instead of six parallel ladders.

### Rules

- **No cross-slot combining.** Prefix + prefix, suffix + suffix. Recipes never merge across the
  slot boundary.
- **Inputs must be the same tier.** No tier N + tier N-1 shortcuts.
- **Tier 5 is the ceiling**, hybrids included.

---

## Slots

**One prefix + one suffix, maximum.** Unchanged from existing canon, and now doing heavy lifting:
with a whole crafting web feeding into it, the two-slot cap is what stops every weapon from
eventually wearing the best of everything.

---

## Canon Changes

| Doc | Current | New |
|---|---|---|
| Both | Learned modifiers apply to unmodified gear only | Unchanged — but now the intended path, since crafted weapons are blank by design |
| Both | Learning a modifier unlocks it | Library entries are **consumed** by combining and applying |
| Both | No modifier crafting or combining | Full recipe-based combining system, vertical and cross-family |
| Both | ~8 prefixes + ~8 suffixes | 30 base modifiers on the district × band grid, plus hybrids |
| GameOverview · Loot | No modifier schematics, no rerolling | Recipes, not rerolls — resolves the standing contradiction with the Crafting loop bullet, which already promised "planned modifier schematics" |
| Both | Rarity derived from modifier state (gray → green → blue → purple) | Needs rework — tiers run 1–5 and the palette has four colors |
| MVP-overview · Open Items | "Exact numbers for the 8+8 modifier list" | Replaced by the 30-cell grid plus a recipe table |

---

## Open Items

- **Rarity palette** — five tiers, four colors. Add a fifth, or decouple rarity from tier.
- **Armor** — the original framing covered weapons *and* armor, but canon splits prefixes as power
  and suffixes as aquatic utility. Suffixes suit armor naturally; prefixes do not. Does armor draw
  from the same pool, a suffix-only pool, or its own?
- **Modifier supply vs. one-time loot** — canon says all loot is one-time and depletion drives
  descent. With modifiers consumed on every combine and application, a player who spends badly has
  no way to recover. Either that *is* the descent pressure, or the system needs a renewable
  trickle.
- **Naming and stats for all 30 base modifiers**, plus the family identities.
- **Which cross-family recipes exist.** Every pairing at every tier is far more than 30 results,
  and each needs a name, an effect, and balancing.
- **Scope for launch.** Recursive cross-family combining implies hundreds of recipes; Terraria
  built that over a decade. Suggested: author the six vertical ladders in full plus a small set of
  cross-family recipes, and treat the wider web as the post-launch expansion surface. The
  data-driven recipe canon already supports growing into it.
- **Do blank crafted weapons ever roll modifiers?** Assumed no — crafted is blank, found is
  pre-modded — but this was never stated in existing docs.

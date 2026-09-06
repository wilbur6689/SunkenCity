# Modifiers — implementation checklist

*2026-09-05. Task tracker for the modifier overhaul: [Modifiers.md](Modifiers.md) is the design,
[ModifiersImpl.md](ModifiersImpl.md) the build contract (§4 schema, §5 per-file changes, §6 build
order), [Merged_Modifiers.json](Merged_Modifiers.json) the 60 names. Same conventions as
`docs/MVP-checklist.md`: tick items as they land; each step ends with the gates that prove it.*

**Settled decisions (do not re-open):** D1 three prefix families (Industrial / Construction /
Business) + three suffix families (Residential / Commercial / Civil) · D2 rarity = highest tier
bucketed (gray / T1–2 green / T3–4 blue / T5 purple / both T5 gold) · D3 strip unknown mods on
load, no version bump · D4 six vertical ladders + the 30 first-order hybrids · D5 no renewable
supply, `ROLL_MOD_CHANCE` 0.35 → 0.6 · D6 names from `Merged_Modifiers.json`.

---

## Step 0 — Content authoring (data only, no code)

*Build landed 2026-09-05 (all gates green: m1 98 · m4 72 · m5 · save 26 · lan 36 · lan driver). Unticked items are the follow-ups.*

### Names
- [x] 30 base names on the district × band grid (`Merged_Modifiers.json`, ids `<fam>_<tier>`)
- [x] 30 first-order hybrid names (ids `demolition/works/development/arcade/parish/customs_<tier>`)
- [ ] Final read of the Business ladder: keep the career nouns (Junior … Executive) or revert to the adjective ladder (Brisk … Executive) — decide once, before the data file is written

### Stats
- [x] One `stats_per_tier` axis per family: Industrial `tool_damage`, Construction `knockback` + `scrap_speed`, Business `tool_speed`, Residential `weight_mult`, Commercial `oxygen` + `swim`, Civil `defense` + `cold` + `light` (Appendix A.1) — pick the per-tier step so T5 ≈ today's power-3 top end
- [x] Hybrid stats: each pair blends both parents' axes at ~70 % of the sum (so a hybrid beats either parent on total but neither on its own axis)
- [x] Per-tier `stats` overrides only where a ladder needs a kink (leave empty by default)
- [x] Junk entry: `rusty` kept as found-only, `learnable: false`, unchanged numbers
- [ ] Sanity table in `ModifiersImpl.md`: every stat key used ↔ the code path that reads it (`ItemMods.stat`, `Player.equip_stat/suit_stat/scrap_speed_mult`); no key without a reader

## Step 1 — Data schema + loader

### `data/modifiers.json` (v2, §4)
- [x] Rewrite to `families` (6 × 5 tiers) + `hybrids` (30, each with `recipe: [a, b]`) + `junk`; drop `prefixes`/`suffixes`; keep `_comment` current
- [x] Every family carries `slot`, `applies`, `stats_per_tier`, `tiers[5]` with `{id, name}`
- [x] Every hybrid carries `id, name, slot, tier, applies, recipe, stats`; `next` omitted at launch (second-order combining is post-launch)
- [x] Names and ids pasted from `Merged_Modifiers.json` (suffix names stored as the bare noun phrase, e.g. `"of the Ward"`, exactly as the display string)

### `scripts/data/data.gd`
- [x] Loader flattens to `Data.modifier_defs: {id → {id, name, slot, tier, family|hybrid, applies, stats, learnable}}`; keeps `Data.modifier_families` and `Data.modifier_hybrids` for the bench UI / combiner
- [x] Validation at load (push_error + skip, never crash): exactly 6 families, 5 tiers each, unique ids across families/hybrids/junk, hybrid recipe ids exist + same tier + same slot + different families, `next` targets exist, stat keys ∈ the known set, slot ∈ prefix/suffix
- [x] Effective stats resolved once at load (`stats` override else `stats_per_tier × tier`) so `ItemMods.stat` reads a flat dict
- [x] `--headless --quit-after 10` boots clean with the new file (no validation errors)

## Step 2 — `ItemMods` rewrite + location-driven rolls

### `scripts/items/item_mods.gd`
- [x] Remove `MAX_POWER`; add `MAX_TIER = 5`, `TIER_OF_BAND = {dry 1, shallows 2, cold 3, dark 4, crush 5}`
- [x] `roll(rng, id, district, band)`: class gate as now → family = district → tier = band; skip when the family's slot doesn't `applies` to the item class; `ROLL_MOD_CHANCE` 0.6; junk rolls on tool/weapon at the old Rusty rate; `ROLL_BOTH_CHANCE` retired (a district owns one slot)
- [x] Instances become `mods: {prefix: {id}, suffix: {id}}` — no `power` anywhere
- [x] `stat(stack, key)`: sum of the resolved def stats, no multiplier
- [x] `rarity(stack)` per D2 + `RARITY_COLORS.legendary` (gold); `rarity_color` unchanged in shape
- [x] `describe_mod(id)`: `"Forged III: +3 damage"` (roman numeral tier + stat lines); `display_name` unchanged
- [x] New helpers: `slot_of`, `tier_of`, `family_of`, `is_hybrid`
- [x] New `combine_result(a, b) -> String`: same id + same family + tier < 5 → family tier+1; different families same tier same slot → hybrid whose `recipe` matches (order-free); same hybrid id with `next` → next; otherwise `""`
- [x] New `clean_stack(s)`: drops unknown mod ids and any `power` key — the one shared cleaner (D3)

### `scripts/world/loot_gen.gd`
- [x] Resolve district per container: `CityGen.tower_at(towers, rec.cell).district`; annex cells → the pocket whose `rect` holds the cell → `tower_at(towers, pocket.entry).district` (pass `World.pockets` from `city.gd`)
- [x] Pass `_band(...)` as the tier source; safes keep their `safe` tables for *what* drops, family/tier still from location
- [x] Log a count per (district, band) at gen behind the existing gen-stats print so the distribution is visible once

## Step 3 — Player library, bench actions, persistence, LAN

### `scripts/player/player.gd`
- [x] `known_mods` → `mod_library: Dictionary` (id → int count ≥ 0)
- [x] `learnable_mods(stack)` = "carries at least one learnable mod" (duplicates always teach)
- [x] `learn_mods(stack)`: +1 per learnable mod on the donor, donor destroyed, returns the names
- [x] `apply_mods(stack, prefix_id, suffix_id)`: each chosen id needs count ≥ 1, slot matches, `applies` matches the class, piece unmodified; decrement on success; writes `{id}` instances
- [x] New `combine_mods(a_id, b_id) -> String`: counts (2 if a == b), same slot, same tier, `ItemMods.combine_result` non-empty; decrement inputs, increment result, return the result name
- [x] `equip_stat` / `suit_stat` / `scrap_speed_mult` / held-tool merge read through the new `ItemMods.stat`

### `scripts/player/player_actions.gd`
- [x] Add `combine_mods` to `ALLOWED` + dispatcher (args `a_id`, `b_id`); bench-in-reach check like `learn_mods`/`apply_mods`; host-validated, optimistic on the client; `_say` the result name
- [x] `learn_mods` / `apply_mods` payloads updated for `{id}` instances

### `scripts/data/save_game.gd`
- [x] Character save writes/reads `mod_library`; a legacy `known_mods` field is read and ignored (no `VERSION` bump)
- [x] On load, `ItemMods.clean_stack` runs over bag, equipment, backpacks and world container records (old `sharp`/`of_the_deep`/`power` instances become clean pieces)

### `scripts/net/char_sync.gd`
- [x] `sanitize` clamps `mod_library` to known ids, `int ≥ 0`; `_clean_stack` delegates to `ItemMods.clean_stack`
- [x] `resume_states` / final-state push carry `mod_library`

## Step 4 — Modify tab UI

### `scripts/ui/inventory_ui.gd`
- [x] Replace the flat learned list with a **6 × 5 grid**: family rows (prefix families above suffix families) × tier columns; cell = name + count badge, tinted by family, dim at 0
- [x] Hybrids list beneath the grid, only ids with count > 0, same badge style
- [x] Selection model: APPLY = one prefix-slot + one suffix-slot pick (as now); COMBINE = two same-slot picks; the COMBINE button label shows the result name or "no recipe" and is disabled when `combine_result` is empty or counts are short
- [x] LEARN / APPLY flow unchanged otherwise; APPLY and COMBINE refresh counts immediately (optimistic), reconcile on host reply
- [x] Hover plate: "Tier N" line via `describe_mod`; rarity title colour per D2 incl. gold
- [x] `UITheme`: one new gold colour constant only
- [x] `menu_preview --screen=modify` seeds `mod_library` with a few cells across tiers + one hybrid and a clean knife on the bench; screenshot checked at UI Size 1.0 and 2.0 (grid must not overflow the window)

## Step 5 — Gates and regressions

- [x] `m5_smoke` G: walk `object_records`, resolve each container's district + band, assert every rolled mod's `family_of` / `tier_of` matches; rarity buckets per D2 (single T1 green, single T3 blue, single T5 purple, both T5 gold); stats no longer scale by power
- [x] `m5_smoke` H: learn +1 (duplicates count), apply consumes, vertical combine 2 × T3 → T4, refuses mixed tier / mixed slot / at T5, one hybrid recipe per slot resolves, junk unlearnable
- [x] `save_smoke`: `mod_library` round trip; a hand-written legacy character file (`known_mods` + `power` instances) loads clean with no errors
- [x] `lan_smoke.tscn`: `combine_mods` action validated on the host (bench reach, counts, refusal path)
- [x] `python tools/lan_smoke.py` still passes (payload shape changed for modded stacks)
- [x] Regressions: `m1`, `m4`, `title`, `district` smokes pass; `--headless --quit-after 10` clean
- [x] Gates run **sequentially** (district + LAN driver fail under concurrent Godot instances)

## Step 6 — Docs canon

- [x] `GameOverview.md`: Loot bullets + Key Decisions — "no modifier schematics" → "recipes, not rerolls"; library is consumed stock; rarity rule per D2; district = family, band = tier
- [x] `MVP-overview.md`: Modifiers line + Open Items (drop "exact numbers for the 8+8 list")
- [x] `OpenQuestions.md`: LT-05/06/08/09 amendment lines dated 2026-09-05
- [x] `MVP-checklist.md`: M5 Loot items re-worded under the new rules (grid, stock library, combine, D2 rarity); link this file
- [ ] `docs/MainGameLoop/Stage3–5`: Modification Bench loop steps read learn → **stock** → combine → apply; S3-11 (numeric-only mods) still holds
- [ ] `Modifiers.md` Open Items: close rarity palette, armor pool, hybrid scope, blank-crafted question with one-line answers pointing at D1–D6
- [ ] `ModifiersImpl.md` Appendix A.3 placeholders replaced by the shipped ladders
- [x] `CLAUDE.md` M5 summary paragraph updated (grid, library counts, combine, `Merged_Modifiers.json` as the naming source)

## Step 7 — District weapons ([Weapons.md](Weapons.md))

The found-weapon roster is the modifier supply: every district × band cell needs weapons to
find, sacrifice and craft blank. Runs after Step 2 (so rolls land on the new items) and can
overlap Steps 3–4.

### Decisions first
- [x] Scope: launch cut (36 items, Weapons.md §6) or the full roster (93) — decide before any icons are drawn
- [x] Confirm the twelve *Heavy X* renames (no "Heavy" in item names: retired modifier word, and it reads as a second prefix in titles)
- [x] Shields (Ballistic / Riot) become gear or are cut; they are not weapons
- [x] Melee roster craftable at its tier's station (blank canvases); firearms stay found-only, blanks = the ~40 % that roll clean

### Mechanics (the only new code)
- [x] Generalise the speargun path: `weapon.projectile` reads per-ammo `speed` / `gravity` / `retrievable` from the ammo item (`SpearBolt` becomes the shared projectile); bows, crossbows, nail / rivet guns, harpoon guns ride it
- [x] Shotguns: `pellets` + `spread` on the hitscan block, one trace per pellet, damage per pellet; still dead submerged
- [x] Flare gun: projectile that lands as a timed fog-beacon light (reuse the dropped-glowstick beacon path)
- [ ] Automatic fire flag for carbines / machine pistol / combat shotgun (hold-to-fire at `speed`), if not already implied by `speed`
- [x] `Constants`: projectile speeds / gravities / flare lifetime named there, never inline

### Data
- [x] `items.json`: one entry per roster row with `category`, `weapon` (+ `tool` block where §4 says it doubles as a tool), `water_factor` by type (knife 0.8 / spear-harpoon 0.9 / axe 0.45 / blunt 0.5), `found_only` on firearms; rename `rifle` → Bolt-Action Rifle, `pistol` → 9mm Pistol, `smg` → Compact SMG
- [x] New ammo items: `shotgun_shells`, `arrows`, `crossbow_bolts`, `nails`, `rivets`, `flares`, `harpoon`; retrievable ones flagged; ammo recipes at the matching station (arrows / bolts / nails cheap, shells / harpoons deeper)
- [x] `recipes.json`: a recipe per melee weapon at its band's station and material tier (wood/scrap T1, scrap T2, iron T3, steel T4–5); no recipe outputs a firearm
- [x] `loot.json`: the §5 matrix as weighted `found` entries under `tables.<district>.<band>` (first-listed melee w 3, others w 2, ranged w 2); `safe` tables get the T4–5 firearms
- [ ] Per-band stat table (damage / speed / knockback baseline per band, district multipliers per Weapons.md §3) generated once, hand-tuned for outliers; `Data` validates every `weapon.ammo` / `projectile` id exists
- [ ] Name check: no item name contains a modifier name or a retired word; worst-case title `<Prefix> Designated Marksman Rifle <of the Suffix>` measured in the hover plate at UI Size 2.0 (shorten to "DMR" if it wraps)

### Art
- [x] 16 px icon per item: reuse `icons/extra/` (machete, combat knife), slice a second Weapons sheet via `convert_weapons` where art exists, Icon Editor for the rest
- [ ] Held-tool paper-doll sprite reads from the icon (verify long items like rifles and pole hook don't clip the hand anchor)

### Gates
- [x] `m4_smoke`: shotgun spread hits, bow/crossbow projectile sticks and is retrievable, nail is not, flare lands as a light beacon, every firearm refuses to fire submerged
- [x] `m5_smoke` G: walk `object_records`; every found weapon's item sits in its cell of the §5 matrix; firearms never appear in a recipe output; modifier family/tier still matches the container
- [x] `m1_smoke`: one melee recipe per band crafts blank (no `mods`) at the right station
- [x] `save_smoke`: renamed ids (`rifle`, `pistol`, `smg`) load from an existing save via the id alias map, or the alias is added to the D3 cleaner
- [x] Sequential run of `m1 / m4 / m5 / save / lan` after the loot tables change (the LAN snapshot carries container records)

### Docs
- [x] `GameOverview.md` Loot / Combat bullets: district weapon flavour, "melee craftable, firearms found-only, spear guns are the underwater ranged line"
- [ ] `docs/MainGameLoop/Stage1–5`: the weapons the player should be holding per stage, taken from the launch cut
- [x] `MVP-checklist.md` M4 Combat + M5 Loot lines updated; `CLAUDE.md` weapon classes paragraph
- [x] `Weapons.md` §4 marked with what shipped vs. what is the content patch

## Deferred (post-launch surface, tracked so it isn't forgotten)

- [ ] Weapons beyond the launch cut (Weapons.md §4, everything not ticked in Step 7)
- [ ] Shields as off-hand gear with `defense` and a block input

- [ ] Second-order combining: `next` on hybrids and hybrid + base recipes
- [ ] Renewable trickle if depletion proves too harsh in play: red-moon stragglers dropping T1-modded scrap weapons (D5 hook)
- [ ] Residential "comfort" regen stat once the family has a second axis to spend
- [ ] Prefix-only Business ladder grammar (nouns as adjectives) revisited if it reads badly in the title strings during the GL-27 pacing check

**GATE:** find a modded district weapon in each district, sacrifice it, combine up one ladder and
across one pair at the bench, craft a blank melee weapon from the roster, apply the results to it
and to a crafted suit, fire a shotgun on a roof and a spear gun underwater, save/reload, and see the
same titles, colours and stats — offline and on a two-instance LAN session.

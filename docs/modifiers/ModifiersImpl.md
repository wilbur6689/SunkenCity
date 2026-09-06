# Modifiers — implementation contract

*Prepared 2026-09-05 from [../Modifiers.md](../Modifiers.md) (the design) against the M5 code.
This is the build plan: what the current system is, what the design changes, the decisions that
still gate implementation, the data schema, and the per-file change list. Companion to
`MultiplayerImpl.md` in role.*

---

## 1. Where the code is today (M5, LT-05..10)

| Piece | Location | Behaviour now |
|---|---|---|
| Mod defs | `data/modifiers.json` | 8 prefixes + 8 suffixes, `applies: [tool/weapon/gear]`, flat `stats`, `learnable` flag (Rusty junk) |
| Instance | stack dict `mods: {prefix: {id, power}, suffix: {id, power}}` | `power` 1–3 scales stats linearly; modded stacks never merge (`Inventory`, `Backpack`) |
| Roll | `LootGen.fill_containers` → `ItemMods.roll(rng, id)` | 35 % of found gear modded, 30 % of those both slots; random def from the class pool, random power |
| Stats | `ItemMods.stat/tool_of/unit_weight`, `Player.equip_stat/suit_stat/scrap_speed_mult` | summed prefix + suffix × power |
| Rarity | `ItemMods.rarity/rarity_color` | derived: none gray / one green / both blue / both at power 3 purple; shown in `inventory_ui` hover plate + bench |
| Library | `Player.known_mods: {id: best_power}` | **unlock**, not stock: learning keeps the best power seen; apply never consumes |
| Bench | `inventory_ui._build_modify_screen/_refresh_modify/_bench_act`; `PlayerActions.learn_mods/apply_mods` (host-validated, LAN) | LEARN destroys the donor, APPLY writes `mods` onto a clean piece once |
| Persistence | `SaveGame` character `known_mods`; `CharSync.sanitize` clamps ids/powers; `_clean_stack` validates instance mods | character save `VERSION` 2, world `WORLD_VERSION` 3 |
| Gates | `m5_smoke` G (rolling/rarity/stats) + H (bench backend); `save_smoke` (known_mods round trip); `menu_preview --screen=modify` | |

Loot-time context available for free: `World.towers` is passed to `LootGen`, so each container can
resolve its **tower's district** (`CityGen.tower_at(towers, cell).district`) and its **floor band**
(`CityGen.band_row` → `_band`). Pocket containers live in the VOID annex where `tower_at` is `{}`;
their district must come from the pocket's `entry` cell (`World.pockets[].entry`, the tower-side
doorway) — the band is already right because pockets share their doorway's rows.

## 2. What Modifiers.md changes, in code terms

| Design rule | Code consequence |
|---|---|
| District = family, band = tier | The roll stops being random-from-pool: a found piece's mod **is determined by where it sits** (tower district → family, floor band → tier). Randomness only in *whether* it rolls (and, later, which slot when a family has both). `LootGen` must pass district + band into `ItemMods.roll`. |
| 30 base cells + hybrids | `modifiers.json` is restructured: `families` (6) with per-tier entries, plus `hybrids` with explicit recipes. `Data` builds `modifier_defs` (id → def with `family`, `tier`, `slot`, `applies`, `stats`) from both. |
| Library is a stock count | `Player.known_mods {id: power}` → `Player.mod_library {id: count}`. LEARN = +1 per mod on the donor. APPLY consumes. Save/CharSync field rename + int clamp ≥ 0. |
| Combine (vertical, deterministic) | Rule, not data: two of the same id at tier N → the family's tier N+1 (if < 5). New `Player.combine_mods(a, b)` + `PlayerActions.combine_mods` (host-validated). |
| Combine (horizontal, named hybrids) | Data: `hybrids[].recipe = [id_a, id_b]` (same tier, same slot, different families). Output id must exist as a def. Hybrid + hybrid same id → tier N+1 of that hybrid if authored. |
| Slots: one prefix + one suffix, no cross-slot combine | Every def carries `slot`; `combine` refuses mixed slots; `apply` unchanged in shape (prefix_id, suffix_id). |
| Crafted = blank, found = pre-modded | Already true (`craft()` never rolls). State it in canon; no code. |
| `power` is gone | Tier lives in the def, so an instance is `mods: {prefix: {id}, suffix: {id}}`. `ItemMods.stat` reads `def.stats` directly (stats are authored per tier, or `family.stats_per_tier × tier`). `describe_mod(id)` prints the tier as a roman numeral. |
| Rarity | Four colours vs five tiers — decision D2 below. |

## 3. Decisions that gate the build (recommendation first)

**Settled 2026-09-05 with the user: D1 = 3 prefix + 3 suffix families · D2 = highest-tier
bucketing + gold · D3 = strip unknown mods on load, no version bump · D4 = ladders + the 30
first-order hybrids.** D5/D6 stand as recommended. The text below keeps the alternatives for the
record.

**D1 — Which slot does each family own?** The grid says one modifier per cell and the rules say
no cross-slot combining, so every cell needs a slot. Canon splits prefixes = power (tool/weapon
stats) and suffixes = aquatic utility (gear stats).
- **Recommended:** 3 prefix families + 3 suffix families. Prefix (power, `applies: tool/weapon`):
  **Industrial**, **Construction**, **Business**. Suffix (utility, `applies: gear` + weight-type
  stats on tool/weapon): **Residential**, **Commercial**, **Civil**. Effects: the armor open item
  answers itself (suits/accessories take suffixes; the three suffix families *are* the armor pool);
  first-order hybrids collapse to C(3,2) × 5 = **15 prefix + 15 suffix = 30 named hybrids** — a
  launch-sized authoring job instead of "hundreds"; and reading the map is literal ("weapons come
  from the working districts, dive gear from the living ones"). Cost: a piece found in a
  suffix-district rolls a suffix only, so weapons found in residential towers are never Sharp —
  which is the grid doing its job.
- Alternative A: every family has a prefix *and* a suffix line (60 cells). Doubles the authoring and
  the hybrid space; keeps every district relevant to every item class.
- Alternative B: slot decided by the item class at roll time (a family is slot-agnostic). Breaks
  "no cross-slot combining" as a meaningful rule.

**D2 — Rarity palette (5 tiers, 4 colours).**
- **Recommended:** colour = the **highest tier** on the piece, bucketed onto the existing palette
  plus one new top colour: none gray · T1–T2 green · T3–T4 blue · T5 purple · **both slots at T5 →
  gold** (new). Tier detail is carried by the modifier's own name (each tier has a distinct name)
  and the tooltip's "Tier N" line. Two-line change in `ItemMods.rarity`, one colour in
  `RARITY_COLORS`, `UITheme` untouched.
- Alternative: decouple — colour keeps meaning "how many mods" (gray/green/blue), purple = both at
  T5, and tier is text only. Cheapest, but T5 single-mod gear reads the same as T1.

**D3 — Existing saves.** Old `known_mods` ids (`sharp`, `of_the_deep`…) and old instance mods
(`{id, power}`) will not exist in the new defs.
- **Recommended:** no version bump. On load, `SaveGame` / `Inventory` **strip unknown modifier
  ids** from every stack (bag, equipment, backpacks, container records) and `mod_library` starts
  from `known_mods` translated to nothing (the field is simply ignored). Old worlds keep playing
  with a few clean pieces where modded ones were. `CharSync._clean_stack` already drops unknown
  ids — reuse that as the shared cleaner.
- Alternative: bump `WORLD_VERSION` 3 → 4 and character `VERSION` 2 → 3 and refuse old saves, as
  the 8 px migration did. Cleaner code, but it kills the current dev saves mid-cycle.

**D4 — Hybrid scope for launch.**
- **Recommended:** ship the six vertical ladders (rule-based, zero recipes to author) plus the
  **30 first-order hybrids** (with D1). Second-order combining (hybrid + base, hybrid + hybrid
  into a new name) is supported by the recipe schema but not authored — the post-launch surface.
- Alternative: vertical ladders only at launch; hybrids as the first content patch.

**D5 — Renewable supply.** Not blocking. Recommended: none in MVP — depletion is the descent
pressure (LT-27/GL-28), and because a T4 also drops *directly* in the Dark, vertical combining is
a **shortcut to reach a tier above your dive depth**, not the only path (a T5 is "16 T1s" only if
you refuse to dive). Compensate by raising the roll odds now that every found piece is consumable
stock: `ROLL_MOD_CHANCE` 0.35 → ~0.6, `ROLL_BOTH_CHANCE` stays. If a trickle is wanted later,
red-moon stragglers dropping T1-modded scrap weapons is the one renewable hook the game has.

**D6 — Who authors the 30 base cells + 30 hybrids.** The user is designing the stage × district
modifiers now. The schema below is built so the content drops in as data; the code will ship with
**placeholder names/stats per family** (one stat axis each) that the user's table replaces.

## 4. Data schema (`data/modifiers.json`, v2)

```jsonc
{
  "_comment": "...",
  "families": {
    "industrial": {
      "slot": "prefix",
      "applies": ["tool", "weapon"],
      "stats_per_tier": {"tool_damage": 1},          // tier N mod = N × this (default scaling)
      "tiers": [                                      // exactly 5; index = tier-1
        {"id": "ind_1", "name": "Rough"},
        {"id": "ind_2", "name": "Tempered"},
        {"id": "ind_3", "name": "Forged", "stats": {"tool_damage": 3, "knockback": 0.5}}, // optional override
        {"id": "ind_4", "name": "Hardened"},
        {"id": "ind_5", "name": "Foundry"}
      ]
    },
    "residential": {"slot": "suffix", "applies": ["gear", "tool", "weapon"], "stats_per_tier": {"weight_mult": -0.06}, "tiers": [...]},
    ...
  },
  "hybrids": [
    {
      "id": "riot_3", "name": "Riot", "slot": "prefix", "tier": 3,
      "applies": ["tool", "weapon"],
      "recipe": ["ind_3", "con_3"],                   // same tier, same slot, different families
      "stats": {"tool_damage": 2, "knockback": 1.5},
      "next": "riot_4"                                 // optional: two riot_3 → riot_4 (vertical on a hybrid)
    }
  ],
  "junk": [                                            // found-only, never learnable (was Rusty)
    {"id": "rusty", "name": "Rusty", "slot": "prefix", "applies": ["tool", "weapon"], "stats": {"tool_damage": -1, "tool_speed": -0.1}}
  ]
}
```

`Data._load` flattens this into `modifier_defs: {id → {id, name, slot, tier, family|hybrid,
applies, stats, learnable}}` and keeps `families`/`hybrids` for the bench UI and the combiner.
Validation at load: 6 families, 5 tiers each, unique ids, hybrid recipe inputs exist / same tier /
same slot / different families, `next` targets exist, stat keys ∈ the known set.

Band → tier: `dry 1 · shallows 2 · cold 3 · dark 4 · crush 5` (`ItemMods.TIER_OF_BAND`).

## 5. Change list by file

**`scripts/items/item_mods.gd`**
- `MAX_POWER` → gone; add `MAX_TIER = 5`, `TIER_OF_BAND`, `RARITY_COLORS.legendary` (gold).
- `roll(rng, id, district, band)`: class-gate as now; family = district (fallback: skip when the
  family's slot doesn't `applies` to the class — e.g. a suffix family on a weapon that can't take
  it); tier = band; `ROLL_MOD_CHANCE` for "modded at all"; `junk` rolls at a small chance on
  tool/weapon as today's Rusty did. With D1 a piece can carry at most the one slot its district
  owns, so `ROLL_BOTH_CHANCE` only matters if D1-alt-A is chosen.
- `stat`: `def.stats` (authored or `stats_per_tier × tier`) — no power multiplier.
- `rarity`: per D2. `describe_mod(id)`: "Forged III: +3 damage". `display_name` unchanged.
- New: `slot_of(id)`, `tier_of(id)`, `family_of(id)`, `combine_result(a, b) -> String` (vertical
  rule → family tier+1; hybrid `recipe` lookup; hybrid `next`; "" when none).

**`scripts/world/loot_gen.gd`**
- Resolve `district` per record: `CityGen.tower_at(towers, rec.cell).district`; for annex cells,
  the pocket whose `rect` holds the cell → `tower_at(towers, pocket.entry).district` (pass
  `World.pockets` in from `city.gd`, or resolve on `World`). Pass `_band(...)` too.
- Safes: keep `safe` tables for *what* drops; family/tier still from location.

**`scripts/player/player.gd`**
- `known_mods` → `mod_library: Dictionary` (id → count).
- `learnable_mods(stack)` → "has at least one learnable mod" (duplicates now always teach).
- `learn_mods(stack)`: +1 per learnable mod; returns the names.
- `apply_mods(stack, prefix_id, suffix_id)`: require count ≥ 1 for each chosen id, slot matches,
  `applies` matches class, piece unmodified; decrement on success.
- New `combine_mods(a_id, b_id) -> String`: both counts (2 if a == b), same slot, same tier,
  result from `ItemMods.combine_result`; decrement inputs, increment result.
- Instance mods written as `{"id": id}` (no power).

**`scripts/player/player_actions.gd`**
- `ALLOWED` + dispatcher: add `combine_mods` (args: a_id, b_id); bench-in-reach check like the
  others; `_say` the result name.

**`scripts/ui/inventory_ui.gd` (Modify tab)**
- Replace the flat learned list with a **6 × 5 grid** (family rows × tier columns; cell = count
  badge, tinted by family, dim when 0) — it is the "map of where you have been" the design wants —
  plus a hybrids list beneath (only ids with count > 0). Click a cell to select it for APPLY (one
  prefix-slot + one suffix-slot selection, as now) or for COMBINE (two selections of the same
  slot; the button shows the result name or "no recipe"). Existing LEARN / APPLY flow otherwise
  unchanged; APPLY now consumes and refreshes counts.
- Hover plate: add a "Tier N" line via `describe_mod`.

**`scripts/data/data.gd`** — new loader/validator per §4; `Data.modifiers` keeps the raw file.

**`scripts/data/save_game.gd`** — write/read `mod_library`; read legacy `known_mods` and ignore;
strip unknown instance mods on load (D3) through one shared `ItemMods.clean_stack(s)` used by
`SaveGame`, `CharSync._clean_stack`, and the world-record loader.

**`scripts/net/char_sync.gd`** — sanitize `mod_library` (known ids, `int ≥ 0`); `_clean_stack`
drops `power`, keeps `{id}`.

**Tests**
- `m5_smoke` G: rolled mods match their container's district/band (walk `object_records`, resolve
  district + band, assert `family_of`/`tier_of`); rarity buckets per D2; stats no longer scale by
  power. H: library counts (learn +1, duplicates count), apply consumes, vertical combine
  (2 × T3 → T4, refuses mixed tier/slot, refuses at T5), one hybrid recipe, junk unlearnable.
- `save_smoke`: `mod_library` round trip; a legacy `known_mods` file loads clean.
- `menu_preview --screen=modify`: seed `mod_library` with a few cells + one hybrid and a clean
  knife on the bench.
- `lan_smoke.tscn`: `combine_mods` action validated on the host (bench reach, counts).

**Docs after the build**
- `GameOverview.md` Loot bullets + Key Decisions ("no modifier schematics" → "recipes, not
  rerolls"; library is consumed; rarity rule per D2); `MVP-overview.md` Modifiers line + Open
  Items; `OpenQuestions.md` LT-05/06/08/09 amendment lines; `MVP-checklist.md` M5 items re-ticked
  under the new rules; `CLAUDE.md` M5 summary; stage docs: S3-11 (numeric-only mods still holds),
  the "Modification Bench" loop steps in Stage 3–5 (learn → **stock**, combine).

## 6. Build order

1. Data schema + `Data` loader/validator with **placeholder families** (D1 slots, one stat axis
   each, tier names "T1…T5") and two sample hybrids — so the code can land before the content.
2. `ItemMods` rewrite (defs, tiers, combine, rarity per D2) + `LootGen` district/band roll.
3. `Player` library/learn/apply/combine + `PlayerActions.combine_mods` + `CharSync` + `SaveGame`
   (D3 cleaner).
4. Modify tab grid + combine UI; `menu_preview` seed.
5. Gates: `m5_smoke`, `save_smoke`, `lan_smoke.tscn`; run `m1/m4/title` for regressions.
6. Drop in the user's 30 + 30 table; docs pass.

Estimated touch: ~9 scripts, 1 data file, 3 test scripts; no scene changes.

---

## Appendix A — Naming framework (district × band)

A modifier name has to tell the player three things at a glance: **which slot** it is (adjective =
prefix, "of the …" = suffix), **which family** it came from (the district's vocabulary), and **which
tier** it is (how deep it was found). The framework below gives each axis a fixed vocabulary so the
30 base names and 30 hybrids can be generated by combination rather than invented one by one.

### A.1 The family axis — one vocabulary and one stat identity per district

| District | Slot | Stat identity (what the ladder scales) | Vocabulary pool | Tone |
|---|---|---|---|---|
| **Industrial** | prefix | raw damage (`tool_damage`) | metalworking stages: rough, tempered, forged, hardened, foundry, mill, quench, anvil, slag | brute, hot, heavy |
| **Construction** | prefix | knockback + scrap speed (demolition) (`knockback`, `scrap_speed`) | structural members and site kit: braced, shored, riveted, girdered, load-bearing, piled, wrecking, rebar | blunt, heavy-handed, unfinished |
| **Business** | prefix | attack/tool speed (`tool_speed`) | corporate efficiency: brisk, efficient, streamlined, optimised, executive; or the career ladder: junior, associate, senior, director, executive | crisp, clipped, a little smug |
| **Residential** | suffix | weight and comfort (`weight_mult`, later regen) | the rooms of a home, top to bottom: porch, landing, hallway, pantry, cellar | warm, domestic, worn-in |
| **Commercial** | suffix | air and swim (`oxygen`, `swim`) — the drowned dive shop | a shop, top to bottom: awning, shopfront, showroom, stockroom, vault | bright, retail, aspirational |
| **Civil** | suffix | defence, cold, light (`defense`, `cold`, `light`) | a public building, top to bottom: helipad, lobby, ward, precinct, morgue/archive | institutional, cool, official |

Rules of thumb: never use a **material tier word** the item ladder already owns (Scrap, Iron,
Steel, Wood) — "Iron Knife" is an item, not a mod; keep prefixes short (the title is
`Prefix Item of the Suffix`, so ≤ 10 letters reads best); no word appears in two families.

### A.2 The tier axis — the band's tone, and two ways to show depth

| Tier | Band | Stage theme (from the stage docs) | Tone words to borrow |
|---|---|---|---|
| 1 | The Dry | wood, roofs, sun, salvage, the first night | weathered, sun-bleached, salvaged, rooftop, rain-washed, bare |
| 2 | The Shallows | tanks and pumps, the tide line, sealed rooms | tide, waterline, sodden, silted, brackish, drowned |
| 3 | The Cold | iron, locks, sharks, the slow | cold, numb, still, rimed, grey, iron-bound |
| 4 | The Dark | steel, light as a resource, the Drowned | black, blind, sunless, lantern, hollow, deep |
| 5 | The Crush | mastery, pressure, the floor | crushing, abyssal, bedrock, pressure, leaden, final |

Two patterns for expressing the tier in a name — pick one per slot and keep it consistent:

- **Pattern A — the escalating ladder** (recommended for **prefixes**). Five words from the
  family pool ordered by intensity, so the fifth word simply *sounds* stronger than the first.
  Example, Industrial: *Rough → Tempered → Forged → Hardened → Foundry*. Tier is felt, not spelled.
- **Pattern B — the descent through a building** (recommended for **suffixes**). Each suffix
  family is one building type; its five nouns are its floors from roof to basement, so "of the
  Cellar" is visibly deeper than "of the Porch". Example, Residential: *of the Porch → of the
  Landing → of the Hallway → of the Pantry → of the Cellar*. The name is literally where you found it.
- Optional **Pattern C — band epithet**: family root + tone word ("of the Cold Ward", "Sunless
  Forged"). Longer; use only where A/B run out of good words.

### A.3 Worked ladders (placeholders — replace freely, keep the shape)

| Family | T1 Dry | T2 Shallows | T3 Cold | T4 Dark | T5 Crush |
|---|---|---|---|---|---|
| Industrial (prefix) | Rough | Tempered | Forged | Hardened | Foundry |
| Construction (prefix) | Braced | Shored | Riveted | Girdered | Load-Bearing |
| Business (prefix) | Brisk | Efficient | Streamlined | Optimised | Executive |
| Residential (suffix) | of the Porch | of the Landing | of the Hallway | of the Pantry | of the Cellar |
| Commercial (suffix) | of the Awning | of the Shopfront | of the Showroom | of the Stockroom | of the Vault |
| Civil (suffix) | of the Helipad | of the Lobby | of the Ward | of the Precinct | of the Archive |

### A.4 Hybrids — name the place or trade the two districts share

A first-order hybrid is two same-tier, same-slot families combined. Name it after the **thing the
two districts have in common**, then carry the tier with Pattern A/B words or a numeral.

| Pair | Shared idea | Prefix/suffix root | Stat blend |
|---|---|---|---|
| Industrial + Construction | demolition, heavy plant | *Wrecking* | damage + knockback |
| Industrial + Business | the contract, the mill office | *Contract* / *Franchise* | damage + speed |
| Construction + Business | development, permits | *Developer* / *Zoned* | knockback + speed |
| Residential + Commercial | the high street, the arcade | *of the Arcade* | weight + swim |
| Residential + Civil | the neighbourhood, the parish | *of the Parish* | weight + defence |
| Commercial + Civil | the market hall, customs | *of the Customs House* | air + cold/light |

Tier on a hybrid: either a five-step ladder of its own (*Wrecking → Demolition → Levelling →
Razing → Annihilating*) or the root plus a tier epithet (*Cold Wrecking*, *Abyssal Wrecking*).
Ladders read better; epithets are faster to author.

### A.5 Checklist for each name

1. Slot is obvious from the grammar (adjective vs "of the …").
2. Family is guessable from the word alone by someone who knows the six districts.
3. Tier is guessable from the word's intensity or its floor in the building.
4. No collision with item names, material tiers, or another family's word.
5. Fits the title: `<Prefix> <Item> <of the Suffix>` under ~32 characters for the worst case
   (*Load-Bearing Cutting Torch of the Customs House* is the outlier to test against).
6. The stat it scales is the family's identity — a name that promises air should not add damage.

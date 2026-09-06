# Prompt — generate the SunkenCity modifier names

Paste everything below the line into a fresh session. Output drops into `data/modifiers.json`
(schema in `ModifiersImpl.md` §4) with ids already in place.

---

You are naming the gear modifiers for **SunkenCity**, a 2D side-scrolling survival sandbox
(Terraria × 7 Days to Die) set in a procedurally generated city that was deliberately flooded to
contain a zombie virus. The player starts on a rooftop and dives progressively deeper through
submerged skyscrapers. Tone: grounded, weathered, a little grim, occasionally dry-humoured; no
fantasy or sci-fi vocabulary (no runes, plasma, arcane, quantum).

## How modifiers work

- A found weapon or piece of gear carries up to **one prefix and one suffix**. Prefixes are
  adjectives that scale a weapon/tool stat; suffixes are "of the …" phrases that scale a
  gear/utility stat. A modded item reads as `<Prefix> <Item Name> <of the Suffix>`, e.g.
  *Forged Cutting Torch of the Ward*.
- Modifiers sit on a **6 × 5 grid**: six city **districts** (each a *family* with its own
  vocabulary and one stat identity) × five **depth bands** (each a *tier*, 1 shallow to 5 deep).
  A modifier's family is the district it was found in; its tier is the depth it was found at.
- **Three districts are prefix families, three are suffix families.**
- Two same-tier modifiers from different families of the same slot combine into a named
  **hybrid**. There are six family pairs, each at five tiers.

## The families

| District | Slot | Stat identity | Vocabulary pool | Tone |
|---|---|---|---|---|
| Industrial | prefix | raw damage | metalworking stages: rough, tempered, forged, hardened, foundry, mill, quench, anvil, slag | brute, hot, heavy |
| Construction | prefix | knockback and demolition speed | structural members and site kit: braced, shored, riveted, girdered, load-bearing, piled, rebar, wrecking | blunt, unfinished |
| Business | prefix | attack/tool speed | corporate efficiency or the career ladder: brisk, efficient, streamlined, optimised, executive, junior, associate, director | crisp, clipped, a little smug |
| Residential | suffix | carried weight and comfort | the rooms of a home from roof to basement: porch, landing, hallway, pantry, cellar, attic, stairwell | warm, domestic, worn-in |
| Commercial | suffix | air supply and swim speed (a drowned dive shop) | a shop from roof to basement: awning, shopfront, showroom, counter, stockroom, vault | bright, retail, aspirational |
| Civil | suffix | defence, cold resistance, light | a public building (hospital, police, city hall) from roof to basement: helipad, lobby, ward, precinct, records, archive, morgue | institutional, cool, official |

## The tiers (depth bands)

| Tier | Band | Theme | Tone words to borrow |
|---|---|---|---|
| 1 | The Dry | rooftops, sun, wood, salvage, the first night | weathered, sun-bleached, salvaged, rooftop, rain-washed, bare |
| 2 | The Shallows | air tanks and pumps, the tide line, sealed rooms | tide, waterline, sodden, silted, brackish, drowned |
| 3 | The Cold | iron, locked doors, sharks, numbing cold | cold, numb, still, rimed, grey, iron-bound |
| 4 | The Dark | steel, light as a resource, swimmers in the black | black, blind, sunless, lantern, hollow, deep |
| 5 | The Crush | mastery, crushing pressure, the city floor | crushing, abyssal, bedrock, pressure, leaden, final |

## Naming patterns (follow these exactly)

- **Prefixes use an escalating ladder.** Five single words from the family's vocabulary, ordered
  so each sounds stronger than the last; tier 5 should feel like the top of that trade. Tier is
  felt, not spelled out. Example shape: Rough → Tempered → Forged → Hardened → Foundry.
- **Suffixes descend through a building.** Each suffix family is one building type; its five
  "of the …" nouns are its floors from roof (tier 1) to basement (tier 5), so the deepest name is
  literally the lowest room. Example shape: of the Porch → of the Landing → of the Hallway →
  of the Pantry → of the Cellar.
- **Hybrids are named for what the two districts share** (a trade, a place, an institution), then
  given their own five-step ladder (prefix hybrids) or five-floor descent (suffix hybrids).
  - Industrial + Construction: demolition, heavy plant → damage + knockback
  - Industrial + Business: the contract, the mill office → damage + speed
  - Construction + Business: development, permits, zoning → knockback + speed
  - Residential + Commercial: the high street, the arcade → weight + swim
  - Residential + Civil: the neighbourhood, the parish → weight + defence
  - Commercial + Civil: the market hall, customs → air + cold/light

## Hard rules

1. Slot must be obvious from grammar: prefixes are one adjective (a hyphenated compound is
   allowed once per ladder at most); suffixes are "of the <Noun>" or "of the <Adjective Noun>".
2. Family must be guessable from the word alone by someone who knows the six districts.
3. Tier must be guessable from intensity (prefix) or floor (suffix).
4. **Never** use these words: Scrap, Iron, Steel, Wood, Stone, Plastic, Cloth (they are item and
   material names), or Sharp, Swift, Heavy, Rusty, Deep, Currents, Shore, Warmth, Sight
   (retired names).
5. No word may appear in two ladders. No duplicates anywhere across the 60 names.
6. Prefixes ≤ 11 letters; suffix nouns ≤ 2 words. Test the worst case against a long item
   name: `<Prefix> Cutting Torch <of the Suffix>` should stay under ~34 characters.
7. A name may only promise its family's stat (nothing about air on a damage prefix, etc.).
8. Plain English; avoid rare or archaic words a player would have to look up.

## Output

Produce **60 names**: 30 base (6 families × 5 tiers) and 30 hybrids (6 pairs × 5 tiers).
Return them in this exact form, nothing else before it:

### Base ladders
One markdown table per slot with columns `Family | T1 | T2 | T3 | T4 | T5`.

### Hybrid ladders
One markdown table per slot with columns `Pair | Shared idea | T1 | T2 | T3 | T4 | T5`.

### JSON ids
A JSON object mapping every name to a stable snake_case id built as
`<fam>_<tier>` for base (fam ∈ ind, con, bus, res, com, civ) and `<pairroot>_<tier>` for hybrids
(pairroot = the shared-idea word in snake_case), e.g. `{"Forged": "ind_3", "of the Ward": "civ_3",
"Wrecking": "wrecking_1"}`.

### Notes
Up to five bullets: any rule you bent and why, and any two alternates you considered for a ladder
where the pick was close.

Do the naming in one pass, then re-read all 60 against the hard rules and fix collisions before
you answer.

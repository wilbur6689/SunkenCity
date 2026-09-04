# SunkenCity — Districts (Building-Type Biomes)

*Design session 2026-09-04. Replaces several items in [GameOverview.md](GameOverview.md) and
[MVP-overview.md](MVP-overview.md) — see **Canon Changes** at the bottom before implementing.*

Terraria's biomes are large vertical slices of the world. SunkenCity's equivalent is
**horizontal**: the city is divided into districts, each a cluster of towers sharing one building
type. Depth still supplies difficulty; districts supply *variety* — different rooms, different
scrap, different shapes at the same depth.

Every district reaches every depth band. A district is not a difficulty zone.

---

## District Types

| Type | Notes |
|---|---|
| **Residential** | The default. Fills every tower not claimed by another district. Many small rooms, doors, tight floors. |
| **Commercial** | Retail and office. |
| **Business** | Small service firms — lawyers, accountants, agencies. |
| **Civil** | Hospital, police, city admin, post office. |
| **Industrial** | Large open floors, tall ceilings. |
| **Construction** | Unfinished towers — a giant construction site. Residential silhouette, far more breaches, near-fully flooded top to bottom. Distinct material palette (**TBD**). |

**Mixed-use is removed.** A tower's district sets its template pool for every floor. This is a
direct reversal of prior canon.

---

## City Layout

- **52 towers**, double-wide standard, **rare triple-wide** (correlation with district type is
  **open**).
- World is roughly **5,500 × 400 blocks** (up from 2,500 to fit 52 towers at the same spacing).
- **Center is reserved:** a cluster of **6 residential towers**, containing the starting hospital.
  No other district may be placed at the center.
- The five non-residential districts are **5–6 towers each** and are shuffled anywhere outside the
  center. No positional weighting — industrial can land at an edge or beside civil.
- **Minimum 1-tower residential buffer** between any two non-residential districts. Districts
  never touch.
- **Residential is not placed — it is what remains.** Assign the five district clusters, then fill
  every unclaimed tower with residential. Buffers emerge from the placement constraint rather than
  being authored.
- Open water and a seafloor beyond the last tower on each side; invisible wall at the map border.

**Rough budget:** 5 districts × 5–6 = 25–30 towers · center = 6 · residential fill ≈ 16–21.
Residential ends up roughly half the city.

### Placement algorithm (suggested)

1. Reserve the 6 center slots as residential.
2. For each of the five district types, roll a size (5–6) and place the cluster in a contiguous run
   of free towers outside the center.
3. Reject any placement adjacent to another non-residential cluster (enforces the 1-tower buffer).
4. Fill all remaining towers with residential.

---

## Skyline

- **Near-flat.** Every tower's crown is within **10 blocks** of every other tower's — roughly one
  or two floors of jitter. Heights are randomly assigned per tower within that band.
- **No taper.** The old bell curve and the shorter, mostly-submerged edge buildings are gone. The
  city is a uniform slab that ends at open water.
- **The starting tower is no longer the crown.** It sits at a random height like everything else
  and is identifiable only as the hospital — a civil landmark inside the residential center.
- **Every tower is a full shaft to ground level.** ~52 viable descent routes rather than a few deep
  ones.

Consequence: **The Dry** is now a consistent horizontal layer across the whole city, so surface
gameplay is lateral rooftop exploration rather than following a slope downward.

---

## Floors & Rooms

- **Floor height varies by district: 6–10 blocks.** 6 remains the minimum — the 3-block jump and
  the two-jump rule between floors survive everywhere, so ladders and ropes stay mandatory.
- **Room width also varies by district.** Industrial trends wide and tall; residential trends small
  and compartmented.
- **Taller floors mean fewer floors, not taller towers.** An industrial tower at 10-block floors
  has proportionally fewer floors than a residential tower at 6, so both crown within the 10-block
  skyline band and both bottom out at the same ground level (~300 blocks).

---

## Bands

- **Band boundaries are fixed absolute depths, identical citywide.** They do not shift per district
  or per tower.
- **A floor that straddles a boundary takes the shallower (upper) band** — enemies, loot table, and
  pressure all resolve to the band above. Applied at the **floor** level, not per room.
- Because floor height is uniform within a district, a given floor index maps to a consistent band
  for that district. Different districts cross bands at different floor counts — a 10-block-floor
  industrial tower crosses fewer, larger floors per band than a residential one.

---

## Canon Changes

These contradict existing docs and need to be propagated:

| Doc | Current | New |
|---|---|---|
| GameOverview · The City | ~26 double-wide towers | 52 |
| Both | World ≈ 2,500 × 400 blocks | ≈ 5,500 × 400 |
| MVP-overview · World | ~40 towers, bell-curve skyline | 52 towers, flat skyline (stale — never got the 2026-09-01 revision) |
| Both | Mixed-use per floor | Removed — one building type per tower |
| GameOverview · The City | Central 80 % high-rise, edge 20 % short and submerged, ~39–56 floors | Flat: all crowns within 10 blocks, no taper |
| GameOverview · The City | Starting tower is the skyline's tallest point | Random height; landmark by function only |
| Both | 6-block building floors | 6–10 blocks, by district |
| MVP-overview · Explicitly OUT | Districts are post-MVP | Districts are in scope |
| GameOverview · Building types | Five room zones | Six — construction added |

---

## Open Items

- **Construction material palette** — what a construction site is built of and scraps into.
- **Triple-wide correlation** — random, or weighted toward industrial/commercial?
- **Per-district floor height and room dimension tables** — the actual numbers for all six types.
- **World-gen and save-file cost** at 5,500 × 400 (~2.2 M tiles, up from ~1 M) with the whole world
  in RAM on the host. Water-sim wake lists on large floods are the likely pressure point.
- **Object modifiers** — not discussed this session; still per GameOverview.

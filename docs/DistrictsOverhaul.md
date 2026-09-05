# SunkenCity — Districts (Building-Type Biomes)

*Design session 2026-09-04; guided review the same day settled the open items. Replaces several
items in [GameOverview.md](GameOverview.md) and [MVP-overview.md](MVP-overview.md) — see
**Canon Changes** at the bottom before implementing.*

**Units:** all sizes below are in **cells** (8 px = 1 ft, the 2026-09-04 grid). Where the original
session spoke in the old 16 px blocks the value is given in parentheses — every old block is a 2×2
group of cells.

Terraria's biomes are large vertical slices of the world. SunkenCity's equivalent is
**horizontal**: the city is divided into districts, each a cluster of towers sharing one building
type. Depth still supplies difficulty; districts supply *variety* — different rooms, different
scrap, different shapes at the same depth.

Every district reaches every depth band. A district is not a difficulty zone.

---

## District Types

| Type | Floor height | Room width | Notes |
|---|---|---|---|
| **Residential** | 12 (6) | 16–24 | The default. Fills every tower not claimed by another district. Many small rooms, doors, tight floors. |
| **Commercial** | 14 (7) | 20–38 | Retail and office. |
| **Business** | 12 (6) | 16–28 | Small service firms — lawyers, accountants, agencies. |
| **Civil** | 14 (7) | 20–38 | Hospital, police, city admin, post office. The hospital rooms live here — there is no authored hospital anywhere else. |
| **Industrial** | 20 (10) | 28 – whole wing | Large open floors, tall ceilings. A wing may be one single room. |
| **Construction** | 12 (6) | 16–24 | Unfinished towers — a giant construction site. Residential silhouette; below the waterline nearly every floor is breached and flooded (no sealed rooms survive). Keeps the dry cap, barrier and roof hatch like any other tower. |

Floor height is the slab-top-to-slab-top pitch; 12 is the minimum (`SLAB_T` 2 + 10 open rows), so
the 6-cell jump and the two-jump rule between floors survive everywhere and ladders/ropes stay
mandatory. Room width is a filter on the template pool (like the existing depth-range filter).

**Construction palette:** metal frame (outer walls, stair and shaft walls, plinth) with wood
temporary flooring and wood partitions — **wood and metal only**, no stone; back walls only below
the waterline. It scraps into wood and scrap metal, so GL-28 (no surface iron) holds.

**Mixed-use is removed.** A tower's district sets its template pool for every floor. This is a
direct reversal of prior canon.

**Triple-wide towers** (three wings, two shafts) are rare and **weighted toward industrial and
commercial; never residential or construction**, so the centre's six towers stay double-wide and
predictable to hop.

---

## City Layout

- **52 towers**, double-wide standard, rare triple-wide (see above).
- **Gaps are jumpable everywhere: 5–10 cells (5–10 ft)** between neighbouring towers (2026-09-05;
  the review's 2–6 hid the water below in a slit). The world width is *derived* from the tower
  count and the gap rule: ≈ 6,900 cells of city (≈ 3,450 old blocks; the session's 5,500 assumed
  the old wide edge spacing), 800 tall, plus the pocket annex east of it.
- **Center is reserved:** a cluster of **6 residential towers**. No other district may be placed at
  the center. There is **no hospital and no authored supply room** at the start — the roof-locked
  opening relies on trees, roof gear and the wood tripod, and with 52 similar-height roofs there
  is plenty to gather.
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

### Placement algorithm

1. Reserve the 6 center slots as residential.
2. For each of the five district types (shuffled order), roll a size (5–6) and place the cluster
   in a contiguous run of free towers outside the center.
3. Reject any placement adjacent to another non-residential cluster (enforces the 1-tower buffer);
   retry with a new position, then a smaller size.
4. Fill all remaining towers with residential.

The algorithm is count-driven (it works on however many tower slots the width holds), so test
slices of the city still get districts.

---

## Skyline

- **Near-flat.** Every tower's crown is within **10 cells (5 old blocks)** of every other tower's —
  under one floor of jitter. Heights are randomly assigned per tower within that band; neighbouring
  roofs keep the existing 4–10-cell step so the skyline reads as varied but hoppable.
- **No taper.** The old bell curve and the shorter, mostly-submerged edge buildings are gone. The
  city is a uniform slab that ends at open water.
- **The starting tower is not the crown.** It is simply the centre-most of the six centre towers,
  at a random height like everything else, with nothing authored on or in it.
- **Every tower is a full shaft to ground level.** ~52 viable descent routes rather than a few deep
  ones. A tower's floor count is whatever its district's floor height divides into the crown-to-
  ground distance; the remainder is a solid plinth (the existing crown lift), so every tower
  bottoms out on the same ground row.

Consequence: **The Dry** is now a consistent horizontal layer across the whole city, so surface
gameplay is lateral rooftop exploration rather than following a slope downward.

---

## Floors & Rooms

- **Floor height varies by district** per the table above (12 / 14 / 20 cells). 12 remains the
  minimum.
- **Room width varies by district** per the table above. Industrial trends wide and tall;
  residential trends small and compartmented.
- **Taller floors mean fewer floors, not taller towers.** An industrial tower at 20-cell floors
  has proportionally fewer floors than a residential tower at 12, so both crown within the 10-cell
  skyline band and both bottom out at the same ground level (~600 cells / 300 old blocks below the
  crowns).

---

## Bands

- **Band boundaries are fixed absolute depths, identical citywide.** They do not shift per district
  or per tower.
- **A floor that straddles a boundary takes the shallower (upper) band** — the band is resolved
  from the floor's **ceiling row**. Applied at the **floor** level, not per room, for **enemy
  seeding, loot tables and the HUD/F3 band label**.
- **The cold and crush damage gates stay per cell.** Pressure and cold are physical: they bite at
  the exact depth, so a crush floor whose ceiling sits one row above the line is not a safe room.
- Because floor height is uniform within a district, a given floor index maps to a consistent band
  for that district. Different districts cross bands at different floor counts — a 20-cell-floor
  industrial tower crosses fewer, larger floors per band than a residential one.

---

## Budget (acceptance bar)

Recorded as a regression fence, not a target — the projected numbers sit well inside it:

| Measure | Bar |
|---|---|
| Full generation (incl. flood) | ≤ 5 s |
| World in host RAM (grid layers + water) | ≤ 64 MB |
| World save file | ≤ 10 MB |
| Water sim on a fresh seed | asleep within a few seconds of load |

---

## Canon Changes

These contradict existing docs and need to be propagated:

| Doc | Current | New |
|---|---|---|
| GameOverview · The City | ~26 double-wide towers | 52 |
| Both | World ≈ 4,800 × 800 cells (2,500 × 400 old blocks) | ≈ 6,700 × 800 cells of city, width derived from 52 towers at hoppable gaps |
| MVP-overview · World | ~40 towers, bell-curve skyline | 52 towers, flat skyline (stale — never got the 2026-09-01 revision) |
| Both | Mixed-use per floor | Removed — one building type per tower |
| GameOverview · The City | Central 80 % high-rise, edge 20 % short and submerged, ~39–56 floors | Flat: all crowns within 10 cells, no taper |
| GameOverview · The City | Starting tower is the skyline's tallest point; authored medical room in a neighbouring tower | Random height; no authored hospital or supply room at the start — hospitals are civil-district rooms |
| Both | Spawn-cluster gaps 2–6 cells, wider toward the edges | 5–10 cells citywide |
| Both | 12-cell (6-block) building floors | 12 / 14 / 20 cells by district |
| MVP-overview · Explicitly OUT | Districts are post-MVP | Districts are in scope |
| GameOverview · Building types | Five room zones | Six — construction added |
| Landmarks | Starting hospital tower + relay stations | Relay stations only |

---

## Open Items

- **Object modifiers** — not discussed; still per GameOverview.
- **Construction room library** — templates and a small scaffold/site object pack are needed before
  the district reads as more than a bare frame.

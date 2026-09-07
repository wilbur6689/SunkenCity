# Flora Overhaul Checklist

Tracker for the plant rebuild described in [flora.md](flora.md). One row per district (plus the
two shared sets); a district is **overhauled** when its module exists in `tools/flora_art/`, all
seven species × three stages are built by `python tools/build_flora.py <module>`, the contact
sheet has been reviewed against the flora.md §8 checklist, and the gates pass. Tick items as they
land and keep the status table current.

## Status

| District | Module | Species (of 7) | Stages built | Sway strips | Seeds | Preview reviewed | Gates | Overhauled |
|---|---|---|---|---|---|---|---|---|
| Residential | `tools/flora_art/res.py` | 7 | 21 / 21 | yes | plane, apple, maple | 2026-09-06 | roof / flora_editor / district / save | **[x] 2026-09-06** |
| Business | `tools/flora_art/bus.py` | 7 | 21 / 21 | yes | cypress, locust, ficus | 2026-09-06 | roof / flora_editor / district / save | **[x] 2026-09-06** |
| Commercial | `tools/flora_art/com.py` | 7 | 21 / 21 | yes | palm, magnolia, bougainvillea | 2026-09-06 | roof / flora_editor / district / save | **[x] 2026-09-06** |
| Civil | `tools/flora_art/civ.py` | 7 | 21 / 21 | yes | acorn, linden, birch | 2026-09-06 | roof / flora_editor / district / save | **[x] 2026-09-06** (great oak landmark deferred) |
| Industrial | `tools/flora_art/ind.py` | 7 | 21 / 21 | yes | ailanthus, birch, sumac | 2026-09-06 | roof / flora_editor / district / save | **[x] 2026-09-06** |
| Construction | `tools/flora_art/con.py` | 7 | 21 / 21 | yes (moss static) | willow, poplar, elder | 2026-09-06 | roof / flora_editor / district / save | **[x] 2026-09-06** |
| Wild (shared roof set) | `tools/flora_art/wild.py` | 0 of 5 | 0 / 15 | — | — | — | — | [ ] |
| Submerged | `tools/flora_art/sub.py` | 0 of 3 | 0 / 3 | — | — | — | — | [ ] |

All six districts are overhauled (2026-09-06). `CityGen._district_flora` keeps a residential fallback only
for a district id with no set at all; the test tower (no district) draws from the union. Remaining: the two
shared sets below and the cross-cutting items.

## Per-district checklist

Copy this block when starting a district; the species rosters are in flora.md §6.1.

### Residential — done 2026-09-06
- [x] Module `res.py` with `SPECIES`, `DISTRICT`, `LEAF_OF`
- [x] Large tree: London plane (`res_plane`) — three stages
- [x] Medium tree: apple (`res_apple`) — three stages, red fruit accent
- [x] Small tree: ornamental maple (`res_maple`) — three stages, amber glint
- [x] Shrub: privet hedge (`res_hedge`)
- [x] Shrub: rose bush (`res_rose`) — pink blossoms
- [x] Grass: lawn tuft (`res_lawn`) — daisies on the full stage
- [x] Grass: clover (`res_clover`) — white flower, organic matter yield
- [x] Seed items + icons for the three trees
- [x] Contact sheet reviewed at 1× and 3× (clusters, top-left light, tinted sel-out outline, tuft, lineage)
- [x] Legacy plants removed (objects, PNGs, `roof_gear.py`, roof garden templates)
- [x] Gates: `roof_smoke`, `flora_editor_smoke`, `district_smoke`, `save_smoke`
- [ ] Feel check in play: a residential roof at dawn, growth over two mornings, planter farming

### Business — done 2026-09-06
- [x] Module `bus.py` (steel-blue shift, cooler greens, grey-blue steel `tub()` containers)
- [x] Large: columnar cypress (`bus_cypress`) — 6×24 flame of five stacked masses, one lit column
- [x] Medium: honey locust (`bus_locust`) — airy crown at lower cluster density, trunk visible through, pale yellow glint
- [x] Small: ficus in a tub (`bus_ficus`) — straight stem, glossy smooth-outlined crown, steel tub in every stage
- [x] Shrub: boxwood sphere (`bus_box_sphere`) — smooth outline, no teeth
- [x] Shrub: boxwood cube in a trough (`bus_box_cube`) — rectangular `_block_canopy`
- [x] Grass: turf strip (`bus_turf`) — mown flat
- [x] Grass: fountain grass (`bus_fountain_grass`) — arcing blades, pale seed plumes
- [x] Seeds + icons (cypress cone, locust pod, fig seed)
- [x] Contact sheet reviewed (fixed: beaded cypress masses → taller overlap; locust crown too dark + trunk spiking through → lighter density, trunk ends inside)
- [x] Gates pass; `roof_smoke` now checks every roof plant belongs to its tower's district set and that business roofs grow the business set (template plants resolve through the district pool)
- [ ] Feel check in play: a business roof, tubs and troughs at zoom 3

### Commercial — done 2026-09-06
- [x] Module `com.py` (warm yellow-green shift; magenta / pink / red accents; concrete `trough()`)
- [x] Large: fan palm (`com_palm`) — ringed `palm_trunk`, seven tapering `frond`s with pinnae teeth, fruit cluster; 8×20 (a 24-cell trunk read as a stick)
- [x] Medium: magnolia (`com_magnolia`) — darker glossy ramp, 3×3 pink blossoms with a white petal
- [x] Small: bougainvillea on a frame (`com_bougainvillea`) — low trellis, cascading side masses, `magenta_tips` over the rim (the one accent-heavy species)
- [x] Shrub: hibiscus (`com_hibiscus`) — big B5 leaves, red flowers with yellow centres
- [x] Shrub: planter bed (`com_bed`) — concrete trough, irregular row of bedding plants, three head colours
- [x] Grass: monstera (`com_monstera`) — broad split leaves on stems
- [x] Grass: fern (`com_fern`) — arching spines with alternating pinnae
- [x] Seeds + icons (palm nut, magnolia seed, bougainvillea cutting)
- [x] Contact sheet reviewed (fixed: spindly palm → shorter trunk, longer bolder fronds; bougainvillea frame read as stilts → bar lowered, cascades hang over it, thicker trunk)
- [x] Gates pass
- [ ] Feel check in play: a commercial roof — do the magenta and pink accents survive the depth grade

### Civil — done 2026-09-06
- [x] Module `civ.py` (base ramp; purple / poppy / white accents; darker rhodo and yew ramps; white flecked birch bark)
- [x] Large: park oak (`civ_oak`) — six overlapping sub-crowns on a thick forked trunk, 10×24
- [ ] Landmark `civ_oak_great` 14×30 — DEFERRED: growth is deterministic per dawn, so a fourth stage would make every oak a landmark; needs a rarity roll at seeding (one per roof) first
- [x] Medium: linden (`civ_linden`) — heart-shaped crown with a pointed top, pale glint
- [x] Small: weeping birch (`civ_birch`) — `birch_trunk` flecks, 2-px `strands` drawn after the outline pass
- [x] Shrub: rhododendron (`civ_rhodo`) — wide 6×4 dome, big leaves, purple `trusses`
- [x] Shrub: memorial yew (`civ_yew`) — smooth clipped cone, dark ramp, restrained glint
- [x] Grass: meadow tuft (`civ_meadow`) — tall mixed blades, 2×2 poppies
- [x] Grass: ivy (`civ_ivy`) — trailing stems with heart leaves
- [x] Seeds + icons (acorn, linden seed, birch catkin)
- [x] Contact sheet reviewed (fixed: oak crown too small and lumpy for its trunk → shorter trunk, larger overlapping masses, limbs end inside the crown)
- [x] Gates pass
- [ ] Feel check in play: a civil roof — the oak next to the player, birch strands in the sway

### Industrial — done 2026-09-06
- [x] Module `ind.py` (dusty olive: hue −14°, sat 0.62; rust / dark berry / dusty purple accents)
- [x] Large: tree of heaven (`ind_ailanthus`) — gangly, sparse layered clusters drawn BEFORE the trunk so the wood shows through, rust seed clusters
- [x] Medium: pioneer birch (`ind_birch`) — reuses civ `birch_trunk`, heavy lean (kink −7), small crown for its height
- [x] Small: sumac thicket (`ind_sumac`) — five stems from one root, a crown and a red-brown cone on each
- [x] Shrub: bramble (`ind_bramble`) — arching 1-px canes (`arc_stem` returns its points), sparse leaves and berry pairs ON the canes
- [x] Shrub: buddleia (`ind_buddleia`) — ragged spray, dusty purple spikes at the stem tips
- [x] Grass: thistle (`ind_thistle`) — spiny stems, purple crowns
- [x] Grass: concrete weeds (`ind_weeds`) — blades from a 1-px crack, a fluff head
- [x] Seeds + icons (ailanthus key, birch catkin, sumac drupe)
- [x] Contact sheet reviewed (fixed: bramble leaves floated off the canes → sampled from cane points; sumac crowns too small for the stems → larger masses)
- [x] Gates pass
- [ ] Feel check in play: an industrial roof — does the olive set read as neglected next to the rust vents

### Construction — done 2026-09-06
- [x] Module `con.py` (yellow-green: hue −20°; module `WEIGHTS` 5:2:1 trees / 4:2:1 shrubs / 3:2:2 grass — seedlings dominate)
- [x] Large: willow (`con_willow`) — leaning trunk, rounded crown, curtains of civ `strands` all round, 10×22
- [x] Medium: poplar (`con_poplar`) — narrow broadleaf column; the sway glint flicker is its accent
- [x] Small: elder (`con_elder`) — multi-stem shrubby tree, cream 3×1 flower plates, black berry clusters
- [x] Shrub: ragwort clump (`con_ragwort`) — upright stems with staggered lobed leaves, yellow heads
- [x] Shrub: rebar ivy (`con_rebar_ivy`) — bent rust rods with hi-vis tape at the tips, a vine winding up between heart leaves
- [x] Grass: horsetail (`con_horsetail`) — jointed 2-px stems with whorls
- [x] Grass: moss on rubble (`con_moss`) — bevelled concrete lump under a moss pad; static (pin = H, 1 frame)
- [x] Seeds + icons (willow catkin, poplar fluff, elderberry)
- [x] Contact sheet reviewed (fixed: ragwort leaves formed an even ladder → staggered per stem)
- [x] Gates pass
- [ ] Feel check in play: a construction roof — mostly seedlings by design; is there enough wood to matter

### Wild (shared roof set, any district at low weight)
- [ ] Module `wild.py`
- [ ] Large: ash (`wild_ash`) — the legacy `tree_seed` should grow this once it exists (`Constants.DEFAULT_SEEDLING`)
- [ ] Medium: tiered pine (`wild_pine`) — the user's preferred look, flora.md §1.4
- [ ] Small: hawthorn (`wild_hawthorn`)
- [ ] Shrub: wild bush (`wild_bush`)
- [ ] Grass: wild grass (`wild_grass`)
- [ ] `_district_flora` mixes wild in at ~20 % (the residential fallback now only covers a district id with no set)

### Submerged
- [ ] Module `sub.py` (static or 2-frame drift, darkest tones only)
- [ ] Kelp strand (`kelp`, 2×6)
- [ ] Algae mat (`algae_mat`)
- [ ] Silt weed (`silt_weed`)
- [ ] Seeding hook for flooded interiors / drowned roofs

## Cross-cutting
- [x] `tools/flora_art/common.py` — ramps, brushes, layered canopy, trunk/branch, tuft, sel-out outline, sway frames, seed icons
- [x] `tools/build_flora.py` — strips + tagged objects.json/items.json merge, stale-entry cleanup
- [x] `tools/flora_art/preview.py` — contact sheet at 1× and 3×
- [x] Engine: strip playback (`WorldObject`), rest-frame textures (`Data.object_texture`), district pools (`CityGen._district_flora`), species seeds (`plants`)
- [ ] `flora_smoke.tscn` gate (flora.md §7.3: lineage, matching ramps, even widths, pinned base rows, frame counts, district-only seeding)
- [ ] Flora Editor: district dropdown + sway preview
- [ ] Planter box vs wide midlings: decide (narrow midlings, wider box sections, or keep "outer sections only")
- [ ] `docs/RoomInventory.md` flora table; GameOverview Stage 1 line

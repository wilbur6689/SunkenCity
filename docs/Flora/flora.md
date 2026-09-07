# SunkenCity — Flora Art Bible

How every plant in the game is drawn: trees, bushes, shrubs, grass, and the plants the player
grows. Written 2026-09-06 from a study of seven reference sheets the user supplied (rooftop bush
layering tutorial, two commercial "12 pixel trees" packs, two pixel pines, and two mixed
tree-and-bush sets) plus the standing pixel-art guidance on foliage clusters, hue-shifted ramps,
pillow shading and banding. This document is the contract for the flora rebuild that follows: a
sprite that does not obey it is wrong even if it looks nice on its own.

Progress tracker: [FloraChecklist.md](FloraChecklist.md) (one row per district, ticked as each set is overhauled).

Companion docs: [../technical/TileArt.md](../technical/TileArt.md) (blocks, palette discipline,
light direction), [../GameOverview.md](../GameOverview.md) (Stage 1 = wood, roof lock,
districts), `data/objects.json` (the `flora` category), `scripts/tools/flora_editor.gd`.

---

## 0. The short version

1. **One light, top-left.** Same as the block art. Every plant is lit from the upper left and
   shadowed on the lower right. Never shade from the outline inward (pillow shading).
2. **Foliage is clusters, not blobs and not noise.** A canopy is a pile of 3–7 px rounded
   clumps, each clump shaded as its own little sphere. Single stray pixels are forbidden.
3. **Five greens + one outline, hue shifted.** Shadows lean blue-green, highlights lean
   yellow-green. Bark is a separate 4-step brown ramp. One accent colour per species.
4. **Every plant is a three-stage lineage** — seedling, midling, full — and the three read as
   the same species at a glance: same silhouette family, same ramp, same accent, trunk in the
   same place, the canopy simply grows.
5. **Every plant animates**: a horizontal strip of square frames, the canopy sways, the base
   never moves. Same strip convention as the monster sheets.
6. **Each district grows its own flora**, themed to the district and coloured within its
   `DISTRICT_TINT` family. Six districts, one shared "wild" roof set, one submerged set.

---

## 1. What the reference images teach

### 1.1 The layered-brush bush (Screenshot 163301, "4 simple steps")

The tutorial builds a bush in four passes and this is the method we adopt for every canopy:

| Pass | What is painted | Where |
|---|---|---|
| 1 | The **whole silhouette** in the **darkest** green (a rounded, slightly lumpy mound, flat-ish bottom) | Everywhere |
| 2 | The next-lighter green as **leaf-cluster shapes** covering roughly the upper 75 % | Leaves the bottom rim and lower right dark |
| 3 | Mid-light green clusters over roughly the upper 50 %, drifting up and left | Never touches the outline on the right or bottom |
| 4 | The **highlight** green as small clusters on the upper-left 20–25 % | Top-left only; a few sparks elsewhere are fine |

Key observations:

- The **layers are offset diagonally**: each lighter layer is a smaller copy of the mass,
  pushed up and to the left. That offset IS the lighting. Nothing else is needed.
- The darkest colour is not an outline drawn around the shape; it is the **base layer showing
  through** at the bottom, the right edge, and in the gaps between clusters. So the "outline"
  is thickest at the bottom-right (2–4 px) and vanishes at the top-left (0–1 px). This is what
  makes the tutorial bush look round rather than stickered.
- The **brushes are leaf-shaped clusters** (little three-lobed and spiky marks), and the same
  three or four marks are reused in every layer. Reusing marks keeps the texture consistent;
  that consistency is what reads as "leaves" instead of camouflage.
- Cluster edges are **ragged on the light side** (individual leaf points poke out) and **smooth
  on the dark side**. The silhouette of the full bush has a leafy top and a calm belly.
- The user's instruction "mix the different layers" means exactly this: do not paint a flat
  shape and then add a highlight blob. Build the plant from overlapping strata.

### 1.2 The twelve-tree pack, cream background (Screenshot 163502)

Twelve species share one style, which shows how much variety a single ruleset gives:

- **Silhouette carries the species.** Round crown (02), ragged spreading oak (01), tall
  columnar cypress (12), layered pagoda tiers (03, 07, 08), teardrop (06), weeping (10),
  umbrella pine (11), a multi-stem thicket (09). None of them needs a different palette or
  technique to be recognisable; the outline alone does it. This is the lesson for district
  flora: **vary shape first, palette second, detail last.**
- **Canopies are built from 3–6 sub-crowns.** Even the round tree (02) is three or four
  overlapping globes, each with its own highlight. The tiered trees (03, 07, 08) are stacked
  lens shapes with a shadowed underside on each tier and the trunk showing between tiers.
- **Every tree has three trunk elements:** a slightly flared base, one or two visible **branch
  forks** that disappear into the canopy, and a lighter vertical highlight stripe on the
  light-facing side of the trunk. Bark uses 3–4 browns with a warm highlight.
- **Every tree stands on a grass tuft footprint** a little wider than the trunk. This anchors
  the tree to the ground; without it trees float. We use the same anchor (see §4.5).
- **Leaf texture is dense at the edges, calmer in the middle.** The pack draws individual leaf
  "teeth" along the silhouette and lets the interior be broad cluster shading. The eye reads
  detail at the edge and infers the rest — do not fill the interior with noise.
- **The palette is four greens plus a dark green outline**; the darkest green also serves as
  the shadow gap between sub-crowns. Highlights are a distinctly yellower green, not a paler
  copy of the mid tone.
- Proportions: crown height ≈ 60–70 % of tree height for broadleaf; trunk width ≈ 1/10 of
  crown width; trunk visible length ≈ 25–35 % of height. Columnar and pine forms invert this
  (crown 85 %+).

### 1.3 The Shutterstock set (Screenshot 163556) — trees, plants, grass, bushes

A flatter, more "game-sprite" style. Useful mostly for the small stuff:

- **Grass tufts** are 3–7 blades of 2–3 greens, blades 1 px wide, bending in one direction,
  tallest blade off-centre. Flowers are a 1–2 px coloured head on a 1 px stem, never more than
  two per tuft. Our roof grass should look like these, not like a green square.
- **Bushes** come in three shapes: **dome** (widest at the bottom third), **mound** (wide and
  low, flat top), and **sphere** (topiary, tight outline). The dark base layer shows along the
  whole bottom edge as a shadow band 1–2 px thick.
- The **dead/willow tree** (third in row one) shows how a bare or drooping form is drawn: the
  branches are the drawing, 1–2 px lines with a lighter top edge, and the hanging foliage is
  vertical strands of 1 px width in two greens. Use for construction-district pioneers and for
  the drowned/silted flora.
- The **palm** (last in row one) is a ringed trunk (alternating light/dark 1 px bands) and 5–7
  fronds that are 1 px lines fattening to 2–3 px at the base with a jagged leaf edge.
- **Twin conifers** (columns 6–7) are the simplest trees in the set: a vertical stack of
  triangles, each tier's left side lit, right side dark, tips staggered.
- This set uses a **pure black outline**. We do NOT: see §3.3. Black outlines fight the
  depth colour grade and read as stickers on our backdrops.

### 1.4 The two pines (Screenshots 163650, 163707) — the user's preferred look

These two are the target feel for the whole flora set; the user asked for "this but with a
little more detail".

- **Tiers.** Both are stacked triangular tiers whose lower edge is a stepped zig-zag of 1–2 px
  steps. Tiers overlap and each lower tier is wider than the one above by 2–3 px per side.
- **Lighting is by tier.** The upper half of each tier catches the lighter green; the lower
  edge of the tier above drops a shadow band 1–2 px deep onto the tier below. In 163707 the
  highlights are bright irregular patches near the upper-left of each tier, and the lower-right
  edge of every tier is the darkest green — textbook top-left light.
- **Outline is hue-tinted dark green, 1 px**, and in 163707 it is thicker (2 px) along the
  bottom-right of each tier, thinner at the top-left — the same principle as the bush tutorial.
- **Trunk is a plain 2–3 tone brown stub, 20–25 % of the total height, never wider than a
  quarter of the bottom tier.** Both pines flare slightly at ground level.
- **Colour count is tiny:** 163650 uses 3 greens + 2 browns; 163707 uses 4 greens (including a
  vivid highlight) + outline + 2 browns. The look is clean because the ramp is short and every
  step is far apart.
- "A little more detail" means, for us: **5 greens instead of 3, 2–4 needle clusters per tier
  breaking the straight tier edges, a visible trunk core between tiers on the largest sizes,
  a highlight stripe on the trunk, and a ground tuft.** It does NOT mean per-pixel texture.

### 1.5 The mixed sets (Screenshots 163729, 163835)

Two more complete kits, both using **soft hue-tinted outlines** rather than black — this is the
outline style we adopt.

- 163729 (twenty items): shows one palette shared across a round oak, a rounded-conical tree,
  a spreading acacia, a cypress, a small conifer and six kinds of low bush/hedge. Hedges are
  long low mounds with the cluster texture only on the top edge and a plain dark belly. The
  bushes' lumps are **2–3 px wide and staggered**, so the top edge is bumpy but not spiky.
- 163835 (twelve items): the most "SunkenCity-like" set — desaturated cool greens, clusters
  drawn as **rounded 3×3 to 5×4 px blobs** each with a 1 px lighter upper-left spot, and the
  darkest green as the gap between blobs. Its four bushes prove that one cluster brush at three
  sizes gives sphere, mound and hedge. The narrow columnar tree (top-left) shows a single
  light-facing highlight column running the whole height — the way to light tall thin forms.
- Both sets repeat one truth: **highlights sit ON clusters, never along the outline.**

---

## 2. Scale in this game

| Fact | Value |
|---|---|
| World cell | 8 × 8 px (`Constants.BLOCK_SIZE`) = 1 foot |
| Object sprite | 1 texel = 1 world px; `size` in cells × 8 = sprite px (`sprite px = size × 8`) |
| Default zoom | 3.0 → one sprite pixel is 3 × 3 monitor pixels at 1080p |
| Player | ~30 px tall ≈ 3.75 cells |
| Floor pitch | 12 cells = 96 px (14, 20 in some districts) |
| Flora Editor canvas cap | 16 × 32 cells = 128 × 256 px (`MAX_W`/`MAX_H`) |
| Macro grid | Flora is dropped on the 2-cell macro grid (`CityGen.M`); grass must be exactly 2 cells wide |

Consequences for the art:

- A **2–4 px cluster is the smallest shape that reads** at zoom 3.0 (it is 6–12 monitor px).
  Single pixels are visible but read as noise; use them only for leaf tips on a silhouette.
- Players stand next to these plants, so a **full tree needs a trunk the player can walk in
  front of**: trunk at least 2 cells (16 px) tall of clear bark before the canopy starts.
- The current `tree_mature` (10 × 30 cells, 240 px) is 2.5 floors tall and a single lollipop.
  Full trees should top out around 24 cells (192 px) for the large class, and only the largest
  species go taller. Roofs are open sky, so height costs nothing mechanically, but a 240 px
  single blob of one green is the reason the plants look wrong today.

---

## 3. The universal style rules

### 3.1 Light

Top-left, roughly 45°, matching `TileArt.md` ("light top-left, dark bottom-right"). Applies to
every cluster, every tier, every trunk, every pot. The test from the pillow-shading guides:
if you cannot point at where the light comes from, the sprite is wrong.

Shadow placement:

- Each lighter foliage layer is the previous layer **shifted 1–2 px up-left and shrunk**.
- The underside of every tier/sub-crown drops a 1–2 px dark band onto what is below it.
- The trunk has a 1 px highlight stripe on its left third and the darkest brown on its right edge.
- The ground tuft is darkest directly under the trunk.

### 3.2 Foliage as clusters

A canopy is built from **one cluster brush per species**, used at 2–3 sizes:

| Brush | Footprint | Used for |
|---|---|---|
| Small | 2×2 / 3×2 | grass tips, seedlings, silhouette teeth |
| Medium | 3×3 / 4×3 rounded | bushes, midlings, canopy interiors |
| Large | 5×4 / 6×5 rounded | full canopies, sub-crowns |

Rules:

- Clusters **overlap**; the darkest green fills the gaps. There is never a hard straight seam
  between two greens inside a canopy.
- Each cluster gets **one lighter pixel group at its upper-left** and, if it is 4 px or more,
  a darker pixel group at its lower-right. That is the whole shading of a cluster.
- The **silhouette edge is ragged on the top and light side** (leaf points 1–2 px), **smooth
  along the bottom and dark side**.
- Interior detail is sparse. Edge detail is dense. ("Not every leaf needs to be represented.")
- **No dithering** in foliage. Depth comes from cluster layering; dither reads as disease at
  this scale.
- **No isolated single pixels** of a lighter colour inside a darker field.
- **No banding**: a lighter colour must not run as a parallel stripe along the outline.
  Break every long edge with clusters.

### 3.3 Outline

- A **1 px hue-tinted outline** in the ramp's darkest step. Not black. Not a separate grey.
- The outline is **selectively omitted at the top-left** where the highlight layer meets air
  (sel-out), and **thickens to 2 px along the bottom-right**. Both pines and both mixed sets
  do this; the Shutterstock black outline is the counter-example.
- The trunk's outline is the darkest bark brown, not the leaf outline colour.

### 3.4 Palette

Foliage is a **6-step ramp**: outline + 5 greens, hue shifted across the ramp (shadow toward
blue-green / teal, highlight toward yellow-green). Luminance spacing ≈ 25–30 per step, like the
block ramps. Bark is a **4-step ramp** (outline + 3 browns), warm highlight. Every species adds
**one accent colour** (blossom, fruit, dead leaf, neon-lit rim, rust dust, hi-vis tape) used in
1–3 % of the sprite's pixels — the accent is what says "commercial district" from across the roof.

Base ramps (start here, then shift per district — §6):

```
Leaf   outline  #12221A   (18,34,26)   deep teal-black
       shadow   #244F3A   (36,79,58)   blue-green
       dark     #337048   (51,112,72)
       mid      #4A9052   (74,144,82)
       light    #74B85A   (116,184,90) yellow-leaning
       glint    #A8DC78   (168,220,120) yellow-green highlight

Bark   outline  #2A1A0E   (42,26,14)
       dark     #5E3E26   (94,62,38)
       mid      #8A5E3A   (138,94,58)
       light    #B8885A   (184,136,90)

Ground tuft: leaf shadow + leaf dark only.
Soil (planters, pots): bark outline + bark dark + a grey-brown mid (110,92,76).
```

The Flora Editor's built-in `PALETTE` ramps (`Leaf`, `Wood`, `Stone`) are close to these and
may be edited to match; the existing `ACCENT_HUES` row covers accents.

Palette discipline from `TileArt.md` still applies: the **depth colour grade** tints the world,
so foliage must not be neon. Saturation stays under ~60 % for greens; accents may go to 80 %.
Night falls to `NIGHT_AMBIENT_VIS`, so a plant must still read as a silhouette — this is why the
canopy has a calm dark belly and a clear trunk gap.

### 3.5 Trunks and branches

- Trunk width by class: seedling 1 px, small full 2 px, medium full 3–4 px, large full 5–8 px.
- **Flared base** (+1 px each side on the bottom 2 rows) and **at least one fork** visible
  before the canopy swallows the branches on medium and large trees.
- Branches are 1–2 px lines with the lighter brown on their upper edge.
- Trunks are straight only on conifers and columnar forms; broadleaf trunks kink once.
- Palm/ringed trunks alternate 1 px light and dark bands every 2 rows.

### 3.6 Ground contact

Every free-standing plant carries a **ground tuft** on its bottom row: 2–4 short blades or a
1 px-tall dark shadow band, 1–3 px wider than the trunk on each side, in leaf shadow/dark.
Planter-grown plants omit the tuft (the soil is the anchor). This one detail removes the
"floating sticker" look more than anything else.

---

## 4. The three-stage lineage

Every flora species ships as **three objects chained by `grows_into`**: `<id>_seedling` →
`<id>_midling` → `<id>` (the full plant). This includes the player-planted chain from
`tree_seed` in a `planter`/`planter_box` (the seed sprouts the species' seedling one cell above
the pot; growth via `World._grow_trees` each dawn; full size only under open sky).

### 4.1 Recognisable as one species

The user's requirement: the three stages "look similar to each other so it's easy to see the
progress". Concretely:

| Property | Seedling | Midling | Full |
|---|---|---|---|
| Ramp | identical | identical | identical |
| Accent | present (1–2 px) | present | present |
| Silhouette family | the full form in miniature: a conifer seedling is already a little triangle, a round tree a little globe on a stick, a palm two fronds | the full form at ~50 % with fewer sub-crowns / tiers | the form |
| Trunk | 1 px, same brown, same kink direction | 2 px, fork appears | full |
| Cluster brush | small | medium | medium + large |
| Number of sub-crowns / tiers | 1 | 2 | 3–6 |
| Height | 2–4 cells | 40–60 % of full | full |
| Width | 2 cells | ~half of full, even | full |
| Trunk x within the sprite | centred (or same offset) | same | same |

Do NOT change species between stages (today's `tree_young` is a pine and grows into a broadleaf
`tree_mature`; that is exactly what the rebuild removes).

### 4.2 Size classes

Sizes are in cells (w × h). Widths are even so the sprite sits on the 2-cell macro grid.

| Class | Seedling | Midling | Full | Examples |
|---|---|---|---|---|
| **Grass / groundcover** | 2×1 (sprout) | 2×2 | 2×2 (denser, flowers) | grass tuft, clover, moss, sedge |
| **Shrub** | 2×2 | 2×4 or 4×3 | 4×4 (dome) / 6×3 (hedge) | boxwood, hedge, bramble, rose bed |
| **Small tree** | 2×3 | 4×6 | 6×10 | ornamental maple, dwarf pine, fig in a tub |
| **Medium tree** | 2×4 | 6×9 | 8×16 | birch, ash, palm, cypress |
| **Large tree** | 2×4 | 6×12 | 10×24 | oak, plane, sequoia-type pine, willow |
| **Landmark** (rare, 1 per roof max) | 2×4 | 8×14 | 14×30 | the civil park oak, the industrial dead giant |

Growth in the sim is a footprint check (`_tree_space_free`) so a midling that cannot fit its
full size waits; keep the full width ≤ 10 for anything that should reliably reach full on a
roof wing between HVAC pieces.

### 4.3 Yields scale with stage

Wood yield ≈ proportional to the trunk pixels: seedling 1–2 wood + 0–1 seed, midling 3–8,
full 25–40 (large) / 12–20 (medium) / 6–10 (small). Shrubs give wood at every stage (a bush is
Stage 1 wood the player does not need an axe for). Seeds: full 1–3, midling 0–1, seedling 0–1.
Grass keeps yielding stone (pebbles in the roots) and gains `organic_material` where the
species is edible or fibrous.

### 4.4 Naming and data

```
id            : <district>_<species>[_seedling|_midling]   e.g. civ_oak_midling
category      : "flora"
room_type     : "tree" | "bush" | "grass" | "shrub"     (FLORA_TYPES in the editor)
zones         : ["roof"]  (+ district tag, see §6.3)
grows_into    : next id (absent on the full stage)
grow_chance   : 1.0 now — growth is deterministic per dawn since 2026-09-02, kept for data compat
flora_weight  : spawn bias; seedlings 3, midlings 1, full 1 (a stand of young plants reads as a living roof)
requires_tool : "axe" on midling + full of the tree classes only
no_item       : true on midling/full trees (seedlings keep an item form so cut groves replant)
frames        : sway frame count (§5); optional when the strip is square-celled
authored      : true when saved from the Flora Editor; generated species omit it so the tool can rebuild them
```

### 4.5 Planter-grown plants

The planter chain uses the **same three sprites** as the wild plant. The seedling stage is drawn
with its bottom row clear of tuft so it reads as rising from the soil; the pot supplies the
ground. A full tree over a planter is identical to a wild one (the trunk starts one cell above
the pot). Whatever species the seed came from grows — `tree_seed` becomes per-species seeds
(`<district>_<species>_seed`) or carries a `species` field; either way, the planted plant keeps
its district identity, which is how the player farms a civil oak on a residential roof.

---

## 5. Animation (sway)

Requested 2026-09-06: "slight animations for the trees similar to how the enemies animate".

### 5.1 Strip contract (same as the monster sheets)

- A sprite is a **horizontal strip of equal frames**; the frame count is derived from
  `texture width / frame width` where frame width = `size[0] × 8`. (Enemies derive it from
  square cells; flora cells are rarely square, so the frame width is the object's declared
  width. A `frames` key overrides when present.)
- **4 frames** for trees and shrubs, **2 frames** for grass, **1 frame** (static) for pots,
  soil, dead wood and fully drowned plants.
- Playback is a **ping-pong at ~2–3 fps** (frame order 0-1-2-3-2-1, each frame ~0.4 s), driven
  the way `Enemy._tick_anim` drives `_anim_t` — a `WorldObject` gains `sprite.hframes` and a
  phase offset from its cell hash so a roof of trees does not sway in lock-step. Speed may
  double while a red moon is up (the wind picks up) and stop under water.
- Frame 0 is the rest pose and is what the Flora Editor and the hover card show.

### 5.2 What moves

- **The base is pinned.** Trunk bottom, pot, ground tuft and the lowest 25 % of the trunk are
  pixel-identical in every frame. Only the canopy and the upper trunk move.
- **Amplitude is 1 px per 16 px of height above the pinned zone**, capped at 3 px at the crown
  tip. A 24-cell oak's crown drifts ±3 px; a 4×4 bush ±1 px; grass blades tilt 1 px.
- Motion is a **lean plus a ripple**: frame 1 shifts the top rows left by 1 px, frame 2 by 2 px
  with the highlight clusters swapped one cluster over (leaves turning in the wind), frame 3 back
  to 1 px. Rows shear progressively (shear = row height / total height × amplitude), never a
  rigid slide of the whole canopy.
- Sub-crowns/tiers lag: the lowest tier moves on frame 1, the top tier on frame 2. Weeping and
  palm forms move their strands/fronds 1–2 px more than their trunk.
- **Highlights flicker, colours do not change.** Swap which cluster carries the glint colour
  between frames 0 and 2; never introduce a new colour for an animation frame.
- Seedlings sway more relative to size (a 3-cell sprout bends its whole stem 1 px).

### 5.3 Authoring

The strip is generated procedurally from the rest frame (a shear-by-row function with a
per-row highlight swap) so the artist draws frame 0 only; hand-tuned strips are allowed and
marked `authored`. The Flora Editor gains a play/stop preview reading `hframes`. Tree feet must
stay on the record's bottom row, so the strip's frames share one canvas height and the shear
is clamped inside the canvas (widen the canvas by the amplitude on each side when needed:
`size[0]` stays the collision/footprint width, the drawn frame may be up to 2 cells wider
via an `art_pad` field — simpler: leave 2–3 px of transparent margin in the rest frame).

---

## 6. District flora

The user's direction: each district gets flora that fits its theme. The roofs are what the
player sees for the whole early game and the district colour (`Constants.DISTRICT_TINT`) is
already painted on hatches and vents, so the plants are the second cue that says which
district you have jumped into. Every set has: **one large tree, one medium tree, one small
tree, two shrubs, two grasses**, all in three stages (so 7 species × 3 = 21 sprites per
district, 126 for the six districts) plus the shared and submerged sets.

Per-district palette shifts are small: shift the whole leaf ramp's hue by ≤ 15° toward the
district tint, and pick the accent from the tint. The bark ramp stays shared (wood is wood).

### 6.1 The sets

**Residential** — amber tint (1.0, 0.86, 0.62). Domestic, planted-by-someone, gone a bit wild.

| Slot | Species | Form | Accent |
|---|---|---|---|
| Large | **Plane tree** (`res_plane`) | broad ragged crown of 4 sub-crowns, pale mottled trunk (bark light tone in patches) | none |
| Medium | **Apple tree** (`res_apple`) | round crown, low fork, short thick trunk | red fruit dots (2–4 px) on midling+ |
| Small | **Ornamental maple** (`res_maple`) | umbrella crown, thin bent trunk | leaf ramp shifted warm; glint = orange-amber |
| Shrub | **Privet hedge** (`res_hedge`) | long low mound 6×3 | none |
| Shrub | **Rose bush** (`res_rose`) | dome with thorny 1 px stem gaps | 3–5 pink/red 2×2 blossoms |
| Grass | **Lawn tuft** (`res_lawn`) | even blades | daisy heads (white 1 px + yellow 1 px) |
| Grass | **Clover** (`res_clover`) | round 2 px leaf trios | none |

**Business** — steel blue (0.62, 0.82, 1.0). Corporate landscaping: clipped, symmetric,
containerised. Cooler greens (shift toward blue-green), grey-blue pots.

| Slot | Species | Form | Accent |
|---|---|---|---|
| Large | **Columnar cypress** (`bus_cypress`) | tall narrow flame, single highlight column | none |
| Medium | **Honey locust** (`bus_locust`) | airy feathered crown of small clusters with trunk visible through | pale yellow glint |
| Small | **Ficus in a tub** (`bus_ficus`) | glossy round crown on a straight 2 px trunk over a square steel-grey tub (tub is part of the sprite) | tub highlight steel blue |
| Shrub | **Boxwood sphere** (`bus_box_sphere`) | tight topiary ball, smooth outline | none |
| Shrub | **Boxwood cube** (`bus_box_cube`) | 4×3 squared hedge in a planter trough | trough steel |
| Grass | **Turf strip** (`bus_turf`) | short even blades, flat top | none |
| Grass | **Ornamental grass** (`bus_fountain_grass`) | tall arcing blades 2 px over | pale seed heads |

**Commercial** — neon pink (1.0, 0.66, 0.88). Showy, tropical, decorative; the plants that
were bought to be looked at. Warmer, slightly yellow greens; hot accents.

| Slot | Species | Form | Accent |
|---|---|---|---|
| Large | **Fan palm** (`com_palm`) | ringed trunk, 6–8 fronds, coconut/fruit cluster at the crown | fronds' glint yellow-green; fruit brown |
| Medium | **Magnolia** (`com_magnolia`) | broad loose crown, glossy dark leaves | large pink/white 3×3 blossoms |
| Small | **Bougainvillea on a frame** (`com_bougainvillea`) | small tree with cascading side masses | magenta cluster tips (the accent is 10 %+ of the sprite, the one exception) |
| Shrub | **Hibiscus** (`com_hibiscus`) | dome with big leaves | 2–3 red 3×3 flowers |
| Shrub | **Planter bed** (`com_bed`) | 6×2 low mixed bed | multi-colour 1 px heads |
| Grass | **Monstera** (`com_monstera`) | 2×2 broad split leaves | none |
| Grass | **Fern** (`com_fern`) | arching fronds | none |

**Civil** — civic green (0.70, 1.0, 0.74). Park and memorial planting: the grandest trees,
formal beds, the one landmark tree class. Clean mid greens, closest to the base ramp.

| Slot | Species | Form | Accent |
|---|---|---|---|
| Large / landmark | **Park oak** (`civ_oak`) | massive spreading crown of 5–6 sub-crowns, thick forked trunk, 14×30 landmark variant `civ_oak_great` | none |
| Medium | **Linden** (`civ_linden`) | tidy heart-shaped crown | pale yellow-green glint |
| Small | **Weeping birch** (`civ_birch`) | drooping strands, white trunk with dark 1 px flecks | none |
| Shrub | **Rhododendron** (`civ_rhodo`) | wide dome, big dark leaves | purple 2×2 flower trusses |
| Shrub | **Memorial yew** (`civ_yew`) | clipped dark cone | none |
| Grass | **Meadow tuft** (`civ_meadow`) | tall mixed blades | poppy red 1 px |
| Grass | **Ivy** (`civ_ivy`) | 2×2 trailing groundcover, also a `_vined` overlay for park furniture | none |

**Industrial** — rust orange (1.0, 0.60, 0.42). Nothing was planted here; this is what grows
where nobody stops it. Desaturated, dusty greens (shift toward olive), brown-grey accents.

| Slot | Species | Form | Accent |
|---|---|---|---|
| Large | **Tree of heaven** (`ind_ailanthus`) | tall gangly, sparse layered leaf clusters, trunk visible most of the way | rust-brown seed clusters |
| Medium | **Silver birch pioneer** (`ind_birch`) | thin, leaning, small crown | none |
| Small | **Sumac** (`ind_sumac`) | multi-stem thicket (form 09 in §1.2) | red-brown cone tips |
| Shrub | **Bramble** (`ind_bramble`) | tangled arching stems, sparse leaves | dark berry 1 px |
| Shrub | **Buddleia** (`ind_buddleia`) | ragged spray | dusty purple spike |
| Grass | **Thistle** (`ind_thistle`) | spiky, tall | purple head |
| Grass | **Cracked-concrete weeds** (`ind_weeds`) | 2–3 sparse blades from a 1 px dark crack | none |

**Construction** — hi-vis yellow (1.0, 0.95, 0.40). Pioneers in rubble: the youngest flora in
the city, so this district is where seedlings and midlings dominate (`flora_weight` favours the
early stages 5:2:1). Yellow-green shifted ramp.

| Slot | Species | Form | Accent |
|---|---|---|---|
| Large | **Willow** (`con_willow`) | weeping mass (form 10), grows where the site flooded | none |
| Medium | **Poplar** (`con_poplar`) | narrow column, leaves flicker light/dark between frames (its animation is the accent) | none |
| Small | **Elder** (`con_elder`) | shrubby small tree | cream flower plates / black berries |
| Shrub | **Ragwort clump** (`con_ragwort`) | ragged upright | yellow 1 px heads |
| Shrub | **Rebar ivy** (`con_rebar_ivy`) | vines climbing a bent 1 px rebar rod (rod rust-brown) | hi-vis tape 2 px |
| Grass | **Horsetail** (`con_horsetail`) | vertical jointed stems | none |
| Grass | **Moss on rubble** (`con_moss`) | 2×2 low pad over a grey stone lump | none |

**Shared wild set** (any roof, lower weight; also the district-less fallback and the test
tower): the current `tree_*`, `roof_bush`, `roof_grass*` chain **redrawn** to this spec as
`wild_ash` (large), `wild_pine` (medium, the user's tiered pine — §1.4), `wild_hawthorn`
(small), `wild_bush`, `wild_grass`. `tree_seed` keeps working and grows `wild_ash` unless a
species is set.

**Submerged set** (interiors and roofs below the waterline, static or 2-frame drift): `kelp`
(2×6 strand, 2-frame sway that moves the whole strand ±1 px, drawn in the leaf shadow/dark
tones only), `algae_mat` (2×1 groundcover), `silt_weed` (drowned grass: the wild grass sprite
in the two darkest greens, no highlight). Drowned trees do not get a special sprite — a tree
record under water simply stops animating and the depth grade does the rest.

### 6.2 What the districts share

- The same six-step ramp construction, the same cluster brush sizes, the same light, the same
  outline rule, the same trunk/ground-tuft rules, the same animation contract. The district
  shows in **silhouette family, hue shift and accent**, nothing else. A player who has learnt
  to read one tree reads them all.
- Zone tagging today is `zones: ["roof"]` for every flora object and `_stamp_roofs` picks from
  one pool. The rebuild adds a **`district` field** on flora defs (like the fauna's) and
  `_stamp_roofs` draws from `district == tower.district` plus the shared wild set at a lower
  weight (proposal: 80 % district / 20 % wild, and 0 % district on the construction district's
  half-built towers that have no dry crown). The Flora Editor gains a district dropdown.
- **Night roof monsters** are already district-picked; flora completes the read: a rooftop of
  clipped cypress and boxwood spheres says "business" before the first steel-blue hatch is seen.

### 6.3 Audit of today's flora (what the rebuild replaces)

| Object | Problem |
|---|---|
| `tree_sapling` 2×4 | acceptable form (globe on a stick) but a different species from what it grows into |
| `tree_young` 2×6 | a pine; grows into a broadleaf; no lineage |
| `tree_mature` 10×30 | one 240 px flat-green lollipop with a stripe highlight; no clusters, no sub-crowns, no fork, no tuft; 2.5 floors tall |
| `roof_bush` 4×4 | closest to spec (has clusters) but a uniform grey-green, no top-left bias |
| `roof_grass*` 2×2 | square blobs, no blades |
| `large_tree`, `Kindy`, `pine_tree_young`, `new_flora` | editor experiments; unfinished, single stage, mixed styles |
| `planter`, `planter_box` | keep (soil ramp per §3.4 when repainted) |

All of these ids stay valid until the new sets land (saves reference them); the wild set takes
their place and a one-time alias map in `Data` swaps old ids for the new wild species on load.

---

## 6.4 Build status

- **2026-09-06: residential set built** by `python tools/build_flora.py res` from `tools/flora_art/res.py`
  (7 species × 3 stages = 21 sway strips, 3 seed items with icons). The legacy plants (`tree_*`,
  `roof_bush`, `roof_grass*`, editor experiments) are deleted; `tree_seed` survives as a legacy item
  that plants the plane. Other districts fall back to the residential set on their roofs until their
  module exists (`CityGen._district_flora`). Adjacent planter-box sections block a wide midling's
  growth (only the outer sections of a box can reach full size at once).

## 7. Production pipeline

1. **Tool, not hand-painting, for the bulk:** a `tools/flora_art/` package mirroring
   `tools/fauna_art/` — `common.py` (ramps, cluster brushes, shear animation, tuft, outline
   pass), one module per district (`res.py`, `bus.py`, …) exposing `SPECIES = {id: drawer}` with
   a `stage` parameter (0/1/2) so all three stages come from one drawer and share proportions by
   construction. `python tools/build_flora.py` writes `assets/sprites/objects/<id>.png` strips
   and merges the objects.json entries (tagged `generated_flora: true`, replaced on re-run;
   `authored: true` entries are never touched). `python tools/flora_art/preview.py <district>
   out.png` renders a contact sheet: the seven species × three stages in a row each, frame 0
   and frame 2, over the district's roof tile, at 1× and 3×.
2. **Hand pass in the Flora Editor** for the hero pieces (the civil great oak, the wild pine,
   the commercial palm): load the generated sprite, refine frame 0, save (`authored`), let the
   tool regenerate the sway strip from the authored rest frame (`--resway <id>`).
3. **Checks:** a `flora_smoke.tscn` gate asserts every flora species has all three stages
   chained, matching ramps (colour sets of the three stages differ only by the accent), even
   widths, base rows identical across frames, frame count 4/2/1 by class, no colour outside the
   species' ramp + accent, and that `_stamp_roofs` seeds each district's set only in that
   district. `roof_smoke` keeps its growth-timing checks on the wild ash.
4. **Docs:** `docs/RoomInventory.md` gains a flora table; `GameOverview.md` gets one line under
   Stage 1 pointing here; this file's §6 tables are the roster of record.

---

## 8. Checklist for any new flora sprite

- [ ] Light from top-left; the darkest green shows along the bottom and right
- [ ] Built as layered clusters (silhouette → 3 lighter layers, each offset up-left)
- [ ] 6-step hue-shifted leaf ramp, 4-step bark ramp, ≤ 1 accent
- [ ] 1 px tinted outline, thin/absent at the top-left, 2 px at the bottom-right
- [ ] No isolated pixels, no dither, no banding along the outline
- [ ] Ragged light-side edge, smooth dark-side edge
- [ ] Trunk: flare, fork, highlight stripe; ≥ 2 cells of clear trunk on trees
- [ ] Ground tuft (wild) or clear base row (planter-grown)
- [ ] Three stages, same species, same ramp, trunk in the same x, sizes per §4.2
- [ ] Sway strip: 4/2/1 frames, base rows pinned, amplitude ≤ 1 px per 16 px height, ping-pong
- [ ] Even width in cells; height fits 32 cells; roof footprint reachable for the full stage
- [ ] District: silhouette family + ≤ 15° hue shift + accent from the district tint

---

## Sources consulted

The seven user screenshots (2026-09-06 16:33–16:38) and:

- [SLYNYRD Pixelblog 15 — Plant Life](https://www.slynyrd.com/blog/2019/3/7/pixelblog-15-plant-life) — leaf bundles on a shared ramp, darker/lighter variants layered to an implied light
- [SLYNYRD Pixelblog 44 — Top Down Trees](https://www.slynyrd.com/blog/2023/5/22/pixelblog-44-top-down-trees) — cluster consistency of shape, size and spacing
- [Pixnote — How to Draw a Pixel Art Tree](https://pixnote.net/en/learn/draw-tree/) — treat leaves as round clumps, three greens per clump
- [Pixnote — Shading & Lighting](https://pixnote.net/en/learn/shading/) and [Glossary](https://pixnote.net/en/learn/glossary/) — pillow shading, banding, clustering
- [Lospec — Pillow-shading](https://lospec.com/pixel-art-tutorials/pixel-art-tips-10-pillow-shading-youtube-by-solar-lune) and [Hue-shifting tutorials](https://lospec.com/pixel-art-tutorials/tags/hueshifting)
- [Derek Yu — Pixel Art: Common Mistakes](https://www.derekyu.com/makegames/pixelart2.html) — banding, pillow shading, noise
- [Pedro Medeiros — Basic Shading](https://medium.com/pixel-grimoire/how-to-start-making-pixel-art-4-f57f51dcfa02) — hue shifting in shadows and highlights
- [Pixel Editor — Color Theory for Pixel Art](https://www.pixel-editor.com/articles/color-theory-for-pixel-art) — ramps and hue shift
- [Envato Tuts+ — Isometric Pixel Art Tree](https://design.tutsplus.com/tutorials/how-to-create-an-isometric-pixel-art-tree-in-adobe-photoshop--cms-23606) — sub-crown construction

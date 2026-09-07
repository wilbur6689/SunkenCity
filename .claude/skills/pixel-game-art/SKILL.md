---
name: pixel-game-art
description: Make good pixel game art — sprites, tiles, plants, creatures, props, icons — for SunkenCity or any 2D pixel game. Use whenever drawing, generating (PIL/Python drawers), reviewing, or fixing pixel art, or when writing an art-style doc or a sprite tool. Encodes the studied rules: scale discipline, big-shapes-first workflow, cluster texture, hue-shifted ramps, top-left light, tinted sel-out outlines, asymmetry, negative space, ground anchoring, growth lineages, sway strips, and controlled procedural variation.
argument-hint: [asset-or-tool-to-draw-or-review]
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, PowerShell
user-invocable: true
effort: high
---

# Pixel Game Art

You are producing or reviewing pixel art for a game. Pixel art is a **visual language, not a
low-resolution drawing**: every pixel is placed on purpose, every colour belongs to a ramp, and
every asset obeys the same scale, light and outline rules as its neighbours. This skill
distils the project's art study (Terraria block close-ups, seven flora reference sheets, the
"Pixel Art Rules for Game Assets" tips, Lospec / SLYNYRD / Pixnote / Derek Yu guidance) into
a procedure. Follow it whether you are hand-placing pixels, writing a PIL drawer, or judging
someone else's sprite.

Project references to read when relevant (they are canon; this skill summarises them):

- `docs/technical/TileArt.md` — blocks/tiles, palette discipline, atlas layout
- `docs/Flora/flora.md` — the flora art bible (ramps, lineage, sway, district roster)
- `docs/Flora/pixelTips.md` — the general tips this skill is built on
- `tools/fauna_art/common.py` — the creature strip drawer contract
- `tools/rooms_pack/*.py`, `tools/gen_weapon_icons.py` — prop and icon drawer conventions

---

## 1. Before drawing: the scale audit

**Pick a resolution and stick to it.** Ask, and answer in writing, before the first pixel:

| Question | SunkenCity answer |
|---|---|
| What is 1 sprite pixel on screen? | 1 world px; at default zoom 3.0 that is a 3×3 monitor block on 1080p |
| How tall is the character? | ~30 px (12×22 hitbox); 1 cell = 8 px = 1 ft |
| Smallest detail that reads? | a **2–4 px cluster**. A lone pixel reads only as a leaf tip, rivet, or eye |
| Asset size bands | grass 8–16 px · bush 16–32 · small tree 48–80 · medium 64–128 · large 80–192 · landmark ≤ 256 |
| Pixel density parity | every asset the player stands beside uses the SAME density: no 1-px-detail tree next to a 3-px-feature character |
| Sprite px contract | objects: `size` cells × 8 = sprite px; 16 px room-pack blocks = 2 cells; icons 16 px (`Data.ICON_PX`); tiles 24 texels per 8 px cell; enemy strips: square cells, feet near the bottom |

If the asset would need 300 tiny pixels of detail to look right, it is at the wrong scale.
Reduce the idea, not the pixel size.

## 2. The workflow: big shapes first, small details last

Never start with detail. Work in this order and **stop after each step to look**:

```
1. Silhouette          — fill it black. Is it recognisable? asymmetric? interesting holes?
2. Major colour masses — base tone per part (canopy / trunk / body / plate)
3. Shadow masses       — the dark side and undersides, as CLUSTERS not gradients
4. Structure           — trunk, branches, limbs, joints, plate seams: tapering shapes, not lines
5. Light masses        — the lit side, one step lighter, offset toward the light
6. Highlights          — a few small clusters on the light-most points; restrained
7. Environment         — ground tuft / shadow / soil / roots / debris that anchors it
8. DELETE              — remove stray pixels, extra colours, noise, anything not communicating
```

Step 8 is not optional. Pixel art gets better when pixels are removed.

Sketching at 2× or 4× and shrinking is allowed only as a sketch. **Never let a resize
algorithm decide final pixels** — after any scale, fix jagged edges, stray pixels, broken
silhouettes, and unwanted colours by hand. No automatic anti-aliasing, no semi-transparent
pixels, no blur: edges step in whole pixels.

## 3. Palette

- **One ramp per material**, 5–7 colours: 1 hue-tinted near-black outline, 3–4 body tones, 1
  highlight. Steps ≈ 25–30 luminance apart. Never one flat colour; never 40 near-identical greens.
- **Hue-shift the ramp**: shadows drift toward blue/teal (or the scene's cool depth colour),
  highlights toward yellow/warm. A shadow that is just "darker" looks dead.
- **One accent colour** per asset (blossom, rust, neon rim, hi-vis tape, eye glow), 1–3 % of
  pixels. The accent is the identity cue at a distance.
- **Saturation discipline**: structure and foliage stay under ~60 % saturation because the
  depth colour grade (`WS-29`) tints the world; accents may reach 80 %. Warm = safe, cold = deep
  applies to lights and props, not blocks.
- Reuse the project's ramps before inventing: `TileArt.md` block ramps, `flora.md` §3.4 leaf/bark/
  soil ramps, `fauna_art/common.py` palette dict, `gen_weapon_icons.py` metal/trim ramps, the
  universal tinted outline `(24, 18, 14)` for props/icons and `(10, 12, 16)` for creatures.
- Depth/night readability: every asset must still read as a **silhouette** at low light —
  keep a calm dark belly, a clear gap between canopy and ground, an unbroken outline.

## 4. Light and shading

- **One light: top-left, ~45°**, for every asset in the game. Lit faces up-left, shadow
  down-right, undersides in shadow. If you cannot point at the light source, it is pillow shaded.
- **Offset, don't gradient.** Each lighter layer is the previous layer shrunk and pushed 1–2 px
  toward the light. That offset IS the shading. For tiers/plates, the piece above drops a 1–2 px
  shadow band on the piece below.
- **Highlights sit on forms, never along the outline** (a light stripe hugging the edge is
  banding). Highlights are small clusters at the top-left of a cluster/plate/limb.
- **Every cluster is a tiny sphere**: lighter pixel group top-left, darker bottom-right if it is
  ≥ 4 px. That is all the shading a cluster needs.
- **No dithering** on organic subjects at this scale (reads as disease/static). Dither is
  acceptable only for large flat gradients (sky plates, water haze).

## 5. Outline

- **1 px, hue-tinted, the ramp's darkest step.** Not pure black (black outlines read as
  stickers/cartoons against the backdrops) — exception: the shared near-black creature outline,
  which is tinted too.
- **Selective outline (sel-out):** thin or absent where the highlight meets air at the top-left;
  thickens to 2 px along the bottom-right. Trunks/limbs outline in their own material's dark.
- Blocks: outline only on faces that meet air (autotile edge pass), not baked into every tile.

## 6. Texture and form

- **Clusters, not noise.** Texture is groups of 2–6 px representing something (a leaf mass, a
  pebble, a plate, a fur tuft). Random scattered pixels are forbidden. Reduce isolated pixels;
  group same-colour pixels.
- **Reuse a small brush set.** 2–4 cluster marks at 2–3 sizes per asset; consistency of shape,
  size and spacing is what reads as texture instead of camouflage.
- **Dense at the edges, calm inside.** Draw individual "teeth" (leaf tips, rivets, cracks)
  along the silhouette and let the interior be broad masses; the eye infers the rest.
- **Ragged on the light side, smooth on the dark side.**
- **Asymmetry.** Nothing natural is mirror-symmetric: one side heavier, uneven heights,
  different cluster sizes. A symmetric tree is an icon, not a tree. Manufactured objects may be
  symmetric in construction but get asymmetric wear/light.
- **Irregular spacing.** Never a grid of evenly spaced details; group them (`●● ····●●● ·● ····●●`).
- **Negative space.** Holes between masses (sky through a canopy, gaps between plates) do more
  than added pixels. Plan where pixels are NOT.
- **Structure as tapering shapes.** Branches/limbs/pipes start thick, split, thin, and vanish
  into the mass. A 1 px line is not a branch.
- **Wind / world direction.** Pick a dominant wind (SunkenCity: the sway leans LEFT on frame 1–2,
  grass bends the same way) and let all vegetation share it — subtle, consistent.

## 7. Anchoring to the world

Every free-standing object touches the ground visibly: a ground shadow band, a tuft of 2–4
blades, soil, roots, debris, or a pot — 1–3 px wider than the base on each side, darkest
directly under the object. Planter-grown or shelf-mounted things skip the tuft; the pot or
shelf is the anchor. Floating stickers are the single most common failure.

Feet/base alignment matters mechanically: objects sit on their record's bottom row, enemy
strips keep feet near `y = cell − 3` (the engine measures the lowest opaque row for the foot
offset), icons centre in their 16 px cell.

## 8. Subject recipes

**Plants** (full detail in `docs/Flora/flora.md`): silhouette → 3–7 overlapping masses (the
"3 blob rule") → 4 layered strata offset up-left → tapering trunk with flare, fork and a
highlight stripe → ground tuft. Leaf MASSES, not leaves, with a few leaf shapes on the rim.
Seedlings are NOT miniature trees: thin stem, 1–3 uneven leaves, slight lean, small shadow —
but they keep the species' silhouette family, ramp and accent so the lineage reads.
Growth stages (seedling / midling / full, optionally old/dead) share ramp, trunk x, accent and
brush; only mass count and size grow. Old/dead/mutated variants exaggerate ONE biological trait
(twisted trunk, dead limbs, oversize leaves, fungal shelves, hanging vines) — designed, not noisy.

**Blocks/tiles**: per-material recipes in `TileArt.md` — pebbles 2–4 px with 1 px dark gaps,
brick courses 3 px + 1 px mortar staggered half a brick, planks 3–4 px with a seam and a light
top edge, metal plates with rivet highlight/shadow pairs. Columns = pattern variants, not
brightness steps. Back walls = same family, darker and flatter.

**Creatures**: base art faces RIGHT (engine flips), flat fills, the builder adds the outline.
Silhouette carries the species (long/low, hunched, bloated); the accent is the tell (eye glow,
stripe). Walk/swim/flap cycles alternate paired limbs (`legs`), a ±1 px `wag` on tails/heads,
body bob of 1 px at most. Hurt/attack/dead clips reuse the palette; never add colours per clip.

**Props/furniture**: box + bevel (light top/left edge, dark bottom/right), a 1 px tinted
outline, legs/feet inset, wear as a few asymmetric clusters (chips, rust, stains) not speckle.
Zone identity comes from the accent/material choice, not from busier detail.

**Icons (16 px)**: one bold readable shape on a diagonal, 3-tone ramp + outline, metal
band-tinted, no interior noise; must read at 1× in a wood slot and at 3×.

## 9. Animation (sway, idle, cycles)

- Horizontal strip of equal frames; frame count from `width / frame width` (square cells for
  creatures, the object's declared width for flora) or a `frames` key.
- **Base pinned**: bottom rows pixel-identical in every frame. Only the free end moves.
- Amplitude ≤ 1 px per 16 px of height above the pinned zone, cap 3 px; shear progressively by
  row, never a rigid slide; lower masses lag upper ones by a frame.
- Ping-pong (0-1-2-3-2-1), 2–3 fps for vegetation sway, 3–10 fps for walk cycles scaled by
  speed. Per-instance phase offset from a position hash so a field never moves in lock-step.
- Highlights may swap between clusters across frames; colours never change; no new colours.
- Frame 0 is the rest pose shown by editors, hover cards and icons.

## 10. Variation without noise

Randomise **within controlled parameters**, never everything: size class × canopy density
(dense/normal/sparse) × lean (left/straight/right) × health (healthy/stressed/dead) × colour
variant. Build 5–10 silhouette variants per species from one base by reshaping the canopy,
swapping the trunk, thinning, or adding dead limbs. Make one **master asset** that obeys every
rule, then derive; when generating, one drawer with a `stage`/`variant` parameter keeps
proportions consistent by construction.

## 11. SunkenCity pipeline rules (do not break these)

- Generate the bulk with **PIL drawers** in a per-subject package (`tools/fauna_art/`,
  `tools/rooms_pack/`, planned `tools/flora_art/`), one module per stage/district exposing a
  dict of drawers; a build script writes PNGs to `assets/sprites/...` and merges JSON entries
  tagged (`grid_fauna`, `generated_flora`, `district_weapon` …) so re-runs replace only their own.
- **Never overwrite hand-edited art**: `authored` / `authored_sprites` / `authored_icon` flags and
  "a file already exists" both mean hands off (`ICONS_FORCE=1` is the explicit override).
- Provide a **preview/contact sheet** (`preview.py <module> out.png`) rendering every asset at
  1× and 3× over the surface it will stand on; look at it with the Read tool before declaring
  done. A palette count per sprite (`len(set(img.getdata()))`) should match ramp + accent + 0/1.
- Textures rewritten on disk load through `Data.load_texture_fresh` (raw under the editor
  binary, `load()` in exports) — `.import` files come from `--headless --import`.
- Keep raw-pixel constants (hitboxes, `FEET_Y`, item offsets) untouched; sizes in JSON are cells.
- Run the relevant gate after data/art changes (`m4_smoke` for enemies, `roof_smoke` for flora,
  editor smokes for editor changes) with a shell timeout, and read the final checks line.

## 12. Review checklist (run it on every asset, yours or not)

**Scale** — same pixel density as the character; smallest detail ≥ 2 px cluster; fits its size band.
**Silhouette** — recognisable in black; asymmetric; deliberate negative space; edges jagged on purpose.
**Palette** — ≤ 7 per material; ramp hue-shifted; ≤ 1 accent; project ramps reused; shadows actually darker.
**Light** — top-left everywhere; shadow masses down-right; highlights on forms, restrained; no pillow shading.
**Outline** — 1 px tinted, sel-out at top-left, 2 px bottom-right; no pure black stickers.
**Texture** — clusters not noise; a small reused brush set; dense edge, calm interior; no dither; no banding.
**Naturalism** — nothing mirror-symmetric; limbs/branches differ; irregular spacing; wind consistent.
**Anchor** — ground tuft/shadow/pot; base row correct; feet on the floor.
**Lineage/variants** — stages share ramp, accent, trunk x, silhouette family; variants differ in controlled parameters.
**Animation** — base pinned; amplitude within limit; ping-pong; no new colours; phase offset.
**Pipeline** — generated vs authored respected; preview inspected at 1× and 3×; JSON sizes in cells; gate run.

When reviewing, report findings against these headings, most damaging first, and propose the
minimal pixel change (often: delete pixels, merge colours, move a highlight up-left).

## 13. Anti-patterns to name on sight

lollipop tree (one flat blob on a stick) · pillow shading · black outline everywhere · pixel
static / speckle texture · 40-green palette · banding along the edge · evenly spaced dots ·
perfectly symmetric plant · floating sticker (no ground contact) · resized-photo softness /
semi-transparent edges · a seedling that is a shrunken adult · stages that change species ·
rigid whole-sprite animation slide · detail density that belongs to a different game.

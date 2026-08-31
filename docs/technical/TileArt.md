# SunkenCity — Tile & Sprite Art Spec

How blocks and characters should be drawn. Source: study of Terraria's block art
(`docs/Examples/terrariaBlocks.png` and close-ups of stone, brick, and wood — 2026-08-31) against
the canon in [../GameOverview.md](../GameOverview.md) (16×16 blocks, 24px character, WS-25/28/29,
CC-22 palette).

## What makes a Terraria block read as textured

Measured from 16×16 originals (pixel-sampled, quantized):

| Property | Observed | Rule for SunkenCity |
|---|---|---|
| Colors per material | **5–7**: 1 near-black outline/shadow, 3–4 body tones, 1 highlight | Same. Never one flat color; never more than ~7 |
| Tone spacing | Body tones ~**25–30 luminance apart**; highlight ~+30 over the top body tone; outline ~lum 10–25, hue-tinted (not pure black) | Build every material as a 5-step ramp from one hue |
| Texture unit | **Clusters of 2–4px**, each shaded as a tiny form (light top-left, dark bottom-right / dark 1px gap between units) — *not* per-pixel noise | Draw shapes, then shade them; random single pixels look like static |
| Edges | 1px dark outline on faces that meet air | Outline lives on exposed faces only (autotile / edge pass), not baked into every tile |
| Repetition | Several pattern variants per tile, picked at random per cell | Atlas columns = **pattern variants** (same palette), not brightness steps |
| Background walls | Same texture family, darker and flatter (less contrast) | Keep the `BackWalls` layer modulate (~0.42) or author dedicated wall tiles at −50% value, −30% contrast |

### Per-material recipes

**Stone (cobble):** irregular rounded pebbles 2–4px across, packed with 1px dark gaps; each
pebble gets a lighter top/left pixel and a darker bottom/right. ~50% mid-gray, 20% light, 20%
dark, 10% outline. No row/column structure — luminance is flat across rows and columns.

**Brick:** horizontal courses **3px tall** separated by a **1px mortar row** (rows ≈ 4, 8, 12 of
16); bricks ~6–7px wide with 1px vertical mortar joints, **staggered half a brick per course**.
Each brick: base tone, 1px lighter top edge, a couple of darker speckle pixels. Mortar is a
neutral dark gray, not the brick hue.

**Wood (planks):** horizontal boards **3–4px tall** with a **1px dark seam** between them and a
**1px lighter top edge** on each board; grain = short 1–3px horizontal dashes ±1 tone. The
smooth "solid wood" variant drops the seams and keeps only the dash grain (5–6 tones).

**Metal (SunkenCity, not in the reference):** follow the brick recipe with larger plates
(8×8 or 16×4), rivets as single highlight+shadow pixel pairs, and a cool desaturated ramp.

**Glass:** near-transparent with a 1px outline and a diagonal 2px highlight streak; fragile
(GL-01) so it also needs a cracked variant.

## Palette discipline (CC-22 / WS-29)

- Materials are **low-saturation** ramps; the **depth color grade** (WS-29) does the mood tinting,
  so tiles must not carry strong hue themselves. Bricks = dusty red, wood = muted brown, metal =
  blue-gray, concrete = warm gray, plastic = whichever accent the object needs.
- **Warm = safe, cold = deep** applies to lights and props, not structure blocks.
- Player-placed blocks should be visually distinguishable from structure (GL-01, unbreakable):
  give craftable blocks a slightly cleaner/brighter ramp than found structure.

## Atlas layout (current placeholder → real art)

`assets/tiles/placeholder_blocks.png`: rows = materials (stone, wood, metal, plastic, water,
ladder, rope), **columns = 5 variants of the same material**. The placeholder currently uses the
columns as brightness steps; the real art keeps the same layout with columns as pattern variants,
so `test_tower.gd`'s position-hash variant pick and the TileSet resource carry over unchanged.

Edge outlines: plan for a Godot **terrain set** (autotile) so exposed faces get the 1px dark
edge automatically; the base 16×16 textures stay outline-free and seamless (patterns wrap at 16px).

## Character (WS-02/25, canon 24px)

`docs/Examples/Character/MainCharacter.png` is a **style reference, not a pixel spec**: it is
drawn at roughly 2.5–3× our canon scale (canon = **24px tall with hair, 21 without, 12×22 hitbox**).
Carry over from it: the silhouette reads (goggles on the head, scarf, backpack, rolled trousers,
bare feet — a diver-scavenger), a 4-direction sheet (front/back/two sides — our game needs only
side + flipped, so front/back are for menus/character creation), and a muted brown/blue/khaki
palette. At 24px most of that detail collapses to 1–2px accents; the layered paper-doll
(body + hair/shirt/pants tints + gear overlays, WS-25) is where those accents live.

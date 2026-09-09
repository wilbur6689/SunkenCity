---
name: character-animation
description: Animate a pixel-art character from a single resting image — plan key poses, breakdowns, timing and anchors, compose frames with the rig-and-pose tool (charanim.py), hand-fix the pixels, and ship a sprite sheet + animation data the engine can play. Use for any player/NPC/creature animation set (idle, walk, sprint, jump, land, crawl, climb, swim, tool/weapon actions, hurt, death …), for reviewing motion, or for wiring clips into a state machine. Pairs with pixel-game-art (how each frame is drawn); this skill is how the frames MOVE.
argument-hint: [rest-image-or-clip-to-animate-or-review]
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, PowerShell
user-invocable: true
effort: high
---

# Character Animation

You turn ONE resting image of a character into every animation the game needs. The method is
**pose-driven pixel animation**: a few strong, readable poses that say where the weight is,
where the body is going, what it is doing and how much force it applies — not many frames
that each move everything slightly. Canon for the craft is
`docs/SunkenCity_Character_Animation_Craft.md` (read it once per session; this skill is its
working procedure). The per-frame drawing rules (scale, ramps, light, outlines, cleanup) are the
`pixel-game-art` skill — load it before any pixel work. The clip list and its status live in
`docs/PlayerAnimations.md`.

Files in this skill folder:

- `charanim.py` — the rig-and-pose composer: rest frame + part mask + poses → frames, sheet,
  `anim.json` (per-frame hand anchors), a 1×/3× preview and GIFs. `python charanim.py` prints the
  formats.
- `clips.md` — pose recipes for every clip (key poses, part rotations, timing, holds, anchors,
  transitions) tuned for a ~30 px character.
- `example/` — the SunkenCity diver rigged and animated (idle/walk/sprint/jump/land/hurt): copy
  it as the template for a new character.

---

## 0. The three questions before touching a pixel

1. **What does the body do?** One sentence per clip ("pulls the tool back, then drives it into the
   block in front"). If you cannot write it, you cannot animate it.
2. **Where is the weight?** Name the centre of gravity in every key pose (over the planted foot;
   low and forward before a jump; behind the feet in a flinch).
3. **Which single frame proves the action?** Chop = tool raised → impact; shoot = aim → recoil;
   pick up = reach → grab; climb = grab → pull; jump = crouch → launch. If that frame does not
   read as a black silhouette, exaggerate the pose before adding detail.

## 1. Intake: audit the rest image

Record the answers in `<character>/character.md` next to the rig; every later decision uses them.

| Ask | Why |
|---|---|
| Frame size, opaque bounds, the feet row (first row BELOW the feet), facing | cell size, `feet_y`, whether frames can grow (a prone body needs a wide cell, a dive with arms out may need a taller one) |
| Row bands: hair/head, torso, hips, legs; the near arm's column band | the part mask |
| Skin / hair / cloth colours | the mask script finds arms and hands by skin; the hand tracker (`tools/gen_hand_anchors.py`) uses the same tones |
| Asymmetric features (hair side, bag, holster, scar, handed tool) | the mirroring decision (§6) — mirror in code unless the asymmetry matters, then hand-correct the mirrored row |
| What the game already plays for each state | never animate a clip the engine cannot reach; list the state → clip mapping first |

SunkenCity answers: 32×32 cells, ~30 px tall, `feet_y` 31 in the frame, `FEET_Y` 12 in the
body, hitbox 12×22, 1 sprite px = 1 world px (3×3 screen px at default zoom), skin tones
`(231,162,128) (199,142,106) (132,81,70)` (+ `(229,166,128)` in the hand-drawn west row).

## 2. Rig it (parts, pivots, z, hand)

A rig is a **part mask** (a copy of the rest frame with each part painted one flat colour) and
`rig.json` (colour → pivot, z-order, optional hand point). Standard parts: `head` (with hair),
`torso`, `arm_near`, `arm_far`, `leg_near`, `leg_far`; add `hair_tail`, `bag`, `tail`, `wing`
for secondary motion. Pivots sit ON the joint: neck for the head, shoulder for arms, hip for
legs, waist for the torso.

- Make the mask with a short script (row bands + skin/colour tests, as in `example/`), never by
  hand-typing coordinates; `python charanim.py check project.json` reports pixels no part owns.
- Look at the mask at 8× (Read the PNG) before animating: an arm that owns a torso strip
  tears the shirt in every frame.
- One `hand` point (the grip) on the near arm; the composer writes its transformed position per
  frame into `anim.json` — that IS the hand anchor for held items. Add a second hand for
  two-handed poses if needed.
- Limbs rotate about their pivot; the whole body can squash/stretch about the feet, lean
  (row-shear from the feet) and rotate about the feet. That is enough for every clip in
  `clips.md`; anything else is a hand-drawn pose.

## 3. Plan every clip on paper first

For each clip, before opening `clips.json`, write (in `character.md` or the clip's comment):

```
clip: <name>           frames: N   fps: F   loop: yes/no   priority tier: 1-5
action: <one sentence>
keys:   READY → ANTICIPATION → ACTION/IMPACT → FOLLOW-THROUGH → RECOVERY   (2-5 poses)
CoG:    <per key>
timing: ██ ██ █ █ ███   (which frames HOLD, which are fast)
arcs:   <hand/foot/tool paths that must curve>
secondary: <hair, cloth, bag: lags one frame behind the body>
anchor: <where the grip is in the impact pose>
in/out: <what pose it starts from and ends in — the next state's first frame>
```

Rules that decide the numbers (from the craft doc):

- **Timing categories**: slow (idle, float, recovery, calm swim), medium (walk, climb, interact,
  swim), fast (sprint, attacks, hurt, jump launch, recoil), very fast (impact, smear, muzzle flash).
  Frames are NOT equal length: hold the anticipation and the impact, rush the travel.
- **Anticipation** before force (crouch before jump, pull back before chop, wind before swing);
  **follow-through** after it (weapon continues, body settles); never stop dead on the target.
- **Squash & stretch** 1–3 px at this scale: squash on crouch/land, stretch on launch.
- **Locomotion** = CONTACT → DOWN → PASSING → UP; arms oppose legs; head steadier than torso;
  the planted foot does not slide (check it frame by frame against the ground line).
- **Sprint ≠ fast walk**: more lean, longer stride, bigger arm swing, more bob and compression.
- **Water**: slower, drifting, no sharp stops, buoyant; **climbing** fights gravity (pull, lift,
  short pause, reach); **death** loses control (posture collapses, limbs stop coordinating).
- **Layers vs baked**: layer the upper body when the legs keep their cycle and the action is
  reusable across tools (carry, aim, light use); bake full-body frames when the centre of
  gravity moves (jump, land, crawl, climb, heavy chop/swing, swim, drown, death).
- Frame counts and per-clip pose recipes: `clips.md`.

## 4. Compose with `charanim.py`

```
python charanim.py build <character>/project.json
```

- Keys hold **only what changes**; unset parameters carry forward from the previous key, so a
  clip's first key sets everything it animates. Ease per key applies to the segment leaving it:
  `in` (accelerate: strikes, launches), `out` (decelerate: settles, landings), `smooth`, `linear`.
- Limb rotation gives hands and feet their arcs for free; add `dx/dy` only for reach or bob.
- Loops: last key at `t == frames` equal to the first key. Non-loops: end in the pose the next
  state starts from (§59–60 of the doc — transitions are part of the design).
- `hold` multiplies a frame's duration in the GIF (and is exported in `anim.json` for the engine).
- Body `lean` for sprint/hurt/strain, `squash` for crouch/launch/land, `rot` for a stagger or a
  dive angle.
- Then **look**: Read `preview.png` (every clip at 1× on a ground line AND at 3×, red dots = hand
  anchors) and the GIFs. Judge at 1× first — that is gameplay scale. Check: feet on the line in
  grounded frames, the impact frame reads as a silhouette, no foot sliding, arcs curve.

## 5. Hand-fix pass (the composer gets you to 80 %)

Nearest-neighbour rotation scatters pixels and opens seams at joints. Fix each frame with the
`pixel-game-art` rules, working on the sheet with a script or pixel editor:

- Re-close silhouettes: fill 1-px holes at joints, delete strays (the composer already drops
  fully isolated pixels), re-run the tinted sel-out outline where a part edge is now inside.
- Keep colours: no new colours; ramps as in the rest frame; highlights may move, never appear.
- Redraw, don't rotate, any limb past ~45°: a bent knee and a foot need 2–3 hand-placed
  clusters, not a rotated column.
- Squash/stretch frames: re-space the face pixels by hand so eyes/mouth stay readable.
- Secondary motion by hand: hair tail and cloth lag a frame behind; 1–2 px is enough.
- Re-check at 1×. Then run the review checklist (§7).

## 6. Sheet, data, engine

- Sheet: one row per clip, equal cells, frame 0 = the clip's first pose (rest for locomotion
  loops); `anim.json` describes it: `{cell, clips: {name: {row, frames, fps, loop, hold,
  anchors}}}`. SunkenCity: `assets/sprites/player.png` + `data/player_anim.json`; the sprite code
  picks a clip by name from state + velocity + flags, never by row number.
- **Priority** when states overlap: death > drowning/critical > hurt > action > jump/fall >
  movement > idle.
- **Mirroring**: draw facing right; mirror in code for symmetric clips (`flip_h` + mirrored
  anchors); hand-correct rows with meaningful asymmetry (the diver's hair and any handed tool).
  The existing west row of the diver is hand-drawn — keep that only if the asymmetry is wanted.
- **Hand anchors per clip**: `tool_carry` low, `harvest_chop` raised, `aim` forward, `use_item`
  at the face. The engine already rides the rest pose on `data/hand_anchors.json`
  (`Player._hand_delta`); a multi-clip sheet extends that file to per-clip rows, and
  `tools/gen_hand_anchors.py` (skin-cluster tracker) or `anim.json` anchors feed it.
- Procedural held-item poses (`Player._attack_pose`, `_chop_pose`) stay: they draw the tool;
  the new clips animate the body under them. Sync their phase fractions to the clip's keys.
- Run the gates after wiring (`m0/m1/m4_smoke`; the LAN sync carries the clip/frame if the
  puppet cannot derive it).

## 7. Review checklist (every clip, yours or not)

**Poses** — 2–5 deliberate keys; action reads in silhouette; CoG makes sense; proportions
constant; contact points believable.
**Motion** — anticipation and follow-through where force is involved; arcs intentional; weight
believable; no foot sliding.
**Timing** — impact and anticipation held; fast things fast; loops seamless; recovery not abrupt.
**Locomotion** — contact and passing poses clear; weight transfers; arms oppose legs; feet grounded.
**Water / climbing** — buoyant and fluid; swimming ≠ walking; drowning ≠ swimming; hands and feet
touch the rungs; pulling visible; hang ≠ climb.
**Actions** — whole body participates; tool arcs; impact frame unmistakable; recovery returns to
the locomotion pose.
**Technical** — name, frames, fps, loop, direction, mirror rule, hand anchor, sheet row all
defined in data; transitions in and out checked; judged at 1×.

Report findings most damaging first and propose the smallest pose/timing change (usually: hold
the impact a frame, add 2 px of anticipation, plant the foot, exaggerate the key).

## 8. Golden rules

Animate poses, not pixels · strong keys beat frame counts · know the centre of gravity ·
anticipation makes it readable, follow-through makes it physical · planted feet stay planted ·
forceful actions move the whole body · water and climbing have their own mechanics · fast
actions need fast timing, heavy ones need weight and recovery · layer when mechanics allow,
bake when they don't · anchors instead of baked-in tools · mirror to save work, correct the
asymmetry · design the transitions · judge at gameplay scale · if it doesn't read as a
silhouette, fix the pose first.

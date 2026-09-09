# Clip recipes

Pose recipes for a ~30 px side-view character rigged as head / torso / arm_near / arm_far /
leg_near / leg_far (see `SKILL.md` §2). Rotations are degrees, positive = clockwise on screen
for a RIGHT-facing character. A limb HANGING from its pivot (arm from the shoulder, leg from
the hip) swings BACKWARD at positive rotation and FORWARD at negative (-30 = foot or hand out
in front; -150 = raised up and forward; +90 = straight back, horizontal). `dy` in px, negative = up. Frame counts are the
craft doc's starting points; timing marks show holds (`██`) vs fast travel (`█`). Every clip
names the pose it starts from and ends in, because transitions are designed, not discovered.

## Locomotion

**idle** — 4–8 f, 4 fps, loop. Breathing only: torso/head/arms `dy` 0 → -1 → 0 → +0 (chest
expands), optional 1 px shoulder drop on the exhale, hair tail lags a frame. Feet never move.
In/out: this IS the rest pose. Anchor: rest hand.

**walk** — 6–8 f, 8–10 fps, loop. CONTACT (legs ±28, arms ∓25, body dy 0) → DOWN (legs ±10,
body dy +1) → PASSING (legs ~0, rear leg swings through, body dy 0) → UP (body dy -1) → CONTACT
mirrored. Head steadier than torso (half the bob). Check the planted foot against the ground
line in every frame: it must not slide. Anchor: the near hand's arc.

**sprint** — 6–8 f, 12 fps, loop. Not a fast walk: body `lean` +4, legs ±45/-40, arms ∓45,
bob dy +2 on DOWN, a flight frame where neither foot touches (dy -1). Longer stride, stronger
compression. In: from walk's CONTACT. Out: the same pose so walk ↔ sprint swap without a hop.

**jump_launch** — 2–3 f, 10 fps, one-shot, hold frame 0 ×2. ANTICIPATION: squash 0.85, knees
bent (legs ±15 toward each other), arms back (+30), head dy +1 · LAUNCH: stretch 1.08, legs
extend, arms fly up (-60). Ease `in` leaving the crouch. Out: into `rise`.

**rise** — 1–2 f, held. Legs tucked (near +20, far -15), arms up (-120/-110), body 1.0. Reads
"going up": limbs react to the push, not a standing sprite moved upward.

**apex_fall** — 1–3 f, held while `velocity.y >= 0`. Apex: limbs relax (arms -90, legs ±10),
body slightly less stretched. Fall: arms out (-60/-40), legs reaching down (near -15, far +10),
body 1.03. Fall must differ from rise.

**land** — 2–4 f, 10 fps, one-shot, hold the squash ×2. IMPACT: squash 0.8, arms forward/down
(+20), head dy +1 → RECOVERY: 1.0, arms 0. Ease `in` to impact, `out` to recovery. A damaging
fall holds the squash 2× longer. Out: idle or walk CONTACT.

**crawl** — 6–8 f, 8 fps, loop, wide cell. Baked pose, not a rotated walker: torso rotated
~80–90° lying along the ground, head raised looking forward, near arm reaches forward (-60)
then pulls back under the shoulder (+20), legs push alternately (near leg bends +40, far leg
straight). Body inches forward on the pull; hips drop 1 px on the push. Prone idle: 4–6 f,
breathing + a 1 px head lift.

**climb** — 4–6 f, 8 fps, loop, drives from climb speed. REACH (near arm -150 up, far arm -60,
near leg +45 on a rung) → GRAB (hold 1 f) → PULL (body dy -3, arms swing to -60/-150, legs swap)
→ LIFT. Hands and feet visibly ON the rungs; a short pause after each pull (the doc's "fight
gravity"). Body faces the ladder: use a back/three-quarter rest if one exists, else the side
view hugging the rail. **climb_hang** 2–4 f: both arms up (-160), legs dangling, 1 px sway.
**climb_idle** 4–6 f: tension breathing, no rung change.

**tread_water** — 6–10 f, 6 fps, loop. Head above the line, torso bobs dy 0/+1/0/-1, arms
scull alternately (near -20 → +20, far opposite), legs kick alternately small (±15). Slow and
fluid. Water reacts (ripples are the world's job). Out: `prone_swim` when moving.

**prone_swim** — 6–8 f, 8 fps, loop, wide cell. Body horizontal (torso rot ~85), **head raised
looking forward**, REACH (near arm forward along the surface) → PULL (arm sweeps under to the
hip, +90 travel) → RECOVER (lifts over the surface, arc). Legs flutter ±15 out of phase with
the arms. No sharp stops; ease everything `smooth`.

**underwater_float** — 6–10 f, 4 fps, loop. Slow sway: body rot ±5, arms drift (-30 ↔ -60),
legs drift, hair tail lags 2 frames, 1 px vertical drift. Never the land idle. **dive_down /
surface_up** (optional) — 2 f each: the prone pose angled by body `rot` (±30); head breaks the
surface first on the way up.

## Actions (upper body; the tool sprite is procedural on top)

**tool_carry** — 2–4 f, layer over locomotion. Near arm bent to hold at the hip (+15, elbow
in), shoulder 1 px down on the tool side, torso lean +1. Anchor: low hand. With a heavy tool
the walk bob shrinks by 1 px.

**harvest_chop** — 5–8 f, 12 fps, loop while harvesting; sync to the engine's chop cycle
(SunkenCity: 0.55 s, lift 60 %, strike to 85 %, hold). READY → ANTICIPATION (torso lean -2,
shoulder back) → RAISED (arm -150, torso lean -1, head up 1) → SWING (fast, ease `in`, smear
optional) → IMPACT (arm +50, torso lean +3, head dy +1, knees +5, hold ×2) → FOLLOW-THROUGH →
RECOVERY. The whole body chops, not just the arm. Anchor: raised hand at the top, front hip
at impact.

**weapon_swing** — 5–8 f, 12 fps, one-shot; sync to the engine's swing (wind 28 % / sweep 24 %
/ return). READY → WIND-UP (torso lean -2, arm back, hold) → ATTACK (smear frame for fast
weapons) → IMPACT (torso lean +4, arm +40, front foot planted, hold) → FOLLOW-THROUGH (weapon
continues, body settles) → RECOVERY into rest. The impact silhouette is the clip.

**aim_shoot** — 3–6 f. AIM: near arm extended toward the cursor (rotation from the aim angle,
-90 up … +90 down), far arm supporting, torso lean +1, head turned toward the aim, stable
stance (hold) → RECOIL (very fast: arm +8 back, torso lean -1, head dy -1) → RECOVER. Anchor:
forward hand. Layer over walk when the legs can keep cycling.

**use_item** — 4–8 f, 8 fps. NEUTRAL → REACH (arm to the face, -110) → USE (hold ×2, head tilts
-5) → HOLD → RETURN. Eat/drink/bandage share the clip; the item is the held sprite at the
face-level anchor.

**place** — 4–6 f, 10 fps. CARRY → LOWER (arm forward-down +30, torso lean +2, knees +5) →
PLACE (hold) → RELEASE (arm opens, +10) → RECOVER. The object stays on the hand anchor until
release.

**interact** — 3–6 f, 10 fps. REACH (arm -30 forward, lean +1) → GRAB (hold) → PULL/PUSH (lean
-2 or +3, knees +5) → RECOVER. Heavy interactions use the body; light ones just the arm.

**pick_up** — 4–6 f, 10 fps, one-shot sized to the long-press time so the lift lands on the
last frame. STAND → REACH (arm -20 forward-down) → CROUCH (squash 0.85, knees +25, torso lean
+4, head dy +2) → GRAB (hold) → LIFT (squash 1.0, arm +20 holding, lean +1) → RECOVER. The item
appears in the hand at GRAB, never while standing upright.

## Reactions and status

**hurt** — 3–5 f, 12 fps, one-shot, directional (flip toward the hit). IMPACT (head rot -15,
dx -1, torso lean -3, near arm -30, very fast) → RECOIL (lean -2) → RECOVERY (0). Optional 1 px
step back.

**drowning** — 6–10 f, 8 fps, loop, uncontrolled: rapid uneven arm reaches (-160/-40
alternating, not symmetric), head dips below the line (dy +2) and lifts (dy -1), torso rot ±8,
legs kick wildly. Must read differently from `tread_water`.

**death_land** — 6–12 f, 8 fps, one-shot. IMPACT (as hurt) → STAGGER (lean -4, 1 px step) →
COLLAPSE (body rot 60 → 90 about the feet, knees fold, arms trail) → GROUND (hold) → SETTLE (1 px
drop, arm flops). Final frame stable and clearly inactive.

**death_water** — 6–12 f, 6 fps. STRUGGLE (weak drowning) → WEAK (arms drift down) → SUBMERGE
(dy +2) → SINK/DRIFT (body rot 20–40, limbs loose, hair up) → SETTLE (float, slow sway). Not the
land death under water.

**wake_bed** — 6–10 f, 6 fps, one-shot. SLEEPING (prone, hold) → SMALL MOVEMENT (1 px) → HEAD
LIFTS (head rot -20) → SIT UP (torso rot from 90 to 20, arms push, hold) → PAUSE → STAND
(transition into idle's rest pose).

**cold_shiver** (optional) — 2–4 f, 12 fps, loop layer: shoulders dy ±1 alternating, arms
pulled in (+20), head dx ±1. Restrained, repetitive.

**crush_strain** (optional) — 4–6 f, 6 fps, loop. BRACE (squash 0.92, knees +15, arms up
-100 as if holding a weight) → STRAIN (lean ±1, head dy +1) → PUSH (squash 0.96) → STRAIN →
RECOVER. The body visibly fights the pressure.

## Order of work

1. idle · walk · sprint · jump_launch · rise · apex_fall · land
2. crawl (+ prone idle) · climb (+ hang, idle) · tread_water · prone_swim · underwater_float
3. tool_carry · harvest_chop · weapon_swing · aim_shoot · use_item · interact · pick_up · place
4. hurt · drowning · death_land · death_water · wake_bed
5. cold_shiver · crush_strain · dive_down · surface_up

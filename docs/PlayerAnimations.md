# Player Animations

Tracker for the player character's animation set (started 2026-09-07). Tick the box when a
clip is drawn AND wired.

**Progress (2026-09-07, late):** 28 of 28 body clips wired — section 3 (hurt, drowning, death on land
and in water, wake at bed, cold shiver, crush strain) composed and wired last. Before that: 22 of 28 body clips wired — the eight Action clips joined the set
(section 2: `tool_carry` holds, `harvest_chop` and `weapon_swing` are phase-locked to the tool
poses, `aim_shoot` holds its aim and recoils on a shot, `use_item`/`place`/`interact`/`pick_up` are
one-shots relayed to LAN puppets). Earlier the same evening: 14 of 28 body clips wired: Walk (hand-drawn, reviewed) and the
whole locomotion set composed from the rest frame by the `character-animation` skill (Sprint,
Jump launch, Rise, Fall, Land, Crawl + prone idle, Climb + hang + idle, Tread water, Prone swim,
Underwater float) on `assets/sprites/player_clips.png` (`tools/player_anim/`, rebuilt by
`make_rig.py` then `make_clips.py` then `charanim.py build`). Composed frames are the composer's
80 %: the hand-fix pass (joint seams, rotated limbs redrawn) is still to do on every one. The
tool-sprite side of Tool-carry, Harvest chop and Weapon swing is complete; Idle keeps its
hand-drawn rest frame (a breathing clip is composed but not wired, pending the mirror decision).

How to make them: the `character-animation` skill (`.claude/skills/character-animation/`) —
procedure, `charanim.py` composer, `clips.md` pose recipes; the craft canon is
`docs/SunkenCity_Character_Animation_Craft.md`.

## What exists today

`assets/sprites/player.png` — 32x32 frames, two rows (row 0 east, row 1 west; the west row is
hand-drawn, not a mirror), col 0 idle + cols 1–6 walk. `Player._update_sprite` picks idle or
the walk loop from horizontal speed. Everything else is a stand-in:

| State / event | Shown today |
|---|---|
| AIRBORNE (jump, fall) | jump_launch one-shot, then rise, then fall (composed) |
| CRAWLING | crawl / prone_idle (composed, lying on the ground row) |
| CLIMBING | climb / climb_idle / climb_hang (composed) |
| SURFACE_SWIM | tread_water / prone_swim (composed), body drawn 8 px lower |
| UNDERWATER | underwater_float / prone_swim (composed) |
| sprint | sprint clip (composed: lean, long stride, flight frame) |
| tools / weapons | tool sprite procedural (grip-held, rest on the tracked hand, chop and swing curves) AND the body plays `tool_carry` / `harvest_chop` / `weapon_swing` composed clips phase-locked to those curves (2026-09-07) |
| shooting | `aim_shoot`: aim frame held while a ranged weapon is in hand, recoil frames on the shot (composed) |
| hurt | red flash + debris + sound + the `hurt` flinch clip (composed) |
| death | camera close + fade while `death_land` / `death_water` plays (composed) |
| use item / place / interact / pick up | one-shot composed clips (`play_action`) |

## The list

Frame counts are suggestions for a 32x32 pixel character (~30 px tall). "Loop" clips repeat;
"one-shot" clips play once and return to the state's loop.

### 1. Locomotion (one clip per state-machine branch) — do first

- [ ] **Idle** — 2–4 frame breathing loop (today 1 frame). Low priority; a single frame reads fine.
      *Reviewed 2026-09-07:* the single frame is a sound rest pose (feet on row 30, weight centred,
      the hand tracker reads it); no breathing loop yet, so it stays open.
- [x] **Walk** — 6-frame loop, DONE. *Reviewed 2026-09-07 against the craft guide:* two clear
      CONTACT poses (frames 2, 5) with PASSING poses between (1, 4) and DOWN frames after each
      contact (3, 6); the arm swings in phase with the stride; the loop closes (6 → 1). Fixed the
      same day: the walk frames' feet sat 1 px above the idle frame's (a hop on the first step) —
      dropped 1 px; no vertical bob — the passing frames now carry the body 1 px higher over the
      planted foot; `data/hand_anchors.json` regenerated. Still open, cosmetic: the west row's
      stride is drawn narrower/lower than the east's (hand-drawn rows differ).
- [x] **Sprint** — 6-frame loop: longer stride, forward lean, arms pumping. *Composed + wired
      2026-09-07* (lean 4 px, legs ±45, flight frames; plays above 1.15× walk speed, phase shared
      with walk). Hand-fix pending.
- [x] **Jump launch** — 2 frames (crouch-push), one-shot over the first airborne frames of a jump.
      *Composed + wired 2026-09-07.* Hand-fix pending.
- [x] **Rise** — 2 frames (arms up, legs tucked), AIRBORNE with `velocity.y < 0`. *Composed + wired
      2026-09-07.*
- [x] **Apex / fall** — 2 frames (arms out, legs reaching), AIRBORNE with `velocity.y >= 0`.
      *Composed + wired 2026-09-07* as `fall`.
- [x] **Land** — 3 frames (squash held ×2), one-shot on GROUNDED entry after a fall of > 2 blocks.
      *Composed + wired 2026-09-07.* Not yet: the longer hold on a damaging fall.
- [x] **Crawl** — 6-frame prone loop + 4-frame prone idle, in the 48-wide cell, replaces the rotated
      sprite. *Composed + wired 2026-09-07* (body laid over 85°, head raised, arm reach/pull, legs
      push). Hand-fix pending: rotated legs read thin.
- [x] **Climb** — 4-frame ladder loop driven by climb speed, plus **hang** (2, nothing climbable
      above the head) and **climb idle** (2). *Composed + wired 2026-09-07.* Side view hugging the
      rail; a back view would need new art.
- [x] **Tread water** — 6-frame loop at the surface (arm scull, leg kick, 1 px bob), replaces the
      sunk walk loop. *Composed + wired 2026-09-07.*
- [x] **Prone swim** (user request 2026-09-07) — the body laid flat along the water, head raised and
      looking forward in the facing direction, 4–6 frame stroke/kick loop (arms reach and pull,
      legs flutter). Plays while MOVING in SURFACE_SWIM (the waterline at the shoulders, so the
      tread-water clip hands over as soon as the stick moves) and for level travel in UNDERWATER,
      replacing the rotated standing sprite. Because the pose is horizontal, the frame is wide:
      draw it in the same cell as the crawl (32 wide) with the head near the cell's leading edge.
      *Composed + wired 2026-09-07* (body 80°, head -60°, full-circle arm stroke, flutter kick) for
      surface travel AND level underwater travel. Hand-fix pending.
- [x] **Underwater float** — 6-frame drift (body 65–75°, limbs drifting, 1 px rise), replaces the
      rotated sprite. *Composed + wired 2026-09-07.*
- [ ] **Dive down / surface up** — 2 frames each, the prone swim angled by `velocity.y` while
      UNDERWATER (optional; the prone swim rotated in code is the cheap version).

### 2. Actions (upper body; the held-tool sprite stays procedural on top)

- [x] **Tool-carry arm** — the arm bent to hold the tool at rest (1 frame per locomotion clip, or a
      separate arm overlay layer). *Tool half DONE 2026-09-07:* the held item is pinned to the
      tracked hand in every idle/walk frame (`Player._hand_delta`, `tools/gen_hand_anchors.py`);
      only the arm art itself is missing. *Body DONE 2026-09-07:* a 2-frame `tool_carry` stance (arm
      bent at the hip, 1 px lean, breathing) plays while standing with a tool or weapon in hand.
- [x] **Harvest chop body** — 2–3 frames of lean/shoulder synced to `CHOP_CYCLE_TIME`. *Tool half
      DONE 2026-09-07:* lift from the shoulder to head height (60 %), chop to the ground out front
      (85 %), impact hold, repeat (`Player._chop_pose`); the one-shot hammer hit plays its last 55 %.
      *Body DONE 2026-09-07:* 6 frames (ready, lean back, raised, swing, impact lean +3 with a knee
      dip, settle) PHASE-LOCKED to that cycle (`Player._chop_phase`), so body and tool never drift.
- [x] **Weapon swing body** — 2–3 frames of torso twist synced to wind / sweep / return. *Tool half
      DONE 2026-09-07:* wind back over the head to flat behind the hip (28 %), sweep around the head
      down to the ground in front at full arm stretch (24 %, the hit window), ease home
      (`Player._attack_pose`); one attack interval long, swoosh on the sweep. *Body DONE 2026-09-07:*
      6 frames (ready, wind lean back, attack, impact lean +4 front foot planted, follow-through,
      recovery) phase-locked to the swing's wind/sweep/return.
- [x] **Aim + shoot** — `aim_shoot`: the aim frame (arm level out front, 1 px lean) holds while a
      ranged weapon is in hand and the body is still; a shot plays the recoil + recover frames.
      *Composed + wired 2026-09-07.* Not yet: the arm following the cursor angle.
- [x] **Use item** — 5 frames (reach to the face, use held ×2, return), one-shot on `Player.use_item`.
      *Composed + wired 2026-09-07.*
- [x] **Place** — 4 frames (carry, lower with a knee dip, place held, release), one-shot on a block or
      object placement. *Composed + wired 2026-09-07.*
- [x] **Interact** — 3 frames (reach, grab held ×2, recover), one-shot on E and on the short LMB press
      release. *Composed + wired 2026-09-07.*
- [x] **Pick up** — *Composed + wired 2026-09-07:* 5 frames (reach, crouch squash 0.85 lean 4, grab,
      lift, recover), 0.5 s = the long press, started with the press so the grab lands as the item
      transfers (hammer lifts of furniture/ladders/ropes, bare-hand wood blocks). Design: bend at the knees/waist, hand to the object, straighten
      with it. Plays on the hammer's long-press lift of furniture/ladders/ropes
      (`Interaction._pickup_object` / `_pickup_climbable`), on a death-backpack recovery and on a
      manual item pickup; the automatic magnet pickup of dropped items does not need it (the items
      fly to the player). Its length should cover `OBJECT_LONG_PRESS` so the lift lands on the last
      frame.

### 3. Reactions and status

- [x] **Hurt flinch** — 3 frames (head snap, lean back, recover), one-shot from `_hurt_fx`; outranks
      every clip but death. *Composed + wired 2026-09-07.*
- [x] **Drowning struggle** — 6-frame loop (uneven arm reaches, head dipping, torso rocking, wild
      kicks), UNDERWATER with `drowning`. *Composed + wired 2026-09-07.*
- [x] **Death on land** — 8 frames (impact, stagger, collapse forward, ground, settle; last frames
      held), plays through the 3 s death scene. *Composed + wired 2026-09-07.*
- [x] **Death in water** — 8 frames (weak struggle, arms drift down, submerge, drift over, settle
      afloat). *Composed + wired 2026-09-07.*
- [x] **Wake at bed** — 6 frames (lying held, stir, head lifts, sit up held, rise, stand), one-shot on
      `respawn` (world start included). *Composed + wired 2026-09-07.*
- [x] **Cold shiver** — 4-frame loop (shoulders, arm pulled in, head jitter) while standing still in
      The Cold without a cold-rated suit. *Composed + wired 2026-09-07.*
- [x] **Crush strain** — 6-frame loop (brace, strain, push, strain) while standing still in The Crush
      without a crush-rated suit. *Composed + wired 2026-09-07.*

Not frames: bleeding (particles), the head lamp pip, suit tints (modulate) stay as they are.

## Decisions to make before drawing

1. **West row: mirror or hand-draw?** The current west row is hand-drawn (hair/face asymmetry).
   Mirroring in code halves the art for ~60 new frames; the hand tracker then mirrors its anchors.
   Recommendation: draw east only and mirror, unless the asymmetry matters to you.
2. **Cell size.** 32x32 fits everything standing and prone; a diving body with arms extended may want
   32x40. Decide once — the sheet loader and `FEET_Y` depend on it.
3. **Sheet layout.** One row per clip, described by `data/player_anim.json` (`{clip: {row, frames,
   fps, loop}}`) so `_update_sprite` picks clips by name from state + velocity + flags; the hand
   tracker tool then writes anchors per clip row.
4. **Layering.** Body + arm overlay (so tools ride a real arm in every clip) vs. baked frames.
   Overlay costs one small extra sheet and keeps the procedural tool poses; baked is simpler art but
   the held tool floats on frames whose arm is elsewhere.

## Suggested order

1. Climb, crawl, tread water, prone swim, underwater float — they replace the rotated-body placeholders.
2. Jump / fall / land, sprint.
3. Hurt, drowning, death, wake.
4. Aim/shoot, use, place, interact, pick up, the action body frames.

# Sunken City — Character Animation Craft & Animation System Guide

## Purpose

This document defines **how characters move** in Sunken City.

It is intentionally separate from the project's pixel-art drawing/style guide.

The existing pixel-art guide defines how individual frames should be constructed:

- Character scale and pixel density
- Silhouette-first drawing
- Color ramps
- Hue shifting
- Lighting
- Outlines
- Pixel cleanup
- Frame consistency

This document defines the animation craft that connects those frames:

- Key poses
- Breakdowns
- Weight and body mechanics
- Timing
- Anticipation
- Follow-through
- Locomotion cycles
- Jump mechanics
- Water movement
- Climbing
- Combat/action mechanics
- Layered animation
- Sprite-sheet organization
- Animation data conventions
- Mirroring

---

# 1. Animation Philosophy

Sunken City should use **pose-driven pixel animation**.

The objective is not to create perfectly smooth animation by adding as many frames as possible.

The objective is to create a small number of **strong, readable poses** that communicate:

- Where the character's weight is
- What direction they are moving
- What action they are performing
- What they are interacting with
- How much force they are applying
- What state they are currently in

A good animation should remain readable even when viewed at the game's normal gameplay scale.

---

# 2. The Difference Between Frames and Motion

A sprite sheet can contain technically consistent frames and still have poor animation.

The important question is not:

> "Are the frames drawn correctly?"

It is:

> "Does the character's body move correctly from one pose to another?"

Animation should therefore be designed around:

```text
Key Pose
    ↓
Breakdown
    ↓
Key Pose
    ↓
Breakdown
    ↓
Key Pose
```

rather than:

```text
Frame 1
 ↓
Move everything slightly
 ↓
Frame 2
 ↓
Move everything slightly
 ↓
Frame 3
```

The second approach often produces stiff, mechanical motion.

---

# 3. Key Poses

Key poses define the important moments of an action.

For example, a melee swing might use:

```text
READY
  ↓
WIND-UP
  ↓
IMPACT
  ↓
FOLLOW-THROUGH
  ↓
RECOVERY
```

Each of these poses should be deliberately designed.

Do not begin by filling in every frame.

Create the important poses first.

---

# 4. Breakdowns

Breakdowns describe **how the character travels between key poses**.

A breakdown answers questions such as:

- Which foot moves first?
- Does the torso rotate?
- Does the head lead or lag?
- Does the weapon travel in an arc?
- Does the character compress?
- Where is the center of gravity?

Breakdowns are where much of the character's personality and physicality is created.

---

# 5. The Character's Center of Gravity

Always know where the character's weight is.

For a standing character:

```text
       HEAD
         O
        /|\
         |
        / \
         ↓
    CENTER OF GRAVITY
```

When the character moves, the center of gravity should shift appropriately.

For example, during a sprint:

```text
        O
       /|
      / |
     /  |
    /  /
   /  /
  /__/
      →
```

The body leans into the movement.

A character should not appear to move quickly while their torso remains perfectly upright.

---

# 6. Anticipation

Anticipation prepares the player for a major action.

The character briefly moves in the opposite direction before the primary action.

Examples:

### Jump

```text
Standing
   ↓
Crouch
   ↓
Launch
```

### Axe Chop

```text
Ready
   ↓
Pull tool backward
   ↓
Swing forward
```

### Heavy Attack

```text
Neutral
   ↓
Wind-up
   ↓
Strike
```

Anticipation makes actions easier to read and gives them weight.

---

# 7. Follow-Through

Follow-through occurs after the primary action.

The character should not always stop immediately after the action reaches its target.

Example:

```text
Wind-up
   ↓
Swing
   ↓
Impact
   ↓
Weapon continues
   ↓
Body settles
```

This is especially useful for:

- Melee weapons
- Tools
- Running
- Jumping
- Swimming
- Climbing
- Throwing

---

# 8. Squash and Stretch

Squash and stretch should be subtle because Sunken City uses small pixel characters.

Use it primarily to communicate force.

## Jump

```text
Standing
   ↓
Squash
   ↓
Stretch
   ↓
Airborne
```

## Landing

```text
Falling
   ↓
Impact
   ↓
Squash
   ↓
Recovery
```

The character does not need to visibly distort by much.

Even a 1–3 pixel change in body proportions can communicate impact.

---

# 9. Timing

Timing is one of the most important parts of pixel animation.

Do not assume every frame should have equal duration.

For example:

```text
Frame:  1   2   3   4   5   6
Time:   ██  ██  █   █   █  ███
```

This creates:

- Hold
- Anticipation
- Fast movement
- Impact
- Recovery

Different actions should have different timing characteristics.

---

# 10. Animation Timing Categories

## Slow

Use for:

- Idle
- Sleeping
- Floating
- Recovery
- Calm swimming

## Medium

Use for:

- Walking
- Climbing
- Interacting
- Normal swimming

## Fast

Use for:

- Sprinting
- Attacks
- Hurt reactions
- Jump launch
- Weapon recoil

## Very Fast

Use for:

- Impact
- Muzzle flash
- Hit reactions
- Smear frames

---

# 11. Recommended Frame Counts

These are starting points rather than strict requirements.

| Animation | Frames |
|---|---:|
| Idle | 4–8 |
| Walk | 6–8 |
| Sprint | 6–8 |
| Jump Launch | 2–3 |
| Rise | 2–3 |
| Apex | 1–3 |
| Fall | 2–3 |
| Land | 2–4 |
| Crawl | 6–8 |
| Prone Idle | 4–6 |
| Climb | 4–6 |
| Climb Hang | 2–4 |
| Climb Idle | 4–6 |
| Tread Water | 6–10 |
| Prone Swim | 6–8 |
| Underwater Float | 6–10 |
| Tool Carry | 2–4 |
| Harvest Chop | 5–8 |
| Weapon Swing | 5–8 |
| Aim + Shoot | 3–6 |
| Use Item | 4–8 |
| Place | 4–6 |
| Interact | 3–6 |
| Pick Up | 4–6 |
| Hurt Flinch | 3–5 |
| Drowning | 6–10 |
| Death Land | 6–12 |
| Death Water | 6–12 |
| Wake at Bed | 6–10 |

Strong animation is more important than hitting an exact frame count.

---

# 12. Locomotion Animation

Locomotion should be built around the character's weight and foot placement.

The most important locomotion principles are:

- Contact
- Weight transfer
- Passing
- Vertical body movement
- Arm/leg opposition
- Ground contact
- Direction of travel

---

# 13. Idle

Idle should communicate that the character is alive without excessive movement.

Use subtle:

- Breathing
- Weight shifts
- Head movement
- Shoulder movement
- Clothing movement

Example:

```text
Frame 1
Normal

Frame 2
Chest expands slightly

Frame 3
Normal

Frame 4
Chest contracts slightly
```

The feet should generally remain planted.

Idle should establish the character's default rest pose.

---

# 14. Walk Cycle

A walk cycle should be based on four primary positions:

```text
CONTACT
   ↓
DOWN
   ↓
PASSING
   ↓
UP
   ↓
CONTACT
```

## 14.1 Contact

One foot is forward while the other is behind.

The character is at the beginning of a weight transfer.

The body is relatively extended.

## 14.2 Down

The body drops slightly as weight settles onto the forward foot.

The knee bends.

The center of gravity lowers.

## 14.3 Passing

The rear foot passes underneath the body.

The character is temporarily balanced over the planted foot.

## 14.4 Up

The body rises slightly.

The rear leg prepares for the next contact.

---

# 15. Walk Arm Mechanics

Arms should generally oppose the legs.

```text
Left leg forward
    +
Right arm forward

Right leg forward
    +
Left arm forward
```

This creates natural counter-rotation.

The head should generally remain more stable than the torso.

---

# 16. Preventing Foot Sliding

Foot sliding occurs when a planted foot moves across the ground between frames.

During a contact pose:

```text
     BODY
       |
       |
      / \
     /   \
    █     █
──────────────
    GROUND
```

The planted foot should remain anchored while the body moves over it.

This is one of the most important checks for walk and sprint animations.

---

# 17. Sprint

Sprint should not simply be a faster walk.

Change the body mechanics.

A sprint should generally include:

- Greater forward lean
- Longer stride
- Stronger arm movement
- More exaggerated leg positions
- Greater vertical movement
- Stronger body compression
- More aggressive silhouette

The character should appear to be **committing their body to forward movement**.

---

# 18. Jump Launch

Jumping should have three important phases:

```text
Anticipation
     ↓
Launch
     ↓
Airborne
```

### Anticipation

Compress the body.

- Bend knees
- Lower hips
- Slightly lower torso
- Prepare arms

### Launch

Rapidly extend the legs.

The body should lengthen slightly.

### Airborne

The character leaves the ground.

The launch pose should visually communicate force.

---

# 19. Jump Rise

During the rise:

- Character is clearly airborne
- Legs react to the jump
- Body may stretch slightly
- Arms react to momentum

Do not simply move the standing sprite upward.

The body should visibly react to being airborne.

---

# 20. Jump Apex

At the apex, vertical velocity is near zero.

The pose can become briefly lighter or more relaxed.

Possible characteristics:

- Limbs relax
- Body becomes less stretched
- Arms reposition
- Character briefly appears suspended

The apex can be a short held pose.

---

# 21. Jump Fall

During the fall:

- Character begins orienting downward
- Limbs react to gravity
- Body becomes more extended
- Feet prepare for landing

The fall pose should be distinguishable from the rise pose.

---

# 22. Landing

Landing should communicate impact.

Suggested sequence:

```text
Falling
   ↓
Impact
   ↓
Squash
   ↓
Recovery
```

At impact:

- Knees bend
- Torso drops
- Head may dip
- Arms react
- Body compresses

The landing animation should not instantly return to idle.

---

# 23. Crawl

Crawling should use completely different body mechanics from walking.

The torso remains close to the ground.

Movement should come from:

- Shoulder movement
- Arm pulls
- Hip movement
- Leg pushes

Avoid simply taking the walking animation and lowering it vertically.

---

# 24. Prone Idle

Prone idle should communicate that the character is lying on the ground.

Use:

- Small breathing movement
- Minor head movement
- Small arm adjustments
- Clothing movement

The silhouette should remain clearly prone.

---

# 25. Climbing

Climbing should make the character appear physically connected to the climbable surface.

Basic cycle:

```text
Reach
  ↓
Grab
  ↓
Pull
  ↓
Lift
  ↓
Reach
```

Hands and feet should visibly contact:

- Ladders
- Ropes
- Pipes
- Vines
- Walls
- Other climbable surfaces

---

# 26. Climb Hang

The hanging pose should communicate that the character is suspended.

Characteristics:

- Arms extended
- Hands gripping
- Body hanging
- Legs dangling
- Slight body sway

This should be a distinct state from active climbing.

---

# 27. Climb Idle

Climb idle represents holding position.

Use:

- Small breathing movement
- Slight arm tension
- Minor leg movement
- Small body sway

Avoid using the normal idle pose.

---

# 28. Water Animation

Water requires different body mechanics from land.

Water removes some of the rigid relationship between the character and the ground.

Important concepts:

- Buoyancy
- Drag
- Resistance
- Floating
- Momentum
- Water displacement

Character motion should generally be slower and more fluid.

---

# 29. Tread Water

Treading water should keep the character near the water surface.

Use:

- Alternating arm paddles
- Alternating leg kicks
- Torso bob
- Small vertical movement
- Head staying above the surface

The water surface should react to the character.

Optional effects:

- Ripples
- Small splashes
- Foam
- Water displacement

---

# 30. Prone Swimming

The character should become primarily horizontal.

Basic cycle:

```text
Reach
   ↓
Pull
   ↓
Recover
   ↓
Reach
```

The arms provide most of the visible propulsion.

The legs provide secondary kicking motion.

The torso should remain relatively horizontal.

---

# 31. Underwater Floating

Underwater movement should be slower and less constrained by gravity.

Use:

- Slow body sway
- Floating arms
- Floating legs
- Clothing movement
- Hair movement
- Small vertical drift
- Occasional bubbles

Avoid simply using the land idle animation underwater.

---

# 32. Dive Down

Optional animation.

Suggested sequence:

```text
Tread
   ↓
Lean
   ↓
Head enters water
   ↓
Torso follows
   ↓
Underwater
```

The character should transition through the water surface rather than instantly changing state.

---

# 33. Surface Up

Reverse the underwater transition:

```text
Underwater
   ↓
Rise
   ↓
Head breaks surface
   ↓
Body follows
   ↓
Tread
```

The head should break the water first.

---

# 34. Tool Carry

Tool carry should be treated as a reusable pose/layer.

Examples:

- Axe
- Pickaxe
- Shovel
- Hammer
- Fishing tool
- Other equipment

The character should visually react to the weight and position of the tool.

Possible changes:

- Shoulder position
- Arm position
- Torso lean
- Hand placement
- Walking posture

---

# 35. Harvest Chop

Harvesting should communicate force.

Recommended sequence:

```text
READY
  ↓
ANTICIPATION
  ↓
TOOL RAISED
  ↓
SWING
  ↓
IMPACT
  ↓
FOLLOW-THROUGH
  ↓
RECOVERY
```

The entire body should participate.

Animate:

- Torso
- Shoulder
- Arm
- Hip
- Legs
- Tool

Do not animate only the tool.

---

# 36. Weapon Swing

Use:

```text
Ready
  ↓
Wind-up
  ↓
Attack
  ↓
Impact
  ↓
Follow-through
  ↓
Recovery
```

The impact pose should be particularly readable.

Use a strong silhouette.

Fast weapons may benefit from a smear frame.

---

# 37. Aim + Shoot

Aiming should establish a stable firing pose.

Important elements:

- Head direction
- Weapon direction
- Arm position
- Torso rotation
- Leg stance

Shooting can be extremely short:

```text
Aim
 ↓
Recoil
 ↓
Recover
```

The recoil should affect the weapon and upper body.

Optional effects:

- Muzzle flash
- Smoke
- Shell casing
- Weapon movement

---

# 38. Use Item

Recommended sequence:

```text
Neutral
  ↓
Reach
  ↓
Use
  ↓
Hold
  ↓
Return
```

Examples:

- Eat
- Drink
- Read
- Apply
- Use device
- Consume item

The hand should visibly interact with the object.

---

# 39. Place

Placement should communicate lowering and releasing an object.

```text
Carry
  ↓
Lower
  ↓
Place
  ↓
Release
  ↓
Recover
```

The object should remain connected to the hand until release.

---

# 40. Interact

Interaction animations should be short and readable.

Examples:

- Open
- Pull
- Push
- Search
- Turn
- Activate

Heavy interactions should use the body.

For example:

```text
Reach
 ↓
Grab
 ↓
Lean
 ↓
Pull
 ↓
Recover
```

---

# 41. Pick Up

A pickup should involve the character lowering their center of gravity.

```text
Standing
   ↓
Reach
   ↓
Crouch
   ↓
Grab
   ↓
Lift
   ↓
Recover
```

Avoid making the item disappear while the character is standing upright unless the interaction specifically calls for it.

---

# 42. Hurt Flinch

Hurt reactions should be short and directional.

```text
Normal
  ↓
Impact
  ↓
Recoil
  ↓
Recovery
```

Possible components:

- Head snap
- Torso recoil
- Shoulder movement
- Arm movement
- Step backward

The reaction direction should ideally reflect where the damage came from.

---

# 43. Drowning Struggle

Drowning should look very different from normal swimming.

Possible sequence:

```text
Tread
  ↓
Submerge
  ↓
Struggle
  ↓
Surface
  ↓
Submerge
  ↓
Struggle
```

Use:

- Rapid arm movement
- Uneven body movement
- Head dipping underwater
- Desperate reaching
- Bubbles
- Splashes

The motion should become increasingly uncontrolled compared with normal swimming.

---

# 44. Death on Land

Suggested sequence:

```text
Impact
  ↓
Stagger
  ↓
Collapse
  ↓
Ground
  ↓
Settle
```

The final pose should clearly communicate that the character is no longer active.

Use gravity and body weight.

---

# 45. Death in Water

Water death should use buoyancy and drag.

Suggested sequence:

```text
Struggle
  ↓
Weak movement
  ↓
Submerge
  ↓
Sink / Drift
  ↓
Float / Settle
```

Optional effects:

- Bubbles
- Ripples
- Floating clothing
- Slow body movement

Do not simply play the land death animation underwater.

---

# 46. Wake at Bed

Suggested sequence:

```text
Sleeping
  ↓
Small movement
  ↓
Head lifts
  ↓
Sit up
  ↓
Pause
  ↓
Stand / Transition
```

Avoid instantly snapping from lying down to standing.

---

# 47. Cold Shiver

Optional status animation.

Use small rapid movements:

- Shoulders
- Arms
- Head
- Torso

The character may pull their arms closer to their body.

The motion should be repetitive but restrained.

---

# 48. Crush Strain

Optional status animation for heavy environmental pressure.

Suggested sequence:

```text
Normal
  ↓
Brace
  ↓
Strain
  ↓
Push
  ↓
Strain
  ↓
Recover
```

Use:

- Bent knees
- Lower center of gravity
- Arms pushing
- Torso compression
- Head movement

The character should visibly fight the force being applied to them.

---

# 49. Layered Animation

Sunken City should prefer reusable animation components where practical.

Instead of creating a unique full-body animation for every possible combination, separate animation into logical layers.

Conceptually:

```text
BASE MOVEMENT
       +
UPPER BODY ACTION
       +
HELD ITEM
       +
STATUS
       +
EQUIPMENT
```

Example:

```text
Walk
 +
Axe Carry
 =
Walking with Axe
```

Another example:

```text
Walk
 +
Tool Carry
 +
Cold Shiver
 =
Walking while cold
```

---

# 50. When to Use Layers vs Baked Frames

Not every animation should be layered.

## Prefer layers when:

- The action primarily affects the upper body.
- Legs can continue their locomotion cycle.
- The held item is independent.
- The action can be reused with multiple tools.
- The body mechanics remain compatible.

Examples:

- Aim while walking
- Carrying a tool
- Holding an item
- Using some lightweight items

## Prefer baked full-body frames when:

- The torso and legs must move together.
- The action changes the center of gravity.
- The character changes posture substantially.
- The action requires precise body mechanics.

Examples:

- Jump
- Land
- Crawl
- Climb
- Heavy chop
- Heavy melee attack
- Death
- Swimming
- Drowning

---

# 51. Hand Anchors

Held objects should have defined attachment points.

Each animation should specify a hand/tool anchor.

Conceptually:

```text
Character Frame
      |
      └── Hand Anchor
              |
              └── Tool Sprite
```

The anchor should identify:

- X position
- Y position
- Facing direction
- Rotation/orientation if applicable

This allows tools and weapons to be reused without manually redrawing the entire character.

---

# 52. Hand Anchor Per Clip

Different actions may require different anchor positions.

Examples:

```text
tool_carry
    → low hand anchor

harvest_chop
    → raised hand anchor

weapon_aim
    → forward hand anchor

weapon_swing
    → swing-specific anchor

use_item
    → face-level hand anchor
```

Do not assume one universal hand position will work for every animation.

---

# 53. Mirroring Rules

Mirroring can reduce the amount of artwork required.

Safe candidates for mirroring:

- Basic walking
- Basic idle
- Simple locomotion
- Some climbing
- Some swimming

Be careful when mirroring:

- Weapons
- Tools
- Character-specific equipment
- Asymmetrical clothing
- Bags
- Holsters
- Character scars or markings
- Handed actions

If an asset has meaningful left/right differences, it should be manually corrected after mirroring.

---

# 54. Directional Animation

Recommended base directions:

```text
Up
Down
Left
Right
```

Additional diagonal directions may be added if gameplay requires them.

Four-direction animation is generally easier to maintain than eight fully unique directions.

Use mirroring where appropriate.

---

# 55. Sprite Sheet Organization

Multi-clip sheets should use a predictable structure.

Example:

```text
character_sheet.png

Row 01 — idle_down
Row 02 — idle_up
Row 03 — idle_left
Row 04 — idle_right

Row 05 — walk_down
Row 06 — walk_up
Row 07 — walk_left
Row 08 — walk_right

Row 09 — sprint_down
Row 10 — sprint_up
Row 11 — sprint_left
Row 12 — sprint_right

Row 13 — jump
Row 14 — crawl
Row 15 — climb
Row 16 — swim
```

The exact organization can change, but it should remain consistent across characters.

---

# 56. Multi-Clip Data Convention

Animation data should describe the clip rather than relying on visual guesswork.

Example conceptual structure:

```text
animation:
    name: walk_down
    row: 5
    frames: 8
    fps: 10
    loop: true
    mirror: false
    anchor:
        x: ...
        y: ...
```

For an action:

```text
animation:
    name: harvest_chop
    row: 20
    frames: 7
    fps: 12
    loop: false
    anchor:
        x: ...
        y: ...
```

The actual data format should match the game's implementation.

---

# 57. Animation State Categories

Animations should be grouped conceptually.

```text
LOCOMOTION
    idle
    walk
    sprint
    jump
    crawl
    climb
    swim

ACTION
    carry
    harvest
    attack
    aim
    shoot
    use
    place
    interact
    pickup

REACTION
    hurt
    drown
    death
    wake
    shiver
    strain
```

This makes the animation system easier to reason about.

---

# 58. Animation Priority

When multiple animation states occur at the same time, higher-priority states should override lower-priority states.

Example:

```text
Death
 ↓
Drowning / Critical Reaction
 ↓
Hurt
 ↓
Action
 ↓
Jump / Fall
 ↓
Movement
 ↓
Idle
```

For example:

```text
Walk
 +
Hurt
 =
Hurt
```

rather than continuing the walk cycle normally.

---

# 59. Animation State Transitions

Transitions should be considered part of the animation design.

Important transitions include:

```text
Idle → Walk
Walk → Sprint
Walk → Jump
Jump → Land
Walk → Crawl
Walk → Climb
Land → Walk
Swim → Tread
Tread → Dive
Dive → Swim
Idle → Attack
Attack → Idle
```

Avoid designing animations as isolated clips.

Consider what pose the character starts in and what pose they end in.

---

# 60. Matching Start and End Poses

Looping animations should return to a compatible pose.

For example:

```text
Walk Frame 0
      ↓
Walk Cycle
      ↓
Walk Final Frame
      ↓
Walk Frame 0
```

The transition should not produce a visible jump.

Likewise, action animations should end in a pose that makes sense for the next state.

For example:

```text
Attack
  ↓
Recovery
  ↓
Idle
```

rather than:

```text
Attack
  ↓
Completely unrelated pose
  ↓
Idle
```

---

# 61. Motion Arcs

Hands, feet, weapons, and heads generally move through arcs rather than perfectly straight paths.

For example:

```text
        ●
      ●
    ●
  ●
●
```

Use motion arcs for:

- Weapon swings
- Tool swings
- Arm movement
- Head movement
- Jumping limbs
- Throwing
- Swimming strokes

Even a few pixels of intentional arc can greatly improve the animation.

---

# 62. Secondary Motion

Secondary motion should follow the primary movement.

Examples:

- Hair
- Clothing
- Backpack
- Straps
- Loose equipment
- Weapon straps

General rule:

```text
PRIMARY BODY
      ↓
SECONDARY MOTION
      ↓
SETTLE
```

Secondary motion should lag slightly behind the main body movement.

It should support the action rather than distract from it.

---

# 63. Action Readability

Every major action should contain at least one unmistakable pose.

Examples:

### Chop

Tool raised → impact

### Shoot

Aim → recoil

### Pickup

Reach → grab

### Place

Lower → release

### Climb

Grab → pull

### Jump

Crouch → launch

If the key action cannot be identified from a single frame, the pose needs more exaggeration.

---

# 64. Animation Smear Frames

Fast actions can use a brief smear frame.

Example:

```text
Wind-up
    ↓
   /
  /   ← smear
 /
    ↓
Impact
```

Smear frames can represent:

- Weapon movement
- Fast arm movement
- Fast body movement
- Rapid turns

Use sparingly.

At small pixel resolutions, a smear should remain readable rather than becoming visual noise.

---

# 65. Character Weight

Weight is communicated through:

- Timing
- Acceleration
- Deceleration
- Body compression
- Foot contact
- Center of gravity
- Follow-through

A heavy character/object generally:

- Takes longer to accelerate
- Takes longer to stop
- Has stronger impact
- Uses larger body movement

A light character/object generally:

- Moves faster
- Changes direction quickly
- Has less compression
- Has more floating movement

---

# 66. Water Weight

Water should reduce the sharpness of normal land movement.

Compared with land:

```text
LAND
Fast acceleration
Strong contact
Sharp stops

WATER
Slow acceleration
Reduced contact
Longer transitions
More drift
```

This should influence:

- Swimming
- Treading
- Diving
- Surfacing
- Drowning
- Floating

---

# 67. Climbing Weight

Climbing should show the character working against gravity.

Use:

- Pulling motion
- Body lift
- Arm tension
- Leg pushing
- Short pauses between pulls

The character should not simply move upward at a constant speed while cycling their limbs.

---

# 68. Death Animations and Gravity

Death animations should feel less controlled than normal animation.

As the character loses control:

- Posture collapses
- Limbs become less coordinated
- Center of gravity shifts
- Body follows gravity

The final frame should communicate a stable resting state.

---

# 69. Animation Quality-Control Process

For each new animation:

### Step 1 — Define the action

Write down exactly what the character is doing.

### Step 2 — Define the key poses

Usually 2–5 major poses.

### Step 3 — Define the center of gravity

Determine where the character's weight should be during each pose.

### Step 4 — Add anticipation

If the action requires force, prepare the movement.

### Step 5 — Add breakdowns

Determine how the character moves between key poses.

### Step 6 — Establish timing

Decide where frames should hold and where movement should accelerate.

### Step 7 — Add secondary motion

Add clothing, equipment, hair, or other delayed movement.

### Step 8 — Test at gameplay scale

Do not judge only while zoomed in.

### Step 9 — Test the silhouette

Temporarily view the character as a solid silhouette.

### Step 10 — Check transitions

Test the animation before and after other animation states.

---

# 70. Animation Review Checklist

## Poses

- [ ] Key poses are clearly defined
- [ ] Action reads from the silhouette
- [ ] Center of gravity makes sense
- [ ] Body proportions remain consistent
- [ ] Contact points are believable

## Motion

- [ ] Anticipation exists where appropriate
- [ ] Follow-through exists where appropriate
- [ ] Motion arcs are intentional
- [ ] Weight feels believable
- [ ] Acceleration/deceleration feels appropriate
- [ ] No foot sliding

## Timing

- [ ] Important poses receive enough screen time
- [ ] Fast actions are actually fast
- [ ] Heavy actions have appropriate impact
- [ ] Loops transition cleanly
- [ ] Recovery does not feel abrupt

## Locomotion

- [ ] Contact pose is clear
- [ ] Passing pose is clear
- [ ] Weight transfers correctly
- [ ] Arms and legs coordinate
- [ ] Feet remain grounded

## Water

- [ ] Character remains buoyant
- [ ] Motion is appropriately fluid
- [ ] Water surface interaction is believable
- [ ] Swimming differs from land locomotion
- [ ] Drowning differs from normal swimming

## Climbing

- [ ] Hands contact the surface
- [ ] Feet contact the surface where appropriate
- [ ] Pulling motion is visible
- [ ] Character appears to fight gravity
- [ ] Hang and climb states are distinct

## Actions

- [ ] Body participates in forceful actions
- [ ] Tool/weapon follows believable arcs
- [ ] Impact pose is readable
- [ ] Recovery returns naturally to locomotion

## Technical

- [ ] Clip has a defined name
- [ ] Frame count is defined
- [ ] Timing/FPS is defined
- [ ] Loop behavior is defined
- [ ] Direction is defined
- [ ] Hand/tool anchor is defined
- [ ] Mirroring behavior is defined
- [ ] Sprite-sheet row/region is defined

---

# 71. Recommended Animation Development Order

When creating a new character, prioritize animations in this order:

## Tier 1 — Core Locomotion

1. Idle
2. Walk
3. Sprint
4. Jump
5. Land

## Tier 2 — Environment

6. Crawl
7. Prone idle
8. Climb
9. Climb hang
10. Climb idle
11. Tread water
12. Prone swim
13. Underwater float

## Tier 3 — Core Actions

14. Tool carry
15. Harvest chop
16. Weapon swing
17. Aim + shoot
18. Use item
19. Interact
20. Pick up
21. Place

## Tier 4 — Reactions

22. Hurt
23. Drowning
24. Death on land
25. Death in water
26. Wake at bed

## Tier 5 — Optional States

27. Cold shiver
28. Crush strain
29. Dive down
30. Surface up

---

# 72. Core Principle

The existing pixel-art guide answers:

> **How should each frame be drawn?**

This document answers:

> **How should those frames move?**

The animation workflow should therefore be:

```text
CHARACTER DESIGN
      ↓
PIXEL-ART STYLE GUIDE
      ↓
KEY POSES
      ↓
BREAKDOWNS
      ↓
TIMING
      ↓
SECONDARY MOTION
      ↓
SPRITE SHEET
      ↓
ANIMATION DATA
      ↓
GAMEPLAY STATE
```

The goal is not to maximize frame count.

The goal is to make every frame contribute to the illusion of:

**weight, momentum, intention, and interaction.**

---

# 73. Golden Rules

> **Animate poses, not pixels.**

> **Strong key poses are more important than high frame counts.**

> **The center of gravity should make sense.**

> **Anticipation makes actions readable.**

> **Follow-through makes actions feel physical.**

> **Feet must feel planted when the character is grounded.**

> **Forceful actions should move the whole body.**

> **Water requires different body mechanics from land.**

> **Climbing should visibly fight gravity.**

> **Fast actions need fast timing.**

> **Heavy actions need weight and recovery.**

> **Use layers when body mechanics allow it; bake full-body frames when they do not.**

> **Define hand anchors instead of hard-coding held objects into every animation.**

> **Use mirroring to save work, but manually correct meaningful asymmetry.**

> **Design transitions, not just individual clips.**

> **Judge animations at gameplay scale, not only while zoomed in.**

> **If the action is not readable as a silhouette, improve the pose before adding detail.**

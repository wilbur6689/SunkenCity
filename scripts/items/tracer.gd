class_name Tracer
extends Node2D
## A tiny fast bullet streak for hitscan firearms (user request 2026-09-05):
## purely cosmetic — the hit was already resolved instantly by
## Interaction._fire_gun. Flies from the muzzle to the impact point at
## Constants.TRACER_SPEED_BLOCKS and frees itself there. Hosts spawn it and
## broadcast a "tracer" effect so clients draw the same streak.

var start: Vector2
var target: Vector2
var _dir: Vector2
var _travel := 0.0
var _length := 0.0

func setup(p_from: Vector2, p_to: Vector2) -> void:
	start = p_from
	target = p_to
	_dir = (target - start).normalized()
	_length = start.distance_to(target)
	global_position = start
	rotation = _dir.angle()

func _draw() -> void:
	# A 3 px streak: bright core with a dimmer tail behind it.
	draw_line(Vector2(-3, 0), Vector2(0, 0), Color(1.0, 0.85, 0.5, 0.55), 1.0)
	draw_line(Vector2(0, 0), Vector2(2, 0), Color(1.0, 0.95, 0.75), 1.0)

func _physics_process(delta: float) -> void:
	var step := Constants.TRACER_SPEED_BLOCKS * Constants.BLOCK_SIZE * delta
	_travel += step
	if _travel >= _length:
		queue_free()
		return
	global_position = start + _dir * _travel

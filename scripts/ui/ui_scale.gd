extends Node
## UI size scaling (user request 2026-09-02). Uses the engine-native
## content_scale_factor, which enlarges all UI with correct anchoring. That
## also enlarges the world, so the player camera divides its zoom by the
## total factor (see Player._apply_zoom) to keep the world the same size -
## only the UI grows. 1.0 = the current, smallest size; persisted to settings.cfg.
##
## Canvas 1920x1080 (2026-09-04, half-size-block plan Phase 0): the UI is still
## laid out in the 1280x720 / 640x360 design frames, so BASE_SCALE lifts it to
## the same on-screen size it had on the 1280x720 canvas. The engine renders at
## the window resolution regardless (canvas_items stretch), so this changes
## nothing visually - it moves the logical canvas to 1080p so later UI work can
## lower BASE_SCALE toward 1.0 and lay out at 1:1.

const SETTINGS_PATH := "user://settings.cfg"
const BASE_SCALE := 1.5 # 1920 / 1280: the design canvas -> logical canvas ratio
const MIN_SCALE := 1.0
const MAX_SCALE := 2.0

var scale: float = 1.0

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		scale = clampf(float(cfg.get_value("ui", "scale", 1.0)), MIN_SCALE, MAX_SCALE)
	_apply()

## Kept for the UI scenes that call it; content_scale_factor needs no per-root
## registration, so this is a no-op now.
func register(_root: Control) -> void:
	pass

func set_scale(s: float) -> void:
	scale = clampf(s, MIN_SCALE, MAX_SCALE)
	_apply()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ui", "scale", scale)
	cfg.save(SETTINGS_PATH)

## The factor actually applied to the window (design scale x user slider).
func content_scale() -> float:
	return BASE_SCALE * scale

func _apply() -> void:
	var w := get_window()
	if w != null:
		w.content_scale_factor = content_scale()

extends Node
## Audio director (autoload "Audio"): ambient beds + the music playlist.
##
## Ambient: two looping underwater beds crossfaded by context — inside a
## building (back-wall cells) vs open water — audible only while submerged.
## Music: adventure tracks rotate in safe bands; threat tracks take over in
## The Dark and The Crush. Tracks never repeat back-to-back and every track
## is followed by a stretch of silence (user request: looping playlist with
## quiet periods), so the city breathes instead of wall-to-wall music.

const MUSIC_POOLS := {
	# adventure01-03 replaced with new takes (2026-08-31; the originals were
	# cut for vibe). Sources live in docs/Examples/Audio/music — run
	# tools/convert_music.py after dropping new WAVs there.
	"adventure": [
		"res://assets/audio/music/adventure01.ogg",
		"res://assets/audio/music/adventure02.ogg",
		"res://assets/audio/music/adventure03.ogg",
		"res://assets/audio/music/adventure04.ogg",
	],
	"threat": [
		"res://assets/audio/music/threat01.ogg",
		"res://assets/audio/music/threat02.ogg",
		"res://assets/audio/music/threat03.ogg",
	],
}
const AMB_INSIDE := "res://assets/audio/ambient/underwater_inside.ogg"
const AMB_OUTSIDE := "res://assets/audio/ambient/underwater_outside.ogg"
const SILENT_DB := -60.0

var music: AudioStreamPlayer
var amb_inside: AudioStreamPlayer
var amb_outside: AudioStreamPlayer

## Headless runs (gate tests) skip actual playback: the mixer's playback
## objects otherwise show up as leaked instances at exit.
var _headless := DisplayServer.get_name() == "headless"
var _silence_left := 0.0     # countdown between tracks
var _play_left := 0.0        # remaining looped play time for the current track
var _time_up := false        # fading because the play stretch ended (not a pool switch)
var _amb_active := true      # ambient duty cycle (user request: long quiet spells)
var _amb_cycle := 0.0
var _current_pool := ""
var _last_track := ""
var _fading_out := false

func _ready() -> void:
	for bus_name: String in ["Music", "Ambient", "SFX"]:
		_ensure_bus(bus_name)
	_load_settings()
	for bus_name: String in volumes:
		_apply_volume(bus_name)
	music = _player("Music")
	music.finished.connect(_on_track_finished)
	amb_inside = _player("Ambient", AMB_INSIDE)
	amb_outside = _player("Ambient", AMB_OUTSIDE)
	_silence_left = randf_range(2.0, 6.0) # short lead-in on boot
	_amb_cycle = randf_range(Constants.AMBIENT_ON_MIN, Constants.AMBIENT_ON_MAX)

func _exit_tree() -> void:
	# Release the streams before engine teardown (quiets the
	# "resources still in use at exit" warnings in headless runs).
	for p: AudioStreamPlayer in [music, amb_inside, amb_outside]:
		if p != null:
			p.stop()
			p.stream = null

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")

func _player(bus_name: String, loop_path: String = "") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	add_child(p)
	if loop_path != "":
		var stream: AudioStreamOggVorbis = load(loop_path)
		stream.loop = true
		p.stream = stream
		p.volume_db = SILENT_DB
		if not _headless:
			p.play()
	return p

# --- Volume settings (Esc menu): a 0..1 slider per bus, applied ON TOP of
# the authored base levels so 100% = the tuned mix. Persisted per user in
# settings.cfg (not per character/world).
const SETTINGS_PATH := "user://settings.cfg"

var volumes: Dictionary = {"Music": 1.0, "Ambient": 1.0, "SFX": 1.0}

func _base_db(bus_name: String) -> float:
	match bus_name:
		"Music": return Constants.MUSIC_VOLUME_DB
		"Ambient": return Constants.AMBIENT_VOLUME_DB
	return 0.0

func set_volume(bus_name: String, linear: float) -> void:
	volumes[bus_name] = clampf(linear, 0.0, 1.0)
	_apply_volume(bus_name)

func volume(bus_name: String) -> float:
	return float(volumes.get(bus_name, 1.0))

func _apply_volume(bus_name: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	var v := volume(bus_name)
	AudioServer.set_bus_mute(idx, v <= 0.0)
	AudioServer.set_bus_volume_db(idx, _base_db(bus_name) + linear_to_db(maxf(v, 0.001)))

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus_name: String in volumes:
		volumes[bus_name] = clampf(float(cfg.get_value("audio", bus_name.to_lower(), 1.0)), 0.0, 1.0)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus_name: String in volumes:
		cfg.set_value("audio", bus_name.to_lower(), volumes[bus_name])
	cfg.save(SETTINGS_PATH)

## One line for the F3 overlay: what the music director is doing right now.
func debug_status() -> String:
	if music != null and music.playing:
		var title := _last_track.get_file().get_basename()
		return "%s (%s)%s" % [title, _current_pool,
			" · fading out" if _fading_out else " · %ds left" % int(ceil(maxf(_play_left, 0.0)))]
	return "silent · next track in %ds (%s)" % [int(ceil(maxf(_silence_left, 0.0))), desired_pool()]

const SFX_DIR := "res://assets/audio/sfx/"

## Positional one-shot from assets/audio/sfx. With variants > 1 a random
## numbered take plays (e.g. "wood_hit" -> wood_hit_1 / wood_hit_2).
func play_sfx(base: String, pos: Vector2, variants: int = 1, volume_db: float = 0.0) -> void:
	if _headless:
		return
	var sfx_name := base if variants <= 1 else "%s_%d" % [base, randi() % variants + 1]
	var path := SFX_DIR + sfx_name + ".wav"
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer2D.new()
	p.bus = "SFX"
	p.stream = load(path)
	p.volume_db = volume_db
	p.max_distance = 30 * Constants.BLOCK_SIZE
	p.pitch_scale = randf_range(0.95, 1.05)
	add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()

## The pool the current situation calls for: threat music in the deep
## danger bands, adventure everywhere else (title screen included).
func desired_pool() -> String:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null and World.is_ready():
		var band: String = World.band_at(World.cell_at(p.global_position))
		if band == "dark" or band == "crush":
			return "threat"
	return "adventure"

func _process(delta: float) -> void:
	_update_ambient(delta)
	_update_music(delta)

func _update_ambient(delta: float) -> void:
	# The beds are not wall-to-wall: they play for a stretch, then rest for
	# a long quiet spell (user request), on top of the submerged/inside gating.
	_amb_cycle -= delta
	if _amb_cycle <= 0.0:
		_amb_active = not _amb_active
		if _amb_active:
			_amb_cycle = randf_range(Constants.AMBIENT_ON_MIN, Constants.AMBIENT_ON_MAX)
		else:
			_amb_cycle = randf_range(Constants.AMBIENT_OFF_MIN, Constants.AMBIENT_OFF_MAX)
	var submerged := false
	var inside := false
	var p := get_tree().get_first_node_in_group("player")
	if p != null and World.is_ready():
		submerged = p.get("submerged") == true
		inside = World.has_back_wall_cell(World.cell_at(p.global_position))
	_fade(amb_inside, 0.0 if (_amb_active and submerged and inside) else SILENT_DB, delta)
	_fade(amb_outside, 0.0 if (_amb_active and submerged and not inside) else SILENT_DB, delta)

func _fade(p: AudioStreamPlayer, target_db: float, delta: float, rate: float = 40.0) -> void:
	p.volume_db = move_toward(p.volume_db, target_db, rate * delta)

func _update_music(delta: float) -> void:
	var want := desired_pool()
	if music.playing:
		# A track loops for a 3-5 minute stretch (user request), then fades
		# into the ~2 minute quiet spell.
		if not _fading_out:
			_play_left -= delta
			if _play_left <= 0.0:
				_fading_out = true
				_time_up = true
		if _fading_out or want != _current_pool:
			# The play stretch ended, or the situation changed: fade out,
			# then let the silence-then-next cycle bring in the right pool.
			_fading_out = true
			_fade(music, SILENT_DB, delta, 12.0)
			if music.volume_db <= SILENT_DB + 1.0:
				music.stop()
				_fading_out = false
				# A pool switch re-scores quickly; time-up rests properly.
				_silence_left = randf_range(Constants.MUSIC_SILENCE_MIN, Constants.MUSIC_SILENCE_MAX) \
						if _time_up else randf_range(2.0, 5.0)
				_time_up = false
		else:
			_fade(music, 0.0, delta, 8.0) # gentle fade-in at track start
		return
	_silence_left -= delta
	if _silence_left <= 0.0:
		_play_from(want)

func _play_from(pool_name: String) -> void:
	var pool: Array = MUSIC_POOLS[pool_name]
	var picks := pool.filter(func(t): return t != _last_track)
	if picks.is_empty(): # a one-track pool may repeat (the silence between hides it)
		picks = pool
	var track: String = picks[randi() % picks.size()]
	_last_track = track
	_current_pool = pool_name
	_play_left = randf_range(Constants.MUSIC_PLAY_MIN, Constants.MUSIC_PLAY_MAX)
	_time_up = false
	if _headless:
		_silence_left = 3600.0
		return
	var stream: AudioStreamOggVorbis = load(track)
	stream.loop = true # the play stretch outlasts the file; loop until time is up
	music.stream = stream
	music.volume_db = -14.0 # ramps to 0 in _update_music
	music.play()

func _on_track_finished() -> void:
	# Looping tracks normally never finish; if one does (loop flag lost),
	# fall back to the quiet period between tracks.
	_silence_left = randf_range(Constants.MUSIC_SILENCE_MIN, Constants.MUSIC_SILENCE_MAX)

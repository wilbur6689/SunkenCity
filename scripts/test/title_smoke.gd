extends Node
## Headless title-flow gate test: creating a new world + character from the
## pickers must actually stick — dive with a fresh seed and name, leave via
## the Esc path (save_and_exit_to_title's save half), and both must appear
## in a rebuilt title's lists.
## Run: godot --path . --headless res://scenes/test/title_smoke.tscn

const WNAME := "world_424242"
const CNAME := "__test_diver"

var failures: PackedStringArray = []
var checks := 0

func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok:   " if cond else "  FAIL: ") + msg)
	if not cond:
		failures.append(msg)

func _ready() -> void:
	_delete_saves()

	print("== A. fresh title: create rows on top (real saves may exist beside them)")
	SaveGame.pending_world = ""
	SaveGame.pending_character = ""
	SaveGame.pending_seed = -1
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	add_child(title)
	check(title.world_list != null and title.world_list.get_item_text(0) == "+ New world", "world list leads with '+ New world'")
	check(title.char_list.get_item_text(0) == "+ New character", "character list leads with '+ New character'")
	check(title.world_list.get_selected_items().size() == 1, "a row starts selected (DIVE always works)")
	var has_quit := false
	for c in title.find_children("*", "Button", true, false):
		if c.text == "QUIT":
			has_quit = true
	check(has_quit, "a QUIT button sits on the title screen (2026-09-01)")

	print("== B. create a new world + character")
	title.world_list.select(0) # the create rows
	title.char_list.select(0)
	title.seed_spin.value = 424242
	title.name_edit.text = "  __test_diver  "
	title._apply_selection()
	check(SaveGame.pending_seed == 424242, "new-world row hands the seed over")
	check(SaveGame.pending_character == CNAME, "typed name (trimmed) hands over")
	remove_child(title)
	title.queue_free()

	var city: Node2D = load("res://scenes/city/city.tscn").instantiate()
	add_child(city)
	var player: Player = city.get_node("Player")
	player.set_multiplayer_authority(2)
	check(city.seed_value == 424242 and city.world_name == WNAME, "city boots the picked seed")
	check(city.character_name == CNAME, "as the picked character")
	for i in 10:
		await get_tree().physics_frame

	print("== C. leaving banks both files")
	city.save_now() # the Esc path minus the scene change
	check(SaveGame.world_names().has(WNAME), "world file exists after leaving")
	check(SaveGame.character_names().has(CNAME), "character file exists after leaving")
	remove_child(city)
	city.queue_free()

	var title2: Control = load("res://scenes/ui/title.tscn").instantiate()
	add_child(title2)
	var world_row := -1
	var char_row := -1
	for i in title2.world_list.item_count:
		if title2.world_list.get_item_text(i) == WNAME:
			world_row = i
	for i in title2.char_list.item_count:
		if title2.char_list.get_item_text(i) == CNAME:
			char_row = i
	check(world_row > 0, "rebuilt title lists the new world")
	check(char_row > 0, "and the new character")
	check(title2.world_list.get_selected_items()[0] > 0, "a saved world is preselected for the next dive")

	print("== D. deleting saves from the title")
	title2.world_list.select(world_row)
	title2._delete_pressed("world")
	check(title2.world_del.text == "Really?", "delete arms and asks for a second click")
	title2._delete_pressed("world")
	check(not SaveGame.world_names().has(WNAME), "the second click deletes the world file")
	var crow := -1
	for i in title2.char_list.item_count:
		if title2.char_list.get_item_text(i) == CNAME:
			crow = i
	title2.char_list.select(crow)
	title2._delete_pressed("char")
	title2._delete_pressed("char")
	check(not SaveGame.character_names().has(CNAME), "characters delete the same way")
	check(title2.world_list.get_item_text(0) == "+ New world", "lists refresh after deleting")

	_delete_saves()
	print("\nTitle smoke: %d checks, %d failures" % [checks, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)

func _delete_saves() -> void:
	for p: String in [SaveGame.WORLD_DIR + WNAME + SaveGame.WORLD_EXT, SaveGame.CHAR_DIR + CNAME + SaveGame.CHAR_EXT]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

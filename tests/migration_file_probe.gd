extends SceneTree
## Copy-only check of a real historical save through the application's load/save path.
const WorldState = preload("res://scripts/world_state.gd")

func _initialize() -> void:
	_run.call_deferred()

func _progress(state: Dictionary) -> Dictionary:
	return {"island": state.island.duplicate(true), "host_water": state.players.host.can_water, "guest_water": state.players.guest.can_water, "day": state.day, "money": state.money, "crop": state.crop.duplicate(true), "tiles": state.deck_tiles.duplicate(), "structures": state.structures.duplicate(true), "chests": state.chests.duplicate(true), "host_bag": state.players.host.bag.duplicate(true), "guest_bag": state.players.guest.bag.duplicate(true), "entities": state.entities.duplicate(true)}

func _run() -> void:
	var arguments := {}
	for value in OS.get_cmdline_user_args():
		var pair := value.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			arguments[pair[0]] = pair[1]
	var source := str(arguments.get("source", ""))
	var destination := str(arguments.get("save-path", ""))
	var artifacts := ProjectSettings.globalize_path("res://artifacts/").replace("\\", "/").to_lower()
	var target := ProjectSettings.globalize_path(destination).replace("\\", "/").to_lower()
	if source.is_empty() or not target.begins_with(artifacts) or FileAccess.file_exists(destination):
		push_error("Migration probe requires a source and a fresh destination inside artifacts")
		quit(1)
		return
	var original := FileAccess.get_file_as_string(source)
	var wrapper: Variant = JSON.parse_string(original)
	var expected := WorldState.new()
	if not wrapper is Dictionary or not expected.restore(wrapper.get("state", {})):
		push_error("Historical source did not validate")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if DirAccess.copy_absolute(source, destination) != OK:
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	var success: bool = game._start("solo", true) and _progress(game.world.data) == _progress(expected.data)
	success = success and game._persist() and game._start("solo", true)
	success = success and _progress(game.world.data) == _progress(expected.data)
	var written: Variant = JSON.parse_string(FileAccess.get_file_as_string(destination))
	success = success and written is Dictionary and written.get("version") == 10 and FileAccess.get_file_as_string(source) == original
	game.mode = "menu"
	game.queue_free()
	await process_frame
	print("MIGRATION FILE ", "PASS" if success else "FAIL", ": v", int(wrapper.get("version", 0)), " source preserved; inventories, layouts, crop and resources survive v9 write/reload")
	quit(0 if success else 1)

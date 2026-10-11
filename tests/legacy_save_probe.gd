extends SceneTree

const Inventory = preload("res://scripts/inventory.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-path="):
			path = arg.trim_prefix("--save-path=")
	var allowed := ProjectSettings.globalize_path("res://artifacts/").replace("\\", "/")
	if path.is_empty() or not ProjectSettings.globalize_path(path).replace("\\", "/").begins_with(allowed):
		push_error("Legacy probe writes only a copied save under project artifacts")
		quit(1)
		return
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.save_path = path
	if not game._start("solo", true):
		push_error("Legacy copy could not be loaded")
		quit(1)
		return
	var migrated: Dictionary = game.world.data
	for player in ["host", "guest"]:
		var old_bag: Variant = original.state.players[player].bag
		var before: Dictionary = Inventory.totals(old_bag) if old_bag is Array else old_bag
		for item in before:
			if Inventory.count(migrated.players[player].bag, item) != int(before[item]):
				push_error("Legacy bag quantity changed: " + player + "/" + item)
				quit(1)
				return
	var stored: Dictionary = game.world.chest_totals()
	var previous_storage: Dictionary = original.state.get("storage", {})
	if original.state.has("chests"):
		for chest in original.state.chests.values():
			for item in Inventory.totals(chest.slots):
				previous_storage[item] = int(previous_storage.get(item, 0)) + Inventory.count(chest.slots, item)
	for item in previous_storage:
		if int(stored.get(item, 0)) != int(previous_storage[item]):
			push_error("Legacy chest quantity changed: " + item)
			quit(1)
			return
	for property in ["day", "money", "expansion"]:
		if int(migrated[property]) != int(original.state[property]):
			push_error("Legacy progress changed: " + property)
			quit(1)
			return
	var layout: Array = migrated.players.host.bag.duplicate(true)
	if not game._persist() or not game._start("solo", true) or game.world.data.players.host.bag != layout:
		push_error("Migrated copy failed save and reopen")
		quit(1)
		return
	print("LEGACY COPY PASS: day=", migrated.day, " host_items=", Inventory.totals(layout), " chests=", stored)
	game.mode = "menu"
	game.queue_free()
	await process_frame
	quit(0)

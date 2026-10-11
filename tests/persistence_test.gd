extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var folder := ProjectSettings.globalize_path("res://artifacts/persistence-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	game.save_path = folder.path_join("world.json")
	_expect(game._start("solo", false), "start isolated world")
	game.world.data.money = 11
	_expect(game._persist(), "save first world")
	game.world.data.money = 22
	_expect(game._persist(), "replace with backup")
	var valid_backup := FileAccess.get_file_as_string(game.save_path + ".bak")
	_expect(int(JSON.parse_string(valid_backup).state.money) == 11, "backup retains previous snapshot")
	_write(game.save_path, "corrupt primary")
	_expect(game._start("solo", true), "recover corrupt primary from backup")
	_expect(int(game.world.data.money) == 11, "backup values recovered")
	_expect(game._persist(), "first save after recovery")
	_expect(FileAccess.get_file_as_string(game.save_path + ".bak") == valid_backup, "valid backup never overwritten with corrupt primary")
	var malformed_wrapper: Dictionary = JSON.parse_string(valid_backup)
	for invalid_version in [{"bad": 1}, [2]]:
		malformed_wrapper.version = invalid_version
		_write(game.save_path, JSON.stringify(malformed_wrapper))
		_expect(game._start("solo", true) and int(game.world.data.money) == 11, "malformed wrapper version falls back to valid backup")
	_expect(game._persist(), "restore valid primary after malformed wrapper recovery")
	_expect(DirAccess.remove_absolute(game.save_path) == OK, "remove test-only primary")
	_expect(game._start("solo", true), "continue when only backup exists")
	_expect(int(game.world.data.money) == 11, "backup-only continuation keeps progress")
	_expect(game._persist(), "restore primary after backup-only continuation")
	_write(game.save_path, "corrupt old primary")
	_expect(game._backup_before_new(), "archive both files before replacing a damaged world")
	_expect(game._start("solo", false), "start replacement world")
	_expect(game._persist(), "save replacement world")
	var preserved_valid_world := false
	var preserved_bad_original := false
	for filename in DirAccess.get_files_at(folder):
		if filename.begins_with("world.json.before-new-"):
			var archived := FileAccess.get_file_as_string(folder.path_join(filename))
			preserved_valid_world = preserved_valid_world or archived == valid_backup
			preserved_bad_original = preserved_bad_original or archived == "corrupt old primary"
	_expect(preserved_valid_world, "new world preserves old world's only valid recovery copy")
	_expect(preserved_bad_original, "new world also preserves old original for inspection")
	_write(game.save_path, "bad primary")
	_write(game.save_path + ".bak", "bad backup")
	_expect(not game._start("solo", true), "refuse two invalid saves")
	_expect(FileAccess.get_file_as_string(game.save_path) == "bad primary", "failed load does not overwrite player file")
	game._start("solo", false)
	preload("res://scripts/navigation.gd").stroke(game.world.data.navigation, "host", Vector2(0.3, -0.7))
	game.world.tick(0.123456789)
	var travel: Dictionary = game.world.data.navigation.duplicate(true)
	_expect(game._persist(), "save fractional sailing coordinates and paddle impulse")
	_expect(game._start("solo", true), "reload fractional sailing world")
	var same_travel: bool = bool(game.world.data.navigation.anchored) == bool(travel.anchored)
	for field in travel:
		if field != "anchored":
			same_travel = same_travel and absf(float(game.world.data.navigation[field]) - float(travel[field])) < 1.0e-10
	_expect(same_travel, "sailing position impulse distance and cooldown survive JSON within 1e-10 simulation units")
	game.mode = "menu"
	game.queue_free()
	await process_frame
	print("PERSISTENCE TESTS: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL persistence: " + description)

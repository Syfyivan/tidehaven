extends "res://tests/island_ui_checks.gd"
## Arrange two real seasonal pots; exercise selected tools through pointer input.
const Gardens = preload("res://scripts/gardens.gd")
const POT_A := Vector2(416, 352)
const POT_B := Vector2(544, 352)

func _run() -> void:
	evidence = (OS.get_environment("TIDEHAVEN_TEST_ROOT") if not OS.get_environment("TIDEHAVEN_TEST_ROOT").is_empty() else ProjectSettings.globalize_path("res://artifacts")).path_join("planter-interaction-") + str(Time.get_unix_time_from_system()).replace(".", "-")
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	root.add_child(main)
	main.save_path = evidence.path_join("world.json")
	main.automated = true
	create_timer(60).timeout.connect(func():
		if not finished:
			printerr("FAIL planter interaction timeout")
			quit(1))
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	_check(main.mode == "solo", "normal title opens isolated solo world")
	if main.mode != "solo":
		finished = true
		quit(1)
		return
	main.set_physics_process(false)
	for size in [Vector2i(960, 600), Vector2i(1280, 800)]:
		root.size = size
		main.world.data.day = 28
		main.world.data.gardens = Gardens.create()
		for id: String in ["planter_a", "planter_b"]:
			main.world.data.structures[id] = main.world._new_structure(id, "garden", POT_A if id == "planter_a" else POT_B)
			Gardens.add_planter(main.world.data, id)
			var crop: Dictionary = main.world.data.gardens.planters[id]
			crop.crop = "seed"
			crop.growth = 2
			crop.watered = true
		# Use the same day transition as normal sleep, rather than marking dead by hand.
		main.world._advance_day()
		var p: Dictionary = _player()
		p.area = "deck"
		p.room = ""
		p.x = 480
		p.y = 352
		p.bag = Inventory.empty_slots(12)
		p.bag[0] = {"item": "scythe", "count": 1}
		p.bag[1] = {"item": "summer_seed", "count": 2}
		p.bag[2] = {"item": "watering_can", "count": 1}
		p.can_water = 20
		await _tap(KEY_H)
		await _settle()
		var plots: Dictionary = main.world.data.gardens.planters
		_check(plots.planter_a.dead and plots.planter_b.dead, "both uncovered spring crops die at actual summer transition")
		await _click(main.hud.slots[0].button.get_global_rect().get_center())
		_check(main.active_tool == "scythe" and plots.planter_a.dead, "clicking scythe only equips without clearing")
		var before_bag: Array = p.bag.duplicate(true)
		var other: Dictionary = plots.planter_b.duplicate(true)
		await _click(_world_point(POT_A, "deck"))
		_check(plots.planter_a.crop == "" and not plots.planter_a.dead, "selected scythe world click clears dead planter")
		_check(plots.planter_b == other and p.bag == before_bag, "only clicked pot clears with no invented harvest or consumed tool")
		await _click(main.hud.slots[1].button.get_global_rect().get_center())
		_check(main.active_tool == "plant" and main.active_seed == "summer_seed", "one click selects the actual summer seed")
		await _click(_world_point(POT_A, "deck"))
		_check(plots.planter_a.crop == "summer_seed" and Inventory.count(p.bag, "summer_seed") == 1, "cleared pot replants one selected seed")
		await _click(main.hud.slots[2].button.get_global_rect().get_center())
		await _click(_world_point(POT_A, "deck"))
		_check(plots.planter_a.watered and p.can_water == 19, "replanted pot waters through the selected can")
		await _click(main.hud.slots[0].button.get_global_rect().get_center())
		var planted: Dictionary = plots.planter_a.duplicate(true)
		await _click(_world_point(POT_A, "deck"))
		_check(plots.planter_a == planted and plots.planter_b == other, "scythe never clears a living crop or neighboring pot")
		await _capture("replanted-%d.png" % size.x)
	# Host-side reject path: a real hand-picked resource is also an obstruction.
	var mushrooms: Array = IslandMap.forest_nodes().values().filter(func(node: Dictionary): return node.kind == "mushroom")
	_check(not mushrooms.is_empty(), "forest has real hand-picked mushroom nodes")
	if not mushrooms.is_empty():
		var node: Dictionary = mushrooms[0]
		var p: Dictionary = _player()
		p.area = "island"
		p.room = ""
		p.x = node.x - 24
		p.y = node.y
		Inventory.add(p.bag, "hoe", 1)
		var point := Vector2(node.x, node.y)
		_check(IslandMap.tillable(point) and Farming.obstruction(main.world.data, point).get("id") == node.id, "actual mushroom occupies tillable grass")
		var before: Dictionary = main.world.snapshot()
		var message: String = main.world.action("host", "till", {"x": point.x, "y": point.y})
		_check(message == "先徒手采摘林菇，再锄地。", "hand-picked obstruction returns a valid instruction without indexing a nonexistent tool")
		_check(main.world.snapshot() == before, "blocked till preserves all inventory, resource and soil state")
	finished = true
	print("PLANTER INTERACTION: %d checks, %d failures; %s" % [checks, failures, evidence])
	quit(0 if failures == 0 else 1)

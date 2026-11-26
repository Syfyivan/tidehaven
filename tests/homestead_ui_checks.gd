extends "res://tests/island_ui_checks.gd"
const Town = preload("res://scripts/island_town.gd")

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/homestead-ui-%d" % Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world.json")
	root.add_child(main)
	main.automated = true
	create_timer(100).timeout.connect(func():
		if not finished:
			printerr("FAIL homestead UI deadline")
			quit(1))
	await _settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	_check(main.mode == "solo", "actual title starts isolated world")
	main.world.data.minute = 720.0
	main.world.data.chart.visited = true
	var route_count:=IslandMap.town_streets().size()
	var coast: Vector2 = Archipelago.island_position(main.world.data.chart)
	main.world.data.navigation.x = coast.x
	main.world.data.navigation.y = coast.y
	main.world.data.navigation.anchored = true
	preload("res://scripts/rooms.gd")._arrive(main.world.data,_player(),"townhall",Town.position("xu_an",720)+Vector2(0,30))
	await _settle()
	for shape in [Vector2i(960, 600), Vector2i(1280, 800)]:
		root.size = shape
		await _settle()
		await _click(_world_point(Town.position("xu_an", main.world.data.minute), "room"))
		_check(main.dialogue_ui.visible and main.dialogue_ui.choice_button.visible, "click mayor opens rental choice at " + str(shape.x))
		_check(not main.world.data.island.homestead.rented, "opening conversation alone does not rent")
		_check(main.dialogue_ui.body.get_line_count() <= 4, "mayor text fits above the dialogue choice")
		await _capture("mayor-%d.png" % shape.x)
		await _tap(KEY_ESCAPE)
	await _click(_world_point(Town.position("xu_an", main.world.data.minute), "room"))
	await _click(main.dialogue_ui.choice_button.get_global_rect().get_center())
	_check(main.world.data.island.homestead.rented and main.dialogue_ui.visible, "dialogue choice rents yard and keeps conversation")
	await _click(main.dialogue_ui.choice_button.get_global_rect().get_center())
	_check(Inventory.count(_player().bag, "hoe") == 1 and Inventory.count(_player().bag, "watering_can") == 1 and Inventory.count(_player().bag, "seed") == 6, "second dialogue choice actually delivers supplies")
	_check(main.dialogue_ui.choice_button.text.begins_with("租下北街旧店") and not main.dialogue_ui.choice_buttons.any(func(b:Button):return "领取" in b.text), "claimed gift advances to optional shop rental without repeating gift")
	_check(main.dialogue_ui.body.get_line_count() <= 4, "gift dialogue stays inside text area")
	await _capture("gift.png")
	await _tap(KEY_ESCAPE)
	_fixture_player("island", IslandMap.YARD_GATE + Vector2(50, 0))
	await _settle()
	_check(IslandMap.town_streets().size() == route_count, "rendered bridges do not append to shared map routes")
	await _capture("yard-gate.png")
	await _tap(KEY_M)
	_check(main.island_atlas.visible, "actual M opens island map")
	await _capture("island-map.png")
	await _click(main.island_atlas.region_buttons.harbor.get_global_rect().get_center())
	await _capture("town-map.png")
	await _tap(KEY_ESCAPE)
	# Select one naturally empty square. No clearing quota or pre-tilled field.
	var cell := Vector2.ZERO
	for y in range(55, 60):
		for x in range(63, 68):
			var at := Vector2(x + 0.5, y + 0.5) * 32
			if IslandMap.tillable(at) and Farming.obstruction(main.world.data, at).is_empty():
				cell = at
	_fixture_player("island", cell + Vector2(0, 28))
	_player().can_water = 20 # Filled-can UI fixture; normal fill is covered by the playthrough.
	await _settle()
	for item in ["hoe", "seed", "watering_can"]:
		main._update_hud()
		await _settle()
		for index in _player().bag.size():
			if _player().bag[index].get("item", "") == item:
				await _click(main.hud.slots[index].button.get_global_rect().get_center())
				break
		_check(Farming.held_item(main.active_tool,main.active_seed)==item,"actual toolbar equips "+item)
		await _click(_world_point(cell, "island"))
	var key := Farming.plot_key(cell)
	_check(main.world.data.island.plots.has(key) and main.world.data.island.plots[key].crop == "seed" and main.world.data.island.plots[key].watered, "bag tools directly till sow and water in rented yard")
	await _capture("yard-planting.png")
	var before: Dictionary = main.world.data.island.duplicate(true)
	await _tap(KEY_ESCAPE)
	await _click(main.return_title_button.get_global_rect().get_center())
	_check(main.mode == "menu", "pause saves and returns to title")
	await _click(main.continue_button.get_global_rect().get_center())
	_check(main.mode == "solo" and main.world.data.island == before, "normal Continue retains lease gift flags and planted cell")
	await _capture("yard-continued.png")
	finished = true
	print("HOMESTEAD UI: %d checks, %d failures; evidence: %s" % [checks, failures, evidence])
	quit(0 if failures == 0 else 1)

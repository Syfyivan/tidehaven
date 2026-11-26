extends "res://tests/island_ui_checks.gd"
## Controlled visual arrangements, actual mouse/keyboard actions, isolated save.
const Art = preload("res://scripts/art_catalog.gd")

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/coastal-ui-%d" % int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world.json")
	root.add_child(main)
	main.save_path = evidence.path_join("world.json")
	main.automated = true
	create_timer(60).timeout.connect(func():
		if not finished:
			printerr("FAIL coastal input check timed out")
			quit(1))
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	main.set_physics_process(false)
	for shape in [Vector2i(1280, 800), Vector2i(960, 600)]:
		root.size = shape
		main.world.data.structures = {"bedroll_0": {"id": "bedroll_0", "kind": "bedroll", "x": 416.0, "y": 224.0, "remaining": 0.0, "output": ""}}
		_fixture_player("deck", Vector2(456, 244))
		main.world.data.elapsed = 8.0
		main.toast_clock = 0
		await _settle()
		await _capture("bedroll-%d.png" % shape.x)
		for notice in ["已放好，物品和进度都保留。", "材料不足，先去收集木材。"]:
			main._toast(notice)
			await _settle()
			var ink: Color = main.status.get_theme_color("font_color")
			_check(main.status.text == notice and ink.get_luminance() < 0.4, "success/error toast uses readable dark ink on the warm paper surface")
		await _capture("notice-%d.png" % shape.x)
		await _facility_click_checks()
		_fixture_player("deck", Vector2(440, 264))
		await _settle()
		await _click(_world_point(Vector2(416, 224), "deck"), MOUSE_BUTTON_RIGHT)
		await _choose_context("relocate")
		await _move_mouse(_world_point(Vector2(480, 224), "deck"))
		await _settle()
		_check(main.view.placement.get("kind", "") == "bedroll" and main.view.placement.get("valid", false), "actual nearby move action offers the sleeping bag at its new cell")
		await _capture("bedroll-preview-%d.png" % shape.x)
		await _click(_world_point(Vector2(480, 224), "deck"))
		_check(main.relocation.is_empty() and main.world.data.structures.bedroll_0.x == 480.0, "real placement click moves the same sleeping bag without replacing its identity")
		var contents := Inventory.empty_slots(16)
		Inventory.add(contents, "wood", 7)
		main.world.data.chests = {"chest_0": {"id": "chest_0", "name": "储物木箱", "x": 544.0, "y": 288.0, "slots": contents}}
		_fixture_player("deck", Vector2(504, 288))
		await _click(_world_point(Vector2(544, 288), "deck"))
		_check(main.inventory_ui.visible and main.view.open_chest_id == "chest_0", "opening inventory selects the same chest's open-lid art")
		await _capture("chest-open-%d.png" % shape.x)
		await _tap(KEY_ESCAPE)
		_check(main.view.open_chest_id.is_empty() and Inventory.count(contents, "wood") == 7, "closing lid leaves actual chest contents untouched")
		_fixture_player("island", Vector2(355, 402))
		await _settle()
		await _capture("camp-%d.png" % shape.x)
	await _processing_target_checks()
	main.set_physics_process(true)
	await _town_input_checks()
	main.set_physics_process(false)
	if main._modal_open():
		await _tap(KEY_ESCAPE)
	# Town fixtures move directly ashore without moving the real raft. Restore a
	# valid deck location before persistence so this tests real v10 save rules.
	_fixture_player("deck", Vector2(480, 288))
	var saved_bag: Array = _player().bag.duplicate(true)
	var saved_structures: Dictionary = main.world.data.structures.duplicate(true)
	var saved_chests: Dictionary = main.world.data.chests.duplicate(true)
	await _tap(KEY_ESCAPE)
	await _click(main.return_title_button.get_global_rect().get_center())
	_check(main.mode == "menu" and not main.continue_button.disabled, "real save-and-title input writes the isolated world")
	await _click(main.continue_button.get_global_rect().get_center())
	_check(main.mode == "solo" and _player().bag == saved_bag and main.world.data.structures == saved_structures and main.world.data.chests == saved_chests, "continue restores exact ordered bag, relocated facilities and chest contents")
	await _capture("continued.png")
	finished = true
	print("COASTAL UI: %d checks, %d failures; evidence: %s" % [checks, failures, evidence])
	quit(0 if failures == 0 else 1)

extends "res://tests/island_ui_checks.gd"
const Recipes=preload("res://scripts/recipes.gd")

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/workbench-ui-%d" % int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	root.add_child(main)
	main.save_path = evidence.path_join("world.json")
	main.automated = true
	create_timer(60).timeout.connect(func():
		if not finished:
			printerr("FAIL workbench UI timed out")
			quit(1))
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	main.set_physics_process(false)
	for shape in [Vector2i(1280, 800), Vector2i(960, 600)]:
		root.size = shape
		main.world.data.structures = {"bedroll_0": main.world._new_structure("bedroll_0", "bedroll", Vector2(416, 224))}
		main.world.data.chests = {}
		_fixture_player("deck", Vector2(480, 288))
		_player().bag = Inventory.empty_slots(12)
		for item in ["wood", "scrap", "rope", "plastic", "ingot"]:
			Inventory.add(_player().bag, item, 20)
		await _settle()
		await _tap(KEY_C)
		await _recipe("fins", "exploration")
		_check(main.crafting_ui.make_button.disabled and main.crafting_ui.make_button.text.contains("工作台"), "sufficient materials without a station show the missing workbench")
		await _capture("locked-%d.png" % shape.x)
		await _recipe("workbench", "survival")
		_check(not main.crafting_ui.make_button.disabled and main.crafting_ui._category_label.text.contains("手工"), "workbench itself is visibly handcraftable")
		await _click(main.crafting_ui.make_button.get_global_rect().get_center())
		await _hold_crafted("workbench")
		var before: Array = _player().bag.duplicate(true)
		await _move_mouse(_world_point(Vector2(480, 224), "deck"))
		await _settle()
		_check(main.view.placement.get("valid", false), "workbench placement has a valid empty cell")
		await _capture("preview-%d.png" % shape.x)
		await _click(_world_point(Vector2(480, 224), "deck"), MOUSE_BUTTON_RIGHT)
		_check(main.placement_recipe.is_empty() and _player().bag == before, "right-click cancellation consumes no material")
		await _hold_crafted("workbench")
		await _click(_world_point(Vector2(480, 224), "deck"))
		_check(main.world.data.structures.has("structure_0") and Inventory.count(_player().bag, "wood") == 14, "real placement builds workbench and deducts exact wood")
		await _capture("built-%d.png" % shape.x)
		await _click(_world_point(Vector2(480, 224), "deck"))
		_check(main.crafting_ui.visible and main.crafting_ui.station_label.text.contains("已就位"), "clicking the physical station opens the same crafting page")
		await _recipe("fins", "exploration")
		_check(not main.crafting_ui.make_button.disabled, "nearby station makes upgrade available")
		await _capture("ready-%d.png" % shape.x)
		await _click(main.crafting_ui.make_button.get_global_rect().get_center())
		_check(Inventory.count(_player().bag, "fins") == 1 and Inventory.count(_player().bag, "ingot") == 18, "real craft button creates one upgrade with exact costs")
		# Simulate the partner moving the shared station while this menu stays open.
		main.world.data.structures.structure_0.x = 416.0
		main.world.data.structures.structure_0.y = 352.0
		await _settle()
		_check(main.crafting_ui.make_button.disabled, "open page refreshes after shared station moves out of range")
		await _tap(KEY_C)
		_fixture_player("deck", Vector2(453, 337))
		Inventory.add(_player().bag, "stone", 6)
		await _tap(KEY_C)
		await _recipe("furnace", "exploration")
		await _click(main.crafting_ui.make_button.get_global_rect().get_center())
		await _hold_crafted("furnace")
		before = _player().bag.duplicate(true)
		main.world.data.structures.structure_0.x = 480.0
		main.world.data.structures.structure_0.y = 224.0
		await _click(_world_point(Vector2(544, 352), "deck"))
		Inventory.remove(before,"furnace",1)
		_check(_player().bag == before and main.world.data.structures.size() == 3, "finished furnace places without re-crafting or needing station again")
		main.world.data.structures.structure_0.x = 416.0
		main.world.data.structures.structure_0.y = 352.0
		await _settle()
		await _click(_world_point(Vector2(416, 352), "deck"), MOUSE_BUTTON_RIGHT)
		await _choose_context("relocate")
		await _click(_world_point(Vector2(480, 224), "deck"))
		_check(main.world.data.structures.structure_0.x == 480.0 and main.world.data.structures.structure_0.y == 224.0, "context move uses the existing real placement controls")
		_fixture_player("deck",Vector2(480,288))
		for item:String in Recipes.ALL.cabin.costs:Inventory.add(_player().bag,item,Recipes.ALL.cabin.costs[item])
		await _tap(KEY_C)
		await _recipe("cabin","exploration")
		_check(main.crafting_ui._cost_rows.filter(func(r):return r.root.visible).size()==4,"all four cabin materials visible")
		await _capture("cabin-recipe-%d.png"%shape.x)
		await _click(main.crafting_ui.make_button.get_global_rect().get_center())
		_check(Inventory.count(_player().bag,"cabin")==1,"cabin craft places finished kit in bag")
		await _recipe("foundation","survival")
		_check(not main.crafting_ui.make_button.disabled,"foundation remains reachable and affordable")
		await _tap(KEY_C)
		_fixture_player("island", IslandState.DOCK)
		await _tap(KEY_C)
		await _recipe("fins", "exploration")
		_check(main.crafting_ui.make_button.disabled, "island page cannot borrow a raft workbench")
		await _tap(KEY_C)
	finished = true
	print("WORKBENCH UI: %d checks, %d failures; %s" % [checks, failures, evidence])
	quit(0 if failures == 0 else 1)

func _recipe(id: String, category: String) -> void:
	await _click(main.crafting_ui.category_buttons[category].get_global_rect().get_center())
	main.crafting_ui.recipe_scroll.ensure_control_visible(main.crafting_ui.recipe_buttons[id])
	await _settle()
	await _click(main.crafting_ui.recipe_buttons[id].get_global_rect().get_center())
	_check(main.crafting_ui.selected_recipe == id, "visible recipe selected: " + id)

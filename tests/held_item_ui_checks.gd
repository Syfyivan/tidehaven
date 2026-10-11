extends "res://tests/island_ui_checks.gd"
## Focused actual input coverage for the island inventory toolbar.
func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/held-item-ui-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world.json")
	root.add_child(main)
	main.save_path = evidence.path_join("world.json")
	main.automated = true
	create_timer(60).timeout.connect(func():
		if not finished:
			printerr("FAIL held item UI exceeded 60 seconds")
			quit(1))
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	await _toolbar_checks()
	await _farm_input_checks()
	await _held_item_edge_checks()
	finished = true
	print("HELD ITEM UI: %d checks, %d failures; evidence: %s" % [checks, failures, evidence])
	quit(0 if failures == 0 else 1)

func _held_item_edge_checks() -> void:
	_fixture_player("island", Vector2(528, 368))
	main.active_tool = "hook"
	main.world.data.day = 1
	main.world.data.island.plots.clear()
	_player().bag = Inventory.empty_slots(12)
	_player().bag[10] = {"item": "hoe", "count": 1}
	_player().bag[11] = {"item": "watering_can", "count": 1}
	_player().bag[8] = {"item": "seed", "count": 1}
	_player().bag[9] = {"item": "winter_seed", "count": 2}
	_player().can_water = 1
	await _settle()
	var first := Vector2(496, 336)
	var second := Vector2(528, 336)
	var first_key := Farming.plot_key(first)
	var second_key := Farming.plot_key(second)
	var before: Array = _player().bag.duplicate(true)
	await _click(main.hud.slots[10].button.get_global_rect().get_center())
	_check(main.active_tool == "till" and _player().bag == before and main.world.data.island.plots.is_empty(), "eleventh bag slot equips the actual hoe without spending or clicking through")
	await _click(_world_point(first, "island"))
	await _click(_world_point(second, "island"))
	_check(main.world.data.island.plots.size() == 2, "equipped late-slot hoe tills one cell per world click")
	await _click(main.hud.slots[9].button.get_global_rect().get_center())
	_check(main.active_tool == "plant" and main.active_seed == "winter_seed", "specific seed stack equips its own variety")
	await _click(_world_point(first, "island"))
	_check(main.world.data.island.plots[first_key].crop == "" and Inventory.count(_player().bag, "winter_seed") == 2, "out-of-season seed refuses without substitution or consumption")
	await _click(main.hud.slots[8].button.get_global_rect().get_center())
	await _click(_world_point(first, "island"))
	_check(main.world.data.island.plots[first_key].crop == "seed" and Inventory.count(_player().bag, "seed") == 0 and main.active_tool == "hook", "last selected seed plants exactly once and clears the held selection")
	await _click(_world_point(second, "island"))
	_check(main.world.data.island.plots[second_key].crop == "" and Inventory.count(_player().bag, "winter_seed") == 2, "empty spring stack does not silently switch to winter seeds")
	_check(_player().can_water == 1 and not main.world.data.island.plots[first_key].watered, "empty hands cannot auto-water a nearby seedling from the generic interaction list")
	await _click(main.hud.slots[11].button.get_global_rect().get_center())
	_check(main.active_tool == "water" and _player().can_water == 1, "twelfth bag slot equips the can without using water (tool=%s, water=%s)" % [main.active_tool, _player().can_water])
	await _click(_world_point(first, "island"))
	_check(main.world.data.island.plots[first_key].watered and _player().can_water == 0 and main.active_tool == "water" and main.hud.slots[11].count.text == "0/20", "watering spends one charge, shows zero and keeps the reusable can held")
	await _click(_world_point(second, "island"))
	_check(not main.world.data.island.plots[second_key].watered and _player().can_water == 0, "empty can cannot water another cell")
	await _tap(KEY_B)
	await _click(main.inventory_ui.sort_bag_button.get_global_rect().get_center())
	await _tap(KEY_B)
	_check(main.active_tool == "water" and _player().bag[11].is_empty(), "real backpack sorting moves the can while keeping the same item equipped")
	await _capture("held-item-island.png")
	var owned_hoe := Inventory.count(_player().bag, "hoe")
	await _tap(KEY_5)
	_check(main.active_tool == "till" and Inventory.count(_player().bag, "hoe") == owned_hoe, "legacy shortcut equips a carried hoe without spending it")
	# A host snapshot or inventory transfer can remove a held item; refresh must drop it.
	Inventory.remove(_player().bag, "hoe", 1)
	await _settle()
	_check(main.active_tool == "hook", "held tool removed from the personal bag clears selection")
	await _tap(KEY_5)
	_check(main.active_tool == "hook", "shortcut cannot equip an absent hoe")
	await _tap(KEY_N)
	_check(main.active_seed == "winter_seed" and main.active_tool == "plant", "N cycles only among actually carried seed varieties")
	await _click(main.hud.slots[11].button.get_global_rect().get_center())
	_check(main.active_tool == "hook" and not main.inventory_ui.visible, "empty toolbar slot puts down the item without opening a modal")
	await _tap(KEY_7)
	_fixture_player("deck", Vector2(480, 288))
	await _settle()
	_check(main.active_tool == "hook" and main.hud.quick_buttons.filter(func(button): return button.visible).size() == 9, "returning to deck clears island tool selection and restores the sea toolbar")

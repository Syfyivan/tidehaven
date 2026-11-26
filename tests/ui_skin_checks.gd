extends "res://tests/island_ui_checks.gd"
## Controlled UI states with real input; normal progression is tested separately.

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/ui-skin-%d" % int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world.json")
	root.add_child(main)
	main.save_path = evidence.path_join("world.json")
	main.automated = true
	create_timer(70).timeout.connect(func():
		if not finished:
			printerr("FAIL UI skin input check timed out")
			quit(1))
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	await _paddle_from_shore()
	main.set_physics_process(false)
	for window_size in [Vector2i(1280, 800), Vector2i(960, 600)]:
		root.size = window_size
		await _settle()
		await _inventory_sample(window_size.x)
		await _crafting_sample(window_size.x)
	_fixture_player("island", Vector2(528, 368))
	_player().bag = Inventory.empty_slots(12)
	_player().bag[11] = {"item": "watering_can", "count": 1}
	_player().can_water = 0
	main._update_hud()
	await _click(main.hud.slots[11].button.get_global_rect().get_center())
	_check(main.active_tool == "water" and main.hud.slots[11].count.text == "0/20", "last actual bag slot equips empty can and displays water, without farming tabs")
	await _capture("island-empty-can.png")
	finished = true
	print("UI SKIN: %d checks, %d failures; fixtures: %s" % [checks, failures, evidence])
	quit(0 if failures == 0 else 1)

func _paddle_from_shore() -> void:
	_fixture_player("deck", Vector2(413, 288))
	_player().bag = Inventory.empty_slots(12)
	Inventory.add(_player().bag, "paddle", 1)
	var nav: Dictionary = main.world.data.navigation
	var island_body: Vector2 = Archipelago.island_position(main.world.data.chart) + Archipelago.ISLAND_BODY_OFFSET
	nav.x = island_body.x - 215.0
	nav.y = island_body.y
	nav.anchored = false
	var start := Vector2(float(nav.x), float(nav.y))
	var stamina := float(_player().stamina)
	await _select_item("paddle")
	var origin: Vector2 = main.view.world_to_screen(Vector2(_player().x, _player().y), "deck")
	await _click(main.view.get_global_transform_with_canvas() * (origin + Vector2.LEFT * 180))
	await _settle(0.9)
	_check(float(nav.x) < start.x - 1.0 and float(_player().stamina) == stamina - 2, "real paddle input moves away from the island shore and charges one stroke")

func _inventory_sample(width: int) -> void:
	_fixture_player("deck", Vector2(496, 288))
	_player().bag = Inventory.empty_slots(12)
	_player().bag[0] = {"item": "wood", "count": 20}
	_player().bag[1] = {"item": "reinforced_hook", "count": 1}
	_player().bag[2] = {"item": "treasure", "count": 2}
	var contents: Array = Inventory.empty_slots(16)
	contents[0] = {"item": "wood", "count": 12}
	main.world.data.chests = {"chest_0": {"id": "chest_0", "name": "储物木箱", "x": 544.0, "y": 288.0, "slots": contents}}
	main._update_hud()
	await _tap(KEY_B)
	_check(main.inventory_ui.visible and main.inventory_ui.chest_id == "chest_0", "B opens adjacent chest with the bag")
	var bag: Array = main.inventory_ui.bag_buttons
	var chest: Array = main.inventory_ui.chest_buttons
	_check(bag.size() == 12 and chest.size() == 16 and chest.all(func(button): return button.is_visible_in_tree()), "all twelve personal and sixteen shared slots are visible")
	_check(bag[3].get_global_rect().end.x < chest[0].get_global_rect().position.x and chest[3].get_global_rect().end.x < main.inventory_ui.detail_icon.get_global_rect().position.x, "bag, chest and details occupy separate columns")
	await _move_mouse(bag[1].get_global_rect().get_center())
	await _settle()
	_check("强化" in main.inventory_ui.selection_note.text, "hover shows the actual long item name")
	await _capture("storage-%d.png" % width)
	await _click(bag[0].get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	_check(int(main.inventory_ui.selected.get("amount", 0)) == 10 and _player().bag[0].count == 20, "right click picks half without changing authoritative inventory")
	main._update_hud()
	await _capture("split-selected-%d.png" % width)
	await _click(chest[0].get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	_check(_player().bag[0].count == 19 and contents[0].count == 13, "right-click destination moves exactly one item")
	await _native_drag(bag[0].get_global_rect().get_center(),chest[1].get_global_rect().get_center())
	_check(_player().bag[0].is_empty() and contents[1].count == 19, "native drag keeps the entire remaining stack")
	await _click(main.inventory_ui.close_button.get_global_rect().get_center())
	_check(not main.inventory_ui.visible, "close control remains clickable at current window size")
	main.world.data.chests.clear()
	for index in 12:
		_player().bag[index] = {"item": "meal", "count": 20}
	_player().bag[0] = {"item": "treasure", "count": 20}
	await _tap(KEY_B)
	await _click(bag[0].get_global_rect().get_center())
	var before: Array = _player().bag.duplicate(true)
	await _click(main.inventory_ui.open_button.get_global_rect().get_center())
	_check(_player().bag == before, "opening treasure with full bag preserves every item")
	_check("剩余 0 格" in main.inventory_ui._capacity_note.text and not main.inventory_ui.chest_title.visible, "full capacity and personal-only layout are accurate")
	_check(not main.inventory_ui.feedback.text.is_empty(), "full-bag refusal remains visible")
	await _capture("full-bag-%d.png" % width)
	await _click(bag[1].get_global_rect().get_center())
	await _click(main.inventory_ui.discard_button.get_global_rect().get_center())
	_check(main.inventory_ui.discard_dialog.visible, "discard still requires the in-game confirmation")
	await _click(main.inventory_ui.discard_cancel_button.get_global_rect().get_center())
	_check(_player().bag == before and not main.inventory_ui.discard_dialog.visible, "cancel discard keeps all items")
	await _tap(KEY_B)

func _crafting_sample(width: int) -> void:
	_player().bag = Inventory.empty_slots(12)
	_player().bag[0] = {"item": "leaf", "count": 4}
	main._update_hud()
	await _tap(KEY_C)
	await _click(main.crafting_ui.category_buttons.survival.get_global_rect().get_center())
	await _click(main.crafting_ui.recipe_buttons.rope.get_global_rect().get_center())
	_check(not main.crafting_ui.make_button.disabled, "sufficient personal materials enable the craft button")
	await _click(main.crafting_ui.make_button.get_global_rect().get_center())
	_check(Inventory.count(_player().bag, "rope") == 1 and Inventory.count(_player().bag, "leaf") == 2, "new craft skin consumes and grants exact quantities once")
	await _click(main.crafting_ui.recipe_buttons.purifier.get_global_rect().get_center())
	_check(main.crafting_ui.make_button.disabled and main.crafting_ui.make_button.text == "材料不足", "missing materials disable crafting and explain why")
	var before: Array = _player().bag.duplicate(true)
	await _click(main.crafting_ui.make_button.get_global_rect().get_center())
	_check(_player().bag == before and main.placement_recipe.is_empty(), "disabled craft button neither spends nor enters placement")
	await _move_mouse(Vector2(8, 400))
	await _capture("craft-shortage-%d.png" % width)
	await _tap(KEY_C)
	_fixture_player("island", Vector2(528, 368))
	await _tap(KEY_C)
	_check("材料来自随身背包" in main.crafting_ui.materials_note.text and not "优先使用" in main.crafting_ui.materials_note.text, "island material-source caption never claims access to raft chests")
	await _click(main.crafting_ui.category_buttons.farming.get_global_rect().get_center())
	await _click(main.crafting_ui.recipe_buttons.watering_can.get_global_rect().get_center())
	await _capture("farm-recipes-%d.png" % width)
	await _tap(KEY_C)

func _native_drag(from:Vector2,to:Vector2)->void:
	await _move_mouse(from)
	var e:=InputEventMouseButton.new();e.position=from;e.global_position=from;e.button_index=MOUSE_BUTTON_LEFT;e.button_mask=MOUSE_BUTTON_MASK_LEFT;e.pressed=true
	root.push_input(e,true);await process_frame
	var previous:=from
	for i in range(1,9):
		var at:=from.lerp(to,i/8.0)
		var m:=InputEventMouseMotion.new();m.position=at;m.global_position=at;m.relative=at-previous;m.button_mask=MOUSE_BUTTON_MASK_LEFT
		root.push_input(m,true);previous=at;await _settle(0.04)
	e=InputEventMouseButton.new();e.position=to;e.global_position=to;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false
	root.push_input(e,true);await _settle()

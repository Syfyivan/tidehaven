extends "res://tests/ui_skin_checks.gd"
## Current menus, confirmations, maps and save/continue; isolated fixtures only.

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/ui-review-%d" % int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world.json")
	root.add_child(main)
	main.save_path = evidence.path_join("world.json")
	main.automated = true
	create_timer(110).timeout.connect(func():
		if not finished:
			printerr("FAIL UI REVIEW timed out")
			quit(1))
	await _settle()
	for shape in [Vector2i(960, 600), Vector2i(1280, 800)]:
		root.size = shape
		await _settle()
		await _click(_named_button(main.menu_actions, "联机游戏").get_global_rect().get_center())
		main.address.text = ""
		await _click(_named_button(main.coop_actions, "加入房间").get_global_rect().get_center())
		_check(main.menu_status.text == "请填写房主 IP。" and main.mode == "menu", "empty address keeps player on the menu with readable guidance")
		_check(main.menu_panel.get_global_rect().encloses(main.menu_status.get_global_rect()), "connection guidance stays inside its paper panel")
		await _capture("connection-%d.png" % shape.x)
		await _click(_named_button(main.coop_actions, "返回").get_global_rect().get_center())
	_check(main.menu_actions.visible and not main.coop_actions.visible, "co-op Back returns to solo choices")
	await _click(main.new_game_button.get_global_rect().get_center())
	main.set_physics_process(false)
	for shape in [Vector2i(960, 600), Vector2i(1280, 800)]:
		root.size = shape
		await _settle()
		await _inventory_sample(shape.x)
		await _crafting_sample(shape.x)
		await _discard_escape(shape.x)
	main.set_physics_process(true)
	await _chart_checks()
	_fixture_player("island", Vector2(528, 368))
	main.world.data.chart.visited = true
	main.world.data.navigation.anchored = true
	await _atlas_checks()
	await _context_checks()
	await _town_input_checks()
	main.set_physics_process(false)
	_fixture_player("deck", Vector2(480, 288))
	await _wide_and_fullscreen()
	for session_mode: String in ["solo", "host"]:
		main.mode = session_mode # Local UI fixture, not a network validation.
		await _tap(KEY_ESCAPE)
		_check(main.pause_open and main.pause_panel.get_global_rect().encloses(main.return_title_button.get_global_rect()), "pause actions stay inside panel in " + session_mode)
		if session_mode == "host":
			_check(main.room_pause_button.visible and not main.room_pause_button.get_global_rect().intersects(main.return_title_button.get_global_rect()), "host room pause and return buttons do not overlap")
		await _capture("pause-%s.png" % session_mode)
		await _tap(KEY_ESCAPE)
	main.mode = "solo"
	var saved_bag: Array = _player().bag.duplicate(true)
	await _tap(KEY_ESCAPE)
	await _click(main.return_title_button.get_global_rect().get_center())
	_check(main.mode == "menu" and not main.continue_button.disabled, "actual pause action saves and returns to title")
	await _click(main.continue_button.get_global_rect().get_center())
	main.set_physics_process(false)
	_check(main.mode == "solo" and _player().bag == saved_bag, "actual Continue restores the exact personal inventory")
	finished = true
	print("UI REVIEW: %d checks, %d failures; evidence: %s" % [checks, failures, evidence])
	quit(0 if failures == 0 else 1)

func _discard_escape(width: int) -> void:
	_fixture_player("deck", Vector2(480, 288))
	_player().bag = Inventory.empty_slots(12)
	_player().bag[0] = {"item": "wood", "count": 3}
	var before: Array = _player().bag.duplicate(true)
	main._update_hud()
	await _tap(KEY_B)
	await _click(main.inventory_ui.bag_buttons[0].get_global_rect().get_center())
	await _click(main.inventory_ui.discard_button.get_global_rect().get_center())
	_check(main.inventory_ui.discard_dialog.visible, "discard opens the confirmation before an item can be lost")
	await _capture("discard-%d.png" % width)
	await _tap(KEY_C)
	_check(main.inventory_ui.visible and main.inventory_ui.discard_dialog.visible and not main.crafting_ui.visible, "craft hotkey cannot bypass an open discard confirmation")
	# Reopen if an unfixed hotkey dismissed the modal so Escape is independent.
	if not main.inventory_ui.visible:
		main.crafting_ui.hide()
		await _tap(KEY_B)
		await _click(main.inventory_ui.bag_buttons[0].get_global_rect().get_center())
		await _click(main.inventory_ui.discard_button.get_global_rect().get_center())
	await _tap(KEY_ESCAPE)
	_check(main.inventory_ui.visible and not main.inventory_ui.discard_dialog.visible and _player().bag == before, "first Escape cancels only discard and keeps inventory/items")
	if main.inventory_ui.visible:
		await _tap(KEY_ESCAPE)
	_check(not main.inventory_ui.visible and not main.pause_open, "second Escape closes the bag without opening pause")

func _named_button(parent: Node, caption: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == caption:
			return child
	return null

func _wide_and_fullscreen() -> void:
	root.size = Vector2i(1440, 600)
	await _settle()
	await _tap(KEY_B)
	_check(main.inventory_ui.visible and root.get_visible_rect().encloses(main.inventory_ui.close_button.get_global_rect()), "wide window retains the visible inventory close target")
	await _capture("wide-inventory.png")
	await _click(main.inventory_ui.close_button.get_global_rect().get_center())
	_check(not main.inventory_ui.visible, "wide-window mouse coordinate closes the inventory")
	if DisplayServer.get_name() != "headless":
		await _tap(KEY_F11)
		await _settle(0.35)
		await _click(main.hud.bag_button.get_global_rect().get_center())
		_check(root.mode == Window.MODE_EXCLUSIVE_FULLSCREEN and main.inventory_ui.visible, "F11 full screen still routes the HUD bag click")
		await _capture("fullscreen-inventory.png")
		await _click(main.inventory_ui.close_button.get_global_rect().get_center())
		_check(not main.inventory_ui.visible, "fullscreen close uses the actual visible button")
		await _tap(KEY_F11)
	root.size = Vector2i(1280, 800)
	await _settle()

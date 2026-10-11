extends "res://tests/island_playthrough.gd"
## Real opening, no fixtures, grants, timer acceleration or direct actions.
func _run() -> void:
	for argument in ["save-path", "report", "evidence-dir"]:
		if not main.cli.has(argument):
			_fail("Missing isolated argument " + argument)
			return
	for version in range(1, 10):
		if ProjectSettings.globalize_path(main.save_path).to_lower() == ProjectSettings.globalize_path("user://world_v%d.json" % version).to_lower():
			_fail("Refusing real player save")
			return
	if FileAccess.file_exists(main.save_path):
		_fail("Require a fresh save")
		return
	await _settle(0.3)
	await _click(main.new_game_button.get_global_rect().get_center())
	if not _check(main.mode == "solo" and Inventory.total_count(_bag()) == 0, "Empty normal opening"):
		return
	await _tap(KEY_M)
	if not _check(not main.chart_ui.full_chart and main.chart_ui.destination_button.disabled, "No compass means local chart only"):
		return
	await _capture("01-local-chart.png")
	await _tap(KEY_M)
	if not (await _gather({"wood": 16, "leaf": 14, "plastic": 4, "scrap": 7})):
		return
	for index in 7:
		if not (await _craft_item("rope")):
			return
	for recipe in ["compass", "anchor", "paddle", "harpoon"]:
		if not (await _craft_item(recipe)):
			return
	await _tap(KEY_M)
	if not _check(main.chart_ui.full_chart and not main.chart_ui.destination_button.disabled, "Crafted personal compass unlocks full chart"):
		return
	await _click(main.chart_ui.destination_button.get_global_rect().get_center())
	await _capture("02-compass-chart.png")
	await _tap(KEY_M)
	await _tap(KEY_G)
	if not _check(_state().navigation.anchored and not _state().navigation.moored, "G deploys actual crafted anchor"):
		return
	await _tap(KEY_1)
	if not (await _walk(Vector2(550, 300), "dive edge")) or not (await _act("dive")):
		return
	if not (await _walk(Vector2(180, 95), "submerged timber")) or not (await _act("collect", "wood_00")):
		return
	if not _check(not _player().activity.is_empty() and float(_player().activity.duration) == 8.0, "Bare wood takes eight seconds"):
		return
	await _capture("03-bare-gather-progress.png")
	await _tap(KEY_P)
	if not _check(_player().activity.is_empty() and _state().entities.wood_00.active, "Right key cancels without consuming node"):
		return
	for id in ["stone_00", "stone_01", "stone_02"]:
		var node: Dictionary = _state().entities[id]
		if not (await _walk(Vector2(float(node.x), float(node.y)), "stone")) or not (await _act("mine", id)):
			return
		if not (await _until(func() -> bool: return not _state().entities[id].active, "bare stone takes real twelve seconds", 14)):
			return
	if not (await _walk(Vector2(120, 90), "buoy")) or not (await _act("surface")):
		return
	for recipe in ["axe", "pickaxe"]:
		if not (await _craft_item(recipe)):
			return
	if not (await _discard_seed_stack()):
		return
	await _tap(KEY_B)
	await _capture("04-crafted-tools.png")
	await _tap(KEY_B)
	if not (await _walk(Vector2(550, 300), "dive edge")) or not (await _act("dive")):
		return
	if not (await _walk(Vector2(180, 95), "wood with axe")) or not (await _act("collect", "wood_00")):
		return
	if not _check(float(_player().activity.duration) == 2.5, "Carried axe accelerates same wood node"):
		return
	if not (await _until(func() -> bool: return not _state().entities.wood_00.active, "axe collection", 4)):
		return
	if not (await _walk(Vector2(475, 285), "ore")) or not (await _act("mine", "ore_00")):
		return
	if not _check(float(_player().activity.duration) == 4.0, "Pickaxe reduces ore to four seconds"):
		return
	await _capture("05-pickaxe-progress.png")
	if not (await _until(func() -> bool: return _count("ore") == 1, "ore enters bag after mining", 6)):
		return
	await _tap(KEY_4)
	var before_fish := _count("fish")
	for attempt in 6:
		var fish: Dictionary = _state().entities.fish_02
		var target := Vector2(float(fish.x), float(fish.y))
		if not (await _walk(target + Vector2(-85, 0), "spear approach")):
			return
		await _click_world(Vector2(float(fish.x), float(fish.y)))
		await _settle(0.4)
		await _capture("06-fish-spear.png")
		if not (await _until(func() -> bool: return _player().activity.is_empty(), "spear flight and recovery", 3)):
			return
		if _count("fish") > before_fish:
			break
	if not _check(_count("fish") == before_fish + 1, "Directional spear hits moving fish"):
		return
	await _tap(KEY_1)
	if not (await _walk(Vector2(120, 90), "return buoy")) or not (await _act("surface")):
		return
	_record("Completed actual casting, compass crafting, bare mining, tool upgrades and directional spearfishing")
	expected_save = _saved_progress()
	if not (await _save_and_title()):
		return
	await _click(main.continue_button.get_global_rect().get_center())
	if not (await _until(func() -> bool: return main.mode == "solo", "continue", 3)):
		return
	restored_save = _saved_progress()
	if not _check(_same_progress(restored_save, expected_save), "Save and Continue preserve resources and tools"):
		return
	await _capture("07-returned.png")
	_record("Saved and continued with exact inventory and depleted resources")
	finished = true
	_release_keys()
	_write_report(true)
	get_tree().quit(0)


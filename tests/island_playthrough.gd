extends "res://tests/playthrough.gd"
## A separate normal-input journey, starting with an empty backpack.
const Archipelago = preload("res://scripts/archipelago.gd")
const IslandState = preload("res://scripts/island_state.gd")

const IslandMap = preload("res://scripts/island_map.gd")
const Farming = preload("res://scripts/farming.gd")
const IslandTown = preload("res://scripts/island_town.gd")

func _run() -> void:
	for argument in ["save-path", "report", "evidence-dir"]:
		if not main.cli.has(argument):
			_fail("Missing isolated argument: " + argument)
			return
	for version in range(1, 11):
		if ProjectSettings.globalize_path(main.save_path).to_lower() == ProjectSettings.globalize_path("user://world_v%d.json" % version).to_lower():
			_fail("Never use the player's default save")
			return
	if FileAccess.file_exists(main.save_path) or FileAccess.file_exists(str(main.save_path) + ".bak"):
		_fail("Use a new isolated save")
		return
	await _settle(0.3)
	await _click(main.new_game_button.get_global_rect().get_center())
	if not _check(_player().area == "deck" and Inventory.total_count(_bag()) == 0, "Empty bag through real title button"):
		return
	if not (await _gather({"wood": 27, "leaf": 14, "plastic": 10, "scrap": 6})):
		return
	for index in 7:
		if not (await _craft_item("rope")):
			return
	for recipe in ["paddle", "anchor", "scythe", "watering_can"]:
		if not (await _craft_item(recipe)):
			return
	if not (await _place("chest", Vector2(544, 352))):
		return
	if not (await _walk(Vector2(506, 319), "organize tools by crafted chest")) or not (await _act("open_chest")):
		return
	await _click(main.inventory_ui.sort_bag_button.get_global_rect().get_center())
	for item in ["leaf", "scrap"]:
		for index in _bag().size():
			if _bag()[index].get("item", "") != item:
				continue
			var slots: Array = _state().chests[main.inventory_ui.chest_id].slots
			for target in slots.size():
				if slots[target].is_empty():
					await _click(_slot_center(false, index))
					await _click(_slot_center(true, target))
					break
	await _tap(KEY_B)
	await _tap(KEY_G)
	await _tap(KEY_1)
	if not (await _walk(Vector2(550, 300), "dive edge")) or not (await _act("dive")):
		return
	for id in ["stone_00", "stone_01", "stone_02", "stone_03"]:
		var node: Dictionary = _state().entities[id]
		if not (await _walk(Vector2(node.x, node.y), "initial tool stone")) or not (await _act("mine", id)):
			return
		if not (await _until(func() -> bool: return not _state().entities[id].active, "bare mining requires twelve real seconds", 14)):
			return
	if not (await _walk(Vector2(120, 90), "return buoy")) or not (await _act("surface")):
		return
	for recipe in ["axe", "pickaxe", "hoe"]:
		if not (await _craft_item(recipe)):
			return
	if not (await _walk(Vector2(462, 236), "rest by bedroll")) or not (await _act("rest")):
		return
	if not (await _until(func() -> bool: return float(_player().stamina) > 95, "recover for paddling and farming", 22)):
		return
	await _tap(KEY_G)
	_record("Hooked supplies, mined four stone nodes with real twelve-second actions and crafted all island tools without grants")
	await _tap(KEY_3)
	var sailing_deadline := Time.get_ticks_msec() + 70000
	while not finished:
		var offset: Vector2 = Archipelago.island_position(_state().chart) - Vector2(float(_state().navigation.x), float(_state().navigation.y))
		if offset.length() <= 85:
			break
		if Time.get_ticks_msec() > sailing_deadline:
			_fail("Could not paddle to first island through normal input")
			return
		var origin: Vector2 = main.view.world_to_screen(Vector2(float(_player().x), float(_player().y)))
		await _click_world(origin + offset.normalized() * 175)
		await _settle(0.62)
	await _tap(KEY_G)
	if not _check(bool(_state().navigation.anchored) and Archipelago.within_docking_range(_state().chart, _state().navigation), "Sailed and anchored inside the actual docking radius"):
		return
	_record("Reached the island through real drift and any necessary paddle clicks, then anchored")
	await _tap(KEY_1)
	if not (await _walk(Vector2(555, 288), "island-facing raft edge")):
		return
	if not (await _capture("02-near-shore.png")) or not (await _menu_action("land")):
		return
	if not _check(_player().area == "island" and _state().chart.visited, "Landed through the visible nearby action menu"):
		return
	if not (await _capture("03-landed.png")):
		return
	for id in ["palm_0", "wood_1", "seeds_0", "stone_0", "palm_1"]:
		if not (await _gather_island(id)):
			return
	await _tap(KEY_M)
	if not _check(main.island_atlas.visible and not main.chart_ui.visible, "M opens the actual island atlas"):
		return
	await _click(main.island_atlas.region_buttons.harbor.get_global_rect().get_center())
	await _capture("04-island-region.png")
	await _tap(KEY_M)
	# A real boundary crossing proves the atlas represents walkable world space.
	for target in [Vector2(840, 280), Vector2(960, 280)]:
		if not (await _walk(target, "walk into next island page")):
			return
	if not _check(IslandMap.page_origin(Vector2(_player().x, _player().y)).x == 896, "Walking changes the page without teleport input"):
		return
	await _capture("05-next-page.png")
	var fiber_id := ""
	for id in IslandMap.nodes_near(Vector2(960, 280)):
		var node: Dictionary = IslandMap.node(id)
		if node.kind == "fiber" and node.x >= 896 and node.x < 1792 and node.y < 544:
			fiber_id = id
			break
	if not _check(not fiber_id.is_empty(), "Second page has natural fiber") or not (await _gather_island(fiber_id)):
		return
	# Variable hook catches can leave two partial wood stacks after crafting tools.
	# Use the player's visible sort control to make room for the canopy result.
	await _tap(KEY_B)
	await _click(main.inventory_ui.sort_bag_button.get_global_rect().get_center())
	await _tap(KEY_B)
	if not (await _craft_item("canopy")):
		return
	for target in [Vector2(960, 280), Vector2(640, 320), Vector2(640, 430)]:
		if not (await _walk(target, "return to freshwater")):
			return
	if not (await _menu_action("refill_can")):
		return
	if not _check(int(_player().can_water) == 20, "Watering can fills at the visible freshwater pool"):
		return
	if not (await _walk(Vector2(520, 365), "farm clearing")):
		return
	var first := Vector2(496, 336)
	var second := Vector2(528, 336)
	await _hold_item("hoe")
	await _click_world(first)
	await _click_world(second)
	if not _check(_state().island.plots.size() == 2, "Two separate clicks till exactly two cells"):
		return
	await _hold_item("canopy")
	await _click_world(second)
	await _hold_item("seed")
	var seed_before := _count("seed")
	await _click_world(first)
	await _click_world(second)
	if not _check(_count("seed") == seed_before - 2 and _state().island.plots["16,10"].covered, "Each cell consumes one seed and crafted canopy covers only its chosen cell"):
		return
	await _hold_item("watering_can")
	await _click_world(first)
	if not _check(int(_player().can_water) == 19 and _state().island.plots["15,10"].watered and not _state().island.plots["16,10"].watered, "Water click spends one charge only on its own cell"):
		return
	await _capture("06-planted-two-cells.png")
	await _settle(2.0)
	if not _check(int(_state().island.plots["15,10"].growth) == 0, "Waiting in real time cannot ripen an island crop"):
		return
	await _tap(KEY_1)
	for night in 4:
		if night > 0:
			if not (await _walk(Vector2(520, 365), "daily watering")):
				return
			await _hold_item("watering_can")
			await _click_world(first)
			await _tap(KEY_1)
		if not (await _walk(IslandState.CAMP, "island camp")):
			return
		var old_day := int(_state().day)
		if not (await _menu_action("sleep")):
			return
		if not _check(int(_state().day) == old_day + 1 and int(_state().island.plots["15,10"].growth) == night + 1 and int(_state().island.plots["16,10"].growth) == 0, "Normal camp sleep grows watered crop once and leaves dry covered crop unchanged"):
			return
	if not (await _walk(Vector2(520, 365), "harvest mature crop")):
		return
	await _capture("07-four-day-crop.png")
	var before_veg := _count("veg")
	await _click_world(first)
	if not _check(_count("veg") == before_veg + 2 and _state().island.plots["15,10"].crop == "" and _state().island.plots["16,10"].crop == "seed", "Harvest picks only the mature clicked cell after four watered nights"):
		return
	_record("Walked across island pages, gathered timed tool resources, crafted a canopy, planted two cells and harvested after four actual camp nights")
	if not (await _town_journey()):
		return
	expected_save = _saved_progress()
	if not (await _save_and_title()):
		return
	await _click(main.continue_button.get_global_rect().get_center())
	if not (await _until(func() -> bool: return main.mode == "solo", "Continue island farm", 3)):
		return
	restored_save = _saved_progress()
	if not _check(_player().area == "island" and Vector2(_player().x, _player().y).distance_to(Vector2(520, 365)) < 5, "Continue returns the island farmer to the saved field instead of resetting to the raft"):
		return
	if not _check(_same_progress(restored_save, expected_save), "Save/Continue preserves sparse farmland, personal can water and gathered resources"):
		return
	await _capture("08-resumed-farm.png")
	_record("Normal Save and Continue preserved the island journey exactly")
	_release_keys()
	finished = true
	if not _write_report(true):
		get_tree().quit(1)
		return
	print("ISLAND FARM PLAYTHROUGH PASS: %.2fs; %d hooked objects; no state grants or clock changes" % [_seconds(), hook_count])
	get_tree().quit(0)

func _town_journey() -> bool:
	for target in [Vector2(840, 280), Vector2(960, 280), Vector2(1344, 280), Vector2(1344, 480), Vector2(1088, 480)]:
		if not (await _walk(target, "walk from reclaimed field to the town market")):
			return false
	if not (await _until(func() -> bool: return IslandTown.open_at("lin_sui", _state().minute), "wait for normal market opening time", 25)):
		return false
	await _click_world(IslandMap.LANDMARKS.market.door)
	if not _check(main.dialogue_ui.visible and "林穗" in main.dialogue_ui.speaker.text, "Left click speaks with market owner without spending money"):
		return false
	await _capture("09-town-conversation.png")
	await _tap(KEY_ESCAPE)
	var before_money := int(_state().money)
	for index in 2:
		if not (await _town_menu("town_trade", "sell_veg")):
			return false
	if not _check(_count("veg") == 0 and int(_state().money) == before_money + 8, "Two real farm harvests sell for eight coins through the visible market menu"):
		return false
	var before_seed := _count("seed")
	if not (await _town_menu("town_trade", "buy_seed")):
		return false
	if not _check(_count("seed") == before_seed + 1 and int(_state().money) == before_money + 5, "Seasonal seed purchase uses exactly three earned coins"):
		return false
	for target in [Vector2(1344, 480), Vector2(1344, 280), Vector2(1840, 280)]:
		if not (await _walk(target, "town road to wild land")):
			return false
	var obstruction: Dictionary = {}
	for node: Dictionary in IslandMap.nodes_near(Vector2(2000, 280)).values():
		if str(node.id).begins_with("clear_2_0_") and node.kind == "fiber" and node.y < 350:
			obstruction = node
			break
	if not _check(not obstruction.is_empty(), "Natural uncultivated land contains real scythe-cleared grass"):
		return false
	var point := Vector2(obstruction.x, obstruction.y)
	if not (await _walk(point, "overgrown grass cell")):
		return false
	await _hold_item("hoe")
	var old_plots: int = _state().island.plots.size()
	await _click_world(point)
	if not _check(_state().island.plots.size() == old_plots, "Hoe cannot skip uncleared wild grass"):
		return false
	if not (await _gather_island(str(obstruction.id))):
		return false
	await _hold_item("hoe")
	await _click_world(point)
	await _hold_item("seed")
	await _click_world(point)
	await _hold_item("watering_can")
	await _click_world(point)
	if not _check(_state().island.plots.size() == old_plots + 1 and _state().island.plots[Farming.plot_key(point)].watered and _state().island.plots[Farming.plot_key(point)].crop == "seed", "Clear then hoe then sow then water creates exactly one new reclaimed plot"):
		return false
	await _capture("10-self-reclaimed-land.png")
	await _tap(KEY_1)
	for target in [Vector2(1840, 280), Vector2(1344, 280), Vector2(1344, 576), Vector2(1528, 576)]:
		if not (await _walk(target, "return to town bathhouse")):
			return false
	if not (await _until(func() -> bool: return IslandTown.open_at("tang_he", _state().minute), "wait for real bathhouse opening at ten", 45)):
		return false
	var money := int(_state().money)
	if not (await _town_menu("town_bath")):
		return false
	if not _check(_player().activity.get("kind") == "town_bath" and int(_state().money) == money, "Bath starts visibly and does not charge before completion"):
		return false
	await _capture("11-town-bath.png")
	if not (await _until(func() -> bool: return _player().activity.is_empty(), "eight real seconds of bathing", 10)):
		return false
	if not _check(int(_state().money) == money - 3, "Finished bathing charges only three coins"):
		return false
	for target in [Vector2(1344, 576), Vector2(1344, 280), Vector2(960, 280), Vector2(840, 280), Vector2(520, 365)]:
		if not (await _walk(target, "walk home to preserved farm")):
			return false
	_record("Walked into town, talked without spending, sold harvested crops, bought a seasonal seed, reclaimed wild grass into one planted cell and paid only after eight real bath seconds")
	return true

func _town_menu(verb: String, offer: String = "") -> bool:
	await _settle(0.18)
	var selected := -1
	for index in main.current_options.size():
		var option: Dictionary = main.current_options[index]
		if option.action == verb and (offer.is_empty() or option.args.get("offer") == offer):
			selected = index
			break
	if not _check(selected >= 0, "Town menu offers " + verb + ":" + offer):
		return false
	await _tap(KEY_P)
	if not _check(main.context_ui.visible, "P opens town services"):
		return false
	await _click(main.context_ui.buttons[selected].get_global_rect().get_center())
	return not finished

func _menu_action(verb: String) -> bool:
	await _settle(0.16)
	var index := -1
	for at in main.current_options.size():
		if str(main.current_options[at].action) == verb:
			index = at
			break
	if not _check(index >= 0, "Nearby menu offers " + verb):
		return false
	await _tap(KEY_P)
	if not _check(main.context_ui.visible and main.context_ui.buttons.size() > index, "P opens action menu"):
		return false
	await _click(main.context_ui.buttons[index].get_global_rect().get_center())
	return not finished

func _gather_island(id: String) -> bool:
	var resource: Dictionary = IslandMap.node(id)
	var at := Vector2(float(resource.x), float(resource.y))
	var before := _count(str(resource.item))
	if not (await _walk(at, "island resource " + id)):
		return false
	await _tap(KEY_1)
	await _click_world(at)
	if not _check(_player().activity.get("kind") == "island_gather", "Click starts timed island gathering: " + id):
		return false
	return await _until(func() -> bool: return _player().activity.is_empty() and _count(str(resource.item)) == before + int(resource.amount), "Real tool work completes " + id, float(resource.duration) + 2)

func _saved_progress() -> Dictionary:
	var result: Dictionary = super._saved_progress()
	result.chart = _state().chart.duplicate(true)
	result.island = _state().island.duplicate(true)
	result.can_water = int(_player().can_water)
	return result

func _walk_segment(target: Vector2, label: String) -> bool:
	if _player().area != "island":
		return await super._walk_segment(target, label)
	# Diagonal walking follows the convex shore; an x-first Manhattan route
	# can hit the northeastern beach before turning south toward the ore.
	var deadline := Time.get_ticks_msec() + 12000
	while not finished:
		var offset := target - Vector2(float(_player().x), float(_player().y))
		if absf(offset.x) < 3.5 and absf(offset.y) < 3.5:
			_release_keys()
			await _settle(0.12)
			return true
		if Time.get_ticks_msec() > deadline:
			_fail("Island walking stalled: " + label)
			return false
		for key in MOVE_KEYS:
			var down: bool = (key == KEY_D and offset.x >= 3.5) or (key == KEY_A and offset.x <= -3.5) or (key == KEY_S and offset.y >= 3.5) or (key == KEY_W and offset.y <= -3.5)
			if bool(held.get(key, false)) != down or Input.is_physical_key_pressed(key) != down:
				_send_key(key, down)
				held[key] = down
		await get_tree().physics_frame
	return false

func _hold_item(item: String) -> void:
	await _settle(0.16)
	for index in _bag().size():
		if _bag()[index].get("item", "") == item:
			var before: Array = _bag().duplicate(true)
			await _click(main.hud.slots[index].button.get_global_rect().get_center())
			_check(Farming.held_item(main.active_tool, main.active_seed) == item and _bag() == before, "Actual bag toolbar equips " + item + " without consuming it")
			return
	_fail("No carried item to equip: " + item)

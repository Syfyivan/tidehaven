extends SceneTree
## Real root scene and input routing. Fixtures arrange cases, never perform actions.
## godot --path <project> --script res://tests/island_ui_checks.gd
const MainScene: PackedScene = preload("res://main.tscn")
const Inventory = preload("res://scripts/inventory.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
const IslandState = preload("res://scripts/island_state.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const Farming = preload("res://scripts/farming.gd")
var main: Node
var checks: int = 0
var failures: int = 0
var finished: bool = false
var evidence: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/island-ui-checks-%d" % int(Time.get_unix_time_from_system() * 1000.0))
	var folder_error: Error = DirAccess.make_dir_recursive_absolute(evidence)
	if folder_error != OK:
		printerr("FAIL cannot create isolated test folder: ", error_string(folder_error))
		quit(1)
		return
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("fixture-world.json")
	root.add_child(main)
	# _ready has completed; no automated CLI flag or extra driver is installed.
	main.save_path = evidence.path_join("fixture-world.json")
	main.automated = true
	create_timer(90.0).timeout.connect(func() -> void:
		if not finished:
			printerr("FAIL ISLAND UI CHECKS exceeded 90 seconds")
			quit(1))
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	_check(main.mode == "solo" and not main.overlay.visible, "actual new-game button starts an isolated solo world")
	if main.mode != "solo":
		quit(1)
		return
	await _chart_checks()
	await _facility_click_checks()
	await _processing_target_checks()
	await _context_checks()
	await _hook_checks()
	await _multi_hook_checks()
	await _shore_occlusion_checks()
	await _mooring_checks()
	await _paddle_checks()
	await _toolbar_checks()
	await _island_checks()
	await _farm_input_checks()
	await _atlas_checks()
	await _page_input_checks()
	await _town_input_checks()
	finished = true
	print("ISLAND UI CHECKS: %d checks, %d failures; isolated save: %s" % [checks, failures, main.save_path])
	quit(0 if failures == 0 else 1)


func _chart_checks() -> void:
	Inventory.add(_player().bag, "compass", 1)
	main.world.data.chart.destination = ""
	await _tap(KEY_M)
	_check(main.chart_ui.visible and main.chart_ui.full_chart, "M opens the full chart through normal key routing when a compass is carried")
	var elapsed: float = float(main.world.data.elapsed)
	var navigation: Dictionary = main.world.data.navigation.duplicate(true)
	await _settle(0.32)
	_check(is_equal_approx(float(main.world.data.elapsed), elapsed) and main.world.data.navigation == navigation, "solo chart pauses both time and raft travel")
	var locked: Button = main.chart_ui.island_buttons["island_mist"]
	await _click(locked.get_global_rect().get_center())
	_check(main.chart_ui.selected_island == "island_mist" and main.chart_ui.title_label.text == "雾岬", "locked-island click shows its own details")
	_check(main.chart_ui.destination_button.disabled and "尚未开放" in str(main.chart_ui.status_label.text), "locked destination remains explicitly unavailable")
	await _click(main.chart_ui.destination_button.get_global_rect().get_center())
	_check(main.world.data.chart.destination == "" and main.world.data.navigation == navigation, "disabled locked destination does not change route or teleport the raft")
	await _click(main.chart_ui.island_buttons["island_home"].get_global_rect().get_center())
	_check(not main.chart_ui.destination_button.disabled, "first island can be selected as a destination")
	await _click(main.chart_ui.destination_button.get_global_rect().get_center())
	_check(main.world.data.chart.destination == "island_home" and main.world.data.navigation == navigation and _player().area == "deck", "setting the first-island marker only changes the marker")
	_check(_player().hook.is_empty(), "map button clicks do not pass through into world tools")
	await _tap(KEY_M)
	_check(not main.chart_ui.visible, "M closes the chart")
	await _settle(0.25)
	_check(float(main.world.data.elapsed) > elapsed and main.world.data.navigation != navigation, "closing the solo chart resumes time and drift")
	await _tap(KEY_M)
	await _click(main.chart_ui.close_button.get_global_rect().get_center())
	_check(not main.chart_ui.visible, "chart close button also uses the normal GUI path")


func _context_checks() -> void:
	_fixture_player("deck", Vector2(448, 224))
	_player().stamina = 35.0
	main.world.data.navigation.anchored = true
	await _settle()
	var day: int = int(main.world.data.day)
	await _click(_world_point(Vector2(416, 224), "deck"), MOUSE_BUTTON_RIGHT)
	_check(main.context_ui.visible, "right click opens nearby actions by the sleeping bag")
	var before_stamina: float = float(_player().stamina)
	await _choose_context("rest")
	await _settle(0.30)
	_check(not main.context_ui.visible and _player().resting and not _player().sleep_ready, "rest button closes the menu and rests without preparing sleep")
	_check(int(main.world.data.day) == day and float(_player().stamina) > before_stamina, "rest restores stamina while remaining in the same day")
	await _tap(KEY_P)
	_check(main.context_ui.visible, "P also opens the nearby-action menu")
	await _tap(KEY_P)
	_check(not main.context_ui.visible and int(main.world.data.day) == day, "P dismisses the menu without choosing an action")
	await _tap(KEY_P)
	await _choose_context("sleep")
	_check(int(main.world.data.day) == day + 1 and not _player().sleep_ready, "separate prepare-sleep button ends a solo day")
	_check(FileAccess.file_exists(main.save_path), "day-end save goes to the isolated fixture path")


func _facility_click_checks() -> void:
	_fixture_player("deck", Vector2(480, 288))
	main.world.data.navigation.anchored = true
	main.world.data.chests = {"chest_0": {"id": "chest_0", "name": "点击目标箱", "x": 544.0, "y": 288.0, "slots": Inventory.empty_slots(16)}}
	await _settle()
	await _click(_world_point(Vector2(544, 288), "deck"))
	_check(main.inventory_ui.visible and main.inventory_ui.chest_id == "chest_0", "clicking the chest itself from 64px away opens that chest rather than testing the actor's position")
	if main.inventory_ui.visible:
		await _tap(KEY_ESCAPE)
	main.world.data.chests = {}
	_fixture_player("deck", Vector2(448, 224))
	var day: int = int(main.world.data.day)
	await _settle()
	await _click(_world_point(Vector2(416, 224), "deck"))
	_check(_player().resting and not _player().sleep_ready and int(main.world.data.day) == day, "first left click on the sleeping bag rests without preparing the next day")
	await _click(_world_point(Vector2(416, 224), "deck"))
	_check(not _player().resting and not _player().sleep_ready and int(main.world.data.day) == day, "second left click on the sleeping bag wakes instead of ending the day")
	var selected_sleep: bool = false
	for _attempt: int in main.current_options.size() + 1:
		var option: Dictionary = main.current_options[int(main.selected_option)]
		if str(option.action) == "sleep":
			selected_sleep = true
			break
		await _tap(KEY_TAB)
	_check(selected_sleep, "Tab can select the explicit sleep option for the keyboard-fallback regression")
	# Avoid any facility hit, so this exercises O's safe fallback with sleep selected.
	await _move_mouse(_world_point(Vector2(780, 420), "drift"))
	_check(main.hovered_drift.is_empty(), "directional tools no longer expose a hovered drift lock")
	await _tap(KEY_O)
	_check(int(main.world.data.day) == day and not _player().sleep_ready, "O never ends the day even when the selected legacy option is sleep; the explicit menu remains required")


func _processing_target_checks() -> void:
	var saved_structures: Dictionary = main.world.data.structures.duplicate(true)
	_fixture_player("deck", Vector2(456, 270))
	main.world.data.structures = {
		"structure_0": {"id": "structure_0", "kind": "purifier", "x": 416.0, "y": 224.0, "remaining": 0.0, "output": "freshwater"},
		"structure_1": {"id": "structure_1", "kind": "grill", "x": 480.0, "y": 224.0, "remaining": 10.0, "output": "cooked_fish"},
	}
	var before_water: int = Inventory.count(_player().bag, "freshwater")
	await _settle()
	await _click(_world_point(Vector2(416, 224), "deck"))
	_check(Inventory.count(_player().bag, "freshwater") == before_water + 1 and main.world.data.structures.structure_0.output == "", "clicking the slightly farther finished purifier claims its water even while the nearer grill is working")
	_check(main.world.data.structures.structure_1.output == "cooked_fish" and float(main.world.data.structures.structure_1.remaining) > 0.0, "claiming the purifier does not collect or restart the nearby grill")
	main.world.data.structures = saved_structures


func _hook_checks() -> void:
	_fixture_player("deck", Vector2(480, 224))
	_player().bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	for drift: Dictionary in main.world.data.drift.values():
		drift.active = false
		drift.respawn = 999.0
	var id: String = str(main.world.data.drift.keys()[0])
	var target: Dictionary = main.world.data.drift[id]
	target.kind = "wood"
	target.x = 480.0
	target.y = 140.0
	target.active = true
	target.respawn = 0.0
	target.speed = 12.0
	target.phase = 0.0
	target.sway = 4.0
	await _tap(KEY_1)
	await _click(_drift_point(id))
	_check(not _player().hook.is_empty() and str(_player().hook.get("phase", "")) == "out" and not _player().hook.has("id"), "left click throws a directional hook without a locked resource id")
	_check(main.hovered_drift.is_empty() and main.view.hovered_id.is_empty(), "pointing at drift does not highlight or lock it")
	await _click(_drift_point(id), MOUSE_BUTTON_RIGHT)
	var returned_early: bool = await _wait_for(func() -> bool: return _player().hook.is_empty(), 5.0)
	_check(returned_early and Inventory.count(_player().bag, "wood") == 0 and bool(target.active), "early right click reels an empty hook back over time without consuming drift or awarding loot")
	await _click(_drift_point(id))
	var caught: bool = await _wait_for(func() -> bool: return id in _player().hook.get("cargo", []), 2.5)
	var travel_at_contact: float = float(_player().hook.get("travel", 0.0))
	await _settle(0.25)
	_check(caught and str(_player().hook.get("phase", "")) == "out" and float(_player().hook.get("travel", 0.0)) > travel_at_contact and Inventory.count(_player().bag, "wood") == 0, "physical contact attaches drift without auto-collecting or stopping the outward throw")
	await _click(_drift_point(id), MOUSE_BUTTON_RIGHT)
	var returned_loaded: bool = await _wait_for(func() -> bool: return _player().hook.is_empty(), 6.0)
	_check(returned_loaded and Inventory.count(_player().bag, "wood") == 2, "right click after contact visibly reels the hook back before crediting the real bag")
	_check(not main.context_ui.visible, "hook retrieval takes precedence over opening nearby actions")


func _multi_hook_checks() -> void:
	var saved_drift: Dictionary = main.world.data.drift.duplicate(true)
	var saved_bag: Array = _player().bag.duplicate(true)
	_fixture_player("deck", Vector2(480, 224))
	_player().bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	for object: Dictionary in main.world.data.drift.values():
		object.active = false
		object.respawn = 999.0
	await _tap(KEY_1)
	await _click(_world_point(Vector2(820, 224), "drift"))
	_check(not _player().hook.is_empty() and _player().hook.get("cargo") is Array and _player().hook.cargo.is_empty() and not _player().hook.has("id"), "throwing toward empty sea creates an empty cargo array with no target lock")
	var floating: bool = await _wait_for(func() -> bool: return str(_player().hook.get("phase", "")) == "float", 3.0)
	_check(floating and Inventory.total_count(_player().bag) == 0, "the empty throw reaches its natural floating phase without awarding materials")
	if not floating:
		main.world.data.drift = saved_drift
		_player().bag = saved_bag
		return
	var tip: Vector2 = Vector2(float(_player().hook.x), float(_player().hook.y))
	var hand: Vector2 = Vector2(float(_player().x), float(_player().y))
	var direction: Vector2 = (tip - hand).normalized()
	var ids: Array = main.world.data.drift.keys().slice(0, 3)
	var kinds: Array[String] = ["wood", "leaf", "scrap"]
	# Only arrange sea fixtures after the empty throw. Every hook transition below
	# still comes from P and the normal physics loop; no cargo or tool action is set.
	for index: int in ids.size():
		var object: Dictionary = main.world.data.drift[ids[index]]
		var at: Vector2 = tip.lerp(hand, 0.25 if index == 0 else 0.5)
		if index == 2:
			at = tip.lerp(hand, 0.4) + Vector2(-direction.y, direction.x) * 65.0
		object.kind = kinds[index]
		object.x = at.x
		object.y = at.y
		object.active = true
		object.respawn = 0.0
		object.speed = 12.0
		object.phase = 0.0
		object.sway = 4.0
	await _tap(KEY_P)
	_check(str(_player().hook.get("phase", "")) == "reel" and not main.context_ui.visible and Inventory.total_count(_player().bag) == 0, "P begins timed retrieval of the empty hook instead of opening the action menu or awarding moved-in drift")
	var first_contact: bool = await _wait_for(func() -> bool: return _player().hook.get("cargo", []).size() >= 1, 2.0)
	_check(first_contact and _player().hook.get("cargo", []) == [ids[0]] and Inventory.total_count(_player().bag) == 0, "returning hook first attaches only the wood encountered on its path, without early bag credit")
	var second_contact: bool = await _wait_for(func() -> bool: return _player().hook.get("cargo", []).size() >= 2, 2.0)
	_check(second_contact and _player().hook.get("cargo", []) == [ids[0], ids[1]] and str(_player().hook.get("phase", "")) == "reel", "the same retrieval continues past wood to attach leaf in contact order without a target lock")
	_check(second_contact and Inventory.total_count(_player().bag) == 0 and bool(main.world.data.drift[ids[0]].active) and bool(main.world.data.drift[ids[1]].active), "both attached materials remain uncredited until the hook returns to hand")
	await _settle(0.16)
	_check(_player().hook.get("cargo", []) == [ids[0], ids[1]] and Inventory.total_count(_player().bag) == 0, "later physics frames do not append attached ids twice or credit either material early")
	_check(main.view._returning_drift(str(ids[0])) and main.view._returning_drift(str(ids[1])) and not main.view._returning_drift(str(ids[2])), "view suppresses both reserved sea sprites while leaving unrelated drift visible")
	_check("2 件" in str(main.hud.hint.text) and "多捞" in str(main.hud.hint.text), "visible hook hint reports the multi-material load and continued path collection")
	if second_contact:
		await _capture("multi-hook-return.png")
	var returned: bool = await _wait_for(func() -> bool: return _player().hook.is_empty(), 5.0)
	_check(returned and Inventory.count(_player().bag, "wood") == 2 and Inventory.count(_player().bag, "leaf") == 2 and Inventory.total_count(_player().bag) == 4, "one physical return credits exactly two wood and two leaf together")
	_check(not bool(main.world.data.drift[ids[0]].active) and not bool(main.world.data.drift[ids[1]].active) and bool(main.world.data.drift[ids[2]].active) and Inventory.count(_player().bag, "scrap") == 0, "only the two contacted resources are consumed; off-path scrap is neither locked nor collected")
	await _settle(0.25)
	_check(_player().hook.is_empty() and Inventory.total_count(_player().bag) == 4, "completed multi-item retrieval cannot duplicate its rewards on later frames")
	main.world.data.drift = saved_drift
	_player().bag = saved_bag


func _shore_occlusion_checks() -> void:
	_fixture_player("deck", Vector2(480, 288))
	var before_nav: Dictionary = main.world.data.navigation.duplicate(true)
	var before_drift: Dictionary = main.world.data.drift.duplicate(true)
	var dock: Vector2 = Archipelago.island_position(main.world.data.chart)
	main.world.data.navigation.x = dock.x
	main.world.data.navigation.y = dock.y
	main.world.data.navigation.anchored = true
	for object: Dictionary in main.world.data.drift.values():
		object.active = false
	var id: String = str(main.world.data.drift.keys()[0])
	var target: Dictionary = main.world.data.drift[id]
	target.x = 690.0
	target.y = 228.0
	target.active = true
	target.respawn = 0.0
	target.speed = 12.0
	target.phase = 0.0
	target.sway = 4.0
	await _tap(KEY_1)
	_check(not main.view.surface_is_clear(Vector2(690, 228)), "island terrain occludes sea drift on the land silhouette")
	var before_bag: Array = _player().bag.duplicate(true)
	await _click(_drift_point(id))
	await _settle(1.8)
	_check(main.hovered_drift.is_empty() and _player().hook.get("cargo", []).is_empty(), "directional throw toward an island cannot attach invisible drift beneath its terrain")
	await _tap(KEY_P)
	var returned: bool = await _wait_for(func() -> bool: return _player().hook.is_empty(), 6.0)
	_check(returned and _player().bag == before_bag and bool(target.active), "reeling across occluded drift gives no invisible reward")
	_check(main.view.surface_is_clear(Vector2(480, 460)), "nearby open sea remains visible and targetable")
	main.world.data.navigation = before_nav
	main.world.data.drift = before_drift

func _mooring_checks() -> void:
	var saved_navigation: Dictionary = main.world.data.navigation.duplicate(true)
	var saved_guest: Dictionary = main.world.data.players.guest.duplicate(true)
	var saved_chart: Dictionary = main.world.data.chart.duplicate(true)
	_fixture_player("deck", Vector2(555, 288))
	_player().bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Inventory.add(_player().bag, "rope", 1)
	main.world.data.players.guest.online = false
	var dock: Vector2 = Archipelago.island_position(main.world.data.chart)
	var navigation: Dictionary = main.world.data.navigation
	navigation.x = dock.x - 70.0
	navigation.y = dock.y
	navigation.anchored = false
	navigation.moored = false
	navigation.push_x = 0.0
	navigation.push_y = 0.0
	navigation.host_cooldown = 0.0
	navigation.guest_cooldown = 0.0
	await _tap(KEY_1)
	await _tap(KEY_P)
	await _choose_context("moor")
	_check(navigation.moored and navigation.anchored and Inventory.count(_player().bag, "rope") == 0 and Inventory.count(_player().bag, "anchor") == 0, "P-menu mooring consumes the sole rope and stops the raft without requiring an anchor")
	var tied_navigation: Dictionary = navigation.duplicate(true)
	await _tap(KEY_G)
	_check(navigation == tied_navigation and Inventory.total_count(_player().bag) == 0, "G cannot turn the deployed mooring rope into an anchor or release the raft")
	await _move_mouse(_world_point(Vector2(555, 288), "deck"))
	await _tap(KEY_O)
	_check(_player().area == "island" and navigation.moored and navigation.anchored and Inventory.count(_player().bag, "rope") == 0, "O at the nearby shore lands the player while leaving the mooring rope deployed")
	await _tap(KEY_P)
	await _choose_context("board_raft")
	_check(_player().area == "deck" and navigation.moored, "P-menu return from the island preserves the tied raft")
	# Walk through normal physical input, not the idle fixture movement vector.
	main.automated = false
	var movement: InputEventKey = InputEventKey.new()
	movement.keycode = KEY_D
	movement.physical_keycode = KEY_D
	movement.pressed = true
	Input.parse_input_event(movement)
	await _settle(0.38)
	movement = InputEventKey.new()
	movement.keycode = KEY_D
	movement.physical_keycode = KEY_D
	movement.pressed = false
	Input.parse_input_event(movement)
	await _settle()
	main.automated = true
	var guest: Dictionary = main.world.data.players.guest
	guest.online = true
	guest.resting = false
	guest.sleep_ready = false
	guest.hook = {}
	guest.fishing = {}
	guest.activity = {}
	guest.oxygen = 100.0
	for area: String in ["water", "island"]:
		guest.area = area
		guest.x = 120.0 if area == "water" else IslandState.DOCK.x
		guest.y = 80.0 if area == "water" else IslandState.DOCK.y
		await _settle()
		await _tap(KEY_P)
		await _choose_context("unmoor")
		_check(navigation.moored and navigation.anchored and Inventory.count(_player().bag, "rope") == 0 and Inventory.count(_player().bag, "anchor") == 0 and guest.area == area, "P-menu unmoor is rejected while the partner is in " + area + ", without returning or converting the rope")
	guest.area = "deck"
	guest.x = 520.0
	guest.y = 288.0
	await _settle()
	await _tap(KEY_P)
	await _choose_context("unmoor")
	_check(not navigation.moored and not navigation.anchored and Inventory.count(_player().bag, "rope") == 1 and Inventory.count(_player().bag, "anchor") == 0, "after both players return, P-menu unmoor returns exactly the original rope and resumes sailing")
	main.world.data.navigation = saved_navigation
	main.world.data.players.guest = saved_guest
	main.world.data.chart = saved_chart


func _paddle_checks() -> void:
	_fixture_player("deck", Vector2(480, 360))
	_player().bag = Inventory.empty_slots(12)
	Inventory.add(_player().bag, "paddle", 1)
	_player().stamina = 60.0
	var nav: Dictionary = main.world.data.navigation
	nav.anchored = false
	nav.moored = false
	nav.host_cooldown = 0.0
	nav.push_x = 0.0
	nav.push_y = 0.0
	await _tap(KEY_3)
	_check(main.active_tool == "paddle", "3 selects the carried paddle")
	await _move_mouse(_world_point(Vector2(780, 310), "drift"))
	var stamina: float = float(_player().stamina)
	await _tap(KEY_O)
	_check(_player().area == "deck" and absf(float(_player().stamina) - (stamina - 2.0)) < 0.01 and float(nav.push_x) > 0.0, "O with paddle strokes toward the pointer instead of taking the nearby dive action")
	await _settle(0.80)
	stamina = float(_player().stamina)
	await _click(_world_point(Vector2(780, 310), "drift"))
	_check(_player().area == "deck" and absf(float(_player().stamina) - (stamina - 2.0)) < 0.01 and float(nav.push_x) > 0.0, "paddle also works through a left click on the sea")
	_check(Inventory.count(_player().bag, "paddle") == 1, "both strokes retain the reusable paddle")


func _toolbar_checks() -> void:
	_fixture_player("deck", Vector2(480, 288))
	_player().bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	for tool: String in ["rod", "paddle", "harpoon"]:
		Inventory.add(_player().bag, tool, 1)
	main.world.data.navigation.anchored = true
	await _settle()
	_check(main.hud.tool_buttons.size() == 4 and main.hud.quick_buttons.size() == 16 and main.hud.slots.size() == 12 and main.hud.quick_buttons.filter(func(button): return button.visible).size() == 9, "sea toolbar retains five visible bag shortcuts beside four distinct tools")
	for tool: String in ["hook", "rod", "paddle"]:
		await _click(main.hud.tool_buttons[tool].get_global_rect().get_center())
		_check(main.active_tool == tool and _player().hook.is_empty() and _player().fishing.is_empty(), tool + ": toolbar selection does not pass through into a world action")
	_check(main.hud.tool_buttons.harpoon.disabled, "harpoon toolbar control is unavailable on deck")
	_fixture_player("water", Vector2(300, 240))
	await _tap(KEY_4)
	_check(main.active_tool == "harpoon" and not main.hud.tool_buttons.harpoon.disabled and main.hud.tool_buttons.rod.disabled and main.hud.tool_buttons.paddle.disabled, "4 selects the water-only harpoon while deck tools become unavailable")
	await _tap(KEY_1)
	_check(main.active_tool == "hook", "1 returns to the water gathering tool")
	await _click(main.hud.tool_buttons.harpoon.get_global_rect().get_center())
	_check(main.active_tool == "harpoon" and _player().activity.is_empty(), "clicking the fourth toolbar control selects harpoon without firing it")
	await _tap(KEY_2)
	_check(main.active_tool == "rod", "legacy 2 keyboard selection remains mapped to rod")
	await _tap(KEY_3)
	_check(main.active_tool == "paddle", "legacy 3 keyboard selection remains mapped to paddle")


func _island_checks() -> void:
	_fixture_player("island", Vector2(302, 280))
	main.world.data.chart.visited = true
	main.world.data.navigation.anchored = true
	main.world.data.navigation.push_x = 0.0
	main.world.data.navigation.push_y = 0.0
	var coast: Vector2 = Archipelago.island_position(main.world.data.chart)
	main.world.data.navigation.x = coast.x
	main.world.data.navigation.y = coast.y
	_player().bag = Inventory.empty_slots(12)
	main.world.data.island.depleted.erase("palm_0")
	main.world.data.island.plots.clear()
	await _tap(KEY_1)
	var resource: Dictionary = IslandMap.node("palm_0")
	await _click(_world_point(Vector2(float(resource.x), float(resource.y)), "island"))
	_check(_player().activity.is_empty() and IslandState.active(main.world.data.island, "palm_0", int(main.world.data.day)) and Inventory.count(_player().bag, "wood") == 0, "island tree click without a personal axe cannot start gathering or award wood")
	Inventory.add(_player().bag, "axe", 1)
	await _click(_world_point(Vector2(float(resource.x), float(resource.y)), "island"))
	_check(_player().activity.get("kind", "") == "island_gather" and _player().activity.get("id", "") == "palm_0" and Inventory.count(_player().bag, "wood") == 0, "left click with the axe starts the correct timed island node, with no instant reward")
	var completed: bool = await _wait_for(func() -> bool: return _player().activity.is_empty(), float(resource.duration) + 2.0)
	_check(completed and not IslandState.active(main.world.data.island, "palm_0", int(main.world.data.day)) and Inventory.count(_player().bag, "wood") == 3, "the normal physics loop finishes the selected tree and records its regrow day")
	await _click(_world_point(Vector2(float(resource.x), float(resource.y)), "island"))
	_check(Inventory.count(_player().bag, "wood") == 3, "clicking the depleted island resource does not duplicate rewards")
	_fixture_player("island", Vector2(520, 288))
	var chest_slots: Array = Inventory.empty_slots(16)
	Inventory.add(chest_slots, "leaf", 20)
	Inventory.add(chest_slots, "wood", 20)
	main.world.data.chests = {"chest_0": {"id": "chest_0", "name": "船上物资", "x": 544.0, "y": 288.0, "slots": chest_slots}}
	_player().bag = Inventory.empty_slots(12)
	Inventory.add(_player().bag, "leaf", 1)
	await _tap(KEY_B)
	_check(main.inventory_ui.visible and "潮芽岛" in str(main.inventory_ui.vitals.text), "island backpack labels the current island")
	_check(main.inventory_ui.chest_id == "" and not main.inventory_ui._with_chest, "matching map coordinates do not expose the distant raft chest")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_C)
	await _click(main.crafting_ui.recipe_buttons["rope"].get_global_rect().get_center())
	_check(main.crafting_ui.selected_recipe == "rope" and main.crafting_ui.make_button.disabled, "island recipe cannot borrow the missing leaf from a raft chest")
	_check(str(main.crafting_ui._cost_rows[0].owned.text) == "1", "island material count displays only the carried leaf")
	var before_chests: Dictionary = main.world.data.chests.duplicate(true)
	await _click(main.crafting_ui.make_button.get_global_rect().get_center())
	_check(Inventory.count(_player().bag, "rope") == 0 and main.world.data.chests == before_chests, "disabled crafting click changes neither bag nor raft storage")
	Inventory.add(_player().bag, "leaf", 1)
	await _settle()
	_check(not main.crafting_ui.make_button.disabled, "same recipe becomes available when personal materials suffice")
	await _click(main.crafting_ui.make_button.get_global_rect().get_center())
	_check(Inventory.count(_player().bag, "rope") == 1 and Inventory.count(_player().bag, "leaf") == 0 and main.world.data.chests == before_chests, "normal crafting button spends only the island player's materials")
	Inventory.add(_player().bag, "wood", 8)
	Inventory.add(_player().bag, "plastic", 4)
	Inventory.add(_player().bag, "rope", 2)
	await _click(main.crafting_ui.recipe_buttons["purifier"].get_global_rect().get_center())
	_check(main.crafting_ui.make_button.disabled and main.crafting_ui.make_button.text == "请返回甲板", "island facility recipe requires returning to deck even with enough materials")
	var before_structures: Dictionary = main.world.data.structures.duplicate(true)
	await _click(main.crafting_ui.make_button.get_global_rect().get_center())
	_check(main.world.data.structures == before_structures and main.placement_recipe.is_empty(), "unavailable island facility cannot enter placement or consume materials")
	await _tap(KEY_ESCAPE)


func _farm_input_checks() -> void:
	# Deliberate tools/position fixtures: this verifies GUI routing, not natural growth.
	main.active_seed = "seed"
	_fixture_player("island", Vector2(528, 368))
	_player().stamina = 90.0
	_player().bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	for item: String in ["hoe", "watering_can", "canopy", "scythe", "summer_seed", "compass"]:
		Inventory.add(_player().bag, item, 1)
	Inventory.add(_player().bag, "seed", 3)
	_player().can_water = 3
	main.world.data.island.plots.clear()
	var first := Vector2(496, 336)
	var second := Vector2(528, 336)
	var first_key: String = Farming.plot_key(first)
	var second_key: String = Farming.plot_key(second)
	await _settle()
	_check(main.hud.slots.size() == 12 and main.hud.slots.all(func(entry): return entry.button.visible) and not main.hud.tool_buttons.rod.visible, "island toolbar exposes all twelve actual bag slots without a separate farming row")
	await _click(main.hud.slots[0].button.get_global_rect().get_center())
	_check(main.active_tool == "till" and main.world.data.island.plots.is_empty(), "clicking the actual hoe stack equips it without passing through to ground")
	await _click(_world_point(first, "island"))
	_check(main.world.data.island.plots.size() == 1 and main.world.data.island.plots.has(first_key), "real mouse till opens exactly the selected world grid cell")
	await _click(_world_point(second, "island"))
	_check(main.world.data.island.plots.size() == 2 and main.world.data.island.plots.has(second_key), "a neighboring mouse click creates an independent second plot")
	await _click(main.hud.slots[6].button.get_global_rect().get_center())
	await _click(_world_point(first, "island"))
	_check(main.world.data.island.plots[first_key].crop == "seed" and main.world.data.island.plots[second_key].crop == "" and Inventory.count(_player().bag, "seed") == 2, "seed stack and left click plant only the chosen cell and consume one personal spring seed")
	await _click(main.hud.slots[1].button.get_global_rect().get_center())
	await _click(_world_point(first, "island"))
	_check(main.world.data.island.plots[first_key].watered and not main.world.data.island.plots[second_key].watered and int(_player().can_water) == 2, "watering can stack and left click water one cell and spend exactly one can charge")
	await _click(_world_point(first, "island"))
	_check(int(_player().can_water) == 2, "clicking an already-watered cell does not consume another charge")
	await _click(_world_point(second, "island"))
	_check(main.world.data.island.plots[second_key].watered and int(_player().can_water) == 1, "the neighboring bare soil has its own watering state")
	await _click(main.hud.slots[2].button.get_global_rect().get_center())
	await _click(_world_point(second, "island"))
	_check(main.world.data.island.plots[second_key].covered and not main.world.data.island.plots[first_key].covered and Inventory.count(_player().bag, "canopy") == 0, "canopy stack places one small canopy on the selected plot without covering its neighbor")
	await _tap(KEY_N)
	_check(main.active_seed == "summer_seed", "N equips the next carried seed without planting or consuming it")
	await _click(main.hud.slots[4].button.get_global_rect().get_center())
	await _click(_world_point(second, "island"))
	_check(main.world.data.island.plots[second_key].crop == "summer_seed" and Inventory.count(_player().bag, "summer_seed") == 0 and int(main.world.data.island.plots[first_key].growth) == 0 and int(main.world.data.island.plots[second_key].growth) == 0, "covered soil accepts the selected out-of-season crop while neither plot gains artificial growth")
	await _capture("island-two-plots.png")
	await _tap(KEY_1)
	_fixture_player("island", Vector2(640, 430))
	await _settle()
	await _click(_world_point(Vector2(640, 430), "island"))
	_check(int(_player().can_water) == Farming.CAN_CAPACITY, "normal mouse interaction at the freshwater bank fills the personal watering can")
	_check(main.world.data.island.plots[first_key].watered and main.world.data.island.plots[second_key].watered and main.world.data.island.plots.size() == 2, "refilling leaves both independent plots untouched")
	_player().can_water = 0
	await _tap(KEY_7)
	await _tap(KEY_P)
	_check(main.context_ui.visible and main.active_tool == "hook", "one P in watering mode exposes the pond refill menu immediately")
	await _choose_context("refill_can")
	_check(int(_player().can_water) == Farming.CAN_CAPACITY, "choosing refill after watering mode fills the personal can")


func _atlas_checks() -> void:
	var position := Vector2(float(_player().x), float(_player().y))
	var navigation: Dictionary = main.world.data.navigation.duplicate(true)
	var island: Dictionary = main.world.data.island.duplicate(true)
	var bag: Array = _player().bag.duplicate(true)
	await _tap(KEY_M)
	_check(main.island_atlas.visible and not main.chart_ui.visible and main.island_atlas.region_buttons.size() == 6 and main.island_atlas.selected_region == "", "M on land opens the six-region island overview instead of the sea chart")
	var elapsed: float = float(main.world.data.elapsed)
	await _settle(0.24)
	_check(is_equal_approx(float(main.world.data.elapsed), elapsed), "the island atlas pauses a solo world")
	await _click(main.island_atlas.region_buttons.harbor.get_global_rect().get_center())
	_check(main.island_atlas.selected_region == "harbor" and main.island_atlas.page_buttons.has("1,0"), "clicking harbor opens its page-level details")
	await _click(main.island_atlas.page_buttons["1,0"].get_global_rect().get_center())
	_check(main.island_atlas.selected_page == Vector2i(1, 0) and not str(main.island_atlas.resources_label.text).is_empty(), "a page button changes the inspected page and resource notes")
	_check(Vector2(float(_player().x), float(_player().y)) == position and main.world.data.navigation == navigation and main.world.data.island == island and _player().bag == bag and _player().activity.is_empty(), "map and page clicks do not teleport, gather, till or modify world inventories")
	await _capture("island-atlas-region.png")
	await _click(main.island_atlas.back_button.get_global_rect().get_center())
	_check(main.island_atlas.selected_region == "" and main.island_atlas.region_buttons.harbor.visible, "the region back button restores the six-region overview")
	await _click(main.island_atlas.sea_button.get_global_rect().get_center())
	_check(main.chart_ui.visible and not main.island_atlas.visible and main.chart_ui.full_chart, "return-to-sea button opens the carried-compass sea chart without moving the player")
	await _click(main.chart_ui.close_button.get_global_rect().get_center())
	_check(main.island_atlas.visible and not main.chart_ui.visible, "closing the sea chart on land returns to the island atlas")
	await _click(main.island_atlas.close_button.get_global_rect().get_center())
	await _settle(0.20)
	_check(not main.island_atlas.visible and not main.chart_ui.visible and float(main.world.data.elapsed) > elapsed, "closing the island atlas resumes normal solo time")


func _page_input_checks() -> void:
	_fixture_player("island", Vector2(884, 208))
	await _tap(KEY_1)
	await _settle()
	var before: Vector2 = main.view.world_to_screen(Vector2(944, 208), "island")
	main.automated = false
	var event := InputEventKey.new()
	event.keycode = KEY_D
	event.physical_keycode = KEY_D
	event.pressed = true
	Input.parse_input_event(event)
	await _settle(0.24)
	event = InputEventKey.new()
	event.keycode = KEY_D
	event.physical_keycode = KEY_D
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()
	main.automated = true
	var position := Vector2(float(_player().x), float(_player().y))
	_check(position.x >= 896 and position.x < 976 and IslandMap.page_origin(position) == Vector2(896, 0), "normal D input walks over the first page boundary without resetting global island position")
	var target := Vector2(944, 208)
	var screen: Vector2 = main.view.world_to_screen(target, "island")
	_check(screen == Vector2(48, 208) and before - screen == Vector2(896, 0) and main.view.screen_to_world(screen, "island") == target, "page switch applies one fixed page offset and exactly inverts pointer coordinates")
	await _tap(KEY_5)
	await _move_mouse(_world_point(target, "island"))
	await _settle()
	_check(main.view.farm_preview.get("x", -1) == target.x and main.view.farm_preview.get("y", -1) == target.y and bool(main.view.farm_preview.get("valid", false)), "farm preview after crossing pages selects the global target cell")
	var before_count: int = main.world.data.island.plots.size()
	await _click(_world_point(target, "island"))
	_check(main.world.data.island.plots.has(Farming.plot_key(target)) and not main.world.data.island.plots.has(Farming.plot_key(screen)) and main.world.data.island.plots.size() == before_count + 1, "real mouse till on page two creates the global cell and never its page-zero alias")
	await _capture("island-page-two-input.png")


func _town_input_checks() -> void:
	_fixture_player("island", Vector2(1088, 480))
	main.world.data.minute = 660.0
	main.world.data.money = 30
	main.active_tool = "hook"
	await _settle()
	await _click(_world_point(Vector2(1088, 480), "island"))
	_check(main.dialogue_ui.visible and "林穗" in main.dialogue_ui.speaker.text and main.world.data.money == 30, "left-click market resident opens readable conversation without any automatic purchase")
	var clock_before: float = main.world.data.minute
	await _settle(0.25)
	_check(main.world.data.minute == clock_before, "solo conversation pauses world time until dismissed")
	await _capture("town-market-dialogue.png")
	await _tap(KEY_ESCAPE)
	_check(not main.dialogue_ui.visible and not main.pause_open, "Escape closes only the conversation")
	var before_seed: int = Inventory.count(_player().bag, "seed")
	await _tap(KEY_P)
	await _choose_context("town_trade")
	_check(main.world.data.money == 27 and Inventory.count(_player().bag, "seed") == before_seed + 1, "explicit market menu buys one seasonal seed for three shared coins")
	_fixture_player("island", Vector2(1528, 576))
	_player().stamina = 20.0
	await _settle()
	await _tap(KEY_P)
	await _choose_context("town_bath")
	_check(_player().activity.get("kind") == "town_bath" and main.world.data.money == 27, "bath menu starts a visible eight-second action without early payment")
	await _capture("town-bath-progress.png")
	await _tap(KEY_P)
	_check(_player().activity.is_empty() and main.world.data.money == 27, "P cancels an unfinished bath without spending shared money")
	_fixture_player("island", Vector2(1344, 680))
	await _settle()
	await _capture("town-south.png")
	await _tap(KEY_M)
	await _click(main.island_atlas.region_buttons.harbor.get_global_rect().get_center())
	await _click(main.island_atlas.page_buttons["1,0"].get_global_rect().get_center())
	_check("超市" in main.island_atlas.detail_label.text and "诊所" in main.island_atlas.detail_label.text, "island page details list actual reachable town buildings")
	await _capture("town-atlas.png")
	await _tap(KEY_M)
	_fixture_player("island", Vector2(6704, 2352))
	await _settle()
	await _capture("lake-shore.png")
	# Stage a genuine wild grass tile; all clearing and farming goes through input.
	var wild: Dictionary = {}
	for node: Dictionary in IslandMap.nodes_near(Vector2(2000, 280)).values():
		if str(node.id).begins_with("clear_2_0_") and node.kind == "fiber" and node.y < 350:
			wild = node
			break
	_check(not wild.is_empty(), "wilderness includes an uncleared grass cell")
	if wild.is_empty():
		return
	var at := Vector2(wild.x, wild.y)
	_fixture_player("island", at)
	_player().bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	for item in ["hoe", "scythe", "seed", "watering_can"]:
		Inventory.add(_player().bag, item, 1)
	_player().can_water = 20
	main.active_seed = "seed"
	main.world.data.island.depleted.erase(wild.id)
	main.world.data.island.plots.erase(Farming.plot_key(at))
	await _settle()
	await _tap(KEY_5)
	await _move_mouse(_world_point(at, "island"))
	await _settle()
	_check(not main.view.farm_preview.valid, "hoe preview marks uncleared grass as blocked")
	await _click(_world_point(at, "island"))
	_check(not main.world.data.island.plots.has(Farming.plot_key(at)), "clicking blocked soil cannot skip grass clearing")
	await _tap(KEY_1)
	await _click(_world_point(at, "island"))
	_check(_player().activity.get("kind") == "island_gather", "scythe gathering starts via clicked grass")
	await _settle(1.9)
	_check(_player().activity.is_empty() and Inventory.count(_player().bag, "fiber") == 3, "timed scythe work yields the grass once")
	await _tap(KEY_5)
	await _click(_world_point(at, "island"))
	await _tap(KEY_6)
	await _click(_world_point(at, "island"))
	await _tap(KEY_7)
	await _click(_world_point(at, "island"))
	var plot: Dictionary = main.world.data.island.plots.get(Farming.plot_key(at), {})
	_check(plot.get("crop") == "seed" and plot.get("watered", false), "cleared wild ground becomes a personal-choice planted and watered cell")
	await _capture("wilderness-reclaimed.png")

func _fixture_player(area: String, at: Vector2) -> void:
	var player: Dictionary = _player()
	player.area = area
	player.x = at.x
	player.y = at.y
	player.resting = false
	player.sleep_ready = false
	player.hook = {}
	player.fishing = {}
	player.activity = {}
	player.oxygen = 100.0
	player.hunger = 90.0
	player.thirst = 90.0


func _player() -> Dictionary:
	return main.world.data.players.host


func _choose_context(action: String) -> void:
	var index: int = -1
	for candidate: int in main.current_options.size():
		if str(main.current_options[candidate].action) == action:
			index = candidate
			break
	_check(main.context_ui.visible and index >= 0 and index < main.context_ui.buttons.size(), "nearby menu contains the distinct " + action + " button")
	if not main.context_ui.visible or index < 0 or index >= main.context_ui.buttons.size():
		return
	await _click(main.context_ui.buttons[index].get_global_rect().get_center())


func _world_point(point: Vector2, area: String) -> Vector2:
	return main.view.get_global_transform_with_canvas() * main.view.world_to_screen(point, area)


func _drift_point(id: String) -> Vector2:
	var target: Dictionary = main.world.data.drift[id]
	return _world_point(Vector2(float(target.x), float(target.y)), "drift")


func _tap(code: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()


func _move_mouse(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	await process_frame


func _click(at: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	await _move_mouse(at)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	event.pressed = false
	root.push_input(event, true)
	await _settle()


func _settle(seconds: float = 0.14) -> void:
	await create_timer(seconds).timeout
	await process_frame


func _wait_for(condition: Callable, timeout: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while not bool(condition.call()) and Time.get_ticks_msec() < deadline:
		await _settle(0.04)
	return bool(condition.call())


func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("Screenshot requires a rendering display: ", evidence.path_join(filename))
		return
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var error: Error = screenshot.save_png(evidence.path_join(filename))
	_check(error == OK, filename + " screenshot saves successfully")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", description)


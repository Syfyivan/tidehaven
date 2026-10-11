extends SceneTree
## Real root controls and input, with isolated fixtures for compass visibility.
## godot --path <project> --script res://tests/exploration_ui_checks.gd
const MainScene: PackedScene = preload("res://main.tscn")
const Inventory = preload("res://scripts/inventory.gd")
const Recipes = preload("res://scripts/recipes.gd")
const Art = preload("res://scripts/art_catalog.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
const ItemSlot = preload("res://scripts/inventory_slot.gd")
const NEW_TOOLS: Array[String] = ["harpoon", "axe", "pickaxe", "compass"]
var main: Node
var checks: int = 0
var failures: int = 0
var finished: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var evidence: String = ProjectSettings.globalize_path("res://artifacts/exploration-ui-checks-%d" % int(Time.get_unix_time_from_system() * 1000.0))
	var folder_error: Error = DirAccess.make_dir_recursive_absolute(evidence)
	if folder_error != OK:
		printerr("FAIL cannot create isolated UI fixture folder: ", error_string(folder_error))
		quit(1)
		return
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("fixture-world.json")
	root.add_child(main)
	main.save_path = evidence.path_join("fixture-world.json")
	main.automated = true
	create_timer(45.0).timeout.connect(func() -> void:
		if not finished:
			printerr("FAIL EXPLORATION UI CHECKS exceeded 45 seconds")
			quit(1))
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	_check(main.mode == "solo", "normal new-game control starts the isolated world")
	if main.mode != "solo":
		quit(1)
		return
	await _chart_checks()
	await _tool_checks()
	finished = true
	print("EXPLORATION UI CHECKS: %d checks, %d failures; isolated save: %s" % [checks, failures, main.save_path])
	quit(0 if failures == 0 else 1)


func _chart_checks() -> void:
	var chart: Dictionary = main.world.data.chart
	var navigation: Dictionary = main.world.data.navigation
	var home: Vector2 = Archipelago.island_position(chart)
	var origin: Vector2 = Archipelago.origin(chart)
	navigation.x = origin.x
	navigation.y = origin.y
	navigation.anchored = true
	_player().bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	main.world.data.players.guest.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Inventory.add(main.world.data.players.guest.bag, "compass", 1)
	var chest_slots: Array = Inventory.empty_slots(Inventory.CHEST_SIZE)
	Inventory.add(chest_slots, "compass", 1)
	main.world.data.chests = {"chest_0": {"id": "chest_0", "name": "测试木箱", "x": 544.0, "y": 288.0, "slots": chest_slots}}
	# An old save can keep a destination; it must not reveal it without a compass.
	chart.destination = Archipelago.HOME_ID
	await _tap(KEY_M)
	_check(main.chart_ui.visible and not main.chart_ui.full_chart, "M opens a local chart when only the partner and a chest have compasses")
	var hidden_islands: bool = true
	for button: Button in main.chart_ui.island_buttons.values():
		hidden_islands = hidden_islands and not button.visible and button.tooltip_text.is_empty()
	_check(hidden_islands, "far island controls and hover names are absent from the local chart")
	_check(main.chart_ui.selected_island == "" and main.chart_ui.title_label.text == "身边的海", "far default selection cannot leak island details")
	_check(main.chart_ui.distance_label.text.is_empty() and main.chart_ui.destination_button.disabled and not "潮芽岛" in main.chart_ui.feedback_label.text, "old destination reveals no distance, route label or enabled waypoint control")
	var elapsed: float = float(main.world.data.elapsed)
	await _settle(0.25)
	_check(is_equal_approx(float(main.world.data.elapsed), elapsed), "solo local chart retains the existing pause behavior")
	var centered: Vector2 = main.chart_ui._map_point(origin)
	_check(centered.distance_to(main.chart_ui.map_canvas.size * 0.5) < 0.01, "local chart centers the raft without global map bounds")

	navigation.x = home.x - 400.0
	navigation.y = home.y
	await _settle()
	_check(main.chart_ui.island_buttons[Archipelago.HOME_ID].visible and main.chart_ui.title_label.text == "潮芽岛", "first playable island becomes visible at the 400-unit local boundary")
	_check(main.chart_ui.destination_button.disabled and main.chart_ui.distance_label.text.is_empty(), "seeing a nearby island does not grant remote navigation or measured distance")
	var before_destination: String = str(chart.destination)
	await _click(main.chart_ui.destination_button.get_global_rect().get_center())
	_check(str(chart.destination) == before_destination and is_equal_approx(float(navigation.x), home.x - 400.0), "disabled local waypoint button cannot mutate travel")
	navigation.x = home.x - 401.0
	await _settle()
	_check(not main.chart_ui.island_buttons[Archipelago.HOME_ID].visible and main.chart_ui.selected_island == "", "island details disappear again outside the local boundary")

	Inventory.add(_player().bag, "compass", 1)
	chart.destination = ""
	await _settle()
	_check(main.chart_ui.full_chart and main.chart_ui.island_buttons["island_mist"].visible, "a compass in the local bag exposes the full chart")
	await _click(main.chart_ui.island_buttons["island_mist"].get_global_rect().get_center())
	_check(main.chart_ui.selected_island == "island_mist" and main.chart_ui.destination_button.disabled, "full chart still cannot unlock the unplayable island")
	await _click(main.chart_ui.destination_button.get_global_rect().get_center())
	_check(str(chart.destination).is_empty(), "locked island cannot acquire a waypoint through its disabled control")
	await _click(main.chart_ui.island_buttons[Archipelago.HOME_ID].get_global_rect().get_center())
	var navigation_before: Dictionary = navigation.duplicate(true)
	await _click(main.chart_ui.destination_button.get_global_rect().get_center())
	_check(str(chart.destination) == Archipelago.HOME_ID and navigation == navigation_before, "full chart's actual waypoint button changes only the destination")
	await _click(main.chart_ui.island_buttons["island_mist"].get_global_rect().get_center())
	await _tap(KEY_M)
	await _tap(KEY_B)
	_check(main.inventory_ui.visible and main.inventory_ui.chest_id == "chest_0", "normal inventory entry exposes the nearby compass chest")
	var compass_index: int = _item_index("compass")
	_check(compass_index >= 0, "local compass remains a real inventory stack")
	if compass_index >= 0:
		await _click(main.inventory_ui.bag_buttons[compass_index].get_global_rect().get_center())
		await _click(main.inventory_ui.chest_buttons[0].get_global_rect().get_center())
	_check(Inventory.count(_player().bag, "compass") == 0 and Inventory.count(main.world.data.chests.chest_0.slots, "compass") == 2, "actual slot clicks store the compass without duplicating it")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_M)
	_check(not main.chart_ui.full_chart and not main.chart_ui.island_buttons["island_mist"].visible, "storing the compass immediately re-locks the full chart")
	_check(main.chart_ui.selected_island == "" and main.chart_ui.title_label.text == "身边的海" and main.chart_ui.distance_label.text.is_empty(), "reopening clears previously selected remote details and measured distance")
	_check(Inventory.count(main.world.data.players.guest.bag, "compass") == 1 and str(chart.destination) == Archipelago.HOME_ID, "chart presentation preserves the partner's tool and saved destination")
	await _tap(KEY_M)


func _tool_checks() -> void:
	main.world.data.chests = {}
	_player().bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	# Exactly enough personal ingredients for the four requested tools.
	for item: String in ["wood", "scrap", "stone", "plastic", "rope"]:
		var quantity: int = int({"wood": 9, "scrap": 5, "stone": 5, "plastic": 2, "rope": 4}[item])
		Inventory.add(_player().bag, item, quantity)
	await _tap(KEY_C)
	await _click(main.crafting_ui.category_buttons.exploration.get_global_rect().get_center())
	_check(main.crafting_ui.visible and main.crafting_ui.selected_category == "exploration", "normal exploration category reveals the new handcraft recipes")
	for item: String in NEW_TOOLS:
		var button: Button = main.crafting_ui.recipe_buttons[item]
		_check(button.visible and main.crafting_ui.recipe_scroll.get_global_rect().encloses(button.get_global_rect()), item + ": recipe is visible inside the category without overflow")
		await _click(button.get_global_rect().get_center())
		_check(main.crafting_ui.selected_recipe == item and main.crafting_ui.picture.texture == Art.item_icon(item) and not main.crafting_ui.make_button.disabled, item + ": actual recipe click selects the shared icon and enabled craft control")
		var before: Dictionary = Inventory.totals(_player().bag)
		await _click(main.crafting_ui.make_button.get_global_rect().get_center())
		_check(Inventory.count(_player().bag, item) == 1 and main.placement_recipe.is_empty(), item + ": normal craft button creates a personal item without facility placement")
		var spent_exactly: bool = true
		for ingredient: String in Recipes.ALL[item].costs:
			spent_exactly = spent_exactly and Inventory.count(_player().bag, ingredient) == int(before[ingredient]) - int(Recipes.ALL[item].costs[ingredient])
		_check(spent_exactly, item + ": recipe consumes exactly its personal ingredients")
	_check(Inventory.used(_player().bag) == 4 and Inventory.total_count(_player().bag) == 4, "four completed tools occupy four finite bag slots with no leftover ingredients")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_B)
	for item: String in NEW_TOOLS:
		var index: int = _item_index(item)
		_check(index >= 0, item + ": result is available in the normal inventory")
		if index < 0:
			continue
		var button: ItemSlot = main.inventory_ui.bag_buttons[index]
		await _move_mouse(button.get_global_rect().get_center())
		_check(button.item_icon.texture == Art.item_icon(item) and button.caption.text == "1", item + ": bag uses the same artwork and readable quantity")
		_check(main.inventory_ui.usage_label.text == ItemSlot.item_usage(item) and main.inventory_ui.source_label.text == ItemSlot.item_source(item), item + ": hover details show its purpose and handcraft source")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_M)
	_check(main.chart_ui.full_chart, "the normally crafted compass unlocks the full chart")
	await _click(main.chart_ui.close_button.get_global_rect().get_center())
	_check(not main.chart_ui.visible, "chart close control still restores normal input")


func _player() -> Dictionary:
	return main.world.data.players.host


func _item_index(item: String) -> int:
	for index: int in _player().bag.size():
		if str(_player().bag[index].get("item", "")) == item:
			return index
	return -1


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
	await _settle()


func _click(at: Vector2) -> void:
	await _move_mouse(at)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	root.push_input(event, true)
	await _settle()


func _settle(seconds: float = 0.14) -> void:
	await create_timer(seconds).timeout
	await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", description)

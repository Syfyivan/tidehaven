extends Node
## Controlled visual fixtures only. The normal-input playthrough proves progression.
const Inventory = preload("res://scripts/inventory.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
const IslandState = preload("res://scripts/island_state.gd")
var main: Node
var folder := ""
var shots: int = 0
var checks: int = 0

func _ready() -> void:
	main = get_parent()
	folder = str(main.cli.get("evidence-dir", ""))
	if folder.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()

func _run() -> void:
	await _shot("01-title.png")
	await _click(main.new_game_button.get_global_rect().get_center())
	if not _check(main.mode == "solo", "normal menu click starts the packaged game"):
		return
	main.toast_clock = 0
	await _shot("02-deck.png")
	for notice: String in ["已放好，里面的物品和加工进度都保留。", "材料不足，先去收集木材。"]:
		main._toast(notice)
		await get_tree().process_frame
		if not _check(main.status.text == notice and main.status.get_theme_color("font_color").get_luminance() < 0.4, "readable notification ink on paper"):
			return
		await _shot("notice-%d.png" % checks)
	await get_tree().create_timer(2.0).timeout
	await _shot("10-deck-current.png")
	for item in {"wood": 16, "leaf": 9, "plastic": 7, "scrap": 3, "rope": 2, "cup": 1, "fish": 4, "seed": 5}:
		Inventory.add(main.world.data.players.host.bag, item, {"wood": 16, "leaf": 9, "plastic": 7, "scrap": 3, "rope": 2, "cup": 1, "fish": 4, "seed": 5}[item])
	main._toggle_inventory()
	await _shot("03-bag.png")
	main.inventory_ui._clicked("bag", 0, false)
	await _shot("03a-wood-detail.png")
	var before_discard: Array = main.world.data.players.host.bag.duplicate(true)
	await _click(main.inventory_ui.discard_button.get_global_rect().get_center())
	await _tap(KEY_C)
	if not _check(main.inventory_ui.visible and main.inventory_ui.discard_dialog.visible and not main.crafting_ui.visible, "packaged discard confirmation owns menu shortcuts"):
		return
	await _shot("03b-discard-confirmation.png")
	await _tap(KEY_ESCAPE)
	if not _check(main.inventory_ui.visible and not main.inventory_ui.discard_dialog.visible and main.world.data.players.host.bag == before_discard, "packaged Escape cancels only discard without losing items"):
		return
	main._toggle_inventory()
	var contents := Inventory.empty_slots(16)
	Inventory.add(contents, "wood", 12)
	Inventory.add(contents, "freshwater", 3)
	Inventory.add(contents, "cooked_fish", 2)
	main.world.data.chests["chest_0"] = {"id": "chest_0", "name": "木箱 1", "x": 544.0, "y": 288.0, "slots": contents}
	main.world.data.players.host.x = 496.0
	main._toggle_inventory()
	await _shot("04-storage.png")
	main._toggle_inventory()
	main._toggle_crafting()
	main.crafting_ui.selected_recipe = "purifier"
	await _shot("05-crafting.png")
	main.crafting_ui.selected_recipe = "anchor"
	await _shot("05a-anchor-recipe.png")
	main._toggle_crafting()
	main._toggle_pause()
	await _shot("06-pause.png")
	main._toggle_pause()
	Inventory.add(main.world.data.chests.chest_0.slots, "stone", 6)
	Inventory.add(main.world.data.chests.chest_0.slots, "ingot", 4)
	main._toggle_crafting()
	main.crafting_ui.selected_recipe = "furnace"
	await _shot("08-exploration-recipes.png")
	main._toggle_crafting()
	main.world.data.navigation.anchored = true
	main.world.data.players.host.area = "water"
	main.world.data.players.host.x = 160.0
	main.world.data.players.host.y = 190.0
	main.world.data.players.host.oxygen = 22.0
	await _shot("07-underwater.png")
	Inventory.add(main.world.data.players.host.bag, "fins", 1)
	main.world.data.players.host.x = 650.0
	main.world.data.players.host.y = 305.0
	await _shot("09-mineral-dive.png")
	var wreck: Dictionary = main.world.data.entities.wreck_00
	main.world.data.players.host.x = float(wreck.x) - 24
	main.world.data.players.host.y = float(wreck.y) - 10
	main.world.data.players.host.oxygen = 85.0
	await _shot("11-wreck.png")
	main.world.data.entities.wreck_00.active = false
	await _shot("12-searched-wreck.png")
	main.world.join("guest", "伙伴")
	main.world.data.players.host.area = "deck"
	main.world.data.players.guest.area = "deck"
	main.world.data.players.host.x = 448.0
	main.world.data.players.host.y = 302.0
	main.world.data.players.guest.x = 505.0
	main.world.data.players.guest.y = 302.0
	await _shot("13-partners.png")
	for shape in [Vector2i(960, 600), Vector2i(1280, 800), Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1440, 600)]:
		get_window().size = shape
		await get_tree().create_timer(0.2).timeout
		await _shot("14-deck-%dx%d.png" % [shape.x, shape.y])
		main._toggle_inventory()
		await _shot("15-bag-%dx%d.png" % [shape.x, shape.y])
		main._toggle_inventory()
		main.world.data.players.host.area = "water"
		main.world.data.players.guest.area = "water"
		main.world.data.players.host.x = 530.0
		main.world.data.players.host.y = 225.0
		main.world.data.players.guest.x = 605.0
		main.world.data.players.guest.y = 240.0
		await _shot("16-water-%dx%d.png" % [shape.x, shape.y])
		main.world.data.players.host.area = "deck"
		main.world.data.players.guest.area = "deck"
		main.world.data.players.host.x = 448.0
		main.world.data.players.host.y = 302.0
		main.world.data.players.guest.x = 505.0
		main.world.data.players.guest.y = 302.0
	await _gallery_07()
	var expected_bag: Array = main.world.data.players.host.bag.duplicate(true)
	var expected_structures: Dictionary = main.world.data.structures.duplicate(true)
	var expected_chests: Dictionary = main.world.data.chests.duplicate(true)
	await _click(main.return_title_button.get_global_rect().get_center())
	if not _check(main.mode == "menu" and not main.continue_button.disabled, "packaged save and return to title"):
		return
	await _click(main.continue_button.get_global_rect().get_center())
	if not _check(main.mode == "solo" and main.world.data.players.host.bag == expected_bag and main.world.data.structures == expected_structures and main.world.data.chests == expected_chests, "packaged continue preserves bag, facilities and chest contents"):
		return
	await _shot("33-continued.png")
	if not (await _homestead_gallery()):
		return
	print("UI GALLERY: %d visual fixtures, %d checks passed at %s" % [shots, checks, folder])
	get_tree().quit()

func _check(condition: bool, description: String) -> bool:
	checks += 1
	if not condition:
		printerr("FAIL GALLERY: ", description)
		get_tree().quit(1)
	return condition

func _click(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout

func _tap(code: int) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout

func _gallery_07() -> void:
	# Keep all original 27 fixtures above. These cases are visual arrangements,
	# while island_ui_checks and island_playthrough prove actual input/progression.
	get_window().size = Vector2i(1280, 800)
	main.set_physics_process(false)
	main.world.data.players.guest.online = false
	var player: Dictionary = main.world.data.players.host
	player.area = "deck"
	player.x = 480.0
	player.y = 360.0
	player.resting = false
	player.sleep_ready = false
	player.hook = {}
	player.fishing = {}
	player.hunger = 87.0
	player.thirst = 76.0
	player.oxygen = 100.0
	player.bag = _filled_slots({"wood": 20, "plastic": 20, "rope": 12, "leaf": 8, "paddle": 1, "anchor": 1}, 12)
	main.world.data.navigation.anchored = true
	main.world.data.navigation.push_x = 0.0
	main.world.data.navigation.push_y = 0.0
	main.world.data.structures = {}
	main.world.data.deck_tiles = []
	for gx: int in range(3, 12):
		for gy: int in range(2, 7):
			main.world.data.deck_tiles.append("%d,%d" % [gx, gy])
	for entry: Array in [
		["bedroll_0", "bedroll", Vector2(224, 160)], ["bed_0", "bed", Vector2(288, 160)],
		["purifier_0", "purifier", Vector2(416, 160)], ["grill_0", "grill", Vector2(544, 160)],
		["furnace_0", "furnace", Vector2(672, 160)], ["garden_0", "garden", Vector2(224, 288)],
		["kitchen_0", "kitchen", Vector2(352, 288)], ["legacy_orders", "orders", Vector2(480, 288)],
		["hatch_0", "hatch", Vector2(608, 288)],
	]:
		var point: Vector2 = entry[2]
		main.world.data.structures[str(entry[0])] = {"id": str(entry[0]), "kind": str(entry[1]), "x": point.x, "y": point.y, "remaining": 0.0, "output": ""}
	main.world.data.chests = {"chest_0": {"id": "chest_0", "name": "储物木箱", "x": 736.0, "y": 288.0, "slots": _filled_slots({"wood": 12, "meal": 3}, 16)}}
	main.world.data.crop = {"stage": 0, "progress": 0.0, "watered": false}
	main.toast_clock = 0.0
	await _shot("17-facilities-idle-empty-garden.png")
	for id: String in ["purifier_0", "grill_0", "furnace_0", "kitchen_0"]:
		main.world.data.structures[id].remaining = 7.0
		main.world.data.structures[id].output = {"purifier_0": "freshwater", "grill_0": "cooked_fish", "furnace_0": "ingot", "kitchen_0": "meal"}[id]
	main.world.data.crop = {"stage": 1, "progress": 0.0, "watered": false}
	await _shot("18-facilities-working-sprout.png")
	main.world.data.crop = {"stage": 1, "progress": 0.6, "watered": true}
	await _shot("19-watered-garden.png")
	for structure: Dictionary in main.world.data.structures.values():
		structure.remaining = 0.0
	main.world.data.crop = {"stage": 2, "progress": 1.0, "watered": true}
	await _shot("20-facilities-ready-ripe-garden.png")
	player.x = 320.0
	player.y = 352.0
	main.placement_recipe = "purifier"
	_fixture_pointer(Vector2(352, 416), "deck")
	await _shot("21-placement-valid.png")
	_fixture_pointer(Vector2(224, 160), "deck")
	await _shot("22-placement-invalid.png")
	main.placement_recipe = ""
	main._toggle_chart()
	main.chart_ui.selected_island = "island_home"
	await _shot("23-chart-first-island.png")
	main.chart_ui.selected_island = "island_mist"
	await _shot("24-chart-locked-island.png")
	main._toggle_chart()
	# A starting-size raft makes the real first shoreline legible at docking range.
	main.world.data.deck_tiles = []
	for gx: int in range(6, 9):
		for gy: int in range(3, 6):
			main.world.data.deck_tiles.append("%d,%d" % [gx, gy])
	main.world.data.structures = {"bedroll_0": {"id": "bedroll_0", "kind": "bedroll", "x": 416.0, "y": 224.0, "remaining": 0.0, "output": ""}}
	main.world.data.chests = {}
	var coast: Vector2 = Archipelago.island_position(main.world.data.chart) - Vector2(70, 0)
	main.world.data.navigation.x = coast.x
	main.world.data.navigation.y = coast.y
	player.x = 548.0
	player.y = 352.0
	main.toast_clock = 0.0
	await _shot("25-first-island-offshore.png")
	main._update_hud()
	main.context_ui.present(main.current_options, Vector2(625, 355))
	await _shot("26-docking-actions.png")
	main.context_ui.hide()
	player.area = "island"
	player.x = IslandState.DOCK.x + 35.0
	player.y = IslandState.DOCK.y
	main.world.data.chart.visited = true
	main.world.data.island = IslandState.create()
	await _shot("27-first-island-landing.png")
	await _tap(KEY_M)
	await _click(main.island_atlas.region_buttons.harbor.get_global_rect().get_center())
	var page_button: Button = main.island_atlas.page_buttons["1,0"]
	await _click(page_button.get_global_rect().get_center())
	var page_outline: StyleBox = page_button.get_theme_stylebox("normal")
	if not _check(main.island_atlas.visible and page_outline is StyleBoxFlat and not page_outline.draw_center, "packaged selected island page preserves the geography below its outline"):
		return
	await _shot("27a-island-map-outline.png")
	await _tap(KEY_ESCAPE)
	player.x = 466.0
	player.y = 365.0
	main.world.data.island.plots["15,10"] = {"crop": "seed", "growth": 4, "watered": false, "covered": false, "dead": false}
	await _shot("28-island-ripe-garden.png")
	main._toggle_inventory()
	await _shot("29-island-inventory.png")
	main._toggle_inventory()
	main.world.data.chests = {"chest_0": {"id": "chest_0", "name": "船上物资", "x": 544.0, "y": 288.0, "slots": _filled_slots({"leaf": 20}, 16)}}
	player.bag = _filled_slots({"leaf": 1}, 12)
	main._toggle_crafting()
	main.crafting_ui.selected_recipe = "rope"
	await _shot("30-island-personal-materials.png")
	main._toggle_crafting()
	player.x = 330.0
	player.y = 306.0
	main._update_hud()
	main.context_ui.present(main.current_options, Vector2(575, 410))
	await _shot("31-island-nearby-actions.png")
	main.context_ui.hide()
	main._toggle_pause()
	await _shot("32-island-pause-menu.png")

func _filled_slots(contents: Dictionary, capacity: int) -> Array:
	var slots: Array = Inventory.empty_slots(capacity)
	for item: String in contents:
		Inventory.add(slots, item, int(contents[item]))
	return slots

func _fixture_pointer(point: Vector2, area: String) -> void:
	main.pointer_position = main.view.get_global_transform_with_canvas() * main.view.world_to_screen(point, area)

func _shot(filename: String) -> void:
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	if screenshot.save_png(folder.path_join(filename)) != OK:
		push_error("Screenshot could not be saved")
		get_tree().quit(1)
	else:
		shots += 1


func _homestead_gallery() -> bool:
	var town = preload("res://scripts/island_town.gd")
	var map = preload("res://scripts/island_map.gd")
	main.set_physics_process(false)
	var player: Dictionary = main.world.data.players.host
	player.area = "island"
	player.bag = Inventory.empty_slots(12)
	main.world.data.minute = 720.0
	main.world.data.chart.visited = true
	var coast: Vector2 = Archipelago.island_position(main.world.data.chart)
	main.world.data.navigation.x = coast.x
	main.world.data.navigation.y = coast.y
	main.world.data.navigation.anchored = true
	var at: Vector2 = town.position("xu_an", 720)
	player.x = at.x
	player.y = at.y + 30
	main.active_tool = "hook"
	main._update_hud()
	await get_tree().process_frame
	await _click(main.view.get_global_transform_with_canvas() * main.view.world_to_screen(at, "island"))
	if not _check(main.dialogue_ui.visible and main.dialogue_ui.choice_button.visible, "packaged mayor opens rental dialogue by click"):
		return false
	await _shot("34-mayor.png")
	await _click(main.dialogue_ui.choice_button.get_global_rect().get_center())
	await _click(main.dialogue_ui.choice_button.get_global_rect().get_center())
	if not _check(main.world.data.island.homestead.rented and main.world.data.island.homestead.claimed.host and Inventory.count(player.bag, "seed") == 6, "packaged rental and personal gift settle through two explicit choices"):
		return false
	await _shot("35-gift.png")
	await _tap(KEY_ESCAPE)
	player.x = map.YARD_GATE.x + 50
	player.y = map.YARD_GATE.y
	await _shot("36-yard.png")
	for spot in [{"name":"39-native-market","at":Vector2(960,820)},{"name":"40-native-workshops","at":Vector2(1400,1260)},{"name":"41-native-fishery","at":Vector2(1400,430)},{"name":"42-native-dock","at":map.DOCK}]:
		player.x=spot.at.x
		player.y=spot.at.y
		await _shot(spot.name+".png")
	player.x=map.YARD_GATE.x+50
	player.y=map.YARD_GATE.y

	await _tap(KEY_M)
	await _click(main.island_atlas.region_buttons.harbor.get_global_rect().get_center())
	await _shot("37-yard-map.png")
	await _tap(KEY_ESCAPE)
	var home: Dictionary = main.world.data.island.homestead.duplicate(true)
	await _tap(KEY_ESCAPE)
	await _click(main.return_title_button.get_global_rect().get_center())
	if not _check(main.mode == "menu", "packaged leased yard saves through pause menu"):
		return false
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(main.save_path))
	if not _check(saved.version == 17 and saved.state.version == 17, "save envelope and world both use v17"):
		return false
	await _click(main.continue_button.get_global_rect().get_center())
	if not _check(main.mode == "solo" and main.world.data.island.homestead == home and Inventory.count(main.world.data.players.host.bag, "seed") == 6, "packaged Continue retains lease and exactly one personal gift"):
		return false
	await _shot("38-yard-continued.png")
	return true

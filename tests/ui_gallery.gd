extends Node
## Controlled visual fixtures only. The normal-input playthrough proves progression.
const Inventory = preload("res://scripts/inventory.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
const IslandState = preload("res://scripts/island_state.gd")
var main: Node
var folder := ""
var shots: int = 0

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
	main._start("solo", false)
	main.toast_clock = 0
	await _shot("02-deck.png")
	await get_tree().create_timer(2.0).timeout
	await _shot("10-deck-current.png")
	for item in {"wood": 16, "leaf": 9, "plastic": 7, "scrap": 3, "rope": 2, "cup": 1, "fish": 4, "seed": 5}:
		Inventory.add(main.world.data.players.host.bag, item, {"wood": 16, "leaf": 9, "plastic": 7, "scrap": 3, "rope": 2, "cup": 1, "fish": 4, "seed": 5}[item])
	main._toggle_inventory()
	await _shot("03-bag.png")
	main.inventory_ui._clicked("bag", 0, false)
	await _shot("03a-wood-detail.png")
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
	for shape in [Vector2i(1280, 800), Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1440, 600)]:
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
	print("UI GALLERY: %d visual fixtures captured at %s" % [shots, folder])
	get_tree().quit()

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

extends SceneTree
const World = preload("res://scripts/world_state.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Recipes = preload("res://scripts/recipes.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var world = World.new()
	world.join("host", "船长")
	world.join("guest", "伙伴")
	var player: Dictionary = world.data.players.host
	for item in {"wood": 20, "scrap": 12, "rope": 10, "stone": 12, "plastic": 12, "ingot": 8, "fiber": 8}:
		Inventory.add(player.bag, item, 20)
	for id in Recipes.WORKBENCH_RECIPES:
		var before: Dictionary = world.snapshot()
		world.action("host", "craft", {"recipe": id, "x": 544.0, "y": 224.0})
		_check(world.snapshot() == before, id + " cannot bypass missing station or spend materials")
	for id in ["cup", "rope", "harpoon", "axe", "pickaxe", "hoe", "watering_can", "scythe"]:
		player.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
		for material in Recipes.ALL[id].costs:
			Inventory.add(player.bag, material, int(Recipes.ALL[id].costs[material]))
		world.action("host", "craft", {"recipe": id})
		_check(Inventory.count(player.bag, str(Recipes.ALL[id].result)) == 1, id + " remains handcraftable before workbench")
	player.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	for material in Recipes.ALL.workbench.costs:
		Inventory.add(player.bag, material, int(Recipes.ALL.workbench.costs[material]))
	var before: Dictionary = world.snapshot()
	world.action("host", "craft", {"recipe": "workbench", "x": 416.0, "y": 224.0})
	_check(world.snapshot() == before, "occupied placement preserves all materials")
	world.action("host", "craft", {"recipe": "workbench", "x": 480.0, "y": 224.0})
	_check(world.data.structures.structure_0.kind == "workbench" and Inventory.total_count(player.bag) == 0, "handcraft station spends exactly six wood two scrap two rope on valid placement")
	_check(Recipes.nearby_workbench(world.data, "host") == "structure_0", "same-deck station is usable at boundary distance")
	world.data.players.guest.x = 515.0
	world.data.players.guest.y = 263.0
	_check(Recipes.station_available(world.data, "guest", "fins"), "guest can share the physical station")
	_check(world.interaction_options("guest").any(func(option): return option.action == "open_workbench"), "nearby shared workbench appears as clickable interaction")
	for slot in ["host", "guest"]:
		for item in Recipes.ALL.fins.costs:
			Inventory.add(world.data.players[slot].bag, item, int(Recipes.ALL.fins.costs[item]))
		world.action(slot, "craft", {"recipe": "fins"})
		_check(Inventory.count(world.data.players[slot].bag, "fins") == 1, slot + " makes own equipment from own materials")
	for area in ["island", "water"]:
		player.area = area
		player.x = 480.0
		player.y = 224.0
		before = world.snapshot()
		world.action("host", "craft", {"recipe": "fins"})
		_check(world.snapshot() == before and not Recipes.station_available(world.data, "host", "fins"), area + " cannot use a matching-coordinate raft station")
	player.area = "deck"
	player.x = 480.0
	player.y = 288.0
	world.data.players.guest.x = 530.0
	world.data.players.guest.y = 288.0
	_check(world.can_place("host", "furnace", 544.0, 352.0), "station allows nearby facility preview")
	world.action("host", "relocate", {"id": "structure_0", "from_x": 480.0, "from_y": 224.0, "x": 416.0, "y": 352.0})
	_check(world.data.structures.structure_0.x == 416.0 and not Recipes.station_available(world.data, "host", "fins"), "moving station immediately removes remote access")
	for item in Recipes.ALL.furnace.costs:
		Inventory.add(player.bag, item, int(Recipes.ALL.furnace.costs[item]))
	before = world.snapshot()
	world.action("host", "craft", {"recipe": "furnace", "x": 544.0, "y": 352.0})
	_check(world.snapshot() == before and not world.can_place("host", "furnace", 544.0, 352.0), "stale preview cannot build after station moved; no material loss")
	player.x = 453.0
	player.y = 337.0
	world.action("host", "craft", {"recipe": "furnace", "x": 544.0, "y": 352.0})
	_check(world.data.structures.size() == 3, "approaching moved station restores advanced facility crafting")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.snapshot()))
	var restored = World.new()
	_check(restored.restore(saved), "station and advanced facility round-trip through existing save format")
	_check(restored.data.structures == world.data.structures, "all station coordinates and facility states survive save")
	# A world saved before workbenches existed still restores with no free station.
	saved.structures.erase("structure_0")
	_check(restored.restore(saved) and not restored.data.structures.values().any(func(s): return s.kind == "workbench"), "old worlds keep existing advanced facilities and need no station migration")
	print("WORKBENCH CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

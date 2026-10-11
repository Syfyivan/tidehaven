extends SceneTree
## Focused authority checks with explicit positions/materials, not a playthrough.

const WorldState = preload("res://scripts/world_state.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
const IslandState = preload("res://scripts/island_state.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const Farming = preload("res://scripts/farming.gd")
const Skills = preload("res://tests/skill_test_helpers.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_landing_and_chart()
	_test_island_harvest()
	_test_farm_and_personal_crafting()
	_test_work_and_rest()
	_test_shore_fishing()
	_test_partner_anchor_guard()
	_test_save_and_migration()
	_test_offline_island_resume()
	_test_invalid_saves()
	_test_manual_hook()
	_test_selected_food()
	print("ISLAND TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _world(two := false):
	var world = WorldState.new()
	world.join("host", "船长")
	if two:
		world.join("guest", "伙伴")
	return world


func _place(world, slot: String, area: String, point: Vector2) -> void:
	world.data.players[slot].area = area
	world.data.players[slot].x = point.x
	world.data.players[slot].y = point.y


func _give(world, slot: String, item: String, amount := 1) -> void:
	Inventory.add(world.data.players[slot].bag, item, amount)


func _count(world, slot: String, item: String) -> int:
	return Inventory.count(world.data.players[slot].bag, item)


func _point(value: Dictionary) -> Vector2:
	return Vector2(float(value.x), float(value.y))


func _moored(two := false):
	var world = _world(two)
	var destination: Vector2 = Archipelago.island_position(world.data.chart)
	world.data.navigation.x = destination.x
	world.data.navigation.y = destination.y
	_give(world, "host", "anchor")
	world.action("host", "drop_anchor")
	for slot in ["host", "guest"]:
		_place(world, slot, "deck", Vector2(544, 352))
	return world


func _land(world, slot := "host") -> void:
	world.action(slot, "land", {"id": Archipelago.HOME_ID})


func _chest(world) -> void:
	world.data.chests.chest_0 = {"id": "chest_0", "name": "材料箱", "x": 544.0, "y": 224.0, "slots": Inventory.empty_slots(Inventory.CHEST_SIZE)}


func _canonical(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _farm_point() -> Vector2:
	for ty in range(9, 13):
		for tx in range(14, 19):
			var point := Vector2(tx * 32 + 16, ty * 32 + 16)
			if not IslandMap.tillable(point):
				continue
			var occupied := false
			for node: Dictionary in IslandMap.nodes_near(point).values():
				occupied = occupied or Farming.plot_key(_point(node)) == Farming.plot_key(point)
			if not occupied:
				return point
	return Vector2(-1, -1)


func _farm_action(world, verb: String, point: Vector2) -> void:
	world.action("host", verb, {"x": point.x, "y": point.y})


func _legacy_island(stage := 0, progress := 0.0, watered := false) -> Dictionary:
	return {"resources": {"palm_0": true, "palm_1": true, "seeds_0": true, "stone_0": true, "ore_0": true, "wood_1": true}, "crop": {"stage": stage, "progress": progress, "watered": watered}}


func _old_island_save(world, version: int, stage := 0, progress := 0.0, watered := false) -> Dictionary:
	var old: Dictionary = world.snapshot()
	old.version = version
	old.island = _legacy_island(stage, progress, watered)
	for player in old.players.values():
		player.erase("can_water")
		if version < 8:
			player.erase("activity")
	if version < 8:
		old.navigation.erase("moored")
	return old


func _test_landing_and_chart() -> void:
	var world = _world()
	_check(world.data.version == 10 and Archipelago.origin(world.data.chart) == Vector2.ZERO and not world.data.chart.visited, "v9 creates a fixed chart origin without claiming an island visit")
	_check(Archipelago.island_position(world.data.chart) == Vector2(520, 120), "first docking target uses the agreed 520,120 navigation offset")
	_place(world, "host", "deck", Vector2(544, 352))
	var before: Dictionary = world.snapshot()
	world.action("host", "land")
	_check(world.snapshot() == before, "deck edge alone cannot land from outside docking range")
	world.data.navigation.x = 520.0
	world.data.navigation.y = 120.0
	before = world.snapshot()
	world.action("host", "land")
	_check(world.snapshot() == before, "being in range still requires a deployed anchor")
	_give(world, "host", "anchor")
	world.action("host", "drop_anchor")
	_place(world, "host", "deck", Vector2(480, 288))
	before = world.snapshot()
	world.action("host", "land")
	_check(world.snapshot() == before, "an anchored player must walk to the deck edge before landing")
	_place(world, "host", "deck", Vector2(544, 352))
	world.data.navigation.x = 520.0 - Archipelago.DOCK_RADIUS - 0.1
	before = world.snapshot()
	world.action("host", "land")
	_check(world.snapshot() == before, "the first point outside the 110-unit docking radius is rejected")
	world.data.navigation.x = 520.0 - Archipelago.DOCK_RADIUS
	var bag: Array = world.data.players.host.bag.duplicate(true)
	_land(world)
	_check(world.data.players.host.area == "island" and _point(world.data.players.host) == IslandState.DOCK and world.data.chart.visited and world.data.players.host.bag == bag, "landing at the exact radius reaches the dock and preserves personal belongings")
	_check(Archipelago.land_walkable(Vector2(132, 380)) and not Archipelago.land_contains(Vector2(132, 380)) and not Archipelago.land_walkable(Vector2(90, 380)), "the dock extends walkable land without admitting surrounding water")
	before = world.snapshot()
	for id in ["island_mist", "island_reef", "island_wind", "unknown"]:
		world.action("host", "set_destination", {"id": id})
		world.action("host", "land", {"id": id})
	_check(world.snapshot() == before, "locked and forged islands cannot become destinations or teleport targets")
	_give(world, "host", "compass")
	world.data.chart.destination = ""
	var position: Vector2 = _point(world.data.navigation)
	world.action("host", "set_destination", {"id": "island_home"})
	_check(world.data.chart.destination == "island_home" and _point(world.data.navigation) == position and _point(world.data.players.host) == IslandState.DOCK, "setting a chart marker changes no raft or player position")
	_place(world, "host", "island", IslandState.FARM)
	before = world.snapshot()
	world.action("host", "board_raft")
	_check(world.snapshot() == before, "boarding requires returning to the actual island dock")


func _test_island_harvest() -> void:
	var world = _moored(true)
	_land(world)
	_land(world, "guest")
	for slot in ["host", "guest"]:
		_place(world, slot, "island", _point(IslandMap.node("palm_0")))
		_give(world, slot, "axe")
	var wood_capacity := (Inventory.BAG_SIZE - 1) * Inventory.STACK_LIMIT
	_give(world, "host", "wood", wood_capacity)
	var before: Dictionary = world.snapshot()
	world.action("host", "gather_island", {"id": "palm_0"})
	_check(_count(world, "host", "wood") == wood_capacity and world.data.players.host.activity.get("duration") == 6.0, "island wood starts a real six-second axe operation without an immediate reward")
	Skills.finish_activity(world, "host")
	_check(world.data.players.host.bag == before.players.host.bag and world.data.players.host.stamina == before.players.host.stamina and IslandState.active(world.data.island, "palm_0", world.data.day), "completed full-pack gathering loses neither island wood nor stamina")
	Inventory.remove(world.data.players.host.bag, "wood", 3)
	var energy: float = world.data.players.host.stamina
	world.action("host", "gather_island", {"id": "palm_0"})
	world.action("guest", "gather_island", {"id": "palm_0"})
	Skills.finish_activity(world, "host")
	_check(_count(world, "host", "wood") == wood_capacity and world.data.players.host.stamina == energy - 6 and not IslandState.active(world.data.island, "palm_0", world.data.day), "three island wood fill exact remaining space for six actor stamina, leaving a regrowth date")
	_check(_count(world, "guest", "wood") == 0 and world.data.players.guest.stamina == 100.0, "a racing axe operation grants neither duplicate wood nor a failed-collector stamina cost")
	before = world.snapshot()
	world.action("guest", "gather_island", {"id": "palm_0"})
	world.action("host", "gather_island", {"id": "palm_0"})
	_check(world.snapshot() == before, "replayed shared-node actions cannot bypass the depleted date")
	_place(world, "guest", "island", _point(IslandMap.node("ore_0")))
	_give(world, "guest", "pickaxe")
	energy = world.data.players.guest.stamina
	world.action("guest", "gather_island", {"id": "ore_0"})
	Skills.finish_activity(world, "guest")
	_check(_count(world, "guest", "ore") == 2 and world.data.players.guest.stamina == energy - 8 and not IslandState.active(world.data.island, "ore_0", world.data.day), "four-second pickaxe mining grants two ore only to its collector and costs eight stamina")
	before = world.snapshot()
	for args in [{"id": "palm_1"}, {"id": "fish_00"}, {"id": 8}, {}]:
		world.action("guest", "gather_island", args)
	world.action("intruder", "gather_island", {"id": "palm_1"})
	_check(world.snapshot() == before, "distant, underwater, malformed and unauthorized resource targets are rejected atomically")


func _test_farm_and_personal_crafting() -> void:
	var world = _moored(true)
	_chest(world)
	Inventory.add(world.data.chests.chest_0.slots, "seed", 3)
	Inventory.add(world.data.chests.chest_0.slots, "leaf", 4)
	var chest_slots: Array = world.data.chests.chest_0.slots.duplicate(true)
	var point := _farm_point()
	_land(world)
	_place(world, "host", "island", point)
	_give(world, "host", "hoe")
	_give(world, "host", "watering_can")
	_farm_action(world, "till", point)
	var key := Farming.plot_key(point)
	_check(world.data.island.plots.has(key), "a carried hoe prepares a selected real grass cell")
	var before: Dictionary = world.snapshot()
	_farm_action(world, "plant", point)
	world.action("host", "craft", {"recipe": "rope"})
	_check(world.snapshot() == before and world.data.chests.chest_0.slots == chest_slots, "island farming and handcrafting cannot consume distant raft-chest materials")
	_give(world, "host", "leaf", 2)
	world.action("host", "craft", {"recipe": "rope"})
	_check(_count(world, "host", "rope") == 1 and _count(world, "host", "leaf") == 0 and world.data.chests.chest_0.slots == chest_slots, "island handcrafting consumes only personally carried ingredients")
	before = world.snapshot()
	world.action("host", "craft", {"recipe": "foundation", "x": 352.0, "y": 288.0})
	_check(world.snapshot() == before, "a player on the island cannot remotely construct raft tiles")
	_give(world, "host", "seed")
	_place(world, "host", "island", Vector2(640, 430))
	_farm_action(world, "refill_can", Vector2(640, 430))
	_place(world, "host", "island", point)
	_farm_action(world, "plant", point)
	_farm_action(world, "water", point)
	var plot: Dictionary = world.data.island.plots[key]
	_check(plot.crop == "seed" and plot.growth == 0 and plot.watered and _count(world, "host", "seed") == 0 and world.data.players.host.can_water == 19 and world.data.crop.stage == 0, "island plot uses its own seed and measured water, separate from raft planting")
	_place(world, "host", "island", IslandState.DOCK)
	world.action("host", "board_raft")
	world.tick(65.1)
	_check(plot.growth == 0 and plot.watered and not Farming.mature(plot), "elapsed seconds never mature island crops while both players are on the raft")
	for night in 4:
		if night > 0:
			_place(world, "host", "island", point)
			_farm_action(world, "water", point)
		_place(world, "host", "island", IslandState.CAMP)
		_place(world, "guest", "deck", Vector2(416, 288))
		world.action("host", "sleep")
		world.action("guest", "sleep")
		_check(world.data.day == night + 2 and plot.growth == night + 1 and not plot.watered, "camp and deck partner end one day together and each watered night grows the plot once")
	_check(Farming.mature(plot), "four watered nights mature the spring crop through the shared sleep rule")
	_place(world, "host", "deck", Vector2(480, 288))
	before = world.snapshot()
	_farm_action(world, "harvest", point)
	_check(world.snapshot() == before, "a deck player cannot harvest the remote island farm")
	_place(world, "host", "deck", Vector2(544, 352))
	_land(world)
	_place(world, "host", "island", point)
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	_give(world, "host", "wood", WorldState.BAG_CAPACITY)
	world.data.players.host.bag[0] = {}
	before = world.snapshot()
	_farm_action(world, "harvest", point)
	_check(world.snapshot() == before and Farming.mature(plot), "one free slot cannot partially collect vegetables while losing the returned seed")
	world.data.players.host.bag[1] = {}
	_farm_action(world, "harvest", point)
	_check(_count(world, "host", "veg") == 2 and _count(world, "host", "seed") == 1 and plot.crop.is_empty() and world.data.chests.chest_0.slots == chest_slots, "two available slots receive the complete crop exactly once without touching ship stores")


func _test_shore_fishing() -> void:
	var world = _moored(true)
	_land(world)
	_place(world, "host", "island", IslandState.FISHING)
	_give(world, "guest", "rod")
	var before: Dictionary = world.snapshot()
	world.action("host", "cast")
	_check(world.snapshot() == before, "shore fishing cannot borrow the partner's rod")
	_give(world, "host", "rod")
	_place(world, "host", "island", IslandState.FISHING + Vector2(55, 0))
	before = world.snapshot()
	world.action("host", "cast")
	_check(world.snapshot() == before, "an island point outside the 54-unit fishing spot cannot cast")
	_place(world, "host", "island", IslandState.FISHING + Vector2(54, 0))
	var energy: float = world.data.players.host.stamina
	world.action("host", "cast")
	_check(not world.data.players.host.fishing.is_empty() and world.data.players.host.stamina == energy - 2, "the fishing boundary accepts a personal rod and spends exactly two stamina")
	var rolled: String = world.data.players.host.fishing.get("result", "fish")
	before = world.snapshot()
	world.action("host", "reel")
	_check(world.snapshot() == before, "shore reeling before the natural wait cannot grant a catch")
	_give(world, "host", "wood", (Inventory.BAG_SIZE - 1) * Inventory.STACK_LIMIT)
	world.tick(WorldState.FISHING_SECONDS + 0.1)
	before = world.snapshot()
	world.action("host", "reel")
	_check(world.snapshot() == before and world.data.players.host.fishing.result == rolled, "a full shore-fishing bag keeps the originally rolled catch on the line")
	Inventory.remove(world.data.players.host.bag, "wood", Inventory.STACK_LIMIT)
	var count_before := _count(world, "host", rolled)
	world.action("host", "reel")
	_check(_count(world, "host", rolled) == count_before + 1 and world.data.players.host.fishing.is_empty(), "shore catch can be collected after making space with no reroll")
	before = world.snapshot()
	world.action("host", "reel")
	_check(world.snapshot() == before, "replaying a completed shore reel cannot duplicate its item")
	world.action("host", "cast")
	_place(world, "host", "island", IslandState.FARM)
	world.tick(0.1)
	_check(world.data.players.host.fishing.is_empty(), "walking away from the shore fishing point cancels the active line")


func _test_partner_anchor_guard() -> void:
	var world = _moored(true)
	_land(world, "guest")
	var before: Dictionary = world.snapshot()
	world.action("host", "raise_anchor")
	_check(world.snapshot() == before and world.data.navigation.anchored, "a guest on the island prevents the deck host from taking away the raft")
	_land(world)
	before = world.snapshot()
	world.action("guest", "raise_anchor")
	_check(world.snapshot() == before, "a landed player cannot operate the raft anchor remotely")
	world.action("host", "board_raft")
	before = world.snapshot()
	world.action("host", "raise_anchor")
	_check(world.snapshot() == before, "one player's return is insufficient while the other remains ashore")
	world.action("guest", "board_raft")
	world.action("host", "raise_anchor")
	_check(not world.data.navigation.anchored and world.data.players.host.area == "deck" and world.data.players.guest.area == "deck" and _count(world, "host", "anchor") == 1 and _count(world, "guest", "anchor") == 0, "all players returning permits recovery of exactly the one deployed anchor")


func _test_save_and_migration() -> void:
	var world = _moored(true)
	_chest(world)
	world.data.chests.chest_0.slots[8] = {"item": "fish", "count": 7}
	_give(world, "guest", "reinforced_hook")
	_land(world)
	_place(world, "host", "island", _point(IslandMap.node("ore_0")))
	_give(world, "host", "pickaxe")
	world.action("host", "gather_island", {"id": "ore_0"})
	Skills.finish_activity(world, "host")
	var point := _farm_point()
	_place(world, "host", "island", point)
	for item in ["seed", "hoe", "watering_can"]:
		_give(world, "host", item)
	world.data.players.host.can_water = 20
	_farm_action(world, "till", point)
	_farm_action(world, "plant", point)
	_farm_action(world, "water", point)
	world.tick(4.5)
	var saved: Dictionary = _canonical(world.snapshot())
	var loaded = WorldState.new()
	_check(loaded.restore(saved) and loaded.data.version == 10 and loaded.data.players.host.area == "island" and _point(loaded.data.players.host) == point, "v9 JSON restoration retains a valid landed player's actual location")
	_check(loaded.data.island == world.data.island, "JSON roundtrip normalizes regrowth days to the same integer-valued island state")
	loaded.join("host", "船长")
	_check(loaded.data.players.host.area == "island" and _point(loaded.data.players.host) == point, "Continue joins the saved island position while the raft is still safely docked")
	for field in ["chart", "island", "navigation", "deck_tiles", "structures", "chests"]:
		_check(_canonical(loaded.data[field]) == saved[field], "v9 JSON restores exact persistent " + field)
	_check(loaded.data.players.host.bag == world.data.players.host.bag and loaded.data.players.guest.bag == world.data.players.guest.bag and loaded.data.players.host.can_water == 19, "v9 restoration preserves both slot layouts, farm tools and the personal water counter")
	var old_world = _world(true)
	_chest(old_world)
	old_world.data.players.host.bag[7] = {"item": "fish", "count": 5}
	old_world.data.players.guest.bag[2] = {"item": "paddle", "count": 1}
	old_world.data.chests.chest_0.slots[11] = {"item": "seed", "count": 19}
	old_world.data.entities.ore_00.active = false
	old_world.data.navigation.x = 234.75
	old_world.data.navigation.y = -91.5
	old_world.data.navigation.distance = 980.125
	var old: Dictionary = old_world.snapshot()
	old.version = 6
	for player in old.players.values():
		player.erase("activity")
		player.erase("can_water")
	old.navigation.erase("moored")
	old.erase("chart")
	old.erase("island")
	_check(loaded.restore(_canonical(old)) and Archipelago.origin(loaded.data.chart) == Vector2(234.75, -91.5) and not loaded.data.chart.visited, "v6 migration creates the chart once at the current sailing position")
	for field in ["deck_tiles", "structures", "chests", "entities"]:
		_check(_canonical(loaded.data[field]) == _canonical(old[field]), "v6 migration leaves exact " + field + " unchanged")
	var expected_navigation: Dictionary = old.navigation.duplicate(true)
	expected_navigation.moored = false
	_check(_canonical(loaded.data.navigation) == _canonical(expected_navigation), "v6 migration preserves every old navigation field while introducing only the unset mooring flag")
	_check(loaded.data.players.host.bag == old.players.host.bag and loaded.data.players.guest.bag == old.players.guest.bag and loaded.data.island == IslandState.create() and loaded.data.players.host.can_water == 0, "v6 migration keeps slot indices and quantities while creating empty sparse island state and water counters")
	var origin: Vector2 = Archipelago.origin(loaded.data.chart)
	loaded.data.navigation.x += 80.0
	var current: Dictionary = _canonical(loaded.snapshot())
	_check(loaded.restore(current) and Archipelago.origin(loaded.data.chart) == origin and Archipelago.island_position(loaded.data.chart) == origin + Vector2(520, 120), "subsequent v9 loads keep the original island anchor instead of moving it with the raft")
	for version in [7, 8]:
		old = _old_island_save(old_world, version, 1 if version == 7 else 2, 0.5 if version == 7 else 1.0, true)
		old.island.resources.ore_0 = false
		old.island.resources.palm_0 = false
		_check(loaded.restore(_canonical(old)) and loaded.data.version == 10 and loaded.data.island.depleted.ore_0 == old.day + 1 and loaded.data.island.depleted.palm_0 == old.day + 1 and loaded.data.island.plots.size() == 1, "actual v%d island resources/crop shape migrates to sparse depletion and one existing crop" % version)
		var migrated: Dictionary = loaded.data.island.plots.values()[0]
		_check(migrated.crop == "seed" and migrated.growth == (2 if version == 7 else 4) and migrated.watered and loaded.data.players.host.can_water == 0 and loaded.data.players.host.bag == old.players.host.bag and loaded.data.players.guest.bag == old.players.guest.bag, "legacy crop progress, original bags and a new empty water counter survive v%d migration" % version)
		var migrated_island: Dictionary = _canonical(loaded.data.island)
		_check(loaded.restore(_canonical(loaded.snapshot())) and _canonical(loaded.data.island) == migrated_island, "migrated v%d crop is on legitimate soil and survives a second v9 JSON restore without replenishment" % version)


func _test_offline_island_resume() -> void:
	var world = _moored(true)
	_land(world, "guest")
	_give(world, "guest", "wood", 3)
	var loaded = WorldState.new()
	_check(loaded.restore(_canonical(world.snapshot())) and not loaded.data.players.guest.online and loaded.data.players.guest.area == "island", "restore retains the absent partner's island location with that slot offline")
	loaded.join("host", "船长")
	loaded.action("host", "raise_anchor")
	loaded.tick(60.0)
	var saved: Dictionary = _canonical(loaded.snapshot())
	_check(not loaded.data.navigation.anchored and not Archipelago.within_docking_range(loaded.data.chart, loaded.data.navigation) and _count(loaded, "host", "anchor") == 1 and loaded.data.players.guest.area == "island", "offline island slot does not block the present player's recovered-anchor sailing beyond docking range")
	_check(world.restore(saved) and _canonical(world.data.navigation) == saved.navigation and world.data.players.guest.area == "island" and not world.data.players.guest.online and _count(world, "guest", "wood") == 3, "unanchored save reloads with the offline island location and both bags preserved")
	world.join("guest", "伙伴")
	_check(world.data.players.guest.area == "deck" and world.data.players.guest.online and _count(world, "guest", "wood") == 3, "the absent partner safely rejoins the travelled raft carrying the same island supplies")


func _test_invalid_saves() -> void:
	var world = _moored()
	_land(world)
	var baseline: Dictionary = world.snapshot()
	var invalid: Array = []
	for field in ["chart", "island"]:
		for value in [null, [], {}, 1]:
			var bad: Dictionary = baseline.duplicate(true)
			bad[field] = value
			invalid.append({"state": bad, "label": field + " rejects wrong shape " + str(value)})
	for change in [{"key": "origin_x", "value": NAN}, {"key": "origin_y", "value": INF}, {"key": "origin_x", "value": true}, {"key": "origin_y", "value": 1.0e16}, {"key": "visited", "value": 1}, {"key": "destination", "value": "island_mist"}, {"key": "destination", "value": []}]:
		var bad: Dictionary = baseline.duplicate(true)
		bad.chart[change.key] = change.value
		invalid.append({"state": bad, "label": "chart rejects invalid " + str(change.key)})
	var farm_key := Farming.plot_key(_farm_point())
	for change in [{"growth": -1}, {"growth": 1.5}, {"growth": NAN}, {"growth": 5}, {"crop": "unknown"}, {"watered": 1}, {"covered": true, "dead": true}]:
		var bad: Dictionary = baseline.duplicate(true)
		var plot := Farming.new_plot()
		plot.crop = "seed"
		for field in change:
			plot[field] = change[field]
		bad.island.plots[farm_key] = plot
		invalid.append({"state": bad, "label": "island plot rejects impossible crop or growth fields"})
	for version in [7, 8]:
		for crop in [{"stage": 3, "progress": 0.0, "watered": false}, {"stage": 1.5, "progress": 0.0, "watered": false}, {"stage": 1, "progress": NAN, "watered": true}, {"stage": 1, "progress": 0.5, "watered": false}, {"stage": 0, "progress": 0.0, "watered": true}, {"stage": 2, "progress": 0.5, "watered": true}]:
			var bad := _old_island_save(world, version)
			bad.island.crop = crop
			invalid.append({"state": bad, "label": "legacy v%d crop still rejects impossible growth states" % version})
	var bad: Dictionary = baseline.duplicate(true)
	bad.chart.extra = 1
	invalid.append({"state": bad, "label": "chart rejects extra fields"})
	bad = baseline.duplicate(true)
	bad.chart.erase("origin_y")
	invalid.append({"state": bad, "label": "chart requires both origin coordinates"})
	bad = baseline.duplicate(true)
	bad.island.depleted.ore_0 = true
	invalid.append({"state": bad, "label": "resource regrowth date cannot be a boolean"})
	bad = baseline.duplicate(true)
	bad.island.erase("plots")
	invalid.append({"state": bad, "label": "island requires its sparse plot dictionary"})
	bad = baseline.duplicate(true)
	bad.island.depleted.forged = 2
	invalid.append({"state": bad, "label": "island rejects invented resource IDs"})
	for counter in [-1, 21, 0.5, true, INF, "20"]:
		bad = baseline.duplicate(true)
		bad.players.host.can_water = counter
		invalid.append({"state": bad, "label": "personal watering capacity requires an integer between zero and twenty"})
	bad = baseline.duplicate(true)
	bad.island.plots["0,0"] = Farming.new_plot()
	invalid.append({"state": bad, "label": "saved farm soil cannot occupy ocean terrain"})
	bad = baseline.duplicate(true)
	bad.island.extra = 0
	invalid.append({"state": bad, "label": "island rejects extra fields"})
	bad = baseline.duplicate(true)
	bad.chart.visited = false
	invalid.append({"state": bad, "label": "a landed player requires the visited island flag"})
	bad = baseline.duplicate(true)
	bad.players.host.x = 30.0
	bad.players.host.y = 30.0
	invalid.append({"state": bad, "label": "a landed player cannot restore outside island and dock bounds"})
	bad = baseline.duplicate(true)
	bad.navigation.anchored = false
	invalid.append({"state": bad, "label": "an online landed player cannot restore beside an unanchored departing raft"})
	bad = baseline.duplicate(true)
	bad.navigation.x = Archipelago.island_position(bad.chart).x - Archipelago.DOCK_RADIUS - 0.1
	invalid.append({"state": bad, "label": "an online landed player requires the anchored raft to remain in docking range"})
	bad = baseline.duplicate(true)
	bad.version = 6
	bad.players.host.area = "deck"
	bad.players.host.x = 544.0
	bad.players.host.y = 352.0
	invalid.append({"state": bad, "label": "v6 data cannot carry undeclared v7 chart or island fields"})
	for candidate in invalid:
		_check(not world.restore(candidate.state) and world.snapshot() == baseline, str(candidate.label) + "; live state is unchanged")


func _test_manual_hook() -> void:
	# Direction collision/races/full bags are covered in sailing_skill_checks.
	var world = _world()
	world.action("host", "hook", {"x": -1.0, "y": 0.0})
	_check(world.data.players.host.hook.phase == "out", "direction cast begins outgoing leg")
	world.action("host", "pull_hook")
	world.tick(0.1)
	_check(world.data.players.host.hook.is_empty(), "an immediate empty return ends without a target lock")
	var before: Dictionary = world.snapshot()
	world.action("host", "hook", {"id": "drift_06", "manual": 1})
	_check(world.snapshot() == before, "obsolete targeted hook requests cannot bypass direction mechanics")


func _test_selected_food() -> void:
	var world = _world()
	_give(world, "host", "meal", 2)
	_give(world, "host", "cooked_fish", 2)
	world.data.players.host.hunger = 10.0
	world.data.players.host.stamina = 10.0
	world.action("host", "eat", {"item": "cooked_fish"})
	_check(_count(world, "host", "meal") == 2 and _count(world, "host", "cooked_fish") == 1 and world.data.players.host.hunger == 45.0 and world.data.players.host.stamina == 55.0, "explicitly choosing cooked fish consumes fish even while a meal is also carried")
	world.action("host", "eat", {"item": "meal"})
	_check(_count(world, "host", "meal") == 1 and _count(world, "host", "cooked_fish") == 1 and world.data.players.host.hunger == 95.0, "explicit meal uses its own quantity and hunger reward")
	var before: Dictionary = world.snapshot()
	for value in ["fish", "wood", "unknown", 1, [], {}]:
		world.action("host", "eat", {"item": value})
	_check(world.snapshot() == before, "invalid food selections never consume inventory or restore vitals")
	world.action("host", "eat")
	_check(_count(world, "host", "meal") == 0 and _count(world, "host", "cooked_fish") == 1, "the unqualified eat action retains the default meal-first behavior")


func _test_work_and_rest() -> void:
	var world = _moored(true)
	_land(world)
	_place(world, "host", "island", Vector2(326, 329))
	_give(world, "host", "axe")
	world.action("host", "gather_island", {"id": "palm_0"})
	_check(not world.data.players.host.activity.is_empty(), "camp overlap starts a real tree activity")
	world.action("host", "rest")
	world.tick(7)
	_check(world.data.players.host.resting and world.data.players.host.activity.is_empty() and _count(world, "host", "wood") == 0 and IslandState.active(world.data.island, "palm_0", world.data.day), "resting cancels timber work and cannot simultaneously recover and award resources")
	world.action("host", "sleep")
	_check(world.data.players.host.sleep_ready, "one of two players can prepare at island camp")
	_place(world, "host", "island", _farm_point())
	_give(world, "host", "hoe")
	var at := _farm_point()
	world.action("host", "till", {"x": at.x, "y": at.y})
	_check(not world.data.players.host.sleep_ready and not world.data.players.host.resting, "successful farm work cancels prior readiness to finish the day")
	_place(world, "guest", "island", IslandState.CAMP)
	world.action("guest", "sleep")
	_check(int(world.data.day) == 1, "partner cannot end the day after the first player resumed farming")

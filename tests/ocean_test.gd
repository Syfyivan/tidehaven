extends SceneTree

const WorldState = preload("res://scripts/world_state.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Skills = preload("res://tests/skill_test_helpers.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_scattered_start()
	_test_current_and_recycling()
	_test_wreck_search()
	_test_save_migration()
	print("OCEAN TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _world():
	var world = WorldState.new()
	world.join("host", "船长")
	world.join("guest", "伙伴")
	return world


func _place(world, slot: String, area: String, point: Vector2) -> void:
	if area == "water":
		world.data.navigation.anchored = true
	world.data.players[slot].area = area
	world.data.players[slot].x = point.x
	world.data.players[slot].y = point.y


func _count(world, slot: String, item: String) -> int:
	return Inventory.count(world.data.players[slot].bag, item)


func _point(item: Dictionary) -> Vector2:
	return Vector2(float(item.x), float(item.y))


func _test_scattered_start() -> void:
	var world = _world()
	world._rng.seed = 105
	world.data.drift = world._new_drift(world.data.deck_tiles)
	var y_values: Dictionary = {}
	var x_values: Array = []
	var outside := true
	for item in world.data.drift.values():
		y_values[float(item.y)] = true
		x_values.append(float(item.x))
		outside = outside and not world.deck_rect().has_point(_point(item))
	x_values.sort()
	var smallest := INF
	var largest := 0.0
	for index in range(1, x_values.size()):
		var gap: float = x_values[index] - x_values[index - 1]
		smallest = minf(smallest, gap)
		largest = maxf(largest, gap)
	_check(y_values.size() >= 10 and largest - smallest > 30.0, "salvage starts scattered in both axes, without two rows or uniform gaps")
	_check(outside and world.data.drift.size() == 16, "all starting salvage is visible outside the actual raft")
	var ready := true
	for seed_value in range(12):
		world._rng.seed = seed_value
		world.data.drift = world._new_drift(world.data.deck_tiles)
		for index in range(5):
			var item: Dictionary = world.data.drift["drift_%02d" % index]
			ready = ready and _point(item).distance_to(Vector2(480, 288)) <= WorldState.HOOK_DISTANCE
	_check(ready, "wood, leaf, plastic, scrap and a barrel are immediately hookable across different starting scatter")


func _test_current_and_recycling() -> void:
	var world = _world()
	world._rng.seed = 109
	world.data.drift = world._new_drift(world.data.deck_tiles)
	var before: Dictionary = world.snapshot()
	world.tick(0.2)
	var forward := true
	var velocities: Dictionary = {}
	for id in world.data.drift:
		var item: Dictionary = world.data.drift[id]
		var dx := float(item.x) - float(before.drift[id].x)
		forward = forward and dx >= -0.001
		velocities[snappedf(dx, 0.01)] = true
	_check(forward and velocities.size() > 4, "a shared current carries salvage forward at varied speeds")
	var drift: Dictionary = world.data.drift.drift_00
	drift.x = 480.0
	drift.y = 288.0
	world.tick(0.1)
	_check(not world.deck_rect().has_point(_point(drift)), "a floor built over salvage cannot hide it permanently")
	var clear := true
	for step in 300:
		world.tick(0.2)
		for item in world.data.drift.values():
			clear = clear and not world.deck_rect().has_point(_point(item))
	_check(clear, "flow curves around the raft throughout repeated host ticks")
	var entry_y: Dictionary = {}
	var delays: Dictionary = {}
	var recycled_offscreen := true
	for cycle in 8:
		drift.active = true
		drift.x = 979.9
		drift.y = 50.0
		world.tick(0.1)
		var delay := float(drift.respawn)
		delays[delay] = true
		recycled_offscreen = recycled_offscreen and not drift.active and delay >= 2.0 and delay <= 7.0
		world.tick(delay + 0.01)
		entry_y[float(drift.y)] = true
		recycled_offscreen = recycled_offscreen and drift.active and float(drift.x) < 0.0 and float(drift.y) >= 16.0 and float(drift.y) <= 544.0
	_check(recycled_offscreen and entry_y.size() > 4 and delays.size() > 4, "spent salvage waits varied intervals and re-enters beyond the left edge at varied heights")
	var fish: Dictionary = world.data.entities.fish_00
	var fish_start := _point(fish)
	world.tick(1.0)
	_check(_point(fish).distance_to(fish_start) > 0.01 and float(fish.x) >= 40.0 and float(fish.x) <= 860.0 and float(fish.y) >= 35.0 and float(fish.y) <= 520.0, "fish keep swimming within underwater bounds")
	fish.active = false
	fish_start = _point(fish)
	world.tick(1.0)
	_check(_point(fish) == fish_start, "caught fish remain depleted rather than continuing their movement")


func _test_wreck_search() -> void:
	var world = _world()
	var wreck: Dictionary = world.data.entities.wreck_00
	var before: Dictionary = world.snapshot()
	world.action("host", "search_wreck", {"id": "wreck_00"})
	_check(world.snapshot() == before, "deck players cannot search underwater wrecks")
	_place(world, "host", "water", _point(wreck))
	_place(world, "guest", "water", _point(wreck))
	var offered := false
	for option in world.interaction_options("host"):
		offered = offered or (option.action == "search_wreck" and option.args.id == "wreck_00")
	_check(offered, "a nearby wreck exposes a normal interaction with its shared entity ID")
	world.action("host", "search_wreck", {"id": "wreck_00"})
	world.action("guest", "search_wreck", {"id": "wreck_00"})
	_check(wreck.active and _count(world, "host", "treasure") == 0, "starting a search leaves the wreck intact until seven seconds elapse")
	Skills.finish_activity(world, "host")
	_check(_count(world, "host", "treasure") == 1 and _count(world, "guest", "treasure") == 0 and not wreck.active, "racing divers recover one treasure from one wreck exactly once")
	world.action("host", "open_treasure", {"index": 0})
	_check(_count(world, "host", "treasure") == 0 and _count(world, "host", "wood") == 3 and _count(world, "host", "seed") == 2 and _count(world, "host", "fish") == 1, "recovered treasure opens through the existing inventory rule into all its supplies")
	wreck = world.data.entities.wreck_01
	_place(world, "host", "water", _point(wreck))
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Inventory.add(world.data.players.host.bag, "wood", WorldState.BAG_CAPACITY)
	before = world.snapshot()
	Skills.gather(world, "host", "search_wreck", "wreck_01")
	_check(world.data.players.host.bag == before.players.host.bag and world.data.players.host.stamina == before.players.host.stamina and wreck.active, "a completed full-pack search leaves the wreck, inventory and stamina untouched")
	world.data.players.host.bag[0] = {"item": "treasure", "count": 19}
	Skills.gather(world, "host", "search_wreck", "wreck_01")
	_check(_count(world, "host", "treasure") == 20 and not wreck.active, "a recovered chest stacks into existing capacity without needing an empty slot")
	_place(world, "host", "water", Vector2(120, 100))
	before = world.snapshot()
	for args in [{"id": "wreck_00"}, {"id": "fish_00"}, {"id": "invented"}, {"id": 5}, {}]:
		world.action("host", "search_wreck", args)
	world.action("intruder", "search_wreck", {"id": "wreck_00"})
	_check(world.snapshot() == before, "distant, depleted and forged wreck requests leave the entire world unchanged")
	world.leave("guest")
	_place(world, "host", "deck", Vector2(416, 288))
	world.action("host", "sleep")
	_check(world.data.day == 2 and world.data.entities.wreck_00.active and world.data.entities.wreck_01.active, "the next day replenishes both seabed wrecks")


func _v4_snapshot(world) -> Dictionary:
	var saved: Dictionary = world.snapshot()
	saved.version = 4
	saved.erase("navigation")
	saved.erase("chart")
	saved.erase("island")
	for player in saved.players.values():
		player.erase("activity")
		player.erase("can_water")
	saved.entities = world._new_entities(true, false)
	for index in WorldState.DRIFT_KINDS.size():
		saved.drift["drift_%02d" % index] = {"kind": WorldState.DRIFT_KINDS[index], "x": 180.0 + index * 42.0, "y": 170.0 if index % 2 == 0 else 405.0, "active": true, "respawn": 0.0}
	return saved


func _test_save_migration() -> void:
	var world = _world()
	var old := _v4_snapshot(world)
	old.entities.ore_00.active = false
	old.entities.fish_00.active = false
	old.drift.drift_00.active = false
	old.drift.drift_00.respawn = 3.0
	old.players.host.hook = {"id": "drift_04", "remaining": 0.5, "duration": 1.0, "x": old.drift.drift_04.x, "y": old.drift.drift_04.y}
	old.players.guest.hook = {"id": "drift_06", "remaining": 0.8, "duration": 1.0, "x": old.drift.drift_06.x, "y": old.drift.drift_06.y}
	Inventory.add(old.players.host.bag, "fins", 1)
	old.structures.furnace_0 = {"id": "furnace_0", "kind": "furnace", "x": 480.0, "y": 224.0, "remaining": 8.0, "output": "ingot"}
	var loaded = WorldState.new()
	_check(loaded.restore(JSON.parse_string(JSON.stringify(old))) and loaded.data.version == 10 and loaded.data.entities.has("wreck_00") and loaded.data.entities.has("wreck_01"), "a real v4 shape migrates by adding the two wrecks")
	_check(not loaded.data.entities.ore_00.active and not loaded.data.entities.fish_00.active and loaded.data.structures.furnace_0.remaining == 8.0 and _count(loaded, "host", "fins") == 1, "v4 migration preserves depleted nodes, in-progress processing and equipment")
	_check(not loaded.data.drift.drift_00.active and loaded.data.drift.drift_00.respawn == 3.0 and _point(loaded.data.drift.drift_00) == _point(old.drift.drift_00) and loaded.data.drift.drift_00.has_all(["speed", "phase", "sway"]), "v4 drift gains motion metadata while preserving collected status, delay and inactive position")
	var heights: Dictionary = {}
	var statuses_preserved := true
	for id in loaded.data.drift:
		var item: Dictionary = loaded.data.drift[id]
		if item.active:
			heights[float(item.y)] = true
		statuses_preserved = statuses_preserved and item.kind == old.drift[id].kind and item.active == old.drift[id].active and item.respawn == old.drift[id].respawn
	_check(heights.size() > 4 and statuses_preserved, "v4 active supplies immediately gain a scattered layout without changing their IDs, kinds or availability")
	_check(_point(loaded.data.drift.drift_04) == _point(old.drift.drift_04) and _point(loaded.data.drift.drift_06) == _point(old.drift.drift_06) and loaded.data.players.host.hook.is_empty() and loaded.data.players.guest.hook.is_empty() and loaded.data.drift.drift_04.active and loaded.data.drift.drift_06.active, "migration cancels old in-flight hooks while preserving both targeted resources and their positions")
	var old_v3 := _v4_snapshot(world)
	old_v3.version = 3
	old_v3.entities = world._new_entities(false)
	var migrated_v3 = WorldState.new()
	var v3_valid: bool = migrated_v3.restore(old_v3)
	heights = {}
	for item in migrated_v3.data.drift.values():
		if item.active:
			heights[float(item.y)] = true
	_check(v3_valid and heights.size() > 4, "v3 active supplies also leave the old two-row layout during migration")
	loaded.join("host", "船长")
	_place(loaded, "host", "water", _point(loaded.data.entities.wreck_00))
	Skills.gather(loaded, "host", "search_wreck", "wreck_00")
	var saved: Variant = JSON.parse_string(JSON.stringify(loaded.snapshot()))
	_check(world.restore(saved) and not world.data.entities.wreck_00.active and world.data.entities.wreck_01.active and _count(world, "host", "treasure") == 1, "v8 roundtrip preserves searched wrecks and their awarded treasure")
	var drift_snapshot: Dictionary = world.data.drift.duplicate(true)
	_check(world.restore(JSON.parse_string(JSON.stringify(world.snapshot()))) and world.data.drift == drift_snapshot and not world.data.entities.wreck_00.active, "repeat v8 loading preserves exact drift motion state and never refills wrecks")
	var baseline: Dictionary = world.snapshot()
	var invalid: Array = []
	var bad: Dictionary = baseline.duplicate(true)
	bad.drift.drift_00.speed = 0.0
	invalid.append(bad)
	bad = baseline.duplicate(true)
	bad.drift.drift_00.phase = "east"
	invalid.append(bad)
	bad = baseline.duplicate(true)
	bad.drift.drift_00.respawn = 8.0
	invalid.append(bad)
	bad = baseline.duplicate(true)
	bad.drift.drift_00.erase("sway")
	invalid.append(bad)
	bad = baseline.duplicate(true)
	bad.entities.erase("wreck_00")
	invalid.append(bad)
	bad = baseline.duplicate(true)
	bad.entities.wreck_01.active = 1
	invalid.append(bad)
	bad = old.duplicate(true)
	bad.drift.drift_00.speed = 15.0
	invalid.append(bad)
	for malformed in invalid:
		_check(not world.restore(malformed) and world.snapshot() == baseline, "invalid version-specific drift or wreck fields reject without replacing the live world")

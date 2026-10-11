extends SceneTree

const Inventory = preload("res://scripts/inventory.gd")
const Skills = preload("res://tests/skill_test_helpers.gd")
const WorldState = preload("res://scripts/world_state.gd")
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_stack_operations()
	_test_authoritative_transfers()
	_test_discard()
	_test_capacity_and_crafting()
	_test_fishing_and_treasure()
	_test_migration_and_validation()
	print("INVENTORY TESTS: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + label)


func _world(two_players := false):
	var world = WorldState.new()
	var old: Dictionary = world.snapshot()
	old.version = 2
	old.entities = world._new_entities(false)
	for key in ["deck_tiles", "structures", "drift", "navigation", "chart", "island"]:
		old.erase(key)
	var slots := Inventory.empty_slots(Inventory.CHEST_SIZE)
	Inventory.add(slots, "seed", 3)
	old.chests = {"chest_0": {"id": "chest_0", "name": "共享木箱", "x": 420.0, "y": 175.0, "slots": slots}}
	for player in old.players.values():
		for key in ["hunger", "thirst", "hook", "notice", "notice_id", "activity", "can_water"]:
			player.erase(key)
		player.x = 475.0
		player.y = 390.0
	_check(world.restore(old), "old-layout inventory fixture migrates")
	world.join("host", "船长")
	if two_players:
		world.join("guest", "伙伴")
	return world


func _place(world, slot: String, x: float, y: float) -> void:
	world.data.players[slot].area = "deck"
	world.data.players[slot].x = x
	world.data.players[slot].y = y


func _transfer(world, slot: String, source: String, source_index: int, target: String, target_index: int, expected: String, amount := 0) -> String:
	return world.action(slot, "inventory_move", {"from_container": source, "from_index": source_index, "to_container": target, "to_index": target_index, "expected_item": expected, "amount": amount})


func _test_stack_operations() -> void:
	var slots := Inventory.empty_slots(3)
	_check(Inventory.add(slots, "wood", 45) == 0 and Inventory.used(slots) == 3 and int(slots[0].count) == 20 and int(slots[2].count) == 5, "add splits items into bounded stacks")
	_check(Inventory.add(slots, "wood", 20) == 5 and Inventory.total_count(slots) == 60, "add returns exact overflow without exceeding capacity")
	var before: Array = slots.duplicate(true)
	_check(not Inventory.remove(slots, "wood", 61) and slots == before, "insufficient removal is atomic")
	_check(Inventory.remove(slots, "wood", 25) and slots[0].is_empty() and int(slots[1].count) == 15, "removal consumes quantities and frees empty slots")
	var other := Inventory.empty_slots(2)
	_check(Inventory.move(slots, 1, other, 0, 5) and int(slots[1].count) == 10 and int(other[0].count) == 5, "manual split transfers requested quantity")
	Inventory.add(other, "fish", 2)
	_check(not Inventory.move(slots, 1, other, 1, 3), "partial transfer cannot swap different item types")
	_check(Inventory.move(slots, 1, other, 1) and slots[1].item == "fish" and other[1].item == "wood", "whole stacks swap without loss")
	before = other.duplicate(true)
	_check(not Inventory.move(other, 1, other, 1) and other == before, "same-slot move is a harmless rejection")
	Inventory.sort_slots(slots)
	_check(Inventory.count(slots, "fish") == 2 and Inventory.count(slots, "wood") == 20 and Inventory.used(slots) == 2, "sort preserves all items while merging and packing")
	_check(Inventory.validate_slots(JSON.parse_string(JSON.stringify(slots)), 3), "JSON floats are valid integral stack counts")
	var malformed := [{"item": "wood", "count": 20.5}, {}, {}]
	_check(not Inventory.validate_slots(malformed, 3), "fractional stack count is rejected")


func _test_authoritative_transfers() -> void:
	var world = _world(true)
	_place(world, "host", 420, 175)
	_place(world, "guest", 420, 175)
	_transfer(world, "host", "chest_0", 0, "bag", 0, "seed")
	_transfer(world, "guest", "chest_0", 0, "bag", 0, "seed")
	_check(Inventory.count(world.data.players.host.bag, "seed") == 3 and Inventory.count(world.data.players.guest.bag, "seed") == 0 and int(world.chest_totals().seed) == 0, "concurrent requests for one shared stack award it only once")
	world.data.chests.chest_0.slots[0] = {"item": "wood", "count": 4}
	var before: Dictionary = world.snapshot()
	_transfer(world, "guest", "chest_0", 0, "bag", 0, "seed")
	_check(world.snapshot() == before, "stale expected item cannot move a replacement stack")
	_transfer(world, "guest", "host", 0, "bag", 0, "seed")
	_check(world.snapshot() == before, "container names never expose the other player's pack")
	_place(world, "host", 200, 385)
	before = world.snapshot()
	_transfer(world, "host", "chest_0", 0, "bag", 1, "wood")
	world.action("host", "sort_inventory", {"container": "chest_0"})
	_check(world.snapshot() == before, "distant chest transfers and sorting are rejected")
	_place(world, "host", 420, 175)
	before = world.snapshot()
	world.action("host", "inventory_move", {"from_container": "chest_0", "from_index": 0.5, "to_container": "bag", "to_index": 1, "expected_item": "wood"})
	_check(world.snapshot() == before, "fractional slot indices are rejected")
	world.action("host", "inventory_move", {"from_container": "chest_0", "from_index": 0, "to_container": "bag", "to_index": 1, "expected_item": "wood", "amount": -1})
	_check(world.snapshot() == before, "negative transfer quantities are rejected")


func _test_discard() -> void:
	var world = WorldState.new()
	world.join("host", "船长")
	world.join("guest", "伙伴")
	Inventory.add(world.data.players.host.bag, "wood", 20)
	Inventory.add(world.data.players.guest.bag, "wood", 20)
	var message: String = world.action("host", "discard", {"index": 0, "amount": 7, "expected_item": "wood"})
	_check(Inventory.count(world.data.players.host.bag, "wood") == 13 and Inventory.count(world.data.players.guest.bag, "wood") == 20 and message.contains("×7"), "discard removes only the explicit quantity from the caller's selected bag stack")
	var before: Dictionary = world.snapshot()
	var invalid_requests: Array = [
		{"index": -1, "amount": 1, "expected_item": "wood"},
		{"index": 12, "amount": 1, "expected_item": "wood"},
		{"index": 0.5, "amount": 1, "expected_item": "wood"},
		{"index": "0", "amount": 1, "expected_item": "wood"},
		{"index": 0, "amount": 0, "expected_item": "wood"},
		{"index": 0, "amount": -1, "expected_item": "wood"},
		{"index": 0, "amount": 1.5, "expected_item": "wood"},
		{"index": 0, "amount": 20, "expected_item": "wood"},
		{"index": 0, "amount": 21, "expected_item": "wood"},
		{"index": 0, "expected_item": "wood"},
		{"index": 0, "amount": 1, "expected_item": "leaf"},
		{"index": 0, "amount": 1, "expected_item": 5},
		{"index": 1, "amount": 1, "expected_item": "wood"},
		{"index": 0, "amount": 1, "expected_item": "wood", "container": "guest"},
	]
	for args in invalid_requests:
		world.action("host", "discard", args)
	world.action("unknown", "discard", {"index": 0, "amount": 1, "expected_item": "wood"})
	_check(world.snapshot() == before, "invalid indices, identity, stale items and nonpositive or excessive quantities cannot discard anything")
	world = WorldState.new()
	world.join("host", "船长")
	var player: Dictionary = world.data.players.host
	Inventory.add(player.bag, "wood", Inventory.BAG_SIZE * Inventory.STACK_LIMIT)
	Skills.stage_drift(world, "drift_09")
	Skills.hook_and_reel(world, "host")
	var full_refused: bool = world.data.drift.drift_09.active and Inventory.count(player.bag, "leaf") == 0
	world.action("host", "discard", {"index": 0, "amount": 20, "expected_item": "wood"})
	Skills.stage_drift(world, "drift_09")
	Skills.hook_and_reel(world, "host")
	_check(full_refused and Inventory.count(player.bag, "wood") == 220 and Inventory.count(player.bag, "leaf") == 2 and not world.data.drift.drift_09.active, "discarding one full wood stack unlocks leaf salvage without needing a chest")


func _test_capacity_and_crafting() -> void:
	var world = _world()
	_place(world, "host", 420, 175)
	var player: Dictionary = world.data.players.host
	var chest: Dictionary = world.data.chests.chest_0
	chest.slots = Inventory.empty_slots(Inventory.CHEST_SIZE)
	Inventory.add(chest.slots, "meal", Inventory.CHEST_SIZE * Inventory.STACK_LIMIT)
	chest.slots[0] = {"item": "wood", "count": 19}
	Inventory.add(player.bag, "wood", 5)
	Inventory.add(player.bag, "fish", 3)
	world.action("host", "deposit")
	_check(Inventory.count(chest.slots, "wood") == 20 and Inventory.count(player.bag, "wood") == 4 and Inventory.count(player.bag, "fish") == 3, "partial deposit fills only available room and leaves all remainder in bag")
	player.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Inventory.add(player.bag, "wood", WorldState.BAG_CAPACITY)
	chest.slots = Inventory.empty_slots(Inventory.CHEST_SIZE)
	Inventory.add(chest.slots, "fish", 1)
	Inventory.add(chest.slots, "veg", 1)
	_place(world, "host", 420, 290)
	world.action("host", "cook")
	world.tick(10.1)
	var before: Dictionary = world.snapshot()
	world.action("host", "collect_output", {"id": "legacy_grill"})
	_check(world.snapshot() == before and world.data.structures.legacy_grill.output == "meal", "full-pack cooking leaves completed meal in the grill")
	_place(world, "host", 565, 175)
	world.data.crop = {"stage": 2, "progress": 1.0, "watered": true}
	before = world.snapshot()
	world.action("host", "harvest")
	_check(world.snapshot() == before, "full-pack harvest preserves ripe crop")
	player.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Inventory.add(player.bag, "wood", 8)
	Inventory.add(player.bag, "rope", 2)
	_place(world, "host", 710, 385)
	world.action("host", "craft", {"recipe": "chest", "x": 608.0, "y": 416.0})
	world.action("host", "craft", {"recipe": "chest", "x": 608.0, "y": 352.0})
	_check(world.data.chests.size() == 3 and Inventory.count(player.bag, "wood") == 0 and world.data.chests.chest_1.slots.size() == 16, "crafting finite chests consumes four wood each")
	before = world.snapshot()
	world.action("host", "craft", {"recipe": "chest", "x": 672.0, "y": 288.0})
	_check(world.snapshot() == before, "failed chest crafting cannot create free storage")
	# Empty migration boxes suffice to exercise the global count guard without filling thousands of slots.
	for index in WorldState.MAX_SAVED_CHESTS - world.data.chests.size():
		world.data.chests["migration_%d" % index] = {"id": "migration_%d" % index, "name": "旧物资箱", "x": 200.0, "y": 250.0, "slots": []}
	Inventory.add(player.bag, "wood", 4)
	Inventory.add(player.bag, "rope", 1)
	world.action("host", "craft", {"recipe": "chest", "x": 672.0, "y": 288.0})
	_check(world.data.chests.size() == WorldState.MAX_SAVED_CHESTS and Inventory.count(player.bag, "wood") == 4, "global chest limit prevents an unrestorable world without consuming wood")


func _test_fishing_and_treasure() -> void:
	var world = _world(true)
	_place(world, "host", 185, 385)
	_place(world, "guest", 185, 385)
	Inventory.add(world.data.players.host.bag, "rod", 1)
	Inventory.add(world.data.players.guest.bag, "rod", 1)
	world.action("host", "cast")
	world.action("guest", "cast")
	var player: Dictionary = world.data.players.host
	_check(player.stamina == 98.0 and player.fishing.remaining == 5.0 and not world.data.players.guest.fishing.is_empty(), "both players can cast independently for two stamina")
	var result: String = player.fishing.result
	world.action("host", "cast")
	world.action("host", "reel")
	_check(player.stamina == 98.0 and player.fishing.result == result and Inventory.total_count(player.bag) == 1, "repeat cast and early reel do not reroll or reward")
	Inventory.add(player.bag, "meal", WorldState.BAG_CAPACITY)
	world.tick(5.1)
	world.action("host", "reel")
	world.action("host", "reel")
	_check(not player.fishing.is_empty() and player.fishing.result == result and player.fishing.remaining == 0.0, "full bag preserves the original catch for later collection")
	Inventory.remove(player.bag, "meal", 20)
	world.action("host", "reel")
	world.action("host", "reel")
	_check(player.fishing.is_empty() and Inventory.count(player.bag, result) == 1, "making room permits one collection without duplication")
	world.set_move("guest", Vector2.RIGHT)
	for step in 3:
		world.set_move("guest", Vector2.RIGHT)
		world.tick(0.2)
	_check(world.data.players.guest.fishing.is_empty() and Inventory.total_count(world.data.players.guest.bag) == 1, "walking away cancels fishing without a reward")
	player.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Inventory.add(player.bag, "meal", WorldState.BAG_CAPACITY)
	player.bag[0] = {"item": "treasure", "count": 1}
	var before: Dictionary = world.snapshot()
	world.action("host", "open_treasure", {"index": 0})
	_check(world.snapshot() == before, "treasure opening is all-or-nothing when contents do not fit")
	Inventory.remove(player.bag, "meal", 40)
	world.action("host", "open_treasure", {"index": 0})
	_check(Inventory.count(player.bag, "treasure") == 0 and Inventory.count(player.bag, "wood") == 3 and Inventory.count(player.bag, "seed") == 2 and Inventory.count(player.bag, "fish") == 1, "treasure consumes one box and awards exactly its complete contents")


func _legacy_snapshot() -> Dictionary:
	var world = _world(true)
	var saved: Dictionary = world.snapshot()
	saved.version = 1
	saved.entities = world._new_entities(false)
	saved.erase("chests")
	for key in ["deck_tiles", "structures", "drift", "navigation", "chart", "island"]:
		saved.erase(key)
	saved.storage = {"fish": 5, "wood": 3, "veg": 0, "meal": 0, "seed": 3}
	for slot in ["host", "guest"]:
		saved.players[slot].bag = {"fish": 0, "wood": 0, "veg": 0, "meal": 0}
		saved.players[slot].erase("fishing")
		for key in ["hunger", "thirst", "hook", "notice", "notice_id", "activity", "can_water"]:
			saved.players[slot].erase(key)
	saved.players.guest.bag = {"fish": 5, "wood": 3, "veg": 0, "meal": 0}
	return saved


func _test_migration_and_validation() -> void:
	var world = WorldState.new()
	var saved := _legacy_snapshot()
	_check(world.restore(JSON.parse_string(JSON.stringify(saved))), "valid old JSON save migrates")
	_check(world.data.version == 10 and Inventory.count(world.data.players.guest.bag, "fish") == 5 and Inventory.count(world.data.players.guest.bag, "wood") == 3 and int(world.chest_totals().fish) == 5 and int(world.chest_totals().wood) == 3, "legacy personal and shared items remain distinct and lossless")
	saved.storage.wood = 700
	_check(world.restore(saved) and world.data.chests.size() >= 3 and int(world.chest_totals().wood) == 700, "oversized legacy warehouse expands into finite migration chests without loss")
	var roundtrip: Variant = JSON.parse_string(JSON.stringify(world.snapshot()))
	_check(world.restore(roundtrip), "migrated v8 snapshot roundtrips")
	world.join("host", "船长")
	_place(world, "host", 185, 385)
	Inventory.add(world.data.players.host.bag, "rod", 1)
	world.action("host", "cast")
	var fishing_save: Dictionary = world.snapshot()
	_check(world.restore(JSON.parse_string(JSON.stringify(fishing_save))), "valid in-progress fishing state validates on load")
	world.join("host", "船长")
	_check(world.data.players.host.fishing.is_empty(), "joining on safe deck cancels previous fishing session")
	var baseline: Dictionary = world.snapshot()
	var cases: Array = []
	var bad: Dictionary = baseline.duplicate(true)
	bad.players.host.bag[0] = {"item": "unknown", "count": 1}
	cases.append(bad)
	bad = baseline.duplicate(true)
	bad.players.host.bag[0] = {"item": "wood", "count": 0}
	cases.append(bad)
	bad = baseline.duplicate(true)
	bad.chests.chest_0.slots.append({})
	cases.append(bad)
	bad = baseline.duplicate(true)
	bad.chests.chest_0.x = 90000
	cases.append(bad)
	bad = baseline.duplicate(true)
	bad.players.host.fishing = {"remaining": -1.0, "result": "treasure"}
	cases.append(bad)
	bad = baseline.duplicate(true)
	bad.chests.chest_0.slots[0]["script"] = "unexpected"
	cases.append(bad)
	bad = baseline.duplicate(true)
	bad["storage"] = {"wood": 900}
	cases.append(bad)
	for malformed in cases:
		_check(not world.restore(malformed) and world.snapshot() == baseline, "invalid current data is rejected without changing live state")

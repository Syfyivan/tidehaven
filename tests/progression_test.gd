extends SceneTree

const WorldState = preload("res://scripts/world_state.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Skills = preload("res://tests/skill_test_helpers.gd")
const Recipes = preload("res://scripts/recipes.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_mining()
	_test_equipment()
	_test_smelting_and_crafting()
	_test_relocation()
	_test_migration_and_restore()
	print("PROGRESSION TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)


func _world(two := false):
	var world = WorldState.new()
	world.join("host", "船长")
	if two:
		world.join("guest", "伙伴")
	return world


func _place(world, slot: String, area: String, x: float, y: float) -> void:
	if area == "water":
		world.data.navigation.anchored = true
	var player: Dictionary = world.data.players[slot]
	player.area = area
	player.x = x
	player.y = y


func _give(world, slot: String, items: Dictionary) -> void:
	for item in items:
		Inventory.add(world.data.players[slot].bag, item, int(items[item]))


func _count(world, slot: String, item: String) -> int:
	return Inventory.count(world.data.players[slot].bag, item)


func _furnace_world(two := false):
	var world = _world(two)
	_give(world, "host", {"stone": 6, "scrap": 2, "wood": 10, "ore": 4})
	world.action("host", "craft", {"recipe": "furnace", "x": 480.0, "y": 224.0})
	_check(world.data.structures.has("structure_0") and world.data.structures.structure_0.kind == "furnace" and _count(world, "host", "stone") == 0 and _count(world, "host", "scrap") == 0 and _count(world, "host", "wood") == 6, "furnace is built through the recipe with exact resource costs")
	return world


func _test_mining() -> void:
	var world = _world(true)
	var stones := 0
	var ores := 0
	for entity in world.data.entities.values():
		stones += 1 if entity.kind == "stone" else 0
		ores += 1 if entity.kind == "ore" else 0
	_check(stones == 6 and ores == 8, "new world contains six stone and eight ore deposits")
	var before: Dictionary = world.snapshot()
	world.action("host", "mine", {"id": "ore_00"})
	_check(world.snapshot() == before, "mining from the deck is rejected atomically")
	var deposit: Dictionary = world.data.entities.ore_00
	_place(world, "host", "water", deposit.x, deposit.y)
	_place(world, "guest", "water", deposit.x, deposit.y)
	world.action("host", "mine", {"id": "ore_00"})
	world.action("guest", "mine", {"id": "ore_00"})
	_check(_count(world, "host", "ore") == 0 and deposit.active, "starting a shared mining operation never grants its reward early")
	Skills.finish_activity(world, "host")
	_check(_count(world, "host", "ore") == 1 and _count(world, "guest", "ore") == 0 and not deposit.active, "two miners receive one shared deposit exactly once")
	_check(world.data.players.host.stamina == 96.0 and world.data.players.guest.stamina == 100.0, "only the successful miner spends stamina")
	var stone: Dictionary = world.data.entities.stone_00
	_place(world, "host", "water", stone.x, stone.y)
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Inventory.add(world.data.players.host.bag, "wood", WorldState.BAG_CAPACITY)
	before = world.snapshot()
	Skills.gather(world, "host", "mine", "stone_00")
	_check(stone.active and world.data.players.host.bag == before.players.host.bag and world.data.players.host.stamina == before.players.host.stamina, "completed full-pack mining preserves stone deposit, every item and stamina")
	world.data.players.host.bag[0] = {"item": "stone", "count": 19}
	before = world.snapshot()
	Skills.gather(world, "host", "mine", "stone_00")
	_check(stone.active and world.data.players.host.bag == before.players.host.bag and world.data.players.host.stamina == before.players.host.stamina, "a two-stone yield never partially fills the last stack or consumes stamina")
	world.data.players.host.bag[0] = {}
	Skills.gather(world, "host", "mine", "stone_00")
	_check(_count(world, "host", "stone") == 2 and not stone.active, "one stone node gives exactly two stone")
	_place(world, "host", "water", 120, 100)
	before = world.snapshot()
	for args in [{"id": "ore_01"}, {"id": "fish_00"}, {"id": "invented"}, {"id": 12}, {}]:
		world.action("host", "mine", args)
	world.action("intruder", "mine", {"id": "ore_01"})
	_check(world.snapshot() == before, "distant or forged mining requests cannot change the world")
	deposit = world.data.entities.ore_01
	_place(world, "host", "water", deposit.x, deposit.y)
	world.data.players.host.stamina = 3.0
	before = world.snapshot()
	world.action("host", "mine", {"id": "ore_01"})
	_check(world.snapshot() == before, "insufficient stamina never consumes a deposit")
	world.leave("guest")
	_place(world, "host", "deck", 416, 288)
	world.action("host", "sleep")
	_check(world.data.day == 2 and world.data.entities.stone_00.active and world.data.entities.ore_00.active, "joint day transition replenishes mined deposits")


func _test_equipment() -> void:
	var world = _world(true)
	var host: Dictionary = world.data.players.host
	var guest: Dictionary = world.data.players.guest
	_give(world, "host", {"fins": 1})
	_give(world, "guest", {"wood": 1})
	_check(is_equal_approx(WorldState.water_speed(host), WorldState.WATER_SPEED * 1.3) and WorldState.water_speed(guest) == WorldState.WATER_SPEED, "fins affect only the carrier")
	_place(world, "host", "water", 200, 200)
	_place(world, "guest", "water", 200, 200)
	world.set_move("host", Vector2.RIGHT)
	world.set_move("guest", Vector2.RIGHT)
	world.tick(0.2)
	_check(is_equal_approx(float(host.x) - 200.0, (float(guest.x) - 200.0) * 1.3), "actual swimming includes fins while preserving equal-load penalties")
	_give(world, "host", {"fins": 3})
	_check(is_equal_approx(WorldState.water_speed(host), WorldState.WATER_SPEED * 1.3), "multiple fins do not stack their bonus")
	Inventory.remove(host.bag, "fins", 4)
	_check(WorldState.water_speed(host) == WorldState.WATER_SPEED, "putting away fins removes the bonus")
	Skills.stage_drift(world, "drift_00", 320.0)
	world.action("guest", "hook", {"x": 1.0, "y": 0.0})
	_check(guest.hook.get("reach") == 280.0 and guest.hook.get("reel_speed") == 115.0, "ordinary hook captures its own reach and reel speed at launch")
	Skills.await_hook_contact(world, "guest")
	Skills.reel(world, ["guest"])
	_check(_count(world, "guest", "wood") == 1 and world.data.drift.drift_00.active, "ordinary directional hook cannot retrieve a receding target beyond its range")
	_give(world, "host", {"reinforced_hook": 2})
	_check(WorldState.hook_distance(host) == 400.0 and WorldState.hook_distance(guest) == 280.0, "reinforced hook is personal and its distance does not stack")
	Skills.stage_drift(world, "drift_00", 320.0)
	world.action("host", "hook", {"x": 1.0, "y": 0.0})
	_check(host.hook.get("reach") == 400.0 and host.hook.get("reel_speed") == 155.0, "upgraded hook snapshots increased reach and reel speed without stacking")
	world.tick(0.66)
	_check(_count(world, "host", "wood") == 0, "upgraded hook grants no instant timer reward while still travelling")
	Skills.await_hook_contact(world, "host")
	_check(host.hook.get("cargo", []).has("drift_00") and _count(world, "host", "wood") == 0, "physical contact holds distant cargo until the player reels it back")
	Skills.reel(world, ["host"])
	_check(_count(world, "host", "wood") == 2, "upgraded hook retrieves distant drift through real contact and return travel")
	Inventory.remove(host.bag, "reinforced_hook", 2)
	world.action("host", "hook", {"x": 1.0, "y": 0.0})
	_check(WorldState.hook_distance(host) == 280.0 and host.hook.get("reel_speed") == 115.0, "storing upgraded hook restores ordinary handling on the next cast")


func _test_smelting_and_crafting() -> void:
	var world = _furnace_world(true)
	_place(world, "guest", "deck", 512, 256)
	world.action("host", "smelt", {"id": "structure_0"})
	_check(world.data.structures.structure_0.remaining == 15.0 and world.data.structures.structure_0.output == "ingot" and _count(world, "host", "ore") == 3 and _count(world, "host", "wood") == 5, "smelting reserves one ore and one wood for a 15-second result")
	var before: Dictionary = world.snapshot()
	world.action("host", "smelt", {"id": "structure_0"})
	world.action("guest", "collect_output", {"id": "structure_0"})
	world.action("host", "grill_fish", {"id": "structure_0"})
	_check(world.snapshot() == before, "busy furnace rejects duplicate start, early claim and wrong processing verb")
	world.tick(15.1)
	world.action("host", "collect_output", {"id": "structure_0"})
	world.action("guest", "collect_output", {"id": "structure_0"})
	_check(_count(world, "host", "ingot") == 1 and _count(world, "guest", "ingot") == 0, "two players cannot claim one ingot twice")
	world.action("host", "smelt", {"id": "structure_0"})
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Inventory.add(world.data.players.host.bag, "cup", WorldState.BAG_CAPACITY)
	world.tick(15.1)
	before = world.snapshot()
	world.action("host", "collect_output", {"id": "structure_0"})
	_check(world.snapshot() == before and world.data.structures.structure_0.output == "ingot", "completed ingot remains in furnace while recipient bag is full")
	Inventory.remove(world.data.players.host.bag, "cup", 20)
	world.action("host", "collect_output", {"id": "structure_0"})
	_check(_count(world, "host", "ingot") == 1 and world.data.structures.structure_0.output.is_empty(), "making room allows exactly one delayed collection")
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	_give(world, "guest", {"ingot": 4, "plastic": 4, "rope": 3})
	before = world.snapshot()
	world.action("host", "craft", {"recipe": "fins"})
	_check(world.snapshot() == before, "personal equipment crafting cannot spend partner inventory")
	_give(world, "host", {"ingot": 4, "plastic": 4, "rope": 3})
	world.action("host", "craft", {"recipe": "fins"})
	world.action("host", "craft", {"recipe": "reinforced_hook"})
	_check(_count(world, "host", "fins") == 1 and _count(world, "host", "reinforced_hook") == 1 and _count(world, "host", "ingot") == 0 and _count(world, "host", "plastic") == 0 and _count(world, "host", "rope") == 0, "both exploration recipes produce equipment for their exact combined costs")
	_check(Recipes.ALL.has_all(["rope", "cup", "rod", "purifier", "grill", "chest", "garden", "bed", "foundation", "paddle", "anchor", "furnace", "fins", "reinforced_hook", "harpoon", "axe", "pickaxe", "compass"]) and Recipes.ALL.furnace.category == "exploration" and Recipes.ALL.fins.category == "exploration", "new skill tools coexist with every existing survival, navigation and exploration recipe")


func _test_relocation() -> void:
	var world = _furnace_world()
	world.action("host", "smelt", {"id": "structure_0"})
	world.tick(4.0)
	var move := {"id": "structure_0", "from_x": 480.0, "from_y": 224.0, "x": 544.0, "y": 224.0}
	var before: Dictionary = world.snapshot()
	_check(world.can_relocate("host", "structure_0", 480, 224, 544, 224) and world.snapshot() == before, "relocation preview is read-only and frees the source for path validation")
	world.action("host", "relocate", move)
	_check(world.data.structures.size() == 2 and world.data.structures.structure_0.x == 544.0 and world.data.structures.structure_0.remaining == 11.0 and world.data.structures.structure_0.output == "ingot", "moving a working furnace preserves identity, output and remaining time")
	before = world.snapshot()
	world.action("host", "relocate", move)
	_check(world.snapshot() == before, "stale source coordinates cannot move the same furnace a second time")
	world = _world(true)
	_place(world, "host", "deck", 416, 288)
	_place(world, "guest", "deck", 416, 288)
	var slots := Inventory.empty_slots(Inventory.CHEST_SIZE)
	Inventory.add(slots, "ore", Inventory.CHEST_SIZE * Inventory.STACK_LIMIT)
	world.data.chests.chest_0 = {"id": "chest_0", "name": "矿石箱", "x": 416.0, "y": 352.0, "slots": slots}
	move = {"id": "chest_0", "from_x": 416.0, "from_y": 352.0, "x": 544.0, "y": 352.0}
	world.action("host", "relocate", move)
	world.action("guest", "relocate", move)
	_check(world.data.chests.size() == 1 and world.data.chests.chest_0.x == 544.0 and world.data.chests.chest_0.slots == slots and Inventory.count(slots, "ore") == 320, "full shared chest moves without repacking or loss, and a racing request cannot duplicate it")
	_place(world, "host", "deck", 544, 288)
	before = world.snapshot()
	var invalid := [
		{"id": "chest_0", "from_x": 544.0, "from_y": 352.0, "x": 544.0, "y": 288.0},
		{"id": "chest_0", "from_x": 544.0, "from_y": 352.0, "x": 416.0, "y": 224.0},
		{"id": "chest_0", "from_x": 544.0, "from_y": 352.0, "x": 608.0, "y": 352.0},
		{"id": "chest_0", "from_x": 544.0, "from_y": 352.0, "x": 470.0, "y": 350.0},
		{"id": "chest_0", "from_x": 544.0, "from_y": 352.0, "x": INF, "y": 352.0},
		{"id": "6,3", "from_x": 416.0, "from_y": 224.0, "x": 480.0, "y": 224.0},
		{"id": "chest_0", "from_x": "544", "from_y": 352.0, "x": 480.0, "y": 352.0},
	]
	for args in invalid:
		world.action("host", "relocate", args)
	_check(world.snapshot() == before, "occupied, off-raft, unsnapped, non-finite, malformed and floor relocation requests change nothing")
	_place(world, "host", "deck", 416, 288)
	before = world.snapshot()
	world.action("host", "relocate", {"id": "chest_0", "from_x": 544.0, "from_y": 352.0, "x": 480.0, "y": 352.0})
	_check(world.snapshot() == before, "a reachable destination does not permit moving a distant source chest")
	_place(world, "host", "water", 544, 288)
	before = world.snapshot()
	world.action("host", "relocate", {"id": "chest_0", "from_x": 544.0, "from_y": 352.0, "x": 480.0, "y": 352.0})
	_check(world.snapshot() == before, "a diver cannot move deck storage")
	world = _world()
	_place(world, "host", "deck", 544, 288)
	world.data.structures.top = {"id": "top", "kind": "grill", "x": 480.0, "y": 224.0, "remaining": 0.0, "output": ""}
	world.data.structures.bottom = {"id": "bottom", "kind": "grill", "x": 480.0, "y": 352.0, "remaining": 0.0, "output": ""}
	world.data.chests.chest_0 = {"id": "chest_0", "name": "木箱", "x": 544.0, "y": 224.0, "slots": Inventory.empty_slots(Inventory.CHEST_SIZE)}
	before = world.snapshot()
	world.action("host", "relocate", {"id": "chest_0", "from_x": 544.0, "from_y": 224.0, "x": 480.0, "y": 288.0})
	_check(world.snapshot() == before, "moving a box cannot sever walkable deck paths")


func _test_migration_and_restore() -> void:
	var world = _world()
	var old: Dictionary = world.snapshot()
	old.version = 3
	old.erase("navigation")
	old.erase("chart")
	old.erase("island")
	for player in old.players.values():
		player.erase("activity")
		player.erase("can_water")
	for index in WorldState.DRIFT_KINDS.size():
		old.drift["drift_%02d" % index] = {"kind": WorldState.DRIFT_KINDS[index], "x": 180.0 + index * 42.0, "y": 170.0 if index % 2 == 0 else 405.0, "active": true, "respawn": 0.0}
	old.entities = world._new_entities(false)
	old.entities.fish_00.active = false
	old.players.host.hook = {"id": "drift_06", "remaining": 1.0, "x": old.drift.drift_06.x, "y": old.drift.drift_06.y}
	var loaded = WorldState.new()
	_check(loaded.restore(JSON.parse_string(JSON.stringify(old))) and loaded.data.version == 10 and loaded.data.entities.size() == 30 and not loaded.data.entities.fish_00.active, "v3 migration adds mineral and wreck nodes while preserving previous harvests")
	_check(loaded.data.players.host.hook.is_empty() and loaded.data.players.host.activity.is_empty() and loaded.data.drift.drift_06.active, "migrating an old in-progress hook cancels the old action without consuming its resource")
	old = world.snapshot()
	old.version = 2
	old.entities = world._new_entities(false)
	for key in ["deck_tiles", "structures", "drift", "navigation", "chart", "island"]:
		old.erase(key)
	old.chests = {"chest_0": {"id": "chest_0", "name": "老木箱", "x": 420.0, "y": 175.0, "slots": Inventory.empty_slots(Inventory.CHEST_SIZE)}}
	Inventory.add(old.chests.chest_0.slots, "wood", 9)
	for player in old.players.values():
		for key in ["hunger", "thirst", "hook", "notice", "notice_id", "activity", "can_water"]:
			player.erase(key)
		player.x = 475.0
		player.y = 390.0
	_check(loaded.restore(old) and loaded.data.version == 10 and loaded.data.entities.has("ore_07") and loaded.data.structures.has("legacy_grill") and int(loaded.chest_totals().wood) == 9, "v2 migration preserves legacy facilities and belongings while adding mineral resources")
	world = _furnace_world()
	_give(world, "host", {"fins": 1, "reinforced_hook": 1})
	world.data.entities.ore_00.active = false
	world.action("host", "smelt", {"id": "structure_0"})
	world.tick(5.0)
	var saved: Variant = JSON.parse_string(JSON.stringify(world.snapshot()))
	_check(loaded.restore(saved) and loaded.data.structures.structure_0.remaining == 10.0 and loaded.data.structures.structure_0.output == "ingot" and _count(loaded, "host", "fins") == 1 and _count(loaded, "host", "reinforced_hook") == 1, "v8 JSON restore preserves processing timer and both carried upgrades")
	_check(not loaded.data.entities.ore_00.active and loaded.restore(JSON.parse_string(JSON.stringify(loaded.snapshot()))) and not loaded.data.entities.ore_00.active, "loading v8 repeatedly never replenishes exhausted deposits")
	loaded.join("host", "船长")
	loaded.tick(10.1)
	loaded.action("host", "collect_output", {"id": "structure_0"})
	_check(_count(loaded, "host", "ingot") == 1, "restored furnace completes normally for one ingot")
	var baseline: Dictionary = loaded.snapshot()
	var cases: Array = []
	var bad: Dictionary = baseline.duplicate(true)
	bad.entities.erase("ore_07")
	cases.append(bad)
	bad = baseline.duplicate(true)
	bad.entities.ore_00.kind = "wood"
	cases.append(bad)
	bad = baseline.duplicate(true)
	bad.structures.structure_0.output = "freshwater"
	cases.append(bad)
	bad = baseline.duplicate(true)
	bad.structures.structure_0.output = "ingot"
	bad.structures.structure_0.remaining = 15.1
	cases.append(bad)
	bad = baseline.duplicate(true)
	bad.players.host.hook = {"id": "drift_06", "remaining": 0.5, "duration": 0.0, "x": 300.0, "y": 170.0}
	cases.append(bad)
	for malformed in cases:
		_check(not loaded.restore(malformed) and loaded.snapshot() == baseline, "invalid current deposits, processing and duration reject atomically")

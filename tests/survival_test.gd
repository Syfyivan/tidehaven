extends SceneTree

const WorldState = preload("res://scripts/world_state.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Skills = preload("res://tests/skill_test_helpers.gd")
const Recipes = preload("res://scripts/recipes.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_start_and_hook()
	_test_recipes_and_placement()
	_test_processing_and_consumption()
	_test_survival_and_movement()
	_test_restore_and_migration()
	print("SURVIVAL TESTS: %d checks, %d failures" % [checks, failures])
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


func _place(world, slot: String, x: float, y: float) -> void:
	world.data.players[slot].area = "deck"
	world.data.players[slot].x = x
	world.data.players[slot].y = y


func _give(world, slot: String, items: Dictionary) -> void:
	for item in items:
		Inventory.add(world.data.players[slot].bag, item, int(items[item]))


func _count(world, slot: String, item: String) -> int:
	return Inventory.count(world.data.players[slot].bag, item)


func _test_start_and_hook() -> void:
	var world = _world(true)
	_check(world.data.version == 10 and world.data.deck_tiles.size() == 9 and world.data.chests.is_empty() and world.data.structures.size() == 1 and world.data.structures.bedroll_0.kind == "bedroll", "new raft starts with nine tiles and only a bedroll")
	_check(Inventory.total_count(world.data.players.host.bag) == 0 and world.data.players.host.x == 480.0 and world.data.players.guest.x == 520.0, "new players have empty individual packs and safe raft spawns")
	Skills.stage_drift(world, "drift_06")
	world.action("host", "hook", {"x": 1.0, "y": 0.0})
	world.action("guest", "hook", {"x": 1.0, "y": 0.0})
	world.tick(0.5)
	_check(_count(world, "host", "leaf") == 0, "hook has a real return delay")
	Skills.await_hook_contact(world, "host")
	Skills.reel(world, ["host", "guest"])
	_check(_count(world, "host", "leaf") + _count(world, "guest", "leaf") == 2 and not world.data.drift.drift_06.active, "two hooks aimed at one drift item reward only once")
	_check(world.data.players.host.notice_id == 1 and world.data.players.guest.notice_id == 1, "hook completion and lost races both emit a personal notice")
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Inventory.add(world.data.players.host.bag, "cup", WorldState.BAG_CAPACITY)
	var full_bag: Array = world.data.players.host.bag.duplicate(true)
	Skills.stage_drift(world, "drift_04")
	Skills.hook_and_reel(world, "host")
	_check(world.data.players.host.bag == full_bag and world.data.drift.drift_04.active, "full-pack barrel retrieval leaves all loot and the barrel untouched")
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Skills.stage_drift(world, "drift_04")
	Skills.hook_and_reel(world, "host")
	_check(_count(world, "host", "wood") == 2 and _count(world, "host", "leaf") == 2 and _count(world, "host", "plastic") == 2 and _count(world, "host", "scrap") == 1 and _count(world, "host", "seed") == 1, "a barrel awards all eight materials atomically")
	var before: Dictionary = world.snapshot()
	world.action("host", "hook", {"id": "not_a_drift"})
	_check(world.snapshot() == before, "client cannot invent a drift reward")
	for cycle in 3:
		for item in world.data.drift.values():
			item.active = false
			item.respawn = 0.2
		world.tick(0.3)
		var active := 0
		var kinds: Dictionary = {}
		for item in world.data.drift.values():
			if item.active:
				active += 1
				kinds[item.kind] = true
		_check(active == 16 and kinds.has_all(["wood", "leaf", "plastic", "scrap", "barrel"]), "all essential drifting materials renew without sleeping")


func _test_recipes_and_placement() -> void:
	var world = _world(true)
	_give(world, "host", {"leaf": 4, "plastic": 4, "wood": 6})
	world.action("host", "craft", {"recipe": "rope"})
	_check(_count(world, "host", "leaf") == 2 and _count(world, "host", "rope") == 1, "rope crafting conserves its exact inputs")
	world.action("host", "craft", {"recipe": "cup"})
	_check(_count(world, "host", "plastic") == 2 and _count(world, "host", "cup") == 1, "cup crafting consumes exactly two plastic")
	var before: Dictionary = world.snapshot()
	world.action("host", "craft", {"recipe": "foundation", "x": 736.0, "y": 416.0})
	world.action("host", "craft", {"recipe": "grill", "x": 416.0, "y": 224.0})
	world.action("host", "craft", {"recipe": "foundation", "x": 601.0, "y": 288.0})
	_check(world.snapshot() == before, "floating floors, occupied cells and unsnapped placement never consume materials")
	world.action("host", "craft", {"recipe": "foundation", "x": 608.0, "y": 288.0})
	_check(world.data.deck_tiles.size() == 10 and "9,4" in world.data.deck_tiles and _count(world, "host", "wood") == 4 and _count(world, "host", "plastic") == 0, "adjacent foundation spends two wood and two plastic")
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	_give(world, "guest", {"wood": 4, "plastic": 2, "rope": 1})
	before = world.snapshot()
	world.action("host", "craft", {"recipe": "purifier", "x": 480.0, "y": 224.0})
	_check(world.snapshot() == before, "crafting never spends the other player's backpack")
	var blocked = _world()
	_place(blocked, "host", 416, 288)
	blocked.data.structures.wall_top = {"id": "wall_top", "kind": "grill", "x": 480.0, "y": 224.0, "remaining": 0.0, "output": ""}
	blocked.data.structures.wall_bottom = {"id": "wall_bottom", "kind": "purifier", "x": 480.0, "y": 352.0, "remaining": 0.0, "output": ""}
	_give(blocked, "host", {"wood": 4, "rope": 1})
	before = blocked.snapshot()
	blocked.action("host", "craft", {"recipe": "chest", "x": 480.0, "y": 288.0})
	_check(not blocked.can_place("host", "chest", 480, 288) and blocked.snapshot() == before, "placing a wall that separates raft walkable cells fails without consuming materials")
	_place(world, "host", 544, 352)
	world.action("host", "cast")
	_check(world.data.players.host.fishing.is_empty(), "fishing requires a crafted rod in the player's own bag")
	_give(world, "host", {"wood": 2, "rope": 2})
	world.action("host", "craft", {"recipe": "rod"})
	world.action("host", "cast")
	_check(_count(world, "host", "rod") == 1 and not world.data.players.host.fishing.is_empty(), "crafted rod enables fishing at the raft edge")


func _built_world():
	var world = _world(true)
	_give(world, "host", {"wood": 20, "plastic": 8, "rope": 4, "scrap": 4})
	world.action("host", "craft", {"recipe": "purifier", "x": 480.0, "y": 224.0})
	world.action("host", "craft", {"recipe": "grill", "x": 416.0, "y": 352.0})
	_check(world.data.structures.has("structure_0") and world.data.structures.has("structure_1"), "processing fixture is created using real building recipes")
	return world


func _test_processing_and_consumption() -> void:
	var world = _built_world()
	_place(world, "host", 544, 352)
	world.action("host", "craft", {"recipe": "cup"})
	world.action("host", "fill_cup")
	_check(_count(world, "host", "saltwater") == 1 and _count(world, "host", "cup") == 0, "filling a cup conserves its container")
	_place(world, "host", 480, 288)
	var wood_before := _count(world, "host", "wood")
	world.action("host", "purify", {"id": "structure_0"})
	_check(world.data.structures.structure_0.remaining == 12.0 and _count(world, "host", "saltwater") == 0 and _count(world, "host", "wood") == wood_before - 1, "purifier consumes seawater and fuel once and starts a real timer")
	world.action("host", "collect_output", {"id": "structure_0"})
	world.tick(11.9)
	world.action("host", "collect_output", {"id": "structure_0"})
	_check(_count(world, "host", "freshwater") == 0, "purified water cannot be claimed early")
	world.tick(0.2)
	_place(world, "guest", 512, 256)
	world.action("host", "collect_output", {"id": "structure_0"})
	world.action("guest", "collect_output", {"id": "structure_0"})
	_check(_count(world, "host", "freshwater") == 1 and _count(world, "guest", "freshwater") == 0 and world.data.structures.structure_0.output == "", "two players cannot duplicate one finished output")
	world.data.players.host.thirst = 20.0
	world.action("host", "drink")
	_check(world.data.players.host.thirst == 70.0 and _count(world, "host", "cup") == 1 and _count(world, "host", "freshwater") == 0, "drinking restores thirst and returns the cup")
	# A full pack may start processing; the finished product stays in its machine until it fits.
	world.data.chests.chest_0 = {"id": "chest_0", "name": "测试材料箱", "x": 544.0, "y": 224.0, "slots": Inventory.empty_slots(Inventory.CHEST_SIZE)}
	Inventory.add(world.data.chests.chest_0.slots, "fish", 1)
	Inventory.add(world.data.chests.chest_0.slots, "wood", 1)
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Inventory.add(world.data.players.host.bag, "cup", WorldState.BAG_CAPACITY)
	_place(world, "host", 416, 288)
	world.action("host", "grill_fish", {"id": "structure_1"})
	world.tick(10.1)
	var before: Dictionary = world.snapshot()
	world.action("host", "collect_output", {"id": "structure_1"})
	_check(world.snapshot() == before and world.data.structures.structure_1.output == "cooked_fish", "full pack leaves the cooked fish in the grill")
	Inventory.remove(world.data.players.host.bag, "cup", 20)
	world.action("host", "collect_output", {"id": "structure_1"})
	world.data.players.host.hunger = 20.0
	world.data.players.host.stamina = 20.0
	world.action("host", "eat")
	_check(world.data.players.host.hunger == 55.0 and world.data.players.host.stamina == 65.0 and _count(world, "host", "cooked_fish") == 0, "eating cooked fish restores hunger and stamina without raw-fish consumption")


func _test_survival_and_movement() -> void:
	var world = _world()
	world.set_move("host", Vector2.RIGHT)
	world.tick(0.1)
	var healthy_distance: float = world.data.players.host.x - 480.0
	_place(world, "host", 480, 288)
	world.data.players.host.hunger = 10.0
	world.data.players.host.thirst = 10.0
	world.set_move("host", Vector2.RIGHT)
	world.tick(0.1)
	_check(is_equal_approx(float(world.data.players.host.x) - 480.0, healthy_distance * 0.7), "low hunger or thirst slows movement without a permanent death state")
	_place(world, "host", 416, 288)
	world.data.players.host.stamina = 0.0
	world.action("host", "rest")
	world.tick(2.0)
	_check(world.data.players.host.stamina == 10.0 and world.data.day == 1, "low needs slow resting but do not force a new day")
	world.data.players.host.hunger = 80.0
	world.data.players.host.thirst = 75.0
	world.set_move("host", Vector2.UP)
	world.tick(0.4)
	_check(world.data.players.host.y >= 253.0, "movement cannot pass through a bedroll")
	_place(world, "host", 544, 352)
	world.set_move("host", Vector2.DOWN)
	world.tick(0.4)
	_check(world.data.players.host.y <= 374.0 and world.data.players.host.area == "deck", "walking never steps into an absent deck tile")
	_give(world, "host", {"anchor": 1})
	world.action("host", "drop_anchor")
	world.action("host", "dive")
	_check(world.data.players.host.area == "water", "any actual raft edge permits a deliberate dive after anchoring")
	world.action("host", "surface")
	_check(world.data.players.host.area == "deck" and world.data.players.host.x == 480.0, "surfacing returns to a safe cell on the current raft")


func _test_restore_and_migration() -> void:
	var world = _built_world()
	_give(world, "host", {"saltwater": 1})
	world.action("host", "purify", {"id": "structure_0"})
	world.tick(5.0)
	var saved: Variant = JSON.parse_string(JSON.stringify(world.snapshot()))
	var loaded = WorldState.new()
	_check(loaded.restore(saved) and loaded.data.structures.structure_0.remaining == 7.0, "v8 JSON roundtrip preserves the remaining processing time")
	loaded.join("host", "船长")
	loaded.tick(7.1)
	loaded.action("host", "collect_output", {"id": "structure_0"})
	_check(_count(loaded, "host", "freshwater") == 1, "restored processing completes and can be claimed exactly once")
	var old: Dictionary = _world().snapshot()
	old.version = 2
	old.entities = WorldState.new()._new_entities(false)
	for key in ["deck_tiles", "structures", "drift", "navigation", "chart", "island"]:
		old.erase(key)
	var slots := Inventory.empty_slots(Inventory.CHEST_SIZE)
	Inventory.add(slots, "fish", 5)
	Inventory.add(slots, "wood", 3)
	old.chests = {"chest_0": {"id": "chest_0", "name": "老木箱", "x": 420.0, "y": 175.0, "slots": slots}}
	for player in old.players.values():
		for key in ["hunger", "thirst", "hook", "notice", "notice_id", "activity", "can_water"]:
			player.erase(key)
		player.x = 475.0
		player.y = 390.0
	Inventory.add(old.players.guest.bag, "treasure", 2)
	_check(loaded.restore(old) and loaded.data.structures.has("legacy_grill") and loaded.data.structures.has("legacy_garden") and loaded.data.deck_tiles.size() == 70, "v2 layout migration preserves old usable facilities on the expanded tile representation")
	_check(int(loaded.chest_totals().fish) == 5 and int(loaded.chest_totals().wood) == 3 and _count(loaded, "guest", "treasure") == 2 and loaded.data.chests.chest_0.x == 420.0, "v2 migration preserves both players' belongings and original chest coordinates")
	var baseline: Dictionary = loaded.snapshot()
	var malformed: Dictionary = baseline.duplicate(true)
	malformed.deck_tiles.append("99,99")
	_check(not loaded.restore(malformed) and loaded.snapshot() == baseline, "invalid tile coordinates do not replace live state")
	malformed = baseline.duplicate(true)
	malformed.structures.legacy_grill.remaining = 5.0
	_check(not loaded.restore(malformed) and loaded.snapshot() == baseline, "processing without a valid planned output is rejected")
	malformed = baseline.duplicate(true)
	malformed.players.host.thirst = -1
	_check(not loaded.restore(malformed) and loaded.snapshot() == baseline, "invalid survival values are rejected atomically")
	malformed = baseline.duplicate(true)
	malformed.players.host.hook = {"id": "invented", "remaining": 0.5, "x": 300.0, "y": 170.0}
	_check(not loaded.restore(malformed) and loaded.snapshot() == baseline, "invalid hook targets cannot be restored")

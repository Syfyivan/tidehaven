extends SceneTree

const WorldState = preload("res://scripts/world_state.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Skills = preload("res://tests/skill_test_helpers.gd")
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_authority_and_capacity()
	_test_free_split_and_oxygen()
	_test_sleep_and_membership()
	_test_loop_and_daily_limits()
	_test_input_expiry()
	_test_save_roundtrip_and_rejection()
	print("STATE TESTS: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _world(two_players := false):
	var world = WorldState.new()
	# Existing mechanics are checked in a migrated old world; new survival starts have their own suite.
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
	_check(world.restore(old), "legacy fixture migrates before regression checks")
	world.join("host", "船长")
	if two_players:
		world.join("guest", "伙伴")
	return world


func _place(world, slot: String, area: String, x: float, y: float) -> void:
	world.data.players[slot].area = area
	world.data.players[slot].x = x
	world.data.players[slot].y = y


func _bag(world, slot: String, item: String) -> int:
	return Inventory.count(world.data.players[slot].bag, item)


func _stored(world, item: String) -> int:
	return int(world.chest_totals()[item])


func _fill_bag(world, slot: String, item: String = "wood") -> void:
	world.data.players[slot].bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Inventory.add(world.data.players[slot].bag, item, WorldState.BAG_CAPACITY)


func _test_authority_and_capacity() -> void:
	var world = _world(true)
	var before: Dictionary = world.snapshot()
	for verb in ["dive", "surface", "catch", "collect", "deposit", "take_meal", "plant", "water", "harvest", "cook", "sell", "build", "rest", "sleep"]:
		world.action("host", verb)
	_check(world.snapshot() == before, "distant actions cannot mutate resources or readiness")
	_check(not world.join("intruder", "第三人"), "only two fixed slots may join")
	world.action("intruder", "catch")
	_check(world.snapshot() == before, "unknown slot cannot act")
	Inventory.add(world.data.players.host.bag, "harpoon", 1)
	Inventory.add(world.data.players.guest.bag, "harpoon", 1)
	Skills.aim_at_fish(world, "host", "fish_00")
	Skills.aim_at_fish(world, "guest", "fish_00")
	world.action("host", "spear", {"x": 1.0, "y": 0.0})
	world.tick(0.5)
	Skills.finish_activity(world, "guest")
	_check(_bag(world, "host", "fish") == 1 and _bag(world, "guest", "fish") == 0, "one fish cannot be caught twice or awarded to two players")
	_check(not world.data.entities.fish_00.active, "caught fish becomes inactive")
	_fill_bag(world, "host")
	world.data.players.host.bag[0] = {"item": "fish", "count": 20}
	world.data.players.host.bag[1] = {"item": "harpoon", "count": 1}
	var stamina: float = world.data.players.host.stamina
	Skills.spear_fish(world, "host", "fish_01")
	_check(world.data.entities.fish_01.active and _bag(world, "host", "fish") == 20, "full pack does not consume a fish")
	_check(world.data.players.host.stamina == stamina - 5.0, "launched spear spends stamina even when the fish cannot fit")
	_place(world, "host", "deck", 420, 175)
	world.action("host", "deposit")
	world.action("host", "deposit")
	_check(_stored(world, "fish") == 20 and _stored(world, "wood") == 200 and _stored(world, "harpoon") == 1, "deposit transfers exactly once, including the carried tool")
	_check(_bag(world, "host", "fish") == 0 and _bag(world, "host", "wood") == 0, "deposit empties personal pack")
	Inventory.add(world.data.chests.chest_0.slots, "meal", 1)
	_fill_bag(world, "host")
	world.action("host", "take_meal")
	_check(_stored(world, "meal") == 1 and _bag(world, "host", "meal") == 0, "meal withdrawal also respects capacity")


func _test_free_split_and_oxygen() -> void:
	var world = _world(true)
	_place(world, "host", "deck", 565, 175)
	world.action("host", "plant")
	world.tick(10.0)
	_check(world.data.crop.progress == 0.0, "dry crop does not grow")
	world.action("host", "water")
	_place(world, "guest", "deck", 720, 410)
	world.action("guest", "dive")
	world.tick(66.0)
	_check(world.data.players.host.area == "deck" and world.data.players.guest.area == "water", "players independently remain on deck and underwater")
	_check(world.data.crop.stage == 2, "watered crop grows while players are in different areas")
	_check(world.data.minute > 360.0, "shared clock progresses across areas")
	for item in ["fish", "wood", "veg", "meal"]:
		Inventory.add(world.data.players.guest.bag, item, 2 if item in ["fish", "wood"] else 1)
	world.data.players.guest.oxygen = 0.01
	Inventory.add(world.data.chests.chest_0.slots, "fish", 3)
	world.data.players.host.stamina = 77.0
	world.tick(1.0)
	_check(world.data.players.guest.area == "deck" and _bag(world, "guest", "fish") == 0, "oxygen failure rescues only that diver and loses carried fish")
	_check(_bag(world, "guest", "wood") == 2 and _bag(world, "guest", "meal") == 1, "oxygen failure preserves non-fish belongings")
	_check(_stored(world, "fish") == 3 and world.data.players.host.stamina == 77.0, "oxygen failure preserves shared warehouse and partner")
	world.tick(1000.0)
	_check(world.data.minute == 1430.0 and world.data.day == 1, "clock caps at 23:50 without forced next day")


func _test_sleep_and_membership() -> void:
	var solo = _world()
	_place(solo, "host", "deck", 230, 170)
	solo.data.players.host.stamina = 30.0
	solo.action("host", "rest")
	solo.tick(2.0)
	_check(solo.data.players.host.stamina == 60.0 and solo.data.day == 1 and solo.data.minute > 360.0, "rest restores stamina without advancing day or freezing time")
	solo.action("host", "sleep")
	_check(solo.data.day == 2 and solo.data.minute == 360.0, "solo explicit sleep advances day")
	_check(not solo.data.players.host.sleep_ready and solo.data.players.host.stamina == 100.0, "new day restores stamina and clears readiness")
	var world = _world(true)
	_place(world, "host", "deck", 230, 170)
	_place(world, "guest", "water", 120, 100)
	world.action("host", "sleep")
	world.action("guest", "sleep")
	_check(world.data.day == 1 and world.data.players.host.sleep_ready and not world.data.players.guest.sleep_ready, "one ready player cannot force a diver into next day")
	world.leave("guest")
	_check(not world.data.players.host.sleep_ready and world.data.day == 1, "leaving clears readiness instead of accidentally advancing day")
	world.join("guest", "伙伴")
	_place(world, "host", "deck", 230, 170)
	world.action("host", "sleep")
	world.set_move("host", Vector2.RIGHT)
	_check(not world.data.players.host.sleep_ready and not world.data.players.host.resting, "moving cancels readiness and rest")
	world.action("host", "sleep")
	_place(world, "guest", "deck", 305, 170)
	world.action("guest", "sleep")
	_check(world.data.day == 2, "both online players explicitly sleeping advances day")
	world.data.players.host.sleep_ready = true
	world.leave("guest")
	world.data.players.host.sleep_ready = true
	Inventory.add(world.data.players.guest.bag, "wood", 3)
	world.join("guest", "新的伙伴")
	_check(not world.data.players.host.sleep_ready, "joining cancels previous readiness")
	_check(_bag(world, "guest", "wood") == 3 and world.data.players.guest.area == "deck", "guest slot preserves its bag and reconnects safely")


func _test_loop_and_daily_limits() -> void:
	var world = _world()
	_place(world, "host", "deck", 565, 175)
	world.action("host", "plant")
	world.action("host", "water")
	_place(world, "host", "deck", 720, 410)
	world.action("host", "dive")
	Inventory.add(world.data.players.host.bag, "harpoon", 1)
	for entity_id in ["fish_00", "fish_01", "fish_02", "wood_00", "wood_01", "wood_02", "wood_03"]:
		var entity: Dictionary = world.data.entities[entity_id]
		_place(world, "host", "water", entity.x, entity.y)
		if entity.kind == "fish":
			Skills.spear_fish(world, "host", entity_id)
		else:
			Skills.gather(world, "host", "collect", entity_id)
	_place(world, "host", "water", 120, 65)
	world.action("host", "surface")
	_place(world, "host", "deck", 420, 175)
	world.action("host", "deposit")
	world.tick(66.0)
	_place(world, "host", "deck", 565, 175)
	world.action("host", "harvest")
	_check(_bag(world, "host", "veg") == 3 and _bag(world, "host", "seed") == 1 and _stored(world, "seed") == 2, "harvest puts vegetables and replacement seed in personal pack")
	world.action("host", "harvest")
	_check(_bag(world, "host", "veg") == 3, "harvest cannot duplicate rewards")
	_place(world, "host", "deck", 420, 290)
	for index in 3:
		world.action("host", "cook")
		world.tick(10.1)
		world.action("host", "collect_output", {"id": "legacy_grill"})
	_check(_bag(world, "host", "meal") == 3 and _stored(world, "fish") == 0 and _bag(world, "host", "veg") == 0, "recipes consume personal and shared ingredients exactly")
	_place(world, "host", "deck", 565, 290)
	for index in 3:
		world.action("host", "sell")
	_check(world.data.money == 24 and world.data.orders_filled == 3, "three orders reward exactly 24 coins")
	Inventory.add(world.data.players.host.bag, "meal", 1)
	world.action("host", "sell")
	_check(world.data.money == 24 and _bag(world, "host", "meal") == 1, "daily order cap rejects additional sales without consumption")
	_place(world, "host", "deck", 710, 385)
	world.action("host", "build")
	_check(world.data.expansion == 1 and _stored(world, "wood") == 0 and world.data.money == 16, "first expansion consumes intended resources")
	world.action("host", "build")
	_check(world.data.expansion == 1 and world.data.money == 16, "unaffordable expansion is atomic")
	_place(world, "host", "deck", 565, 175)
	world.action("host", "plant")
	world.action("host", "water")
	_place(world, "host", "deck", 230, 170)
	world.action("host", "sleep")
	_check(world.data.orders_filled == 0 and world.data.entities.fish_00.active and world.data.entities.wood_00.active, "next day replenishes limited orders and gathered entities")
	_check(world.data.crop.stage == 2 and world.data.expansion == 1, "watered crop matures overnight and construction persists")


func _test_input_expiry() -> void:
	var world = _world()
	_place(world, "host", "deck", 480, 390)
	var start: float = world.data.players.host.x
	world.set_move("host", Vector2(10, 0))
	world.tick(1.0)
	_check(is_equal_approx(float(world.data.players.host.x) - start, WorldState.DECK_SPEED * WorldState.INPUT_TIMEOUT), "oversized input is normalized and expires after 0.4 seconds")
	var stopped: float = world.data.players.host.x
	world.tick(1.0)
	_check(world.data.players.host.x == stopped, "stale input does not keep moving player")
	world.set_move("host", Vector2(INF, 0))
	world.tick(0.1)
	_check(world.data.players.host.x == stopped, "non-finite movement is rejected")
	_place(world, "host", "water", 200.0, 200.0)
	world.set_move("host", Vector2.RIGHT)
	world.tick(0.2)
	var light_distance: float = world.data.players.host.x - 200.0
	_fill_bag(world, "host")
	_place(world, "host", "water", 200.0, 200.0)
	world.set_move("host", Vector2.RIGHT)
	world.tick(0.2)
	var loaded_distance: float = world.data.players.host.x - 200.0
	_check(is_equal_approx(loaded_distance, light_distance * 0.8), "full underwater pack reduces swimming speed by 20 percent")
	world.leave("host")
	var elapsed: float = world.data.elapsed
	world.tick(10.0)
	_check(world.data.elapsed == elapsed, "empty session does not simulate")


func _test_save_roundtrip_and_rejection() -> void:
	var world = _world(true)
	world.data.money = 17
	Inventory.add(world.data.players.guest.bag, "wood", 3)
	world.data.players.host.sleep_ready = true
	world.data.players.host.resting = true
	world.set_move("guest", Vector2.RIGHT)
	var detached: Dictionary = world.snapshot()
	detached.chests.chest_0.slots[0].count = 19
	_check(_stored(world, "seed") == 3, "snapshots do not expose mutable live nested dictionaries")
	var decoded: Variant = JSON.parse_string(JSON.stringify(world.snapshot()))
	var restored = WorldState.new()
	_check(decoded is Dictionary and restored.restore(decoded), "actual JSON-decoded numeric fields restore successfully")
	_check(restored.data.money == 17 and _bag(restored, "guest", "wood") == 3, "roundtrip preserves world economy and offline guest bag")
	_check(not restored.data.players.host.online and not restored.data.players.guest.online and not restored.data.players.host.resting and not restored.data.players.host.sleep_ready, "loading clears connection, rest and readiness flags")
	restored.join("guest", "伙伴")
	var x_before: float = restored.data.players.guest.x
	restored.tick(0.2)
	_check(restored.data.players.guest.area == "deck" and restored.data.players.guest.x == x_before, "loaded joining player is safe and has no stale movement")
	var baseline: Dictionary = restored.snapshot()
	var valid: Dictionary = world.snapshot()
	var corruptions: Array = []
	var bad: Dictionary = valid.duplicate(true)
	bad.version = 99
	corruptions.append(bad)
	bad = valid.duplicate(true)
	bad.chests.chest_0.slots[0].count = -1
	corruptions.append(bad)
	bad = valid.duplicate(true)
	bad.players.guest.bag[0].count = 21
	corruptions.append(bad)
	bad = valid.duplicate(true)
	bad.players.host.x = INF
	corruptions.append(bad)
	bad = valid.duplicate(true)
	bad.crop.progress = "broken"
	corruptions.append(bad)
	bad = valid.duplicate(true)
	bad.players.erase("host")
	corruptions.append(bad)
	bad = valid.duplicate(true)
	bad.entities.fish_00.active = "yes"
	corruptions.append(bad)
	bad = valid.duplicate(true)
	bad.money = 1.5
	corruptions.append(bad)
	bad = valid.duplicate(true)
	bad.players.host.online = 1
	corruptions.append(bad)
	for corrupted in corruptions:
		_check(not restored.restore(corrupted), "malformed save is rejected")
		_check(restored.snapshot() == baseline, "rejected save leaves current world unchanged")

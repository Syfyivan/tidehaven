extends SceneTree

const Actions = preload("res://scripts/underwater_actions.gd")
const Inventory = preload("res://scripts/inventory.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_durations_and_tools()
	_test_gather_cancellation()
	_test_gather_capacity_and_race()
	_test_spear_launch_and_collision()
	_test_spear_failures_and_race()
	_test_validation()
	print("UNDERWATER ACTION CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _data() -> Dictionary:
	return {"entities": {
		"wood_00": {"kind": "wood", "x": 235.0, "y": 200.0, "active": true},
		"stone_00": {"kind": "stone", "x": 240.0, "y": 215.0, "active": true},
		"ore_00": {"kind": "ore", "x": 235.0, "y": 185.0, "active": true},
		"wreck_00": {"kind": "wreck", "x": 245.0, "y": 225.0, "active": true},
		"fish_00": {"kind": "fish", "x": 280.0, "y": 200.0, "active": true},
	}}


func _player(tools: Array = []) -> Dictionary:
	var player := {"area": "water", "x": 200.0, "y": 200.0, "stamina": 100.0, "caught": 0, "bag": Inventory.empty_slots(Inventory.BAG_SIZE), "activity": {}}
	for item in tools:
		Inventory.add(player.bag, item, 1)
	return player


func _snapshot(data: Dictionary, player: Dictionary) -> Dictionary:
	return {"data": data.duplicate(true), "player": player.duplicate(true)}


func _test_durations_and_tools() -> void:
	var cases := [
		["collect", "wood_00", [], 8.0, "wood", 1, 2.0],
		["collect", "wood_00", ["axe"], 2.5, "wood", 1, 2.0],
		["mine", "stone_00", [], 12.0, "stone", 2, 4.0],
		["mine", "stone_00", ["pickaxe"], 3.0, "stone", 2, 4.0],
		["mine", "ore_00", [], 16.0, "ore", 1, 4.0],
		["mine", "ore_00", ["pickaxe"], 4.0, "ore", 1, 4.0],
		["search_wreck", "wreck_00", [], 7.0, "treasure", 1, 2.0],
	]
	for row in cases:
		var data := _data()
		var player := _player(row[2])
		Actions.start(data, player, row[0], {"id": row[1]})
		_check(player.activity.get("duration") == row[3] and player.stamina == 100.0 and data.entities[row[1]].active, "gather duration matches its actual carried tool without starting rewards or costs: " + str(row[1]))
		var pending: Dictionary = player.activity.duplicate(true)
		Actions.start(data, player, row[0], {"id": row[1]})
		_check(player.activity == pending, "repeated gather cannot restart or shorten its timer")
		var notice := Actions.tick(data, player, float(row[3]) - 0.1)
		_check(notice.is_empty() and Inventory.count(player.bag, row[4]) == 0 and data.entities[row[1]].active and player.stamina == 100.0, "gather never awards early")
		notice = Actions.tick(data, player, 0.11)
		_check(not notice.is_empty() and player.activity.is_empty() and not data.entities[row[1]].active and Inventory.count(player.bag, row[4]) == row[5] and player.stamina == 100.0 - float(row[6]), "completed gather gives the exact reward and pays once")
		var completed := _snapshot(data, player)
		Actions.tick(data, player, 20.0)
		_check(_snapshot(data, player) == completed, "completed activity cannot reward a second time")
	var data := _data()
	var player := _player(["pickaxe", "pickaxe"])
	Actions.start(data, player, "mine", {"id": "ore_00"})
	_check(player.activity.duration == 4.0, "multiple pickaxes do not stack their speed bonus")
	player = _player(["pickaxe"])
	Actions.start(data, player, "collect", {"id": "wood_00"})
	_check(player.activity.duration == 8.0, "a pickaxe does not accelerate wood gathering")


func _test_gather_cancellation() -> void:
	var data := _data()
	var player := _player()
	Actions.start(data, player, "collect", {"id": "wood_00"})
	player.x += 9.0
	Actions.tick(data, player, 8.0)
	_check(player.activity.is_empty() and data.entities.wood_00.active and Inventory.count(player.bag, "wood") == 0 and player.stamina == 100.0, "moving more than eight units cancels without consuming the target or stamina")
	player = _player()
	Actions.start(data, player, "collect", {"id": "wood_00"})
	player.x += 8.0
	Actions.tick(data, player, 8.0)
	_check(not data.entities.wood_00.active and Inventory.count(player.bag, "wood") == 1, "movement within the tolerance does not prevent a valid completion")
	data = _data()
	player = _player()
	Actions.start(data, player, "mine", {"id": "ore_00"})
	data.entities.ore_00.x = 500.0
	Actions.tick(data, player, 16.0)
	_check(player.activity.is_empty() and data.entities.ore_00.active and player.stamina == 100.0, "a target that is no longer nearby cancels gathering")
	data = _data()
	player = _player()
	Actions.start(data, player, "search_wreck", {"id": "wreck_00"})
	player.area = "deck"
	Actions.tick(data, player, 7.0)
	_check(player.activity.is_empty() and data.entities.wreck_00.active and player.stamina == 100.0, "leaving water cancels a wreck search")
	player = _player()
	Actions.start(data, player, "mine", {"id": "stone_00"})
	player.stamina = 3.0
	Actions.tick(data, player, 12.0)
	_check(player.activity.is_empty() and data.entities.stone_00.active and player.stamina == 3.0 and Inventory.count(player.bag, "stone") == 0, "completion rechecks stamina before collecting")
	player = _player()
	player.stamina = 1.0
	var before := _snapshot(data, player)
	Actions.start(data, player, "collect", {"id": "wood_00"})
	_check(_snapshot(data, player) == before, "insufficient starting stamina cannot begin gathering")


func _test_gather_capacity_and_race() -> void:
	var data := _data()
	var player := _player()
	Inventory.add(player.bag, "wood", Inventory.BAG_SIZE * Inventory.STACK_LIMIT)
	player.bag[0] = {"item": "stone", "count": 19}
	var slots: Array = player.bag.duplicate(true)
	Actions.start(data, player, "mine", {"id": "stone_00"})
	Actions.tick(data, player, 12.0)
	_check(player.bag == slots and player.stamina == 100.0 and data.entities.stone_00.active and player.activity.is_empty(), "a two-stone yield cannot partially fill a bag with room for only one")
	player = _player()
	Inventory.add(player.bag, "wood", Inventory.BAG_SIZE * Inventory.STACK_LIMIT)
	Actions.start(data, player, "search_wreck", {"id": "wreck_00"})
	Actions.tick(data, player, 7.0)
	_check(data.entities.wreck_00.active and player.stamina == 100.0 and Inventory.count(player.bag, "treasure") == 0, "a full bag leaves the searched wreck untouched")
	player.bag[0] = {"item": "treasure", "count": 19}
	Actions.start(data, player, "search_wreck", {"id": "wreck_00"})
	Actions.tick(data, player, 7.0)
	_check(not data.entities.wreck_00.active and Inventory.count(player.bag, "treasure") == 20 and player.stamina == 98.0, "existing treasure stack capacity permits one complete wreck reward")
	var first := _player()
	var second := _player()
	Actions.start(data, first, "collect", {"id": "wood_00"})
	Actions.start(data, second, "collect", {"id": "wood_00"})
	Actions.tick(data, first, 8.0)
	Actions.tick(data, second, 8.0)
	_check(Inventory.count(first.bag, "wood") == 1 and Inventory.count(second.bag, "wood") == 0 and first.stamina == 98.0 and second.stamina == 100.0 and second.activity.is_empty(), "two completed timers cannot duplicate one shared gather node")


func _test_spear_launch_and_collision() -> void:
	var data := _data()
	var player := _player(["harpoon"])
	Actions.start(data, player, "spear", {"x": 1000.0, "y": 0.0})
	_check(player.activity.get("phase") == "windup" and player.activity.dx == 1.0 and player.stamina == 100.0 and data.entities.fish_00.active, "spear captures a normalized fixed direction and starts a real windup")
	Actions.tick(data, player, 0.29)
	_check(player.activity.phase == "windup" and player.stamina == 100.0 and Inventory.count(player.bag, "fish") == 0, "spear does not spend stamina or catch fish before launch")
	Actions.tick(data, player, 0.02)
	_check(player.activity.phase == "flight" and player.stamina == 95.0 and player.activity.x > 200.0 and data.entities.fish_00.active, "windup completion launches at finite speed and pays five stamina")
	var flight: Dictionary = player.activity.duplicate(true)
	_check(Actions.valid_activity(JSON.parse_string(JSON.stringify(flight))), "a partly flown spear survives strict JSON state validation")
	var before := _snapshot(data, player)
	Actions.start(data, player, "spear", {"x": 0.0, "y": 1.0})
	_check(_snapshot(data, player) == before, "another click cannot redirect an existing projectile")
	Actions.tick(data, player, 0.5)
	_check(not data.entities.fish_00.active and Inventory.count(player.bag, "fish") == 1 and player.caught == 1 and player.stamina == 95.0 and player.activity.phase == "cooldown", "swept collision catches a fish passed between frame endpoints exactly once")
	_check(Actions.valid_activity(player.activity), "hit cooldown keeps valid renderable projectile state")
	before = _snapshot(data, player)
	Actions.start(data, player, "spear", {"x": 1.0, "y": 0.0})
	_check(_snapshot(data, player) == before, "cooldown prevents repeated spear launches")
	Actions.tick(data, player, 0.91)
	_check(player.activity.is_empty() and player.caught == 1, "cooldown clears without a second reward")
	data = _data()
	data.entities.fish_near = {"kind": "fish", "x": 250.0, "y": 200.0, "active": true}
	player = _player(["harpoon"])
	Actions.start(data, player, "spear", {"x": 1.0, "y": 0.0})
	Actions.tick(data, player, 0.8)
	_check(not data.entities.fish_near.active and data.entities.fish_00.active and Inventory.count(player.bag, "fish") == 1, "a spear hits the nearest fish along its sweep regardless of dictionary order")


func _test_spear_failures_and_race() -> void:
	var data := _data()
	var player := _player(["harpoon"])
	Actions.start(data, player, "spear", {"x": 1.0, "y": 0.0})
	data.entities.fish_00.y = 250.0
	var notice := Actions.tick(data, player, 2.0)
	_check(data.entities.fish_00.active and Inventory.count(player.bag, "fish") == 0 and player.stamina == 95.0 and player.activity.is_empty() and notice.contains("没有命中"), "a fish that swims out of the aimed line can dodge a fixed-direction spear")
	data = _data()
	data.entities.fish_00.x = 390.0
	player = _player(["harpoon"])
	Actions.start(data, player, "spear", {"x": 1.0, "y": 0.0})
	Actions.tick(data, player, 2.0)
	_check(data.entities.fish_00.active and player.caught == 0, "a fish beyond the projectile range and collision radius is never caught")
	data = _data()
	player = _player(["harpoon"])
	Inventory.add(player.bag, "wood", Inventory.BAG_SIZE * Inventory.STACK_LIMIT)
	Actions.start(data, player, "spear", {"x": 1.0, "y": 0.0})
	Actions.tick(data, player, 0.8)
	_check(data.entities.fish_00.active and player.caught == 0 and Inventory.count(player.bag, "fish") == 0 and player.stamina == 95.0 and player.activity.phase == "cooldown", "a full bag preserves the struck fish, but the fired spear still costs stamina")
	var first := _player(["harpoon"])
	var second := _player(["harpoon"])
	Actions.start(data, first, "spear", {"x": 1.0, "y": 0.0})
	Actions.start(data, second, "spear", {"x": 1.0, "y": 0.0})
	Actions.tick(data, first, 0.8)
	Actions.tick(data, second, 0.8)
	_check(Inventory.count(first.bag, "fish") + Inventory.count(second.bag, "fish") == 1 and first.caught + second.caught == 1 and first.stamina == 95.0 and second.stamina == 95.0, "two shots cannot award the same fish twice")
	data = _data()
	player = _player(["harpoon"])
	Actions.start(data, player, "spear", {"x": 1.0, "y": 0.0})
	player.area = "deck"
	Actions.tick(data, player, 0.3)
	_check(player.activity.is_empty() and player.stamina == 100.0 and data.entities.fish_00.active, "leaving water before launch cancels without spending stamina")
	player = _player(["harpoon"])
	Actions.start(data, player, "spear", {"x": 1.0, "y": 0.0})
	Inventory.remove(player.bag, "harpoon", 1)
	Actions.tick(data, player, 0.3)
	_check(player.activity.is_empty() and player.stamina == 100.0, "discarding the spear during windup prevents a phantom launch")
	player = _player(["harpoon"])
	Actions.start(data, player, "spear", {"x": 1.0, "y": 0.0})
	player.stamina = 4.0
	Actions.tick(data, player, 0.3)
	_check(player.activity.is_empty() and player.stamina == 4.0, "launch rechecks stamina at the end of windup")


func _test_validation() -> void:
	var data := _data()
	var player := _player()
	var before := _snapshot(data, player)
	Actions.start(data, player, "spear", {"x": 1.0, "y": 0.0})
	Actions.start(data, player, "catch", {})
	_check(_snapshot(data, player) == before, "neither bare-handed spear nor legacy catch can award an instant fish")
	player = _player(["harpoon"])
	before = _snapshot(data, player)
	for args in [{}, {"id": "fish_00"}, {"x": 0, "y": 0}, {"x": INF, "y": 1}, {"x": NAN, "y": 0}, {"x": "1", "y": 0}, {"x": true, "y": 0}, {"x": 1, "y": 0, "id": "fish_00"}]:
		Actions.start(data, player, "spear", args)
	for args in [{}, {"id": 2}, {"id": "fish_00"}, {"id": "unknown"}, {"id": "ore_00", "duration": 0.0}]:
		Actions.start(data, player, "mine", args)
	Actions.start(data, player, "collect", {"id": "stone_00"})
	Actions.start(data, player, "search_wreck", {"id": "wood_00"})
	Actions.start(data, player, "catch", {"id": "fish_00"})
	_check(_snapshot(data, player) == before, "forged IDs, zero or non-finite aim, target locks and client duration overrides change nothing")
	Actions.start(data, player, "mine", {"id": "ore_00"})
	var gather: Dictionary = player.activity.duplicate(true)
	_check(Actions.valid_activity(gather) and Actions.valid_activity({}) and Actions.valid_activity(JSON.parse_string(JSON.stringify(gather))), "empty and real gather states satisfy the save contract")
	before = _snapshot(data, player)
	for delta in [0.0, -1.0, INF, NAN]:
		Actions.tick(data, player, delta)
	_check(_snapshot(data, player) == before, "invalid time steps cannot accelerate an activity")
	var invalid: Array = [null, [], {"kind": "unknown"}]
	for property in ["duration", "remaining", "start_x"]:
		var bad: Dictionary = gather.duplicate(true)
		bad[property] = INF
		invalid.append(bad)
	var bad: Dictionary = gather.duplicate(true)
	bad.remaining = -1.0
	invalid.append(bad)
	bad = gather.duplicate(true)
	bad.duration = 0.0
	invalid.append(bad)
	bad = gather.duplicate(true)
	bad.reward = "fish"
	invalid.append(bad)
	player.activity = {}
	Actions.start(data, player, "spear", {"x": 1.0, "y": 1.0})
	var spear: Dictionary = player.activity.duplicate(true)
	_check(Actions.valid_activity(spear), "normalized diagonal spear windup is valid")
	for property in ["x", "dx", "duration", "distance"]:
		bad = spear.duplicate(true)
		bad[property] = NAN
		invalid.append(bad)
	bad = spear.duplicate(true)
	bad.dx = 0.0
	bad.dy = 0.0
	invalid.append(bad)
	bad = spear.duplicate(true)
	bad.distance = 10.0
	invalid.append(bad)
	bad = spear.duplicate(true)
	bad.phase = "homing"
	invalid.append(bad)
	bad = spear.duplicate(true)
	bad.target = "fish_00"
	invalid.append(bad)
	for malformed in invalid:
		_check(not Actions.valid_activity(malformed), "malformed action state fails strict finite save validation")

extends SceneTree
const World = preload("res://scripts/world_state.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Hook = preload("res://scripts/salvage_hook.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_hook()
	_test_mooring()
	_test_save_and_tools()
	print("SAILING SKILL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + label)

func fresh():
	var world = World.new()
	world.join("host", "船长")
	world.join("guest", "伙伴")
	world.data.navigation.anchored = true
	for item in world.data.drift.values():
		item.active = false
	var item: Dictionary = world.data.drift.drift_00
	item.active = true
	item.x = 610.0
	item.y = 288.0
	return world

func step_hook(world, seconds: float) -> void:
	for index in ceili(seconds / 0.02):
		world.data.elapsed += 0.02
		for player in world.data.players.values():
			Hook.tick(world.data, player, 0.02, Vector2.ZERO)

func _test_hook() -> void:
	var world = fresh()
	var host: Dictionary = world.data.players.host
	var before: Dictionary = world.snapshot()
	world.action("host", "hook", {"id": "drift_00"})
	check(world.snapshot() == before, "old id RPC cannot claim or target resources")
	for args in [{"x": NAN, "y": 0}, {"x": INF, "y": 0}, {"x": 2, "y": 0}, {"x": 0, "y": 0}, {"x": "1", "y": 0}]:
		world.action("host", "hook", args)
		check(host.hook.is_empty(), "reject invalid cast direction")
	world.action("host", "hook", {"x": 1, "y": 0})
	check(Hook.valid(host.hook), "runtime hook matches persisted schema")
	step_hook(world, 0.4)
	check(host.hook.cargo.is_empty() and Inventory.count(host.bag, "wood") == 0, "flight takes time")
	step_hook(world, 0.7)
	check(host.hook.cargo == ["drift_00"] and Inventory.count(host.bag, "wood") == 0, "collision reserves cargo without reward")
	world.action("guest", "hook", {"x": 1, "y": 0})
	step_hook(world, 1.0)
	check(world.data.players.guest.hook.cargo.is_empty(), "second player cannot catch reserved cargo")
	world.action("host", "pull_hook")
	step_hook(world, 0.2)
	check(Inventory.count(host.bag, "wood") == 0, "reeling is not instant")
	step_hook(world, 3.0)
	check(Inventory.count(host.bag, "wood") == 2 and not world.data.drift.drift_00.active, "only completed reel awards once")
	world.action("host", "pull_hook")
	step_hook(world, 1.0)
	check(Inventory.count(host.bag, "wood") == 2, "repeat reel cannot duplicate")
	world = fresh()
	host = world.data.players.host
	world.action("host", "hook", {"x": -1, "y": 0})
	step_hook(world, 2)
	check(host.hook.phase == "float" and host.hook.cargo.is_empty(), "wrong direction misses and rests on water")
	world.action("host", "pull_hook")
	step_hook(world, 3)
	check(host.hook.is_empty() and Inventory.count(host.bag, "wood") == 0, "empty hook returns without reward")
	world = fresh()
	host = world.data.players.host
	for index in host.bag.size():
		host.bag[index] = {"item": "wood", "count": 20}
	world.action("host", "hook", {"x": 1, "y": 0})
	step_hook(world, 1)
	world.action("host", "pull_hook")
	step_hook(world, 2)
	check(world.data.drift.drift_00.active and Inventory.count(host.bag, "wood") == 240 and not Hook.reserved(world.data, "drift_00"), "full bag releases original resource")
	world = fresh()
	world.action("host", "hook", {"x": 1, "y": 0})
	step_hook(world, 1)
	world.leave("host")
	check(world.data.drift.drift_00.active and not Hook.reserved(world.data, "drift_00"), "disconnect releases reservation without loss")
	check(not Hook.wind(0).is_equal_approx(Hook.wind(40)) and Hook.wave(0) != Hook.wave(40), "wind and wave conditions vary over time")

func _test_mooring() -> void:
	var world = fresh()
	var host: Dictionary = world.data.players.host
	world.data.navigation.anchored = false
	host.x = 570.0
	Inventory.add(host.bag, "rope", 1)
	var before: Dictionary = world.snapshot()
	world.action("host", "moor")
	check(world.snapshot() == before, "cannot moor away from island")
	world.data.navigation.x = 520.0
	world.data.navigation.y = 120.0
	world.action("host", "moor")
	check(world.data.navigation.moored and world.data.navigation.anchored and Inventory.count(host.bag, "rope") == 0, "coast uses rope instead of anchor")
	before = world.snapshot()
	world.action("host", "raise_anchor")
	check(world.snapshot() == before and Inventory.count(host.bag, "anchor") == 0, "G cannot turn mooring rope into anchor")
	world.action("host", "land")
	check(host.area == "island", "rope mooring supports actual landing")
	world.action("guest", "unmoor")
	check(world.data.navigation.moored, "cannot abandon island partner")
	world.action("host", "board_raft")
	world.action("host", "unmoor")
	check(not world.data.navigation.anchored and not world.data.navigation.moored and Inventory.count(host.bag, "rope") == 1, "unmoor recovers exactly rope")
	world.action("host", "drop_anchor")
	check(not world.data.navigation.anchored, "rope cannot substitute for sea anchor")
	Inventory.add(host.bag, "anchor", 1)
	world.action("host", "drop_anchor")
	check(world.data.navigation.anchored and not world.data.navigation.moored, "sea anchor remains separate")
	world.action("host", "raise_anchor")
	check(Inventory.count(host.bag, "anchor") == 1, "sea anchor is recoverable")
	for option in world.interaction_options("host"):
		check(option.action not in ["drop_anchor", "raise_anchor"], "context E/O no duplicate G anchor action")

func _test_save_and_tools() -> void:
	var world = fresh()
	var host: Dictionary = world.data.players.host
	world.action("host", "set_destination", {"id": "island_home"})
	check(str(world.data.chart.destination).is_empty(), "server denies waypoint without personal compass")
	Inventory.add(world.data.players.guest.bag, "compass", 1)
	world.action("host", "set_destination", {"id": "island_home"})
	check(str(world.data.chart.destination).is_empty(), "partner compass does not unlock map")
	for entry in [{"item": "scrap", "count": 3}, {"item": "plastic", "count": 2}, {"item": "rope", "count": 1}]:
		Inventory.add(host.bag, entry.item, entry.count)
	world.action("host", "craft", {"recipe": "compass"})
	check(Inventory.count(host.bag, "compass") == 1 and Inventory.count(host.bag, "scrap") == 0, "compass crafts for exact costs")
	world.action("host", "set_destination", {"id": "island_home"})
	check(world.data.chart.destination == "island_home", "compass permits waypoint")
	world.action("host", "hook", {"x": 1, "y": 0})
	step_hook(world, 1)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.snapshot(), "", false, true))
	var loaded = World.new()
	check(loaded.restore(saved), "v8 saves while hook holds resource")
	check(loaded.data.players.host.hook.is_empty() and loaded.data.drift.drift_00.active and Inventory.count(loaded.data.players.host.bag, "compass") == 1, "resume cancels transient hook without rewards or loss")
	var old: Dictionary = saved.duplicate(true)
	old.version = 7
	old.island = {"resources": {"palm_0": true,"palm_1": true,"seeds_0": true,"stone_0": true,"ore_0": true,"wood_1": true}, "crop": {"stage": 0, "progress": 0.0, "watered": false}}
	old.navigation.erase("moored")
	for player in old.players.values():
		player.erase("activity")
		player.erase("can_water")
		player.hook = {}
	check(loaded.restore(old) and loaded.data.version == 10, "v7 migrates to v9")
	var bad: Dictionary = saved.duplicate(true)
	bad.players.host.hook.dx = NAN
	check(not loaded.restore(bad), "malformed projectile rejected atomically")
	bad = saved.duplicate(true)
	bad.navigation.moored = true
	check(not loaded.restore(bad), "mooring save must be at coast")

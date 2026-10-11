extends SceneTree

const WorldState = preload("res://scripts/world_state.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Navigation = preload("res://scripts/navigation.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_motion_and_relative_current()
	_test_paddle_requirements()
	_test_invalid_strokes()
	_test_anchor_conservation()
	_test_diving_and_partner_guard()
	_test_four_edge_recycling()
	_test_save_and_migration()
	print("NAVIGATION TESTS: %d checks, %d failures" % [checks, failures])
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

func _give(world, slot: String, item: String, amount := 1) -> void:
	Inventory.add(world.data.players[slot].bag, item, amount)

func _point(value: Dictionary) -> Vector2:
	return Vector2(float(value.x), float(value.y))

func _anchors(world) -> int:
	var total: int = 1 if bool(world.data.navigation.anchored) else 0
	for player in world.data.players.values():
		total += Inventory.count(player.bag, "anchor")
	for chest in world.data.chests.values():
		total += Inventory.count(chest.slots, "anchor")
	return total

func _drift_fixture(world, position := Vector2(100, 100)) -> Dictionary:
	var drift: Dictionary = world.data.drift.drift_00
	drift.x = position.x
	drift.y = position.y
	drift.speed = 16.0
	drift.phase = 0.0
	drift.sway = 4.0
	drift.active = true
	drift.respawn = 0.0
	return drift

func _test_motion_and_relative_current() -> void:
	var floating = _world()
	var stopped = _world()
	var pushed = _world()
	var floating_drift := _drift_fixture(floating)
	var stopped_drift := _drift_fixture(stopped)
	var pushed_drift := _drift_fixture(pushed)
	_check(floating.data.version == 10 and not floating.data.navigation.anchored and _anchors(floating) == 0, "fresh v7 world starts drifting without a free anchor")
	_give(stopped, "host", "anchor")
	stopped.action("host", "drop_anchor")
	_give(pushed, "host", "paddle")
	pushed.action("host", "paddle", {"x": 1.0, "y": 0.0})
	var feet: Vector2 = _point(floating.data.players.host)
	for world in [floating, stopped, pushed]:
		world.tick(0.25)
	_check(_point(floating.data.navigation).distance_to(Navigation.CURRENT * 0.25) < 0.001 and float(floating.data.navigation.distance) > 0, "unanchored raft accumulates real position and travel distance")
	_check(_point(stopped.data.navigation) == Vector2.ZERO and float(stopped.data.navigation.distance) == 0 and Navigation.velocity(stopped.data.navigation) == Vector2.ZERO, "anchored raft stays completely still while time advances")
	_check(float(pushed.data.navigation.x) > float(floating.data.navigation.x) and float(pushed.data.navigation.push_x) < Navigation.STROKE, "a real paddle action increases travel and its push decays over time")
	_check(_point(floating.data.players.host) == feet, "travel preserves the player's local deck coordinates")
	_check((_point(stopped_drift) - _point(floating_drift)).distance_to(_point(floating.data.navigation)) < 0.001, "salvage displacement differs by exactly raft displacement when anchoring")
	_check(float(pushed_drift.x) < 100.0 and float(floating_drift.x) > 100.0, "rowing faster than salvage reverses its relative screen direction")

func _test_paddle_requirements() -> void:
	var world = _world(true)
	_give(world, "guest", "paddle")
	var before: Dictionary = world.snapshot()
	world.action("host", "paddle", {"x": 1.0, "y": 0.0})
	_check(world.snapshot() == before, "a partner's paddle cannot be used from the host's empty bag")
	_give(world, "host", "paddle")
	var host_energy: float = world.data.players.host.stamina
	var guest_energy: float = world.data.players.guest.stamina
	world.action("host", "paddle", {"x": 1.0, "y": 1.0})
	var push := Vector2(float(world.data.navigation.push_x), float(world.data.navigation.push_y))
	_check(is_equal_approx(push.length(), Navigation.STROKE) and world.data.players.host.stamina == host_energy - 2.0 and world.data.players.guest.stamina == guest_energy, "diagonal stroke is normalized and spends exactly two actor stamina")
	_check(Inventory.count(world.data.players.host.bag, "paddle") == 1, "rowing preserves the reusable paddle")
	before = world.snapshot()
	world.action("host", "paddle", {"x": 1.0, "y": 0.0})
	_check(world.snapshot() == before, "repeated strokes during cooldown cannot spend stamina or add velocity")
	world.action("guest", "paddle", {"x": 0.0, "y": -1.0})
	_check(world.data.players.guest.stamina == guest_energy - 2.0 and world.data.navigation.guest_cooldown == Navigation.COOLDOWN and world.data.navigation.host_cooldown == Navigation.COOLDOWN, "partners have independent stroke cooldowns")
	world.tick(Navigation.COOLDOWN + 0.01)
	world.action("host", "paddle", {"x": 1.0, "y": 0.0})
	_check(world.data.players.host.stamina == host_energy - 4.0, "a new stroke is accepted after the cooldown expires")
	_give(world, "host", "anchor")
	world.action("host", "drop_anchor")
	before = world.snapshot()
	world.action("guest", "paddle", {"x": 0.0, "y": -1.0})
	_check(world.snapshot() == before and Navigation.velocity(world.data.navigation) == Vector2.ZERO, "an anchored raft cannot be pushed by either player")

func _test_invalid_strokes() -> void:
	var world = _world()
	_give(world, "host", "paddle")
	var malformed := [{}, {"x": 1}, {"x": true, "y": 0}, {"x": "east", "y": 0}, {"x": [], "y": 0}, {"x": NAN, "y": 0}, {"x": INF, "y": 0}, {"x": 2.0, "y": 0}, {"x": 0, "y": -1.01}, {"x": 0.0, "y": 0.0}, {"x": 0.01, "y": 0.01}]
	for args in malformed:
		var before: Dictionary = world.snapshot()
		world.action("host", "paddle", args)
		_check(world.snapshot() == before, "malformed, nonfinite or ineffective direction leaves the complete world unchanged")
	var before: Dictionary = world.snapshot()
	world.action("intruder", "paddle", {"x": 1, "y": 0})
	world.action("guest", "paddle", {"x": 1, "y": 0})
	_check(world.snapshot() == before, "unknown and offline slots cannot steer")
	world.data.players.host.stamina = 1.0
	before = world.snapshot()
	world.action("host", "paddle", {"x": 1, "y": 0})
	_check(world.snapshot() == before, "insufficient stamina cannot partially apply a stroke")
	world.data.players.host.stamina = 100.0
	world.data.players.host.hook = {"id": "drift_00", "remaining": 0.5, "duration": 1.0, "x": 100.0, "y": 100.0}
	before = world.snapshot()
	world.action("host", "paddle", {"x": 1, "y": 0})
	_check(world.snapshot() == before, "an active hook must finish before rowing")
	world.data.players.host.hook = {}
	world.data.players.host.fishing = {"remaining": 2.0, "result": "fish"}
	before = world.snapshot()
	world.action("host", "paddle", {"x": 1, "y": 0})
	_check(world.snapshot() == before, "an active fishing line must finish before rowing")

func _test_anchor_conservation() -> void:
	var world = _world(true)
	var before: Dictionary = world.snapshot()
	world.action("host", "drop_anchor")
	_check(world.snapshot() == before, "dropping an unowned anchor cannot stop the raft")
	_give(world, "host", "anchor", 2)
	world.action("host", "drop_anchor")
	_check(bool(world.data.navigation.anchored) and Inventory.count(world.data.players.host.bag, "anchor") == 1 and _anchors(world) == 2, "dropping transfers exactly one carried anchor into the shared world")
	before = world.snapshot()
	world.action("guest", "drop_anchor")
	_check(world.snapshot() == before, "duplicate drop requests cannot consume another anchor")
	world.action("guest", "raise_anchor")
	_check(not bool(world.data.navigation.anchored) and Inventory.count(world.data.players.guest.bag, "anchor") == 1 and _anchors(world) == 2, "the other deck player can retrieve the same shared anchor")
	before = world.snapshot()
	world.action("host", "raise_anchor")
	_check(world.snapshot() == before, "duplicate retrieval cannot award a second copy")
	world = _world(true)
	_give(world, "host", "anchor")
	world.action("host", "drop_anchor")
	_give(world, "host", "wood", Inventory.BAG_SIZE * Inventory.STACK_LIMIT)
	before = world.snapshot()
	world.action("host", "raise_anchor")
	_check(world.snapshot() == before and _anchors(world) == 1, "a full recipient bag leaves the world anchored and loses nothing")
	world.data.players.host.bag[0] = {"item": "anchor", "count": 19}
	var guest_bag: Array = world.data.players.guest.bag.duplicate(true)
	world.action("host", "raise_anchor")
	_check(not world.data.navigation.anchored and Inventory.count(world.data.players.host.bag, "anchor") == 20 and Inventory.used(world.data.players.host.bag) == Inventory.BAG_SIZE and world.data.players.guest.bag == guest_bag, "retrieval uses an existing partial anchor stack even when every slot is occupied")

func _test_diving_and_partner_guard() -> void:
	var world = _world(true)
	for slot in ["host", "guest"]:
		world.data.players[slot].x = 544.0
		world.data.players[slot].y = 352.0
		_give(world, slot, "paddle")
	_give(world, "host", "anchor")
	var before: Dictionary = world.snapshot()
	world.action("guest", "dive")
	_check(world.snapshot() == before, "a real deck edge still requires anchoring before diving")
	world.action("host", "drop_anchor")
	world.action("guest", "dive")
	_check(world.data.players.guest.area == "water" and world.data.players.host.area == "deck", "anchoring permits one partner to dive independently")
	before = world.snapshot()
	world.action("host", "raise_anchor")
	_check(world.snapshot() == before and _anchors(world) == 1, "a diver blocks the deck partner from retrieving the shared anchor")
	for verb in ["paddle", "drop_anchor", "raise_anchor"]:
		world.action("guest", verb, {"x": 1.0, "y": 0.0})
	_check(world.snapshot() == before, "a submerged player cannot steer, drop or retrieve an anchor")
	world.action("guest", "surface")
	world.action("host", "raise_anchor")
	_check(world.data.players.guest.area == "deck" and not world.data.navigation.anchored and _anchors(world) == 1, "after a normal buoy return the same anchor can be recovered")

func _test_four_edge_recycling() -> void:
	var cases := [
		{"direction": Vector2.LEFT, "point": Vector2(979.9, 60), "edge": "left"},
		{"direction": Vector2.RIGHT, "point": Vector2(-89.9, 60), "edge": "right"},
		{"direction": Vector2.UP, "point": Vector2(100, 639.9), "edge": "top"},
		{"direction": Vector2.DOWN, "point": Vector2(100, -79.9), "edge": "bottom"},
	]
	for sample in cases:
		var world = _world()
		_give(world, "host", "paddle")
		var drift := _drift_fixture(world, sample.point)
		world.action("host", "paddle", {"x": sample.direction.x, "y": sample.direction.y})
		world.tick(0.03)
		_check(not drift.active and float(drift.respawn) >= 2.0 and float(drift.respawn) <= 7.0, "salvage crossing the %s-flow exit is recycled with a real delay" % sample.edge)
		for step in 80:
			world.action("host", "paddle", {"x": sample.direction.x, "y": sample.direction.y})
			world.tick(0.1)
			if drift.active:
				break
		var enters_correctly := false
		match sample.edge:
			"left": enters_correctly = float(drift.x) < 0
			"right": enters_correctly = float(drift.x) > 900
			"top": enters_correctly = float(drift.y) < 0
			"bottom": enters_correctly = float(drift.y) > 560
		_check(drift.active and enters_correctly and not world.deck_rect().has_point(_point(drift)), "sustained rowing replenishes salvage from the %s upstream edge" % sample.edge)

func _same_navigation(first: Dictionary, second: Dictionary) -> bool:
	if first.anchored != second.anchored:
		return false
	for key in ["x", "y", "distance", "push_x", "push_y", "host_cooldown", "guest_cooldown"]:
		if not is_equal_approx(float(first[key]), float(second[key])):
			return false
	return true

func _test_save_and_migration() -> void:
	var world = _world(true)
	_give(world, "host", "paddle")
	_give(world, "guest", "anchor")
	world.action("host", "paddle", {"x": 0.0, "y": 1.0})
	world.tick(0.2)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.snapshot()))
	var loaded = WorldState.new()
	_check(loaded.restore(saved) and loaded.data.version == 10 and _same_navigation(loaded.data.navigation, world.data.navigation), "v7 JSON roundtrip preserves travel, momentum and individual cooldowns")
	_check(loaded.data.players.host.bag == world.data.players.host.bag and loaded.data.players.guest.bag == world.data.players.guest.bag and _anchors(loaded) == 1, "sailing saves preserve both personal bags and total anchor supply")
	loaded.join("host", "船长")
	var distance: float = loaded.data.navigation.distance
	loaded.tick(0.1)
	_check(float(loaded.data.navigation.distance) > distance, "a restored sailing world continues travelling after joining")
	world.action("guest", "drop_anchor")
	_check(loaded.restore(JSON.parse_string(JSON.stringify(world.snapshot()))) and loaded.data.navigation.anchored and _anchors(loaded) == 1, "an anchor deployed in the world survives saving without becoming an extra inventory item")
	var old_world = _world()
	_give(old_world, "host", "fish", 3)
	var old: Dictionary = old_world.snapshot()
	old.version = 5
	for player in old.players.values():
		player.erase("activity")
		player.erase("can_water")
	old.erase("navigation")
	old.erase("chart")
	old.erase("island")
	old.players.host.area = "water"
	old.players.host.x = 120.0
	old.players.host.y = 100.0
	old.entities.fish_00.active = false
	_check(loaded.restore(JSON.parse_string(JSON.stringify(old))) and loaded.data.version == 10 and loaded.data.navigation.anchored and loaded.data.players.host.area == "water" and not loaded.data.entities.fish_00.active, "a genuine v5 underwater save migrates safely moored without resetting its harvest")
	loaded.join("host", "船长")
	loaded.action("host", "raise_anchor")
	_check(not loaded.data.navigation.anchored and Inventory.count(loaded.data.players.host.bag, "anchor") == 1 and Inventory.count(loaded.data.players.host.bag, "fish") == 3, "the one migration anchor is recoverable while preserving old belongings")
	var migrated: Dictionary = JSON.parse_string(JSON.stringify(loaded.snapshot()))
	_check(loaded.restore(migrated) and _anchors(loaded) == 1 and not loaded.data.navigation.anchored, "reloading migrated v7 data does not grant another migration anchor")
	var baseline: Dictionary = loaded.snapshot()
	var invalid: Array = []
	for value in [null, [], {}, {"anchored": true}]:
		var bad: Dictionary = baseline.duplicate(true)
		bad.navigation = value
		invalid.append(bad)
	for change in [{"key": "anchored", "value": 1}, {"key": "x", "value": true}, {"key": "y", "value": "north"}, {"key": "x", "value": NAN}, {"key": "y", "value": INF}, {"key": "distance", "value": -1.0}, {"key": "x", "value": 1.0e16}, {"key": "push_x", "value": 100.0}, {"key": "host_cooldown", "value": -0.1}, {"key": "guest_cooldown", "value": 1.0}]:
		var bad: Dictionary = baseline.duplicate(true)
		bad.navigation[change.key] = change.value
		invalid.append(bad)
	var bad: Dictionary = baseline.duplicate(true)
	bad.erase("navigation")
	invalid.append(bad)
	bad = baseline.duplicate(true)
	bad.navigation.erase("push_y")
	invalid.append(bad)
	bad = baseline.duplicate(true)
	bad.navigation.extra = 0
	invalid.append(bad)
	bad = baseline.duplicate(true)
	bad.navigation.anchored = true
	bad.navigation.push_x = 1.0
	invalid.append(bad)
	for value in invalid:
		_check(not loaded.restore(value) and loaded.snapshot() == baseline, "malformed navigation is rejected atomically without replacing the live world")

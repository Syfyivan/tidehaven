extends SceneTree
const World = preload("res://scripts/world_state.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Hook = preload("res://scripts/salvage_hook.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_outbound()
	_return_path()
	_float_path()
	_capacity()
	_ownership_and_restore()
	print("MULTI HOOK: %d checks, %d failures" % [checks, failures])
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
	return world

func place(world, id: String, at: Vector2) -> void:
	var item: Dictionary = world.data.drift[id]
	item.active = true
	item.x = at.x
	item.y = at.y

func step(world, seconds: float) -> void:
	for index in ceili(seconds / 0.02):
		world.data.elapsed += 0.02
		for player in world.data.players.values():
			Hook.tick(world.data, player, 0.02, Vector2.ZERO)

func cargo(player: Dictionary) -> Array:
	var value: Variant = player.hook.get("cargo", [])
	# Allows the pre-fix implementation to fail assertions instead of crashing.
	return value if value is Array else ([] if str(value).is_empty() else [value])

func _outbound() -> void:
	var world = fresh()
	var host: Dictionary = world.data.players.host
	place(world, "drift_00", Vector2(580, 288))
	place(world, "drift_01", Vector2(700, 288))
	world.action("host", "hook", {"x": 1, "y": 0})
	step(world, 0.8)
	check(cargo(host).has("drift_00"), "first resource attaches on physical contact")
	check(host.hook.phase == "out", "first resource must not stop outbound travel")
	step(world, 1.0)
	check(cargo(host) == ["drift_00", "drift_01"], "one outward throw carries successive resources")
	check(Inventory.total_count(host.bag) == 0, "multiple contacts do not pre-award")
	check(Hook.reserved(world.data, "drift_00") and Hook.reserved(world.data, "drift_01"), "every carried resource is reserved")
	world.action("host", "pull_hook")
	step(world, 3)
	check(host.hook.is_empty() and Inventory.count(host.bag, "wood") == 2 and Inventory.count(host.bag, "leaf") == 2, "outward haul lands together")

func _return_path() -> void:
	var world = fresh()
	var host: Dictionary = world.data.players.host
	world.action("host", "hook", {"x": 1, "y": 0})
	step(world, 1.8)
	check(host.hook.phase == "float" and cargo(host).is_empty(), "cast into empty water needs no selected object")
	# Resources drift into the retrieval corridor only after the throw has passed.
	place(world, "drift_00", Vector2(650, 290))
	place(world, "drift_01", Vector2(700, 290))
	place(world, "drift_02", Vector2(700, 290))
	place(world, "drift_03", Vector2(660, 350))
	world.action("host", "pull_hook")
	step(world, 1.1)
	check(cargo(host).size() == 3, "retrieval catches successive and overlapping objects in one sweep")
	check(cargo(host).slice(0, 2).has("drift_01") and cargo(host).slice(0, 2).has("drift_02") and cargo(host).back() == "drift_00", "cargo follows contact order instead of drift dictionary order")
	check(Inventory.total_count(host.bag) == 0, "reel cargo remains outside bag until reaching hand")
	world.action("host", "pull_hook")
	step(world, 2)
	check(Inventory.count(host.bag, "wood") == 2 and Inventory.count(host.bag, "leaf") == 2 and Inventory.count(host.bag, "plastic") == 2, "one empty cast returns three resource types")
	check(world.data.drift.drift_03.active and Inventory.count(host.bag, "scrap") == 0, "off-path material is never magnetically collected")
	world.action("host", "pull_hook")
	step(world, 0.5)
	check(Inventory.total_count(host.bag) == 6, "repeated pull cannot duplicate multi haul")

func _float_path() -> void:
	var world = fresh()
	var host: Dictionary = world.data.players.host
	world.action("host", "hook", {"x": 1, "y": 0})
	step(world, 1.8)
	var tip := Vector2(float(host.hook.x), float(host.hook.y))
	place(world, "drift_00", tip)
	step(world, 0.1)
	place(world, "drift_01", Vector2(float(host.hook.x), float(host.hook.y)))
	step(world, 0.1)
	check(host.hook.phase == "float" and cargo(host).size() == 2, "floating tip continues collecting without automatic retrieval")
	check(Vector2(float(host.hook.x), float(host.hook.y)).distance_to(tip) > 1, "carrying cargo does not freeze drift")

func _capacity() -> void:
	var world = fresh()
	var host: Dictionary = world.data.players.host
	for index in host.bag.size():
		host.bag[index] = {"item": "stone", "count": 20}
	host.bag[0] = {"item": "wood", "count": 18}
	world.action("host", "hook", {"x": 1, "y": 0})
	step(world, 1.8)
	place(world, "drift_04", Vector2(710, 290))
	place(world, "drift_01", Vector2(675, 290))
	place(world, "drift_00", Vector2(630, 290))
	world.action("host", "pull_hook")
	step(world, 3)
	check(Inventory.count(host.bag, "wood") == 20 and not world.data.drift.drift_00.active, "a rejected barrel must not block a later resource that fits")
	check(world.data.drift.drift_04.active and world.data.drift.drift_01.active, "overflow objects remain intact on the water")
	check(Inventory.count(host.bag, "seed") == 0 and Inventory.count(host.bag, "leaf") == 0 and Inventory.total_count(host.bag) == 240, "barrel cannot partly award before rejection")
	check(not Hook.reserved(world.data, "drift_04") and not Hook.reserved(world.data, "drift_01"), "overflow reservations released")

func _ownership_and_restore() -> void:
	var world = fresh()
	var host: Dictionary = world.data.players.host
	place(world, "drift_00", Vector2(580, 288))
	place(world, "drift_01", Vector2(700, 288))
	world.action("host", "hook", {"x": 1, "y": 0})
	step(world, 1.8)
	world.action("guest", "hook", {"x": 1, "y": 0})
	step(world, 1.8)
	check(cargo(world.data.players.guest).is_empty(), "another hook cannot duplicate any item in multi cargo")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(world.snapshot(), "", false, true))
	var loaded = World.new()
	check(loaded.restore(saved), "in-flight multi cargo save is accepted")
	check(loaded.data.players.host.hook.is_empty() and Inventory.total_count(loaded.data.players.host.bag) == 0 and loaded.data.drift.drift_00.active and loaded.data.drift.drift_01.active, "resume releases every cargo object without auto-award or loss")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.players.host.hook.cargo = "drift_00"
	legacy.players.guest.hook.cargo = ""
	check(loaded.restore(legacy) and loaded.data.players.host.hook.is_empty() and loaded.data.drift.drift_00.active, "0.8 single-id in-flight save still resumes safely")
	for value in [["drift_00", "drift_00"], [12], [""], {"id": "drift_00"}]:
		var bad: Dictionary = saved.duplicate(true)
		bad.players.host.hook.cargo = value
		check(not loaded.restore(bad), "malformed multi cargo must reject restore")
	world.leave("host")
	check(not Hook.reserved(world.data, "drift_00") and not Hook.reserved(world.data, "drift_01") and world.data.drift.drift_00.active and world.data.drift.drift_01.active, "disconnect releases all captured resources")

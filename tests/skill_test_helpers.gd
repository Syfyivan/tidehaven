extends RefCounted

# Fixtures control positions; all rewards still pass through normal host actions and ticks.
static func gather(world, slot: String, verb: String, id: String) -> void:
	world.action(slot, verb, {"id": id})
	finish_activity(world, slot)


static func finish_activity(world, slot: String) -> void:
	for step in 400:
		if world.data.players[slot].activity.is_empty():
			return
		world.tick(0.05)


static func aim_at_fish(world, slot: String, id: String) -> void:
	var player: Dictionary = world.data.players[slot]
	var fish: Dictionary = world.data.entities[id]
	world.set_move(slot, Vector2.ZERO)
	world.data.navigation.anchored = true
	player.area = "water"
	player.x = maxf(40.0, float(fish.x) - 25.0)
	player.y = float(fish.y)
	world.action(slot, "spear", {"x": 1.0, "y": 0.0})


static func spear_fish(world, slot: String, id: String) -> void:
	aim_at_fish(world, slot, id)
	world.tick(0.5)
	finish_activity(world, slot)


static func stage_drift(world, id: String, distance := 100.0) -> void:
	world.data.navigation.anchored = true
	world.data.navigation.push_x = 0.0
	world.data.navigation.push_y = 0.0
	for slot in ["host", "guest"]:
		world.set_move(slot, Vector2.ZERO)
		world.data.players[slot].area = "deck"
		world.data.players[slot].x = 544.0
		world.data.players[slot].y = 288.0
	for item in world.data.drift.values():
		item.active = false
		item.respawn = 7.0
	var target: Dictionary = world.data.drift[id]
	target.active = true
	target.respawn = 0.0
	target.x = 544.0 + distance
	target.y = 288.0
	target.speed = 12.0
	target.sway = 4.0
	target.phase = fposmod(PI / 2.0 - float(world.data.elapsed) * 0.45, TAU)


static func await_hook_contact(world, slot: String) -> void:
	for step in 70:
		var hook: Dictionary = world.data.players[slot].hook
		if hook.is_empty() or not hook.cargo.is_empty() or hook.phase == "float":
			return
		world.tick(0.05)


static func reel(world, slots: Array) -> void:
	for slot in slots:
		world.action(slot, "pull_hook")
	for step in 160:
		var pending := false
		for slot in slots:
			pending = pending or not world.data.players[slot].hook.is_empty()
		if not pending:
			return
		world.tick(0.05)


static func hook_and_reel(world, slot: String) -> void:
	world.action(slot, "hook", {"x": 1.0, "y": 0.0})
	await_hook_contact(world, slot)
	reel(world, [slot])

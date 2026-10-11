extends RefCounted
## Directional host simulation. A client never supplies a resource id or reward.
const Inventory = preload("res://scripts/inventory.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
const CAST_SPEED := 160.0
const REEL_SPEED := 115.0
const HIT_RADIUS := 13.0

static func wind(time: float) -> Vector2:
	return Vector2(5.0 + sin(time * 0.071) * 4.0, sin(time * 0.11) * 5.0)

static func wave(time: float) -> float:
	return 0.5 + 0.5 * sin(time * 0.053)

static func start(player: Dictionary, args: Dictionary) -> String:
	if player.area != "deck":
		return "站在甲板上，朝海面抛钩。"
	if not player.hook.is_empty() or not player.fishing.is_empty():
		return "先收回手里的钩子或鱼竿。"
	for key in ["x", "y"]:
		if typeof(args.get(key)) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(args[key])) or absf(float(args[key])) > 1.0:
			return "请选择抛钩方向。"
	var direction := Vector2(float(args.x), float(args.y))
	if direction.length_squared() < 0.01:
		return "朝远一点的海面抛钩。"
	direction = direction.normalized()
	var upgraded := Inventory.count(player.bag, "reinforced_hook") > 0
	player.hook = {"phase": "out", "x": float(player.x), "y": float(player.y), "dx": direction.x, "dy": direction.y, "travel": 0.0, "reach": 400.0 if upgraded else 280.0, "reel_speed": 155.0 if upgraded else REEL_SPEED, "age": 0.0, "cargo": []}
	player.resting = false
	player.sleep_ready = false
	return "钩子已出手 · 右键 / P 收回"

static func pull(player: Dictionary) -> String:
	if player.hook.is_empty():
		return "钩子已在手里。"
	if player.hook.phase == "reel":
		return "正在收绳……"
	player.hook.phase = "reel"
	return "收绳中 · 沿途碰到的物资也会带回"

static func reserved(data: Dictionary, id: String) -> bool:
	for player in data.players.values():
		if id in player.get("hook", {}).get("cargo", []):
			return true
	return false

static func tick(data: Dictionary, player: Dictionary, delta: float, travel_velocity: Vector2) -> String:
	if player.hook.is_empty():
		return ""
	if player.area != "deck":
		player.hook = {}
		return ""
	var remaining := delta
	while remaining > 0.00001 and not player.hook.is_empty():
		var step := minf(remaining, 0.04)
		remaining -= step
		var hook: Dictionary = player.hook
		hook.age += step
		var before := Vector2(float(hook.x), float(hook.y))
		var hand := Vector2(float(player.x), float(player.y))
		var after := before
		var time := float(data.elapsed) - remaining
		if hook.phase == "out":
			after += (Vector2(float(hook.dx), float(hook.dy)) * CAST_SPEED + wind(time) - travel_velocity) * step
			hook.travel += CAST_SPEED * step
			if float(hook.travel) >= float(hook.reach):
				hook.phase = "float"
		elif hook.phase == "float":
			after += (wind(time) + Vector2(4, sin(time * 2.0) * (2 + 4 * wave(time))) - travel_velocity) * step
			if float(hook.age) > 10.0 or after.distance_to(hand) > float(hook.reach) + 35:
				hook.phase = "reel"
		else:
			after = before.move_toward(hand, float(hook.reel_speed) * step)
		hook.x = after.x
		hook.y = after.y
		# Every phase sweeps the tip. Catching cargo never stops or redirects it.
		var contacts: Array = []
		var island_center := Vector2(480, 288) + Archipelago.island_position(data.chart) + Archipelago.ISLAND_BODY_OFFSET - Vector2(float(data.navigation.x), float(data.navigation.y))
		for id in data.drift:
			var item: Dictionary = data.drift[id]
			if not item.active or reserved(data, str(id)):
				continue
			var point := Vector2(float(item.x), float(item.y))
			if point.distance_to(island_center) < Archipelago.ISLAND_WORLD_RADIUS + 20:
				continue
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, before, after)) <= HIT_RADIUS:
				contacts.append({"id": str(id), "distance": before.distance_squared_to(point)})
		contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
		for contact in contacts:
			hook.cargo.append(contact.id)
		if hook.phase == "reel" and after.distance_to(hand) <= 1:
			var cargo: Array = hook.cargo
			player.hook = {}
			return _land_cargo(data, player, cargo)
	return ""

static func _land_cargo(data: Dictionary, player: Dictionary, cargo: Array) -> String:
	var landed := 0
	var overflow := 0
	var totals: Dictionary = {}
	for id in cargo:
		if not data.drift.has(id) or not data.drift[id].active:
			continue
		var item: Dictionary = data.drift[id]
		var rewards := {"wood": 2, "leaf": 2, "plastic": 2, "scrap": 1, "seed": 1} if item.kind == "barrel" else {item.kind: 1 if item.kind == "scrap" else 2}
		var bag: Array = player.bag.duplicate(true)
		var fits := true
		for kind in rewards:
			if Inventory.add(bag, kind, int(rewards[kind])) != 0:
				fits = false
				break
		if not fits:
			overflow += 1
			continue
		# Each object is atomic; an oversized barrel must not block later cargo.
		player.bag = bag
		item.active = false
		item.respawn = 4.0
		landed += 1
		for kind in rewards:
			totals[kind] = int(totals.get(kind, 0)) + int(rewards[kind])
	if landed == 0:
		return "背包放不下，物资仍留在水面。" if overflow > 0 else "空钩收回 · 试着让回收路线经过漂浮物"
	var contents := PackedStringArray()
	for kind in totals:
		contents.append("%s +%d" % [Inventory.ITEM_NAMES[kind], totals[kind]])
	return "、".join(contents) + (" · %d件放不下，留在海面" % overflow if overflow > 0 else " → 背包")

static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	if value.size() != 10 or value.get("phase") not in ["out", "float", "reel"]:
		return false
	var cargo: Variant = value.get("cargo")
	if cargo is String:
		# 0.8 saves used one id. Restore cancels all transient hooks, old or new.
		if cargo.length() > 64:
			return false
	elif cargo is Array:
		if cargo.size() > 16:
			return false
		var seen := {}
		for id in cargo:
			if not id is String or id.is_empty() or id.length() > 64 or seen.has(id):
				return false
			seen[id] = true
	else:
		return false
	for key in ["x", "y", "dx", "dy", "travel", "reach", "reel_speed", "age"]:
		if typeof(value.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value[key])):
			return false
	return absf(float(value.x)) <= 2000 and absf(float(value.y)) <= 2000 and absf(Vector2(float(value.dx), float(value.dy)).length() - 1) < 0.001 and float(value.travel) >= 0 and float(value.travel) <= 410 and float(value.reach) in [280.0, 400.0] and float(value.reel_speed) in [115.0, 155.0] and float(value.age) >= 0 and float(value.age) < 100000

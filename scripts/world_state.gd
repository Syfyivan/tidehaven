extends RefCounted

const SalvageHook = preload("res://scripts/salvage_hook.gd")
const UnderwaterActions = preload("res://scripts/underwater_actions.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Recipes = preload("res://scripts/recipes.gd")
const Navigation = preload("res://scripts/navigation.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
const IslandState = preload("res://scripts/island_state.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const IslandActivity = preload("res://scripts/island_activity.gd")
const Farming = preload("res://scripts/farming.gd")
const IslandTown = preload("res://scripts/island_town.gd")
var migration_notice := ""
const SLOTS := ["host", "guest"]
const BAG_ITEMS := ["fish", "wood", "veg", "meal"]
const STORAGE_ITEMS := ["fish", "wood", "veg", "meal", "seed"]
const BAG_CAPACITY := Inventory.BAG_SIZE * Inventory.STACK_LIMIT
const CHEST_POSITIONS := [Vector2(350, 420), Vector2(430, 420), Vector2(510, 420), Vector2(590, 420)]
const FISHING_SECONDS := 5.0
const MAX_SAVED_CHESTS := 4096
const TILE_SIZE := 64
const HOOK_DISTANCE := 280.0
const HOOK_SECONDS := 1.0
const DRIFT_CURRENT := Vector2(1.0, 0.10)
const DRIFT_KINDS := ["wood", "leaf", "plastic", "scrap", "barrel", "wood", "leaf", "plastic", "wood", "leaf", "plastic", "scrap", "barrel", "wood", "leaf", "plastic"]
const BUILD_DISTANCE := 220.0
const STRUCTURE_KINDS := ["bedroll", "bed", "purifier", "grill", "garden", "orders", "furnace"]
const INTERACTION_DISTANCE := 64.0
const INPUT_TIMEOUT := 0.4
const CROP_SECONDS := 65.0
const OXYGEN_PER_SECOND := 0.65
const MINUTES_PER_SECOND := 6.0
const DECK_SPEED := 155.0
const WATER_SPEED := 135.0
const STATIONS := {
	"storage": Vector2(420, 175), "garden": Vector2(565, 175),
	"kitchen": Vector2(420, 290), "orders": Vector2(565, 290),
	"expansion": Vector2(710, 385), "hatch": Vector2(670, 410),
	"buoy": Vector2(120, 65),
	"fishing": Vector2(185, 385),
}

var data: Dictionary
var _inputs: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _travel_velocity := Vector2.ZERO


func _init() -> void:
	_rng.randomize()
	var initial_tiles: Array = []
	for gx in range(6, 9):
		for gy in range(3, 6):
			initial_tiles.append(_tile_key(gx, gy))
	data = {
		"version": 10, "day": 1, "minute": 360.0, "elapsed": 0.0,
		"navigation": Navigation.create(), "chart": Archipelago.create(Navigation.create()), "island": IslandState.create(),
		"money": 0, "chests": {}, "deck_tiles": initial_tiles,
		"structures": {"bedroll_0": _new_structure("bedroll_0", "bedroll", Vector2(416, 224))},
		"drift": _new_drift(initial_tiles),
		"expansion": 0, "crop": {"stage": 0, "progress": 0.0, "watered": false},
		"orders_filled": 0, "orders_limit": 3,
		"players": {"host": _new_player("船长"), "guest": _new_player("伙伴")},
		"entities": _new_entities(),
	}


func _new_chest(id: String, label: String, point: Vector2, slots: Array) -> Dictionary:
	return {"id": id, "name": label, "x": point.x, "y": point.y, "slots": slots}


func _new_structure(id: String, kind: String, point: Vector2) -> Dictionary:
	return {"id": id, "kind": kind, "x": point.x, "y": point.y, "remaining": 0.0, "output": ""}


func _new_drift(tiles: Array = []) -> Dictionary:
	var result: Dictionary = {}
	# A few loose supplies near the starting raft make the first hook immediately useful.
	var nearby := [Vector2(310, 218), Vector2(434, 136), Vector2(640, 256), Vector2(452, 452), Vector2(627, 407)]
	var bounds := _tiles_rect(tiles) if not tiles.is_empty() else Rect2(384, 192, 192, 192)
	for index in DRIFT_KINDS.size():
		var point := Vector2.ZERO
		for attempt in 20:
			point = nearby[index] + Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-18, 18)) if index < nearby.size() else Vector2(_rng.randf_range(64, 872), _rng.randf_range(40, 520))
			point = _outside_raft(point, bounds, 22.0)
			var separated := true
			for other in result.values():
				if point.distance_to(Vector2(float(other.x), float(other.y))) < 44.0:
					separated = false
					break
			if separated:
				break
		var item := {"kind": DRIFT_KINDS[index], "x": point.x, "y": point.y, "active": true, "respawn": 0.0}
		_drift_variation(item)
		result["drift_%02d" % index] = item
	return result


func _drift_variation(item: Dictionary) -> void:
	item.speed = _rng.randf_range(12.0, 20.0)
	item.phase = _rng.randf_range(0.0, TAU)
	item.sway = _rng.randf_range(4.0, 10.0)


func _outside_raft(point: Vector2, bounds: Rect2, margin: float) -> Vector2:
	var blocked := bounds.grow(margin)
	if not blocked.has_point(point):
		return point
	var choices := [Vector2(blocked.position.x, point.y), Vector2(blocked.end.x, point.y), Vector2(point.x, maxf(16.0, blocked.position.y)), Vector2(point.x, minf(544.0, blocked.end.y))]
	var nearest: Vector2 = choices[0]
	for candidate in choices:
		if point.distance_squared_to(candidate) < point.distance_squared_to(nearest):
			nearest = candidate
	return nearest


func _new_player(display_name: String) -> Dictionary:
	return {
		"name": display_name, "online": false, "area": "deck", "x": 480.0, "y": 288.0,
		"oxygen": 100.0, "stamina": 100.0, "resting": false, "sleep_ready": false,
		"bag": Inventory.empty_slots(Inventory.BAG_SIZE), "caught": 0, "fishing": {},
		"hunger": 80.0, "thirst": 75.0, "hook": {}, "activity": {}, "can_water": 0, "notice": "", "notice_id": 0,
	}


func _new_entities(include_minerals := true, include_wrecks := true) -> Dictionary:
	var result: Dictionary = {}
	var fish_positions := [Vector2(195, 155), Vector2(350, 235), Vector2(535, 190), Vector2(710, 285), Vector2(445, 405), Vector2(760, 440)]
	var wood_positions := [Vector2(180, 95), Vector2(265, 170), Vector2(380, 310), Vector2(590, 330), Vector2(635, 445), Vector2(250, 410), Vector2(810, 165), Vector2(540, 485)]
	for index in fish_positions.size():
		var point: Vector2 = fish_positions[index]
		result["fish_%02d" % index] = {"kind": "fish", "x": point.x, "y": point.y, "base_x": point.x, "base_y": point.y, "phase": index * 0.8, "active": true}
	for index in wood_positions.size():
		var point: Vector2 = wood_positions[index]
		result["wood_%02d" % index] = {"kind": "wood", "x": point.x, "y": point.y, "active": true}
	if include_minerals:
		var deposits := {
			"stone": [Vector2(290, 275), Vector2(425, 310), Vector2(555, 365), Vector2(685, 400), Vector2(330, 465), Vector2(785, 485)],
			"ore": [Vector2(475, 285), Vector2(650, 300), Vector2(800, 335), Vector2(395, 395), Vector2(510, 460), Vector2(635, 495), Vector2(735, 470), Vector2(825, 430)],
		}
		for kind in deposits:
			for index in deposits[kind].size():
				var point: Vector2 = deposits[kind][index]
				result["%s_%02d" % [kind, index]] = {"kind": kind, "x": point.x, "y": point.y, "active": true}
		if include_wrecks:
			result["wreck_00"] = {"kind": "wreck", "x": 305.0, "y": 365.0, "active": true}
			result["wreck_01"] = {"kind": "wreck", "x": 710.0, "y": 505.0, "active": true}
	return result


static func hook_distance(player: Dictionary) -> float:
	return 400.0 if Inventory.count(player.bag, "reinforced_hook") > 0 else HOOK_DISTANCE


static func hook_seconds(player: Dictionary) -> float:
	return 0.65 if Inventory.count(player.bag, "reinforced_hook") > 0 else HOOK_SECONDS


static func water_speed(player: Dictionary) -> float:
	return WATER_SPEED * (1.3 if Inventory.count(player.bag, "fins") > 0 else 1.0)


func join(slot: String, display_name: String) -> bool:
	if not slot in SLOTS:
		return false
	var player: Dictionary = data.players[slot]
	player.name = display_name.strip_edges().left(32) if not display_name.strip_edges().is_empty() else ("船长" if slot == "host" else "伙伴")
	player.online = true
	if player.area == "island" and data.chart.visited and data.navigation.anchored and Archipelago.within_docking_range(data.chart, data.navigation) and IslandMap.walkable(Vector2(player.x, player.y)):
		player.oxygen = 100.0
		player.resting = false
		player.sleep_ready = false
		player.activity = {}
		player.fishing = {}
		player.hook = {}
	else:
		_safe_deck(player, slot)
	_clear_ready()
	_inputs.erase(slot)
	return true


func leave(slot: String) -> void:
	if not slot in SLOTS or not data.players[slot].online:
		return
	var player: Dictionary = data.players[slot]
	player.online = false
	_safe_deck(player, slot)
	_inputs.erase(slot)
	_clear_ready()


func _safe_deck(player: Dictionary, slot: String) -> void:
	var point := _safe_position(slot)
	player.area = "deck"
	player.x = point.x
	player.y = point.y
	player.oxygen = 100.0
	player.resting = false
	player.sleep_ready = false
	player.fishing = {}
	player.hook = {}
	player.activity = {}


func _clear_ready() -> void:
	for slot in SLOTS:
		data.players[slot].sleep_ready = false


func set_move(slot: String, direction: Vector2) -> void:
	if not _is_online(slot) or not direction.is_finite():
		return
	var movement := direction.limit_length(1.0)
	_inputs[slot] = {"direction": movement, "age": 0.0}
	if movement.length_squared() > 0.001:
		data.players[slot].resting = false
		data.players[slot].sleep_ready = false


func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or not _any_online():
		return
	data.elapsed += delta
	data.minute = minf(1430.0, float(data.minute) + delta * MINUTES_PER_SECOND)
	var old_position := Vector2(float(data.navigation.x), float(data.navigation.y))
	var old_distance := float(data.navigation.distance)
	Navigation.tick(data.navigation, delta)
	# Keep the hull off the island shore; the western dock remains approachable.
	var island_center: Vector2 = Archipelago.island_position(data.chart) + Archipelago.ISLAND_BODY_OFFSET
	var raft_position := Vector2(float(data.navigation.x), float(data.navigation.y))
	if not bool(data.navigation.anchored) and raft_position.distance_to(island_center) < 215:
		var away := (raft_position - island_center).normalized()
		raft_position = island_center + (Vector2.LEFT if away.is_zero_approx() else away) * 215
		data.navigation.x = raft_position.x
		data.navigation.y = raft_position.y
		data.navigation.push_x = 0.0
		data.navigation.push_y = 0.0
	data.navigation.distance = old_distance + raft_position.distance_to(old_position)
	_travel_velocity = (raft_position - old_position) / delta
	_tick_drift(delta)
	for structure in data.structures.values():
		if float(structure.remaining) > 0.0:
			structure.remaining = maxf(0.0, float(structure.remaining) - delta)
	for crop in [data.crop]:
		if int(crop.stage) == 1 and crop.watered:
			crop.progress = minf(1.0, float(crop.progress) + delta / CROP_SECONDS)
			if crop.progress >= 1.0:
				crop.stage = 2
	for slot in SLOTS:
		var player: Dictionary = data.players[slot]
		if not player.online:
			continue
		player.hunger = maxf(0.0, float(player.hunger) - delta * 0.05)
		player.thirst = maxf(0.0, float(player.thirst) - delta * 0.08)
		if _inputs.has(slot):
			var movement: Dictionary = _inputs[slot]
			var moving_delta := minf(delta, maxf(0.0, INPUT_TIMEOUT - float(movement.age)))
			movement.age += delta
			if moving_delta > 0.0 and not player.resting:
				var direction: Vector2 = movement.direction
				var speed := water_speed(player) if player.area == "water" else DECK_SPEED
				if player.area == "water":
					speed *= 1.0 - 0.2 * float(_bag_count(player)) / BAG_CAPACITY
				if _needs_low(player):
					speed *= 0.7
				_move_player(player, direction * speed * moving_delta)
		if not player.fishing.is_empty():
			if not _fishing_location(player):
				player.fishing = {}
			else:
				player.fishing.remaining = maxf(0.0, float(player.fishing.remaining) - delta)
		_tick_hook(player, delta)
		var work_notice := ""
		if player.get("activity", {}).get("kind") == "town_bath":
			work_notice = IslandTown.tick(data, player, delta)
		elif player.get("activity", {}).get("kind") == "island_gather":
			work_notice = IslandActivity.tick(data, player, delta)
		else:
			work_notice = UnderwaterActions.tick(data, player, delta)
		if not work_notice.is_empty():
			_notify(player, work_notice)
		if player.area == "water":
			player.oxygen = maxf(0.0, float(player.oxygen) - delta * OXYGEN_PER_SECOND)
			if player.oxygen <= 0.0:
				_notify(player, "氧气耗尽，已返回木筏；本趟背包里的鱼丢失了。")
				Inventory.remove(player.bag, "fish", Inventory.count(player.bag, "fish"))
				_safe_deck(player, slot)
				_inputs.erase(slot)
		elif player.resting:
			player.stamina = minf(100.0, float(player.stamina) + delta * (5.0 if _needs_low(player) else 15.0))
	for entity in data.entities.values():
		if entity.kind == "fish" and entity.active:
			var phase := float(entity.phase)
			var time := float(data.elapsed)
			entity.x = clampf(float(entity.base_x) + sin(time * (0.43 + phase * 0.035) + phase) * 31.0 + sin(time * 0.19 + phase * 2.0) * 7.0, 40.0, 860.0)
			entity.y = clampf(float(entity.base_y) + sin(time * 0.37 + phase) * 12.0 + sin(time * 0.17 + phase * 1.7) * 4.0, 35.0, 520.0)


func _move_player(player: Dictionary, offset: Vector2) -> void:
	if player.area == "island":
		var steps := maxi(1, ceili(offset.length() / 8.0))
		var step := offset / steps
		for index in steps:
			var at := Vector2(float(player.x), float(player.y))
			if IslandMap.walkable(at + Vector2(step.x, 0)):
				player.x += step.x
			if IslandMap.walkable(Vector2(float(player.x), float(player.y) + step.y)):
				player.y += step.y
	elif player.area == "water":
		player.x = clampf(float(player.x) + offset.x, 40.0, 860.0)
		player.y = clampf(float(player.y) + offset.y, 35.0, 520.0)
	else:
		# Small substeps stop a delayed movement packet from tunnelling through a facility.
		var steps := maxi(1, ceili(offset.length() / 8.0))
		var step := offset / steps
		for index in steps:
			if _deck_walkable(Vector2(float(player.x) + step.x, float(player.y))):
				player.x += step.x
			if _deck_walkable(Vector2(float(player.x), float(player.y) + step.y)):
				player.y += step.y


func _tile_key(gx: int, gy: int) -> String:
	return "%d,%d" % [gx, gy]


func _point_tile(point: Vector2) -> String:
	return _tile_key(floori(point.x / TILE_SIZE), floori(point.y / TILE_SIZE))


func _tile_center(key: String) -> Vector2:
	var parts := key.split(",")
	return Vector2(int(parts[0]) * TILE_SIZE + TILE_SIZE / 2.0, int(parts[1]) * TILE_SIZE + TILE_SIZE / 2.0)


func deck_rect() -> Rect2:
	return _tiles_rect(data.deck_tiles)


func _tiles_rect(tiles: Array) -> Rect2:
	var result := Rect2(_tile_center(str(tiles[0])) - Vector2(32, 32), Vector2(64, 64))
	for key in tiles:
		result = result.merge(Rect2(_tile_center(key) - Vector2(32, 32), Vector2(64, 64)))
	return result


func _deck_walkable(point: Vector2) -> bool:
	return _walkable_in(point, data.deck_tiles, data.structures, data.chests)


func _walkable_in(point: Vector2, tiles: Array, structures: Dictionary, chests: Dictionary, excluded_id := "") -> bool:
	for corner in [Vector2(-10, -10), Vector2(10, -10), Vector2(-10, 10), Vector2(10, 10)]:
		if _point_tile(point + corner) not in tiles:
			return false
	for objects in [structures, chests]:
		for object in objects.values():
			if object.id == excluded_id:
				continue
			if absf(point.x - float(object.x)) < 29.0 and absf(point.y - float(object.y)) < 29.0:
				return false
	return true


func _safe_position(slot: String) -> Vector2:
	var preferred := Vector2(480, 288) if slot == "host" else Vector2(520, 288)
	if _deck_walkable(preferred):
		return preferred
	# Prefer free cells next to a bed, then any safe cell on the actual raft.
	for structure in data.structures.values():
		if structure.kind in ["bed", "bedroll"]:
			for offset in [Vector2(64, 0), Vector2(0, 64), Vector2(-64, 0), Vector2(0, -64)]:
				var point: Vector2 = Vector2(float(structure.x), float(structure.y)) + offset
				if _deck_walkable(point):
					return point
	for key in data.deck_tiles:
		var point := _tile_center(key)
		if _deck_walkable(point):
			return point
	return preferred # Placement and restore both require a walkable cell, so this is unreachable.


func at_edge(player: Dictionary) -> bool:
	return _edge_in_tiles(player, data.deck_tiles)


func _edge_in_tiles(player: Dictionary, tiles: Array) -> bool:
	if player.area != "deck":
		return false
	var gx := floori(float(player.x) / TILE_SIZE)
	var gy := floori(float(player.y) / TILE_SIZE)
	if _tile_key(gx, gy) not in tiles:
		return false
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _tile_key(gx + direction.x, gy + direction.y) not in tiles:
			return true
	return false


func can_place(slot: String, recipe_id: String, x: float, y: float) -> bool:
	if not _is_online(slot) or data.players[slot].area != "deck" or not Recipes.ALL.has(recipe_id) or not is_finite(x) or not is_finite(y):
		return false
	var recipe: Dictionary = Recipes.ALL[recipe_id]
	if recipe.structure.is_empty():
		return false
	var gx := floori(x / TILE_SIZE)
	var gy := floori(y / TILE_SIZE)
	var center := Vector2(gx * TILE_SIZE + 32, gy * TILE_SIZE + 32)
	if not center.is_equal_approx(Vector2(x, y)) or gx < 2 or gx > 11 or gy < 2 or gy > 6:
		return false
	var player: Dictionary = data.players[slot]
	if Vector2(float(player.x), float(player.y)).distance_to(center) > BUILD_DISTANCE:
		return false
	var key := _tile_key(gx, gy)
	if recipe.structure == "foundation":
		if key in data.deck_tiles:
			return false
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if _tile_key(gx + direction.x, gy + direction.y) in data.deck_tiles:
				return true
		return false
	return _can_occupy(slot, x, y)


func _can_occupy(slot: String, x: float, y: float, excluded_id := "") -> bool:
	if not is_finite(x) or not is_finite(y):
		return false
	var gx := floori(x / TILE_SIZE)
	var gy := floori(y / TILE_SIZE)
	var center := Vector2(gx * TILE_SIZE + 32, gy * TILE_SIZE + 32)
	if not center.is_equal_approx(Vector2(x, y)) or gx < 2 or gx > 11 or gy < 2 or gy > 6:
		return false
	var player: Dictionary = data.players[slot]
	if Vector2(float(player.x), float(player.y)).distance_to(center) > BUILD_DISTANCE:
		return false
	var key := _tile_key(gx, gy)
	if key not in data.deck_tiles:
		return false
	for objects in [data.structures, data.chests]:
		for object in objects.values():
			if object.id == excluded_id:
				continue
			if _point_tile(Vector2(float(object.x), float(object.y))) == key:
				return false
	for other in data.players.values():
		if other.online and other.area == "deck" and absf(float(other.x) - x) < 39.0 and absf(float(other.y) - y) < 39.0:
			return false
	return _placement_preserves_paths(key, excluded_id)


func can_relocate(slot: String, id: String, from_x: float, from_y: float, x: float, y: float) -> bool:
	if not _is_online(slot) or data.players[slot].area != "deck" or not is_finite(from_x) or not is_finite(from_y):
		return false
	var object := _relocatable(id)
	if object.is_empty() or float(object.x) != from_x or float(object.y) != from_y:
		return false
	if not _near(data.players[slot], Vector2(from_x, from_y)) or Vector2(from_x, from_y).is_equal_approx(Vector2(x, y)):
		return false
	return _can_occupy(slot, x, y, id)


func _relocatable(id: String) -> Dictionary:
	# IDs are stable across moves, including a chest that somebody has open.
	if data.chests.has(id) and data.structures.has(id):
		return {}
	if data.chests.has(id):
		return data.chests[id]
	return data.structures.get(id, {})


func _relocate(slot: String, args: Dictionary) -> String:
	if not args.get("id") is String:
		return "请先选择要搬动的设施。"
	for key in ["from_x", "from_y", "x", "y"]:
		if not _number(args.get(key), 0.0, 900.0):
			return "搬动位置无效，设施仍在原处。"
	if not can_relocate(slot, args.id, float(args.from_x), float(args.from_y), float(args.x), float(args.y)):
		return "这里不能放置，或设施已经被伙伴搬走；请靠近原位置重新选择。"
	var object := _relocatable(args.id)
	object.x = float(args.x)
	object.y = float(args.y)
	if object.get("kind", "") in ["bed", "bedroll"]:
		_clear_ready()
		for player in data.players.values():
			player.resting = false
	return "已搬好，里面的物品和加工进度都保留。"


func _placement_preserves_paths(occupied_key: String, excluded_id := "") -> bool:
	var free: Dictionary = {}
	for tile in data.deck_tiles:
		if tile != occupied_key and _walkable_in(_tile_center(tile), data.deck_tiles, data.structures, data.chests, excluded_id):
			free[tile] = true
	if free.is_empty():
		return false
	for player in data.players.values():
		if player.online and player.area == "deck" and not free.has(_point_tile(Vector2(float(player.x), float(player.y)))):
			return false
	var pending: Array = [free.keys()[0]]
	var visited: Dictionary = {pending[0]: true}
	while not pending.is_empty():
		var parts: PackedStringArray = str(pending.pop_front()).split(",")
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor := _tile_key(int(parts[0]) + direction.x, int(parts[1]) + direction.y)
			if free.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				pending.append(neighbor)
	return visited.size() == free.size()


func _needs_low(player: Dictionary) -> bool:
	return float(player.hunger) < 15.0 or float(player.thirst) < 15.0


func _notify(player: Dictionary, message: String) -> void:
	player.notice = message
	player.notice_id += 1


func _tick_drift(delta: float) -> void:
	var bounds := deck_rect()
	# Small steps also keep a delayed host frame from sending salvage through the raft.
	var steps := maxi(1, ceili(delta / 0.25))
	var step := delta / steps
	var time := float(data.elapsed) - delta
	for _index in steps:
		time += step
		for drift_id in data.drift:
			var drift: Dictionary = data.drift[drift_id]
			if SalvageHook.reserved(data, str(drift_id)):
				continue
			if not drift.active:
				drift.respawn = maxf(0.0, float(drift.respawn) - step)
				if float(drift.respawn) == 0.0:
					_drift_variation(drift)
					var entry_velocity: Vector2 = DRIFT_CURRENT * float(drift.speed) + Navigation.CURRENT - _travel_velocity
					if absf(entry_velocity.x) >= absf(entry_velocity.y):
						drift.x = _rng.randf_range(-80.0, -24.0) if entry_velocity.x >= 0 else _rng.randf_range(924.0, 974.0)
						drift.y = _rng.randf_range(36.0, 524.0)
					else:
						drift.x = _rng.randf_range(36.0, 864.0)
						drift.y = _rng.randf_range(-70.0, -24.0) if entry_velocity.y >= 0 else _rng.randf_range(584.0, 634.0)
					drift.active = true
				continue
			var point := _outside_raft(Vector2(float(drift.x), float(drift.y)), bounds, 18.0)
			var speed := float(drift.speed)
			var sway := (sin(time * 0.45 + float(drift.phase)) - sin((time - step) * 0.45 + float(drift.phase))) * float(drift.sway)
			var relative_velocity: Vector2 = DRIFT_CURRENT * speed + Navigation.CURRENT + SalvageHook.wind(time) * 0.45 - _travel_velocity
			var next := point + relative_velocity * step + Vector2(0, sway)
			var clearance := 22.0 + float(drift.sway) * 1.5
			var top := maxf(16.0, bounds.position.y - clearance)
			var bottom := minf(544.0, bounds.end.y + clearance)
			if relative_velocity.x > 0 and point.x > bounds.position.x - 105.0 and point.x < bounds.end.x + 18.0 and point.y > top and point.y < bottom:
				var target_y := top if point.y < bounds.get_center().y else bottom
				next.y = move_toward(point.y, target_y, speed * 1.8 * step)
				# The current curves around the bow; it never transports hidden objects under it.
				if next.x >= bounds.position.x - 18.0 and point.x <= bounds.position.x - 18.0 and next.y > bounds.position.y - 18.0 and next.y < bounds.end.y + 18.0:
					next.x = bounds.position.x - 18.0
			elif relative_velocity.x < 0 and point.x > bounds.position.x - 18.0 and point.x < bounds.end.x + 105.0 and point.y > top and point.y < bottom:
				next.y = move_toward(point.y, top if point.y < bounds.get_center().y else bottom, relative_velocity.length() * 1.8 * step)
			if absf(relative_velocity.y) > absf(relative_velocity.x) and point.y > bounds.position.y - 105 and point.y < bounds.end.y + 105 and point.x > bounds.position.x - 20 and point.x < bounds.end.x + 20:
				next.x = move_toward(point.x, bounds.position.x - 25 if point.x < bounds.get_center().x else bounds.end.x + 25, relative_velocity.length() * 1.8 * step)
			next = _outside_raft(next, bounds, 18.0)
			drift.x = clampf(next.x, -90.0, 980.0)
			drift.y = clampf(next.y, -80.0, 640.0)
			if next.x >= 980.0 or next.x <= -90.0 or next.y <= -80.0 or next.y >= 640.0:
				_recycle_drift(drift)


func _recycle_drift(drift: Dictionary) -> void:
	drift.active = false
	drift.respawn = _rng.randf_range(2.0, 7.0)


func _tick_hook(player: Dictionary, delta: float) -> void:
	var message := SalvageHook.tick(data, player, delta, _travel_velocity)
	if not message.is_empty():
		_notify(player, message)


func action(slot: String, verb: String, args: Dictionary = {}) -> String:
	if not _is_online(slot):
		return "玩家尚未加入。"
	var player: Dictionary = data.players[slot]
	if verb.begins_with("town_"):
		return IslandTown.action(data, player, verb, args)
	if verb == "gather_island":
		return IslandActivity.start(data, player, args)
	if verb in ["till", "cover", "clear_crop", "refill_can"] or (player.area == "island" and verb in ["plant", "water", "harvest"]):
		if not player.activity.is_empty():
			return "先等当前动作完成，或右键取消。"
		return Farming.action(data, player, verb, args)
	if verb in ["land", "board_raft", "set_destination"]:
		return _island_action(slot, verb, args)
	if verb == "cancel_activity":
		if player.activity.is_empty():
			return "当前没有采集。"
		if str(player.activity.kind) == "spear":
			return "等鱼叉收势后再出手。"
		player.activity = {}
		return "已停止采集，物资仍在原处。"
	if verb == "pull_hook":
		return SalvageHook.pull(player)
	if verb in ["paddle", "drop_anchor", "raise_anchor", "moor", "unmoor"]:
		return _navigation_action(slot, verb, args)
	if verb == "hook":
		return SalvageHook.start(player, args)
	if verb in ["collect", "mine", "search_wreck", "spear", "catch"]:
		var work_args := args.duplicate()
		if verb == "collect" and not work_args.has("id"):
			work_args["id"] = _nearest_entity(player, "wood")
		return UnderwaterActions.start(data, player, verb, work_args)
	if verb == "craft":
		return _craft(slot, args)
	if verb == "relocate":
		return _relocate(slot, args)
	if verb in ["purify", "grill_fish", "smelt", "collect_output"]:
		return _process_action(player, verb, args)
	if verb == "fill_cup":
		if not at_edge(player):
			return "请走到甲板边缘舀海水。"
		if not _personal_exchange(player, {"cup": 1}, {"saltwater": 1}):
			return "需要背包里的空杯，并留出一格装海水。"
		return "舀了一杯海水，放到净水器里才能喝。"
	if verb == "drink":
		if float(player.thirst) >= 100.0:
			return "现在不渴，先留着这杯水吧。"
		if not _personal_exchange(player, {"freshwater": 1}, {"cup": 1}):
			return "需要背包里的一杯淡水，并给空杯留出空间。"
		player.thirst = minf(100.0, float(player.thirst) + 50.0)
		return "喝了淡水，口渴恢复 50，空杯已放回背包。"
	if verb == "inventory_move":
		return _inventory_move(slot, args)
	if verb == "discard":
		return _discard(player, args)
	if verb == "sort_inventory":
		var container: Variant = args.get("container", "bag")
		if not container is String or not _container_access(slot, container):
			return "请靠近要整理的箱子；只能整理自己的背包。"
		Inventory.sort_slots(_container_slots(slot, container))
		return "已合并同类物品并整理空格。"
	if verb == "open_treasure":
		return _open_treasure(player, args)
	if verb == "cast" or verb == "reel":
		return _fishing_action(player, verb)
	if verb == "eat":
		var food: String = str(args.get("item", "meal" if Inventory.count(player.bag, "meal") > 0 else "cooked_fish"))
		if food not in ["meal", "cooked_fish"]:
			return "这件物品不能直接食用。"
		if Inventory.count(player.bag, food) < 1:
			return "背包里没有熟食，先用烤架做一份烤鱼。"
		if float(player.stamina) >= 100.0 and float(player.hunger) >= 100.0:
			return "体力和饱腹都满了，留着稍后吃吧。"
		Inventory.remove(player.bag, food, 1)
		player.stamina = minf(100.0, float(player.stamina) + 45.0)
		player.hunger = minf(100.0, float(player.hunger) + (50.0 if food == "meal" else 35.0))
		return "吃了%s，恢复了饱腹和体力。" % Inventory.ITEM_NAMES[food]
	if verb == "wake":
		player.resting = false
		player.sleep_ready = false
		return "已经起身，取消结束今天的准备。"
	if verb == "dive":
		if not at_edge(player):
			return "请走到甲板边缘再下潜。"
		if not bool(data.navigation.anchored):
			return "下潜前先抛锚 · C 手工制作简易锚，G 抛锚。"
		player.area = "water"
		player.x = 120.0
		player.y = 100.0
		player.oxygen = 100.0
		player.resting = false
		player.sleep_ready = false
		player.fishing = {}
		player.hook = {}
		_inputs.erase(slot)
		return "开始潜水；浮标旁可以返航。"
	if verb == "surface":
		if player.area != "water" or not _near(player, STATIONS.buoy):
			return "请回到水面浮标旁再返航。"
		_safe_deck(player, slot)
		_inputs.erase(slot)
		return "平安返航，记得把收获存入仓库。"
	if verb in ["deposit", "take_meal", "open_chest"]:
		var chest_id := nearby_chest(slot)
		if chest_id.is_empty():
			return "请走到一个木箱旁。"
		var chest: Dictionary = data.chests[chest_id]
		if verb == "open_chest":
			return "已打开%s。" % chest.name
		if verb == "deposit":
			if _bag_count(player) == 0:
				return "背包里还没有收获。"
			var deposited := 0
			for index in player.bag.size():
				var stack: Dictionary = player.bag[index]
				if stack.is_empty():
					continue
				var remaining := Inventory.add(chest.slots, stack.item, int(stack.count))
				deposited += int(stack.count) - remaining
				player.bag[index] = {} if remaining == 0 else {"item": stack.item, "count": remaining}
			if deposited == 0:
				return "这个箱子已满，物品仍在你的背包里。"
			return "存入了 %d 件物品；剩余物品留在背包。" % deposited if _bag_count(player) > 0 else "已把随身物品存入这个箱子。"
		if Inventory.count(chest.slots, "meal") < 1:
			return "这个箱子没有料理。"
		var bag: Array = player.bag.duplicate(true)
		if Inventory.add(bag, "meal", 1) != 0:
			return "背包没有空格，无法领取料理。"
		Inventory.remove(chest.slots, "meal", 1)
		player.bag = bag
		return "领取了一份料理。"
	if verb in ["plant", "water", "harvest"]:
		return _garden_action(player, verb)
	if verb == "cook":
		return _process_action(player, "cook", args)
	if verb == "sell":
		if not _at_station(player, "orders"):
			return "请走到订单板旁。"
		if int(data.orders_filled) >= int(data.orders_limit):
			return "今天的订单已经完成，明天再来。"
		if not _exchange(player, {"meal": 1}, {}):
			return "需要背包或木箱里的 1 份料理。"
		data.money += 8
		data.orders_filled += 1
		return "交付了一份料理，获得 8 枚金币。"
	if verb == "craft_chest":
		return "按 C 打开配方，选择储物木箱后点击空甲板格放置。"
	if verb == "build":
		if _nearest_structure(player, ["orders"]).is_empty() and not data.structures.has("legacy_orders"):
			return "按 C 选择木筏地板，再点击相邻水面格扩建。"
		if not _at_station(player, "expansion"):
			return "请走到甲板扩建标记旁。"
		if int(data.expansion) >= 2:
			return "甲板已完成本原型的两次扩建。"
		var wood_cost := 4 + int(data.expansion) * 2
		var money_cost := 8 + int(data.expansion) * 4
		if int(data.money) < money_cost:
			return "扩建需要 %d 份木材和 %d 枚金币。" % [wood_cost, money_cost]
		if not _exchange(player, {"wood": wood_cost}, {}):
			return "扩建需要 %d 份木材和 %d 枚金币。" % [wood_cost, money_cost]
		data.money -= money_cost
		data.expansion += 1
		for gy in range(1, 8):
			var key := _tile_key(11 + int(data.expansion), gy)
			if key not in data.deck_tiles:
				data.deck_tiles.append(key)
		return "甲板变大了！两个人都有更多活动空间。"
	if verb == "rest" or verb == "sleep":
		if not _at_bed(player):
			return "请走到甲板的床旁或岛上营地。"
		player.activity = {}
		player.resting = true
		_inputs.erase(slot)
		if verb == "rest":
			player.sleep_ready = false
			return "正在休息恢复体力，世界时间继续流动。"
		player.sleep_ready = true
		if _all_ready():
			_advance_day()
			return "大家都已准备好，迎来了新的一天。"
		return "已准备结束今天，等待伙伴也到床旁确认。"
	return "现在还不能进行这个操作。"


func _navigation_action(slot: String, verb: String, args: Dictionary) -> String:
	var player: Dictionary = data.players[slot]
	var nav: Dictionary = data.navigation
	if player.area != "deck":
		return "请先回到甲板上操船。"
	if verb in ["moor", "unmoor"]:
		if verb == "moor":
			if bool(nav.anchored):
				return "木筏已经停稳；先收回船锚或解缆。"
			if not at_edge(player) or not Archipelago.within_docking_range(data.chart, nav):
				return "靠近潮芽岛码头，在筏边用绳子系泊。"
			if not Inventory.remove(player.bag, "rope", 1):
				return "岸边系泊需要 1 根绳子 · C 可用叶子制作。"
			nav.moored = true
			nav.anchored = true
			nav.push_x = 0.0
			nav.push_y = 0.0
			return "已系泊码头 · 绳子固定木筏，可以登岸或下潜。"
		if not bool(nav.moored):
			return "木筏没有系在码头。"
		for other in data.players.values():
			if other.online and other.area != "deck":
				return "等所有人回到木筏后再解缆。"
		if not _personal_exchange(player, {}, {"rope": 1}):
			return "背包放不下绳子，先整理；木筏仍系泊。"
		nav.moored = false
		nav.anchored = false
		return "已解缆 · 绳子收回背包，继续航行。"
	if bool(nav.moored):
		return "这是岸边系泊绳，走到筏边右键选择解缆；G 只操作船锚。"
	if verb == "drop_anchor":
		if bool(nav.anchored):
			return "木筏已经抛锚停稳了。"
		if not Inventory.remove(player.bag, "anchor", 1):
			return "船锚尚未制作 · C 制作简易锚，再按 G 抛锚停船；靠岸也可用绳子系泊。"
		nav.anchored = true
		nav.push_x = 0.0
		nav.push_y = 0.0
		return "已抛锚 · 木筏停止漂行，可以下潜。"
	if verb == "raise_anchor":
		if not bool(nav.anchored):
			return "还没有抛锚。"
		for other in data.players.values():
			if other.online and other.area != "deck":
				return "伙伴还在水下或岛上，等所有人回到木筏后才能起锚。"
		var bag: Array = player.bag.duplicate(true)
		if Inventory.add(bag, "anchor", 1) != 0:
			return "背包已满，先腾出一格收锚；木筏仍停泊。"
		player.bag = bag
		nav.anchored = false
		return "已起锚 · 简易锚回到背包，木筏继续顺流漂行。"
	if Inventory.count(player.bag, "paddle") < 1:
		return "需要随身携带船桨 · C 可以手工制作。"
	if bool(nav.anchored):
		return "先按 G 起锚，再划桨。"
	if float(nav[slot + "_cooldown"]) > 0.0:
		return "船桨正在划水，稍等片刻。"
	if not _number(args.get("x"), -1.0, 1.0) or not _number(args.get("y"), -1.0, 1.0):
		return "请选择有效的划桨方向。"
	var direction := Vector2(float(args.x), float(args.y))
	if direction.length_squared() < 0.01:
		return "点击远一点的海面，选择划桨方向。"
	if float(player.stamina) < 2.0:
		return "体力不足，吃点熟食或回床边休息。"
	if not player.hook.is_empty() or not player.fishing.is_empty():
		return "先收回钩子或钓竿，再划桨。"
	player.stamina -= 2.0
	player.resting = false
	player.sleep_ready = false
	Navigation.stroke(nav, slot, direction)
	return "划桨 · 朝所指方向前进。"


func _island_action(slot: String, verb: String, args: Dictionary) -> String:
	var player: Dictionary = data.players[slot]
	if verb == "set_destination":
		if Inventory.count(player.bag, "compass") < 1:
			return "随身带上罗盘，才能查看完整海图并设置航标。"
		if args.get("id") != "island_home":
			return "这片海域尚未解锁。"
		data.chart.destination = "island_home"
		return "已标记潮芽岛；看海图方向划桨，靠近后抛锚登岸。"
	if verb == "land":
		if args.get("id", "island_home") != "island_home" or player.area != "deck" or not at_edge(player) or not Archipelago.within_docking_range(data.chart, data.navigation):
			return "先划到潮芽岛停泊点附近，再走到筏边登岸。"
		if not bool(data.navigation.anchored):
			return "先在筏边用绳子系泊，或按 G 抛锚停船，再登岸。"
		player.area = "island"
		player.x = IslandState.DOCK.x
		player.y = IslandState.DOCK.y
		player.hook = {}
		player.fishing = {}
		player.resting = false
		player.sleep_ready = false
		_inputs.erase(slot)
		data.chart.visited = true
		return "到了潮芽岛；沿小路采集，码头可返回木筏。"
	if player.area != "island":
		return "请先登上潮芽岛。"
	if verb == "board_raft":
		if not _near(player, IslandState.DOCK):
			return "回到西侧码头，才能登上自己的木筏。"
		_safe_deck(player, slot)
		_inputs.erase(slot)
		return "已回到木筏，随身物资都带回来了。"
	return "这个岛上操作尚不可用。"

func _fishing_location(player: Dictionary) -> bool:
	return (player.area == "island" and (_near(player, IslandState.FISHING, 54.0) or IslandMap.water_near(Vector2(float(player.x), float(player.y))))) or at_edge(player)

func _garden_action(player: Dictionary, verb: String) -> String:
	var on_island: bool = false
	if (on_island and not _near(player, IslandState.FARM)) or (not on_island and not _at_station(player, "garden")):
		return "请走到种植盆或岛上农地旁。"
	var crop: Dictionary = data.crop
	if verb == "plant":
		if int(crop.stage) != 0:
			return "种植箱里已经有作物了。"
		if not (_personal_exchange(player, {"seed": 1}, {}) if on_island else _exchange(player, {"seed": 1}, {})):
			return "背包和木箱里都没有种子。"
		crop.stage = 1
		crop.progress = 0.0
		crop.watered = false
		return "种好了，浇水之后才会生长。"
	if verb == "water":
		if int(crop.stage) != 1:
			return "当前没有需要浇水的幼苗。"
		if crop.watered:
			return "已经浇过水，可以放心去做别的事。"
		crop.watered = true
		return "浇好了水；下潜时作物也会继续生长。"
	if int(crop.stage) != 2:
		return "作物还没有成熟。"
	if not (_personal_exchange(player, {}, {"veg": 3, "seed": 1}) if on_island else _exchange(player, {}, {"veg": 3, "seed": 1})):
		return "背包放不下蔬菜和种子，作物会留在这里等你。"
	crop.stage = 0
	crop.progress = 0.0
	crop.watered = false
	return "收获了 3 份蔬菜和 1 颗种子，已放进背包。"


func _craft(slot: String, args: Dictionary) -> String:
	var id: Variant = args.get("recipe")
	if not id is String or not Recipes.ALL.has(id):
		return "请选择一个有效配方。"
	var player: Dictionary = data.players[slot]
	var recipe: Dictionary = Recipes.ALL[id]
	if player.area == "island" and recipe.structure.is_empty():
		if not _personal_exchange(player, recipe.costs, {recipe.result: int(recipe.amount)}):
			return "随身材料不足，或背包放不下成品；岛上不会使用船上的箱子。"
		return "%s +%d → 我的背包" % [recipe.name, int(recipe.amount)]
	if player.area != "deck":
		return "岛上可手工制作随身物品；设施请回到甲板建造。"
	if recipe.structure.is_empty():
		if not _exchange(player, recipe.costs, {recipe.result: int(recipe.amount)}):
			return "材料不足，或背包空间不足；没有消耗材料。"
		return "%s +%d → 我的背包" % [recipe.name, int(recipe.amount)]
	if recipe.structure == "chest" and data.chests.size() >= MAX_SAVED_CHESTS:
		return "木箱数量已达到存档上限，没有消耗材料。"
	if not _number(args.get("x"), 0.0, 900.0) or not _number(args.get("y"), 0.0, 560.0) or not can_place(slot, id, float(args.x), float(args.y)):
		return "这里不能放置：请选附近空甲板格；地板须接在甲板旁，避开人物和设施。"
	if not _exchange(player, recipe.costs, {}):
		return "材料不足，没有消耗材料。"
	var point := Vector2(float(args.x), float(args.y))
	if recipe.structure == "foundation":
		data.deck_tiles.append(_point_tile(point))
	elif recipe.structure == "chest":
		var number := 0
		while data.chests.has("chest_%d" % number):
			number += 1
		var chest_id := "chest_%d" % number
		data.chests[chest_id] = _new_chest(chest_id, "木箱 %d" % (number + 1), point, Inventory.empty_slots(Inventory.CHEST_SIZE))
	else:
		var number := 0
		while data.structures.has("structure_%d" % number):
			number += 1
		var structure_id := "structure_%d" % number
		data.structures[structure_id] = _new_structure(structure_id, recipe.structure, point)
	return "已建好%s。" % recipe.name


func _process_action(player: Dictionary, verb: String, args: Dictionary) -> String:
	var kinds := ["purifier", "grill", "furnace"] if verb == "collect_output" else (["furnace"] if verb == "smelt" else (["purifier"] if verb == "purify" else ["grill"]))
	var id: Variant = args.get("id", _nearest_structure(player, kinds))
	if not id is String or not data.structures.has(id):
		return "请靠近对应的加工设施。"
	var structure: Dictionary = data.structures[id]
	if player.area != "deck" or structure.kind not in kinds or not _near(player, Vector2(float(structure.x), float(structure.y))):
		return "请靠近这个设施再操作。"
	if verb == "collect_output":
		if float(structure.remaining) > 0.0:
			return "还在加工，稍等一会儿。"
		if structure.output.is_empty():
			return "还没有可以领取的成品。"
		var bag: Array = player.bag.duplicate(true)
		if Inventory.add(bag, structure.output, 1) != 0:
			return "背包已满，成品会留在设施里等你。"
		var item: String = structure.output
		player.bag = bag
		structure.output = ""
		return "%s +1 → 我的背包" % Inventory.ITEM_NAMES[item]
	if float(structure.remaining) > 0.0 or not structure.output.is_empty():
		return "设施还在加工，或上一次成品尚未领取。"
	var costs: Dictionary = {"ore": 1, "wood": 1} if verb == "smelt" else ({"saltwater": 1, "wood": 1} if verb == "purify" else ({"fish": 1, "veg": 1} if verb == "cook" else {"fish": 1, "wood": 1}))
	if not _exchange(player, costs, {}):
		return "材料不足，需要 1 份金属矿石和 1 块木板。" if verb == "smelt" else "材料不足；净水需要海水和木板，烤鱼需要生鱼和木板，料理需要鱼和蔬菜。"
	structure.output = "ingot" if verb == "smelt" else ("freshwater" if verb == "purify" else ("meal" if verb == "cook" else "cooked_fish"))
	structure.remaining = 15.0 if verb == "smelt" else (12.0 if verb == "purify" else 10.0)
	return "开始加工，%d 秒后可以领取。" % int(structure.remaining)


func _personal_exchange(player: Dictionary, costs: Dictionary, rewards: Dictionary) -> bool:
	var bag: Array = player.bag.duplicate(true)
	for item in costs:
		if not Inventory.remove(bag, item, int(costs[item])):
			return false
	for item in rewards:
		if Inventory.add(bag, item, int(rewards[item])) != 0:
			return false
	player.bag = bag
	return true


func _nearest_structure(player: Dictionary, kinds: Array) -> String:
	if player.area != "deck":
		return ""
	var found := ""
	var distance := INTERACTION_DISTANCE
	for id in data.structures:
		var structure: Dictionary = data.structures[id]
		if structure.kind not in kinds:
			continue
		var candidate := Vector2(float(player.x), float(player.y)).distance_to(Vector2(float(structure.x), float(structure.y)))
		if candidate <= distance:
			distance = candidate
			found = id
	return found


func interaction_options(slot: String) -> Array:
	var result: Array = []
	if not _is_online(slot):
		return result
	var player: Dictionary = data.players[slot]
	if player.area == "island":
		result.append_array(IslandTown.options(data, player))
		if _near(player, IslandState.DOCK):
			_option(result, "board_raft", "返回自己的木筏")
		var at := Vector2(float(player.x), float(player.y))
		var nodes: Dictionary = IslandMap.nodes_near(at)
		for id in nodes:
			var resource: Dictionary = nodes[id]
			if IslandState.active(data.island, id, int(data.day)) and _near(player, Vector2(float(resource.x), float(resource.y))):
				_option(result, "gather_island", "%s · %s · %.1f秒" % [resource.label, Inventory.ITEM_NAMES[resource.tool], resource.duration], {"id": id})
		for key in data.island.plots:
			var center: Vector2 = Farming.plot_center(key)
			if not _near(player, center):
				continue
			var plot: Dictionary = data.island.plots[key]
			var args := {"x": center.x, "y": center.y}
			if plot.dead:
				_option(result, "clear_crop", "清除枯萎植株 · 镰刀", args)
			elif Farming.mature(plot):
				_option(result, "harvest", "收获%s" % Farming.CROPS[plot.crop].name, args)
		if IslandMap.water_near(at):
			_option(result, "refill_can", "装满水壶 · 淡水池", {"x": at.x, "y": at.y})
		if _near(player, IslandState.CAMP):
			_option(result, "wake" if player.resting else "rest", "起身" if player.resting else "营地休息", {"id": "island_camp"})
			_option(result, "sleep", "准备结束今天", {"id": "island_camp"})
		if _fishing_location(player):
			if player.fishing.is_empty() and Inventory.count(player.bag, "rod") > 0:
				_option(result, "cast", "在岸边钓鱼")
			elif not player.fishing.is_empty():
				_option(result, "reel", "收竿领取渔获" if float(player.fishing.remaining) <= 0 else "等咬钩后收竿")
	elif player.area == "water":
		if _near(player, STATIONS.buoy):
			_option(result, "surface", "返回甲板")
		var wreck_id := _nearest_entity(player, "wreck")
		if not wreck_id.is_empty():
			_option(result, "search_wreck", "搜寻沉箱 · 7 秒", {"id": wreck_id})
		for kind in ["stone", "ore"]:
			var deposit_id := _nearest_entity(player, kind)
			if not deposit_id.is_empty():
				_option(result, "mine", "开采%s · %s" % [Inventory.ITEM_NAMES[kind], "石镐加速" if Inventory.count(player.bag, "pickaxe") > 0 else "徒手较慢"], {"id": deposit_id})
		if not _nearest_entity(player, "wood").is_empty():
			_option(result, "collect", "拆取木材 · %s" % ("2.5 秒" if Inventory.count(player.bag, "axe") > 0 else "8 秒"), {"id": _nearest_entity(player, "wood")})
	else:
		if not player.fishing.is_empty() and float(player.fishing.remaining) <= 0.0 and at_edge(player):
			_option(result, "reel", "收竿领取渔获")
		var chest_id := nearby_chest(slot)
		if not chest_id.is_empty():
			_option(result, "open_chest", "打开附近木箱", {"id": chest_id})
			if _bag_count(player) > 0:
				_option(result, "deposit", "尽量存入附近木箱")
			_option(result, "take_meal", "领取 1 份料理")
		if _at_station(player, "garden"):
			var garden_id := _nearest_structure(player, ["garden"])
			if int(data.crop.stage) == 0:
				_option(result, "plant", "播种 · 1 种子", {"id": garden_id})
			elif int(data.crop.stage) == 1 and not data.crop.watered:
				_option(result, "water", "给幼苗浇水", {"id": garden_id})
			elif int(data.crop.stage) == 2:
				_option(result, "harvest", "收获蔬菜", {"id": garden_id})
		for structure_id in data.structures:
			var structure: Dictionary = data.structures[structure_id]
			if structure.kind not in ["purifier", "grill", "furnace"] or not _near(player, Vector2(float(structure.x), float(structure.y))):
				continue
			if float(structure.remaining) == 0.0:
				if not structure.output.is_empty():
					_option(result, "collect_output", "领取%s" % Inventory.ITEM_NAMES[structure.output], {"id": structure_id})
				elif structure.kind == "purifier":
					_option(result, "purify", "净水 · 海水 + 木板", {"id": structure_id})
				elif structure.kind == "furnace":
					_option(result, "smelt", "炼制金属锭 · 矿石 + 木板", {"id": structure_id})
				else:
					_option(result, "grill_fish", "烤鱼 · 生鱼 + 木板", {"id": structure_id})
					_option(result, "cook", "料理 · 生鱼 + 蔬菜", {"id": structure_id})
		if _at_station(player, "orders"):
			_option(result, "sell", "交付料理 · 获得 8 金币")
		if data.structures.has("legacy_orders") and _at_station(player, "expansion") and int(data.expansion) < 2:
			_option(result, "build", "扩建 · %d 木材 + %d 金币" % [4 + int(data.expansion) * 2, 8 + int(data.expansion) * 4])
		if _at_bed(player):
			var bed_id := _nearest_structure(player, ["bed", "bedroll"])
			_option(result, "wake" if player.resting else "rest", "起身 / 取消准备" if player.resting else "休息恢复体力", {"id": bed_id})
			if not player.sleep_ready:
				_option(result, "sleep", "准备结束今天", {"id": bed_id})
		if at_edge(player):
			if Archipelago.within_docking_range(data.chart, data.navigation):
				_option(result, "land", "登上潮芽岛" if bool(data.navigation.anchored) else "登岛前先停船")
			if player.fishing.is_empty() and Inventory.count(player.bag, "rod") > 0:
				_option(result, "cast", "抛竿钓鱼 · 2 体力")
			if Inventory.count(player.bag, "cup") > 0:
				_option(result, "fill_cup", "舀一杯海水")
			_option(result, "dive", "从筏边下潜" if bool(data.navigation.anchored) else "下潜前先抛锚 · G")
			if bool(data.navigation.moored):
				_option(result, "unmoor", "解缆 · 收回系泊绳")
			elif not bool(data.navigation.anchored) and Archipelago.within_docking_range(data.chart, data.navigation):
				_option(result, "moor", "系泊码头 · 1 根绳子")
		var movable_ids: Array = [nearby_chest(slot), _nearest_structure(player, STRUCTURE_KINDS)]
		for id in movable_ids:
			if id.is_empty():
				continue
			var object := _relocatable(id)
			if object.is_empty():
				continue
			var label := str(object.get("name", "设施"))
			if object.has("kind"):
				label = str(Recipes.ALL.get(object.kind, {}).get("name", "睡袋" if object.kind == "bedroll" else "设施"))
			_option(result, "relocate", "搬动%s" % label, {"id": id, "from_x": float(object.x), "from_y": float(object.y)})
	if Inventory.count(player.bag, "freshwater") > 0:
		_option(result, "drink", "喝淡水 · 恢复口渴")
	if Inventory.count(player.bag, "meal") > 0 or Inventory.count(player.bag, "cooked_fish") > 0:
		_option(result, "eat", "吃熟食 · 恢复饱腹和体力")
	return result


func _option(options: Array, verb: String, label: String, args: Dictionary = {}) -> void:
	var option := {"action": verb, "label": label}
	if not args.is_empty():
		option.args = args
	options.append(option)


func _at_station(player: Dictionary, station: String) -> bool:
	if station in ["garden", "kitchen", "orders"]:
		return not _nearest_structure(player, ["grill" if station == "kitchen" else station]).is_empty()
	if station == "fishing" or station == "hatch":
		return at_edge(player)
	return player.area == "deck" and _near(player, STATIONS[station])


func _at_bed(player: Dictionary) -> bool:
	return (player.area == "island" and _near(player, IslandState.CAMP)) or not _nearest_structure(player, ["bed", "bedroll"]).is_empty()


func _near(player: Dictionary, point: Vector2, radius: float = INTERACTION_DISTANCE) -> bool:
	return Vector2(float(player.x), float(player.y)).distance_to(point) <= radius


func _nearest_entity(player: Dictionary, kind: String) -> String:
	var found := ""
	var distance := INTERACTION_DISTANCE
	var position := Vector2(float(player.x), float(player.y))
	for entity_id in data.entities:
		var entity: Dictionary = data.entities[entity_id]
		if entity.kind != kind or not entity.active:
			continue
		var candidate := position.distance_to(Vector2(float(entity.x), float(entity.y)))
		if candidate <= distance:
			distance = candidate
			found = entity_id
	return found


func _bag_count(player: Dictionary) -> int:
	return Inventory.total_count(player.bag)


func nearby_chest(slot: String) -> String:
	if not _is_online(slot) or data.players[slot].area != "deck":
		return ""
	var player: Dictionary = data.players[slot]
	var nearest := ""
	var distance := INTERACTION_DISTANCE
	for id in data.chests:
		var chest: Dictionary = data.chests[id]
		var candidate := Vector2(float(player.x), float(player.y)).distance_to(Vector2(float(chest.x), float(chest.y)))
		if candidate <= distance:
			distance = candidate
			nearest = id
	return nearest


func chest_totals() -> Dictionary:
	var result := Inventory.totals([])
	for chest in data.chests.values():
		var contents := Inventory.totals(chest.slots)
		for item in Inventory.ITEMS:
			result[item] += int(contents[item])
	return result


func inventory_totals() -> Dictionary:
	return chest_totals()


func _container_access(slot: String, container: String) -> bool:
	if container == "bag":
		return true
	if not data.chests.has(container):
		return false
	var chest: Dictionary = data.chests[container]
	return data.players[slot].area == "deck" and _near(data.players[slot], Vector2(float(chest.x), float(chest.y)))


func _container_slots(slot: String, container: String) -> Array:
	return data.players[slot].bag if container == "bag" else data.chests[container].slots


func _inventory_move(slot: String, args: Dictionary) -> String:
	var source: Variant = args.get("from_container")
	var target: Variant = args.get("to_container")
	if not source is String or not target is String or not _container_access(slot, source) or not _container_access(slot, target):
		return "只能操作自己的背包和身边的木箱。"
	var from_slots := _container_slots(slot, source)
	var to_slots := _container_slots(slot, target)
	if not _integer(args.get("from_index"), 0, from_slots.size() - 1) or not _integer(args.get("to_index"), 0, to_slots.size() - 1) or not _integer(args.get("amount", 0), 0, Inventory.STACK_LIMIT):
		return "物品格或数量无效。"
	var from_index := int(args.from_index)
	var stack: Dictionary = from_slots[from_index]
	if not args.get("expected_item") is String or stack.is_empty() or stack.item != args.expected_item:
		return "这个格子的物品已变化，请重新选择。"
	if not Inventory.move(from_slots, from_index, to_slots, int(args.to_index), int(args.get("amount", 0))):
		return "无法移动：目标格空间不足，或交换时需要移动整堆。"
	return "物品已移动。"


func _discard(player: Dictionary, args: Dictionary) -> String:
	if not _keys(args, ["index", "amount", "expected_item"]) or not _integer(args.get("index"), 0, player.bag.size() - 1) or not _integer(args.get("amount"), 1, Inventory.STACK_LIMIT):
		return "请选择有效背包格，并明确要丢弃的正整数数量。"
	var index := int(args.index)
	var stack: Dictionary = player.bag[index]
	if not args.get("expected_item") is String or stack.is_empty() or stack.item != args.expected_item:
		return "这个格子的物品已变化，请重新选择后再丢弃。"
	var amount := int(args.amount)
	if amount > int(stack.count):
		return "格内物品数量不足，没有丢弃任何物品。"
	var item: String = stack.item
	player.bag[index] = {} if amount == int(stack.count) else {"item": item, "count": int(stack.count) - amount}
	return "已丢弃%s ×%d。" % [Inventory.ITEM_NAMES[item], amount]


func _exchange(player: Dictionary, costs: Dictionary, rewards: Dictionary) -> bool:
	# Simulate every removal and reward first, so a full pack never consumes ingredients.
	var bag: Array = player.bag.duplicate(true)
	var containers: Dictionary = {}
	for id in data.chests:
		containers[id] = data.chests[id].slots.duplicate(true)
	for item in costs:
		var remaining := int(costs[item])
		var from_bag := mini(remaining, Inventory.count(bag, item))
		Inventory.remove(bag, item, from_bag)
		remaining -= from_bag
		for chest_slots in containers.values():
			var from_chest := mini(remaining, Inventory.count(chest_slots, item))
			Inventory.remove(chest_slots, item, from_chest)
			remaining -= from_chest
			if remaining == 0:
				break
		if remaining > 0:
			return false
	for item in rewards:
		if Inventory.add(bag, item, int(rewards[item])) != 0:
			return false
	player.bag = bag
	for id in containers:
		data.chests[id].slots = containers[id]
	return true


func _fishing_action(player: Dictionary, verb: String) -> String:
	if not _fishing_location(player):
		player.fishing = {}
		return "请到木筏边缘或岛上钓位钓鱼。"
	if verb == "cast":
		if Inventory.count(player.bag, "rod") == 0:
			return "需要先制作钓竿并带在自己的背包里。"
		if not player.fishing.is_empty():
			return "鱼线还在水里，等咬钩后收竿。"
		if float(player.stamina) < 2.0:
			return "体力不足，先去休息或吃一份料理。"
		player.stamina -= 2.0
		var roll := _rng.randf()
		var catch_item := "treasure" if roll < 0.1 else ("fish" if roll < 0.55 else "wood")
		player.fishing = {"remaining": FISHING_SECONDS, "result": catch_item}
		player.resting = false
		player.sleep_ready = false
		return "抛竿了，留在钓位等 5 秒。"
	if player.fishing.is_empty():
		return "还没有抛竿。"
	if float(player.fishing.remaining) > 0.0:
		return "还没有咬钩，再等一会儿。"
	var bag: Array = player.bag.duplicate(true)
	var item: String = player.fishing.result
	if Inventory.add(bag, item, 1) != 0:
		return "背包放不下，渔获仍留在鱼线上；整理后再收竿。"
	player.bag = bag
	player.fishing = {}
	if item == "fish":
		player.caught += 1
	return "钓到了%s！" % Inventory.ITEM_NAMES[item]


func _open_treasure(player: Dictionary, args: Dictionary) -> String:
	if not _integer(args.get("index"), 0, Inventory.BAG_SIZE - 1):
		return "请在背包中选中一个物资宝箱。"
	var index := int(args.index)
	var bag: Array = player.bag.duplicate(true)
	if bag[index].is_empty() or bag[index].item != "treasure":
		return "这个格子里没有物资宝箱。"
	bag[index].count -= 1
	if int(bag[index].count) == 0:
		bag[index] = {}
	for reward in [{"item": "wood", "count": 3}, {"item": "seed", "count": 2}, {"item": "fish", "count": 1}]:
		if Inventory.add(bag, reward.item, int(reward.count)) != 0:
			return "背包放不下全部物资，宝箱仍然保留，请先整理。"
	player.bag = bag
	return "打开宝箱：获得 3 木材、2 种子和 1 条鱼。"


func _is_online(slot: String) -> bool:
	return slot in SLOTS and bool(data.players[slot].online)


func _any_online() -> bool:
	return bool(data.players.host.online) or bool(data.players.guest.online)


func _all_ready() -> bool:
	if not _any_online():
		return false
	for slot in SLOTS:
		if data.players[slot].online and not data.players[slot].sleep_ready:
			return false
	return true


func _advance_day() -> void:
	Farming.advance_day(data.island, int(data.day), int(data.day) + 1)
	data.day += 1
	data.minute = 360.0
	data.orders_filled = 0
	data.entities = _new_entities()
	for crop in [data.crop]:
		if int(crop.stage) == 1 and crop.watered:
			crop.stage = 2
			crop.progress = 1.0
	for slot in SLOTS:
		var player: Dictionary = data.players[slot]
		player.stamina = 100.0
		if player.area == "island":
			player.resting = false
			player.sleep_ready = false
			player.activity = {}
			player.fishing = {}
		else:
			_safe_deck(player, slot)
	_inputs.clear()


func snapshot() -> Dictionary:
	return data.duplicate(true)


func restore(saved: Dictionary) -> bool:
	migration_notice = ""
	var pending_migration_notice := ""
	# Build a fresh validated value; a rejected file must leave the live world untouched.
	if not _integer(saved.get("version"), 1, 10) or not _integer(saved.get("day"), 1, 1000000):
		return false
	var legacy := int(saved.version) == 1
	var survival := int(saved.version) >= 3
	var exploration := int(saved.version) >= 4
	var ocean := int(saved.version) >= 5
	var sailing := int(saved.version) >= 6
	var islands := int(saved.version) >= 7
	var skilled := int(saved.version) >= 8
	var navigation: Dictionary = Navigation.restore(saved.get("navigation")) if sailing else Navigation.create(true)
	if navigation.is_empty():
		return false
	var chart: Dictionary = Archipelago.restore(saved.get("chart")) if islands else Archipelago.create(navigation)
	var island: Dictionary = IslandState.restore(saved.get("island"), int(saved.version), int(saved.day)) if islands else IslandState.create()
	if skilled and (not saved.get("navigation") is Dictionary or saved.navigation.size() != 9 or not saved.navigation.has("moored")):
		return false
	if chart.is_empty() or island.is_empty():
		return false
	if int(saved.version) == 9 and not saved.island.plots.keys().all(func(key: String) -> bool: return island.plots.has(key)):
		pending_migration_notice = "旧农田与新建筑或水域重叠，已完整移到附近荒地；旧版存档仍保留。"
	if navigation.moored and not Archipelago.within_docking_range(chart, navigation):
		return false
	var world_keys := ["version", "day", "minute", "elapsed", "money", "chests", "expansion", "crop", "orders_filled", "orders_limit", "players", "entities"]
	if survival:
		world_keys.append_array(["deck_tiles", "structures", "drift"])
	if sailing:
		world_keys.append("navigation")
	if islands:
		world_keys.append_array(["chart", "island"])
	if not legacy and not _keys(saved, world_keys):
		return false
	if not _number(saved.get("minute"), 360.0, 1430.0) or not _number(saved.get("elapsed"), 0.0, 1.0e12):
		return false
	if not _integer(saved.get("money"), 0, 1000000000) or not _integer(saved.get("expansion"), 0, 2):
		return false
	var layout := _validate_layout(saved) if survival else _migrate_layout(int(saved.expansion))
	if layout.is_empty():
		return false
	if legacy and not _counts_valid(saved.get("storage"), STORAGE_ITEMS, 1000000000):
		return false
	var crop_value: Variant = saved.get("crop")
	if not crop_value is Dictionary:
		return false
	var crop: Dictionary = crop_value
	if not _keys(crop, ["stage", "progress", "watered"]):
		return false
	if not _integer(crop.get("stage"), 0, 2) or not _number(crop.get("progress"), 0.0, 1.0) or not crop.get("watered") is bool:
		return false
	if (int(crop.stage) == 0 and (float(crop.progress) != 0.0 or crop.watered)) or (int(crop.stage) == 2 and float(crop.progress) != 1.0):
		return false
	if not crop.watered and float(crop.progress) > 0.0:
		return false
	if not _integer(saved.get("orders_filled", 0), 0, 3) or not _integer(saved.get("orders_limit", 3), 3, 3):
		return false
	if not saved.get("players") is Dictionary or saved.players.size() != 2:
		return false
	var players: Dictionary = {}
	for slot in SLOTS:
		if not saved.players.get(slot) is Dictionary:
			return false
		var player: Dictionary = saved.players[slot]
		var player_keys := ["name", "online", "area", "x", "y", "oxygen", "stamina", "resting", "sleep_ready", "bag", "caught", "fishing"]
		if survival:
			player_keys.append_array(["hunger", "thirst", "hook", "notice", "notice_id"])
		if int(saved.version) >= 9:
			player_keys.append("can_water")
			if not _integer(player.get("can_water"), 0, 20):
				return false
		if skilled:
			player_keys.append("activity")
			if not UnderwaterActions.valid_activity(player.get("activity")) and not (int(saved.version) >= 9 and IslandActivity.valid(player.get("activity"), int(saved.version) == 9)) and not (int(saved.version) >= 10 and IslandTown.valid(player.get("activity"))):
				return false
		if not legacy and not _keys(player, player_keys):
			return false
		if not player.get("name") is String or player.name.is_empty() or player.name.length() > 32:
			return false
		if player.get("area") not in (["deck", "water", "island"] if islands else ["deck", "water"]):
			return false
		for flag in ["online", "resting", "sleep_ready"]:
			if not player.get(flag) is bool:
				return false
		if not _number(player.get("oxygen"), 0.0, 100.0) or not _number(player.get("stamina"), 0.0, 100.0) or not _integer(player.get("caught"), 0, 1000000000):
			return false
		var is_water: bool = player.area == "water"
		if not _number(player.get("x"), 40.0 if is_water else (0.0 if survival else 152.0), 860.0 if is_water else (IslandMap.SIZE.x if player.area == "island" and int(saved.version) >= 9 else 900.0 if survival else 728.0 + int(saved.expansion) * 60.0)):
			return false
		if not _number(player.get("y"), 35.0 if is_water else (0.0 if survival else 102.0), 520.0 if is_water else (IslandMap.SIZE.y if player.area == "island" and int(saved.version) >= 9 else 560.0 if survival else 468.0)):
			return false
		var restored_point := Vector2(float(player.x), float(player.y))
		var valid_island_position: bool = (IslandMap.walkable(restored_point) if int(saved.version) >= 10 else IslandMap.legacy_walkable(restored_point)) if int(saved.version) >= 9 else Archipelago.land_walkable(restored_point)
		if player.area == "island" and (not chart.visited or not valid_island_position):
			return false
		if player.area == "island" and int(saved.version) < 10 and not IslandMap.walkable(restored_point):
			restored_point = IslandState.DOCK # A new pond may cover a valid historical landing position.
		if player.area == "island" and player.online and (not bool(navigation.anchored) or not Archipelago.within_docking_range(chart, navigation)):
			return false
		if player.area == "deck" and _point_tile(Vector2(float(player.x), float(player.y))) not in layout.deck_tiles:
			return false
		var bag := Inventory.empty_slots(Inventory.BAG_SIZE)
		var fishing: Dictionary = {}
		if legacy:
			if not _counts_valid(player.get("bag"), BAG_ITEMS, 8):
				return false
			var old_total := 0
			for item in BAG_ITEMS:
				old_total += int(player.bag[item])
				Inventory.add(bag, item, int(player.bag[item]))
			if old_total > 8:
				return false
		else:
			if not Inventory.validate_slots(player.get("bag"), Inventory.BAG_SIZE):
				return false
			bag = Inventory.normalize(player.bag)
			if not player.get("fishing") is Dictionary:
				return false
			if not player.fishing.is_empty():
				if not _keys(player.fishing, ["remaining", "result"]) or not _number(player.fishing.get("remaining"), 0.0, FISHING_SECONDS) or player.fishing.get("result") not in ["fish", "wood", "treasure"]:
					return false
				if (survival and not (_edge_in_tiles(player, layout.deck_tiles) or (islands and player.area == "island" and (_near(player, IslandState.FISHING, 54.0) or (int(saved.version) >= 10 and IslandMap.water_near(restored_point)))))) or (not survival and (player.area != "deck" or not _near(player, STATIONS.fishing))):
					return false
				# Old free fishing is cancelled on migration; no items are lost or awarded.
				if survival:
					fishing = {"remaining": float(player.fishing.remaining), "result": player.fishing.result}
		var hook: Dictionary = {}
		if survival:
			if not _number(player.get("hunger"), 0.0, 100.0) or not _number(player.get("thirst"), 0.0, 100.0) or not player.get("notice") is String or player.notice.length() > 200 or not _integer(player.get("notice_id"), 0, 1000000000) or not player.get("hook") is Dictionary:
				return false
			if skilled and not SalvageHook.valid(player.hook):
				return false
			if not skilled and not player.hook.is_empty():
				var hook_keys := ["id", "remaining", "x", "y"]
				if player.hook.has("duration"):
					hook_keys.append("duration")
				if islands and player.hook.has("manual"):
					if not player.hook.manual is bool:
						return false
					hook_keys.append("manual")
				if not _keys(player.hook, hook_keys) or not player.hook.get("id") is String or not layout.drift.has(player.hook.id) or player.area != "deck":
					return false
				var duration: Variant = player.hook.get("duration", HOOK_SECONDS)
				if not _number(duration, 0.65, HOOK_SECONDS) or not (is_equal_approx(float(duration), 0.65) or is_equal_approx(float(duration), HOOK_SECONDS)):
					return false
				if not _number(player.hook.get("remaining"), 0.0, float(duration)) or not _number(player.hook.get("x"), -96.0 if ocean else -80.0, 980.0 if ocean else 950.0) or not _number(player.hook.get("y"), -80.0 if sailing else (16.0 if ocean else 100.0), 640.0 if sailing else (544.0 if ocean else 450.0)):
					return false
				hook = {"id": player.hook.id, "remaining": float(player.hook.remaining), "duration": float(duration), "x": float(player.hook.x), "y": float(player.hook.y)}
				if islands and player.hook.has("manual"):
					hook["manual"] = player.hook.manual
		players[slot] = {
			"name": player.name, "online": false, "area": player.area, "x": float(player.x), "y": float(player.y),
			"oxygen": float(player.oxygen), "stamina": float(player.stamina), "resting": false, "sleep_ready": false,
			"bag": bag, "caught": int(player.caught), "fishing": fishing,
			"hunger": float(player.hunger) if survival else 80.0, "thirst": float(player.thirst) if survival else 75.0,
			"hook": {}, "activity": {}, "can_water": int(player.can_water) if int(saved.version) >= 9 else 0, "notice": player.notice if survival else "", "notice_id": int(player.notice_id) if survival else 0,
		}
		if player.area == "island" and int(saved.version) < 10:
			players[slot].x = restored_point.x
			players[slot].y = restored_point.y
	var chests: Dictionary = {}
	if legacy:
		chests = _migrate_storage(saved.storage)
		if chests.is_empty():
			return false
	else:
		if not saved.get("chests") is Dictionary or (not survival and not saved.chests.has("chest_0")) or saved.chests.size() > MAX_SAVED_CHESTS:
			return false
		for id in saved.chests:
			if not id is String or not _chest_id_valid(id) or not saved.chests[id] is Dictionary:
				return false
			var chest: Dictionary = saved.chests[id]
			if not _keys(chest, ["id", "name", "x", "y", "slots"]) or chest.get("id") != id or not chest.get("name") is String or chest.name.is_empty() or chest.name.length() > 32:
				return false
			if not _number(chest.get("x"), 0.0 if survival else 152.0, 900.0 if survival else 728.0 + int(saved.expansion) * 60.0) or not _number(chest.get("y"), 0.0 if survival else 102.0, 560.0 if survival else 468.0) or not Inventory.validate_slots(chest.get("slots"), Inventory.CHEST_SIZE):
				return false
			if _point_tile(Vector2(float(chest.x), float(chest.y))) not in layout.deck_tiles:
				return false
			chests[id] = _new_chest(id, chest.name, Vector2(float(chest.x), float(chest.y)), Inventory.normalize(chest.slots))
	if not saved.get("entities") is Dictionary:
		return false
	var expected := _new_entities(exploration, ocean)
	if saved.entities.size() != expected.size():
		return false
	var entities: Dictionary = {}
	for entity_id in expected:
		if not saved.entities.get(entity_id) is Dictionary:
			return false
		var entity: Dictionary = saved.entities[entity_id]
		if entity.get("kind") != expected[entity_id].kind or not entity.get("active") is bool:
			return false
		if not _keys(entity, ["kind", "x", "y", "active", "base_x", "base_y", "phase"] if entity.kind == "fish" else ["kind", "x", "y", "active"]):
			return false
		if not _number(entity.get("x"), 40.0, 860.0) or not _number(entity.get("y"), 35.0, 520.0):
			return false
		entities[entity_id] = {"kind": entity.kind, "x": float(entity.x), "y": float(entity.y), "active": entity.active}
		if entity.kind == "fish":
			if not _number(entity.get("base_x"), 62.0, 838.0) or not _number(entity.get("base_y"), 43.0, 512.0) or not _number(entity.get("phase"), 0.0, TAU):
				return false
			entities[entity_id].base_x = float(entity.base_x)
			entities[entity_id].base_y = float(entity.base_y)
			entities[entity_id].phase = float(entity.phase)
	# Add only resources that did not exist in this version, preserving every harvested node.
	if not ocean:
		var current_entities := _new_entities()
		for entity_id in current_entities:
			if not entities.has(entity_id):
				entities[entity_id] = current_entities[entity_id]
	var walkable := false
	for tile in layout.deck_tiles:
		if _walkable_in(_tile_center(tile), layout.deck_tiles, layout.structures, chests):
			walkable = true
			break
	if not walkable:
		return false
	data = {
		"version": 10, "day": int(saved.day), "minute": float(saved.minute), "elapsed": float(saved.elapsed), "navigation": navigation, "chart": chart, "island": island,
		"money": int(saved.money), "chests": chests, "expansion": int(saved.expansion),
		"crop": {"stage": int(crop.stage), "progress": float(crop.progress), "watered": bool(crop.watered)},
		"orders_filled": int(saved.get("orders_filled", 0)), "orders_limit": 3, "players": players, "entities": entities,
		"deck_tiles": layout.deck_tiles, "structures": layout.structures, "drift": layout.drift,
	}
	migration_notice = pending_migration_notice
	_inputs.clear()
	return true


func _keys(value: Dictionary, allowed: Array) -> bool:
	if value.size() != allowed.size():
		return false
	for key in allowed:
		if not value.has(key):
			return false
	return true


func _migrate_layout(expansion: int) -> Dictionary:
	var tiles: Array = []
	for gx in range(2, 12 + expansion):
		for gy in range(1, 8):
			tiles.append(_tile_key(gx, gy))
	return {
		"deck_tiles": tiles, "drift": _new_drift(tiles),
		"structures": {
			"legacy_bed_0": _new_structure("legacy_bed_0", "bed", Vector2(230, 170)),
			"legacy_bed_1": _new_structure("legacy_bed_1", "bed", Vector2(305, 170)),
			"legacy_grill": _new_structure("legacy_grill", "grill", Vector2(420, 290)),
			"legacy_garden": _new_structure("legacy_garden", "garden", Vector2(565, 175)),
			"legacy_orders": _new_structure("legacy_orders", "orders", Vector2(565, 290)),
		},
	}


func _validate_layout(saved: Dictionary) -> Dictionary:
	if not saved.get("deck_tiles") is Array or saved.deck_tiles.is_empty() or saved.deck_tiles.size() > 84:
		return {}
	var tiles: Array = []
	for key in saved.deck_tiles:
		if not key is String:
			return {}
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return {}
		var gx := int(parts[0])
		var gy := int(parts[1])
		if gx < 2 or gx > 13 or gy < 1 or gy > 7 or _tile_key(gx, gy) != key or key in tiles:
			return {}
		tiles.append(key)
	var visited: Dictionary = {tiles[0]: true}
	var pending: Array = [tiles[0]]
	while not pending.is_empty():
		var parts: PackedStringArray = str(pending.pop_front()).split(",")
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor := _tile_key(int(parts[0]) + direction.x, int(parts[1]) + direction.y)
			if neighbor in tiles and not visited.has(neighbor):
				visited[neighbor] = true
				pending.append(neighbor)
	if visited.size() != tiles.size():
		return {}
	if not saved.get("structures") is Dictionary or saved.structures.is_empty() or saved.structures.size() > 128:
		return {}
	var structures: Dictionary = {}
	var has_bed := false
	for id in saved.structures:
		if not id is String or id.length() > 64 or not id.is_valid_identifier() or not saved.structures[id] is Dictionary:
			return {}
		var structure: Dictionary = saved.structures[id]
		if not _keys(structure, ["id", "kind", "x", "y", "remaining", "output"]) or structure.get("id") != id or structure.get("kind") not in STRUCTURE_KINDS or not structure.get("output") is String:
			return {}
		if not _number(structure.get("x"), 0.0, 900.0) or not _number(structure.get("y"), 0.0, 560.0) or _point_tile(Vector2(float(structure.x), float(structure.y))) not in tiles:
			return {}
		var allowed_outputs: Array = [""]
		var duration := 0.0
		if structure.kind == "purifier":
			allowed_outputs.append("freshwater")
			duration = 12.0
		elif structure.kind == "grill":
			allowed_outputs.append_array(["cooked_fish", "meal"])
			duration = 10.0
		elif structure.kind == "furnace":
			allowed_outputs.append("ingot")
			duration = 15.0
		if not _number(structure.get("remaining"), 0.0, duration) or structure.output not in allowed_outputs or (float(structure.remaining) > 0.0 and structure.output.is_empty()):
			return {}
		if structure.kind in ["bed", "bedroll"]:
			has_bed = true
		structures[id] = {"id": id, "kind": structure.kind, "x": float(structure.x), "y": float(structure.y), "remaining": float(structure.remaining), "output": structure.output}
	if not has_bed or not saved.get("drift") is Dictionary:
		return {}
	if saved.drift.size() != DRIFT_KINDS.size():
		return {}
	var ocean := int(saved.version) >= 5
	var drift: Dictionary = {}
	for index in DRIFT_KINDS.size():
		var id := "drift_%02d" % index
		if not saved.drift.get(id) is Dictionary:
			return {}
		var item: Dictionary = saved.drift[id]
		var drift_keys := ["kind", "x", "y", "active", "respawn"]
		if ocean:
			drift_keys.append_array(["speed", "phase", "sway"])
		if not _keys(item, drift_keys) or item.get("kind") != DRIFT_KINDS[index] or not item.get("active") is bool:
			return {}
		var minimum_y := -80.0 if int(saved.version) >= 6 else (16.0 if ocean else 100.0)
		var maximum_y := 640.0 if int(saved.version) >= 6 else (544.0 if ocean else 450.0)
		if not _number(item.get("x"), -96.0 if ocean else -80.0, 980.0 if ocean else 950.0) or not _number(item.get("y"), minimum_y, maximum_y) or not _number(item.get("respawn"), 0.0, 7.0 if ocean else 4.0):
			return {}
		drift[id] = {"kind": item.kind, "x": float(item.x), "y": float(item.y), "active": item.active, "respawn": float(item.respawn)}
		if ocean:
			if not _number(item.get("speed"), 12.0, 20.0) or not _number(item.get("phase"), 0.0, TAU) or not _number(item.get("sway"), 4.0, 10.0):
				return {}
			for key in ["speed", "phase", "sway"]:
				drift[id][key] = float(item[key])
		else:
			_drift_variation(drift[id])
	if not ocean:
		# Replace the old rows once, without moving salvage already on either player's hook.
		var hooked: Dictionary = {}
		if saved.get("players") is Dictionary:
			for player in saved.players.values():
				if player is Dictionary and player.get("hook") is Dictionary and player.hook.get("id") is String:
					hooked[player.hook.id] = true
		var scattered := _new_drift(tiles)
		for id in drift:
			if drift[id].active and not hooked.has(id):
				drift[id].x = scattered[id].x
				drift[id].y = scattered[id].y
	return {"deck_tiles": tiles, "structures": structures, "drift": drift}


func _chest_id_valid(id: String) -> bool:
	for prefix in ["chest_", "migration_"]:
		if id.begins_with(prefix):
			var suffix := id.trim_prefix(prefix)
			if not suffix.is_valid_int() or str(int(suffix)) != suffix:
				return false
			return int(suffix) >= 0 and int(suffix) < MAX_SAVED_CHESTS
	return false


func _migrate_storage(storage: Dictionary) -> Dictionary:
	# Old worlds had an unlimited aggregate store. Keep its contents in extra finite boxes.
	var needed_slots := 0
	for item in STORAGE_ITEMS:
		needed_slots += int(ceil(float(storage[item]) / Inventory.STACK_LIMIT))
	if needed_slots > MAX_SAVED_CHESTS * Inventory.CHEST_SIZE:
		return {} # Refuse an impractically large/corrupt save, never truncate its possessions.
	var boxes: Dictionary = {"chest_0": _new_chest("chest_0", "共享木箱", Vector2(420, 175), Inventory.empty_slots(Inventory.CHEST_SIZE))}
	var current_id := "chest_0"
	var next_index := 0
	for item in STORAGE_ITEMS:
		var remaining := int(storage[item])
		while remaining > 0:
			remaining = Inventory.add(boxes[current_id].slots, item, remaining)
			if remaining > 0:
				current_id = "migration_%d" % next_index
				var point := Vector2(170.0 + (next_index % 12) * 46.0, 220.0 + ((next_index / 12) % 5) * 42.0)
				boxes[current_id] = _new_chest(current_id, "旧物资箱 %d" % (next_index + 1), point, Inventory.empty_slots(Inventory.CHEST_SIZE))
				next_index += 1
	return boxes


func _number(value: Variant, minimum: float, maximum: float) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, float(minimum), float(maximum)) and floorf(float(value)) == float(value)


func _counts_valid(value: Variant, keys: Array, maximum: int) -> bool:
	if not value is Dictionary or value.size() != keys.size():
		return false
	for key in keys:
		if not _integer(value.get(key), 0, maximum):
			return false
	return true


func _normalized_counts(value: Dictionary, keys: Array) -> Dictionary:
	var result: Dictionary = {}
	for key in keys:
		result[key] = int(value[key])
	return result

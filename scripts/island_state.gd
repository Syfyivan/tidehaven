extends RefCounted
const Map = preload("res://scripts/island_map.gd")
const Farming = preload("res://scripts/farming.gd")
const FARM := Vector2(500, 335)
const FISHING := Vector2(270, 425)
const SHOP := Vector2(640, 395)
const DOCK := Vector2(210, 380)
const CAMP := Vector2(305, 385)
static func create() -> Dictionary:
	return {"depleted": {}, "plots": {}, "homestead": {"rented": false, "claimed": {"host": false, "guest": false}}}

static func active(island: Dictionary, id: String, day: int, chests: Dictionary = {}) -> bool:
	var node: Dictionary = Map.node(id)
	if node.is_empty() or int(island.depleted.get(id, 0)) > day:
		return false
	var at := Vector2(float(node.x), float(node.y))
	for chest in chests.values():
		if chest.get("area", "deck") == "island" and absf(float(chest.x)-at.x) < 40 and absf(float(chest.y)-at.y) < 40:
			return false
	# New maintained streets suppress old wild nodes without changing their saved ids.
	if Map.TOWN_BOUNDS.has_point(at) and Map.terrain(at) in ["path", "bridge"]:
		return false
	if not Map.walkable(at):
		return false
	return not island.plots.has(Farming.plot_key(Vector2(float(node.x), float(node.y))))


static func blockers(island: Dictionary, day: int, from: Vector2, to: Vector2, chests: Dictionary = {}) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var search := Rect2(from, Vector2.ZERO).expand(to).grow(28)
	for resource: Dictionary in Map.nodes_near(from).values():
		var at := Vector2(resource.x, resource.y)
		if resource.kind not in ["tree", "stone", "ore"] or not search.has_point(at):
			continue
		if active(island, str(resource.id), day, chests):
			# Only ground-level solids block movement, never a tree's whole canopy.
			result.append(Rect2(at + Vector2(-8,-9),Vector2(16,14)) if resource.kind == "tree" else Rect2(at + Vector2(-12,-12),Vector2(24,20)))
	return result


static func feet_clear(from: Vector2, to: Vector2, solids: Array[Rect2]) -> bool:
	var feet := Rect2(to - Vector2(6,3),Vector2(12,6))
	for solid: Rect2 in solids:
		if feet.intersects(solid):
			# Old saves / regrowth can surround a player: allow movement out, not deeper in.
			var previous := Rect2(from - Vector2(6,3),Vector2(12,6))
			if not previous.intersects(solid) or to.distance_squared_to(solid.get_center()) <= from.distance_squared_to(solid.get_center()):
				return false
	return true

static func restore(value: Variant, version: int = 11, day: int = 1) -> Dictionary:
	if not value is Dictionary or value.size() != (3 if version >= 11 else 2):
		return {}
	if version < 9:
		return _migrate(value, day)
	if not value.get("depleted") is Dictionary or value.depleted.size() > 20000:
		return {}
	var depleted: Dictionary = {}
	for id in value.depleted:
		var number: Variant = value.depleted[id]
		if not id is String or Map.node(id).is_empty() or typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or floorf(float(number)) != float(number) or float(number) < 1 or float(number) > 1000010:
			return {}
		depleted[id] = int(number)
	var plots: Variant = Farming.restore_plots(value.get("plots"), version == 9, version == 10)
	if plots == null:
		return {}
	if version <= 13:
		plots = _fit_old_plots(plots)
		if plots == null:
			return {}
	var home: Dictionary = create().homestead
	if version >= 11:
		var saved: Variant = value.get("homestead")
		if not saved is Dictionary or saved.size() != 2 or not saved.get("rented") is bool or not saved.get("claimed") is Dictionary or saved.claimed.size() != 2:
			return {}
		for slot in ["host", "guest"]:
			if not saved.claimed.get(slot) is bool or (saved.claimed[slot] and not saved.rented):
				return {}
		home = saved.duplicate(true)
	return {"depleted": depleted, "plots": plots, "homestead": home}

static func _fit_old_plots(plots: Dictionary) -> Variant:
	# Keep all unaffected cells exactly where they were. Only new buildings/water
	# can move an old plot, with its crop, age, water and shelter intact.
	var result: Dictionary = {}
	var displaced: Array = []
	var keys: Array = plots.keys()
	keys.sort()
	for key: String in keys:
		if Map.tillable(Farming.plot_center(key)):
			result[key] = plots[key]
		else:
			displaced.append(key)
	for key: String in displaced:
		var center := Farming.plot_center(key)
		var placed := false
		for ring in range(1, 449):
			for y in range(-ring, ring + 1):
				for x in range(-ring, ring + 1):
					if absi(x) != ring and absi(y) != ring:
						continue
					var at := center + Vector2(x, y) * Map.TILE
					var next := Farming.plot_key(at)
					if next.is_empty() or result.has(next) or not Map.tillable(at):
						continue
					result[next] = plots[key]
					placed = true
					break
				if placed:
					break
			if placed:
				break
		if not placed:
			return null
	return result

static func _migrate(value: Dictionary, day: int) -> Dictionary:
	if not value.get("resources") is Dictionary or not value.get("crop") is Dictionary:
		return {}
	var ids := ["palm_0", "palm_1", "seeds_0", "stone_0", "ore_0", "wood_1"]
	if value.resources.size() != ids.size():
		return {}
	var result := create()
	for id in ids:
		if not value.resources.get(id) is bool:
			return {}
		if not value.resources[id]:
			result.depleted[id] = day + 1
	var crop: Dictionary = value.crop
	if crop.size() != 3 or typeof(crop.get("stage")) not in [TYPE_INT, TYPE_FLOAT] or typeof(crop.get("progress")) not in [TYPE_INT, TYPE_FLOAT] or not crop.get("watered") is bool:
		return {}
	if float(crop.stage) not in [0.0, 1.0, 2.0] or not is_finite(float(crop.progress)) or float(crop.progress) < 0 or float(crop.progress) > 1:
		return {}
	if (int(crop.stage) == 0 and (float(crop.progress) != 0 or crop.watered)) or (int(crop.stage) == 2 and float(crop.progress) != 1) or (not crop.watered and float(crop.progress) > 0):
		return {}
	if int(crop.stage) > 0:
		var plot: Dictionary = Farming.new_plot()
		plot.crop = "seed"
		plot.growth = 4 if int(crop.stage) == 2 else mini(3, floori(float(crop.progress) * 4))
		plot.watered = bool(crop.watered)
		result.plots[Farming.plot_key(FARM)] = plot
	return result

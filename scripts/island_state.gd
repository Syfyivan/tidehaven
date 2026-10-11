extends RefCounted
const Map = preload("res://scripts/island_map.gd")
const Farming = preload("res://scripts/farming.gd")
const FARM := Vector2(500, 335)
const FISHING := Vector2(270, 425)
const SHOP := Vector2(640, 395)
const DOCK := Vector2(210, 380)
const CAMP := Vector2(305, 385)
static func create() -> Dictionary:
	return {"depleted": {}, "plots": {}}

static func active(island: Dictionary, id: String, day: int) -> bool:
	var node: Dictionary = Map.node(id)
	if node.is_empty() or int(island.depleted.get(id, 0)) > day:
		return false
	if not Map.walkable(Vector2(float(node.x), float(node.y))):
		return false
	return not island.plots.has(Farming.plot_key(Vector2(float(node.x), float(node.y))))

static func restore(value: Variant, version: int = 10, day: int = 1) -> Dictionary:
	if not value is Dictionary or value.size() != 2:
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
	var plots: Variant = Farming.restore_plots(value.get("plots"), version == 9)
	if plots == null:
		return {}
	if version == 9:
		plots = _fit_old_plots(plots)
		if plots == null:
			return {}
	return {"depleted": depleted, "plots": plots}

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

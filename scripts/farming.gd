extends RefCounted
## Sparse island soil and daily crop rules. WorldState owns when a day advances.

const Inventory = preload("res://scripts/inventory.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const TILE := 32
const REACH := 64.0
const SEASON_DAYS := 28
const CAN_CAPACITY := 20
const ACTION_ITEMS := {"till": "hoe", "water": "watering_can", "cover": "canopy"}
const SEASONS := ["春", "夏", "秋", "冬"]
const CROPS := {
	"seed": {"name": "春萝卜", "days": 4, "seasons": [0], "yield": 2},
	"summer_seed": {"name": "玉米", "days": 7, "seasons": [1, 2], "yield": 2},
	"autumn_seed": {"name": "南瓜", "days": 10, "seasons": [2], "yield": 2},
	"winter_seed": {"name": "雪根", "days": 6, "seasons": [3], "yield": 2},
}

static func held_item(action: String, seed: String) -> String:
	return seed if action == "plant" else str(ACTION_ITEMS.get(action, action))


static func season(day: int) -> int:
	return posmod(floori(float(maxi(1, day) - 1) / SEASON_DAYS), 4)


static func date_label(day: int) -> String:
	var elapsed := maxi(1, day) - 1
	return "第%d年 · %s 第%d天" % [floori(float(elapsed) / (SEASON_DAYS * 4)) + 1, SEASONS[season(day)], posmod(elapsed, SEASON_DAYS) + 1]


static func crop_for_season(day: int) -> String:
	return ["seed", "summer_seed", "autumn_seed", "winter_seed"][season(day)]


static func new_plot() -> Dictionary:
	return {"crop": "", "growth": 0, "watered": false, "covered": false, "dead": false}


static func plot_key(point: Vector2) -> String:
	if not _inside(point):
		return ""
	return "%d,%d" % [floori(point.x / TILE), floori(point.y / TILE)]


static func plot_center(key: String) -> Vector2:
	var tile := _key_tile(key)
	if tile.x < 0:
		return Vector2(-1, -1)
	return (Vector2(tile) + Vector2(0.5, 0.5)) * TILE


static func mature(plot: Dictionary) -> bool:
	var crop: String = str(plot.get("crop", ""))
	return CROPS.has(crop) and not bool(plot.get("dead", false)) and int(plot.get("growth", 0)) >= int(CROPS[crop].days)

static func obstruction(data: Dictionary, point: Vector2) -> Dictionary:
	var key := plot_key(point)
	for node: Dictionary in IslandMap.nodes_near(point).values():
		if not IslandMap.walkable(Vector2(float(node.x), float(node.y))):
			continue
		if plot_key(Vector2(float(node.x), float(node.y))) == key and int(data.day) >= int(data.island.depleted.get(node.id, 0)):
			return node
	return {}


static func action(data: Dictionary, player: Dictionary, verb: String, args: Dictionary) -> String:
	if verb not in ["till", "plant", "water", "harvest", "cover", "clear_crop", "refill_can"]:
		return "这里没有这个农事操作。"
	if player.get("area") != "island" or not _finite(player.get("x")) or not _finite(player.get("y")):
		return "登岛后才能照料这片土地。"
	var keys: Array = ["x", "y"]
	if verb == "plant" and args.has("seed"):
		keys.append("seed")
	if args.size() != keys.size() or not args.has_all(keys) or not _finite(args.get("x")) or not _finite(args.get("y")):
		return "请选择附近的一格土地。"
	var point := Vector2(float(args.x), float(args.y))
	var at := Vector2(float(player.x), float(player.y))
	if not _inside(point) or not _inside(at):
		return "这处土地不在岛上。"
	if not data.get("island") is Dictionary or not data.island.get("plots") is Dictionary or not data.island.get("depleted") is Dictionary:
		return "这片土地暂时无法操作。"
	if verb == "refill_can":
		return _refill(player, at, point)
	var key := plot_key(point)
	var center := plot_center(key)
	if at.distance_to(center) > REACH:
		return "再靠近一些，农事操作只能照料身边两格。"
	var plots: Dictionary = data.island.plots
	if verb == "till":
		if plots.has(key):
			return "这格地已经开垦好了。"
		if Inventory.count(player.bag, "hoe") < 1:
			return "需要随身携带锄头才能开垦。"
		if not IslandMap.tillable(center):
			return "只有岛上的草地可以开垦，道路、沙滩和水边不能种植。"
		var blocked := obstruction(data, center)
		if not blocked.is_empty():
			return "先用%s%s，再锄地。" % [Inventory.ITEM_NAMES[blocked.tool], blocked.label]
		plots[key] = new_plot()
		_resume_work(player)
		return "开垦了一格土地 · 可播种或先浇水。"
	if not plots.has(key):
		return "先用锄头开垦这一格。"
	var plot: Dictionary = plots[key]
	match verb:
		"plant":
			return _plant(data, player, plot, args)
		"water":
			if Inventory.count(player.bag, "watering_can") < 1:
				return "需要把浇水壶带在自己的背包里。"
			if plot.dead:
				return "枯萎的植株无法恢复，先用镰刀清理。"
			if plot.watered:
				return "这格地今天已经浇过水了。"
			if not _integer(player.get("can_water"), 1, CAN_CAPACITY):
				return "水壶空了，去岛上的淡水池装满。"
			player.can_water = int(player.can_water) - 1
			plot.watered = true
			_resume_work(player)
			return "浇过水了 · 明天作物会长大一些。"
		"harvest":
			return _harvest(player, plot)
		"cover":
			if plot.covered:
				return "这格地已有暖棚保护。"
			if plot.dead:
				return "先清理枯萎植株，再搭暖棚。"
			if not Inventory.remove(player.bag, "canopy", 1):
				return "需要一个随身携带的暖棚套件。"
			plot.covered = true
			_resume_work(player)
			return "暖棚搭好了 · 这格作物可以跨季生长，仍需每天浇水。"
		"clear_crop":
			if not plot.dead:
				return "这里只能清理枯萎的植株。"
			if Inventory.count(player.bag, "scythe") < 1:
				return "需要随身携带镰刀清理枯萎植株。"
			_clear(plot)
			_resume_work(player)
			return "枯萎植株已清理，可以重新播种。"
	return ""


static func _plant(data: Dictionary, player: Dictionary, plot: Dictionary, args: Dictionary) -> String:
	if not str(plot.crop).is_empty():
		return "这格已经种下作物，先收获或清理枯萎植株。"
	var seed: Variant = args.get("seed", "seed")
	if not seed is String or not CROPS.has(seed):
		return "请选择一种可以种植的种子。"
	var crop: Dictionary = CROPS[seed]
	if not plot.covered and season(int(data.day)) not in crop.seasons:
		return "%s不适合当前季节，需要合适的季节或暖棚。" % crop.name
	if not Inventory.remove(player.bag, seed, 1):
		return "自己的背包里没有%s。" % Inventory.ITEM_NAMES[seed]
	plot.crop = seed
	plot.growth = 0
	plot.dead = false
	_resume_work(player)
	return "种下%s · 浇水生长 %d 天后成熟。" % [crop.name, int(crop.days)]


static func _harvest(player: Dictionary, plot: Dictionary) -> String:
	if not mature(plot):
		return "植株已经枯萎，先用镰刀清理。" if plot.dead else "作物还没有成熟。"
	var crop: Dictionary = CROPS[plot.crop]
	var bag: Array = player.bag.duplicate(true)
	if Inventory.add(bag, "veg", int(crop["yield"])) != 0 or Inventory.add(bag, plot.crop, 1) != 0:
		return "背包放不下全部蔬菜和种子，成熟作物仍留在地里。"
	player.bag = bag
	_clear(plot)
	_resume_work(player)
	return "收获%s · 蔬菜 +%d、原种子 +1。" % [crop.name, int(crop["yield"])]


static func _refill(player: Dictionary, at: Vector2, point: Vector2) -> String:
	if at.distance_to(point) > REACH or not IslandMap.water_near(at) or not IslandMap.water_near(point):
		return "走到岛上的淡水池边再装水，海水不能浇田。"
	if Inventory.count(player.bag, "watering_can") < 1:
		return "需要把浇水壶带在自己的背包里。"
	if not _integer(player.get("can_water"), 0, CAN_CAPACITY):
		return "水壶状态无效。"
	if int(player.can_water) == CAN_CAPACITY:
		return "水壶已经装满了。"
	player.can_water = CAN_CAPACITY
	_resume_work(player)
	return "水壶装满了 · 可以浇 %d 格地。" % CAN_CAPACITY


static func _resume_work(player: Dictionary) -> void:
	player.resting = false
	player.sleep_ready = false


static func _clear(plot: Dictionary) -> void:
	plot.crop = ""
	plot.growth = 0
	plot.watered = false
	plot.dead = false


static func advance_day(island: Dictionary, old_day: int, new_day: int) -> void:
	if old_day < 1 or new_day <= old_day or not island.get("plots") is Dictionary:
		return
	for plot in island.plots.values():
		var seed: String = str(plot.crop)
		if CROPS.has(seed) and not plot.dead:
			if plot.watered:
				plot.growth = mini(int(CROPS[seed].days), int(plot.growth) + 1)
			if not plot.covered:
				# One watering covers one night, even if an imported world skips dates.
				# A full year contains every possible intervening season.
				for offset in range(1, mini(new_day - old_day, SEASON_DAYS * 4) + 1):
					if season(old_day + offset) not in CROPS[seed].seasons:
						plot.dead = true
						break
		plot.watered = false


static func restore_plots(value: Variant, old_map: bool = false) -> Variant:
	if not value is Dictionary or value.size() > ceili(IslandMap.SIZE.x / TILE) * ceili(IslandMap.SIZE.y / TILE):
		return null
	var result: Dictionary = {}
	for key in value:
		if not key is String or _key_tile(key).x < 0:
			return null
		if not (IslandMap.legacy_tillable(plot_center(key)) if old_map else IslandMap.tillable(plot_center(key))):
			return null
		var plot: Variant = value[key]
		if not plot is Dictionary or plot.size() != 5 or not plot.has_all(["crop", "growth", "watered", "covered", "dead"]):
			return null
		if not plot.crop is String or (not plot.crop.is_empty() and not CROPS.has(plot.crop)) or not plot.watered is bool or not plot.covered is bool or not plot.dead is bool:
			return null
		var maximum := 0 if plot.crop.is_empty() else int(CROPS[plot.crop].days)
		if not _integer(plot.growth, 0, maximum) or (plot.crop.is_empty() and plot.dead) or (plot.dead and (plot.watered or plot.covered)):
			return null
		result[key] = {"crop": plot.crop, "growth": int(plot.growth), "watered": plot.watered, "covered": plot.covered, "dead": plot.dead}
	return result


static func _key_tile(key: String) -> Vector2i:
	if key.length() > 24:
		return Vector2i(-1, -1)
	var parts := key.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-1, -1)
	var tile := Vector2i(int(parts[0]), int(parts[1]))
	if tile.x < 0 or tile.y < 0 or str(tile.x) != parts[0] or str(tile.y) != parts[1] or not _inside((Vector2(tile) + Vector2(0.5, 0.5)) * TILE):
		return Vector2i(-1, -1)
	return tile


static func _inside(point: Vector2) -> bool:
	return point.is_finite() and point.x >= 0.0 and point.y >= 0.0 and point.x < IslandMap.SIZE.x and point.y < IslandMap.SIZE.y


static func _finite(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _finite(value) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum

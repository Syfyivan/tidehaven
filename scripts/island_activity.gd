extends RefCounted
const Map = preload("res://scripts/island_map.gd")
const Island = preload("res://scripts/island_state.gd")
const Inventory = preload("res://scripts/inventory.gd")

static func start(data: Dictionary, player: Dictionary, args: Dictionary) -> String:
	if player.area != "island" or not player.activity.is_empty():
		return "先登岛，或等当前动作完成；右键可取消。"
	if args.size() != 1 or not args.get("id") is String:
		return "请选择附近的岛上物资。"
	var node: Dictionary = Map.node(args.id)
	if node.is_empty() or not Island.active(data.island, args.id, int(data.day)) or _point(player).distance_to(_point(node)) > 64:
		return "请靠近还没采集的物资。"
	if Inventory.count(player.bag, node.tool) < 1:
		return "需要随身携带%s · C 手工制作。" % Inventory.ITEM_NAMES.get(node.tool, node.tool)
	if float(player.stamina) < float(node.cost):
		return "体力不足，回营地休息或吃熟食。"
	player.resting = false
	player.sleep_ready = false
	player.activity = {"kind": "island_gather", "id": args.id, "duration": float(node.duration), "remaining": float(node.duration), "start_x": float(player.x), "start_y": float(player.y)}
	return "%s · %.1f 秒 · 移动/右键取消" % [node.label, node.duration]

static func tick(data: Dictionary, player: Dictionary, delta: float) -> String:
	var activity: Dictionary = player.activity
	if activity.is_empty():
		return ""
	if not valid(activity):
		player.activity = {}
		return "采集状态无效，已取消。"
	var node: Dictionary = Map.node(str(activity.id))
	if player.area != "island" or _point(player).distance_to(Vector2(float(activity.start_x), float(activity.start_y))) > 8 or _point(player).distance_to(_point(node)) > 64:
		player.activity = {}
		return "已停止采集，物资留在原处。"
	if not Island.active(data.island, activity.id, int(data.day)):
		player.activity = {}
		return "这处物资已被同伴收走。"
	if Inventory.count(player.bag, node.tool) < 1:
		player.activity = {}
		return "工具已不在背包，采集取消。"
	activity.remaining = maxf(0, float(activity.remaining) - delta)
	if float(activity.remaining) > 0:
		return ""
	player.activity = {}
	if float(player.stamina) < float(node.cost):
		return "体力不足，物资留在原处。"
	var bag: Array = player.bag.duplicate(true)
	if Inventory.add(bag, str(node.item), int(node.amount)) != 0:
		return "背包放不下，物资留在原处。"
	player.bag = bag
	player.stamina -= float(node.cost)
	data.island.depleted[activity.id] = int(data.day) + int(node.regrow)
	return "%s +%d → 背包" % [Inventory.ITEM_NAMES[node.item], node.amount]

static func valid(value: Variant, old_map: bool = false) -> bool:
	if not value is Dictionary or value.size() != 6 or value.get("kind") != "island_gather" or not value.get("id") is String:
		return false
	var node: Dictionary = Map.node(value.id)
	if node.is_empty():
		return false
	for key in ["duration", "remaining", "start_x", "start_y"]:
		if typeof(value.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value[key])):
			return false
	var start_point := Vector2(float(value.start_x), float(value.start_y))
	return float(value.duration) == float(node.duration) and float(value.remaining) >= 0 and float(value.remaining) <= float(value.duration) and (Map.legacy_walkable(start_point) if old_map else Map.walkable(start_point))

static func _point(value: Dictionary) -> Vector2:
	return Vector2(float(value.x), float(value.y))

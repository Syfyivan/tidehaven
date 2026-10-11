extends RefCounted

const Inventory = preload("res://scripts/inventory.gd")
const REACH := 64.0
const MOVE_CANCEL := 8.0
const SPEAR_WINDUP := 0.3
const SPEAR_SPEED := 220.0
const SPEAR_RANGE := 170.0
const SPEAR_COOLDOWN := 0.9
const SPEAR_RADIUS := 12.0


static func start(data: Dictionary, player: Dictionary, verb: String, args: Dictionary) -> String:
	if verb == "catch":
		return "带上鱼叉，朝游鱼瞄准后点击发射。"
	if not _underwater(player):
		return "下潜后才能进行这个操作。"
	var current: Variant = player.get("activity", {})
	if not current is Dictionary or not current.is_empty():
		return "当前操作尚未结束；右键可取消采集。"
	if verb == "spear":
		return _start_spear(player, args)
	var kinds: Array = ["wood"] if verb == "collect" else (["stone", "ore"] if verb == "mine" else (["wreck"] if verb == "search_wreck" else []))
	if kinds.is_empty() or not _keys(args, ["id"]) or not args.get("id") is String:
		return "请选择附近可以采集的物资。"
	var target: Dictionary = data.get("entities", {}).get(args.id, {})
	if target.is_empty() or target.get("kind") not in kinds or not target.get("active", false) or _point(player).distance_to(_point(target)) > REACH:
		return "请靠近还没采集过的物资。"
	if float(player.stamina) < _gather_cost(target.kind):
		return "体力不足，吃点熟食或回甲板休息。"
	var duration := _gather_duration(player, target.kind)
	player.activity = {"kind": "gather", "id": args.id, "duration": duration, "remaining": duration, "start_x": float(player.x), "start_y": float(player.y)}
	return "正在搜寻沉箱……移动或右键取消。" if target.kind == "wreck" else "正在采集%s……移动或右键取消。" % Inventory.ITEM_NAMES[target.kind]


static func _start_spear(player: Dictionary, args: Dictionary) -> String:
	if Inventory.count(player.bag, "harpoon") < 1:
		return "需要随身携带鱼叉，再朝游鱼瞄准发射。"
	if not _keys(args, ["x", "y"]) or not _finite(args.get("x")) or not _finite(args.get("y")):
		return "请给鱼叉选择一个有效方向。"
	# Scale before constructing Vector2 so even large finite input cannot overflow it.
	var magnitude := maxf(absf(float(args.x)), absf(float(args.y)))
	if magnitude < 0.000001:
		return "请朝游鱼瞄准，不能向脚下发射。"
	if float(player.stamina) < 5.0:
		return "体力不足，鱼叉需要 5 体力。"
	var direction := Vector2(float(args.x) / magnitude, float(args.y) / magnitude).normalized()
	player.activity = {"kind": "spear", "phase": "windup", "x": float(player.x), "y": float(player.y), "dx": direction.x, "dy": direction.y, "duration": SPEAR_WINDUP, "remaining": SPEAR_WINDUP, "distance": 0.0}
	return "鱼叉蓄势中……"


static func tick(data: Dictionary, player: Dictionary, delta: float) -> String:
	if not is_finite(delta) or delta <= 0.0:
		return ""
	var current: Variant = player.get("activity", {})
	if current is Dictionary and current.is_empty():
		return ""
	if not valid_activity(current):
		player.activity = {}
		return "操作状态无效，已取消。"
	if not _underwater(player):
		player.activity = {}
		return "已离开水下，操作取消。"
	if player.activity.kind == "gather":
		return _tick_gather(data, player, delta)
	return _tick_spear(data, player, delta)


static func _tick_gather(data: Dictionary, player: Dictionary, delta: float) -> String:
	var activity: Dictionary = player.activity
	var target: Dictionary = data.get("entities", {}).get(activity.id, {})
	if _point(player).distance_to(Vector2(float(activity.start_x), float(activity.start_y))) > MOVE_CANCEL:
		player.activity = {}
		return "移动后已取消采集，物资仍在原处。"
	if target.is_empty() or target.get("kind") not in ["wood", "stone", "ore", "wreck"] or not target.get("active", false):
		player.activity = {}
		return "这处物资已经被收走了。"
	if _point(player).distance_to(_point(target)) > REACH:
		player.activity = {}
		return "离物资太远，采集已取消。"
	activity.remaining = maxf(0.0, float(activity.remaining) - delta)
	if float(activity.remaining) > 0.0:
		return ""
	player.activity = {}
	var cost := _gather_cost(target.kind)
	if float(player.stamina) < cost:
		return "体力不足，物资仍在原处。"
	var item: String = "treasure" if target.kind == "wreck" else str(target.kind)
	var amount := 2 if item == "stone" else 1
	var bag: Array = player.bag.duplicate(true)
	if Inventory.add(bag, item, amount) != 0:
		return "背包已满，物资仍在原处。"
	player.bag = bag
	player.stamina -= cost
	target.active = false
	return "%s +%d → 我的背包" % [Inventory.ITEM_NAMES[item], amount]


static func _tick_spear(data: Dictionary, player: Dictionary, delta: float) -> String:
	var activity: Dictionary = player.activity
	var left := delta
	var notice := ""
	while left > 0.0 and not player.activity.is_empty():
		var consumed := minf(left, float(activity.remaining))
		if activity.phase == "windup":
			activity.x = float(player.x)
			activity.y = float(player.y)
			activity.remaining = maxf(0.0, float(activity.remaining) - consumed)
			left -= consumed
			if float(activity.remaining) > 0.0:
				break
			if float(player.stamina) < 5.0 or Inventory.count(player.bag, "harpoon") < 1:
				player.activity = {}
				return "鱼叉未能出手：需要随身鱼叉和 5 体力。"
			player.stamina -= 5.0
			_set_phase(activity, "flight", SPEAR_RANGE / SPEAR_SPEED)
		elif activity.phase == "flight":
			var from := _point(activity)
			var distance := minf(SPEAR_RANGE - float(activity.distance), SPEAR_SPEED * consumed)
			var direction := Vector2(float(activity.dx), float(activity.dy))
			var to := from + direction * distance
			var hit := _swept_fish(data.get("entities", {}), from, to)
			if not hit.is_empty():
				var fraction := float(hit.fraction)
				activity.x = from.lerp(to, fraction).x
				activity.y = from.lerp(to, fraction).y
				activity.distance = minf(SPEAR_RANGE, float(activity.distance) + distance * fraction)
				left -= consumed * fraction
				var bag: Array = player.bag.duplicate(true)
				if Inventory.add(bag, "fish", 1) != 0:
					notice = "背包已满，鱼仍留在水中。"
				else:
					player.bag = bag
					data.entities[hit.id].active = false
					player.caught = int(player.get("caught", 0)) + 1
					notice = "鱼 +1 → 我的背包"
				_set_phase(activity, "cooldown", SPEAR_COOLDOWN)
			else:
				activity.x = to.x
				activity.y = to.y
				activity.distance = minf(SPEAR_RANGE, float(activity.distance) + distance)
				activity.remaining = maxf(0.0, float(activity.remaining) - consumed)
				left -= consumed
				if float(activity.remaining) <= 0.0 or float(activity.distance) >= SPEAR_RANGE:
					_set_phase(activity, "cooldown", SPEAR_COOLDOWN)
					notice = "鱼叉没有命中，再瞄准试试。"
		else:
			activity.remaining = maxf(0.0, float(activity.remaining) - consumed)
			left -= consumed
			if float(activity.remaining) <= 0.0:
				player.activity = {}
	return notice


static func _swept_fish(entities: Dictionary, from: Vector2, to: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var earliest := INF
	var segment := to - from
	var length_squared := segment.length_squared()
	for id in entities:
		var entity: Dictionary = entities[id]
		if entity.get("kind") != "fish" or not entity.get("active", false):
			continue
		var fraction := clampf((_point(entity) - from).dot(segment) / length_squared, 0.0, 1.0) if length_squared > 0.0 else 0.0
		if _point(entity).distance_squared_to(from + segment * fraction) <= SPEAR_RADIUS * SPEAR_RADIUS and fraction < earliest:
			earliest = fraction
			nearest = {"id": id, "fraction": fraction}
	return nearest


static func _set_phase(activity: Dictionary, phase: String, duration: float) -> void:
	activity.phase = phase
	activity.duration = duration
	activity.remaining = duration


static func _gather_duration(player: Dictionary, kind: String) -> float:
	if kind == "wood":
		return 2.5 if Inventory.count(player.bag, "axe") > 0 else 8.0
	if kind == "stone":
		return 3.0 if Inventory.count(player.bag, "pickaxe") > 0 else 12.0
	if kind == "ore":
		return 4.0 if Inventory.count(player.bag, "pickaxe") > 0 else 16.0
	return 7.0


static func _gather_cost(kind: String) -> float:
	return 4.0 if kind in ["stone", "ore"] else 2.0


static func _underwater(player: Dictionary) -> bool:
	return player.get("area") == "water" and _number(player.get("x"), 40.0, 860.0) and _number(player.get("y"), 35.0, 520.0)


static func _point(value: Dictionary) -> Vector2:
	return Vector2(float(value.x), float(value.y))


static func valid_activity(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	if value.get("kind") == "gather":
		if not _keys(value, ["kind", "id", "duration", "remaining", "start_x", "start_y"]) or not value.get("id") is String or not value.id.is_valid_identifier() or value.id.length() > 80:
			return false
		if not _finite(value.get("duration")) or float(value.duration) not in [2.5, 3.0, 4.0, 7.0, 8.0, 12.0, 16.0]:
			return false
		return _number(value.get("remaining"), 0.0, float(value.duration)) and _number(value.get("start_x"), 40.0, 860.0) and _number(value.get("start_y"), 35.0, 520.0)
	if value.get("kind") != "spear" or not _keys(value, ["kind", "phase", "x", "y", "dx", "dy", "duration", "remaining", "distance"]):
		return false
	if value.get("phase") not in ["windup", "flight", "cooldown"]:
		return false
	if not _number(value.get("x"), -130.0, 1030.0) or not _number(value.get("y"), -135.0, 690.0) or not _number(value.get("dx"), -1.0, 1.0) or not _number(value.get("dy"), -1.0, 1.0) or not _number(value.get("distance"), 0.0, SPEAR_RANGE):
		return false
	if not is_equal_approx(Vector2(float(value.dx), float(value.dy)).length_squared(), 1.0):
		return false
	var duration := SPEAR_WINDUP if value.phase == "windup" else (SPEAR_RANGE / SPEAR_SPEED if value.phase == "flight" else SPEAR_COOLDOWN)
	if not _finite(value.get("duration")) or not is_equal_approx(float(value.duration), duration) or not _number(value.get("remaining"), 0.0, duration + 0.000001):
		return false
	if value.phase == "windup" and float(value.distance) != 0.0:
		return false
	return value.phase != "flight" or is_equal_approx(float(value.remaining), (SPEAR_RANGE - float(value.distance)) / SPEAR_SPEED)


static func _keys(value: Dictionary, expected: Array) -> bool:
	return value.size() == expected.size() and value.has_all(expected)


static func _finite(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return _finite(value) and float(value) >= minimum and float(value) <= maximum

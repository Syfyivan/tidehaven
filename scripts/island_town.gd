extends RefCounted
## Deterministic residents and host-side services. Nothing here is saved separately.
## Call action/tick only from WorldState's authoritative path; clients send intent.
const Map = preload("res://scripts/island_map.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Farming = preload("res://scripts/farming.gd")
const REACH := 64.0
const MONEY_LIMIT := 1000000000
const BATH_SECONDS := 8.0
const BATH_PRICE := 3
const TREAT_PRICE := 5
const NPCS := {
	"lin_sui": {"name": "林穗", "role": "超市店主", "landmark": "market", "variant": 0, "sprite_slot": "guest", "color": Color("eac99c"), "start": 480, "end": 1080, "talk": "种子得跟着季节买。我收新鲜蔬菜；清掉荒草和石头，再用锄头开田，别把明天要种的种子卖光啦。"},
	"su_qin": {"name": "苏芩", "role": "诊所医师", "landmark": "clinic", "variant": 1, "sprite_slot": "guest", "color": Color("dce8e4"), "start": 480, "end": 1200, "talk": "远行前看看体力和吃喝。诊所在广场东北侧；水壶要在淡水岸边装满，海水可不能直接喝。"},
	"tang_he": {"name": "汤禾", "role": "澡堂掌柜", "landmark": "bathhouse", "variant": 2, "sprite_slot": "host", "color": Color("b6d5d8"), "start": 600, "end": 1320, "talk": "先把肩膀放松。泡澡要安稳待八秒，泡好才收钱；赶路时随时能起身，今晚营地也留着睡袋。"},
	"he_mu": {"name": "贺木", "role": "木匠", "landmark": "carpenter", "variant": 3, "sprite_slot": "host", "color": Color("d7b68c"), "start": 480, "end": 1020, "talk": "两块木板能换三份纤维，省得你临时找荒草。林地在镇子往东；枯枝也得用斧头处理，别徒手硬掰。"},
	"yan_zhen": {"name": "严砧", "role": "铁匠", "landmark": "smith", "variant": 4, "sprite_slot": "host", "color": Color("b9b1ad"), "start": 540, "end": 1080, "talk": "石斧伐木，石镐凿石。往东的灰岩山麓有露天矿；矿洞入口还封着，先在外面找矿脉。"},
	"zhou_chao": {"name": "周潮", "role": "渔民", "landmark": "fishery", "variant": 5, "sprite_slot": "host", "color": Color("b2c5cf"), "start": 360, "end": 960, "talk": "我每天六点就摆摊，鲜鱼一条收四枚金币。带鱼叉下潜之前先把船停稳，氧气不够就往浮标游。"},
	"tian_qing": {"name": "田青", "role": "农人", "landmark": "farmhouse", "variant": 6, "sprite_slot": "guest", "color": Color("bfd0a2"), "start": 420, "end": 1080, "talk": "南面的旧日农庄有开阔荒地，每一格都得自己整理。种好每天浇水，睡过一夜才长；换季要留意种子的时令。"},
	"lu_yao": {"name": "陆遥", "role": "引路员", "landmark": "plaza", "variant": 7, "sprite_slot": "guest", "color": Color("d7bdd0"), "start": 420, "end": 1260, "talk": "这里是镇广场，码头在西边。按 M 能看岛图：东面林地与山麓，南面湿地、农庄和古迹；地图只指路，不会把人送过去。"},
}
const PLAZA_OFFSETS := [Vector2(-48, -32), Vector2(0, -48), Vector2(48, -32), Vector2(-64, 16), Vector2(64, 16), Vector2(-40, 56), Vector2(0, 64), Vector2(40, 56)]
const TRADES := {
	"buy_seed": {"npc": "lin_sui", "price": 3, "take": {}, "give": {"season_seed": 1}},
	"sell_veg": {"npc": "lin_sui", "price": -4, "take": {"veg": 1}, "give": {}},
	"sell_fish": {"npc": "zhou_chao", "price": -4, "take": {"fish": 1}, "give": {}},
	"swap_fiber": {"npc": "he_mu", "price": 0, "take": {"wood": 2}, "give": {"fiber": 3}},
	"buy_rope": {"npc": "he_mu", "price": 3, "take": {}, "give": {"rope": 1}},
	"buy_axe": {"npc": "yan_zhen", "price": 12, "take": {}, "give": {"axe": 1}},
	"buy_pickaxe": {"npc": "yan_zhen", "price": 14, "take": {}, "give": {"pickaxe": 1}},
	"buy_can": {"npc": "tian_qing", "price": 10, "take": {}, "give": {"watering_can": 1}},
}


static func open_at(npc_id: String, minute: float) -> bool:
	if not NPCS.has(npc_id) or not is_finite(minute):
		return false
	var npc: Dictionary = NPCS[npc_id]
	var landmark: Dictionary = Map.LANDMARKS.get(npc.landmark, {})
	var clock_minute := fposmod(minute, 1440.0)
	return bool(landmark.get("open", false)) and clock_minute >= float(npc.start) and clock_minute < float(npc.end)


static func position(npc_id: String, minute: float) -> Vector2:
	if not NPCS.has(npc_id):
		return Vector2(-10000, -10000)
	var npc: Dictionary = NPCS[npc_id]
	if open_at(npc_id, minute):
		return Map.LANDMARKS[npc.landmark].door
	return Map.LANDMARKS.plaza.door + PLAZA_OFFSETS[int(npc.variant)]


static func residents(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var minute := float(data.get("minute", 360.0))
	for npc_id: String in NPCS:
		var row: Dictionary = NPCS[npc_id].duplicate(true)
		var at := position(npc_id, minute)
		row.id = npc_id
		row.x = at.x
		row.y = at.y
		row.open = open_at(npc_id, minute)
		row.hours = _hours(NPCS[npc_id])
		result[npc_id] = row
	return result


static func options(data: Dictionary, player: Dictionary) -> Array:
	var result: Array = []
	if not _actor_ready(player):
		return result
	for npc_id: String in NPCS:
		if not _near(data, player, npc_id):
			continue
		var npc: Dictionary = NPCS[npc_id]
		result.append({"action": "town_talk", "label": "%s · %s · 聊聊" % [npc.name, npc.role], "args": {"id": npc_id}})
		if not open_at(npc_id, float(data.minute)):
			continue
		for offer_id: String in TRADES:
			if TRADES[offer_id].npc == npc_id:
				result.append({"action": "town_trade", "label": _trade_label(data, offer_id), "args": {"id": npc_id, "offer": offer_id}})
		if npc_id == "su_qin":
			result.append({"action": "town_treat", "label": "诊疗补给 · 5金币 · 体+60/饱+35/水+35", "args": {"id": npc_id}})
		elif npc_id == "tang_he":
			result.append({"action": "town_bath", "label": "泡澡8秒 · 3金币 · 体+60/水+20", "args": {"id": npc_id}})
	return result


static func action(data: Dictionary, player: Dictionary, verb: String, args: Dictionary) -> String:
	if verb not in ["town_talk", "town_trade", "town_treat", "town_bath"]:
		return "这里没有这个小镇服务。"
	var keys: Array = ["id", "offer"] if verb == "town_trade" else ["id"]
	if args.size() != keys.size() or not args.has_all(keys) or not args.get("id") is String or not NPCS.has(args.id):
		return "请选择附近的居民。"
	var npc_id: String = args.id
	if not _actor_ready(player) or not _near(data, player, npc_id):
		return "请在岛上走近这位居民，再使用服务。"
	var npc: Dictionary = NPCS[npc_id]
	if verb == "town_talk":
		var clock_note := "营业 %s。" % _hours(npc) if open_at(npc_id, float(data.minute)) else "我已收工，营业时间 %s。" % _hours(npc)
		return "%s：%s %s" % [npc.name, npc.talk, clock_note]
	if not open_at(npc_id, float(data.minute)):
		return "%s已经收工，%s再来吧。" % [npc.name, _hours(npc)]
	if not player.get("activity", {}).is_empty() or not player.get("hook", {}).is_empty() or not player.get("fishing", {}).is_empty():
		return "先完成当前动作，或右键取消后再来。"
	if not _money_valid(data.get("money")) or not Inventory.validate_slots(player.get("bag"), Inventory.BAG_SIZE):
		return "物品或金币状态无效，未进行交易。"
	match verb:
		"town_trade":
			return _trade(data, player, npc_id, args.get("offer"))
		"town_treat":
			if npc_id != "su_qin":
				return "诊疗请找诊所的苏芩。"
			if not _needs_care(player, true):
				return "你现在精神和吃喝都很充足，不需要付费诊疗。"
			if int(data.money) < TREAT_PRICE:
				return "诊疗补给需要5枚共享金币。"
			data.money -= TREAT_PRICE
			_start_service(player)
			player.stamina = minf(100, float(player.stamina) + 60)
			player.hunger = minf(100, float(player.hunger) + 35)
			player.thirst = minf(100, float(player.thirst) + 35)
			return "苏芩为你准备了补给 · 体力+60/饱食+35/水分+35（最多100）· -5金币"
		"town_bath":
			if npc_id != "tang_he":
				return "泡澡请找澡堂的汤禾。"
			if not _needs_care(player, false):
				return "体力和水分都很充足，先把金币留着吧。"
			if int(data.money) < BATH_PRICE:
				return "泡澡需要3枚共享金币，完成后才扣。"
			_start_service(player)
			player.activity = {"kind": "town_bath", "id": npc_id, "duration": BATH_SECONDS, "remaining": BATH_SECONDS, "start_x": float(player.x), "start_y": float(player.y)}
			return "放松泡澡 · 8秒后体力+60/水分+20，完成扣3金币 · 移动/右键取消"
	return "这里没有这个小镇服务。"


static func tick(data: Dictionary, player: Dictionary, delta: float) -> String:
	var activity: Dictionary = player.get("activity", {})
	if activity.get("kind") != "town_bath":
		return ""
	if not valid(activity):
		player.activity = {}
		return "泡澡状态无效，已取消且未扣金币。"
	if not is_finite(delta) or delta <= 0:
		return ""
	if not _actor_ready(player) or _point(player).distance_to(Vector2(float(activity.start_x), float(activity.start_y))) > 8 or not _near(data, player, str(activity.id)) or not open_at(str(activity.id), float(data.minute)):
		player.activity = {}
		return "泡澡已取消，未扣金币。"
	activity.remaining = maxf(0, float(activity.remaining) - delta)
	if float(activity.remaining) > 0:
		return ""
	player.activity = {}
	if not _needs_care(player, false):
		return "已经恢复精神，这次不收泡澡费。"
	if not _money_valid(data.get("money")) or int(data.money) < BATH_PRICE:
		return "共享金币不足3枚，未进行恢复，也没有扣款。"
	data.money -= BATH_PRICE
	player.stamina = minf(100, float(player.stamina) + 60)
	player.thirst = minf(100, float(player.thirst) + 20)
	return "泡澡完成 · 体力+60/水分+20（最多100）· -3金币"


static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 6 or value.get("kind") != "town_bath" or value.get("id") != "tang_he":
		return false
	for key in ["duration", "remaining", "start_x", "start_y"]:
		if not _finite(value.get(key)):
			return false
	var start := Vector2(float(value.start_x), float(value.start_y))
	var door: Vector2 = Map.LANDMARKS.bathhouse.door
	return float(value.duration) == BATH_SECONDS and float(value.remaining) >= 0 and float(value.remaining) <= BATH_SECONDS and start.distance_to(door) <= REACH and Map.walkable(start)


static func _trade(data: Dictionary, player: Dictionary, npc_id: String, offer: Variant) -> String:
	if not offer is String or not TRADES.has(offer) or TRADES[offer].npc != npc_id:
		return "这位居民不提供该交易。"
	var trade: Dictionary = TRADES[offer]
	var after_money := int(data.money) - int(trade.price)
	if after_money < 0:
		return "共享金币不足，需要%d枚。" % int(trade.price)
	if after_money > MONEY_LIMIT:
		return "共享金币已经装满，物品留在背包里。"
	var bag: Array = player.bag.duplicate(true)
	for item: String in trade.take:
		if not Inventory.remove(bag, item, int(trade.take[item])):
			return "需要本人背包里的%s ×%d。" % [Inventory.ITEM_NAMES[item], int(trade.take[item])]
	for item: String in trade.give:
		var actual_item := Farming.crop_for_season(int(data.day)) if item == "season_seed" else item
		if Inventory.add(bag, actual_item, int(trade.give[item])) != 0:
			return "背包装不下，物品和金币都没有扣除。"
	player.bag = bag
	data.money = after_money
	_start_service(player)
	return "交易完成 · " + _trade_label(data, str(offer))


static func _trade_label(data: Dictionary, offer_id: String) -> String:
	match offer_id:
		"buy_seed": return "购买%s ×1 · 3金币" % Inventory.ITEM_NAMES[Farming.crop_for_season(int(data.day))]
		"sell_veg": return "出售蔬菜 ×1 · 获得4金币"
		"sell_fish": return "出售鲜鱼 ×1 · 获得4金币"
		"swap_fiber": return "木板 ×2 换植物纤维 ×3"
		"buy_rope": return "购买绳子 ×1 · 3金币"
		"buy_axe": return "购买石斧 ×1 · 12金币"
		"buy_pickaxe": return "购买石镐 ×1 · 14金币"
		"buy_can": return "购买浇水壶 ×1 · 10金币"
	return ""


static func _actor_ready(player: Dictionary) -> bool:
	return player.get("area") == "island" and bool(player.get("online", false)) and _finite(player.get("x")) and _finite(player.get("y"))


static func _near(data: Dictionary, player: Dictionary, npc_id: String) -> bool:
	return _finite(data.get("minute")) and _point(player).distance_to(position(npc_id, float(data.minute))) <= REACH


static func _needs_care(player: Dictionary, include_food: bool) -> bool:
	return float(player.stamina) < 100 or float(player.thirst) < 100 or (include_food and float(player.hunger) < 100)


static func _start_service(player: Dictionary) -> void:
	player.resting = false
	player.sleep_ready = false


static func _hours(npc: Dictionary) -> String:
	return "%02d:%02d—%02d:%02d" % [floori(float(npc.start) / 60), int(npc.start) % 60, floori(float(npc.end) / 60), int(npc.end) % 60]


static func _point(value: Dictionary) -> Vector2:
	return Vector2(float(value.x), float(value.y))


static func _finite(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _money_valid(value: Variant) -> bool:
	return _finite(value) and float(value) == floorf(float(value)) and float(value) >= 0 and float(value) <= MONEY_LIMIT

extends RefCounted
## Deterministic residents and host-side services. Rental and personal gifts live in the shared island save.
## Call action/tick only from WorldState's authoritative path; clients send intent.
const Map = preload("res://scripts/island_map.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Farming = preload("res://scripts/farming.gd")
const Routes = preload("res://scripts/resident_routes.gd")
const Restaurant=preload("res://scripts/restaurant.gd")
const Rooms = preload("res://scripts/rooms.gd")
const Housing=preload("res://scripts/housing.gd")
const Journal=preload("res://scripts/journal.gd")
const PersonalStories=preload("res://scripts/resident_stories.gd")
const REACH := 64.0
const MONEY_LIMIT := 1000000000
const BATH_SECONDS := 8.0
const BATH_PRICE := 3
const TREAT_PRICE := 5
const NPCS := {
	"lu_zhou": {"name":"陆舟","role":"港口救援员","landmark":"fishery","home":"east_house","work_at":Vector2(272,208),"variant":14,"start":480,"end":960,"talk":"我在周潮的渔铺检查救生绳。以前遇过一场大浪，之后总想把准备做得再仔细些。你下水时别急着游远，先认清浮标在哪；有空的话，我想听听你在海里看到了什么。"},
	"mu_tong": {"name":"沐桐","role":"植物画师","landmark":"farmhouse","home":"orchard_house","work_at":Vector2(368,464),"variant":15,"start":540,"end":1020,"talk":"田青借了我一张桌子，好把岛上的野花和庄稼画下来。城里的人只记得盛开的样子，可我喜欢它们刚冒芽的时候。等你院里的第一茬作物长起来，也带我去看看吧。"},
	"gu_xing": {"name":"顾星","role":"潮汐器械师","landmark":"carpenter","home":"east_house","work_at":Vector2(400,656),"variant":16,"start":600,"end":1080,"talk":"我借贺木工坊的一角修测潮仪。海风和潮水有自己的节奏，旧仪器却总慢半拍。严砧说齿轮没坏，或许是我太想把每件事算准了。你从外岛回来时，能和我讲讲那里的浪吗？"},
	"xu_mian": {"name":"许棉","role":"裁缝","landmark":"market","home":"orchard_house","work_at":Vector2(304,656),"variant":17,"start":600,"end":1080,"talk":"林穗把柜台边的位置借给我缝衣服。我以前总照着别人的样子做，最近想试试自己的配色。发型和衣服都可以换，舒服最要紧；你喜欢明亮一点，还是像旧帆布那样安静的颜色？"},
	"chen_yu": {"name":"陈鱼","role":"厨师","landmark":"restaurant","variant":9,"start":660,"end":1320,"talk":"旧酒馆的灶台还好用。你潜水带回来的鱼很鲜，配上自己种的蔬菜做寿司吧。镇长管租约，我白天在店里，你们两个人可以一个备餐、一个上菜。"},
	"wen_zhi": {"name":"温知","role":"教师","landmark":"townhall","variant":10,"start":480,"end":960,"talk":"镇公所借了角落给我们上课。图鉴里记着四季：春萝卜四天，玉米七天，南瓜十天，雪根六天。每天浇水，夜里才生长。修好温室就不用担心换季了。"},
	"qiao_xin": {"name":"乔信","role":"邮差","landmark":"plaza","variant":11,"start":540,"end":1020,"talk":"我把镇里的供货单带到广场。居民需要鱼和蔬菜，凑够一单再交给我，金币会进你们的共同钱袋。做不做都行，不耽误出海。"},
	"shi_xun": {"name":"石寻","role":"矿工","landmark":"smith","variant":12,"start":540,"end":1080,"talk":"灰岩山麓的矿洞已经能进。带石镐，一层层开通落石，深处矿更多。走近入口可以上一层；挖到的矿带回熔炉，木板当燃料。"},
	"sen_ke": {"name":"森柯","role":"护林员","landmark":"plaza","work_at":Vector2(1456,944),"variant":13,"start":420,"end":1020,"talk":"风语林地有老树丛、野生种子洼地和藏箱遗址。地图会标出来，带上斧、镰和锄头。林地也有淡水，别跑到一半没水喝。"},
	"xu_an": {"name": "许岸", "role": "镇长", "landmark": "townhall", "variant": 8, "sprite_slot": "host", "color": Color("b6c8b0"), "start": 420, "end": 1260, "talk": "镇公所东南那座大院空了很久。愿意照料的话，首期租金就免了，慢慢收拾就好。先开哪片地、种什么，都由你们自己定。"},
	"lin_sui": {"name": "林穗", "role": "超市店主", "landmark": "market", "variant": 0, "sprite_slot": "guest", "color": Color("eac99c"), "start": 480, "end": 1080, "talk": "种子得跟着季节买。我收新鲜蔬菜；清掉荒草和石头，再用锄头开田，别把明天要种的种子卖光啦。"},
	"su_qin": {"name": "苏芩", "role": "诊所医师", "landmark": "clinic", "variant": 1, "sprite_slot": "guest", "color": Color("dce8e4"), "start": 480, "end": 1200, "talk": "远行前看看体力和吃喝。诊所在超市西侧；水壶要在淡水岸边装满，海水可不能直接喝。"},
	"tang_he": {"name": "汤禾", "role": "澡堂掌柜", "landmark": "bathhouse", "variant": 2, "sprite_slot": "host", "color": Color("b6d5d8"), "start": 600, "end": 1320, "talk": "先把肩膀放松。沿走廊往下进入池水，按E安稳泡八秒，泡好才收钱；赶路时随时能起身，今晚营地也留着睡袋。"},
	"he_mu": {"name": "贺木", "role": "木匠", "landmark": "carpenter", "variant": 3, "sprite_slot": "host", "color": Color("d7b68c"), "start": 480, "end": 1020, "talk": "两块木板能换三份纤维，省得你临时找荒草。林地在镇子往东；枯枝也得用斧头处理，别徒手硬掰。"},
	"yan_zhen": {"name": "严砧", "role": "铁匠", "landmark": "smith", "variant": 4, "sprite_slot": "host", "color": Color("b9b1ad"), "start": 540, "end": 1080, "talk": "石斧伐木，石镐凿石。往东的灰岩山麓有露天矿；矿洞有三层，带镐逐层开通落石。"},
	"zhou_chao": {"name": "周潮", "role": "渔民", "landmark": "fishery", "variant": 5, "sprite_slot": "host", "color": Color("b2c5cf"), "start": 360, "end": 960, "talk": "我每天六点就摆摊，鲜鱼一条收四枚金币。带鱼叉下潜之前先把船停稳，氧气不够就往浮标游。"},
	"tian_qing": {"name": "田青", "role": "农人", "landmark": "farmhouse", "variant": 6, "sprite_slot": "guest", "color": Color("bfd0a2"), "start": 420, "end": 1080, "talk": "东南的旧院子很大，先挑一处顺手的空地就好。枯枝用斧头，荒草用镰刀，石块用镐；这些都能自己制作。种好每天浇水，睡过一夜才长；换季要留意种子的时令。"},
	"lu_yao": {"name": "陆遥", "role": "引路员", "landmark": "plaza", "variant": 7, "sprite_slot": "guest", "color": Color("d7bdd0"), "start": 420, "end": 1260, "talk": "码头在西边，镇公所在东街。许岸镇长愿意把东南的荒院租给旅人，可以去找他聊聊。按 M 能看岛图：东面林地与山麓，南面湿地、农庄和古迹；地图只指路，不会把人送过去。"},
}
const PLAZA_OFFSETS := [Vector2(-48, -32), Vector2(0, -48), Vector2(48, -32), Vector2(-64, 16), Vector2(64, 16), Vector2(-40, 56), Vector2(0, 64), Vector2(40, 56), Vector2(0, 120)]
const TRADES := {
	"buy_rice":{"npc":"lin_sui","price":2,"take":{},"give":{"rice":1}},
	"buy_seaweed":{"npc":"zhou_chao","price":2,"take":{},"give":{"seaweed":1}},
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


static func position(npc_id: String, minute: float,data:Dictionary={}) -> Vector2:
	if not NPCS.has(npc_id):
		return Vector2(-10000, -10000)
	return location(npc_id,minute,data).at

static func location(npc_id: String, minute: float,data:Dictionary={}) -> Dictionary:
	if npc_id=="he_mu" and data.get("housing",{}).get("carpenter",false):
		return {"area":"room","room":"raft_cabin","at":Rooms.onward("raft_cabin"),"moving":false,"direction":0,"distance":0.0}
	return Routes.location(npc_id,NPCS[npc_id],minute)


static func residents(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var minute := float(data.get("minute", 360.0))
	for npc_id: String in NPCS:
		var row: Dictionary = NPCS[npc_id].duplicate(true)
		var at := position(npc_id, minute,data)
		var place := location(npc_id,minute,data)
		row.area=place.area;row.room=place.room;row.moving=place.moving;row.direction=place.direction;row.distance=place.distance
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
		result.append_array(PersonalStories.entries(data,"host" if is_same(player,data.players.host) else "guest",npc_id))
		if not open_at(npc_id, float(data.minute)):
			continue
		if npc_id=="he_mu":result.append_array(Housing.choices(data))
		result.append_array(Journal.choices(data,"host" if is_same(player,data.players.host) else "guest",npc_id))
		for offer_id: String in TRADES:
			if TRADES[offer_id].npc == npc_id:
				result.append({"action": "town_trade", "label": _trade_label(data, offer_id), "args": {"id": npc_id, "offer": offer_id}})
		if npc_id=="xu_an" and not data.restaurant.rented:
			result.append({"action":"town_shop","label":"租下旧店 · 30金币 / 木板12","args":{"id":npc_id}})
		if npc_id=="qiao_xin":
			for item:String in Restaurant.SUPPLIES:
				if int(data.restaurant.deliveries.get(item,0))!=int(data.day):result.append({"action":"town_supply","label":"供货 %s ×%d · +%d金币"%[Inventory.ITEM_NAMES[item],Restaurant.SUPPLIES[item].count,Restaurant.SUPPLIES[item].price],"args":{"id":npc_id,"offer":item}})
		if npc_id == "su_qin":
			result.append({"action": "town_treat", "label": "诊疗补给 · 5金币 · 体+60/饱+35/水+35", "args": {"id": npc_id}})
	if Rooms.bathing(player) and open_at("tang_he",float(data.minute)):
		result.append({"action":"town_bath","label":"泡澡8秒 · 3金币 · 体+60/水+20","args":{"id":"tang_he"},"x":player.x,"y":player.y})
	return result


static func action(data: Dictionary, player: Dictionary, verb: String, args: Dictionary, slot: String = "") -> String:
	if verb not in ["town_talk", "town_trade", "town_treat", "town_bath", "town_rent", "town_claim", "town_shop", "town_supply","town_home_repair","town_home_expand","town_invite","town_errand_accept","town_errand_finish","town_gift","town_story_accept","town_story_finish","town_personal_open","town_personal_reply"]:
		return "这里没有这个小镇服务。"
	var keys: Array = ["id", "offer"] if verb in ["town_trade","town_supply"] else ["id"]
	if verb=="town_personal_open":keys=["id","story","step"]
	if verb=="town_personal_reply":keys=["id","story","step","reply"]
	if args.size() != keys.size() or not args.has_all(keys) or not args.get("id") is String or not NPCS.has(args.id):
		return "请选择附近的居民。"
	var npc_id: String = args.id
	if not _actor_ready(player) or (not Rooms.bathing(player) if verb=="town_bath" else not _near(data, player, npc_id)):
		return "请在岛上走近这位居民，再使用服务。"
	var npc: Dictionary = NPCS[npc_id]
	if slot.is_empty():slot="host" if is_same(player,data.players.host) else "guest"
	if verb in ["town_personal_open","town_personal_reply"]:
		if player.get("resting",false) or player.get("sleep_ready",false):return "先起身再聊吧。"
		if not player.get("activity",{}).is_empty() or not player.get("hook",{}).is_empty() or not player.get("fishing",{}).is_empty():return "先完成手上的动作，或右键取消。"
		return str(npc.name)+"："+(PersonalStories.open(data,slot,args) if verb=="town_personal_open" else PersonalStories.action(data,player,slot,args))
	if verb in ["town_rent", "town_claim"]:
		return _homestead(data, player, slot, npc_id, verb)
	if verb == "town_talk":
		var introduction:String=str(npc.talk)
		if npc_id == "xu_an" and data.get("island", {}).get("homestead", {}).get("rented", false):
			introduction="院子在镇公所东南，沿东街向南走，西侧缺口就是入口。那里有淡水。北街的旧店可以卖寿司；愿意经营再来聊，完全由你决定。"
			if not data.island.homestead.claimed[slot]:introduction+="种子、锄头和水壶给你留了一份，其他工具自己做就行。"
		var clock_note := "营业 %s。" % _hours(npc) if open_at(npc_id, float(data.minute)) else "我已收工，营业时间 %s。" % _hours(npc)
		return "%s：%s %s" % [npc.name, Journal.talk(data,slot,npc_id,introduction), clock_note]
	if not open_at(npc_id, float(data.minute)):
		return "%s已经收工，%s再来吧。" % [npc.name, _hours(npc)]
	if not player.get("activity", {}).is_empty() or not player.get("hook", {}).is_empty() or not player.get("fishing", {}).is_empty():
		return "先完成当前动作，或右键取消后再来。"
	if not _money_valid(data.get("money")) or not Inventory.validate_slots(player.get("bag"), Inventory.BAG_SIZE):
		return "物品或金币状态无效，未进行交易。"
	match verb:
		"town_invite":
			if npc_id!="he_mu":return "这次是邀请木匠贺木。"
			if data.housing.carpenter:return "贺木已经住在船屋。"
			if data.housing.cabin.is_empty():return "先用工作台制作船屋套件，在木筏上留出四格宽、两格深的位置搭好。"
			if int(data.journal[slot].friendship.get("he_mu",0))<40:return "贺木：再熟悉一些吧，多来聊聊，或帮我做些委托。好感40后我愿意随船。"
			data.housing.carpenter=true
			return "贺木收拾好工具，住进了筏上的船屋。白天可以在那里交易和委托修屋。"
		"town_errand_accept","town_errand_finish","town_gift","town_story_accept","town_story_finish":
			return Journal.action(data,player,slot,npc_id,verb)
		"town_home_repair","town_home_expand":
			return Housing.commission(data,player,verb) if npc_id=="he_mu" else "房屋工程请找木匠贺木。"
		"town_shop":
			return Restaurant.rent(data,player) if npc_id=="xu_an" else "租店请找许岸镇长。"
		"town_supply":
			return Restaurant.supply(data,player,str(args.offer)) if npc_id=="qiao_xin" and args.offer is String else "供货请找广场邮差乔信。"
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
	if not _actor_ready(player) or _point(player).distance_to(Vector2(float(activity.start_x), float(activity.start_y))) > 8 or not Rooms.bathing(player) or not open_at(str(activity.id), float(data.minute)):
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
	var interior := Rooms.in_pool(start)
	var legacy := start.distance_to(Map.LANDMARKS.bathhouse.door)<=REACH and Map.walkable(start)
	return float(value.duration) == BATH_SECONDS and float(value.remaining) >= 0 and float(value.remaining) <= BATH_SECONDS and (interior or legacy)


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
		"buy_rice":return "购买大米 ×1 · 2金币"
		"buy_seaweed":return "购买海苔 ×1 · 2金币"
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
	return player.get("area") in ["island","room"] and bool(player.get("online", false)) and _finite(player.get("x")) and _finite(player.get("y"))


static func _near(data: Dictionary, player: Dictionary, npc_id: String) -> bool:
	if not _finite(data.get("minute")): return false
	var place := location(npc_id,float(data.minute),data)
	return player.area==place.area and player.get("room","")==place.room and _point(player).distance_to(place.at)<=REACH


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


static func homestead_choices(data: Dictionary, slot: String, npc_id: String) -> Array:
	if npc_id != "xu_an" or slot not in ["host", "guest"]:
		return []
	var home: Dictionary = data.get("island", {}).get("homestead", {})
	if not home.get("rented", false):
		return [{"action": "town_rent", "label": "我想租下这座院子", "args": {"id": npc_id}}]
	if not home.get("claimed", {}).get(slot, false):
		return [{"action": "town_claim", "label": "领取种子、锄头和水壶", "args": {"id": npc_id}}]
	if not data.restaurant.rented:return [{"action":"town_shop","label":"租下北街旧店 · 30金币 + 木板12","args":{"id":npc_id}}]
	return []

static func _homestead(data: Dictionary, player: Dictionary, slot: String, npc_id: String, verb: String) -> String:
	if npc_id != "xu_an" or slot not in ["host", "guest"] or not data.get("players", {}).has(slot):
		return "租院子的事，请找镇长许岸聊聊。"
	if not player.get("activity", {}).is_empty() or not player.get("hook", {}).is_empty() or not player.get("fishing", {}).is_empty():
		return "许岸：先忙完手上的事，我们再聊。"
	var home: Dictionary = data.island.homestead
	if verb == "town_rent":
		if home.rented:
			return "许岸：这院子已经留给你们了，随时可以过去。"
		home.rented = true
		_start_service(player)
		return "许岸：那就交给你们照料了。首期免租，院子里的地慢慢收拾，不着急。每人都有一份当季种子、锄头和水壶，背包空些就来拿。"
	if not home.rented:
		return "许岸：先说好租院子的事，我再把东西交给你。"
	if home.claimed[slot]:
		return "许岸：你的那份已经领过啦。想添种子，可以去找超市的林穗。"
	if not Inventory.validate_slots(player.get("bag"), Inventory.BAG_SIZE):
		return "许岸：背包暂时有些问题，东西先替你保管着。"
	var bag: Array = player.bag.duplicate(true)
	var seed: String = Farming.crop_for_season(int(data.day))
	for item: String in [seed, "hoe", "watering_can"]:
		if Inventory.add(bag, item, 6 if item == seed else 1) != 0:
			return "许岸：包里装不下了，先腾出些位置。这份东西留在我这里，等你回来拿。"
	player.bag = bag
	home.claimed[slot] = true
	_start_service(player)
	return "许岸：给你%s种子六份，还有锄头和水壶。水壶是空的，院子里的水泊就能装水。斧头、镐和镰刀自己做；不必一口气清完整座院子。" % Farming.CROPS[seed].name

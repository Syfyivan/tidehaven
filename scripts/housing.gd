extends RefCounted
const Map=preload("res://scripts/island_map.gd")
const Inventory=preload("res://scripts/inventory.gd")
const SITES:=[Vector2(2192,1536),Vector2(3200,1536),Vector2(2192,2080),Vector2(2384,2080),Vector2(3200,2080)]
const REPAIR:={"wood":30,"stone":12,"fiber":10}
const EXPAND:={"wood":60,"stone":24,"ingot":6}

static func footprint(site:int)->Rect2:
	return Rect2(SITES[site]-Vector2(48,128),Vector2(256,112))

static func site_free(data:Dictionary,site:int)->bool:
	var bounds:=footprint(site).grow(24)
	for key:String in data.get("island",{}).get("plots",{}):
		var parts:=key.split(",")
		if bounds.has_point(Vector2(int(parts[0]),int(parts[1]))*32+Vector2(16,16)):return false
	for chest:Dictionary in data.get("chests",{}).values():
		if chest.get("area")=="island" and bounds.has_point(Vector2(chest.x,chest.y)):return false
	for player:Dictionary in data.get("players",{}).values():
		if player.area=="island" and bounds.has_point(Vector2(player.x,player.y)):return false
	return true

static func create(data:Dictionary)->Dictionary:
	var site:=-1
	for i in SITES.size():
		if site_free(data,i):site=i;break
	return {"site":site,"level":0,"ready_day":0,"target":0,"carpenter":false,"furniture":[],"cabin":{}}

static func bounds(data:Dictionary)->Rect2:
	var site:int=int(data.get("housing",{}).get("site",-1))
	return footprint(site) if site>=0 else Rect2()

static func door(data:Dictionary)->Vector2:
	var site:int=int(data.get("housing",{}).get("site",-1))
	return SITES[site] if site>=0 else Vector2(-999,-999)

static func landmark(data:Dictionary)->Dictionary:
	return {"id":"yard_home","name":"荒院小屋 · "+("施工中" if int(data.housing.ready_day)>0 else "待修复" if int(data.housing.level)==0 else "已扩建" if int(data.housing.level)==2 else "你的家"),"kind":"house","bounds":bounds(data),"door":door(data),"open":true}

static func choices(data:Dictionary)->Array:
	var house:Dictionary=data.housing
	var result:Array=[]
	if not house.carpenter:result.append({"action":"town_invite","label":"邀请贺木住上木筏 · 船屋 / 好感40","args":{"id":"he_mu"}})
	if int(house.ready_day)>0:return result
	if int(house.level)==0:result.append({"action":"town_home_repair","label":"修复荒院小屋 · 木30 / 石12 / 纤维10 · 两夜完工","args":{"id":"he_mu"}})
	elif int(house.level)==1:result.append({"action":"town_home_expand","label":"扩建小屋 · 木60 / 石24 / 金属锭6 · 三夜完工","args":{"id":"he_mu"}})
	return result

static func pay(player:Dictionary,cost:Dictionary)->bool:
	var bag:Array=player.bag.duplicate(true)
	for item:String in cost:
		if Inventory.count(bag,item)<int(cost[item]):return false
		Inventory.remove(bag,item,int(cost[item]))
	player.bag=bag;return true

static func commission(data:Dictionary,player:Dictionary,verb:String)->String:
	var house:Dictionary=data.housing
	if not data.island.homestead.rented:return "先向镇长承租荒院，再来找我修屋。"
	if int(house.ready_day)>0:return "贺木：工程还在进行，%d天后完工。"%maxi(0,int(house.ready_day)-int(data.day))
	var selected_site:int=int(house.site)
	if selected_site<0:
		for i in SITES.size():
			if site_free(data,i):selected_site=i;break
		if selected_site<0:return "院内预留位置都已有农田或箱子，请先清出一处；原有东西不会移动。"
	var expanding:=verb=="town_home_expand"
	if (expanding and int(house.level)!=1) or (not expanding and int(house.level)!=0):return "这项工程已经完成或尚未开放。"
	if not pay(player,EXPAND if expanding else REPAIR):return "随身材料不足，未扣除任何物品。"
	house.site=selected_site
	house.target=2 if expanding else 1
	house.ready_day=int(data.day)+(3 if expanding else 2)
	return "贺木：材料齐了，我会施工%d天；你们照常出海和种地就好。"%(3 if expanding else 2)

static func advance(data:Dictionary)->void:
	var house:Dictionary=data.housing
	if int(house.ready_day)>0 and int(data.day)>=int(house.ready_day):
		house.level=int(house.target);house.ready_day=0;house.target=0

static func restore(value:Variant,day:int)->Dictionary:
	if not value is Dictionary or value.size()!=7 or not value.has_all(["site","level","ready_day","target","carpenter","furniture","cabin"]):return {}
	for key:String in ["site","level","ready_day","target"]:
		var n:Variant=value[key]
		if typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)) or floorf(float(n))!=float(n):return {}
	if value.site < -1 or value.site>=SITES.size() or value.level<0 or value.level>2 or value.target<0 or value.target>2 or value.ready_day<0 or value.ready_day>day+3:return {}
	if (value.ready_day==0 and value.target!=0) or (value.ready_day>0 and (value.target!=value.level+1 or value.ready_day<=day)):return {}
	if value.site<0 and (value.level!=0 or value.target!=0):return {}
	if not value.carpenter is bool or not value.furniture is Array or not value.cabin is Dictionary:return {}
	if value.carpenter and value.cabin.is_empty():return {}
	if not value.cabin.is_empty():
		if value.cabin.size()!=2 or not value.cabin.has_all(["x","y"]):return {}
		for key:String in ["x","y"]:
			var number:Variant=value.cabin[key]
			if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)) or number<0 or number>900 or fposmod(float(number),64)!=32:return {}
	if value.furniture.size()>32:return {}
	for prop in value.furniture:
		if not prop is Dictionary or prop.size()!=6 or not prop.has_all(["id","item","room","x","y","slots"]):return {}
		if not prop.id is String or not prop.id.begins_with("home_") or not prop.id.trim_prefix("home_").is_valid_int() or prop.id.length()>9 or prop.item not in ["bed","chest","workbench"] or prop.room not in ["yard_home","yard_annex","raft_cabin"]:return {}
		if (prop.room.begins_with("yard_") and value.level<1) or (prop.room=="raft_cabin" and value.cabin.is_empty()):return {}
		for key:String in ["x","y"]:
			var number:Variant=prop[key]
			if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)) or number<0 or number>4096 or fposmod(float(number),64)!=32:return {}
		if not Inventory.validate_slots(prop.slots,16 if prop.item=="chest" else 0):return {}
	var result:Dictionary=value.duplicate(true)
	for key:String in ["site","level","ready_day","target"]:result[key]=int(result[key])
	return result

static func cabin_bounds(data:Dictionary)->Rect2:
	var cabin:Dictionary=data.get("housing",{}).get("cabin",{})
	return Rect2(Vector2(cabin.x,cabin.y)-Vector2(160,96),Vector2(256,128)) if not cabin.is_empty() else Rect2()

static func cabin_door(data:Dictionary)->Vector2:
	var cabin:Dictionary=data.housing.cabin
	return Vector2(cabin.x,cabin.y+64) if not cabin.is_empty() else Vector2(-999,-999)

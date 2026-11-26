extends RefCounted
## One definition for scene entrances, collision, exploration, map and host actions.
const Tiles = preload("res://scripts/island_tiles.gd")
const Map = preload("res://scripts/island_map.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Housing=preload("res://scripts/housing.gd")
const SEA_ENTRY := Vector2(820, 480)
const GROTTO_ARCH := Vector2(456, 210)
const REACH := 64.0
const INTERIORS := {
	"island_mist":{"map":"Mountain","name":"雾岬 · 山湖"},
	"island_reef":{"map":"Beach","name":"珊湾 · 潮岸"},
	"island_wind":{"map":"Farm","name":"风栖岛 · 林间旧农庄"},
	"yard_home":{"map":"SamHouse","name":"荒院小屋"},
	"yard_annex":{"map":"Trailer","name":"小屋扩建 · 书房"},
	"raft_cabin":{"map":"Trailer","name":"筏上船屋"},
	"townhall": {"map":"ManorHouse", "name":"潮芽镇公所"},
	"market": {"map":"SeedShop", "name":"潮芽超市"},
	"clinic": {"map":"Hospital", "name":"海风诊所"},
	"bathhouse": {"map":"BathHouse_Pool", "name":"暖泉澡堂"},
	"carpenter": {"map":"ScienceHouse", "name":"木匠工坊"},
	"smith": {"map":"Blacksmith", "name":"炉火铁匠铺"},
	"fishery": {"map":"FishShop", "name":"岸边渔铺"},
	"farmhouse": {"map":"AnimalShop", "name":"苔瓦民居"},
	"east_house": {"map":"SamHouse", "name":"东街民居"},
	"orchard_house": {"map":"Trailer", "name":"榕荫民居"},
	"restaurant": {"map":"Saloon", "name":"潮间寿司屋"},
	"greenhouse": {"map":"Greenhouse", "name":"旧日温室"},
}
static var _geometry: Dictionary = {}
static var _nodes: Dictionary = {}

static func create() -> Dictionary:
	return {"visited":{}, "depleted":{}, "opened":{"sea":1,"mine":1}}

static func valid_id(id: String) -> bool:
	return INTERIORS.has(id) or id in ["sea_1","sea_2","sea_3","reef_grotto","mine_1","mine_2","mine_3"]

static func is_sea_cave(id: String) -> bool:
	return id.begins_with("sea_") or id == "reef_grotto"

static func underwater(player: Dictionary) -> bool:
	return player.get("area") == "water" or (player.get("area") == "room" and is_sea_cave(str(player.get("room", ""))))

static func room_name(id: String) -> String:
	if INTERIORS.has(id): return INTERIORS[id].name
	if id == "reef_grotto": return "潮钟礁洞 · 55米"
	if id.begins_with("sea_"): return "回声海洞 · %d层 · %d米" % [floor_number(id), 40+floor_number(id)*15]
	if id.begins_with("mine_"): return "灰岩矿洞 · 地下%d层" % floor_number(id)
	return ""

static func floor_number(id: String) -> int:
	return 4 if id == "reef_grotto" else int(id.get_slice("_",1))

static func source(id: String) -> String:
	return str(INTERIORS[id].map) if INTERIORS.has(id) else ("Mines/%d" % floor_number(id) if id.begins_with("mine_") else "")

static func size(id: String) -> Vector2:
	if is_sea_cave(id): return Vector2(900,560)
	var map: Dictionary = Tiles.map_data(source(id))
	return Vector2(float(map.width),float(map.height))*32

static func camera(player: Dictionary) -> Vector2:
	var extent := size(str(player.room))
	return Vector2(clampf(float(player.x)-450,0,maxf(0,extent.x-900)),clampf(float(player.y)-280,0,maxf(0,extent.y-560))).floor() - Vector2(maxf(0,900-extent.x)/2,maxf(0,560-extent.y)/2)

static func ceiling(x: float, floor_id: int) -> float:
	return 125 + sin(x/125+floor_id)*22 + sin(x/52)*10

static func seabed(x: float, floor_id: int) -> float:
	return 473 + sin(x/112+floor_id)*25 + sin(x/57)*12

static func can_stand(id: String, at: Vector2) -> bool:
	if not valid_id(id) or not at.is_finite(): return false
	if not Rect2(Vector2.ZERO,size(id)).has_point(at): return false
	if is_sea_cave(id):
		return at.x >= 36 and at.x <= 864 and at.y >= ceiling(at.x,floor_number(id))+28 and at.y <= seabed(at.x,floor_number(id))-24
	var cells: Dictionary = geometry(id).cells
	for offset in [Vector2(-7,-3),Vector2(7,-3),Vector2(-7,4),Vector2(7,4)]:
		if not cells.has(Vector2i((at+offset)/32)): return false
	return true

static func in_pool(at:Vector2)->bool:
	if not can_stand("bathhouse",at):return false
	var map:Dictionary=Tiles.map_data("BathHouse_Pool")
	var cell:=Vector2i(at/32)
	for layer:Dictionary in map.layers:
		if layer.name=="Back":return int(layer.cells[cell.y*int(map.width)+cell.x])==121
	return false

static func bathing(player:Dictionary)->bool:
	return player.get("area")=="room" and player.get("room")=="bathhouse" and in_pool(Vector2(player.x,player.y))

static func clear_step(data:Dictionary,id:String,from:Vector2,to:Vector2)->bool:
	if not can_stand(id,to):return false
	for prop:Dictionary in data.get("housing",{}).get("furniture",[]):
		if prop.room==id:
			var point:=Vector2(prop.x,prop.y)
			if Rect2(point-Vector2(29,29),Vector2(58,58)).has_point(to) and to.distance_squared_to(point)<from.distance_squared_to(point):return false
	for node:Dictionary in nodes(id).values():
		if not active(data,node):continue
		var at:=Vector2(node.x,node.y)
		var solid:=Rect2(at+Vector2(-15,-8),Vector2(30,18))
		if solid.grow(6).has_point(to) and to.distance_squared_to(at)<from.distance_squared_to(at):return false
	return true

static func geometry(id: String) -> Dictionary:
	if _geometry.has(id): return _geometry[id]
	var map: Dictionary = Tiles.map_data(source(id))
	var width := int(map.width)
	var height := int(map.height)
	var back: Array = []
	var buildings: Array = []
	for layer: Dictionary in map.layers:
		if layer.name == "Back": back = layer.cells
		if layer.name == "Buildings": buildings = layer.cells
	var all_cells: Dictionary = {}
	for y in height:
		for x in width:
			var index := y*width+x
			var ground := int(back[index])
			var wall := int(buildings[index]) if not buildings.is_empty() else 0
			# TMX index 0 on the interior sheet is transparent void, not floor.
			if ground <= 1: continue
			if id.begins_with("island_") and Tiles.tile(source(id),ground).properties.has("Water"):continue
			if wall != 0 and not Tiles.tile(source(id),wall).properties.has("Passable"): continue
			all_cells[Vector2i(x,y)] = true
	if id.begins_with("mine_"):
		var unseen := all_cells.duplicate()
		var largest: Dictionary = {}
		while not unseen.is_empty():
			var component := _connected(unseen,unseen.keys()[0])
			for cell in component: unseen.erase(cell)
			if component.size()>largest.size(): largest=component
		all_cells=largest
	var warp: PackedStringArray = str(map.properties.get("Warp", "")).split(" ",false)
	var wanted := Vector2(width*0.5,height-2)*32+Vector2(16,16)
	if warp.size() >= 2 and not id.begins_with("mine_"):
		wanted = Vector2(clampi(int(warp[0]),0,width-1),clampi(int(warp[1]),0,height-1))*32+Vector2(16,16)
	if id.begins_with("mine_"):
		wanted = Vector2(width*16,0)
	if id == "bathhouse": wanted=Vector2(208,112)
	if id=="island_mist":wanted=Vector2(16,31)*32+Vector2(16,16)
	if id=="island_reef":wanted=Vector2(16,26)*32+Vector2(16,16)
	if id=="island_wind":wanted=Vector2(38,58)*32+Vector2(16,16)
	var start := Vector2i.ZERO
	var best := INF
	for cell: Vector2i in all_cells:
		var distance := (Vector2(cell)*32+Vector2(16,16)).distance_squared_to(wanted)
		if distance < best: best = distance; start = cell
	# Only the entry-connected floor is playable. Sealed backdrop rooms stay sealed.
	var cells := {start:true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		for step: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next := current+step
			if all_cells.has(next) and not cells.has(next): cells[next]=true; queue.append(next)
	var spawn := Vector2(start)*32+Vector2(16,16)
	var farthest := spawn
	for cell:Vector2i in queue:
		var safe:=true
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.UP,Vector2i(0,-2)]:
			if not cells.has(cell+offset):safe=false
		if safe:farthest=Vector2(cell)*32+Vector2(16,16)
	_geometry[id] = {"cells":cells,"entry":spawn,"end":farthest,"ordered":queue}
	return _geometry[id]

static func _connected(cells: Dictionary,start: Vector2i) -> Dictionary:
	var result := {start:true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor<queue.size():
		var current: Vector2i = queue[cursor]; cursor+=1
		for step: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next := current+step
			if cells.has(next) and not result.has(next): result[next]=true; queue.append(next)
	return result

static func entry(id: String) -> Vector2:
	return Vector2(80,225) if is_sea_cave(id) else Vector2(geometry(id).entry)

static func onward(id: String) -> Vector2:
	return Vector2(820,310) if is_sea_cave(id) else Vector2(geometry(id).end)

static func nodes(id: String) -> Dictionary:
	if _nodes.has(id): return _nodes[id]
	var result: Dictionary = {}
	if not id.begins_with("sea_") and not id.begins_with("mine_") and not id.begins_with("island_"): return result
	var points: Array[Vector2] = []
	if id.begins_with("sea_"):
		for x in [230,360,490,620,740]: points.append(Vector2(x,seabed(x,floor_number(id))-30))
	else:
		var candidates: Array = geometry(id).ordered
		for cell: Vector2i in candidates:
			var point := Vector2(cell)*32+Vector2(16,16)
			if point.distance_to(entry(id)) < 100 or point.distance_to(onward(id)) < 96: continue
			if points.any(func(other: Vector2):return point.distance_to(other)<110): continue
			points.append(point)
			if points.size() >= (18 if id.begins_with("island_") else 10): break
	for i in points.size():
		var kind := "stone" if i%3 == 0 else "ore"
		var key := "%s:%d" % [id,i]
		result[key] = {"id":key,"room":id,"x":points[i].x,"y":points[i].y,"kind":kind,"amount":floor_number(id)+1,"duration":3.5+floor_number(id)*0.75,"cost":4+floor_number(id)}
		if id.begins_with("island_"):
			kind=str((["ore","stone","ore","mushroom"] if id=="island_mist" else ["treasure","seaweed","wood","fiber"] if id=="island_reef" else ["wood","fiber","mushroom","seed"])[i%4])
			result[key].kind=kind;result[key].amount=1 if kind in ["treasure","seed"] else 3;result[key].duration=5.0 if kind in ["wood","ore","stone"] else 3.0;result[key].cost=4
			result[key].tool={"wood":"axe","ore":"pickaxe","stone":"pickaxe","fiber":"scythe","seed":"hoe"}.get(kind,"")
	_nodes[id] = result
	return result

static func active(data: Dictionary, node: Dictionary) -> bool:
	return int(data.day) >= int(data.rooms.depleted.get(node.id,0))

static func options(data: Dictionary, player: Dictionary) -> Array:
	var result: Array = []
	var at := Vector2(player.x,player.y)
	if player.area=="deck" and not data.housing.cabin.is_empty() and at.distance_to(Housing.cabin_door(data))<=REACH:
		result.append(option("room_enter","进入筏上船屋","raft_cabin",Housing.cabin_door(data)))
	elif player.area == "water" and at.distance_to(SEA_ENTRY)<=REACH:
		result.append(option("room_enter","进入回声海洞 · 深水40米", "sea_1", SEA_ENTRY))
	elif player.area == "island":
		if int(data.get("housing",{}).get("site",-1))>=0 and at.distance_to(Housing.door(data))<=REACH:
			result.append(option("room_enter","查看旧屋 · 请木匠修缮" if int(data.housing.level)==0 else "进入荒院小屋","yard_home",Housing.door(data)))
		for id: String in Map.LANDMARKS:
			if (INTERIORS.has(id) or id == "mine_entrance") and at.distance_to(Map.LANDMARKS[id].door)<=REACH:
				result.append(option("room_enter", "进入"+str(Map.LANDMARKS[id].name), "mine_1" if id=="mine_entrance" else id, Map.LANDMARKS[id].door))
	elif player.area == "room":
		var id := str(player.room)
		if id in ["yard_home","yard_annex","raft_cabin"]:
			result.append(option("rest","在家休息",id,at))
			result.append(option("sleep","准备结束今天",id,at))
		if id=="yard_home" and int(data.housing.level)>=2 and at.distance_to(onward(id))<=REACH:
			result.append(option("room_annex","走进扩建书房","yard_annex",onward(id)))
		if id=="sea_2" and at.distance_to(GROTTO_ARCH)<=REACH:
			result.append(option("room_enter","进入潮钟礁洞 · 55米","reef_grotto",GROTTO_ARCH))
		if at.distance_to(entry(id))<=REACH: result.append(option("room_exit","回到停泊的木筏" if id.begins_with("island_") else "返回上一处",id,entry(id)))
		if (id.begins_with("sea_") or id.begins_with("mine_")) and floor_number(id)<3 and at.distance_to(onward(id))<=REACH:
			result.append(option("room_deeper","前往下一层 · 先开采本层矿脉",id,onward(id)))
		for node: Dictionary in nodes(id).values():
			if active(data,node) and at.distance_to(Vector2(node.x,node.y))<=REACH:
				result.append(option("room_mine","%s · 采集%s · %.1f秒" % [Inventory.ITEM_NAMES.get(str(node.get("tool","pickaxe")),"徒手"),Inventory.ITEM_NAMES[node.kind],node.duration],node.id,Vector2(node.x,node.y)))
	return result

static func option(verb: String,label: String,id: String,at: Vector2) -> Dictionary:
	return {"action":verb,"label":label,"args":{"id":id},"target_x":at.x,"target_y":at.y}

static func action(data: Dictionary, player: Dictionary, verb: String, args: Dictionary) -> String:
	if args.size()!=1 or not args.get("id") is String: return "请选择身边的入口或矿脉。"
	var accepted := false
	for row: Dictionary in options(data,player):
		if row.action==verb and row.args.id==args.id: accepted=true; break
	if not accepted: return "走近入口或矿脉后再操作。"
	if not player.activity.is_empty() or not player.hook.is_empty() or not player.fishing.is_empty(): return "先完成手上的动作，或右键取消。"
	var id := str(args.id)
	if verb == "room_mine":
		var node: Dictionary = nodes(str(player.room))[id]
		var tool:String=str(node.get("tool","pickaxe"))
		if not tool.is_empty() and Inventory.count(player.bag,tool)<1:return "需要随身携带"+str(Inventory.ITEM_NAMES[tool])+"，C打开制作。"
		if float(player.stamina)<float(node.cost): return "体力不足，先回去休息补给。"
		var bag: Array = player.bag.duplicate(true)
		if Inventory.add(bag,node.kind,int(node.amount))!=0: return "背包装不下，矿脉保留原样。"
		player.activity={"kind":"room_mine","id":id,"room":player.room,"duration":node.duration,"remaining":node.duration,"start_x":player.x,"start_y":player.y}
		if tool=="axe":
			var standing:=chopping_stance(data,player,node)
			if not standing.is_finite():player.activity={};return "木枝旁没有可站的位置，请绕到另一侧。"
			player.activity.start_x=standing.x;player.activity.start_y=standing.y
			if standing.distance_to(Vector2(player.x,player.y))>0.1:player.activity.approach=true
		return "开始开采 · 移动或右键取消。"
	if verb=="room_annex":
		_arrive(data,player,"yard_annex")
	elif verb == "room_deeper":
		var family := id.get_slice("_",0)
		if int(data.rooms.opened[family])<=floor_number(id): return "落石挡住了深处，先用石镐开采本层的一处矿脉。"
		_arrive(data,player,"%s_%d" % [family,floor_number(id)+1])
	elif verb == "room_enter":
		if id=="yard_home" and int(data.housing.level)<1:return "旧屋尚不能入住，承租院子后请木匠贺木修复。"
		if id=="greenhouse" and not data.get("gardens",{}).get("greenhouse",false): return "温室年久失修，带齐材料后在门前右键修复。"
		_arrive(data,player,id)
	elif verb == "room_exit":
		if id.begins_with("island_"):return "请从停泊点返回木筏。"
		elif id=="yard_annex":_arrive(data,player,"yard_home",onward("yard_home"))
		elif id=="reef_grotto":_arrive(data,player,"sea_2",GROTTO_ARCH+Vector2(0,26))
		elif id=="raft_cabin":_outside(player,"deck",Housing.cabin_door(data))
		elif id=="yard_home":_outside(player,"island",Housing.door(data))
		elif id.begins_with("sea_") or id.begins_with("mine_"):
			if floor_number(id)>1:
				var previous := "%s_%d" % [id.get_slice("_",0),floor_number(id)-1]
				_arrive(data,player,previous,onward(previous))
			elif id.begins_with("sea_"):
				_outside(player,"water",SEA_ENTRY)
			else: _outside(player,"island",Map.LANDMARKS.mine_entrance.door)
		else: _outside(player,"island",Map.LANDMARKS[id].door)
	return "来到"+room_name(str(player.room)) if player.area=="room" else "已返回海域。" if player.area=="water" else "已回到岛上。"

static func _arrive(data: Dictionary,player: Dictionary,id: String,at: Vector2 = Vector2(-1,-1)) -> void:
	player.area="room"; player.room=id
	var point := entry(id) if at.x<0 else at
	player.x=point.x; player.y=point.y
	player.resting=false; player.sleep_ready=false
	data.rooms.visited[id]=true

static func _outside(player: Dictionary,area: String,at: Vector2) -> void:
	player.area=area; player.room=""; player.x=at.x; player.y=at.y
	player.resting=false; player.sleep_ready=false

static func tick(data: Dictionary, player: Dictionary, delta: float) -> String:
	var work: Dictionary = player.activity
	if work.get("kind")!="room_mine": return ""
	if work.get("approach",false):return ""
	var node: Dictionary = nodes(str(work.room)).get(work.id,{})
	var tool:String=str(node.get("tool","pickaxe"))
	if player.area!="room" or player.room!=work.room or Vector2(player.x,player.y).distance_to(Vector2(work.start_x,work.start_y))>8 or node.is_empty() or not active(data,node) or (not tool.is_empty() and Inventory.count(player.bag,tool)<1):
		player.activity={}; return "开采已中断，未扣物资。"
	work.remaining=maxf(0,float(work.remaining)-delta)
	if float(work.remaining)>0: return ""
	player.activity={}
	if float(player.stamina)<float(node.cost): return "体力不足，矿脉保留。"
	var bag: Array = player.bag.duplicate(true)
	if Inventory.add(bag,node.kind,int(node.amount))!=0: return "背包装不下，矿脉保留。"
	player.bag=bag; player.stamina-=float(node.cost)
	data.rooms.depleted[node.id]=int(data.day)+3
	var family: String = str(player.room).get_slice("_",0)
	if family in ["sea","mine"]:data.rooms.opened[family]=maxi(int(data.rooms.opened[family]),mini(3,floor_number(player.room)+1))
	return "获得%s ×%d%s" % [Inventory.ITEM_NAMES[node.kind],node.amount," · 更深处的通道已疏通。" if family in ["sea","mine"] else "，物资已放进背包。"]

static func chopping_stance(data:Dictionary,player:Dictionary,node:Dictionary)->Vector2:
	var from:=Vector2(player.x,player.y)
	var candidates:Array[Vector2]=[]
	for direction in 4:candidates.append(preload("res://scripts/tool_motion.gd").stance(Vector2(node.x,node.y),direction,"wood"))
	candidates.sort_custom(func(a:Vector2,b:Vector2):return from.distance_squared_to(a)<from.distance_squared_to(b))
	for at in candidates:
		if from.distance_to(at)>96 or not can_stand(player.room,at):continue
		var clear:=true;var prior:=from;var steps:=maxi(1,ceili(from.distance_to(at)/4))
		for i in range(1,steps+1):
			var next:=from.lerp(at,float(i)/steps)
			if not clear_step(data,player.room,prior,next):clear=false;break
			prior=next
		if clear:return at
	return Vector2(INF,INF)

static func valid_activity(value: Variant) -> bool:
	if not value is Dictionary or value.size() not in [7,8] or value.get("kind")!="room_mine" or not value.get("room") is String or not valid_id(value.room) or not value.get("id") is String: return false
	var node: Dictionary = nodes(value.room).get(value.id,{})
	if node.is_empty(): return false
	if value.size()==8 and (not value.get("approach") is bool or not value.approach or node.get("tool")!="axe" or value.remaining!=value.duration):return false
	for key in ["duration","remaining","start_x","start_y"]:
		if typeof(value.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value[key])): return false
	return float(value.duration)==float(node.duration) and float(value.remaining)>=0 and float(value.remaining)<=float(node.duration) and can_stand(value.room,Vector2(value.start_x,value.start_y)) and Vector2(value.start_x,value.start_y).distance_to(Vector2(node.x,node.y))<=REACH

static func restore(value: Variant, day: int) -> Dictionary:
	if not value is Dictionary or value.size()!=3 or not value.get("visited") is Dictionary or not value.get("depleted") is Dictionary or not value.get("opened") is Dictionary: return {}
	if value.opened.size()!=2: return {}
	for family in ["sea","mine"]:
		if typeof(value.opened.get(family)) not in [TYPE_INT,TYPE_FLOAT] or float(value.opened[family])!=floorf(float(value.opened[family])) or float(value.opened[family])<1 or float(value.opened[family])>3: return {}
	for id in value.visited:
		if not id is String or not valid_id(id) or value.visited[id]!=true: return {}
	for id in value.depleted:
		if not id is String or id.split(":").size()!=2 or not valid_id(id.get_slice(":",0)) or not nodes(id.get_slice(":",0)).has(id): return {}
		var deadline: Variant = value.depleted[id]
		if typeof(deadline) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(deadline)) or float(deadline)!=floorf(float(deadline)) or float(deadline)<1 or float(deadline)>day+3: return {}
	# JSON parses every number as float. Restore validated discrete progress to
	# its native type, as the other save readers do; never round invalid input.
	var result:Dictionary=value.duplicate(true)
	for family in result.opened:result.opened[family]=int(result.opened[family])
	for id in result.depleted:result.depleted[id]=int(result.depleted[id])
	return result

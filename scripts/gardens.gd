extends RefCounted
const Farming=preload("res://scripts/farming.gd")
const Inventory=preload("res://scripts/inventory.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Map=preload("res://scripts/island_map.gd")
const SOIL:=Rect2i(4,10,12,10)
const TAP:=Vector2(352,208)
const REPAIR:={"wood":20,"ingot":4,"plastic":12}

static func create()->Dictionary:
	return {"planters":{},"greenhouse":false,"plots":{},"legacy":""}

static func add_planter(data:Dictionary,id:String)->void:
	data.gardens.planters[id]=Farming.new_plot()

static func target(data:Dictionary,player:Dictionary,point:Vector2)->String:
	if player.area=="deck":
		for id:String in data.structures:
			var structure:Dictionary=data.structures[id]
			if structure.kind=="garden" and point.distance_to(Vector2(structure.x,structure.y))<=32:return id
	elif player.area=="room" and player.room=="greenhouse" and SOIL.has_point(Vector2i((point/32).floor())):
		return "%d,%d" % [floori(point.x/32),floori(point.y/32)]
	return ""

static func center(data:Dictionary,player:Dictionary,key:String)->Vector2:
	return Vector2(data.structures[key].x,data.structures[key].y) if player.area=="deck" else Farming.plot_center(key)

static func action(data:Dictionary,player:Dictionary,verb:String,args:Dictionary)->String:
	if verb=="repair_greenhouse":
		if not args.is_empty() or player.area!="island" or Vector2(player.x,player.y).distance_to(Map.LANDMARKS.greenhouse.door)>64:return "走到旧日温室门前再修复。"
		if data.gardens.greenhouse:return "温室已经修好了。"
		var bag:Array=player.bag.duplicate(true)
		for item:String in REPAIR:
			if not Inventory.remove(bag,item,int(REPAIR[item])):return "修复温室需要木板20、金属锭4、塑料12，随身带齐再来。"
		player.bag=bag;data.gardens.greenhouse=true
		return "温室修好了 · 室内土地需自己开垦，四季都可种植；北侧水槽装水。"
	if verb=="refill_can" and player.area=="deck":
		if not args.is_empty():return "请选择水壶装水。"
		if Inventory.count(player.bag,"watering_can")<1:return "需要随身携带浇水壶。"
		if int(player.can_water)>=20:return "水壶已经满了。"
		var bag:Array=player.bag.duplicate(true)
		if not Inventory.remove(bag,"freshwater",1) or Inventory.add(bag,"cup",1)!=0:return "用一杯淡水补充10格水；需要空格放回空杯。"
		player.bag=bag;player.can_water=mini(20,int(player.can_water)+10)
		return "一杯淡水装入水壶 · 水量 %d/20。" % int(player.can_water)
	var keys:Array=["x","y"]
	if verb=="plant":keys.append("seed")
	if args.size()!=keys.size() or not args.has_all(keys):return "请选择身边的种植格。"
	for coordinate in [args.x,args.y]:
		if typeof(coordinate) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(coordinate)):return "坐标无效。"
	var point:=Vector2(args.x,args.y)
	var at:=Vector2(player.x,player.y)
	if player.area=="room" and player.room=="greenhouse" and data.gardens.greenhouse and verb=="refill_can":
		if point.distance_to(TAP)>48 or at.distance_to(TAP)>64:return "靠近北侧水槽装水。"
		if Inventory.count(player.bag,"watering_can")<1:return "需要浇水壶。"
		player.can_water=20;return "水壶装满了 · 20格水。"
	var key:=target(data,player,point)
	if key=="":return "选择甲板种植箱或温室里的土地。"
	if at.distance_to(center(data,player,key))>64:return "走近这格地再操作。"
	if not player.activity.is_empty():return "先完成手上的动作，或右键取消。"
	var plots:Dictionary=data.gardens.planters if player.area=="deck" else data.gardens.plots
	if player.area=="room" and not data.gardens.greenhouse:return "温室还没修好。"
	if verb=="till":
		if plots.has(key):return "这里已经可以种植。"
		if Inventory.count(player.bag,"hoe")<1:return "需要锄头。"
		var plot:=Farming.new_plot();plot.covered=true;plots[key]=plot
		return "温室开垦了一格 · 可跨季种植，仍需每天浇水。"
	if not plots.has(key):return "先拿锄头开垦一格。"
	if verb=="harvest" and player.area=="deck" and data.gardens.legacy==key:
		if not Farming.mature(plots[key]):return "作物还没有成熟。"
		var bag:Array=player.bag.duplicate(true)
		if Inventory.add(bag,"veg",3)!=0 or Inventory.add(bag,"seed",1)!=0:return "背包装不下全部收获，作物留在盆里。"
		player.bag=bag;plots[key]=Farming.new_plot();data.gardens.legacy=""
		return "收获蔬菜×3、种子×1。"
	return Farming.tend(data,player,plots[key],verb,args)

static func options(data:Dictionary,player:Dictionary)->Array:
	var result:Array=[]
	var at:=Vector2(player.x,player.y)
	if player.area=="island" and not data.gardens.greenhouse and at.distance_to(Map.LANDMARKS.greenhouse.door)<=64:
		result.append({"action":"repair_greenhouse","label":"修复温室 · 木板20 / 锭4 / 塑料12","args":{},"target_x":Map.LANDMARKS.greenhouse.door.x,"target_y":Map.LANDMARKS.greenhouse.door.y})
	var plots:Dictionary={}
	if player.area=="deck":
		plots=data.gardens.planters
		if Inventory.count(player.bag,"watering_can")>0 and Inventory.count(player.bag,"freshwater")>0 and int(player.can_water)<20:
			result.append({"action":"refill_can","label":"用一杯淡水补充水壶 · 10格","args":{}})
	elif player.area=="room" and player.room=="greenhouse":
		plots=data.gardens.plots
		if at.distance_to(TAP)<=64:result.append({"action":"refill_can","label":"水槽 · 装满水壶","args":{"x":TAP.x,"y":TAP.y},"target_x":TAP.x,"target_y":TAP.y})
	for key:String in plots:
		var point:=center(data,player,key)
		if at.distance_to(point)>64:continue
		var plot:Dictionary=plots[key]
		if Farming.mature(plot) or plot.dead:
			result.append({"action":"clear_crop" if plot.dead else "harvest","label":"清理枯株 · 镰刀" if plot.dead else "收获"+str(Farming.CROPS[plot.crop].name),"args":{"x":point.x,"y":point.y},"target_x":point.x,"target_y":point.y})
	return result

static func advance_day(data:Dictionary)->void:
	for plots:Dictionary in [data.gardens.planters,data.gardens.plots]:Farming.advance_day({"plots":plots},int(data.day),int(data.day)+1)

static func migrate(structures:Dictionary,crop:Dictionary)->Dictionary:
	var result:=create()
	var ids:Array=structures.keys();ids.sort()
	var transferred:=false
	for id:String in ids:
		if structures[id].kind!="garden":continue
		var plot:=Farming.new_plot()
		if not transferred and int(crop.stage)>0:
			plot.crop="seed";plot.growth=4 if int(crop.stage)==2 else 3
			plot.watered=bool(crop.watered);plot.covered=true
			result.legacy=id
			transferred=true
		result.planters[id]=plot
	return result

static func restore(value:Variant,structures:Dictionary)->Dictionary:
	if not value is Dictionary or value.size()!=4 or not value.get("legacy") is String or not value.get("greenhouse") is bool or not value.get("plots") is Dictionary or not value.get("planters") is Dictionary:return {}
	var expected:Array=[]
	for id:String in structures:
		if structures[id].kind=="garden":expected.append(id)
	if value.planters.size()!=expected.size():return {}
	for id:String in expected:
		if Farming.restore_plot(value.planters.get(id))==null:return {}
	if value.legacy!="" and (not value.planters.has(value.legacy) or value.planters[value.legacy].crop!="seed" or not value.planters[value.legacy].covered):return {}
	if not value.greenhouse and not value.plots.is_empty():return {}
	for key in value.plots:
		if not key is String or Farming.restore_plot(value.plots[key])==null or not bool(value.plots[key].covered):return {}
		var point:=Farming.plot_center(key)
		if not SOIL.has_point(Vector2i((point/32).floor())):return {}
	var result:Dictionary=value.duplicate(true)
	for plots:Dictionary in [result.planters,result.plots]:
		for id:String in plots:plots[id]=Farming.restore_plot(plots[id])
	return result

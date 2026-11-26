extends RefCounted
const Rooms=preload("res://scripts/rooms.gd")
const Housing=preload("res://scripts/housing.gd")
const Inventory=preload("res://scripts/inventory.gd")
const OWN_ROOMS:=["yard_home","yard_annex","raft_cabin"]

static func furniture(data:Dictionary,id:String)->Dictionary:
	for item:Dictionary in data.housing.furniture:
		if item.id==id:return item
	return {}

static func access(data:Dictionary,player:Dictionary,id:String)->bool:
	var item:=furniture(data,id)
	return not item.is_empty() and player.area=="room" and player.room==item.room and Vector2(player.x,player.y).distance_to(Vector2(item.x,item.y))<=64

static func placement_reason(data:Dictionary,player:Dictionary,item:String,at:Vector2)->String:
	if player.area!="room" or player.room not in OWN_ROOMS:return "家具放在自家的小屋或筏上船屋里。"
	if item not in ["bed","chest","workbench"]:return "屋内可以摆放床、木箱和工作台。"
	if not at.is_finite() or not at.is_equal_approx((at/64).floor()*64+Vector2(32,32)):return "请对齐室内的家具格。"
	if Vector2(player.x,player.y).distance_to(at)>96:return "走近一些再放置。"
	if data.housing.furniture.size()>=32:return "现有家具已满，请先收起一件。"
	for dx in [-23,23]:
		for dy in [-23,23]:
			if not Rooms.can_stand(player.room,at+Vector2(dx,dy)):return "这里有墙或原有家具，请选择空地。"
	var blocked:Dictionary={}
	for prop:Dictionary in data.housing.furniture:
		if prop.room==player.room:
			if Vector2(prop.x,prop.y).distance_to(at)<64:return "这里已有家具。"
			_block(blocked,Vector2(prop.x,prop.y))
	_block(blocked,at)
	var cells:Dictionary=Rooms.geometry(player.room).cells.duplicate()
	for cell in blocked:cells.erase(cell)
	var entry:=Vector2i(Rooms.entry(player.room)/32)
	if not cells.has(entry):return "给房门留出通路。"
	var reachable:=Rooms._connected(cells,entry)
	if reachable.size()!=cells.size():return "家具会切断走道，请留出通路。"
	if not reachable.has(Vector2i(Rooms.onward(player.room)/32)):return "请留出通往里屋的路。"
	for other:Dictionary in data.players.values():
		if other.online and other.area=="room" and other.room==player.room and not reachable.has(Vector2i(Vector2(other.x,other.y)/32)):return "这里有人，等空出来再放置。"
	return ""

static func _block(cells:Dictionary,at:Vector2)->void:
	for dx in [-16,16]:
		for dy in [-16,16]:cells[Vector2i((at+Vector2(dx,dy))/32)]=true

static func place(data:Dictionary,player:Dictionary,item:String,at:Vector2)->void:
	var n:=0
	while not furniture(data,"home_%d"%n).is_empty():n+=1
	data.housing.furniture.append({"id":"home_%d"%n,"item":item,"room":str(player.room),"x":at.x,"y":at.y,"slots":Inventory.empty_slots(16) if item=="chest" else []})

static func options(data:Dictionary,player:Dictionary)->Array:
	var result:Array=[]
	if player.area!="room" or player.room not in OWN_ROOMS:return result
	for prop:Dictionary in data.housing.furniture:
		if not access(data,player,prop.id):continue
		if prop.item=="chest":result.append(Rooms.option("open_chest","打开家中木箱",prop.id,Vector2(prop.x,prop.y)))
		result.append(Rooms.option("home_pack","收起"+str(Inventory.ITEM_NAMES[prop.item]),prop.id,Vector2(prop.x,prop.y)))
	return result

static func pack(data:Dictionary,player:Dictionary,args:Dictionary)->String:
	if args.size()!=1 or not args.get("id") is String or not access(data,player,args.id):return "走近自己的家具再收起。"
	var prop:=furniture(data,args.id)
	if prop.item=="chest" and Inventory.used(prop.slots)>0:return "先取出木箱里的东西再收起。"
	var bag:Array=player.bag.duplicate(true)
	if Inventory.add(bag,prop.item,1)!=0:return "背包放不下，家具留在原处。"
	player.bag=bag;data.housing.furniture.erase(prop)
	return "家具收回背包，可重新选择位置放下。"

static func validate(data:Dictionary)->bool:
	var copy:Dictionary=data.duplicate(true)
	copy.housing.furniture=[]
	for person:Dictionary in copy.players.values():person.online=false
	for prop:Dictionary in data.housing.furniture:
		var actor:={"area":"room","room":prop.room,"x":prop.x,"y":prop.y}
		if not placement_reason(copy,actor,prop.item,Vector2(prop.x,prop.y)).is_empty():return false
		copy.housing.furniture.append(prop.duplicate(true))
	var bounds:=Housing.bounds(data).grow(16)
	if int(data.housing.site)>=0:
		for key:String in data.island.plots:
			var xy:=key.split(",")
			if bounds.has_point(Vector2(int(xy[0]),int(xy[1]))*32+Vector2(16,16)):return false
		for chest:Dictionary in data.chests.values():
			if chest.get("area")=="island" and bounds.has_point(Vector2(chest.x,chest.y)):return false
	var ids:Dictionary={}
	for prop:Dictionary in data.housing.furniture:
		if ids.has(prop.id) or prop.room not in OWN_ROOMS or not Rooms.can_stand(prop.room,Vector2(prop.x,prop.y)):return false
		if prop.room=="yard_annex" and int(data.housing.level)<2:return false
		if prop.room=="raft_cabin" and data.housing.cabin.is_empty():return false
		ids[prop.id]=true
	for player:Dictionary in data.players.values():
		if player.area=="room":
			if player.room=="yard_home" and data.housing.level<1:return false
			if player.room=="yard_annex" and data.housing.level<2:return false
			if player.room=="raft_cabin" and data.housing.cabin.is_empty():return false
	if not data.housing.cabin.is_empty():
		copy=data.duplicate(true);copy.housing.cabin={}
		var at:=Vector2(data.housing.cabin.x,data.housing.cabin.y)
		if not cabin_reason(copy,{"area":"deck","x":at.x,"y":at.y},at,false).is_empty():return false
	return true

static func cabin_reason(data:Dictionary,player:Dictionary,at:Vector2,check_reach:=true)->String:
	if player.area!="deck":return "船屋要搭在扩建后的甲板上。"
	if not data.housing.cabin.is_empty():return "木筏上已经有一间船屋。"
	if not at.is_finite() or not at.is_equal_approx((at/64).floor()*64+Vector2(32,32)):return "请对齐甲板格。"
	if check_reach and Vector2(player.x,player.y).distance_to(at)>192:return "走近这片甲板再搭船屋。"
	var cells:Dictionary={}
	for key:String in data.deck_tiles:cells[key]=true
	var blocked:Dictionary={}
	for dx in [-2,-1,0,1]:
		for dy in [-1,0]:
			var key:="%d,%d"%[int(at.x/64)+dx,int(at.y/64)+dy]
			if not cells.has(key):return "需要四格宽、两格深的完整甲板。"
			blocked[key]=true
	for objects:Dictionary in [data.structures,data.chests]:
		for object:Dictionary in objects.values():
			if object.get("area","deck")!="deck":continue
			var key:="%d,%d"%[int(object.x/64),int(object.y/64)]
			if blocked.has(key):return "先搬开这片甲板上的设施。"
			cells.erase(key)
	for key:String in blocked:cells.erase(key)
	var entry:=Vector2i(int(at.x/64),int(at.y/64)+1)
	if not cells.has("%d,%d"%[entry.x,entry.y]):return "门前还要一格空甲板。"
	var cell_vectors:Dictionary={}
	for key:String in cells:
		var xy:=key.split(",");cell_vectors[Vector2i(int(xy[0]),int(xy[1]))]=true
	if Rooms._connected(cell_vectors,entry).size()!=cells.size():return "船屋会挡住走道，请扩出绕屋的通路。"
	for other:Dictionary in data.players.values():
		if other.online and other.area=="deck" and blocked.has("%d,%d"%[int(other.x/64),int(other.y/64)]):return "有人站在施工位置，先让出空地。"
	return ""

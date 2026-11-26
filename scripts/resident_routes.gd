extends RefCounted
## Read-only deterministic daily travel, shared by interaction, drawing and maps.
const Map=preload("res://scripts/island_map.gd")
const Rooms=preload("res://scripts/rooms.gd")
const WALK_PER_MINUTE:=18.0
static var _street_cells:Dictionary={}
static var _paths:Dictionary={}
static var _journeys:Dictionary={}

static func street_cells()->Dictionary:
	if not _street_cells.is_empty():return _street_cells
	for y in range(2,79):
		for x in range(20,111):
			var at:=Vector2(x*32+16,y*32+16)
			if Map.terrain(at) in ["path","bridge"] and Map.can_stand(at):_street_cells[Vector2i(x,y)]=true
	return _street_cells

static func nearest(cells:Dictionary,point:Vector2)->Vector2i:
	var best:=INF
	var result:=Vector2i.ZERO
	for cell:Vector2i in cells:
		var gap:float=(Vector2(cell)*32+Vector2(16,16)).distance_squared_to(point)
		if gap<best:best=gap;result=cell
	return result

static func path(room:String,from:Vector2,to:Vector2)->PackedVector2Array:
	var key:=room+str(from)+str(to)
	if _paths.has(key):return _paths[key]
	var cells:Dictionary=street_cells() if room.is_empty() else Rooms.geometry(room).cells
	var start:=nearest(cells,from)
	var end:=nearest(cells,to)
	var parents:Dictionary={start:start}
	var queue:Array[Vector2i]=[start]
	var cursor:=0
	while cursor<queue.size() and not parents.has(end):
		var current:Vector2i=queue[cursor];cursor+=1
		for step:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:=current+step
			if cells.has(next) and not parents.has(next):parents[next]=current;queue.append(next)
	var points:=PackedVector2Array()
	if not parents.has(end):
		push_error("Resident route disconnected: "+key)
		return points
	var cell:=end
	while cell!=start:points.append(Vector2(cell)*32+Vector2(16,16));cell=parents[cell]
	points.append(Vector2(start)*32+Vector2(16,16));points.reverse()
	points.insert(0,from);points.append(to)
	_paths[key]=points
	return points

static func place(room:String,wanted:Vector2)->Vector2:
	return Vector2(nearest(Rooms.geometry(room).cells,wanted))*32+Vector2(16,16)

static func home(id:String,npc:Dictionary)->String:
	return str(npc.get("home", "east_house" if int(npc.variant)%2==0 else "orchard_house"))

static func work_room(npc:Dictionary)->String:
	return str(npc.landmark) if Rooms.INTERIORS.has(str(npc.landmark)) else ""

static func work_point(npc:Dictionary)->Vector2:
	var room:=work_room(npc)
	if room.is_empty():
		if npc.has("work_at"):return Vector2(nearest(street_cells(),npc.work_at))*32+Vector2(16,16)
		return Map.LANDMARKS[npc.landmark].door+Vector2((int(npc.variant)%3-1)*32,32)
	# Shared shops keep separate work spots; the same connected floor defines routes and maps.
	if npc.has("work_at"):return place(room,npc.work_at)
	var desired:Vector2={"townhall":Vector2(240,272),"market":Vector2(144,656),"clinic":Vector2(80,528),"bathhouse":Vector2(400,240),"carpenter":Vector2(208,656),"smith":Vector2(336,464),"fishery":Vector2(144,208),"farmhouse":Vector2(496,464),"restaurant":Vector2(720,592)}.get(room,Rooms.entry(room)+Vector2(0,-96))
	if int(npc.variant)>=9:desired+=Vector2((int(npc.variant)%2)*64,64)
	return place(room,desired)

static func home_point(id:String,npc:Dictionary)->Vector2:
	var room:=home(id,npc)
	var cells:Array=Rooms.geometry(room).ordered
	return Vector2(cells[posmod(6+int(npc.variant)*7,cells.size())])*32+Vector2(16,16)

static func _leg(room:String,from:Vector2,to:Vector2)->Dictionary:
	var points:=path(room,from,to)
	var length:=0.0
	for i in range(1,points.size()):length+=points[i-1].distance_to(points[i])
	return {"room":room,"points":points,"duration":maxf(0.01,length/WALK_PER_MINUTE)}

static func journeys(id:String,npc:Dictionary)->Dictionary:
	if _journeys.has(id):return _journeys[id]
	var home_room:=home(id,npc)
	var work:=work_room(npc)
	var home_door:Vector2=Map.LANDMARKS[home_room].door
	var work_door:Vector2=Map.LANDMARKS[npc.landmark].door
	var plaza:Vector2=Map.LANDMARKS.plaza.door+Vector2((int(npc.variant)%5-2)*32,(int(npc.variant)/5)*32)
	var morning:Array=[_leg(home_room,home_point(id,npc),Rooms.entry(home_room)),_leg("",home_door,work_door)]
	if not work.is_empty():morning.append(_leg(work,Rooms.entry(work),work_point(npc)))
	else:morning.append(_leg("",work_door,work_point(npc)))
	var evening:Array=[]
	if not work.is_empty():evening.append(_leg(work,work_point(npc),Rooms.entry(work)))
	else:evening.append(_leg("",work_point(npc),work_door))
	evening.append(_leg("",work_door,plaza))
	var homeward:Array=[_leg("",plaza,home_door),_leg(home_room,Rooms.entry(home_room),home_point(id,npc))]
	_journeys[id]={"morning":morning,"evening":evening,"homeward":homeward,"plaza":plaza}
	return _journeys[id]

static func duration(legs:Array)->float:
	var result:=0.0
	for leg:Dictionary in legs:result+=float(leg.duration)
	return result

static func stationary(room:String,point:Vector2)->Dictionary:
	return {"area":"island" if room.is_empty() else "room","room":room,"at":point,"moving":false,"direction":0,"distance":0.0}

static func travel(legs:Array,elapsed:float)->Dictionary:
	for leg:Dictionary in legs:
		if elapsed>float(leg.duration):elapsed-=float(leg.duration);continue
		var distance:=elapsed*WALK_PER_MINUTE
		var points:PackedVector2Array=leg.points
		for i in range(1,points.size()):
			var span:=points[i-1].distance_to(points[i])
			if distance>span:distance-=span;continue
			var direction:=points[i]-points[i-1]
			var result:=stationary(leg.room,points[i-1].lerp(points[i],distance/maxf(0.001,span)))
			result.moving=true;result.distance=elapsed*WALK_PER_MINUTE
			result.direction=(2 if direction.x>0 else 1) if absf(direction.x)>absf(direction.y) else (0 if direction.y>0 else 3)
			return result
	var last:Dictionary=legs[-1]
	return stationary(last.room,last.points[-1])

static func location(id:String,npc:Dictionary,minute:float)->Dictionary:
	var plan:=journeys(id,npc)
	var clock:=fposmod(minute,1440)
	var start:=float(npc.start)-duration(plan.morning)
	if clock<start:return stationary(home(id,npc),home_point(id,npc))
	if clock<float(npc.start):return travel(plan.morning,clock-start)
	if clock<float(npc.end):return stationary(work_room(npc),work_point(npc))
	var home_time:=float(npc.end)+duration(plan.evening)+60
	if clock<float(npc.end)+duration(plan.evening):return travel(plan.evening,clock-float(npc.end))
	if clock<home_time:return stationary("",plan.plaza)
	if clock<home_time+duration(plan.homeward):return travel(plan.homeward,clock-home_time)
	return stationary(home(id,npc),home_point(id,npc))

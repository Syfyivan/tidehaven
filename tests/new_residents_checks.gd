extends SceneTree
## Four distinct original resident bodies and real routes through existing shops.
const Town=preload("res://scripts/island_town.gd")
const Routes=preload("res://scripts/resident_routes.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Map=preload("res://scripts/island_map.gd")
const Art=preload("res://scripts/character_art.gd")
const NEW_RESIDENTS:={"lu_zhou":"Alex.png","mu_tong":"Leah.png","gu_xing":"Maru.png","xu_mian":"Emily.png"}
var checks:=0
var failures:=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func clear_leg(leg:Dictionary)->bool:
	var points:PackedVector2Array=leg.points
	if points.size()<2:return false
	for i in range(1,points.size()):
		var steps:int=maxi(1,ceili(points[i-1].distance_to(points[i])/4))
		for j in range(steps+1):
			var at:Vector2=points[i-1].lerp(points[i],float(j)/steps)
			if not (Map.can_stand(at) if str(leg.room).is_empty() else Rooms.can_stand(str(leg.room),at)):return false
	return true

func _initialize()->void:
	check(Town.NPCS.size()==18 and Art.NPC_SHEETS.size()==18,"18 registered town residents with complete original sheets")
	check(Art.WORLD_SIZE==Vector2(32,64) and Art.FOOT_OFFSET==Vector2(16,62),"all adults keep the existing world scale and fixed foot")
	var sources:Dictionary={}
	var homes:Dictionary={}
	for id:String in Town.NPCS:
		var npc:Dictionary=Town.NPCS[id]
		var sheet:Texture2D=Art.NPC_SHEETS[id]
		check(not sources.has(sheet.resource_path),"independent original body for "+id)
		sources[sheet.resource_path]=true
		var home_key:String=Routes.home(id,npc)+str(Routes.home_point(id,npc))
		check(not homes.has(home_key),"separate resting place for "+id)
		homes[home_key]=true
	for id:String in NEW_RESIDENTS:
		var npc:Dictionary=Town.NPCS[id]
		var room:String=Routes.work_room(npc)
		var work:Vector2=Routes.work_point(npc)
		check(Art.NPC_SHEETS[id].resource_path.ends_with(NEW_RESIDENTS[id]),"pinned complete source assigned to "+id)
		check(Rooms.can_stand(room,work),id+" stands on connected shop floor")
		for other_id:String in Town.NPCS:
			if other_id==id:continue
			var other:Dictionary=Town.NPCS[other_id]
			if Routes.work_room(other)==room:check(work.distance_to(Routes.work_point(other))>=32,id+" does not overlap "+other_id)
		for direction in range(4):
			for frame in range(4):
				var texture:Texture2D=Art.npc_texture(id,direction,frame)
				check(texture.get_size()==Vector2(16,32) and not texture.get_image().is_invisible(),"%s normal direction %d frame %d"%[id,direction,frame])
		var journeys:Dictionary=Routes.journeys(id,npc)
		for journey:String in ["morning","evening","homeward"]:
			for leg:Dictionary in journeys[journey]:check(clear_leg(leg),id+" avoids wall and water on "+journey+" / "+str(leg.room))
		check(Town.open_at(id,float(npc.start)) and not Town.open_at(id,float(npc.end)),id+" respects real work hours")
		check(Town.location(id,float(npc.start)).at==work,id+" has reached the actual workplace at opening")
		check(Town.location(id,float(npc.end)+0.01).moving,id+" walks away after work")
		var data:Dictionary={"minute":float(npc.start),"housing":{}}
		var before:Dictionary=data.duplicate(true)
		var residents:Dictionary=Town.residents(data)
		check(Vector2(residents[id].x,residents[id].y)==work and residents[id].room==room,id+" shared render/map/interaction position")
		check(data==before,id+" routes are deterministic read-only views")
	print("NEW RESIDENTS: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)

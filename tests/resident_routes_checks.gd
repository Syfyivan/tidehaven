extends SceneTree
const Town=preload("res://scripts/island_town.gd")
const Routes=preload("res://scripts/resident_routes.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Map=preload("res://scripts/island_map.gd")
const World=preload("res://scripts/world_state.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	for id:String in Town.NPCS:
		var npc:Dictionary=Town.NPCS[id]
		var journeys:=Routes.journeys(id,npc)
		for kind in ["morning","evening","homeward"]:
			for leg:Dictionary in journeys[kind]:
				check(leg.points.size()>0,id+" connected "+kind)
				var all_clear:=true
				for i in range(1,leg.points.size()):
					var from:Vector2=leg.points[i-1];var to:Vector2=leg.points[i]
					for j in maxi(1,ceili(from.distance_to(to)/4)):
						var at:=from.lerp(to,float(j)/maxi(1,ceili(from.distance_to(to)/4)))
						all_clear=all_clear and (Map.can_stand(at) if leg.room=="" else Rooms.can_stand(leg.room,at))
				check(all_clear,id+" no wall/water crossing "+kind+" "+str(leg.room))
		var opening:=Town.location(id,float(npc.start))
		check(opening.room==Routes.work_room(npc),id+" work room at opening")
		check(Town.open_at(id,float(npc.start)) and not Town.open_at(id,float(npc.end)),id+" hours boundaries")
		var morning:=Town.location(id,float(npc.start)-1)
		check(morning.moving,id+" approaches workplace before opening")
	var w=World.new();w.join("host","船长");w.data.minute=720
	var p:Dictionary=w.data.players.host
	var place:=Town.location("su_qin",720)
	Rooms._arrive(w.data,p,place.room,place.at)
	w.data.money=50;p.stamina=10
	check(w.action("host","town_treat",{"id":"su_qin"}).contains("补给"),"clinic treatment inside")
	check(p.stamina==70 and w.data.money==45,"treatment consumes once")
	p.area="island";p.room=""
	check(not w.action("host","town_treat",{"id":"su_qin"}).contains("苏芩为你"),"same coordinate on island cannot access indoor service")
	print("RESIDENT ROUTES: %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)

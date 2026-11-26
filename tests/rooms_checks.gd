extends SceneTree
const World = preload("res://scripts/world_state.gd")
const Rooms = preload("res://scripts/rooms.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Map = preload("res://scripts/island_map.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL ",label)
func _initialize()->void:
	for id in Array(Rooms.INTERIORS.keys())+["mine_1","mine_2","mine_3"]:
		var geom:=Rooms.geometry(id)
		print(id," floor cells=",geom.cells.size()," entry=",geom.entry," end=",geom.end)
		check(geom.cells.size()>20,id+" has connected playable floor")
		check(Rooms.can_stand(id,Rooms.entry(id)),id+" entry stands inside floor")
		check(Rooms.can_stand(id,Rooms.onward(id)),id+" depth exit reachable in same component")
		check(not Rooms.can_stand(id,Vector2(-1,-1)),id+" void collision")
	var w=World.new(); w.join("host","船长"); w.join("guest","伙伴")
	var p:Dictionary=w.data.players.host
	p.area="water";p.x=Rooms.SEA_ENTRY.x;p.y=Rooms.SEA_ENTRY.y
	var rejected=w.action("host","room_enter",{"id":"sea_3"})
	check(p.area=="water","cannot enter deeper room by forged id")
	check(w.action("host","room_enter",{"id":"sea_1"}).contains("来到"),"deep entrance opens")
	check(p.area=="room" and p.room=="sea_1","room state travels")
	check(w.data.players.guest.area=="deck","partner remains independent")
	p.oxygen=30;w.tick(1);check(p.oxygen>30,"air pocket restores oxygen")
	var node:Dictionary=Rooms.nodes("sea_1").values()[0]
	p.x=node.x;p.y=node.y
	check(w.action("host","room_mine",{"id":node.id}).contains("石镐"),"pickaxe required")
	Inventory.add(p.bag,"pickaxe",1)
	w.action("host","room_mine",{"id":node.id});w.tick(1)
	check(Inventory.count(p.bag,node.kind)==0 and not p.activity.is_empty(),"mining takes time")
	check(p.oxygen<38,"deep cave consumes oxygen")
	var while_work=World.new();check(while_work.restore(w.snapshot()),"active cave gathering serializes")
	check(while_work.data.players.host.activity.is_empty(),"load cancels incomplete work without reward")
	w.action("host","cancel_activity");check(Rooms.active(w.data,node),"cancel preserves mineral")
	w.action("host","room_mine",{"id":node.id});w.tick(6)
	check(Inventory.count(p.bag,node.kind)==int(node.amount),"completion grants correct ore")
	check(not Rooms.active(w.data,node) and w.data.rooms.opened.sea==2,"exhaustion and progression shared")
	p.x=Rooms.onward("sea_1").x;p.y=Rooms.onward("sea_1").y
	w.action("host","room_deeper",{"id":"sea_1"});check(p.room=="sea_2","deeper portal")
	w.action("host","room_exit",{"id":"sea_2"});check(p.room=="sea_1","return to previous floor")
	p.x=Rooms.entry("sea_1").x;p.y=Rooms.entry("sea_1").y
	w.action("host","room_exit",{"id":"sea_1"});check(p.area=="water" and p.room=="","return to open sea")
	var saved:=w.snapshot();var restored=World.new()
	check(restored.restore(saved),"new world roundtrip")
	var json_rooms:Dictionary=JSON.parse_string(JSON.stringify(saved.rooms))
	var loaded_rooms:=Rooms.restore(json_rooms,int(saved.day))
	check(loaded_rooms==saved.rooms,"actual JSON roundtrip preserves exact room progress")
	for family in ["sea","mine"]:
		check(typeof(loaded_rooms.opened[family])==TYPE_INT,"loaded floor is an integer: "+family)
	check(typeof(loaded_rooms.depleted[node.id])==TYPE_INT,"loaded regrowth deadline is an integer")
	var fractional:Dictionary=json_rooms.duplicate(true);fractional.opened.sea=1.5
	check(Rooms.restore(fractional,int(saved.day)).is_empty(),"normalization never accepts a fractional floor")
	fractional=json_rooms.duplicate(true);fractional.depleted[node.id]=1.5
	check(Rooms.restore(fractional,int(saved.day)).is_empty(),"normalization never accepts a fractional deadline")
	for corruption in ["room","position","deadline","opened"]:
		var bad:Dictionary=saved.duplicate(true)
		match corruption:
			"room":bad.players.host.room="unknown"
			"position":bad.players.host.area="room";bad.players.host.room="sea_1";bad.players.host.x=0
			"deadline":bad.rooms.depleted[node.id]=INF
			"opened":bad.rooms.opened.sea=4
		var before:Dictionary=restored.snapshot()
		check(not restored.restore(bad),"reject "+corruption)
		check(restored.snapshot()==before,"reject preserves live world "+corruption)
	var legacy:Dictionary=saved.duplicate(true);legacy.version=13;legacy.erase("rooms");legacy.erase("gardens")
	for v14_key in ["rooms","gardens","restaurant","wardrobe","housing","journal","stories"]:legacy.erase(v14_key)
	for v14_player in legacy.players.values():v14_player.erase("room")
	for other:Dictionary in legacy.players.values():other.erase("room")
	check(restored.restore(legacy),"v13 migration")
	check(restored.data.players.host.bag==saved.players.host.bag,"v13 inventory preserved")
	check(Rooms.in_pool(Vector2(400,560)) and not Rooms.in_pool(Vector2(208,112)),"pool water distinct from dry entry")
	Rooms._arrive(w.data,p,"restaurant")
	var kept_bag:Array=p.bag.duplicate(true)
	w.data.navigation.anchored=false;w.join("host","returning")
	check(p.area=="deck" and p.bag==kept_bag,"indoor reconnect rescues to raft if partner already sailed away")
	print("ROOMS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

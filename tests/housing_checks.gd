extends SceneTree
const World=preload("res://scripts/world_state.gd")
const Housing=preload("res://scripts/housing.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Town=preload("res://scripts/island_town.gd")
const Inventory=preload("res://scripts/inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL "+label)
func _init()->void:
	var w:=World.new();w.join("host","客人");w.data.minute=600
	var p:Dictionary=w.data.players.host
	var npc:=Town.location("he_mu",600);p.area=npc.area;p.room=npc.room;p.x=npc.at.x;p.y=npc.at.y
	w.data.rooms.visited[p.room]=true
	var before:=w.snapshot();w.action("host","town_home_repair",{"id":"he_mu"})
	check(w.snapshot()==before,"unrented yard costs nothing")
	w.data.island.homestead.rented=true
	before=w.snapshot();w.action("host","town_home_repair",{"id":"he_mu"})
	check(w.snapshot()==before,"insufficient materials atomic")
	for item:String in Housing.REPAIR:Inventory.add(p.bag,item,Housing.REPAIR[item])
	w.action("host","town_home_repair",{"id":"he_mu"})
	check(w.data.housing.ready_day==3 and w.data.housing.level==0,"two actual nights of construction")
	before=w.snapshot();w.action("host","town_home_repair",{"id":"he_mu"});check(w.snapshot()==before,"no duplicate commissioning")
	var restored:=World.new();check(restored.restore(JSON.parse_string(JSON.stringify(w.snapshot()))),"construction JSON round trip")
	w._advance_day();check(w.data.housing.level==0,"one night remains")
	w._advance_day();check(w.data.housing.level==1 and w.data.housing.ready_day==0,"second night finishes")
	var door:=Housing.door(w.data);p.area="island";p.room="";p.x=door.x;p.y=door.y
	w.action("host","room_enter",{"id":"yard_home"});check(p.area=="room" and p.room=="yard_home","real home entry")
	w.action("host","sleep",{});check(w.data.day==4 and p.room=="yard_home","sleep stays in home")
	check(restored.restore(JSON.parse_string(JSON.stringify(w.snapshot()))),"home save load")
	w.action("host","room_exit",{"id":"yard_home"});check(p.area=="island" and Vector2(p.x,p.y)==door,"return to correct dynamic door")
	w.data.minute=600
	npc=Town.location("he_mu",600,w.data);Rooms._arrive(w.data,p,npc.room,npc.at)
	for item:String in Housing.EXPAND:Inventory.add(p.bag,item,Housing.EXPAND[item])
	w.action("host","town_home_expand",{"id":"he_mu"})
	check(w.data.housing.ready_day==w.data.day+3 and w.data.housing.target==2,"three nights scheduled for expansion")
	w._advance_day();w._advance_day()
	check(w.data.housing.level==1 and restored.restore(JSON.parse_string(JSON.stringify(w.snapshot()))),"unfinished expansion survives two nights and reload")
	w._advance_day();check(w.data.housing.level==2 and w.data.housing.ready_day==0,"third night expands without moving footprint")
	check(Housing.door(w.data)==door,"expansion protects surrounding cultivated land")
	var old:=World.new();var occupied:=Housing.footprint(0).get_center()
	old.data.island.plots["%d,%d"%[int(occupied.x/32),int(occupied.y/32)]]={"crop":"seed"}
	var home:=Housing.create(old.data);check(home.site!=0,"existing farm is never covered")
	for site in Housing.SITES.size():
		occupied=Housing.footprint(site).get_center()
		old.data.island.plots["%d,%d"%[int(occupied.x/32),int(occupied.y/32)]]={"crop":"seed"}
	home=Housing.create(old.data)
	check(home.site==-1,"fully occupied historical yard keeps every plot")
	for site in Housing.SITES.size():check(Housing.footprint(site).has_area() and World.IslandMap.can_stand(Housing.SITES[site]),"candidate door on land")
	print("HOUSING CHECKS ",checks," failures=",failures);quit(1 if failures else 0)

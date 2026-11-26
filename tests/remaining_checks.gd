extends SceneTree
const World=preload("res://scripts/world_state.gd")
const Inventory=preload("res://scripts/inventory.gd")
const Town=preload("res://scripts/island_town.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Housing=preload("res://scripts/housing.gd")
const Journal=preload("res://scripts/journal.gd")
const Home=preload("res://scripts/home_life.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL "+label)
func near_npc(w:RefCounted,slot:String,id:String)->void:
	w.data.minute=600
	var npc:=Town.location(id,600,w.data)
	var p:Dictionary=w.data.players[slot]
	p.area=npc.area;p.room=npc.room;p.x=npc.at.x;p.y=npc.at.y
	if p.area=="room":w.data.rooms.visited[p.room]=true
func _init()->void:
	var w:=World.new();w.join("host","船长");w.join("guest","伙伴")
	var p:Dictionary=w.data.players.host
	near_npc(w,"host","he_mu");near_npc(w,"guest","he_mu")
	w.action("host","town_errand_accept",{"id":"he_mu"})
	check(w.data.journal.host.accepted.has("he_mu") and w.data.journal.guest.accepted.is_empty(),"personal request")
	var before:=w.snapshot();w.action("host","town_errand_finish",{"id":"he_mu"})
	check(w.snapshot()==before,"insufficient errand atomic")
	Inventory.add(p.bag,"fiber",6);w.action("host","town_errand_finish",{"id":"he_mu"})
	check(w.data.money==16 and w.data.journal.host.friendship.he_mu==20,"one delivery reward")
	before=w.snapshot();w.action("host","town_errand_finish",{"id":"he_mu"});check(w.snapshot()==before,"cannot duplicate reward")
	w.data.journal.host.accepted.he_mu=1;Inventory.add(p.bag,"fiber",6);w.data.money=1000000000
	before=w.snapshot();w.action("host","town_errand_finish",{"id":"he_mu"});check(w.snapshot()==before,"full money bag preserves pending reward and materials")
	w.data.journal.host.accepted.erase("he_mu");Inventory.remove(p.bag,"fiber",6);w.data.money=16
	w.action("host","town_talk",{"id":"he_mu"});w.action("host","town_talk",{"id":"he_mu"})
	check(w.data.journal.host.friendship.he_mu==22,"daily talk once")
	Inventory.add(p.bag,"meal",2);w.action("host","town_gift",{"id":"he_mu"});w.action("host","town_gift",{"id":"he_mu"})
	check(Inventory.count(p.bag,"meal")==1 and w.data.journal.host.friendship.he_mu==32,"gift once daily")
	near_npc(w,"host","xu_an");w.action("host","town_story_accept",{"id":"xu_an"})
	Inventory.add(p.bag,"wood",12);Inventory.add(p.bag,"scrap",6);w.action("host","town_story_finish",{"id":"xu_an"})
	check(w.data.journal.story_step==1 and w.data.money==41,"shared chapter reward")
	near_npc(w,"guest","xu_an");before=w.snapshot();w.action("guest","town_story_finish",{"id":"xu_an"});check(w.snapshot()==before,"partner cannot duplicate shared chapter")
	var loaded:=World.new();check(loaded.restore(JSON.parse_string(JSON.stringify(w.snapshot()))),"journal JSON round trip")
	var bad:=w.snapshot();bad.journal.host.friendship.he_mu=0.5;before=loaded.snapshot();check(not loaded.restore(bad) and loaded.snapshot()==before,"reject malformed journal atomically")
	# Real interior expansion and finite furniture use existing bag/container operations.
	w.data.housing.level=2;Rooms._arrive(w.data,p,"yard_home",Rooms.onward("yard_home"))
	w.action("host","room_annex",{"id":"yard_annex"});check(p.room=="yard_annex","expanded room accessible")
	w.action("host","room_exit",{"id":"yard_annex"});check(p.room=="yard_home","annex returns inside home")
	var placed:=false
	for cell:Vector2i in Rooms.geometry("yard_home").ordered:
		var at:Vector2=(Vector2(cell)*32/64).floor()*64+Vector2(32,32)
		for stand:Vector2 in [at+Vector2(64,0),at-Vector2(64,0),at+Vector2(0,64)]:
			if not Rooms.can_stand("yard_home",stand):continue
			p.x=stand.x;p.y=stand.y
			if Home.placement_reason(w.data,p,"chest",at).is_empty():
				Inventory.add(p.bag,"chest",1);w.action("host","place_item",{"item":"chest","x":at.x,"y":at.y});placed=true;break
		if placed:break
	check(placed and w.data.housing.furniture.size()==1,"furniture legal empty floor exists")
	if placed:
		var id:String=w.data.housing.furniture[0].id
		check(w.nearby_chest("host")==id,"home chest reachable through inventory")
		Inventory.add(w.data.housing.furniture[0].slots,"wood",999)
		before=w.snapshot();w.action("host","home_pack",{"id":id});check(w.snapshot()==before,"full chest cannot pack")
		check(loaded.restore(JSON.parse_string(JSON.stringify(w.snapshot()))),"furnished home round trip")
		w.data.housing.furniture[0].slots=Inventory.empty_slots(16);w.action("host","home_pack",{"id":id})
		check(w.data.housing.furniture.is_empty() and Inventory.count(p.bag,"chest")==1,"recover furniture into bag")
	# Cabin requires genuine connected deck, not a visual-only object.
	w.data.deck_tiles=[]
	for x in range(2,12):
		for y in range(2,7):w.data.deck_tiles.append("%d,%d"%[x,y])
	p.area="deck";p.room="";p.x=544;p.y=352
	w.data.players.guest.area="deck";w.data.players.guest.room="";w.data.players.guest.x=608;w.data.players.guest.y=352
	var at:=Vector2(608,224)
	Inventory.add(p.bag,"cabin",1)
	var reason:=w.item_placement_reason("host","cabin",at.x,at.y)
	check(reason.is_empty(),"cabin can occupy expanded deck: "+reason)
	w.action("host","place_item",{"item":"cabin","x":at.x,"y":at.y})
	check(not w.data.housing.cabin.is_empty(),"cabin actually placed")
	if not w.data.housing.cabin.is_empty():
		check(not w._deck_walkable(at) and w._deck_walkable(Housing.cabin_door(w.data)),"solid cabin and clear door")
		near_npc(w,"host","he_mu");w.data.journal.host.friendship.he_mu=40;w.action("host","town_invite",{"id":"he_mu"})
		check(w.data.housing.carpenter and Town.location("he_mu",600,w.data).room=="raft_cabin","carpenter lives in cabin")
		p.area="deck";p.room="";p.x=Housing.cabin_door(w.data).x;p.y=Housing.cabin_door(w.data).y
		w.action("host","room_enter",{"id":"raft_cabin"});check(p.room=="raft_cabin","player enters cabin")
		check(loaded.restore(JSON.parse_string(JSON.stringify(w.snapshot()))),"cabin and resident round trip")
	for site in Housing.SITES.size():
		if not World.IslandMap.can_stand(Housing.SITES[site]):print("BLOCKED SITE ",site," ",Housing.SITES[site])
	print("REMAINING CHECKS ",checks," failures=",failures)
	quit(1 if failures else 0)

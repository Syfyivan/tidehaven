extends "res://tests/progression_network_probe.gd"
const Rooms=preload("res://scripts/rooms.gd")
const Town=preload("res://scripts/island_town.gd")
const Housing=preload("res://scripts/housing.gd")
const Archipelago=preload("res://scripts/archipelago.gd")
const Appearance=preload("res://scripts/appearance.gd")
var profile:Dictionary=_guest_profile()

func _guest_profile()->Dictionary:
	var result:=Appearance.default_for("guest")
	result.hair=3;result.shirt=5
	return result

func _setup_fixture()->void:
	var d:Dictionary=main.world.data
	d.navigation.anchored=true;d.chart.visited=true;d.island.homestead.rented=true;d.minute=600
	var coast:=Archipelago.island_position(d.chart);d.navigation.x=coast.x;d.navigation.y=coast.y
	Inventory.add(d.players.guest.bag,"fiber",6)
	for item:String in Housing.REPAIR:Inventory.add(d.players.guest.bag,item,Housing.REPAIR[item])

func _host()->void:
	var d:Dictionary=main.world.data
	match phase:
		90:
			if d.players.guest.online:
				var npc:=Town.location("he_mu",600,d)
				Rooms._arrive(d,d.players.guest,npc.room,npc.at)
				_signal_client("errand");_next()
		91:
			if d.housing.ready_day==3:
				_check(d.wardrobe.guest==profile and d.wardrobe.host==Appearance.default_for("host"),"guest appearance changes only their own layers")
				_check(d.money==16 and d.journal.guest.completed.has("he_mu") and d.journal.host.completed.is_empty(),"replayed guest delivery grants one personal reward")
				_check(Inventory.count(d.players.guest.bag,"fiber")==0,"repair and errand spend their exact separate materials")
				for slot in ["host","guest"]:_place(slot,"island",preload("res://scripts/island_state.gd").CAMP);d.players[slot].room=""
				main.perform("sleep");_signal_client("night1");_next()
		92:
			if d.day==2:
				_check(d.housing.level==0 and d.housing.ready_day==3,"first shared night retains unfinished house")
				main.perform("sleep");_signal_client("night2");_next()
		93:
			if d.day==3:
				_check(d.housing.level==1 and d.housing.ready_day==0,"second shared night completes one commission")
				for slot in ["host","guest"]:_place(slot,"deck",Vector2(555,288));d.players[slot].room=""
				var dock:=Archipelago.island_position(d.chart,"island_mist");d.navigation.x=dock.x;d.navigation.y=dock.y
				_signal_client("land");_next()
		94:
			if d.players.guest.room=="island_mist":
				_check(d.players.host.area=="deck" and d.rooms.visited.has("island_mist"),"guest explores new island while host stays aboard")
				main.perform("raise_anchor");_check(d.navigation.anchored,"host cannot strand island partner")
				_signal_client("return");_next()
		95:
			if d.players.guest.area=="deck":
				expected={"housing":d.housing.duplicate(true),"journal":d.journal.duplicate(true),"wardrobe":d.wardrobe.duplicate(true),"rooms":d.rooms.duplicate(true),"guest_bag":d.players.guest.bag.duplicate(true)}
				_check(main._persist(),"host writes new shared and personal progress")
				var f:=FileAccess.open(str(main.save_path)+".expected.json",FileAccess.WRITE);f.store_string(JSON.stringify(expected,"",true,true));f.close()
				_signal_client("saved");_next()
		96:
			if not d.players.guest.online:_finish()

func _client()->void:
	var d:Dictionary=main.current_state()
	if d.is_empty():return
	match phase:
		0:
			if server_stage=="errand":main.perform("appearance",profile);_next()
		1:
			if d.wardrobe.guest==profile and _age()>0.35:
				main.perform("town_errand_accept",{"id":"he_mu"});_next()
		2:
			if d.journal.guest.accepted.has("he_mu") and _age()>0.35:
				main.perform("town_errand_finish",{"id":"he_mu"});_next()
		3:
			if d.journal.guest.completed.has("he_mu") and _age()>0.35:
				main.perform("town_errand_finish",{"id":"he_mu"});_next()
		4:
			if _age()>0.5:main.perform("town_home_repair",{"id":"he_mu"});_next()
		5:
			if server_stage=="night1" and _age()>0.35:
				_check(d.housing.ready_day==3 and d.money==16,"client sees actual construction and reward")
				main.perform("sleep");_next()
		6:
			if server_stage=="night2" and _age()>0.35:
				_check(d.day==2 and d.housing.level==0,"client sees unfinished first night")
				main.perform("sleep");_next()
		7:
			if server_stage=="land" and _age()>0.35:main.perform("land",{"id":"island_mist"});_next()
		8:
			if server_stage=="return" and _age()>0.35:
				_check(d.players.guest.room=="island_mist","new room arrives through host snapshot")
				main.perform("room_exit",{"id":"island_mist"});_next()
		9:
			if server_stage=="saved":
				_check(d.housing.level==1 and d.players.guest.area=="deck","return and construction persist on client")
				_finish()

func _resume()->void:
	var d:Dictionary=main.world.data
	_check(_json_fields({"housing":d.housing,"journal":d.journal,"wardrobe":d.wardrobe,"rooms":d.rooms,"guest_bag":d.players.guest.bag})==_json_fields(expected),"independent process restores new personal and shared progress")
	_check(d.housing.level==1 and d.housing.ready_day==0,"finished construction does not charge or restart")
	_check(d.money==16 and d.journal.guest.completed.has("he_mu"),"completed errand retains one reward")
	if not finished:_finish()

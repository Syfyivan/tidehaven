extends "res://tests/progression_network_probe.gd"
const Rooms=preload("res://scripts/rooms.gd")
const Shop=preload("res://scripts/restaurant.gd")
var cave_node:Dictionary={}
var customer_id:=""
func _setup_fixture()->void:
	var d:Dictionary=main.world.data
	d.navigation.anchored=true;d.chart.visited=true
	var coast:Vector2=preload("res://scripts/archipelago.gd").island_position(d.chart)
	d.navigation.x=coast.x;d.navigation.y=coast.y
	d.restaurant.rented=true;d.restaurant.menu=["sashimi"]
	Inventory.add(d.restaurant.stock,"fish",8)
	for slot in ["host","guest"]:Inventory.add(d.players[slot].bag,"pickaxe",1)
	cave_node=Rooms.nodes("sea_1").values()[1]
func _host()->void:
	var d:Dictionary=main.world.data
	match phase:
		90:
			if d.players.guest.online:
				_place("host","deck",Vector2(480,288));_place("guest","water",Rooms.SEA_ENTRY)
				_signal_client("dive");_next()
		91:
			if d.players.guest.get("room")=="sea_1":
				_check(d.players.host.area=="deck","one diver enters cave independently of deck partner")
				d.players.guest.x=cave_node.x-30;d.players.guest.y=cave_node.y-15
				_signal_client("mine");_next()
		92:
			if Inventory.count(d.players.guest.bag,"ore")>0:
				_check(d.rooms.depleted.has(cave_node.id) and d.rooms.opened.sea==2,"guest timed mining awards and unlocks once on host")
				_check(d.players.guest.oxygen<100 and Inventory.count(d.players.host.bag,"ore")==0,"cave oxygen and personal loot independent")
				Rooms._arrive(d,d.players.host,"restaurant",Shop.station(0));Rooms._arrive(d,d.players.guest,"restaurant",Shop.station(1))
				main.perform("shop_prepare",{"station":0,"recipe":"sashimi"});_signal_client("prepare");_next()
		93:
			if d.restaurant.stations.all(func(s:Dictionary):return not s.is_empty() and s.remaining==0):
				_check(Inventory.count(d.restaurant.stock,"fish")==4,"two preparation RPCs deduct shared food exactly once each")
				main.perform("shop_collect",{"station":0});_signal_client("collect");_next()
		94:
			if Inventory.count(d.players.guest.bag,"sashimi")==1:
				_check(d.restaurant.stations[1].is_empty(),"guest retrieves actual finished food")
				Rooms._arrive(d,d.players.host,"restaurant",Shop.counter());d.minute=1080
				main.perform("shop_open");_next()
		95:
			for c:Dictionary in d.restaurant.customers:
				if c.phase=="wait":
					customer_id=c.id;Rooms._arrive(d,d.players.guest,"restaurant",Vector2(c.x,c.y));Rooms._arrive(d,d.players.host,"restaurant",Vector2(c.x,c.y))
					_signal_client("serve:"+customer_id);_next();break
		96:
			if d.restaurant.served==1:
				main.perform("shop_serve",{"id":customer_id})
				_check(d.restaurant.served==1 and Inventory.count(d.players.host.bag,"sashimi")==1,"racing second serve cannot consume another meal or duplicate sale")
				Rooms._arrive(d,d.players.host,"restaurant",Shop.counter());main.perform("shop_close")
				_check(d.money==12 and d.restaurant.last.served==1,"shared restaurant settlement is paid once")
				expected={"host_bag":d.players.host.bag.duplicate(true),"guest_bag":d.players.guest.bag.duplicate(true),"restaurant":d.restaurant.duplicate(true),"rooms":d.rooms.duplicate(true)}
				_check(main._persist(),"host saves restaurant cave progression and bags")
				var f:=FileAccess.open(str(main.save_path)+".expected.json",FileAccess.WRITE);f.store_string(JSON.stringify(expected,"",true,true));f.close()
				_signal_client("saved");_next()
		97:
			if not d.players.guest.online:_finish()
func _client()->void:
	var d:Dictionary=main.current_state()
	if d.is_empty():return
	match phase:
		0:
			if server_stage=="dive":main.perform("room_enter",{"id":"sea_1"});_next()
		1:
			if server_stage=="mine":
				_check(d.players.guest.room=="sea_1" and d.players.host.area=="deck","client sees independent room and deck scenes")
				var node:Dictionary=Rooms.nodes("sea_1").values()[1]
				main.perform("room_mine",{"id":node.id});_next()
		2:
			if server_stage=="prepare":
				_check(Inventory.count(d.players.guest.bag,"ore")>0,"ore result arrives through authoritative snapshot")
				main.perform("shop_prepare",{"station":1,"recipe":"sashimi"});_next()
		3:
			if server_stage=="collect":main.perform("shop_collect",{"station":1});_next()
		4:
			if server_stage.begins_with("serve:"):
				_check(d.restaurant.open and Inventory.count(d.players.guest.bag,"sashimi")==1,"client receives prepared food and live customers")
				main.perform("shop_serve",{"id":server_stage.trim_prefix("serve:")});_next()
		5:
			if server_stage=="saved":
				_check(d.restaurant.last.get("served")==1 and d.money==12,"client sees matching final settlement")
				_finish()
func _resume()->void:
	var d:Dictionary=main.world.data
	_check(_json_fields({"host_bag":d.players.host.bag,"guest_bag":d.players.guest.bag,"restaurant":d.restaurant,"rooms":d.rooms})==_json_fields(expected),"separate process restores exact bags pantry sales and cave progress")
	_check(d.players.host.area=="room" and d.players.host.room=="restaurant","continue returns inside shop while raft remains docked")
	main.perform("shop_close")
	_check(d.money==12,"restored settlement cannot be repeated")
	if not finished:_finish()

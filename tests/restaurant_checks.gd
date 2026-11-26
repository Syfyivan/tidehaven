extends SceneTree
const World=preload("res://scripts/world_state.gd")
const Shop=preload("res://scripts/restaurant.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Town=preload("res://scripts/island_town.gd")
const Inventory=preload("res://scripts/inventory.gd")
const Map=preload("res://scripts/island_map.gd")
const Activity=preload("res://scripts/island_activity.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func at(w:RefCounted,slot:String,point:Vector2)->void:Rooms._arrive(w.data,w.data.players[slot],"restaurant",point)
func _initialize()->void:
	var w=World.new();w.join("host","厨师");w.join("guest","店员")
	var p:Dictionary=w.data.players.host;var g:Dictionary=w.data.players.guest
	w.data.minute=720;w.data.money=50
	Inventory.add(p.bag,"wood",12)
	var place:=Town.location("xu_an",720)
	Rooms._arrive(w.data,p,place.room,place.at)
	check(w.action("host","town_shop",{"id":"xu_an"}).begins_with("许岸：北街"),"mayor voluntarily leases shop")
	check(w.data.money==20 and Inventory.count(p.bag,"wood")==0,"rent consumes exact materials")
	w.action("host","town_shop",{"id":"xu_an"})
	check(w.data.money==20,"repeat lease not charged")
	at(w,"host",Shop.pantry());Inventory.add(p.bag,"fish",12)
	check(w.nearby_chest("host")==Shop.STOCK_ID,"real shared pantry")
	w.action("host","inventory_move",{"from_container":"bag","to_container":Shop.STOCK_ID,"from_index":0,"to_index":0,"amount":8,"expected_item":"fish"})
	check(Inventory.count(w.data.restaurant.stock,"fish")==8 and Inventory.count(p.bag,"fish")==4,"manual stock transfer")
	var before:=w.snapshot()
	w.action("guest","inventory_move",{"from_container":Shop.STOCK_ID,"to_container":"bag","from_index":0,"to_index":0,"amount":1,"expected_item":"fish"})
	check(w.snapshot()==before,"remote pantry access rejected")
	at(w,"host",Shop.station(0));at(w,"guest",Shop.station(1))
	w.action("host","shop_prepare",{"station":0,"recipe":"sashimi"});w.action("guest","shop_prepare",{"station":1,"recipe":"sashimi"})
	check(Inventory.count(w.data.restaurant.stock,"fish")==4 and w.data.restaurant.stations.all(func(s:Dictionary):return not s.is_empty()),"two cooks use independent counters")
	w.action("host","shop_prepare",{"station":0,"recipe":"sashimi"})
	check(Inventory.count(w.data.restaurant.stock,"fish")==4,"busy counter cannot consume twice")
	Shop.tick(w.data,3);w.action("host","shop_collect",{"station":0})
	check(Inventory.count(p.bag,"sashimi")==0,"preparation takes actual time")
	var resumed=World.new();check(resumed.restore(w.snapshot()),"active preparation saves")
	check(resumed.data.restaurant.stations[0].remaining==1,"preparation remaining restored")
	Shop.tick(w.data,1)
	p.bag=Inventory.empty_slots(12)
	for i in 12:p.bag[i]={"item":"wood","count":999}
	w.action("host","shop_collect",{"station":0})
	check(not w.data.restaurant.stations[0].is_empty(),"full bag leaves completed food")
	p.bag=Inventory.empty_slots(12);w.action("host","shop_collect",{"station":0});w.action("host","shop_collect",{"station":0})
	check(Inventory.count(p.bag,"sashimi")==1,"ready food claimed once")
	at(w,"host",Shop.counter());w.action("host","shop_menu",{"recipe":"maki"});w.action("host","shop_menu",{"recipe":"salad"})
	check(w.data.restaurant.menu==["sashimi"],"choose menu without changing recipes")
	w.action("host","shop_open");check(not w.data.restaurant.open,"daytime preparation only")
	w.data.minute=1080;w.action("host","shop_open");check(w.data.restaurant.open,"evening manually open")
	var served:=0
	for frame in 1000:
		Shop.tick(w.data,0.1)
		for c:Dictionary in w.data.restaurant.customers:
			check(Rooms.can_stand("restaurant",Vector2(c.x,c.y)),"customer follows traversable room floor")
			if c.phase=="wait" and served==0:
				at(w,"host",Vector2(c.x,c.y));w.action("host","shop_serve",{"id":c.id})
				var cash:=int(w.data.restaurant.earnings)
				at(w,"guest",Vector2(c.x,c.y));Inventory.add(g.bag,"sashimi",1)
				w.action("guest","shop_serve",{"id":c.id})
				check(cash==12 and w.data.restaurant.earnings==cash and Inventory.count(g.bag,"sashimi")==1,"same customer served only once")
				served+=1
				check(resumed.restore(w.snapshot()),"customers and earnings save during service")
		if served>0 and w.data.restaurant.missed>0:break
	check(served==1 and w.data.restaurant.missed>0,"customer arrival order patience and service loop")
	check(w.data.money==20,"earnings wait for settlement")
	at(w,"host",Shop.counter());w.action("host","shop_close")
	check(w.data.money==32 and w.data.restaurant.last.served==1 and not w.data.restaurant.open,"manual close pays once")
	w.action("host","shop_close");w.action("host","shop_open")
	check(w.data.money==32 and not w.data.restaurant.open,"same evening cannot duplicate revenue or arrivals")
	w._advance_day();w.data.minute=1080;at(w,"host",Shop.counter());w.action("host","shop_open")
	check(w.data.restaurant.open and w.data.restaurant.arrivals==0,"next evening fresh service with stock retained")
	w.data.minute=1430;Shop.tick(w.data,0.1);check(not w.data.restaurant.open,"late night automatically closes")
	w.data.chart.visited=true;w.data.navigation.anchored=true
	w.data.navigation.x=preload("res://scripts/archipelago.gd").island_position(w.data.chart).x;w.data.navigation.y=preload("res://scripts/archipelago.gd").island_position(w.data.chart).y
	w.data.minute=720;place=Town.location("qiao_xin",720);p.area=place.area;p.room=place.room;p.x=place.at.x;p.y=place.at.y
	p.bag=Inventory.empty_slots(12);Inventory.add(p.bag,"veg",12)
	w.action("host","town_supply",{"id":"qiao_xin","offer":"veg"});w.action("host","town_supply",{"id":"qiao_xin","offer":"veg"})
	check(Inventory.count(p.bag,"veg")==6 and w.data.money==60,"real supply shared daily once")
	check(resumed.restore(w.snapshot()),"supply completion and settlement roundtrip")
	var corrupt:=w.snapshot();corrupt.restaurant.stations[0]={"recipe":"wood","remaining":1}
	before=resumed.snapshot();check(not resumed.restore(corrupt) and resumed.snapshot()==before,"bad recipe restore atomic")
	check(Map.forest_nodes().size()==12,"three distinct forest resources sites populated")
	var mushroom:Dictionary=Map.forest_nodes().values().filter(func(n:Dictionary):return n.kind=="mushroom")[0]
	p.area="island";p.room="";p.x=mushroom.x-24;p.y=mushroom.y
	w.action("host","gather_island",{"id":mushroom.id});Activity.tick(w.data,p,2)
	check(Inventory.count(p.bag,"mushroom")==2,"forest mushrooms hand collected after time")
	print("RESTAURANT: %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)

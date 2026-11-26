extends SceneTree
## Controlled 58-day campaign, not 58 real-time days or a human playtest.
const World=preload("res://scripts/world_state.gd")
const Inventory=preload("res://scripts/inventory.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Shop=preload("res://scripts/restaurant.gd")
const Farming=preload("res://scripts/farming.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL "+label)
func _init()->void:
	var w:=World.new();w.join("host","厨师");w.join("guest","店员")
	var coast:=World.Archipelago.island_position(w.data.chart)
	w.data.navigation.x=coast.x;w.data.navigation.y=coast.y;w.data.navigation.anchored=true;w.data.chart.visited=true
	w.data.housing.level=2;w.data.island.homestead.rented=true;w.data.gardens.greenhouse=true
	w.data.restaurant.rented=true;w.data.restaurant.menu=["sashimi"];Inventory.add(w.data.restaurant.stock,"fish",28)
	var outside:="80,60"
	w.data.island.plots[outside]=Farming.new_plot()
	w.data.gardens.plots["10,12"]=Farming.new_plot()
	var protected:Dictionary=w.data.gardens.plots["10,12"]
	protected.covered=true
	var missed_growth:=0
	for day in range(1,59):
		var p:Dictionary=w.data.players.host;var g:Dictionary=w.data.players.guest
		if day<=14:
			Rooms._arrive(w.data,p,"restaurant",Shop.station(0))
			w.action("host","shop_prepare",{"station":0,"recipe":"sashimi"});Shop.tick(w.data,4)
			w.action("host","shop_collect",{"station":0})
			check(Inventory.count(p.bag,"sashimi")==1,"day %d preparation exact"%day)
			Rooms._arrive(w.data,p,"restaurant",Shop.counter());w.data.minute=1080
			w.action("host","shop_open")
			var delivered:=false
			for frame in 500:
				Shop.tick(w.data,0.2)
				for customer:Dictionary in w.data.restaurant.customers:
					if customer.phase=="wait":
						Rooms._arrive(w.data,p,"restaurant",Vector2(customer.x,customer.y))
						w.action("host","shop_serve",{"id":customer.id});delivered=true;break
				if delivered:break
			Rooms._arrive(w.data,p,"restaurant",Shop.counter());w.action("host","shop_close")
			check(delivered and w.data.money==day*12 and Inventory.count(w.data.restaurant.stock,"fish")==28-day*2,"day %d cumulative stock and income"%day)
			w.action("host","shop_close")
			check(w.data.money==day*12,"repeated close cannot duplicate income")
		if day==26:
			w.data.island.plots[outside]={"crop":"seed","growth":0,"watered":false,"covered":false,"dead":false}
			protected.crop="seed";protected.growth=0
		if day>=26:
			w.data.island.plots[outside].watered=not w.data.island.plots[outside].dead
			protected.watered=day!=27
		if day==27:missed_growth=protected.growth
		for person in [p,g]:Rooms._arrive(w.data,person,"yard_home",Rooms.entry("yard_home"))
		w.action("host","sleep")
		check(w.data.day==day,"one partner cannot force shared next day")
		w.action("guest","sleep")
		check(w.data.day==day+1 and p.room=="yard_home" and g.room=="yard_home","shared night preserves home")
		if day==27:check(protected.growth==missed_growth,"unwatered greenhouse night does not grow")
		if day==28:check(w.data.island.plots[outside].dead and not protected.dead,"spring ends outdoors while greenhouse preserves crop")
		if day==31:check(Farming.mature(protected),"greenhouse crop requires four watered nights")
		var saved:=w.snapshot();var loaded:=World.new()
		check(loaded.restore(JSON.parse_string(JSON.stringify(saved))),"daily saved campaign restores day %d"%day)
		check(loaded.data.gardens==w.data.gardens and loaded.data.island.plots==w.data.island.plots and loaded.data.restaurant==w.data.restaurant and loaded.data.money==w.data.money,"daily growth pantry and income exact")
	check(w.data.day==59 and Farming.season(w.data.day)==2 and w.data.money==168,"58 nights reach autumn with exact fourteen evenings income")
	print("SEASON CAMPAIGN ",checks," failures=",failures);quit(1 if failures else 0)

extends SceneTree
const World=preload("res://scripts/world_state.gd")
const Gardens=preload("res://scripts/gardens.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Inventory=preload("res://scripts/inventory.gd")
const Farming=preload("res://scripts/farming.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	var w=World.new();w.join("host","船长");w.join("guest","伙伴")
	var p:Dictionary=w.data.players.host
	for i in 2:
		var id:="pot%d"%i
		w.data.structures[id]=w._new_structure(id,"garden",Vector2(480+i*64,352))
		Gardens.add_planter(w.data,id)
	for item in ["seed","watering_can","summer_seed","hoe"]:Inventory.add(p.bag,item,4)
	p.x=500;p.y=304;p.can_water=20
	w.action("host","plant",{"x":480,"y":352,"seed":"seed"})
	check(w.data.gardens.planters.pot0.crop=="seed" and w.data.gardens.planters.pot1.crop=="","pots are independent")
	w.action("host","water",{"x":480,"y":352});w.tick(100)
	check(w.data.gardens.planters.pot0.growth==0,"pots no longer grow in seconds")
	check(p.can_water==19,"watering consumes one can charge")
	for day in 4:
		w.action("host","water",{"x":480,"y":352});w._advance_day()
		p=w.data.players.host;p.x=500;p.y=304
	check(Farming.mature(w.data.gardens.planters.pot0),"four watered nights mature spring crop")
	w.action("host","harvest",{"x":480,"y":352})
	check(Inventory.count(p.bag,"veg")==2 and w.data.gardens.planters.pot0.crop=="","harvest clears only chosen pot")
	w.action("host","plant",{"x":544,"y":352,"seed":"summer_seed"})
	check(w.data.gardens.planters.pot1.crop=="","pot respects season")
	p.can_water=0;Inventory.add(p.bag,"freshwater",1)
	w.action("host","refill_can",{})
	check(p.can_water==10 and Inventory.count(p.bag,"cup")==1,"purified water fills can and preserves cup")
	var door:Vector2=preload("res://scripts/island_map.gd").LANDMARKS.greenhouse.door
	p.area="island";p.x=door.x;p.y=door.y
	w.action("host","repair_greenhouse",{})
	check(not w.data.gardens.greenhouse,"repair requires all materials")
	for item:String in Gardens.REPAIR:Inventory.add(p.bag,item,int(Gardens.REPAIR[item]))
	w.action("host","repair_greenhouse",{})
	check(w.data.gardens.greenhouse and Inventory.count(p.bag,"ingot")==0,"repair consumes once")
	w.action("host","room_enter",{"id":"greenhouse"})
	check(p.room=="greenhouse","repaired greenhouse can be entered")
	for y in range(Gardens.SOIL.position.y,Gardens.SOIL.end.y):
		for x in range(Gardens.SOIL.position.x,Gardens.SOIL.end.x):check(Rooms.can_stand("greenhouse",Vector2(x*32+16,y*32+16)),"greenhouse soil really walkable")
	var at:=Vector2(336,400);p.x=at.x;p.y=at.y
	w.action("host","till",{"x":at.x,"y":at.y})
	w.action("host","plant",{"x":at.x,"y":at.y,"seed":"summer_seed"})
	check(w.data.gardens.plots[Farming.plot_key(at)].crop=="summer_seed","greenhouse accepts out of season seed")
	w.action("host","water",{"x":at.x,"y":at.y})
	Gardens.advance_day(w.data)
	check(w.data.gardens.plots[Farming.plot_key(at)].growth==1,"greenhouse shares daily crop growth")
	var restored=World.new();check(restored.restore(w.snapshot()),"gardens and indoor player roundtrip")
	var before:Dictionary=restored.snapshot();var bad:Dictionary=w.snapshot();bad.gardens.plots["0,0"]=Farming.new_plot()
	check(not restored.restore(bad) and restored.snapshot()==before,"invalid greenhouse soil rejected atomically")
	var old:=Gardens.migrate(w.data.structures,{"stage":2,"progress":1.0,"watered":true})
	check(old.planters.pot0.growth==4 and old.planters.pot1.crop=="" and old.legacy=="pot0","legacy crop migrates once")
	print("GARDENS: %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)

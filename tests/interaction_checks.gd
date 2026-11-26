extends SceneTree
const World = preload("res://scripts/world_state.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Recipes = preload("res://scripts/recipes.gd")
const Map = preload("res://scripts/island_map.gd")
const Farming = preload("res://scripts/farming.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	var bag := Inventory.empty_slots(12)
	_check(Inventory.add(bag,"wood",1000)==0 and bag[0].count==999 and bag[1].count==1,"999 limit and exact overflow to second slot")
	bag[2]={"item":"wood","count":20}
	_check(Inventory.move(bag,2,bag,1) and bag[1].count==21 and bag[2].is_empty(),"old small stack can merge manually")
	bag[2]={"item":"wood","count":999}
	_check(Inventory.move(bag,2,bag,1) and bag[1].count==999 and bag[2].count==21,"partial merge retains overflow at source")
	_check(Inventory.validate_slots(JSON.parse_string(JSON.stringify(bag)),12),"999 stacks survive JSON")
	bag[0].count=1000
	_check(not Inventory.validate_slots(bag,12),"1000 in one slot rejected")
	var w = World.new()
	w.join("host","测试")
	w.join("guest","同伴")
	w.data.players.guest.x=544.0
	w.data.players.guest.y=352.0
	Inventory.add(w.data.players.host.bag,"wood",8)
	Inventory.add(w.data.players.host.bag,"rope",2)
	w.action("host","craft",{"recipe":"chest"})
	_check(Inventory.count(w.data.players.host.bag,"chest")==1 and w.data.chests.is_empty(),"craft produces portable chest without automatic placement")
	_check(Inventory.count(w.data.players.host.bag,"wood")==4 and Inventory.count(w.data.players.host.bag,"rope")==1,"craft spends materials once")
	var before: Dictionary=w.snapshot()
	w.action("host","place_item",{"item":"chest","x":480.0,"y":288.0})
	_check(w.snapshot()==before,"occupied preview fails without spending kit")
	w.action("host","place_item",{"item":"chest","x":544.0,"y":224.0})
	_check(w.data.chests.size()==1 and Inventory.count(w.data.players.host.bag,"chest")==0,"place consumes exactly one chest")
	_check(Inventory.count(w.data.players.host.bag,"wood")==4,"place does not charge materials again")
	before=w.snapshot()
	w.action("host","place_item",{"item":"chest","x":544.0,"y":224.0})
	_check(w.snapshot()==before,"duplicate placement cannot duplicate a chest")
	w.action("guest","place_item",{"item":"chest","x":416.0,"y":352.0})
	_check(w.snapshot()==before,"partner cannot spend another player's kit")
	w.data.chests.chest_0.area="island"
	_check(w.nearby_chest("host").is_empty(),"nearby chest lookup cannot expose another scene at same numeric coordinates")
	w.data.chests.chest_0.erase("area")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(w.snapshot()))
	var restored=World.new()
	_check(restored.restore(saved),"v12 deck furniture and inventory restore")
	saved.version=11
	for v14_key in ["rooms","gardens","restaurant","wardrobe","housing","journal","stories"]:saved.erase(v14_key)
	for v14_player in saved.players.values():v14_player.erase("room")
	saved.erase("threats")
	for legacy_player in saved.players.values(): legacy_player.erase("dive_status")
	_check(restored.restore(saved),"v11 stacks and deck furniture migrate without sorting")
	_check(JSON.parse_string(JSON.stringify(restored.data.players.host.bag))==saved.players.host.bag,"old slot order preserved")
	w.data.players.host.bag=Inventory.empty_slots(12)
	for i in 12:w.data.players.host.bag[i]={"item":"wood","count":999}
	w.data.chests.chest_0.slots[0]={"item":"rope","count":2}
	before=w.snapshot()
	w.action("host","craft",{"recipe":"chest"})
	_check(w.snapshot()==before,"full bag crafting is atomic including shared materials")
	_check(not Recipes.output_fits(w.data.players.host.bag,"chest"),"UI sees portable structure needs output capacity")
	w.data.players.host.bag[11]={"item":"rope","count":1}
	_check(Recipes.output_fits(w.data.players.host.bag,"chest"),"using final ingredient can free result slot")
	w.action("host","craft",{"recipe":"chest"})
	_check(Inventory.count(w.data.players.host.bag,"chest")==1,"full-before-consumption crafting succeeds when a slot frees")
	# Workbench needed only during fabrication, never when placing an existing kit.
	w.data.players.host.bag=Inventory.empty_slots(12)
	Inventory.add(w.data.players.host.bag,"furnace",1)
	_check(w.item_placement_reason("host","furnace",480,224).is_empty(),"finished advanced facility places without workbench")
	w.action("host","place_item",{"item":"furnace","x":480.0,"y":224.0})
	_check(w.data.structures.values().any(func(v):return v.kind=="furnace"),"advanced facility retained after placement")
	w=World.new(); w.join("host","岛上"); w.join("guest","筏上")
	w.data.island.homestead.rented=true
	var p: Dictionary=w.data.players.host
	p.area="island"
	var found:=Vector2.ZERO
	for gx in range(32,52):
		for gy in range(21,34):
			var at:=Vector2(gx*64+32,gy*64+32)
			p.x=at.x;p.y=at.y+64
			if Map.can_stand(Vector2(p.x,p.y)) and w.island_chest_reason("host",at).is_empty():
				found=at;break
		if found!=Vector2.ZERO:break
	_check(found!=Vector2.ZERO,"natural cleared yard spot exists")
	if found!=Vector2.ZERO:
		Inventory.add(p.bag,"chest",2)
		before=w.snapshot()
		w.data.island.homestead.rented=false
		_check(not w.item_placement_reason("host","chest",found.x,found.y).is_empty(),"unrented yard denied")
		w.data.island.homestead.rented=true
		w.action("host","place_item",{"item":"chest","x":found.x,"y":found.y})
		_check(w.data.chests.size()==1 and w.data.chests.chest_0.area=="island","island chest owns island coordinates")
		_check(w.nearby_chest("host")=="chest_0" and w.nearby_chest("guest").is_empty(),"chest access scoped to same scene")
		Inventory.add(w.data.chests.chest_0.slots,"wood",999)
		_check(w.chest_totals().wood==0,"raft crafting cannot remotely drain island storage")
		var from:=Vector2(p.x,p.y)
		w._move_player(p,Vector2(0,-64))
		_check(Vector2(p.x,p.y).distance_to(found)>18,"island chest blocks walking through")
		p.x=from.x;p.y=from.y
		Inventory.add(p.bag,"hoe",1)
		var count:int=w.data.island.plots.size()
		w.action("host","till",{"x":found.x+16,"y":found.y+16})
		_check(w.data.island.plots.size()==count,"cannot till beneath placed chest")
		p.area="deck";p.x=480.0;p.y=288.0
		w.data.chart.visited=true
		saved=JSON.parse_string(JSON.stringify(w.snapshot()))
		_check(restored.restore(saved) and restored.data.chests.chest_0.slots[0].count==999,"island chest location and 999 items survive save/continue")
	print("INTERACTION RULES: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func _check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",message)

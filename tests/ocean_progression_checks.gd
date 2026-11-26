extends SceneTree
const World=preload("res://scripts/world_state.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Ocean=preload("res://scripts/ocean_residents.gd")
const Journal=preload("res://scripts/journal.gd")
const Inventory=preload("res://scripts/inventory.gd")
const Archipelago=preload("res://scripts/archipelago.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL "+label)
func _init()->void:
	for id:String in ["island_mist","island_reef","island_wind"]:
		var w:=World.new();w.join("host","船长")
		var p:Dictionary=w.data.players.host;p.x=555;p.y=288
		var position:=Archipelago.island_position(w.data.chart,id)
		w.data.navigation.x=position.x;w.data.navigation.y=position.y;w.data.navigation.anchored=true
		var before:=w.snapshot();w.action("host","set_destination",{"id":id});check(w.snapshot()==before,"compass still required")
		Inventory.add(p.bag,"compass",1);w.action("host","set_destination",{"id":id});check(w.data.chart.destination==id,"all three navigation destinations")
		w.action("host","land",{"id":id});check(p.area=="room" and p.room==id and Rooms.can_stand(id,Vector2(p.x,p.y)),"real landable island")
		check(Rooms.geometry(id).cells.size()>100 and Rooms.nodes(id).size()==18,"connected useful exploration region "+id)
		for node:Dictionary in Rooms.nodes(id).values():
			check(Rooms.can_stand(id,Vector2(node.x,node.y)),"resource on connected land")
		var node:Dictionary=Rooms.nodes(id).values().filter(func(n):return n.get("tool","")!="")[0]
		p.x=node.x;p.y=node.y
		before=w.snapshot();w.action("host","room_mine",{"id":node.id});check(w.snapshot()==before,"correct tool required")
		Inventory.add(p.bag,node.tool,1);w.action("host","room_mine",{"id":node.id})
		check(not p.activity.is_empty(),"timed gathering started")
		Rooms.tick(w.data,p,float(node.duration)+0.01)
		check(Inventory.count(p.bag,node.kind)==node.amount and not Rooms.active(w.data,node),"deplete once and award")
		var restored:=World.new();check(restored.restore(JSON.parse_string(JSON.stringify(w.snapshot()))),"new island JSON save")
		restored.join("host","返回");check(restored.data.players.host.room==id,"continue stays on visited island")
		p.x=Rooms.entry(id).x;p.y=Rooms.entry(id).y
		w.action("host","room_exit",{"id":id});check(p.area=="deck","return to raft")
	var w:=World.new();w.join("host","船长");w.join("guest","伙伴")
	var p:Dictionary=w.data.players.host
	Rooms._arrive(w.data,p,"sea_3",Ocean.position("lan_ying"))
	var before:=w.snapshot();w.action("host","ocean_errand_accept",{"id":"lan_ying"});check(w.snapshot()==before,"cannot understand before story")
	w.data.journal.story_step=3;w.data.journal.tide_speech=true
	w.action("host","ocean_errand_accept",{"id":"lan_ying"});Inventory.add(p.bag,"ore",4)
	w.action("host","ocean_errand_finish",{"id":"lan_ying"});check(w.data.journal.spells.get("breath",false),"ocean request unlocks real ability")
	p.oxygen=35;p.stamina=50
	w.action("host","spell",{"id":"breath"})
	check(p.oxygen==70 and p.stamina==38 and w.data.journal.cooldown.host==30,"breath costs and capped gain")
	before=w.snapshot();w.action("host","spell",{"id":"breath"});check(w.snapshot()==before,"cooldown prevents repeat")
	check(w.data.journal.cooldown.guest==0,"personal cooldown")
	var restored:=World.new();check(restored.restore(JSON.parse_string(JSON.stringify(w.snapshot()))),"spell unlock and cooldown persist")
	w.data.journal.cooldown.host=0;w.data.journal.spells.rain=true
	p.area="island";p.room="";p.x=2200;p.y=1800;p.stamina=50
	w.data.island.plots={"68,56":{"crop":"seed","growth":2,"watered":false,"covered":false,"dead":false},"69,56":{"crop":"seed","growth":3,"watered":false,"covered":false,"dead":false},"90,56":{"crop":"seed","growth":1,"watered":false,"covered":false,"dead":false}}
	w.action("host","spell",{"id":"rain"})
	check(w.data.island.plots["68,56"].watered and w.data.island.plots["69,56"].watered and not w.data.island.plots["90,56"].watered,"rain respects local radius")
	check(w.data.island.plots["68,56"].growth==2 and p.stamina==30,"magic cannot skip growth")
	print("OCEAN PROGRESSION ",checks," failures=",failures);quit(1 if failures else 0)

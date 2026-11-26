extends "res://tests/progression_network_probe.gd"
const Map=preload("res://scripts/island_map.gd")
const Motion=preload("res://scripts/tool_motion.gd")
var tree:Dictionary={}
var seen:Array=[]
func _setup_fixture()->void:
	var d:Dictionary=main.world.data
	d.navigation.anchored=true;d.chart.visited=true
	var port:Vector2=preload("res://scripts/archipelago.gd").island_position(d.chart)
	d.navigation.x=port.x;d.navigation.y=port.y
	for node in Map.nodes_near(Vector2(2500,1700)).values():
		if node.kind=="tree" and Map.can_stand(Vector2(node.x,node.y)+Vector2(0,48)) and Map.can_stand(Vector2(node.x,node.y)-Vector2(48,0)):tree=node;break
	for slot in ["host","guest"]:Inventory.add(d.players[slot].bag,"axe",1)
	_place("host","island",Vector2(tree.x-48,tree.y))
func _host()->void:
	var d:Dictionary=main.world.data
	match phase:
		90:
			if d.players.guest.online:
				_place("guest","island",Vector2(tree.x,tree.y+48))
				_signal_client(str(tree.id));_next()
		91:
			if not d.players.guest.activity.is_empty() and _age()>0.4:
				_check(d.players.guest.activity.kind=="island_gather","guest starts real server-owned chopping")
				main._equip_index(0)
				main.perform("gather_island",{"id":tree.id})
				_next()
		92:
			if remote_stage=="done":
				_check(Inventory.count(d.players.guest.bag,"wood")==tree.amount,"guest receives exactly one tree reward")
				_check(Inventory.count(d.players.host.bag,"wood")==0 and d.players.host.activity.is_empty(),"competing host stops without duplicate reward")
				expected=_persistent_fields(d)
				main._persist()
				var f:=FileAccess.open(str(main.save_path)+".expected.json",FileAccess.WRITE);f.store_string(JSON.stringify(expected,"",false,true));f.close()
				_signal_client("saved");_next()
		93:
			if not d.players.guest.online:_finish()
func _client()->void:
	var d:Dictionary=main.current_state()
	if d.is_empty():return
	var p:Dictionary=d.players.guest
	match phase:
		0:
			if server_stage!="" and p.online:
				tree=Map.node(server_stage)
				main._equip_index(0);main.perform("gather_island",{"id":tree.id});_next()
		1:
			if not p.activity.is_empty():
				var pose:=Motion.sample(p.activity,Vector2(p.x,p.y),Vector2(tree.x,tree.y))
				if pose.frame not in seen:seen.append(pose.frame)
			elif Inventory.count(p.bag,"wood")>0:
				_check(seen.size()==5,"client snapshots show all five native chopping poses")
				_check(Inventory.count(p.bag,"wood")==tree.amount,"client reward matches shared tree once")
				_check(d.island.depleted.has(tree.id),"client sees depleted tree")
				client_stage.rpc_id(1,"done");_next()
		2:
			if server_stage=="saved":_finish()
func _resume()->void:
	_check(_json_fields(_persistent_fields(main.world.data))==_json_fields(expected),"chopping rewards and depletion restore exactly")
	_check(main.world.data.players.host.activity.is_empty(),"no phantom host swing after Continue")
	_check(main.world.data.players.guest.activity.is_empty(),"no phantom guest swing after Continue")
	if not finished:_finish()
func _persistent_fields(d:Dictionary)->Dictionary:
	return {"island":d.island.duplicate(true),"host_bag":d.players.host.bag.duplicate(true),"guest_bag":d.players.guest.bag.duplicate(true)}

extends "res://tests/progression_network_probe.gd"
const Threats=preload("res://scripts/sea_threats.gd")
func _setup_fixture()->void:
	var d:Dictionary=main.world.data
	d.navigation.anchored=true
	for slot in ["host","guest"]:Inventory.add(d.players[slot].bag,"harpoon",1)
	for e in d.entities.values():
		if e.kind=="fish":e.active=false
func _host()->void:
	var d:Dictionary=main.world.data
	match phase:
		90:
			if d.players.guest.online:
				_place("host","deck",Vector2(480,288));_place("guest","water",Vector2(565,265))
				d.threats=Threats.create()
				_signal_client("ready");_next()
		91:
			if d.threats.shark.phase=="repelled":
				_check(d.players.guest.stamina==95,"guest spear RPC repels with one stamina cost")
				_check(d.players.host.stamina==100 and d.players.host.area=="deck","deck partner is unaffected by underwater combat")
				_check(Inventory.total_count(d.players.guest.bag)==1,"enemy cannot be harvested as duplicate fish")
				_signal_client("repelled");_next()
		92:
			if remote_stage=="seen":
				_place("guest","water",Vector2(120,100));_signal_client("surface");_next()
		93:
			if d.players.guest.area=="deck":
				_check(d.threats.shark.target=="","surface clears shared attack target")
				expected={"host_bag":d.players.host.bag.duplicate(true),"guest_bag":d.players.guest.bag.duplicate(true)}
				main._persist()
				var f:=FileAccess.open(str(main.save_path)+".expected.json",FileAccess.WRITE);f.store_string(JSON.stringify(expected));f.close()
				_signal_client("saved");_next()
		94:
			if not d.players.guest.online:_finish()
func _client()->void:
	var d:Dictionary=main.current_state()
	if d.is_empty():return
	var p:Dictionary=d.players.guest
	match phase:
		0:
			if server_stage=="ready" and d.threats.shark.phase=="windup":
				_check(d.threats.shark.target=="guest","client sees host-confirmed enemy warning")
				var direction:Vector2=Threats.point(d.threats.shark)-Threats.point(p)
				main._equip_index(0);main.perform("spear",{"x":direction.x,"y":direction.y});_next()
		1:
			if server_stage=="repelled":
				_check(d.threats.shark.phase=="repelled" and p.stamina==95,"client receives same repel phase and personal stamina")
				_check(p.activity.get("kind","") in ["","spear"],"no invented harvest activity after enemy hit")
				client_stage.rpc_id(1,"seen");_next()
		2:
			if server_stage=="surface":main.perform("surface");_next()
		3:
			if server_stage=="saved":_finish()
func _resume()->void:
	var d:Dictionary=main.world.data
	_check(_json_fields({"host_bag":d.players.host.bag,"guest_bag":d.players.guest.bag})==_json_fields(expected),"both exact bags restore after combat")
	_check(d.threats.shark.phase=="repelled" and d.threats.shark.remaining>0,"independent restore keeps earned repel cooldown")
	_check(d.threats.shark.target=="" and d.players.guest.activity.is_empty(),"no resumed charge or duplicate spear after loading")
	if not finished:_finish()

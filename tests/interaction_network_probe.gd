extends "res://tests/progression_network_probe.gd"
func _setup_fixture()->void:
	Inventory.add(main.world.data.players.host.bag,"chest",1)
	Inventory.add(main.world.data.players.guest.bag,"fish",999)
	Inventory.add(main.world.data.players.guest.bag,"wood",4)
	Inventory.add(main.world.data.players.guest.bag,"rope",1)
	_place("host","deck",Vector2(480,288))
func _host()->void:
	var d:Dictionary=main.world.data
	match phase:
		90:
			if d.players.guest.online:
				_place("guest","deck",Vector2(544,288))
				_signal_client("craft");_next()
		91:
			if remote_stage=="stored" and _age()>0.3:
				if not _check(d.chests.size()==1 and d.chests.chest_0.slots[0].count==999,"guest crafts, places, and deposits 999 through real RPC"):return
				if not _check(Inventory.count(d.players.guest.bag,"chest")==0 and Inventory.count(d.players.guest.bag,"wood")==0,"kit and ingredients each spent once"):return
				var before:Dictionary=main.world.snapshot()
				main.perform("place_item",{"item":"chest","x":544.0,"y":224.0})
				if not _check(main.world.snapshot()==before,"competing host placement retains own chest kit"):return
				expected=_persistent_fields(d)
				if not main._persist():_fail("interaction save");return
				var f:=FileAccess.open(str(main.save_path)+".expected.json",FileAccess.WRITE)
				f.store_string(JSON.stringify(expected,"",false,true));f.close()
				_signal_client("saved");_next()
		92:
			if not d.players.guest.online:_finish()
func _client()->void:
	var d:Dictionary=main.current_state()
	if d.is_empty() or not d.players.guest.online:return
	var bag:Array=d.players.guest.bag
	match phase:
		0:
			if server_stage=="craft":
				_check(Inventory.count(bag,"fish")==999,"client receives 999 stack")
				main.perform("craft",{"recipe":"chest"});_next()
		1:
			if Inventory.count(bag,"chest")==1 and _age()>0.2:
				_check(d.chests.is_empty(),"guest crafting creates inventory item only")
				main.perform("place_item",{"item":"chest","x":544.0,"y":224.0})
				main.perform("place_item",{"item":"chest","x":544.0,"y":224.0})
				_next()
		2:
			if d.chests.has("chest_0") and _age()>0.2:
				_check(Inventory.count(bag,"chest")==0 and d.chests.size()==1,"duplicate request does not duplicate furniture")
				main.perform("inventory_move",{"from_container":"bag","from_index":0,"to_container":"chest_0","to_index":0,"amount":999,"expected_item":"fish"})
				_next()
		3:
			if d.chests.chest_0.slots[0].get("count",0)==999:
				_check(Inventory.count(bag,"fish")==0,"transfer leaves no duplicate personal stack")
				client_stage.rpc_id(1,"stored");_next()
		4:
			if server_stage=="saved":_finish()
func _resume()->void:
	_check(_json_fields(_persistent_fields(main.world.data))==_json_fields(expected),"independent process restores exact 999 storage and both bags")
	_check(main.world.data.chests.size()==1,"resume retains exactly one placed chest")
	_check(Inventory.count(main.world.data.players.guest.bag,"fish")==0,"resume does not restore already deposited fish to guest bag")
	if not finished:_finish()
func _persistent_fields(d:Dictionary)->Dictionary:
	return {"chests":d.chests.duplicate(true),"host_bag":d.players.host.bag.duplicate(true),"guest_bag":d.players.guest.bag.duplicate(true)}

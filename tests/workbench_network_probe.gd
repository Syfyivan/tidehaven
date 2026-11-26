extends "res://tests/progression_network_probe.gd"
## Reuse the existing three-process ENet/save harness with a station-specific journey.
const Recipes = preload("res://scripts/recipes.gd")

func _setup_fixture() -> void:
	for slot in ["host", "guest"]:
		for item in Recipes.ALL.fins.costs:
			Inventory.add(main.world.data.players[slot].bag, item, int(Recipes.ALL.fins.costs[item]))
	for item in Recipes.ALL.workbench.costs:
		Inventory.add(main.world.data.players.host.bag, item, int(Recipes.ALL.workbench.costs[item]))
	_place("host", "deck", Vector2(480, 288))
	main.world.data.deck_tiles.append_array(["9,3", "9,4"])
	_check(main.world.data.structures.size() == 1, "fixture starts without a workbench")

func _host() -> void:
	var data: Dictionary = main.world.data
	match phase:
		90:
			if data.players.guest.online:
				_place("guest", "deck", Vector2(515, 263))
				host_bag_before = data.players.guest.bag.duplicate(true)
				_signal_client("blocked")
				_next()
		91:
			if remote_stage == "blocked" and _age() > 0.5:
				if not _check(data.players.guest.bag == host_bag_before, "guest cannot bypass absent station over real RPC"):
					return
				main.perform("craft", {"recipe": "workbench", "x": 480.0, "y": 224.0})
				if not _check(data.structures.get("structure_0", {}).get("kind") == "workbench", "host builds shared station with recipe costs"):
					return
				_signal_client("ready")
				_next()
		92:
			if remote_stage == "crafted" and _age() > 0.5:
				if not _check(Inventory.count(data.players.guest.bag, "fins") == 1 and Inventory.count(data.players.guest.bag, "ingot") == 0, "guest makes one upgrade and spends own ingredients"):
					return
				# Add raw costs only for a second, intentionally stale request.
				for item in Recipes.ALL.fins.costs:
					Inventory.add(data.players.guest.bag, item, int(Recipes.ALL.fins.costs[item]))
				host_bag_before = data.players.guest.bag.duplicate(true)
				main.perform("relocate", {"id": "structure_0", "from_x": 480.0, "from_y": 224.0, "x": 608.0, "y": 288.0})
				if not _check(data.structures.structure_0.x == 608.0, "host moves the station out of guest range"):
					return
				_signal_client("moved")
				_next()
		93:
			if remote_stage == "stale" and _age() > 0.5:
				if not _check(data.players.guest.bag == host_bag_before, "stale guest crafting after a host move cannot spend materials"):
					return
				_place("host", "deck", Vector2(544, 288))
				main.perform("craft", {"recipe": "fins"})
				if not _check(Inventory.count(data.players.host.bag, "fins") == 1, "host independently uses moved shared workbench"):
					return
				expected = _persistent_fields(data)
				if not main._persist():
					_fail("workbench save failed")
					return
				var manifest := FileAccess.open(str(main.save_path) + ".expected.json", FileAccess.WRITE)
				manifest.store_string(JSON.stringify(expected, "", false, true))
				manifest.close()
				_signal_client("saved")
				_next()
		94:
			if not data.players.guest.online:
				_finish()

func _client() -> void:
	var data: Dictionary = main.current_state()
	if data.is_empty() or not data.players.guest.online:
		return
	match phase:
		0:
			if server_stage == "blocked":
				_check(not Recipes.station_available(data, "guest", "fins"), "client sees handcraft-only availability")
				main.perform("craft", {"recipe": "fins"})
				client_stage.rpc_id(1, "blocked")
				_next()
		1:
			if server_stage == "ready" and data.structures.has("structure_0"):
				_check(Recipes.station_available(data, "guest", "fins"), "client sees host-built station nearby")
				main.perform("craft", {"recipe": "fins"})
				client_stage.rpc_id(1, "crafted")
				_next()
		2:
			if server_stage == "moved" and data.structures.structure_0.x == 608.0:
				_check(not Recipes.station_available(data, "guest", "fins"), "client sees moved station out of range")
				main.perform("craft", {"recipe": "fins"})
				client_stage.rpc_id(1, "stale")
				_next()
		3:
			if server_stage == "saved":
				if not _check(Inventory.count(data.players.guest.bag, "fins") == 1 and Inventory.count(data.players.host.bag, "fins") == 1, "both independently crafted upgrades synchronise"):
					return
				_finish()

func _resume() -> void:
	var data: Dictionary = main.world.data
	_check(_json_fields(_persistent_fields(data)) == _json_fields(expected), "separate solo process restores station and ordered personal bags")
	_check(data.structures.structure_0.kind == "workbench" and data.structures.structure_0.x == 608.0, "moved station survives disk save")
	_check(Inventory.count(data.players.guest.bag, "fins") == 1 and Inventory.count(data.players.host.bag, "fins") == 1, "both saved upgrades survive guest disconnect")
	if not finished:
		_finish()

func _persistent_fields(data: Dictionary) -> Dictionary:
	return {"structures": data.structures.duplicate(true), "host_bag": data.players.host.bag.duplicate(true), "guest_bag": data.players.guest.bag.duplicate(true)}

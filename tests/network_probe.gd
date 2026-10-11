extends Node

const Inventory = preload("res://scripts/inventory.gd")

var main: Node
var role := ""
var phase := 0
var start_ms := 0
var phase_ms := 0
var rest_minute := 0.0
var fish_id := ""
var checks: Array[String] = []
var fish_bag_index := -1
var fish_chest_index := -1
var host_bag_before: Array = []
var chest_before: Array = []

func _ready() -> void:
	main = get_parent()
	role = str(main.cli["test-role"])
	if not main.cli.has("save-path") or ProjectSettings.globalize_path(str(main.save_path)) in [ProjectSettings.globalize_path("user://world_v1.json"), ProjectSettings.globalize_path("user://world_v2.json"), ProjectSettings.globalize_path("user://world_v3.json"), ProjectSettings.globalize_path("user://world_v4.json"), ProjectSettings.globalize_path("user://world_v5.json"), ProjectSettings.globalize_path("user://world_v6.json"), ProjectSettings.globalize_path("user://world_v7.json")]:
		_fail("network tests require an isolated save path, never the player default")
		return
	start_ms = Time.get_ticks_msec()
	phase_ms = start_ms
	if role == "host":
		main.nickname.text = "验证船长"
		if not main._start("host", false):
			_fail("host startup")
			return
		# Network regression fixture: preserve an existing large raft and shared chest.
		# The survival playthrough separately proves gathering and constructing these from nothing.
		var old: Dictionary = main.world.snapshot()
		old.version = 2
		for id in old.entities.keys():
			if old.entities[id].kind in ["ore", "stone", "wreck"]:
				old.entities.erase(id)
		for key in ["deck_tiles", "structures", "drift", "navigation", "chart", "island"]:
			old.erase(key)
		var slots := Inventory.empty_slots(Inventory.CHEST_SIZE)
		Inventory.add(slots, "seed", 3)
		old.chests = {"chest_0": {"id": "chest_0", "name": "共享木箱", "x": 420.0, "y": 175.0, "slots": slots}}
		for player in old.players.values():
			for key in ["hunger", "thirst", "hook", "activity", "notice", "notice_id"]:
				player.erase(key)
			player.x = 475.0
			player.y = 390.0
		if not main.world.restore(old):
			_fail("legacy multiplayer fixture migration")
			return
		main.world.join("host", "验证船长")
		Inventory.add(main.world.data.players.guest.bag, "harpoon", 1)
	elif role == "client":
		main.nickname.text = "验证伙伴"
		main.address.text = "127.0.0.1"
		main._join()
	elif role == "resume":
		if not main._start("solo", true):
			_fail("resume existing world")
			return
		if int(main.world.data.day) != 2 or Inventory.count(main.world.data.players.guest.bag, "fish") != 1:
			_fail("persisted day and guest catch")
			return
		_check("saved day and guest inventory restored")
		if main.world.data.players.guest.online:
			_fail("offline guest not restored offline")
			return
	else:
		_fail("unknown test role")

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - start_ms > 80000:
		_fail("timeout at phase %d (%s)" % [phase, role])
		return
	if role == "host":
		_host()
	elif role == "client":
		_client()
	elif role == "resume":
		_resume()

func _host() -> void:
	var data: Dictionary = main.current_state()
	match phase:
		0:
			if data.players.guest.online and _walk(Vector2(230, 216)):
				main.perform("rest")
				rest_minute = float(data.minute)
				_next()
		1:
			if data.players.guest.area == "water" and _age() > 0.5:
				if not data.players.host.resting or float(data.minute) <= rest_minute:
					_fail("rest did not preserve moving world time")
					return
				_check("host rests on deck while guest dives and world advances")
				main.perform("sleep")
				_next()
		2:
			if _age() > 0.5:
				if int(data.day) != 1 or not data.players.host.sleep_ready:
					_fail("one sleeping player ended day")
					return
				_check("one ready player does not end the day")
				_next()
		3:
			if int(data.day) == 2:
				if Inventory.count(data.players.guest.bag, "fish") != 1 or Inventory.count(data.players.host.bag, "fish") != 0 or Inventory.count(data.chests.chest_0.slots, "fish") != 0:
					_fail("shared chest round trip did not preserve independent bags at day transition")
					return
				if not FileAccess.file_exists(main.save_path):
					_fail("day transition did not automatically save")
					return
				if data.players.host.sleep_ready or data.players.guest.sleep_ready:
					_fail("sleep flags not cleared at day transition")
					return
				_check("two ready players advance exactly one day")
				_next()
		4:
			if not data.players.guest.online:
				if Inventory.count(data.players.guest.bag, "fish") != 1:
					_fail("guest inventory lost on disconnect")
					return
				_check("disconnect preserves guest bag and clears online membership")
				if not main._persist():
					_fail("save failed")
					return
				_finish()

func _client() -> void:
	if main.mode != "client" or main.received.is_empty():
		return
	var data: Dictionary = main.current_state()
	var player: Dictionary = data.players.guest
	match phase:
		0:
			if _walk(Vector2(746, 410)):
				main.perform("dive")
				_next()
		1:
			if player.area == "water":
				fish_id = "fish_00"
				_check("guest independently enters water")
				_next()
		2:
			var entity: Dictionary = data.entities[fish_id]
			if _walk(Vector2(float(entity.x), float(entity.y))):
				main.perform("spear", {"x": 1.0, "y": 0.0})
				_next()
		3:
			if Inventory.count(player.bag, "fish") == 1:
				if bool(data.entities[fish_id].active):
					_fail("caught fish remains active")
					return
				_check("authoritative catch reflected in guest inventory and shared world")
				_next()
		4:
			if data.players.host.sleep_ready and _walk(Vector2(120, 65)):
				main.perform("surface")
				_next()
		5:
			if player.area == "deck" and _walk(Vector2(466, 175)):
				fish_bag_index = _find_item(player.bag, "fish")
				fish_chest_index = _find_empty(data.chests.chest_0.slots)
				if fish_bag_index < 0 or fish_chest_index < 0:
					_fail("no slot available for guest chest round trip")
					return
				host_bag_before = data.players.host.bag.duplicate(true)
				chest_before = data.chests.chest_0.slots.duplicate(true)
				main.perform("inventory_move", {
					"from_container": "bag", "from_index": fish_bag_index,
					"to_container": "chest_0", "to_index": fish_chest_index,
					"amount": 1, "expected_item": "fish",
				})
				_next()
		6:
			if _age() > 0.2 and Inventory.count(player.bag, "fish") == 0 and Inventory.count(data.chests.chest_0.slots, "fish") == 1:
				if data.players.host.bag != host_bag_before or Inventory.count(data.chests.chest_0.slots, "seed") != Inventory.count(chest_before, "seed"):
					_fail("guest deposit changed the host bag or unrelated chest items")
					return
				_check("guest deposits one fish through the host-authoritative inventory RPC")
				main.perform("inventory_move", {
					"from_container": "chest_0", "from_index": fish_chest_index,
					"to_container": "bag", "to_index": fish_bag_index,
					"amount": 1, "expected_item": "fish",
				})
				_next()
		7:
			if Inventory.count(player.bag, "fish") == 1 and Inventory.count(data.chests.chest_0.slots, "fish") == 0:
				if data.players.host.bag != host_bag_before or data.chests.chest_0.slots != chest_before:
					_fail("guest retrieval failed to preserve the host bag and original chest slot order")
					return
				_check("guest retrieves the same fish; host backpack and original chest slots stay unchanged")
				_next()
		8:
			if _walk(Vector2(305, 216)):
				main.perform("sleep")
				_next()
		9:
			if int(data.day) == 2:
				if Inventory.count(player.bag, "fish") != 1:
					_fail("sleep lost the retrieved fish")
					return
				_check("guest receives common new day")
				main._toggle_pause()
				rest_minute = float(data.minute)
				_next()
		10:
			if _age() > 0.8:
				if float(data.minute) <= rest_minute:
					_fail("guest personal menu paused world")
					return
				_check("guest personal menu does not pause world")
				_finish()

func _resume() -> void:
	var data: Dictionary = main.current_state()
	match phase:
		0:
			main._toggle_pause()
			rest_minute = float(data.minute)
			_next()
		1:
			if _age() > 0.7:
				if not is_equal_approx(rest_minute, float(data.minute)):
					_fail("solo menu failed to pause world")
					return
				_check("solo menu pauses world")
				main._toggle_pause()
				_next()
		2:
			if _walk(Vector2(230, 216)):
				main.perform("sleep")
				_next()
		3:
			if int(data.day) == 3:
				_check("solo continuation sleeps without waiting for offline guest")
				_finish()

func _walk(target: Vector2) -> bool:
	var data: Dictionary = main.current_state()
	var player: Dictionary = data.players[main.local_slot]
	var offset := target - Vector2(float(player.x), float(player.y))
	if offset.length() < 26.0:
		main.automation_input = Vector2.ZERO
		return true
	main.automation_input = offset.normalized()
	return false

func _find_item(slots: Array, item: String) -> int:
	for index in slots.size():
		if not slots[index].is_empty() and str(slots[index].item) == item:
			return index
	return -1

func _find_empty(slots: Array) -> int:
	for index in slots.size():
		if slots[index].is_empty():
			return index
	return -1

func _age() -> float:
	return float(Time.get_ticks_msec() - phase_ms) / 1000.0

func _next() -> void:
	phase += 1
	phase_ms = Time.get_ticks_msec()
	print("NETWORK ", role, " phase=", phase)

func _check(description: String) -> void:
	checks.append(description)
	print("PASS ", role, ": ", description)

func _finish() -> void:
	set_process(false)
	main.automation_input = Vector2.ZERO
	var path: String = str(main.cli.get("report", ""))
	if not path.is_empty():
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"role": role, "checks": checks, "day": main.current_state().day, "elapsed_ms": Time.get_ticks_msec() - start_ms}, "\t"))
		file.close()
	print("NETWORK PASS ", role, " checks=", checks.size())
	get_tree().quit(0)

func _fail(description: String) -> void:
	set_process(false)
	push_error("NETWORK FAIL " + role + ": " + description)
	get_tree().quit(1)

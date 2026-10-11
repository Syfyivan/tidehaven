extends Node
## Controlled layout/material/position fixture, not a normal progression playthrough.
## Actions under test use main.perform and the real ENet action RPC. Driver RPCs only synchronise stages.

const Inventory = preload("res://scripts/inventory.gd")
const ORE_ID := "ore_00"
const WRECK_ID := "wreck_00"
const FURNACE_ID := "progression_furnace"
const CHEST_ID := "chest_0"
const CHEST_FROM := Vector2(416, 352)
const CHEST_TO := Vector2(544, 352)
const REPLAY_TARGET := Vector2(608, 352)

var main: Node
var role := ""
var phase := 0
var start_ms := 0
var phase_ms := 0
var smelt_ms := 0
var remote_stage := ""
var server_stage := ""
var checks: Array[String] = []
var host_bag_before: Array = []
var chest_before: Array = []
var expected: Dictionary = {}
var finished := false


func _ready() -> void:
	name = "ProgressionNetworkProbe"
	main = get_parent()
	role = str(main.cli.get("test-role", ""))
	start_ms = Time.get_ticks_msec()
	phase_ms = start_ms
	if not main.cli.has("save-path") or not main.cli.has("report"):
		_fail("isolated save-path and report are required")
		return
	for version in range(1, 10):
		if ProjectSettings.globalize_path(str(main.save_path)).to_lower() == ProjectSettings.globalize_path("user://world_v%d.json" % version).to_lower():
			_fail("never use a player default save")
			return
	match role:
		"host":
			main.nickname.text = "进阶验证船长"
			if not main._start("host", false):
				_fail("host startup")
				return
			_setup_fixture()
			phase = 90
			if finished:
				return
			var ready_file := FileAccess.open(str(main.cli.report) + ".ready", FileAccess.WRITE)
			if ready_file == null:
				_fail("cannot write host readiness marker")
				return
			ready_file.store_string("ready")
			ready_file.close()
			print("PROGRESSION READY host")
		"client":
			main.nickname.text = "进阶验证伙伴"
			main.address.text = "127.0.0.1"
			main._join()
		"resume":
			if not main._start("solo", true):
				_fail("solo save restoration")
				return
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(main.save_path) + ".expected.json"))
			if not parsed is Dictionary:
				_fail("missing saved-state comparison manifest")
				return
			expected = parsed
		_:
			_fail("unknown role")


func _setup_fixture() -> void:
	var data: Dictionary = main.world.data
	if not _check(int(data.version) == 10 and data.entities.has(WRECK_ID) and data.entities[ORE_ID].kind == "ore", "v7 underwater ore and wreck are present"):
		return
	data.deck_tiles = []
	for gx in range(5, 10):
		for gy in range(2, 7):
			data.deck_tiles.append("%d,%d" % [gx, gy])
	data.structures[FURNACE_ID] = main.world._new_structure(FURNACE_ID, "furnace", Vector2(544, 224))
	var contents: Array = Inventory.empty_slots(Inventory.CHEST_SIZE)
	contents[2] = {"item": "wood", "count": 7}
	contents[7] = {"item": "ore", "count": 2}
	contents[12] = {"item": "seed", "count": 3}
	data.chests[CHEST_ID] = main.world._new_chest(CHEST_ID, "进阶验证木箱", CHEST_FROM, contents)
	for slot in ["host", "guest"]:
		data.players[slot].bag = Inventory.empty_slots(Inventory.BAG_SIZE)
		Inventory.add(data.players[slot].bag, "fish" if slot == "host" else "wood", 3 if slot == "host" else 2)
		Inventory.add(data.players[slot].bag, "fins", 1)
		Inventory.add(data.players[slot].bag, "reinforced_hook", 1)
	Inventory.add(data.players.guest.bag, "paddle", 1)
	Inventory.add(data.players.guest.bag, "anchor", 1)
	host_bag_before = data.players.host.bag.duplicate(true)
	chest_before = contents.duplicate(true)
	_place("host", "deck", Vector2(544, 288))


func _process(_delta: float) -> void:
	if finished:
		return
	if Time.get_ticks_msec() - start_ms > 75000:
		_fail("timeout at phase %d, server=%s, client=%s" % [phase, server_stage, remote_stage])
		return
	if role == "host":
		_host()
	elif role == "client":
		_client()
	elif role == "resume":
		_resume()


@rpc("any_peer", "call_remote", "reliable")
func client_stage(stage: String) -> void:
	if role == "host" and multiplayer.get_remote_sender_id() == int(main.remote_peer):
		remote_stage = stage


@rpc("authority", "call_remote", "reliable")
func host_stage(stage: String) -> void:
	if role == "client":
		server_stage = stage


func _host() -> void:
	var data: Dictionary = main.world.data
	var furnace: Dictionary = data.structures[FURNACE_ID]
	match phase:
		90:
			if data.players.guest.online:
				_signal_client("paddle_ready")
				_next()
		91:
			if remote_stage == "paddle_sent":
				if not _check(float(data.players.guest.stamina) == 98 and float(data.navigation.push_y) < -5 and data.players.host.bag == host_bag_before, "guest paddle RPC steers host-owned raft; immediate replay spends stamina once"):
					return
				_signal_client("anchor_ready")
				_next()
		92:
			if remote_stage == "anchor_sent":
				if not _check(bool(data.navigation.anchored) and Inventory.count(data.players.guest.bag, "anchor") == 0, "guest deploy RPC and replay consume exactly one shared anchor"):
					return
				_place("host", "water", Vector2(120, 90))
				_signal_client("raise_blocked")
				_next()
		93:
			if remote_stage == "blocked_sent":
				if not _check(bool(data.navigation.anchored) and Inventory.count(data.players.guest.bag, "anchor") == 0, "guest cannot raise anchor while host dives independently"):
					return
				_place("host", "deck", Vector2(544, 288))
				_signal_client("raise_ready")
				_next()
		94:
			if remote_stage == "raised_sent":
				if not _check(not bool(data.navigation.anchored) and Inventory.count(data.players.guest.bag, "anchor") == 1, "guest retrieves anchor after both players return to deck"):
					return
				_signal_client("redrop_ready")
				_next()
		95:
			if remote_stage == "redrop_sent":
				if not _check(bool(data.navigation.anchored) and Inventory.count(data.players.guest.bag, "anchor") == 0, "guest redeploys same anchor before shared underwater exploration"):
					return
				data.players.guest.stamina = 100.0
				phase = 0

		0:
			if data.players.guest.online:
				var wreck: Dictionary = data.entities[WRECK_ID]
				_place("guest", "water", Vector2(float(wreck.x), float(wreck.y)))
				_signal_client("search_ready")
				_next()
		1:
			if remote_stage == "wreck_repeat_sent":
				if not _check(Inventory.count(data.players.guest.bag, "treasure") == 1 and not data.entities[WRECK_ID].active and data.players.host.bag == host_bag_before, "guest search and repeated RPC give exactly one treasure without changing host inventory"):
					return
				remote_stage = ""
				var ore: Dictionary = data.entities[ORE_ID]
				_place("guest", "water", Vector2(float(ore.x), float(ore.y)))
				_signal_client("mine_ready")
			if remote_stage == "mine_repeat_sent":
				if not _check(Inventory.count(data.players.guest.bag, "ore") == 1 and not data.entities[ORE_ID].active and data.players.host.bag == host_bag_before and float(data.players.guest.stamina) == 94.0, "guest mine RPC and replay award one ore; host bag and repeat stamina stay unchanged"):
					return
				_place("guest", "deck", Vector2(510, 260))
				_signal_client("smelt_ready")
				_next()
		2:
			if float(furnace.remaining) > 0.0 and furnace.output == "ingot":
				smelt_ms = Time.get_ticks_msec()
				if not _check(Inventory.count(data.players.guest.bag, "ore") == 0 and Inventory.count(data.players.guest.bag, "wood") == 1 and data.chests[CHEST_ID].slots == chest_before and data.players.host.bag == host_bag_before, "guest starts furnace through RPC using exactly personal ore and wood"):
					return
				_next()
		3:
			if remote_stage == "early_collect_sent":
				if not _check(float(furnace.remaining) > 0.0 and furnace.output == "ingot" and _ingots(data) == 0, "early collection RPC cannot bypass the furnace timer"):
					return
				_next()
		4:
			if remote_stage == "collect_sent":
				if not _check(Time.get_ticks_msec() - smelt_ms >= 14500 and Inventory.count(data.players.guest.bag, "ingot") == 1 and furnace.output == "", "guest receives the ingot only after a natural fifteen-second process"):
					return
				# The reliable barrier follows the guest's claim on the same channel.
				# The host immediately contests that same finished output in the authority queue.
				main.perform("collect_output", {"id": FURNACE_ID})
				if not _check(_ingots(data) == 1 and data.players.host.bag == host_bag_before and furnace.output == "", "host and guest cannot both receive the completed ingot"):
					return
				_place("guest", "deck", Vector2(448, 320))
				_signal_client("relocate_ready")
				_next()
		5:
			if remote_stage == "relocated":
				var chest: Dictionary = data.chests[CHEST_ID]
				if not _check(Vector2(float(chest.x), float(chest.y)) == CHEST_TO and chest.slots == chest_before, "guest relocation RPC preserves the exact sixteen-slot chest contents"):
					return
				# This point is within 64 px of BOTH old and new positions. The next target
				# is also free and reachable, so the stale from-coordinates cause rejection.
				_place("guest", "deck", Vector2(480, 352))
				if not _check(main.world.can_relocate("guest", CHEST_ID, CHEST_TO.x, CHEST_TO.y, REPLAY_TARGET.x, REPLAY_TARGET.y), "fresh source coordinates would allow the replay target"):
					return
				_signal_client("replay_ready")
				_next()
		6:
			if remote_stage == "relocate_replay_sent":
				var chest: Dictionary = data.chests[CHEST_ID]
				if not _check(Vector2(float(chest.x), float(chest.y)) == CHEST_TO and chest.slots == chest_before, "stale relocation source is rejected without changing position or slots"):
					return
				expected = _persistent_fields(data)
				if not main._persist() or not FileAccess.file_exists(str(main.save_path)):
					_fail("host save while guest remains connected")
					return
				var manifest := FileAccess.open(str(main.save_path) + ".expected.json", FileAccess.WRITE)
				if manifest == null:
					_fail("cannot write saved-state comparison manifest")
					return
				manifest.store_string(JSON.stringify(expected, "", false, true))
				manifest.close()
				_check(true, "host explicitly saves completed facilities and independent equipped bags")
				_signal_client("saved")
				_next()
		7:
			if not data.players.guest.online:
				if not _check(_persistent_fields(data) == expected, "guest disconnect preserves exact facility, chest and personal equipment state"):
					return
				if not main._persist():
					_fail("final host save after guest disconnect")
					return
				_finish()


func _client() -> void:
	if main.mode != "client" or main.received.is_empty():
		return
	var data: Dictionary = main.current_state()
	var player: Dictionary = data.players.guest
	var furnace: Dictionary = data.structures[FURNACE_ID]
	match phase:
		90:
			if _age() > 0.2 and server_stage == "anchor_ready" and float(player.stamina) == 98:
				if not _check(float(data.navigation.push_y) < -5, "client receives its paddle movement from authoritative snapshots"):
					return
				main.perform("drop_anchor")
				main.perform("drop_anchor")
				client_stage.rpc_id(1, "anchor_sent")
				phase = 91
				phase_ms = Time.get_ticks_msec()
		91:
			if _age() > 0.2 and server_stage == "raise_blocked" and data.players.host.area == "water":
				main.perform("raise_anchor")
				client_stage.rpc_id(1, "blocked_sent")
				phase = 92
				phase_ms = Time.get_ticks_msec()
		92:
			if _age() > 0.2 and server_stage == "raise_ready" and data.players.host.area == "deck":
				main.perform("raise_anchor")
				client_stage.rpc_id(1, "raised_sent")
				phase = 93
				phase_ms = Time.get_ticks_msec()
		93:
			if _age() > 0.2 and server_stage == "redrop_ready" and not bool(data.navigation.anchored):
				if not _check(Inventory.count(player.bag, "anchor") == 1, "client sees recovered anchor in its own bag"):
					return
				main.perform("drop_anchor")
				client_stage.rpc_id(1, "redrop_sent")
				phase = 94
				phase_ms = Time.get_ticks_msec()
		94:
			if server_stage == "search_ready" and bool(data.navigation.anchored):
				_check(true, "client sees anchored raft before diving")
				phase = 0

		0:
			if server_stage == "paddle_ready":
				main.perform("paddle", {"x": 0.0, "y": -1.0})
				main.perform("paddle", {"x": 0.0, "y": -1.0})
				client_stage.rpc_id(1, "paddle_sent")
				phase = 90
				phase_ms = Time.get_ticks_msec()
				return
			if server_stage == "search_ready" and player.area == "water":
				host_bag_before = data.players.host.bag.duplicate(true)
				main.perform("search_wreck", {"id": WRECK_ID})
				phase = 20
				phase_ms = Time.get_ticks_msec()
				return
			if server_stage == "mine_ready" and player.area == "water":
				host_bag_before = data.players.host.bag.duplicate(true)
				chest_before = data.chests[CHEST_ID].slots.duplicate(true)
				main.perform("mine", {"id": ORE_ID})
				_next()
		20:
			if _age() > 0.2 and Inventory.count(player.bag, "treasure") == 1 and not data.entities[WRECK_ID].active:
				if not _check(data.players.host.bag == host_bag_before, "client sees depleted wreck and recovered treasure in its own bag"):
					return
				main.perform("search_wreck", {"id": WRECK_ID})
				client_stage.rpc_id(1, "wreck_repeat_sent")
				phase = 21
				phase_ms = Time.get_ticks_msec()
		21:
			if _age() > 0.2 and server_stage == "mine_ready":
				phase = 0
		1:
			if _age() > 0.2 and Inventory.count(player.bag, "ore") == 1 and not data.entities[ORE_ID].active:
				if not _check(data.players.host.bag == host_bag_before, "client snapshot shows mined ore only in guest backpack"):
					return
				main.perform("mine", {"id": ORE_ID})
				client_stage.rpc_id(1, "mine_repeat_sent")
				_next()
		2:
			if _age() > 0.2 and server_stage == "smelt_ready" and player.area == "deck":
				main.perform("smelt", {"id": FURNACE_ID})
				_next()
		3:
			if _age() > 0.2 and float(furnace.remaining) > 0.0 and furnace.output == "ingot":
				_check(true, "client sees a running furnace with a pending ingot")
				main.perform("collect_output", {"id": FURNACE_ID})
				client_stage.rpc_id(1, "early_collect_sent")
				_next()
		4:
			if float(furnace.remaining) == 0.0 and furnace.output == "ingot":
				main.perform("collect_output", {"id": FURNACE_ID})
				client_stage.rpc_id(1, "collect_sent")
				_next()
		5:
			if _age() > 0.2 and server_stage == "relocate_ready" and Vector2(float(player.x), float(player.y)).is_equal_approx(Vector2(448, 320)):
				if not _check(Inventory.count(player.bag, "ingot") == 1 and _ingots(data) == 1, "client receives the single ingot despite a competing host claim"):
					return
				main.perform("relocate", _relocate_args(CHEST_TO))
				_next()
		6:
			var chest: Dictionary = data.chests[CHEST_ID]
			if Vector2(float(chest.x), float(chest.y)) == CHEST_TO:
				if not _check(chest.slots == chest_before, "client observes moved chest with unchanged sparse slot order"):
					return
				client_stage.rpc_id(1, "relocated")
				_next()
		7:
			if _age() > 0.2 and server_stage == "replay_ready" and Vector2(float(player.x), float(player.y)).is_equal_approx(Vector2(480, 352)):
				main.perform("relocate", _relocate_args(REPLAY_TARGET))
				client_stage.rpc_id(1, "relocate_replay_sent")
				_next()
		8:
			if server_stage == "saved":
				var chest: Dictionary = data.chests[CHEST_ID]
				if not _check(Vector2(float(chest.x), float(chest.y)) == CHEST_TO and chest.slots == chest_before and Inventory.count(player.bag, "fins") == 1 and Inventory.count(player.bag, "reinforced_hook") == 1, "stale request leaves shared chest and guest equipment intact before exit"):
					return
				_finish()


func _resume() -> void:
	var data: Dictionary = main.world.data
	if not _check(_json_fields(_persistent_fields(data)) == _json_fields(expected), "independent solo process restores exact v7 navigation and facilities, moved chest slots and both backpacks"):
		return
	if not _check(not data.players.guest.online and not data.entities[ORE_ID].active and _ingots(data) == 1, "resume preserves depleted deposit and single ingot with guest offline"):
		return
	if not _check(not data.entities[WRECK_ID].active and Inventory.count(data.players.guest.bag, "treasure") == 1, "resume preserves searched wreck and the single guest treasure"):
		return
	if not _check(Inventory.count(data.players.host.bag, "fins") == 1 and Inventory.count(data.players.host.bag, "reinforced_hook") == 1 and Inventory.count(data.players.guest.bag, "fins") == 1 and Inventory.count(data.players.guest.bag, "reinforced_hook") == 1, "personal equipment remains in the correct saved bags"):
		return
	_finish()


func _persistent_fields(data: Dictionary) -> Dictionary:
	return {"navigation": data.navigation.duplicate(true), "version": data.version, "deck_tiles": data.deck_tiles.duplicate(), "structures": data.structures.duplicate(true), "chests": data.chests.duplicate(true), "host_bag": data.players.host.bag.duplicate(true), "guest_bag": data.players.guest.bag.duplicate(true), "ore": data.entities[ORE_ID].duplicate(true), "wreck": data.entities[WRECK_ID].duplicate(true)}


func _json_fields(fields: Dictionary) -> Dictionary:
	# Godot JSON numbers are floats; restore normalises integral counts/version.
	# Compare both complete structures in the same JSON representation, without
	# rounding coordinates, dropping fields or aggregating the ordered bag slots.
	var normalised: Dictionary = JSON.parse_string(JSON.stringify(fields, "", true, true))
	return normalised


func _ingots(data: Dictionary) -> int:
	return Inventory.count(data.players.host.bag, "ingot") + Inventory.count(data.players.guest.bag, "ingot") + Inventory.count(data.chests[CHEST_ID].slots, "ingot")


func _relocate_args(target: Vector2) -> Dictionary:
	return {"id": CHEST_ID, "from_x": CHEST_FROM.x, "from_y": CHEST_FROM.y, "x": target.x, "y": target.y}


func _place(slot: String, area: String, point: Vector2) -> void:
	var player: Dictionary = main.world.data.players[slot]
	player.area = area
	player.x = point.x
	player.y = point.y
	player.resting = false
	player.sleep_ready = false
	main.world.set_move(slot, Vector2.ZERO)


func _signal_client(stage: String) -> void:
	main._send_snapshot()
	host_stage.rpc_id(int(main.remote_peer), stage)


func _age() -> float:
	return float(Time.get_ticks_msec() - phase_ms) / 1000.0


func _next() -> void:
	phase += 1
	phase_ms = Time.get_ticks_msec()
	print("PROGRESSION ", role, " phase=", phase)


func _check(condition: bool, description: String) -> bool:
	if not condition:
		_fail(description)
		return false
	checks.append(description)
	print("PASS ", role, ": ", description)
	return true


func _finish() -> void:
	var report := FileAccess.open(str(main.cli.report), FileAccess.WRITE)
	if report == null:
		_fail("cannot write passing report")
		return
	report.store_string(JSON.stringify({"passed": true, "role": role, "fixture": "controlled layout, raw materials, equipment and positions; actual ENet action RPCs", "checks": checks, "elapsed_ms": Time.get_ticks_msec() - start_ms}, "\t"))
	report.close()
	finished = true
	set_process(false)
	main.automation_input = Vector2.ZERO
	print("PROGRESSION NETWORK PASS ", role, " checks=", checks.size())
	get_tree().quit(0)


func _fail(description: String) -> void:
	finished = true
	set_process(false)
	push_error("PROGRESSION NETWORK FAIL " + role + ": " + description)
	get_tree().quit(1)

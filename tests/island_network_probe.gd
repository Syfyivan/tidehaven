extends Node
## Controlled starting tools/supplies, dock/actor positions and one drift object.
## Actual main.perform ENet actions and host ticks produce all rewards and growth.
## Driver RPCs are barriers only. This is not a normal-progression playthrough.
const Inventory = preload("res://scripts/inventory.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
const IslandState = preload("res://scripts/island_state.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const Farming = preload("res://scripts/farming.gd")
const DRIFT_ID := "drift_06"
const DECK_EDGE := Vector2(544, 352)
const FRESHWATER := Vector2(640, 430)
const FARM_POINT := Vector2(496, 336)
const FARM_KEY := "15,10"
const HOOK_POINT := Vector2(520, 224)
var main: Node
var role := ""
var phase := "start"
var start_ms := 0
var phase_ms := 0
var remote_stage := ""
var server_stage := ""
var checks: Array[String] = []
var host_bag_before: Array = []
var race_stamina := 0.0
var hook_staged := false
var expected: Dictionary = {}
var finished := false


func _ready() -> void:
	name = "IslandNetworkProbe"
	main = get_parent()
	role = str(main.cli.get("test-role", ""))
	start_ms = Time.get_ticks_msec()
	phase_ms = start_ms
	var allowed := ProjectSettings.globalize_path("res://artifacts/").replace("\\", "/").to_lower()
	for argument in ["save-path", "report"]:
		var path := ProjectSettings.globalize_path(str(main.cli.get(argument, ""))).replace("\\", "/").to_lower()
		if not path.begins_with(allowed):
			_fail("isolated artifact save-path and report are required")
			return
	match role:
		"host":
			main.nickname.text = "登岛验证船长"
			if not main._start("host", false):
				_fail("host startup")
				return
			_setup_fixture()
			if finished:
				return
			var marker := FileAccess.open(str(main.cli.report) + ".ready", FileAccess.WRITE)
			if marker == null:
				_fail("cannot write host readiness marker")
				return
			marker.store_string("ready")
			marker.close()
			print("ISLAND READY host")
		"client":
			main.nickname.text = "登岛验证伙伴"
			main.address.text = "127.0.0.1"
			main._join()
		"resume":
			if not main._start("solo", true):
				_fail("solo save restoration")
				return
			var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(main.save_path) + ".expected.json"))
			if not manifest is Dictionary:
				_fail("missing saved-state comparison manifest")
				return
			expected = manifest
		_:
			_fail("unknown role")


func _setup_fixture() -> void:
	var data: Dictionary = main.world.data
	if not _check(int(data.version) == 10 and data.island.depleted.is_empty() and data.island.plots.is_empty(), "fresh v10 chart has sparse empty island progress"):
		return
	if not _check(IslandMap.tillable(FARM_POINT) and IslandMap.water_near(FRESHWATER), "controlled farm clearing and freshwater bank are valid map locations"):
		return
	var target: Vector2 = Archipelago.island_position(data.chart)
	data.navigation.x = target.x
	data.navigation.y = target.y
	for slot in ["host", "guest"]:
		data.players[slot].bag = Inventory.empty_slots(Inventory.BAG_SIZE)
		for item in ["axe", "pickaxe", "watering_can"]:
			Inventory.add(data.players[slot].bag, item, 1)
	Inventory.add(data.players.host.bag, "fish", 3)
	Inventory.add(data.players.host.bag, "anchor", 1)
	Inventory.add(data.players.host.bag, "scythe", 1)
	Inventory.add(data.players.guest.bag, "hoe", 1)
	Inventory.add(data.players.guest.bag, "seed", 2)
	Inventory.add(data.players.guest.bag, "rope", 1)
	_place("host", "deck", DECK_EDGE)
	main.perform("drop_anchor")
	host_bag_before = data.players.host.bag.duplicate(true)
	_check(bool(data.navigation.anchored) and not bool(data.navigation.moored) and _count(data, "host", "anchor") == 0, "fixture deploys one real anchor at the first-island docking target")


func _process(_delta: float) -> void:
	if finished:
		return
	if Time.get_ticks_msec() - start_ms > 70000:
		_fail("timeout at phase %s; server=%s, client=%s" % [phase, server_stage, remote_stage])
		return
	match role:
		"host": _host()
		"client": _client()
		"resume": _resume()


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
	var guest: Dictionary = data.players.guest
	var captain: Dictionary = data.players.host
	match phase:
		"start":
			if guest.online:
				_place("guest", "deck", DECK_EDGE)
				_signal_client("land_ready")
				_next("guest_landing")
		"guest_landing":
			if remote_stage == "landed":
				if not _check(guest.area == "island" and captain.area == "deck" and bool(data.chart.visited), "guest lands through RPC while host remains on the raft"):
					return
				main.perform("raise_anchor")
				if not _check(bool(data.navigation.anchored) and captain.bag == host_bag_before, "host cannot recover the anchor while the connected guest is ashore"):
					return
				_place("guest", "island", _node_point("palm_0"))
				_signal_client("gather_ready")
				_next("guest_working")
		"guest_working":
			if remote_stage == "gather_started":
				if not _check(guest.activity.get("id") == "palm_0" and float(guest.activity.remaining) > 4.0 and _count(data, "guest", "wood") == 0 and float(guest.stamina) == 100.0 and IslandState.active(data.island, "palm_0", int(data.day)), "real guest RPC starts a six-second axe action without initial cost or reward"):
					return
				_next("guest_collection")
		"guest_collection":
			if remote_stage == "gather_replay_sent":
				if not _check(_count(data, "guest", "wood") == 3 and int(data.island.depleted.get("palm_0", 0)) == 4 and float(guest.stamina) == 94.0 and guest.activity.is_empty() and captain.bag == host_bag_before, "completed guest collection and delayed replay grant three wood once, paying six stamina only once"):
					return
				_place("guest", "island", IslandState.DOCK)
				_signal_client("return_ready")
				_next("guest_boarding")
		"guest_boarding":
			if remote_stage == "boarded":
				if not _check(guest.area == "deck" and _count(data, "guest", "wood") == 3, "guest boarding RPC returns with its collected supplies"):
					return
				main.perform("raise_anchor")
				if not _check(not bool(data.navigation.anchored) and _count(data, "host", "anchor") == 1, "host retrieves exactly one reusable anchor once both players are aboard"):
					return
				_place("guest", "deck", DECK_EDGE)
				_signal_client("moor_ready")
				_next("guest_mooring")
		"guest_mooring":
			if remote_stage == "moored":
				if not _check(bool(data.navigation.anchored) and bool(data.navigation.moored) and _count(data, "guest", "rope") == 0 and _count(data, "host", "anchor") == 1, "guest mooring RPC consumes its own rope while the recovered anchor stays in host's bag"):
					return
				main.perform("raise_anchor")
				if not _check(bool(data.navigation.moored) and _count(data, "host", "anchor") == 1, "anchor action cannot convert a deployed mooring rope into another anchor"):
					return
				_place("host", "deck", DECK_EDGE)
				main.perform("land", {"id": Archipelago.HOME_ID})
				if not _check(captain.area == "island" and guest.area == "deck", "host lands independently while guest remains on the moored raft"):
					return
				_signal_client("host_ashore")
				_next("guest_release_blocked")
		"guest_release_blocked":
			if remote_stage == "unmoor_blocked":
				if not _check(bool(data.navigation.moored) and _count(data, "guest", "rope") == 0, "guest unmoor RPC is rejected while host remains ashore"):
					return
				_place("host", "island", _node_point("palm_1"))
				main.perform("gather_island", {"id": "palm_1"})
				if not _check(captain.activity.get("id") == "palm_1" and _count(data, "host", "fiber") == 0, "role-reversed host gathering also waits for its scythe action"):
					return
				_next("host_collection")
		"host_collection":
			if captain.activity.is_empty() and _count(data, "host", "fiber") == 3:
				main.perform("gather_island", {"id": "palm_1"})
				if not _check(int(data.island.depleted.get("palm_1", 0)) == 3 and float(captain.stamina) == 97.0 and _count(data, "host", "fiber") == 3 and _count(data, "guest", "fiber") == 0, "host's completed scythe collection is personal and repeated claims do not duplicate fiber"):
					return
				_signal_client("join_island")
				_next("both_ashore")
		"both_ashore":
			if remote_stage == "landed_again":
				if not _check(guest.area == "island" and captain.area == "island", "both actors can explore the same island concurrently"):
					return
				for slot in ["host", "guest"]:
					_place(slot, "island", _node_point("stone_0"))
				race_stamina = float(captain.stamina) + float(guest.stamina)
				_signal_client("race_ready")
				_next("race_start")
		"race_start":
			if remote_stage == "race_started":
				main.perform("gather_island", {"id": "stone_0"})
				if not _check(captain.activity.get("id") == "stone_0" and guest.activity.get("id") == "stone_0" and _count(data, "host", "stone") + _count(data, "guest", "stone") == 0, "host and real client simultaneously work one live stone node without early awards"):
					return
				_signal_client("race_running")
				_next("race_finish")
		"race_finish":
			if captain.activity.is_empty() and guest.activity.is_empty():
				var host_stone := _count(data, "host", "stone")
				var guest_stone := _count(data, "guest", "stone")
				if not _check(host_stone + guest_stone == 3 and (host_stone == 0 or guest_stone == 0) and int(data.island.depleted.get("stone_0", 0)) == 4, "competing collection grants exactly one intact three-stone reward"):
					return
				if not _check(is_equal_approx(float(captain.stamina) + float(guest.stamina), race_stamina - 6.0), "only the winning collector pays the mining stamina cost"):
					return
				for slot in ["host", "guest"]:
					_place(slot, "island", FRESHWATER)
				main.perform("refill_can", _at(FRESHWATER))
				if not _check(int(captain.can_water) == 20 and int(guest.can_water) == 0, "host refill changes only its own held watering can"):
					return
				_signal_client("refill_ready")
				_next("guest_refill")
		"guest_refill":
			if remote_stage == "refilled":
				if not _check(int(guest.can_water) == 20 and int(captain.can_water) == 20 and _count(data, "guest", "watering_can") == 1, "guest freshwater refill RPC fills its own can without changing the host's water"):
					return
				_place("guest", "island", FARM_POINT)
				_signal_client("till_ready")
				_next("guest_till")
		"guest_till":
			if remote_stage == "tilled":
				if not _check(data.island.plots.size() == 1 and _plot(data) == Farming.new_plot() and _count(data, "guest", "seed") == 2, "client hoe RPC opens exactly one empty grid cell without consuming seeds"):
					return
				_signal_client("plant_ready")
				_next("guest_plant")
		"guest_plant":
			if remote_stage == "planted":
				if not _check(_plot(data).crop == "seed" and int(_plot(data).growth) == 0 and _count(data, "guest", "seed") == 1, "client planting RPC spends exactly one spring seed on its selected cell"):
					return
				_signal_client("water_ready")
				_next("guest_water")
		"guest_water":
			if remote_stage == "watered":
				if not _check(bool(_plot(data).watered) and int(guest.can_water) == 19 and int(captain.can_water) == 20, "client watering RPC consumes one personal water charge only"):
					return
				_place("host", "island", FARM_POINT)
				main.perform("water", _at(FARM_POINT))
				if not _check(int(captain.can_water) == 20 and int(guest.can_water) == 19 and int(_plot(data).growth) == 0, "repeated watering of the same cell neither consumes host water nor advances growth"):
					return
				for slot in ["host", "guest"]:
					_place(slot, "island", IslandState.CAMP)
				_signal_client("sleep_ready")
				_next("one_sleeping")
		"one_sleeping":
			if remote_stage == "sleep_sent" and _age() > 0.8:
				if not _check(bool(guest.sleep_ready) and not bool(captain.sleep_ready) and int(data.day) == 1 and int(_plot(data).growth) == 0 and bool(_plot(data).watered), "one actor's camp sleep RPC leaves the day and watered seedling unchanged"):
					return
				main.perform("sleep")
				if not _check(int(data.day) == 2 and int(_plot(data).growth) == 1 and not bool(_plot(data).watered) and not Farming.mature(_plot(data)), "both camp sleep actions advance one real day and grow the watered crop exactly once"):
					return
				if not _check(int(captain.can_water) == 20 and int(guest.can_water) == 19 and _count(data, "guest", "veg") == 0, "ending the day does not refill personal cans or award immature crops"):
					return
				_signal_client("new_day")
				_next("day_seen")
		"day_seen":
			if remote_stage == "day_observed":
				for slot in ["host", "guest"]:
					_place(slot, "island", IslandState.DOCK)
				main.perform("board_raft")
				_signal_client("board_final")
				_next("both_boarded")
		"both_boarded":
			if remote_stage == "board_final_done":
				if not _check(captain.area == "deck" and guest.area == "deck" and int(_plot(data).growth) == 1, "both actors return to the raft while the island crop keeps its daily progress"):
					return
				_signal_client("unmoor_ready")
				_next("guest_unmoor")
		"guest_unmoor":
			if remote_stage == "unmoored":
				if not _check(not bool(data.navigation.anchored) and not bool(data.navigation.moored) and _count(data, "guest", "rope") == 1 and _count(data, "host", "anchor") == 1, "successful client unmoor RPC returns exactly its original rope once both actors are aboard"):
					return
				main.perform("drop_anchor")
				if not _check(bool(data.navigation.anchored) and not bool(data.navigation.moored) and _count(data, "host", "anchor") == 0, "host can redeploy its separate reusable anchor after unmooring"):
					return
				_place("guest", "deck", HOOK_POINT)
				# Isolate this directional hook regression from random passing cargo.
				for item in data.drift.values():
					item.active = false
					item.respawn = 7.0
				_signal_client("hook_ready")
				_next("hook_working")
		"hook_working":
			if not guest.hook.is_empty() and not hook_staged:
				# Stage a real supply ahead of the thrown hook, never assign hook cargo.
				var item: Dictionary = data.drift[DRIFT_ID]
				var point := _point(guest.hook) + Vector2(0, -70)
				item.x = point.x
				item.y = point.y
				item.active = true
				item.respawn = 0.0
				item.speed = 12.0
				item.sway = 4.0
				item.phase = fposmod(PI / 2.0 - float(data.elapsed) * 0.45, TAU)
				hook_staged = true
			if remote_stage == "manual_pulled" and _count(data, "guest", "leaf") == 2 and not data.drift[DRIFT_ID].active:
				if not _check(guest.hook.is_empty() and _count(data, "guest", "wood") == 3 and _count(data, "guest", "seed") == 1 and _count(data, "host", "fiber") == 3 and _count(data, "host", "fish") == 3, "directional hook and pull RPCs complete once while each island reward stays in its own bag"):
					return
				expected = _persistent_fields(data)
				if not main._persist():
					_fail("host save after island farming and hook RPCs")
					return
				var manifest := FileAccess.open(str(main.save_path) + ".expected.json", FileAccess.WRITE)
				if manifest == null:
					_fail("cannot write saved-state comparison manifest")
					return
				manifest.store_string(JSON.stringify(expected, "", true, true))
				manifest.close()
				_check(true, "host saves exact v10 day, crop cell, resource regrowth dates, cans, chart, navigation and ordered bags")
				_signal_client("saved")
				_next("guest_disconnect")
		"guest_disconnect":
			if not guest.online:
				if not _check(_persistent_fields(data) == expected, "guest disconnect preserves farm progress, depleted nodes, each can and each personal inventory"):
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
	match phase:
		"start":
			if server_stage == "land_ready" and player.area == "deck" and _point(player).is_equal_approx(DECK_EDGE):
				host_bag_before = data.players.host.bag.duplicate(true)
				main.perform("land", {"id": Archipelago.HOME_ID})
				_next("landing")
		"landing":
			if player.area == "island" and bool(data.chart.visited):
				if not _check(_point(player) == IslandState.DOCK and data.players.host.area == "deck", "client receives its island arrival and the independently docked host"):
					return
				client_stage.rpc_id(1, "landed")
				_next("gather_start")
		"gather_start":
			if _age() > 0.2 and server_stage == "gather_ready" and _point(player).is_equal_approx(_node_point("palm_0")):
				main.perform("gather_island", {"id": "palm_0"})
				_next("gather_pending")
		"gather_pending":
			if player.activity.get("id") == "palm_0":
				if not _check(float(player.activity.duration) == 6.0 and _count(data, "guest", "wood") == 0 and float(player.stamina) == 100.0, "client observes actual six-second axe progress before any wood or stamina cost"):
					return
				client_stage.rpc_id(1, "gather_started")
				_next("gather_finish")
		"gather_finish":
			if _age() > 0.2 and _count(data, "guest", "wood") == 3 and player.activity.is_empty():
				if not _check(int(data.island.depleted.get("palm_0", 0)) == 4 and float(player.stamina) == 94.0 and data.players.host.bag == host_bag_before, "client receives its completed wood reward and unchanged host bag"):
					return
				# Outside the RPC rate gate, proving depleted-node idempotency.
				main.perform("gather_island", {"id": "palm_0"})
				client_stage.rpc_id(1, "gather_replay_sent")
				_next("returning")
		"returning":
			if _age() > 0.2 and server_stage == "return_ready" and _point(player).is_equal_approx(IslandState.DOCK):
				main.perform("board_raft")
				_next("boarded")
		"boarded":
			if player.area == "deck":
				client_stage.rpc_id(1, "boarded")
				_next("moor_start")
		"moor_start":
			if _age() > 0.2 and server_stage == "moor_ready" and _point(player).is_equal_approx(DECK_EDGE):
				main.perform("moor")
				_next("mooring")
		"mooring":
			if bool(data.navigation.moored):
				if not _check(_count(data, "guest", "rope") == 0 and _count(data, "host", "anchor") == 1, "client sees its rope deployed separately from host's recovered anchor"):
					return
				client_stage.rpc_id(1, "moored")
				_next("blocked_release")
		"blocked_release":
			if _age() > 0.2 and server_stage == "host_ashore" and data.players.host.area == "island" and player.area == "deck":
				main.perform("unmoor")
				client_stage.rpc_id(1, "unmoor_blocked")
				_next("join_host")
		"join_host":
			if _age() > 0.2 and server_stage == "join_island":
				if not _check(bool(data.navigation.moored) and _count(data, "host", "fiber") == 3 and _count(data, "guest", "fiber") == 0, "client remains moored while host finishes its separate fiber harvest"):
					return
				main.perform("land", {"id": Archipelago.HOME_ID})
				_next("second_landing")
		"second_landing":
			if player.area == "island":
				client_stage.rpc_id(1, "landed_again")
				_next("race_start")
		"race_start":
			if _age() > 0.2 and server_stage == "race_ready" and _point(player).is_equal_approx(_node_point("stone_0")):
				main.perform("gather_island", {"id": "stone_0"})
				_next("race_pending")
		"race_pending":
			if player.activity.get("id") == "stone_0":
				client_stage.rpc_id(1, "race_started")
				_next("race_concurrent")
		"race_concurrent":
			if server_stage == "race_running" and data.players.host.activity.get("id") == "stone_0":
				if not _check(player.activity.get("id") == "stone_0" and _count(data, "host", "stone") + _count(data, "guest", "stone") == 0, "client sees both pickaxe actions on one node before any reward"):
					return
				_next("refill_start")
		"refill_start":
			if _age() > 0.2 and server_stage == "refill_ready" and _point(player).is_equal_approx(FRESHWATER):
				if not _check(_count(data, "host", "stone") + _count(data, "guest", "stone") == 3 and int(data.island.depleted.get("stone_0", 0)) == 4 and player.activity.is_empty() and data.players.host.activity.is_empty(), "client sees one mining reward and both conflicting actions stopped"):
					return
				if not _check(int(player.can_water) == 0 and int(data.players.host.can_water) == 20, "client's empty watering can stays independent of host refill"):
					return
				main.perform("refill_can", _at(FRESHWATER))
				_next("refilling")
		"refilling":
			if int(player.can_water) == 20:
				if not _check(int(data.players.host.can_water) == 20, "client refill RPC returns both independent full-can counts"):
					return
				client_stage.rpc_id(1, "refilled")
				_next("till_start")
		"till_start":
			if _age() > 0.2 and server_stage == "till_ready" and _point(player).is_equal_approx(FARM_POINT):
				_next("tilling")
				_use_held_at.call_deferred("hoe", FARM_POINT)
		"tilling":
			if data.island.plots.has(FARM_KEY):
				if not _check(_plot(data) == Farming.new_plot() and data.island.plots.size() == 1, "client receives precisely the one newly tilled soil cell"):
					return
				client_stage.rpc_id(1, "tilled")
				_next("plant_start")
		"plant_start":
			if _age() > 0.2 and server_stage == "plant_ready":
				_next("planting")
				_use_held_at.call_deferred("seed", FARM_POINT)
		"planting":
			if _plot(data).get("crop") == "seed":
				if not _check(_count(data, "guest", "seed") == 1 and int(_plot(data).growth) == 0, "client receives one planted spring crop and exactly one seed debit"):
					return
				client_stage.rpc_id(1, "planted")
				_next("water_start")
		"water_start":
			if _age() > 0.2 and server_stage == "water_ready":
				_next("watering")
				_use_held_at.call_deferred("watering_can", FARM_POINT)
		"watering":
			if bool(_plot(data).get("watered", false)):
				if not _check(int(player.can_water) == 19 and int(data.players.host.can_water) == 20, "client observes one water debit in its own can and none in host's can"):
					return
				client_stage.rpc_id(1, "watered")
				_next("sleep_start")
		"sleep_start":
			if _age() > 0.2 and server_stage == "sleep_ready" and _point(player).is_equal_approx(IslandState.CAMP):
				main.perform("sleep")
				_next("sleeping")
		"sleeping":
			if bool(player.sleep_ready):
				if not _check(int(data.day) == 1 and int(_plot(data).growth) == 0 and not bool(data.players.host.sleep_ready), "client's sleep readiness alone does not advance day or crop"):
					return
				client_stage.rpc_id(1, "sleep_sent")
				_next("next_day")
		"next_day":
			if server_stage == "new_day" and int(data.day) == 2:
				if not _check(int(_plot(data).growth) == 1 and not bool(_plot(data).watered) and not Farming.mature(_plot(data)) and not bool(player.sleep_ready) and not bool(data.players.host.sleep_ready), "client receives one day of crop growth only after both actors sleep"):
					return
				if not _check(int(player.can_water) == 19 and int(data.players.host.can_water) == 20 and _count(data, "guest", "veg") == 0, "new-day snapshot preserves personal can water and gives no premature harvest"):
					return
				client_stage.rpc_id(1, "day_observed")
				_next("return_final")
		"return_final":
			if _age() > 0.2 and server_stage == "board_final" and _point(player).is_equal_approx(IslandState.DOCK):
				main.perform("board_raft")
				_next("board_final")
		"board_final":
			if player.area == "deck":
				client_stage.rpc_id(1, "board_final_done")
				_next("unmoor_start")
		"unmoor_start":
			if _age() > 0.2 and server_stage == "unmoor_ready":
				main.perform("unmoor")
				_next("unmooring")
		"unmooring":
			if not bool(data.navigation.anchored) and not bool(data.navigation.moored):
				if not _check(_count(data, "guest", "rope") == 1 and _count(data, "host", "anchor") == 1, "client receives its mooring rope back without changing host's anchor"):
					return
				client_stage.rpc_id(1, "unmoored")
				_next("hook_start")
		"hook_start":
			if _age() > 0.2 and server_stage == "hook_ready" and data.players.host.area == "deck" and _point(player).is_equal_approx(HOOK_POINT):
				main.perform("hook", {"x": 0.0, "y": -1.0})
				_next("hook_contact")
		"hook_contact":
			if not player.hook.is_empty() and player.hook.cargo.has(DRIFT_ID):
				if not _check(_count(data, "guest", "leaf") == 0 and bool(data.drift[DRIFT_ID].active) and player.hook.phase != "reel", "client directional hook carries real collided cargo without an early inventory reward"):
					return
				main.perform("pull_hook")
				client_stage.rpc_id(1, "manual_pulled")
				_next("saved")
		"saved":
			if server_stage == "saved" and _count(data, "guest", "leaf") == 2:
				if not _check(int(data.version) == 10 and bool(data.chart.visited) and int(data.day) == 2 and int(_plot(data).growth) == 1 and not bool(_plot(data).watered) and int(player.can_water) == 19 and int(data.players.host.can_water) == 20 and _count(data, "guest", "wood") == 3 and _count(data, "guest", "seed") == 1 and bool(data.navigation.anchored) and not bool(data.navigation.moored), "client receives exact v10 island, daily farming, independent water and final salvage state before exit"):
					return
				_finish()


func _resume() -> void:
	var data: Dictionary = main.world.data
	if not _check(_json_fields(_persistent_fields(data)) == _json_fields(expected), "independent solo process restores exact v10 chart, day, island, navigation, layout, water and ordered personal bags"):
		return
	if not _check(bool(data.chart.visited) and int(data.island.depleted.get("palm_0", 0)) == 4 and int(data.island.depleted.get("palm_1", 0)) == 3 and int(data.island.depleted.get("stone_0", 0)) == 4 and not data.players.guest.online, "visited island and all collected-node regrowth dates survive with partner offline"):
		return
	if not _check(int(data.day) == 2 and data.island.plots.size() == 1 and _plot(data).crop == "seed" and int(_plot(data).growth) == 1 and not bool(_plot(data).watered) and not Farming.mature(_plot(data)), "saved spring crop resumes one day grown, dry and still immature"):
		return
	if not _check(int(data.players.host.can_water) == 20 and int(data.players.guest.can_water) == 19 and _count(data, "host", "watering_can") == 1 and _count(data, "guest", "watering_can") == 1, "separate can contents and held tools survive independent restoration"):
		return
	if not _check(_count(data, "guest", "wood") == 3 and _count(data, "guest", "seed") == 1 and _count(data, "guest", "leaf") == 2 and _count(data, "host", "fish") == 3 and _count(data, "host", "fiber") == 3 and _count(data, "host", "stone") + _count(data, "guest", "stone") == 3, "saved personal bags retain island and hook awards exactly once, including contested stone"):
		return
	if not _check(bool(data.navigation.anchored) and not bool(data.navigation.moored) and _count(data, "host", "anchor") == 0 and _count(data, "guest", "anchor") == 0 and _count(data, "guest", "rope") == 1, "one deployed shared anchor and recovered personal mooring rope survive save and resume"):
		return
	_finish()


func _persistent_fields(data: Dictionary) -> Dictionary:
	return {"version": data.version, "day": data.day, "chart": data.chart.duplicate(true), "island": data.island.duplicate(true), "navigation": data.navigation.duplicate(true), "deck_tiles": data.deck_tiles.duplicate(), "structures": data.structures.duplicate(true), "chests": data.chests.duplicate(true), "host_bag": data.players.host.bag.duplicate(true), "guest_bag": data.players.guest.bag.duplicate(true), "host_water": data.players.host.can_water, "guest_water": data.players.guest.can_water}


func _json_fields(fields: Dictionary) -> Dictionary:
	# Canonicalize JSON numeric types without dropping ordered slots or state fields.
	return JSON.parse_string(JSON.stringify(fields, "", true, true))


func _plot(data: Dictionary) -> Dictionary:
	return data.island.plots.get(FARM_KEY, {})


func _count(data: Dictionary, slot: String, item: String) -> int:
	return Inventory.count(data.players[slot].bag, item)


func _point(value: Dictionary) -> Vector2:
	return Vector2(float(value.x), float(value.y))


func _node_point(id: String) -> Vector2:
	return _point(IslandMap.node(id))


func _at(point: Vector2) -> Dictionary:
	return {"x": point.x, "y": point.y}


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


func _next(next_phase: String) -> void:
	phase = next_phase
	phase_ms = Time.get_ticks_msec()
	print("ISLAND ", role, " phase=", phase)


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
	report.store_string(JSON.stringify({"passed": true, "role": role, "version": 10, "fixture": "controlled starting tools/supplies, dock and actor positions, one staged drift object; actual ENet actions, timed collection and one real shared-sleep day; not a normal-progression playthrough", "checks": checks, "elapsed_ms": Time.get_ticks_msec() - start_ms}, "\t"))
	report.close()
	finished = true
	set_process(false)
	main.automation_input = Vector2.ZERO
	print("ISLAND NETWORK PASS ", role, " checks=", checks.size())
	get_tree().quit(0)


func _fail(description: String) -> void:
	finished = true
	set_process(false)
	push_error("ISLAND NETWORK FAIL " + role + ": " + description)
	get_tree().quit(1)

func _use_held_at(item: String, point: Vector2) -> void:
	var bag: Array = main.current_state().players.guest.bag
	var index := -1
	for at in bag.size():
		if bag[at].get("item", "") == item:
			index = at
			break
	if not _check(index >= 0 and main.hud.slots[index].button.visible, "client has a visible actual bag slot for " + item):
		return
	var before: Array = bag.duplicate(true)
	await _click_input(main.hud.slots[index].button.get_global_rect().get_center())
	if not _check(Farming.held_item(main.active_tool, main.active_seed) == item and main.current_state().players.guest.bag == before, "client equips " + item + " by real toolbar click without spending"):
		return
	var screen: Vector2 = main.view.get_global_transform_with_canvas() * main.view.world_to_screen(point, "island")
	await _click_input(screen)

func _click_input(at: Vector2) -> void:
	var viewport: Viewport = get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		viewport.push_input(event, true)
		await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout

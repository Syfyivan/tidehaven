extends Node
## Controlled town positions, starting inventories, money and vitals.
## Real main.perform RPCs and host clock settle every transaction and bath.
## Driver RPCs carry barriers only. This is not normal-entry progression.
const Town = preload("res://scripts/island_town.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
var main: Node
var role := ""
var phase := "start"
var remote_stage := ""
var server_stage := ""
var start_ms := 0
var phase_ms := 0
var talk_minute := 0.0
var bath_start_ms := 0
var early_bath_checked := false
var checks: Array[String] = []
var original_host_bag: Array = []
var expected: Dictionary = {}
var finished := false
var paths_valid := false


func _ready() -> void:
	name = "TownNetworkProbe"
	main = get_parent()
	role = str(main.cli.get("test-role", ""))
	start_ms = Time.get_ticks_msec()
	phase_ms = start_ms
	var allowed := ProjectSettings.globalize_path("res://artifacts/").simplify_path().replace("\\", "/").trim_suffix("/").to_lower() + "/"
	for argument in ["save-path", "report"]:
		var path := ProjectSettings.globalize_path(str(main.cli.get(argument, ""))).simplify_path().replace("\\", "/").to_lower()
		if not path.begins_with(allowed):
			_fail("isolated artifact save-path and report are required")
			return
	paths_valid = true
	match role:
		"host":
			main.nickname.text = "小镇验证船长"
			if not main._start("host", false):
				_fail("host startup")
				return
			_setup_fixture()
			if finished:
				return
			var marker := FileAccess.open(str(main.cli.report) + ".ready", FileAccess.WRITE)
			if marker == null:
				_fail("cannot write readiness marker")
				return
			marker.store_string("ready")
			marker.close()
			print("TOWN READY host")
		"client":
			main.nickname.text = "小镇验证伙伴"
			main.address.text = "127.0.0.1"
			main._join()
		"resume":
			if not main._start("solo", true):
				_fail("independent solo restoration")
				return
			main.room_paused = true # Inspect exact saved vitals before another simulation tick.
			var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(main.save_path) + ".expected.json"))
			if not manifest is Dictionary:
				_fail("missing saved-state comparison manifest")
				return
			expected = manifest
		_:
			_fail("unknown role")


func _setup_fixture() -> void:
	var data: Dictionary = main.world.data
	data.minute = 720.0
	data.money = 11
	data.chart.visited = true
	var dock: Vector2 = Archipelago.island_position(data.chart)
	data.navigation.x = dock.x
	data.navigation.y = dock.y
	data.navigation.anchored = true
	for slot in ["host", "guest"]:
		data.players[slot].bag = Inventory.empty_slots(Inventory.BAG_SIZE)
		data.players[slot].stamina = 20.0 if slot == "guest" else 100.0
		data.players[slot].hunger = 75.0
		data.players[slot].thirst = 50.0
		_place(slot, "lin_sui")
	Inventory.add(data.players.host.bag, "fish", 2)
	Inventory.add(data.players.host.bag, "wood", 1)
	Inventory.add(data.players.guest.bag, "veg", 2)
	original_host_bag = data.players.host.bag.duplicate(true)
	_check(int(data.version) == 10 and Town.open_at("lin_sui", float(data.minute)) and Archipelago.within_docking_range(data.chart, data.navigation), "fixture starts a valid v10 docked town visit with two vegetables and eleven shared coins")


func _process(_delta: float) -> void:
	if finished:
		return
	if Time.get_ticks_msec() - start_ms > 28000:
		_fail("timeout at %s; server=%s client=%s" % [phase, server_stage, remote_stage])
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
				_place("guest", "lin_sui")
				_signal_client("talk_ready")
				_next("talk_wait")
		"talk_wait":
			if remote_stage == "talk_visible":
				talk_minute = float(data.minute)
				_signal_client("talk_hold")
				_next("talk_open")
		"talk_open":
			if remote_stage == "talk_observed":
				if not _check(float(data.minute) > talk_minute + 3.0 and not main.room_paused and captain.bag == original_host_bag and int(data.money) == 11, "remote dialogue leaves host simulation advancing and changes no inventory or coins"):
					return
				_signal_client("sell_first")
				_next("market_sale")
		"market_sale":
			if remote_stage == "sold_first":
				if not _check(_count(data, "guest", "veg") == 1 and int(data.money) == 15 and captain.bag == original_host_bag, "guest sale RPC spends its personal vegetable and grants four shared coins without touching host bag"):
					return
				_signal_client("buy_seed")
				_next("market_purchase")
		"market_purchase":
			if remote_stage == "bought_seed":
				if not _check(_count(data, "guest", "seed") == 1 and _count(data, "guest", "veg") == 1 and int(data.money) == 12, "guest seasonal seed purchase costs three coins and keeps its remaining vegetable"):
					return
				_place("host", "yan_zhen")
				_place("guest", "yan_zhen")
				main.perform("town_trade", {"id": "yan_zhen", "offer": "buy_axe"})
				if not _check(int(data.money) == 0 and _count(data, "host", "axe") == 1 and _count(data, "guest", "axe") == 0, "host consumes the one shared tool budget through its real transaction"):
					return
				_signal_client("budget_spent")
				_next("guest_rejection")
		"guest_rejection":
			if remote_stage == "tool_rejected":
				if not _check(int(data.money) == 0 and _count(data, "host", "axe") == 1 and _count(data, "guest", "axe") == 0 and _count(data, "guest", "seed") == 1 and _count(data, "guest", "veg") == 1, "guest tool RPC is atomically refused after host spends the shared funds"):
					return
				_place("guest", "lin_sui")
				_signal_client("sell_last")
				_next("bath_funding")
		"bath_funding":
			if remote_stage == "funded":
				if not _check(int(data.money) == 4 and _count(data, "guest", "veg") == 0 and _count(data, "host", "fish") == 2, "last vegetable funds the bath and a repeated empty sale gives no extra coins"):
					return
				_place("guest", "tang_he")
				_signal_client("bath_ready")
				_next("bath_start")
		"bath_start":
			if remote_stage == "bath_started":
				if not _check(guest.activity.get("kind") == "town_bath" and float(guest.activity.remaining) > 7 and float(guest.stamina) == 20 and int(data.money) == 4, "guest bath RPC starts a real eight-second activity without early recovery or fee"):
					return
				bath_start_ms = Time.get_ticks_msec()
				_next("bath_running")
		"bath_running":
			if not guest.activity.is_empty() and (float(guest.stamina) != 20 or int(data.money) != 4):
				_fail("bath gave recovery or charged before real completion")
				return
			if remote_stage == "bath_done":
				if not _check(Time.get_ticks_msec() - bath_start_ms >= 7500 and guest.activity.is_empty() and float(guest.stamina) == 80 and int(data.money) == 1 and float(guest.thirst) > 65 and float(guest.thirst) < 71, "host settles the eight-second bath once with real thirst decay, sixty stamina and a three-coin charge"):
					return
				main.room_paused = true
				_signal_client("finish_client")
				_next("disconnect")
		"disconnect":
			if not guest.online:
				if not _check(_count(data, "guest", "seed") == 1 and _count(data, "guest", "veg") == 0 and _count(data, "host", "axe") == 1 and int(data.money) == 1 and float(guest.stamina) == 80, "disconnect preserves personal purchases, shared balance and paid recovery"):
					return
				expected = _persistent_fields(data)
				if not main._persist():
					_fail("host isolated save")
					return
				var manifest := FileAccess.open(str(main.save_path) + ".expected.json", FileAccess.WRITE)
				if manifest == null:
					_fail("cannot save comparison manifest")
					return
				manifest.store_string(JSON.stringify(expected, "", true, true))
				manifest.close()
				_check(true, "host persists its isolated v10 world after actual town RPCs and partner disconnect")
				_finish()


func _client() -> void:
	if main.mode != "client" or main.received.is_empty():
		return
	var data: Dictionary = main.current_state()
	var player: Dictionary = data.players.guest
	match phase:
		"start":
			if server_stage == "talk_ready" and _at_npc(player, "lin_sui", data):
				original_host_bag = data.players.host.bag.duplicate(true)
				main.perform("town_talk", {"id": "lin_sui"})
				_next("talk_reply")
		"talk_reply":
			if main.dialogue_ui.visible:
				if not _check(main.dialogue_ui.speaker.text == "林穗 · 超市店主" and main.dialogue_ui.body.text.contains("种子") and main.pending_talk.is_empty(), "reliable remote talk reply is correlated to the requested NPC and opens its actual dialogue panel"):
					return
				client_stage.rpc_id(1, "talk_visible")
				_next("talk_hold")
		"talk_hold":
			if server_stage == "talk_hold":
				talk_minute = float(data.minute)
				_next("talk_clock")
		"talk_clock":
			if _age() > 1.0:
				if not _check(main.dialogue_ui.visible and float(data.minute) > talk_minute + 3 and not main.room_paused and data.players.host.bag == original_host_bag, "client continues receiving newer host time while its conversation stays open"):
					return
				_escape()
				_next("talk_closing")
		"talk_closing":
			# parse_input_event queues normal dispatch; observe it on later frames.
			if _age() > 0.1:
				if not _check(not main.dialogue_ui.visible, "real Escape input closes the client conversation"):
					return
				client_stage.rpc_id(1, "talk_observed")
				_next("first_sale_start")
		"first_sale_start":
			if server_stage == "sell_first":
				main.perform("town_trade", {"id": "lin_sui", "offer": "sell_veg"})
				_next("first_sale")
		"first_sale":
			if _count(data, "guest", "veg") == 1 and int(data.money) == 15:
				if not _check(data.players.host.bag == original_host_bag, "client observes only its own sale item removed and shared income credited"):
					return
				client_stage.rpc_id(1, "sold_first")
				_next("seed_start")
		"seed_start":
			if server_stage == "buy_seed" and _age() > 0.15:
				main.perform("town_trade", {"id": "lin_sui", "offer": "buy_seed"})
				_next("seed_purchase")
		"seed_purchase":
			if _count(data, "guest", "seed") == 1 and int(data.money) == 12:
				_check(_count(data, "guest", "veg") == 1, "client receives its purchased seed without consuming unrelated inventory")
				client_stage.rpc_id(1, "bought_seed")
				_next("budget_start")
		"budget_start":
			if server_stage == "budget_spent" and _at_npc(player, "yan_zhen", data) and int(data.money) == 0 and _age() > 0.15:
				main.perform("town_talk", {"id": "yan_zhen"})
				_next("smith_reply")
		"smith_reply":
			if main.dialogue_ui.visible:
				if not _check(main.dialogue_ui.speaker.text == "严砧 · 铁匠" and main.dialogue_ui.body.text.contains("石斧") and main.pending_talk.is_empty(), "second remote talk_id selects the blacksmith rather than retaining the previous shopkeeper dialogue"):
					return
				_escape()
				_next("smith_closing")
		"smith_closing":
			if _age() > 0.1:
				if not _check(not main.dialogue_ui.visible, "second Escape input closes the blacksmith conversation before trading"):
					return
				_next("budget_trade_start")
		"budget_trade_start":
			if _age() > 0.15:
				main.perform("town_trade", {"id": "yan_zhen", "offer": "buy_axe"})
				_next("budget_reply")
		"budget_reply":
			if _age() > 0.2 and str(main.status.text).contains("金币不足"):
				if not _check(int(data.money) == 0 and _count(data, "guest", "axe") == 0 and _count(data, "host", "axe") == 1 and _count(data, "guest", "seed") == 1, "remote insufficient-funds feedback preserves both personal bags and the zero shared balance"):
					return
				client_stage.rpc_id(1, "tool_rejected")
				_next("last_sale_start")
		"last_sale_start":
			if server_stage == "sell_last" and _at_npc(player, "lin_sui", data) and _age() > 0.15:
				main.perform("town_trade", {"id": "lin_sui", "offer": "sell_veg"})
				_next("last_sale")
		"last_sale":
			if _count(data, "guest", "veg") == 0 and int(data.money) == 4 and _age() > 0.2:
				main.perform("town_trade", {"id": "lin_sui", "offer": "sell_veg"})
				_next("replay_sale")
		"replay_sale":
			if _age() > 0.2 and str(main.status.text).contains("本人背包"):
				if not _check(int(data.money) == 4 and _count(data, "guest", "veg") == 0, "repeated remote sale request cannot award payment without another personal vegetable"):
					return
				client_stage.rpc_id(1, "funded")
				_next("bath_start")
		"bath_start":
			if server_stage == "bath_ready" and _at_npc(player, "tang_he", data) and _age() > 0.15:
				main.perform("town_bath", {"id": "tang_he"})
				bath_start_ms = Time.get_ticks_msec()
				_next("bath_reply")
		"bath_reply":
			if player.activity.get("kind") == "town_bath":
				if not _check(float(player.activity.remaining) > 7 and int(data.money) == 4 and float(player.stamina) == 20, "client sees pending eight-second bath rather than an injected completion reward"):
					return
				client_stage.rpc_id(1, "bath_started")
				_next("bath_running")
		"bath_running":
			if not player.activity.is_empty():
				if float(player.stamina) != 20 or int(data.money) != 4:
					_fail("client observed premature bath reward or fee")
					return
				if _age() > 2 and not early_bath_checked:
					early_bath_checked = true
					_check(float(player.activity.remaining) < 6 and float(player.activity.remaining) > 0, "multiple real host snapshots advance bath progress while coins and stamina remain unchanged")
			elif float(player.stamina) == 80 and int(data.money) == 1:
				if not _check(Time.get_ticks_msec() - bath_start_ms >= 7800 and early_bath_checked and float(player.thirst) > 65, "client receives exactly one completed bath after eight real seconds"):
					return
				client_stage.rpc_id(1, "bath_done")
				_next("finish")
		"finish":
			if server_stage == "finish_client" and main.room_paused:
				if not _check(_count(data, "guest", "seed") == 1 and _count(data, "guest", "veg") == 0 and _count(data, "guest", "axe") == 0 and _count(data, "host", "axe") == 1 and int(data.money) == 1, "final network snapshot preserves distinct inventories and exact town balance"):
					return
				_finish()


func _resume() -> void:
	var data: Dictionary = main.world.data
	if not _check(_json(_persistent_fields(data)) == _json(expected), "independent process restores exact v10 positions, bags, shared money, town recovery and island progress"):
		return
	if not _check(int(data.version) == 10 and int(data.money) == 1 and _count(data, "host", "axe") == 1 and _count(data, "guest", "seed") == 1 and _count(data, "guest", "veg") == 0, "saved purchases and completed sale income survive a normal solo load"):
		return
	if not _check(float(data.players.guest.stamina) == 80 and data.players.host.activity.is_empty() and data.players.guest.activity.is_empty(), "paid bath recovery survives without replaying an activity or charging again"):
		return
	if not _check(data.players.host.online and not data.players.guest.online and data.players.host.area == "island" and data.players.guest.area == "deck", "solo restore keeps host town position and the safely disconnected guest offline"):
		return
	_finish()


func _persistent_fields(data: Dictionary) -> Dictionary:
	var result := {"version": data.version, "day": data.day, "minute": data.minute, "money": data.money, "chart": data.chart.duplicate(true), "island": data.island.duplicate(true), "navigation": data.navigation.duplicate(true), "chests": data.chests.duplicate(true), "players": {}}
	for slot in ["host", "guest"]:
		var player: Dictionary = data.players[slot]
		result.players[slot] = {"area": player.area, "x": player.x, "y": player.y, "bag": player.bag.duplicate(true), "stamina": player.stamina, "hunger": player.hunger, "thirst": player.thirst, "can_water": player.can_water}
	return result


func _json(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _count(data: Dictionary, slot: String, item: String) -> int:
	return Inventory.count(data.players[slot].bag, item)


func _at_npc(player: Dictionary, npc_id: String, data: Dictionary) -> bool:
	return player.area == "island" and Vector2(float(player.x), float(player.y)).is_equal_approx(Town.position(npc_id, float(data.minute)))


func _place(slot: String, npc_id: String) -> void:
	var player: Dictionary = main.world.data.players[slot]
	var at: Vector2 = Town.position(npc_id, float(main.world.data.minute))
	player.area = "island"
	player.x = at.x
	player.y = at.y
	player.resting = false
	player.sleep_ready = false
	main.world.set_move(slot, Vector2.ZERO)


func _escape() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ESCAPE
		event.keycode = KEY_ESCAPE
		event.pressed = down
		Input.parse_input_event(event)


func _signal_client(stage: String) -> void:
	main._send_snapshot()
	host_stage.rpc_id(int(main.remote_peer), stage)


func _next(next_phase: String) -> void:
	phase = next_phase
	phase_ms = Time.get_ticks_msec()
	print("TOWN ", role, " phase=", phase)


func _age() -> float:
	return float(Time.get_ticks_msec() - phase_ms) / 1000.0


func _check(condition: bool, description: String) -> bool:
	if not condition:
		_fail(description)
		return false
	checks.append(description)
	print("PASS ", role, ": ", description)
	return true


func _finish() -> void:
	if not _write_report(true, ""):
		_fail("cannot write passing report")
		return
	finished = true
	set_process(false)
	print("TOWN NETWORK PASS ", role, " checks=", checks.size())
	get_tree().quit(0)


func _write_report(passed: bool, reason: String) -> bool:
	if not paths_valid or not is_instance_valid(main) or not main.cli.has("report"):
		return false
	var report := FileAccess.open(str(main.cli.report), FileAccess.WRITE)
	if report == null:
		return false
	report.store_string(JSON.stringify({"passed": passed, "role": role, "version": 10, "fixture": "controlled dock/town actor positions, 2 guest vegetables, host fish/wood, 11 shared coins and starting vitals; real ENet actions and eight-second host bath timer; not normal progression or cross-computer evidence", "phase": phase, "reason": reason, "checks": checks, "elapsed_ms": Time.get_ticks_msec() - start_ms}, "\t"))
	report.close()
	return true


func _fail(reason: String) -> void:
	if finished:
		return
	finished = true
	set_process(false)
	_write_report(false, reason)
	push_error("TOWN NETWORK FAIL " + role + ": " + reason)
	get_tree().quit(1)

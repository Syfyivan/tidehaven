extends Node
## Controlled locations and bags, real ENet request/feedback and save/continue.
const Inv = preload("res://scripts/inventory.gd")
const Town = preload("res://scripts/island_town.gd")
const Sea = preload("res://scripts/archipelago.gd")
var main: Node
var role := ""
var phase := "start"
var stage := ""
var checks: Array[String] = []
var started := 0
var last_step := 0
var done := false

func _ready() -> void:
	name = "HomesteadProbe"
	main = get_parent()
	role = str(main.cli.get("test-role", ""))
	started = Time.get_ticks_msec()
	for argument in ["save-path", "report"]:
		var path := ProjectSettings.globalize_path(str(main.cli.get(argument, ""))).replace("\\", "/").to_lower()
		if not path.begins_with(ProjectSettings.globalize_path("res://artifacts/").replace("\\", "/").to_lower()):
			finish(false, "isolated paths required")
			return
	if role == "host":
		main._start("host", false)
		var data: Dictionary = main.world.data
		var at: Vector2 = Sea.island_position(data.chart)
		data.chart.visited = true
		data.navigation.x = at.x
		data.navigation.y = at.y
		data.navigation.anchored = true
		data.minute = 720.0
		var marker := FileAccess.open(str(main.cli.report) + ".ready", FileAccess.WRITE)
		marker.store_string("ready")
	elif role == "client":
		main.address.text = "127.0.0.1"
		main._join()
	else:
		verify(main._start("solo", true), "normal solo loads host save")
		verify(main.world.data.island.homestead == {"rented": true, "claimed": {"host": true, "guest": true}}, "shared lease and both personal claims survive")
		verify(Inv.count(main.world.data.players.guest.bag, "seed") == 6, "guest gift remains in saved personal bag")
		finish(true)

func verify(ok: bool, label: String) -> bool:
	if not ok:
		finish(false, label)
		return false
	checks.append(label)
	return true

@rpc("any_peer", "call_remote", "reliable")
func reached(value: String) -> void:
	if role == "host" and multiplayer.get_remote_sender_id() == main.remote_peer:
		stage = value

@rpc("authority", "call_remote", "reliable")
func proceed(value: String) -> void:
	stage = value

func _process(_delta: float) -> void:
	if done:
		return
	if Time.get_ticks_msec() - started > 30000:
		finish(false, "timeout " + phase)
		return
	if Time.get_ticks_msec() - last_step < 200:
		return
	last_step = Time.get_ticks_msec()
	var data: Dictionary = main.current_state()
	if data.is_empty() or main.mode not in ["host", "client"]:
		return
	var home: Dictionary = data.island.homestead
	if role == "host":
		var guest: Dictionary = data.players.guest
		match phase:
			"start":
				if not guest.online:
					return
				var at: Vector2 = Town.position("xu_an", data.minute)
				guest.area = "island"
				guest.x = at.x
				guest.y = at.y
				for index in Inv.BAG_SIZE:
					guest.bag[index] = {"item": "wood", "count": 20}
				proceed.rpc_id(main.remote_peer, "rent")
				phase = "full"
			"full":
				if stage != "full":
					return
				verify(home.rented, "guest RPC creates shared lease while host stays on raft")
				verify(not home.claimed.guest and Inv.count(guest.bag, "wood") == 240, "full bag claim changes no items or flag")
				guest.bag = Inv.empty_slots(12) # second controlled capacity case
				proceed.rpc_id(main.remote_peer, "claim")
				phase = "claimed"
			"claimed":
				if stage != "replayed":
					return
				verify(home.claimed.guest and Inv.count(guest.bag, "seed") == 6, "guest RPC and delayed duplicate grant exactly six seeds")
				verify(Inv.count(guest.bag, "hoe") == 1 and Inv.count(guest.bag, "watering_can") == 1, "guest receives both tools once")
				var host: Dictionary = data.players.host
				var at: Vector2 = Town.position("xu_an", data.minute)
				host.area = "island"
				host.x = at.x
				host.y = at.y
				main.perform("town_claim", {"id": "xu_an"})
				verify(home.claimed.host and Inv.count(host.bag, "seed") == 6, "host claims independently without repeating lease")
				verify(main._persist(), "host writes validated isolated save")
				proceed.rpc_id(main.remote_peer, "finish")
				phase = "finish"
			"finish":
				if stage == "finish":
					finish(true)
	else:
		match phase:
			"start":
				if stage == "rent" and data.players.guest.area == "island":
					main.perform("town_rent", {"id": "xu_an"})
					phase = "rent"
			"rent":
				if home.rented:
					verify(data.players.host.area == "deck", "host remains independently on raft")
					main.perform("town_claim", {"id": "xu_an"})
					phase = "full"
			"full":
				verify(not home.claimed.guest, "full claim stays available on client")
				reached.rpc_id(1, "full")
				phase = "retry"
			"retry":
				if stage == "claim" and Inv.total_count(data.players.guest.bag) == 0:
					main.perform("town_claim", {"id": "xu_an"})
					phase = "claimed"
			"claimed":
				if home.claimed.guest:
					verify(Inv.count(data.players.guest.bag, "seed") == 6, "client sees successful retry rewards")
					main.perform("town_claim", {"id": "xu_an"})
					phase = "duplicate"
			"duplicate":
				verify(Inv.count(data.players.guest.bag, "seed") == 6, "client replay does not add more seeds")
				reached.rpc_id(1, "replayed")
				phase = "finish"
			"finish":
				if stage == "finish" and home.claimed.host:
					verify(home.rented and home.claimed.guest, "both flags are replicated")
					reached.rpc_id(1, "finish")
					finish(true)

func finish(passed: bool, reason := "") -> void:
	if done:
		return
	done = true
	var file := FileAccess.open(str(main.cli.report), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "role": role, "version": 16, "checks": checks, "reason": reason, "fixture": "controlled positions/capacity; actual ENet claims and persisted host save"}, "\t"))
	file.close()
	print("HOMESTEAD NETWORK ", role, ": ", checks.size(), " checks; ", passed, " ", reason)
	await get_tree().create_timer(0.4).timeout
	get_tree().quit(0 if passed else 1)

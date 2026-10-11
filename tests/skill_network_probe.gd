extends "res://tests/progression_network_probe.gd"
## Controlled drift positions; real client input, action RPCs, host ticks and snapshots.
const HOOK_WOOD := "drift_00"
const HOOK_LEAF := "drift_01"
var hook_stage := 0
var hook_done := false
var hook_started := 0
var hook_guest_before: Array = []
var hook_expected_bag: Array = []
var hook_drift_before: Dictionary = {}
var hook_navigation_before: Dictionary = {}
var hook_guest_position := Vector2.ZERO
var hook_first_seen := false
var hook_both_seen := false


func _host() -> void:
	if hook_done:
		super._host()
		return
	var data: Dictionary = main.world.data
	var player: Dictionary = data.players.guest
	if not player.online:
		return
	if hook_stage > 0:
		# Keep unrelated random supplies out of this controlled collision fixture.
		for id in data.drift:
			if hook_stage >= 3 and id in [HOOK_WOOD, HOOK_LEAF]:
				continue
			data.drift[id].active = false
			data.drift[id].respawn = 7.0
	if hook_stage == 0:
		hook_guest_before = player.bag.duplicate(true)
		hook_expected_bag = hook_guest_before.duplicate(true)
		Inventory.add(hook_expected_bag, "wood", 2)
		Inventory.add(hook_expected_bag, "leaf", 2)
		if not _check(data.drift[HOOK_WOOD].kind == "wood" and data.drift[HOOK_LEAF].kind == "leaf" and Inventory.count(hook_expected_bag, "wood") == Inventory.count(hook_guest_before, "wood") + 2 and Inventory.count(hook_expected_bag, "leaf") == Inventory.count(hook_guest_before, "leaf") + 2, "fixture has two distinct material types and enough real inventory capacity for both complete rewards"):
			return
		hook_drift_before = data.drift.duplicate(true)
		hook_navigation_before = data.navigation.duplicate(true)
		hook_guest_position = Vector2(float(player.x), float(player.y))
		data.navigation.anchored = true
		data.navigation.push_x = 0.0
		data.navigation.push_y = 0.0
		_place("guest", "deck", Vector2(544, 288))
		for item in data.drift.values():
			item.active = false
			item.respawn = 7.0
		_signal_client("direction_hook")
		hook_stage = 1
	elif hook_stage == 1 and not player.hook.is_empty():
		if not _check(player.hook.phase == "out" and not player.hook.has("id") and player.hook.cargo is Array and player.hook.cargo.is_empty() and player.bag == hook_guest_before, "direction RPC begins a genuinely empty flight with an array cargo and no instant reward"):
			return
		hook_started = Time.get_ticks_msec()
		hook_stage = 2
	elif hook_stage == 2 and not player.hook.is_empty() and player.hook.phase == "float":
		if not _check(player.hook.cargo.is_empty() and float(player.hook.travel) >= 400.0 and player.bag == hook_guest_before, "empty cast naturally reaches its full range and floats before either material enters the return path"):
			return
		var tip := Vector2(float(player.hook.x), float(player.hook.y))
		var hand := Vector2(float(player.x), float(player.y))
		_stage_return_item(data, HOOK_WOOD, tip.move_toward(hand, 95.0))
		_stage_return_item(data, HOOK_LEAF, tip.move_toward(hand, 205.0))
		hook_stage = 3
		_signal_client("empty_float_ready")
	elif hook_stage == 3 and not player.hook.is_empty() and player.hook.phase == "reel":
		if not _check(player.hook.cargo.is_empty() and player.bag == hook_guest_before, "client P input starts retrieving the still-empty hook through the host action RPC"):
			return
		hook_stage = 4
	elif hook_stage == 4:
		if not player.hook.is_empty():
			if player.bag != hook_guest_before or data.players.host.bag != host_bag_before:
				_fail("a travelling multi-cargo hook must not award either player's inventory")
				return
			var cargo: Array = player.hook.cargo
			if not hook_first_seen and cargo == [HOOK_WOOD]:
				if not _check(player.hook.phase == "reel" and data.drift[HOOK_WOOD].active and data.drift[HOOK_LEAF].active, "returning empty hook collides with the first material and keeps reeling without consuming it early"):
					return
				hook_first_seen = true
			elif not hook_both_seen and cargo == [HOOK_WOOD, HOOK_LEAF]:
				if not _check(hook_first_seen and player.hook.phase == "reel" and data.drift[HOOK_WOOD].active and data.drift[HOOK_LEAF].active, "the same returning hook adds a second distinct material in contact order before either is awarded"):
					return
				hook_both_seen = true
		if remote_stage == "hook_received":
			if not _check(hook_first_seen and hook_both_seen and player.hook.is_empty() and Time.get_ticks_msec() - hook_started > 4500 and player.bag == hook_expected_bag and not data.drift[HOOK_WOOD].active and not data.drift[HOOK_LEAF].active and data.players.host.bag == host_bag_before, "one completed client reel awards exactly two wood and two leaves once; replayed empty pulls cannot duplicate either reward"):
				return
			# Remove only verified rewards, then restore the drift/navigation fixture.
			Inventory.remove(player.bag, "wood", 2)
			Inventory.remove(player.bag, "leaf", 2)
			if not _check(player.bag == hook_guest_before, "multi-cargo fixture cleanup restores the inherited guest inventory exactly"):
				return
			data.drift = hook_drift_before.duplicate(true)
			data.navigation = hook_navigation_before.duplicate(true)
			_place("guest", "deck", hook_guest_position)
			remote_stage = ""
			hook_done = true
			_signal_client("hook_done")


func _stage_return_item(data: Dictionary, id: String, point: Vector2) -> void:
	var item: Dictionary = data.drift[id]
	item.active = true
	item.respawn = 0.0
	item.x = point.x
	item.y = point.y
	item.speed = 12.0
	item.sway = 4.0
	item.phase = fposmod(PI / 2.0 - float(data.elapsed) * 0.45, TAU)


func _client() -> void:
	if hook_done:
		super._client()
		return
	if main.mode != "client" or main.received.is_empty():
		return
	var data: Dictionary = main.current_state()
	var player: Dictionary = data.players.guest
	if hook_stage == 0 and server_stage == "direction_hook" and player.x == 544:
		hook_guest_before = player.bag.duplicate(true)
		host_bag_before = data.players.host.bag.duplicate(true)
		hook_expected_bag = hook_guest_before.duplicate(true)
		Inventory.add(hook_expected_bag, "wood", 2)
		Inventory.add(hook_expected_bag, "leaf", 2)
		main.perform("hook", {"id": HOOK_WOOD})
		hook_started = Time.get_ticks_msec()
		hook_stage = 1
	elif hook_stage == 1 and Time.get_ticks_msec() - hook_started > 250:
		if not _check(player.hook.is_empty() and player.bag == hook_guest_before, "obsolete target-id RPC is rejected without a hook or inventory reward"):
			return
		main.perform("hook", {"x": 1.0, "y": 0.0})
		hook_stage = 2
	elif hook_stage == 2 and server_stage == "empty_float_ready" and not player.hook.is_empty() and player.hook.phase == "float":
		if not _check(player.hook.cargo is Array and player.hook.cargo.is_empty() and player.bag == hook_guest_before and data.drift[HOOK_WOOD].active and data.drift[HOOK_LEAF].active, "client receives a floating empty hook and two material types waiting in its return path"):
			return
		_press_pull_key()
		hook_stage = 3
	elif hook_stage == 3:
		if not player.hook.is_empty():
			if player.bag != hook_guest_before or data.players.host.bag != host_bag_before:
				_fail("received in-flight cargo snapshot must not pre-award inventory")
				return
			var cargo: Array = player.hook.cargo
			if not hook_first_seen and cargo == [HOOK_WOOD]:
				if not _check(player.hook.phase == "reel", "client receives first returning cargo while inventory remains unchanged"):
					return
				hook_first_seen = true
			elif not hook_both_seen and cargo == [HOOK_WOOD, HOOK_LEAF]:
				if not _check(hook_first_seen and player.hook.phase == "reel" and data.drift[HOOK_WOOD].active and data.drift[HOOK_LEAF].active, "client receives both ordered cargo entries before the physical return grants any materials"):
					return
				hook_both_seen = true
				_press_pull_key()
		elif hook_first_seen and hook_both_seen:
			if not _check(player.bag == hook_expected_bag and not data.drift[HOOK_WOOD].active and not data.drift[HOOK_LEAF].active and data.players.host.bag == host_bag_before, "client sees exactly both material rewards only after completed reel"):
				return
			main.perform("pull_hook")
			main.perform("pull_hook")
			hook_started = Time.get_ticks_msec()
			hook_stage = 4
	elif hook_stage == 4 and Time.get_ticks_msec() - hook_started > 300:
		if not _check(player.hook.is_empty() and player.bag == hook_expected_bag, "subsequent authoritative snapshots preserve exact rewards after repeated empty pull RPCs"):
			return
		client_stage.rpc_id(1, "hook_received")
		hook_stage = 5
	elif hook_stage == 5 and server_stage in ["hook_done", "paddle_ready"]:
		hook_done = true


func _press_pull_key() -> void:
	var down := InputEventKey.new()
	down.physical_keycode = KEY_P
	down.keycode = KEY_P
	down.pressed = true
	get_viewport().push_input(down, true)
	var up := InputEventKey.new()
	up.physical_keycode = KEY_P
	up.keycode = KEY_P
	up.pressed = false
	get_viewport().push_input(up, true)

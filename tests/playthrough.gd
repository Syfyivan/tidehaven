extends Node
## Full survival opening through normal mouse/keyboard controls only.
## State, recipes, and can_place are read for observation; no game mutations
## bypass the same controls available to the player.

const Inventory = preload("res://scripts/inventory.gd")
const Recipes = preload("res://scripts/recipes.gd")
const DEADLINE_SECONDS := 480.0
const MOVE_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D]
const CENTER := Vector2(480, 288)

var main
var started_ms := 0
var finished := false
var failure := ""
var failure_context: Dictionary = {}
var held: Dictionary = {}
var steps: Array = []
var screenshots: Array = []
var inputs: Array = []
var hook_count := 0
var fishing_results: Array = []
var expected_save: Dictionary = {}
var restored_save: Dictionary = {}
var purifier_id := ""
var grill_id := ""

func _ready() -> void:
	main = get_parent()
	started_ms = Time.get_ticks_msec()
	_run.call_deferred()

func _process(_delta: float) -> void:
	if not finished and _seconds() > DEADLINE_SECONDS:
		_fail("Normal-input survival opening exceeded 480 real seconds")

func _run() -> void:
	for argument in ["save-path", "report", "evidence-dir"]:
		if not main.cli.has(argument):
			_fail("Missing isolated test argument: " + argument)
			return
	for filename in ["world_v1.json", "world_v2.json", "world_v3.json", "world_v4.json", "world_v5.json", "world_v6.json", "world_v7.json", "world_v8.json", "world_v9.json", "world_v10.json"]:
		if ProjectSettings.globalize_path(str(main.save_path)) == ProjectSettings.globalize_path("user://" + filename):
			_fail("Refusing to use the player's default save")
			return
	if FileAccess.file_exists(main.save_path) or FileAccess.file_exists(str(main.save_path) + ".bak"):
		_fail("Use a fresh isolated save path; an existing save will not be replaced")
		return
	await _settle(0.35)
	await _click(main.new_game_button.get_global_rect().get_center())
	if not (await _until(func() -> bool: return str(main.mode) == "solo" and not main.overlay.visible, "new solo title button", 4.0)):
		return
	if not _check(int(_state().version) == 10 and _state().deck_tiles.size() == 9 and _state().chests.is_empty() and _state().structures.size() == 1 and Inventory.total_count(_bag()) == 0, "Fresh opening must be nine raft cells, one bedroll and an empty backpack"):
		return
	_record("Started the real nine-cell survival opening with no granted resources")
	if not (await _capture("01-opening.png")):
		return
	await _tap(KEY_1)
	if not (await _gather({"wood": 24, "leaf": 14, "plastic": 8, "scrap": 4})):
		return
	_record("Mouse-hooked drifting supplies for tools, three facilities, fuel and a new floor")
	if not (await _discard_seed_stack()):
		return
	for index in range(7):
		if not (await _craft_item("rope")):
			return
	if not (await _craft_item("cup")) or not (await _craft_item("rod")):
		return
	_record("Crafted seven ropes, a cup and a fishing rod from the visible recipe list")
	if not (await _craft_item("paddle")) or not (await _craft_item("anchor")):
		return
	var sailing_start := Vector2(float(_state().navigation.x), float(_state().navigation.y))
	var stamina_start: float = float(_player().stamina)
	await _tap(KEY_3)
	await _click_world(Vector2(480, 120))
	await _settle(0.9)
	if not _check(float(_state().navigation.y) < sailing_start.y and float(_player().stamina) == stamina_start - 2, "Paddle mouse input moves the raft north and costs exactly two stamina"):
		return
	if not (await _capture("02a-paddling.png")):
		return
	await _tap(KEY_G)
	if not _check(bool(_state().navigation.anchored) and _count("anchor") == 0, "G deploys the crafted anchor from the backpack"):
		return
	var stopped: Dictionary = _state().navigation.duplicate(true)
	await _settle(0.8)
	if not _check(_state().navigation == stopped, "Anchored raft remains stationary while supplies continue to drift"):
		return
	await _tap(KEY_G)
	if not _check(not bool(_state().navigation.anchored) and _count("anchor") == 1, "G retrieves exactly one anchor"):
		return
	await _tap(KEY_G)
	await _tap(KEY_1)
	_record("Crafted a paddle and reusable anchor, steered north, anchored, retrieved and redeployed through normal input")

	if not (await _place("purifier", Vector2(544, 224), true)):
		return
	purifier_id = _structure_id("purifier")
	if not (await _place("grill", Vector2(544, 352))):
		return
	grill_id = _structure_id("grill")
	if not (await _place("chest", Vector2(416, 352))):
		return
	if not _check(_state().chests.size() == 1 and _state().structures.size() == 3, "Player-built purifier, grill and chest were not placed"):
		return
	_record("Placed purifier, grill and chest at corners, leaving the center walkable")
	if not (await _capture("03-built-raft.png")):
		return

	if not (await _walk(Vector2(500, 240), "purifier approach and raft edge")):
		return
	if not (await _act("fill_cup")):
		return
	if not (await _until(func() -> bool: return _count("saltwater") == 1 and _count("cup") == 0, "filling the cup with sea water", 3.0)):
		return
	var water_start: float = float(_state().elapsed)
	if not (await _act("purify", purifier_id)):
		return
	if not (await _until(func() -> bool: return float(_state().structures[purifier_id].remaining) > 0 and _state().structures[purifier_id].output == "freshwater", "purifier starts its timer", 3.0)):
		return
	if not (await _capture("04-purifier-working.png")):
		return
	if not (await _until(func() -> bool: return float(_state().structures[purifier_id].remaining) <= 0, "twelve seconds of natural purification", 16.0)):
		return
	if not _check(float(_state().elapsed) - water_start >= 11.9, "Purification skipped the game-clock wait"):
		return
	if not (await _act("collect_output", purifier_id)):
		return
	if not (await _until(func() -> bool: return _count("freshwater") == 1 and str(_state().structures[purifier_id].output).is_empty(), "fresh water enters the backpack", 3.0)):
		return
	var thirst_before: float = float(_player().thirst)
	if not (await _act("drink")):
		return
	if not (await _until(func() -> bool: return _count("freshwater") == 0 and _count("cup") == 1 and float(_player().thirst) > thirst_before + 10, "drinking restores thirst and returns the cup", 3.0)):
		return
	_record("Filled, purified, collected and drank water through E/Tab interactions")

	if not (await _walk(Vector2(480, 365), "open bottom edge for fishing")):
		return
	await _tap(KEY_2)
	if not (await _fish_until_caught()):
		return
	if not (await _walk(Vector2(500, 335), "grill approach")):
		return
	var cooking_start: float = float(_state().elapsed)
	if not (await _act("grill_fish", grill_id)):
		return
	if not (await _until(func() -> bool: return float(_state().structures[grill_id].remaining) > 0, "grill starts cooking", 3.0)):
		return
	if not (await _capture("05-grill-working.png")):
		return
	if not (await _until(func() -> bool: return float(_state().structures[grill_id].remaining) <= 0, "ten seconds of natural cooking", 14.0)):
		return
	if not _check(float(_state().elapsed) - cooking_start >= 9.9, "Cooking skipped the game-clock wait"):
		return
	if not (await _act("collect_output", grill_id)):
		return
	if not (await _until(func() -> bool: return _count("cooked_fish") == 1, "cooked fish enters the backpack", 3.0)):
		return
	var hunger_before: float = float(_player().hunger)
	if not (await _act("eat")):
		return
	if not (await _until(func() -> bool: return _count("cooked_fish") == 0 and float(_player().hunger) > hunger_before + 5, "eating restores hunger", 3.0)):
		return
	_record("Caught a real fish, cooked it for ten seconds and ate it")
	if not (await _place("foundation", Vector2(480, 416))):
		return
	if not _check(_state().deck_tiles.size() == 10, "Foundation recipe must add exactly one adjacent raft cell"):
		return
	_record("Built one additional connected floor cell")
	if not (await _walk(Vector2(453, 337), "new wooden chest")):
		return
	if not (await _inventory_round_trip()):
		return
	if not (await _exploration_loop()):
		return

	expected_save = _saved_progress()
	if not (await _save_and_title()):
		return
	if not _check(FileAccess.file_exists(main.save_path), "Save-and-return did not create the isolated world"):
		return
	if not (await _capture("07-saved-title.png")):
		return
	await _click(main.continue_button.get_global_rect().get_center())
	if not (await _until(func() -> bool: return str(main.mode) == "solo" and not main.overlay.visible, "Continue Solo restores the saved world", 4.0)):
		return
	restored_save = _saved_progress()
	if not _check(_same_progress(restored_save, expected_save), "Restored recipes, structures, raft or slot order differ from the saved world"):
		return
	_record("Saved and continued the same raft, facilities, chest and exact backpack slots")
	if not (await _capture("08-continued-world.png")):
		return
	_release_keys()
	finished = true
	if not _write_report(true):
		push_error("PLAYTHROUGH FAIL: could not write report")
		get_tree().quit(1)
		return
	print("PLAYTHROUGH PASS: normal-input survival opening in %.2fs; %d hooked objects, %d fishing attempts" % [_seconds(), hook_count, fishing_results.size()])
	get_tree().quit(0)

func _exploration_loop() -> bool:
	await _tap(KEY_1)
	if not (await _gather({"wood": 11, "leaf": 8, "plastic": 4, "scrap": 4})):
		return false
	for index in 4:
		if not (await _craft_item("rope")):
			return false
	if not (await _craft_item("harpoon")):
		return false
	_record("Gathered the additional wood, scrap and rope and crafted a personal harpoon for the underwater fish")
	if not (await _walk(Vector2(416, 288), "edge for mining dive")) or not (await _act("dive")):
		return false
	if not (await _until(func() -> bool: return _player().area == "water", "diving from the raft", 3.0)):
		return false
	for kind in ["stone", "ore"]:
		var needed: int = 6 if kind == "stone" else 4
		while _count(kind) < needed and not finished:
			var nearest := ""
			var distance: float = INF
			var at := Vector2(float(_player().x), float(_player().y))
			for id in _state().entities:
				var node: Dictionary = _state().entities[id]
				var point := Vector2(float(node.x), float(node.y))
				if node.kind == kind and node.active and point.distance_to(at) < distance:
					nearest = str(id)
					distance = point.distance_to(at)
			if not _check(not nearest.is_empty(), "No natural mineral deposit for " + kind):
				return false
			var deposit: Dictionary = _state().entities[nearest]
			if not (await _walk(Vector2(float(deposit.x), float(deposit.y)), "swim to " + nearest)):
				return false
			var before: int = _count(kind)
			if not (await _act("mine", nearest)):
				return false
			var duration: float = 12.0 if kind == "stone" else 16.0
			if not _check(_player().activity.get("kind", "") == "gather" and is_equal_approx(float(_player().activity.get("duration", 0)), duration), "Bare mineral collection must start its real work timer"):
				return false
			if not (await _until(func() -> bool: return _count(kind) > before and not _state().entities[nearest].active and _player().activity.is_empty(), "collecting " + nearest + " over its natural work duration", duration + 3.0)):
				return false
	if not (await _capture("09-mining.png")):
		return false
	if not (await _walk(Vector2(120, 90), "return buoy")) or not (await _act("surface")):
		return false
	if not (await _until(func() -> bool: return _player().area == "deck", "return from mineral dive", 3.0)):
		return false
	_record("Swam to natural deposits and returned with six stone and four ore")
	if not (await _place("furnace", Vector2(480, 416))):
		return false
	var furnace := _structure_id("furnace")
	if not (await _walk(Vector2(480, 352), "furnace approach")) or not (await _act("smelt", furnace)):
		return false
	var remaining: float = float(_state().structures[furnace].remaining)
	if not _check(remaining > 13.0 and _count("ore") == 3, "Furnace must consume one ore and start its real timer"):
		return false
	if not (await _act("relocate", furnace)):
		return false
	await _tap(KEY_ESCAPE)
	if not _check(main.relocation.is_empty() and _state().structures[furnace].y == 416.0 and not main.pause_open, "Cancelling movement must leave the running furnace in place"):
		return false
	if not (await _act("relocate", furnace)):
		return false
	await _click_world(Vector2(480, 224))
	if not (await _until(func() -> bool: return main.relocation.is_empty() and _state().structures[furnace].y == 224.0, "relocating a running furnace", 3.0)):
		return false
	if not _check(_state().structures[furnace].output == "ingot" and float(_state().structures[furnace].remaining) > 0 and float(_state().structures[furnace].remaining) < remaining, "Relocation must preserve and keep advancing the processing job"):
		return false
	if not (await _walk(CENTER, "moved furnace")) or not (await _capture("10-smelting.png")):
		return false
	for batch in 4:
		if batch > 0 and not (await _act("smelt", furnace)):
			return false
		if not (await _until(func() -> bool: return float(_state().structures[furnace].remaining) <= 0, "natural fifteen-second smelting batch", 18.0)):
			return false
		if not (await _act("collect_output", furnace)):
			return false
		if not (await _until(func() -> bool: return _count("ingot") == batch + 1, "claiming the smelted ingot", 3.0)):
			return false
	if not (await _select_recipe("fins")) or not (await _capture("11-exploration-recipes.png")):
		return false
	await _tap(KEY_C)
	if not (await _craft_item("fins")) or not (await _craft_item("reinforced_hook")):
		return false
	_record("Built and moved a working furnace, waited four real smelts, crafted personal fins and a reinforced hook")
	# Put a real item in the built chest before moving it; no fixture inventory.
	if not (await _walk(Vector2(453, 337), "chest before relocation")) or not (await _act("open_chest")):
		return false
	await _settle(0.2)
	var chest_id := str(main.inventory_ui.chest_id)
	var cup_index := -1
	for index in _bag().size():
		if _bag()[index].get("item", "") == "cup":
			cup_index = index
	if not _check(not chest_id.is_empty() and cup_index >= 0, "Chest and reusable cup are required before relocation"):
		return false
	await _click(_slot_center(false, cup_index))
	await _click(_slot_center(true, 0))
	await _tap(KEY_B)
	var chest_contents: Array = _state().chests[chest_id].slots.duplicate(true)
	if not (await _act("relocate", chest_id)):
		return false
	await _click_world(Vector2(480, 416))
	if not (await _until(func() -> bool: return main.relocation.is_empty() and _state().chests[chest_id].y == 416.0 and _state().chests[chest_id].x == 480.0, "moving the chest with its contents", 3.0)):
		return false
	if not _check(_state().chests[chest_id].slots == chest_contents and Inventory.count(chest_contents, "cup") == 1, "Chest relocation lost or reordered inventory"):
		return false
	# A timed straight swim verifies that carrying the crafted fins changes movement.
	if not (await _walk(Vector2(416, 288), "raft edge with upgraded equipment")) or not (await _act("dive")):
		return false
	await _settle(0.1)
	var swim_start: float = float(_player().x)
	_send_key(KEY_D, true)
	held[KEY_D] = true
	await _settle(0.8)
	_release_keys()
	var distance: float = float(_player().x) - swim_start
	if not _check(distance > 118.0 and distance < 155.0, "Crafted fins should produce the faster real swim, got " + str(distance)):
		return false
	if not (await _capture("12-equipped-dive.png")) or not (await _seabed_search()):
		return false
	if not (await _walk(Vector2(120, 90), "upgraded dive return")) or not (await _act("surface")):
		return false
	await _tap(KEY_1)
	var remote_retrieved: bool = false
	var hook_deadline: int = Time.get_ticks_msec() + 60000
	while not remote_retrieved and not finished and Time.get_ticks_msec() < hook_deadline:
		var hook_target: String = ""
		var player_at := Vector2(float(_player().x), float(_player().y))
		for id in _state().drift:
			var drift: Dictionary = _state().drift[id]
			if not main.view.surface_is_clear(Vector2(float(drift.x), float(drift.y))):
				continue
			var span := player_at.distance_to(Vector2(float(drift.x), float(drift.y)))
			if drift.active and span > 292 and span < 376 and float(drift.x) > 32 and float(drift.x) < 866:
				var screen_point: Vector2 = main.view.get_global_transform_with_canvas() * Vector2(float(drift.x), float(drift.y))
				var blocked := false
				var hud_buttons: Array = [main.hud.bag_button, main.hud.crafting_button, main.hud.menu_button, main.hud.anchor_button, main.hud.map_button]
				hud_buttons.append_array(main.hud.quick_buttons)
				for button in hud_buttons:
					if button.visible and button.get_global_rect().grow(12).has_point(screen_point):
						blocked = true
						break
				if blocked:
					continue
				hook_target = str(id)
				break
		if hook_target.is_empty():
			await _settle(0.2)
			continue
		var drift: Dictionary = _state().drift[hook_target]
		var observed: Vector2 = Vector2(float(drift.x), float(drift.y))
		await _settle(0.15)
		var destination: Vector2 = Vector2(float(drift.x), float(drift.y))
		var velocity: Vector2 = (destination - observed) / 0.15
		var flight: float = player_at.distance_to(destination) / 160.0
		var wind: Vector2 = preload("res://scripts/salvage_hook.gd").wind(float(_state().elapsed))
		var aim: Vector2 = destination + (velocity - wind) * flight
		var screen_aim: Vector2 = main.view.get_global_transform_with_canvas() * aim
		if not get_viewport().get_visible_rect().has_point(screen_aim):
			continue
		var aim_blocked: bool = false
		var controls: Array = [main.hud.bag_button, main.hud.crafting_button, main.hud.menu_button, main.hud.anchor_button, main.hud.map_button]
		controls.append_array(main.hud.quick_buttons)
		for control in controls:
			if control.visible and control.get_global_rect().grow(12).has_point(screen_aim):
				aim_blocked = true
				break
		if aim_blocked:
			continue
		var before: int = Inventory.total_count(_bag())
		await _click_world(aim)
		if not (await _until(func() -> bool: return not _player().hook.is_empty(), "directional reinforced hook launch", 2.0)):
			return false
		if not _check(float(_player().hook.get("reach", 0)) == 400.0 and float(_player().hook.get("reel_speed", 0)) == 155.0 and not _player().hook.has("id"), "Crafted hook must expose its longer directional reach and faster physical reel speed"):
			return false
		# Continuing past first contact means final travel no longer proves where it hit.
		var contact := {"travel": 0.0, "distance": 0.0}
		var observe_contact: Callable = func() -> bool:
			var live: Dictionary = _player().hook
			if live.is_empty():
				return false
			if live.get("cargo", []).has(hook_target) and float(contact.travel) == 0.0:
				contact.travel = float(live.travel)
				contact.distance = Vector2(float(live.x), float(live.y)).distance_to(Vector2(float(_player().x), float(_player().y)))
			return str(live.phase) != "out"
		if not (await _until(observe_contact, "reinforced hook continues outward while recording its first distant contact", 3.5)):
			return false
		var cargo: Array = _player().hook.get("cargo", []).duplicate()
		await _tap(KEY_P)
		if not (await _until(func() -> bool: return _player().hook.is_empty(), "reinforced hook reels all the way to the player", 6.0)):
			return false
		remote_retrieved = cargo.has(hook_target) and float(contact.travel) > 290.0 and float(contact.distance) > 290.0 and not bool(_state().drift[hook_target].active) and Inventory.total_count(_bag()) > before
		if Inventory.total_count(_bag()) > before:
			hook_count += 1
		if not remote_retrieved:
			_record("Reinforced directional cast missed the distant target or caught nearer drift; observed and retried")
	if not _check(remote_retrieved, "Need a real directional collision beyond the basic hook's reach and substep margin, followed by a successful physical return"):
		return false
	_record("Moved the filled chest without changing its slots and verified the crafted fins through a timed real swim")
	_record("Used the crafted reinforced hook to retrieve drift outside the basic hook range")
	return true


func _seabed_search() -> bool:
	var wreck: Dictionary = _state().entities.wreck_00
	if not (await _walk(Vector2(float(wreck.x), float(wreck.y)), "natural seabed chest")):
		return false
	if not (await _capture("13-seabed-chest.png")):
		return false
	var before: int = _count("treasure")
	if not (await _act("search_wreck", "wreck_00")):
		return false
	if not _check(_player().activity.get("kind", "") == "gather" and is_equal_approx(float(_player().activity.get("duration", 0)), 7.0), "Seabed search must start a seven-second activity"):
		return false
	if not (await _until(func() -> bool: return _count("treasure") == before + 1 and not _state().entities.wreck_00.active and _player().activity.is_empty(), "searching a real seabed chest for seven seconds", 10.0)):
		return false
	await _tap(KEY_B)
	var treasure_index := -1
	for index in _bag().size():
		if _bag()[index].get("item", "") == "treasure":
			treasure_index = index
	if not _check(treasure_index >= 0 and main.inventory_ui.visible, "Recovered treasure must be selectable in the bag"):
		return false
	await _click(_slot_center(false, treasure_index))
	var wood_before := _count("wood")
	var fish_before := _count("fish")
	var seed_before := _count("seed")
	await _click(main.inventory_ui.open_button.get_global_rect().get_center())
	if not _check(_count("treasure") == before and _count("wood") == wood_before + 3 and _count("fish") == fish_before + 1 and _count("seed") == seed_before + 2, "Recovered treasure opens into exact supplies using the visible button"):
		return false
	await _capture("14-treasure-supplies.png")
	await _tap(KEY_B)
	# Catch a moving world fish through the crafted directional spear, allowing misses.
	if not (await _spear_fish("fish_04")):
		return false
	_record("Searched a natural seabed chest for seven seconds, opened its supplies through the bag, and speared a swimming fish")
	return true


func _spear_fish(preferred: String) -> bool:
	if not _check(_count("harpoon") > 0 and _player().area == "water", "Spearfishing needs the normally crafted personal harpoon underwater"):
		return false
	await _tap(KEY_4)
	var caught_before: int = _count("fish")
	for attempt in 6:
		var fish_id: String = preferred
		if not bool(_state().entities.get(fish_id, {}).get("active", false)):
			fish_id = ""
			for id in _state().entities:
				if _state().entities[id].kind == "fish" and _state().entities[id].active:
					fish_id = str(id)
					break
		if not _check(not fish_id.is_empty(), "A natural swimming fish must remain available"):
			return false
		var fish: Dictionary = _state().entities[fish_id]
		var target: Vector2 = Vector2(float(fish.x), float(fish.y))
		var approach: Vector2 = Vector2(clampf(target.x - 85.0, 45.0, 855.0), clampf(target.y, 40.0, 515.0))
		if not (await _walk(approach, "directional spear approach")):
			return false
		var observed: Vector2 = Vector2(float(fish.x), float(fish.y))
		await _settle(0.15)
		target = Vector2(float(fish.x), float(fish.y))
		var velocity: Vector2 = (target - observed) / 0.15
		var player_at: Vector2 = Vector2(float(_player().x), float(_player().y))
		var aim: Vector2 = target + velocity * (0.3 + player_at.distance_to(target) / 220.0)
		await _click_world(aim)
		if not (await _until(func() -> bool: return not _player().activity.is_empty() and _player().activity.kind == "spear", "4 and left click start the directional spear", 2.0)):
			return false
		if attempt == 0 and not (await _capture("15-directional-spear.png")):
			return false
		if not (await _until(func() -> bool: return _player().activity.is_empty(), "natural spear windup, flight and recovery", 4.0)):
			return false
		if _count("fish") > caught_before:
			break
		_record("Directional spear missed the moving fish; adjusted the next shot")
	await _tap(KEY_1)
	return _check(_count("fish") == caught_before + 1, "A directional spear collision must add exactly one natural fish")


func _gather(targets: Dictionary) -> bool:
	var deadline: int = Time.get_ticks_msec() + 210000
	while not finished and not _has_counts(targets):
		if Time.get_ticks_msec() > deadline:
			_fail("Gathering deadline; held " + JSON.stringify(Inventory.totals(_bag())))
			return false
		var player_at := Vector2(float(_player().x), float(_player().y))
		var candidate := ""
		var best_score: float = -INF
		for id in _state().drift:
			var object: Dictionary = _state().drift[id]
			if not object.active or float(object.x) < 35 or float(object.x) > 865:
				continue
			var point := Vector2(float(object.x), float(object.y))
			if not main.view.surface_is_clear(point):
				continue
			# A player cannot target drift hidden under an interactive HUD button.
			var on_screen: Vector2 = main.view.get_global_transform_with_canvas() * point
			var covered := false
			var buttons: Array = [main.hud.bag_button, main.hud.crafting_button, main.hud.menu_button, main.hud.anchor_button, main.hud.map_button]
			buttons.append_array(main.hud.quick_buttons)
			for button in buttons:
				if button.visible and button.get_global_rect().grow(12).has_point(on_screen):
					covered = true
					break
			if covered:
				continue
			var rewards: Dictionary = {"wood": 2, "leaf": 2, "plastic": 2, "scrap": 1, "seed": 1} if object.kind == "barrel" else {str(object.kind): 1 if object.kind == "scrap" else 2}
			var benefit: float = 0
			for item in targets:
				benefit += mini(maxi(0, int(targets[item]) - _count(str(item))), int(rewards.get(item, 0)))
			if benefit <= 0:
				continue
			var distance: float = player_at.distance_to(point)
			var score: float = benefit * 100 - distance - (400 if distance > 266 else 0)
			if score > best_score:
				candidate = str(id)
				best_score = score
		if candidate.is_empty():
			await _settle(0.25)
			continue
		var chosen: Dictionary = _state().drift[candidate]
		var destination := Vector2(float(chosen.x), float(chosen.y))
		if player_at.distance_to(destination) > 266:
			var best_stand: Vector2 = player_at
			var nearest: float = player_at.distance_to(destination)
			for tile in _state().deck_tiles:
				var at: Vector2 = _tile_center(str(tile))
				if _walkable(at) and at.distance_to(destination) < nearest:
					best_stand = at
					nearest = at.distance_to(destination)
			if best_stand.distance_to(player_at) > 8:
				if not (await _walk(best_stand, "edge nearest needed drift")):
					return false
			else:
				await _settle(0.3)
			continue
		var before: int = Inventory.total_count(_bag())
		# Observe drift motion and aim ahead, as a player must; misses are allowed.
		var observed := destination
		await _settle(0.15)
		destination = Vector2(float(chosen.x), float(chosen.y))
		var velocity := (destination - observed) / 0.15
		var flight := player_at.distance_to(destination) / 160.0
		var wind: Vector2 = preload("res://scripts/salvage_hook.gd").wind(float(_state().elapsed))
		var aim := destination + (velocity - wind) * flight
		await _click_world(aim)
		if not (await _until(func() -> bool: return not _player().hook.is_empty(), "mouse click launches hook at " + candidate, 2.0)):
			return false
		if not (await _pull_hook()):
			return false
		if not (await _until(func() -> bool: return _player().hook.is_empty(), "hook returns with " + candidate, 5.0)):
			return false
		if Inventory.total_count(_bag()) > before:
			hook_count += 1
			_record("Directional hook collected supplies")
		else:
			_record("Directional hook missed; observed drift and retried")
	return not finished

func _pull_hook() -> bool:
	if not (await _until(func() -> bool: return not _player().hook.is_empty() and str(_player().hook.phase) != "out", "hook completes its uninterrupted outward flight", 3.5)):
		return false
	await _tap(KEY_P)
	return true

func _has_counts(targets: Dictionary) -> bool:
	for item in targets:
		if _count(str(item)) < int(targets[item]):
			return false
	return true

func _discard_seed_stack() -> bool:
	# Seeds are earned from real barrels; the discard check never silently skips.
	if _count("seed") == 0 and not (await _gather({"seed": 1})):
		return false
	await _tap(KEY_B)
	if not (await _until(func() -> bool: return main.inventory_ui.visible, "B opens the backpack for discarding", 3.0)):
		return false
	var before: Array = _bag().duplicate(true)
	var seed_index := -1
	for index in before.size():
		if not before[index].is_empty() and before[index].item == "seed":
			seed_index = index
			break
	if not _check(seed_index >= 0, "A normally collected barrel seed is required for the discard check"):
		return false
	var discarded: int = int(before[seed_index].count)
	var expected: Array = before.duplicate(true)
	expected[seed_index] = {}
	await _click(_slot_center(false, seed_index))
	if not (await _until(func() -> bool: return main.inventory_ui.selected.get("item", "") == "seed" and int(main.inventory_ui.selected.get("amount", 0)) == discarded, "left click selects the complete seed stack", 3.0)):
		return false
	await _click(main.inventory_ui.discard_button.get_global_rect().get_center())
	if not (await _until(func() -> bool: return main.inventory_ui.discard_dialog.visible, "Discard opens confirmation", 3.0)):
		return false
	if not _check(_bag() == before, "Opening discard confirmation consumed items before confirmation"):
		return false
	var confirm_at: Vector2 = main.inventory_ui.discard_confirm_button.get_global_rect().get_center()
	await _click(confirm_at)
	if not (await _until(func() -> bool: return not main.inventory_ui.discard_dialog.visible and _count("seed") == 0 and _bag() == expected, "confirmed seed discard preserves every other backpack slot", 3.0)):
		return false
	await _tap(KEY_B)
	if not (await _until(func() -> bool: return not main.inventory_ui.visible and not main.pause_open, "B closes the backpack after discarding", 3.0)):
		return false
	_record("Confirmed discard of %d barrel seeds; every other item and slot stayed unchanged" % discarded)
	return true

func _select_recipe(id: String) -> bool:
	if not main.crafting_ui.visible:
		await _tap(KEY_C)
	if not (await _until(func() -> bool: return main.crafting_ui.visible, "C opens crafting", 3.0)):
		return false
	if not _check(Recipes.ALL.has(id) and main.crafting_ui.recipe_buttons.has(id), "Unknown recipe button " + id):
		return false
	var category: String = main.crafting_ui._recipe_group(id)
	if main.crafting_ui.selected_category != category:
		await _click(main.crafting_ui.category_buttons[category].get_global_rect().get_center())
	# Scroll through the actual recipe list; added farm tools can move recipes below the fold.
	for attempt in 12:
		var bounds: Rect2 = main.crafting_ui.recipe_scroll.get_global_rect()
		var button_bounds: Rect2 = main.crafting_ui.recipe_buttons[id].get_global_rect()
		if bounds.encloses(button_bounds):
			break
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if button_bounds.end.y > bounds.end.y else MOUSE_BUTTON_WHEEL_UP
		wheel.position = bounds.get_center()
		wheel.global_position = wheel.position
		wheel.pressed = true
		get_viewport().push_input(wheel, true)
		await _settle(0.1)
	await _click(main.crafting_ui.recipe_buttons[id].get_global_rect().get_center())
	return await _until(func() -> bool: return str(main.crafting_ui.selected_recipe) == id and not main.crafting_ui.make_button.disabled, "selected affordable recipe " + id, 3.0)

func _craft_item(id: String) -> bool:
	var recipe: Dictionary = Recipes.ALL[id]
	var before: int = _count(str(recipe.result))
	if not (await _select_recipe(id)):
		return false
	await _click(main.crafting_ui.make_button.get_global_rect().get_center())
	if not (await _until(func() -> bool: return _count(str(recipe.result)) == before + int(recipe.amount), "crafting " + id + " through Make button", 3.0)):
		return false
	await _tap(KEY_C)
	return await _until(func() -> bool: return not main.crafting_ui.visible, "closing crafting", 2.0)

func _place(id: String, preferred: Vector2, recipe_shot: bool = false) -> bool:
	if not (await _walk(CENTER, "central build aisle")):
		return false
	var target: Vector2 = preferred
	if not main.world.can_place("host", id, target.x, target.y):
		target = Vector2(INF, INF)
		for gy in range(2, 7):
			for gx in range(2, 12):
				var point := Vector2(gx * 64 + 32, gy * 64 + 32)
				if point.distance_to(CENTER) < 50:
					continue
				if main.world.can_place("host", id, point.x, point.y):
					target = point
					break
			if target.is_finite():
				break
	if not _check(target.is_finite(), "No legal build location for " + id):
		return false
	if not (await _select_recipe(id)):
		return false
	if recipe_shot and not (await _capture("02-recipe-book.png")):
		return false
	var before_count: int = _state().deck_tiles.size() if id == "foundation" else (_state().chests.size() if id == "chest" else _state().structures.size())
	await _click(main.crafting_ui.make_button.get_global_rect().get_center())
	if not (await _until(func() -> bool: return str(main.placement_recipe) == id and not main.crafting_ui.visible, "recipe enters world placement", 3.0)):
		return false
	await _click_world(target)
	return await _until(func() -> bool: return _placed_count(id) == before_count + 1 and str(main.placement_recipe).is_empty(), "placing " + id, 3.0)

func _placed_count(id: String) -> int:
	if id == "foundation":
		return _state().deck_tiles.size()
	if id == "chest":
		return _state().chests.size()
	return _state().structures.size()

func _act(verb: String, structure: String = "") -> bool:
	if not (await _until(func() -> bool: return _option_index(verb, structure) >= 0, "available interaction " + verb, 4.0)):
		return false
	for attempt in range(16):
		var index: int = _option_index(verb, structure)
		if index >= 0 and int(main.selected_option) == index:
			await _tap(KEY_E)
			return not finished
		await _tap(KEY_TAB)
	_fail("Could not select interaction " + verb + " using Tab")
	return false

func _option_index(verb: String, structure: String = "") -> int:
	for index in main.current_options.size():
		var option: Dictionary = main.current_options[index]
		if str(option.action) == verb and (structure.is_empty() or str(option.get("args", {}).get("id", "")) == structure):
			return index
	return -1

func _fish_until_caught() -> bool:
	for attempt in range(14):
		var before: Dictionary = Inventory.totals(_bag())
		var start: float = float(_state().elapsed)
		# Selecting tool 2 and clicking the open sea uses the normal mouse cast path.
		await _click_world(Vector2(480, 455))
		if not (await _until(func() -> bool: return not _player().fishing.is_empty(), "mouse casting with selected rod", 3.0)):
			return false
		if not (await _until(func() -> bool: return not _player().fishing.is_empty() and float(_player().fishing.remaining) <= 0, "natural fishing bite", 9.0)):
			return false
		if not _check(float(_state().elapsed) - start >= 4.9, "Fishing did not wait five game seconds"):
			return false
		await _click_world(Vector2(480, 455))
		if not (await _until(func() -> bool: return _player().fishing.is_empty(), "mouse reeling", 3.0)):
			return false
		var outcome := ""
		for item in Inventory.ITEMS:
			var change: int = _count(item) - int(before[item])
			if change == 1 and item in ["fish", "wood", "treasure"] and outcome.is_empty():
				outcome = str(item)
			elif not _check(change == 0, "Reeling changed more than the one earned item"):
				return false
		if not _check(not outcome.is_empty(), "Reeling produced no catch"):
			return false
		fishing_results.append(outcome)
		_record("Rod catch: " + outcome)
		if outcome == "fish":
			return true
	_fail("Fourteen real fishing attempts yielded no fish; random outcomes: " + str(fishing_results))
	return false

func _inventory_round_trip() -> bool:
	if not (await _act("open_chest")):
		return false
	if not (await _until(func() -> bool: return main.inventory_ui.visible and not str(main.inventory_ui.chest_id).is_empty(), "new chest opens its slot panel", 3.0)):
		return false
	var chest_id: String = str(main.inventory_ui.chest_id)
	var before_bag: Array = _bag().duplicate(true)
	var before_chest: Array = _state().chests[chest_id].slots.duplicate(true)
	var cup_index := -1
	var target_index := -1
	for index in _bag().size():
		if not _bag()[index].is_empty() and _bag()[index].item == "cup":
			cup_index = index
	for index in before_chest.size():
		if before_chest[index].is_empty():
			target_index = index
			break
	if not _check(cup_index >= 0 and target_index >= 0, "A returned cup and an empty chest slot are required"):
		return false
	await _click(_slot_center(false, cup_index))
	await _click(_slot_center(true, target_index))
	if not (await _until(func() -> bool: return _count("cup") == 0 and Inventory.count(_state().chests[chest_id].slots, "cup") == 1, "manual cup deposit", 3.0)):
		return false
	if not (await _capture("06-inventory.png")):
		return false
	await _click(_slot_center(true, target_index))
	await _click(_slot_center(false, cup_index))
	if not (await _until(func() -> bool: return _bag() == before_bag and _state().chests[chest_id].slots == before_chest, "manual retrieval preserves exact slots", 3.0)):
		return false
	await _tap(KEY_ESCAPE)
	if not (await _until(func() -> bool: return not main.inventory_ui.visible and not main.pause_open, "Esc closes slots without opening pause", 3.0)):
		return false
	_record("Stored and retrieved the reusable cup through actual inventory slots")
	return true

func _walk(target: Vector2, label: String) -> bool:
	if _player().area != "deck":
		return await _walk_segment(target, label)
	var start_key: String = _tile_key(Vector2(float(_player().x), float(_player().y)))
	var goal_key: String = _tile_key(target)
	var queue: Array[String] = [start_key]
	var parents: Dictionary = {start_key: ""}
	var cursor := 0
	while cursor < queue.size() and not parents.has(goal_key):
		var current: String = queue[cursor]
		cursor += 1
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var next: String = _tile_key(_tile_center(current) + direction * 64)
			if not parents.has(next) and next in _state().deck_tiles and _walkable(_tile_center(next)):
				parents[next] = current
				queue.append(next)
	if not _check(parents.has(goal_key) and _walkable(target), "No normal walking route to " + label):
		return false
	var path: Array[String] = []
	var key: String = goal_key
	while key != start_key:
		path.push_front(key)
		key = str(parents[key])
	# Center the starting cell before crossing its boundary; this avoids clipping
	# the corner of a neighboring facility during a physically valid route.
	if not (await _walk_segment(_tile_center(start_key), label)):
		return false
	for cell in path:
		if not (await _walk_segment(_tile_center(cell), label)):
			return false
	return await _walk_segment(target, label)

func _walk_segment(target: Vector2, label: String) -> bool:
	var start := Vector2(float(_player().x), float(_player().y))
	var route_length := absf(target.x - start.x) + absf(target.y - start.y)
	# The farthest laden return swim can exceed the old fixed seven seconds.
	# Keep a separate no-progress deadline so a blocked input still fails quickly.
	var deadline: int = Time.get_ticks_msec() + int(maxf(7.0, route_length / 70.0 + 2.0) * 1000)
	var progress_at := start
	var progress_ms := Time.get_ticks_msec()
	while not finished:
		var at := Vector2(float(_player().x), float(_player().y))
		if at.distance_to(progress_at) > 2.0:
			progress_at = at
			progress_ms = Time.get_ticks_msec()
		var delta: Vector2 = target - at
		if absf(delta.x) < 3.5 and absf(delta.y) < 3.5:
			_release_keys()
			await _settle(0.09)
			return true
		if Time.get_ticks_msec() > deadline or Time.get_ticks_msec() - progress_ms > 2000:
			_fail("WASD walking stalled at " + label + " from " + str(at) + " toward " + str(target))
			return false
		var wanted := KEY_D if delta.x > 0 else KEY_A
		if absf(delta.x) < 3.5:
			wanted = KEY_S if delta.y > 0 else KEY_W
		for code in MOVE_KEYS:
			var down: bool = code == wanted
			# A background window can lose its physical-key state independently of
			# the replay's cache. Reconcile through the normal input-event path.
			if bool(held.get(code, false)) != down or Input.is_physical_key_pressed(code) != down:
				_send_key(code, down)
				held[code] = down
		await get_tree().physics_frame
	return false

func _walkable(point: Vector2) -> bool:
	for offset in [Vector2(-10, -10), Vector2(10, -10), Vector2(-10, 10), Vector2(10, 10)]:
		if _tile_key(point + offset) not in _state().deck_tiles:
			return false
	for objects in [_state().structures, _state().chests]:
		for object in objects.values():
			if absf(point.x - float(object.x)) < 29 and absf(point.y - float(object.y)) < 29:
				return false
	return true

func _tile_key(point: Vector2) -> String:
	return "%d,%d" % [floori(point.x / 64), floori(point.y / 64)]

func _tile_center(key: String) -> Vector2:
	var parts := key.split(",")
	return Vector2(int(parts[0]) * 64 + 32, int(parts[1]) * 64 + 32)

func _structure_id(kind: String) -> String:
	for id in _state().structures:
		if _state().structures[id].kind == kind:
			return str(id)
	return ""

func _state() -> Dictionary:
	return main.world.data

func _player() -> Dictionary:
	return _state().players.host

func _bag() -> Array:
	return _player().bag

func _count(item: String) -> int:
	return Inventory.count(_bag(), item)

func _same_progress(actual: Dictionary, expected: Dictionary) -> bool:
	# JSON decimal parsing can differ by the last binary float bit. Counts,
	# slots and layout remain exact; only sailing floats have a sub-pixel tolerance.
	var a := actual.duplicate(true)
	var b := expected.duplicate(true)
	var actual_nav: Dictionary = a.navigation
	var expected_nav: Dictionary = b.navigation
	a.erase("navigation")
	b.erase("navigation")
	if a != b or actual_nav.size() != expected_nav.size() or bool(actual_nav.anchored) != bool(expected_nav.anchored):
		return false
	for key in actual_nav:
		if key not in ["anchored", "moored"] and absf(float(actual_nav[key]) - float(expected_nav[key])) > 1.0e-8:
			return false
	return true

func _saved_progress() -> Dictionary:
	return {"navigation": _state().navigation.duplicate(true), "version": int(_state().version), "day": int(_state().day), "deck_tiles": _state().deck_tiles.duplicate(), "structures": _state().structures.duplicate(true), "chests": _state().chests.duplicate(true), "bag": _bag().duplicate(true), "caught": int(_player().caught), "wreck": _state().entities.wreck_00.duplicate(true)}

func _slot_center(chest: bool, index: int) -> Vector2:
	var button: Button = main.inventory_ui.chest_buttons[index] if chest else main.inventory_ui.bag_buttons[index]
	return button.get_global_rect().get_center()

func _send_key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	event.echo = false
	Input.parse_input_event(event)

func _release_keys() -> void:
	for code in MOVE_KEYS:
		if bool(held.get(code, false)) or Input.is_physical_key_pressed(code):
			_send_key(code, false)
	held.clear()

func _tap(code: int) -> void:
	if finished:
		return
	inputs.append({"type": "key", "key": OS.get_keycode_string(code), "seconds": _seconds()})
	_send_key(code, true)
	await get_tree().process_frame
	_send_key(code, false)
	await _settle(0.12)

func _click_world(point: Vector2) -> void:
	var rendered := point
	if not main.placement_recipe.is_empty() or not main.relocation.is_empty():
		rendered = main.view.world_to_screen(point, "deck")
	elif _player().area == "island":
		rendered = main.view.world_to_screen(point, "island")
	await _click(main.view.position + rendered * main.view.scale)

func _click(at: Vector2, target: Viewport = null) -> void:
	if finished:
		return
	var viewport: Viewport = get_viewport() if target == null else target
	inputs.append({"type": "click", "x": at.x, "y": at.y, "viewport": str(viewport.name), "seconds": _seconds()})
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	await get_tree().process_frame
	var down := InputEventMouseButton.new()
	down.position = at
	down.global_position = at
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	viewport.push_input(down, true)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.position = at
	up.global_position = at
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	viewport.push_input(up, true)
	await _settle(0.14)

func _save_and_title() -> bool:
	await _tap(KEY_ESCAPE)
	if not (await _until(func() -> bool: return bool(main.pause_open) and main.pause_overlay.visible, "Esc opens pause", 3.0)):
		return false
	await _click(main.return_title_button.get_global_rect().get_center())
	return await _until(func() -> bool: return str(main.mode) == "menu" and main.overlay.visible, "Save and Return to Title", 4.0)

func _until(predicate: Callable, label: String, timeout: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000)
	while not finished:
		if bool(predicate.call()):
			return true
		if Time.get_ticks_msec() > deadline:
			_fail("Timed out: " + label + "; HUD=" + str(main.status.text))
			return false
		await get_tree().process_frame
	return false

func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _capture(filename: String) -> bool:
	await _settle(0.15)
	await RenderingServer.frame_post_draw
	if finished:
		return false
	var directory := ProjectSettings.globalize_path(str(main.cli["evidence-dir"]))
	if not _check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Cannot create evidence directory"):
		return false
	var path: String = directory.path_join(filename)
	var shot: Image = get_viewport().get_texture().get_image()
	if not _check(shot != null and not shot.is_empty() and shot.save_png(path) == OK, "Cannot save rendered screenshot " + filename):
		return false
	screenshots.append(path)
	return true

func _record(label: String) -> void:
	steps.append({"label": label, "seconds": _seconds(), "items": Inventory.totals(_bag()), "tiles": _state().deck_tiles.size()})
	print("PLAYTHROUGH %.2fs: %s" % [_seconds(), label])

func _seconds() -> float:
	return float(Time.get_ticks_msec() - started_ms) / 1000.0

func _check(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
	return condition

func _fail(message: String) -> void:
	if finished:
		return
	failure = message
	failure_context = _input_context()
	finished = true
	_release_keys()
	_write_report(false)
	push_error("PLAYTHROUGH FAIL: " + message)
	get_tree().quit(1)

func _input_context() -> Dictionary:
	var cached: Dictionary = {}
	var physical: Dictionary = {}
	for code in MOVE_KEYS:
		var key: String = OS.get_keycode_string(code)
		cached[key] = bool(held.get(code, false))
		physical[key] = Input.is_physical_key_pressed(code)
	return {
		"held_keys": cached,
		"physical_keys": physical,
		"mode": str(main.mode),
		"pause_flags": {
			"pause_open": bool(main.pause_open),
			"room_paused": bool(main.room_paused),
			"title_visible": bool(main.overlay.visible),
			"pause_overlay_visible": bool(main.pause_overlay.visible),
			"inventory_visible": bool(main.inventory_ui.visible),
			"crafting_visible": bool(main.crafting_ui.visible),
			"discard_visible": bool(main.inventory_ui.discard_dialog.visible),
		},
	}

func _write_report(passed: bool) -> bool:
	if not main.cli.has("report"):
		return false
	var path := ProjectSettings.globalize_path(str(main.cli["report"]))
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"passed": passed, "failure": failure, "failure_context": failure_context, "elapsed_seconds": _seconds(), "method": "Normal viewport mouse clicks and physical WASD/C/B/M/G/P/1/2/3/4/5/6/7/8/N/Tab/E/Esc events; read-only state observation and placement eligibility", "steps": steps, "inputs": inputs, "screenshots": screenshots, "hook_count": hook_count, "fishing_results": fishing_results, "saved_progress": expected_save, "restored_progress": restored_save, "final_bag": _bag().duplicate(true), "final_world": _state().duplicate(true)}, "\t"))
	file.flush()
	var error: int = file.get_error()
	file.close()
	return error == OK

extends "res://tests/playthrough.gd"
## A separate normal-input journey, starting with an empty backpack.
const IslandState = preload("res://scripts/island_state.gd")

const IslandMap = preload("res://scripts/island_map.gd")
const Farming = preload("res://scripts/farming.gd")
const IslandTown = preload("res://scripts/island_town.gd")
const Rooms = preload("res://scripts/rooms.gd")
const ResidentRoutes = preload("res://scripts/resident_routes.gd")

func _process(_delta: float) -> void:
	if not finished and _seconds() > 600.0:
		_fail("Normal-input island farming and indoor services exceeded 600 real seconds")

func _run() -> void:
	for argument in ["save-path", "report", "evidence-dir"]:
		if not main.cli.has(argument):
			_fail("Missing isolated argument: " + argument)
			return
	for version in range(1, 19):
		if ProjectSettings.globalize_path(main.save_path).to_lower() == ProjectSettings.globalize_path("user://world_v%d.json" % version).to_lower():
			_fail("Never use the player's default save")
			return
	if FileAccess.file_exists(main.save_path) or FileAccess.file_exists(str(main.save_path) + ".bak"):
		_fail("Use a new isolated save")
		return
	await _settle(0.3)
	await _click(main.new_game_button.get_global_rect().get_center())
	if not _check(_player().area == "deck" and Inventory.total_count(_bag()) == 0, "Empty bag through real title button"):
		return
	if not (await _gather({"wood": 33, "leaf": 18, "plastic": 10, "scrap": 8})):
		return
	for index in 9:
		if not (await _craft_item("rope")):
			return
	# Natural multi-object catches leave partial stacks. Use the real sort button
	# before adding four distinct tools; never enlarge or silently rewrite the bag.
	await _tap(KEY_B)
	await _click(main.inventory_ui.sort_bag_button.get_global_rect().get_center())
	await _tap(KEY_B)
	for recipe in ["paddle", "anchor", "scythe", "watering_can"]:
		if not (await _craft_item(recipe)):
			return
	if not (await _place("chest", Vector2(544, 352))):
		return
	if not (await _place("workbench", Vector2(416, 352))):
		return
	if not (await _walk(Vector2(506, 319), "organize tools by crafted chest")) or not (await _act("open_chest")):
		return
	await _click(main.inventory_ui.sort_bag_button.get_global_rect().get_center())
	for item in ["leaf", "scrap"]:
		for index in _bag().size():
			if _bag()[index].get("item", "") != item:
				continue
			var slots: Array = _state().chests[main.inventory_ui.chest_id].slots
			for target in slots.size():
				if slots[target].is_empty():
					await _drag(_slot_center(false, index), _slot_center(true, target))
					break
	await _tap(KEY_B)
	await _tap(KEY_G)
	await _tap(KEY_H)
	if not (await _walk(Vector2(550, 300), "dive edge")) or not (await _act("dive")):
		return
	# The western two deposits are outside enemy patrols when worked from the west.
	# Four natural stone make a pickaxe; the first shore rock funds the axe and hoe.
	# No defenseless twelve-second mining in the shark's hunting ground.
	for id in ["stone_00", "stone_04"]:
		var node: Dictionary = _state().entities[id]
		if not (await _collect_in_dive(id, "mine", 12.0, Vector2(float(node.x)-48, float(node.y)))):
			return
	if not _check(_count("stone") == 4, "Two natural twelve-second western deposits yield four stone"):
		return
	if not (await _swim_work_route(Vector2(120, 90), "return buoy")) or not (await _act("surface")):
		return
	if not (await _craft_item("pickaxe")):
		return
	if not _check(_count("stone") == 1, "Handmade pickaxe consumes three of the naturally collected stone"):
		return
	if not (await _walk(Vector2(462, 236), "rest by bedroll")) or not (await _act("rest")):
		return
	if not (await _until(func() -> bool: return float(_player().stamina) > 95, "recover for paddling and farming", 22)):
		return
	if not (await _act("wake")):
		return
	await _tap(KEY_G)
	_record("Hooked supplies, mined two safe western deposits for twelve seconds each and hand-crafted the pickaxe without grants")
	await _equip_tool("paddle")
	var sailing_deadline := Time.get_ticks_msec() + 70000
	while not finished:
		var offset: Vector2 = Archipelago.island_position(_state().chart) - Vector2(float(_state().navigation.x), float(_state().navigation.y))
		if offset.length() <= 85:
			break
		if Time.get_ticks_msec() > sailing_deadline:
			_fail("Could not paddle to first island through normal input")
			return
		var origin: Vector2 = main.view.world_to_screen(Vector2(float(_player().x), float(_player().y)))
		await _click_world(origin + offset.normalized() * 175)
		await _settle(0.62)
	await _tap(KEY_G)
	if not _check(bool(_state().navigation.anchored) and Archipelago.within_docking_range(_state().chart, _state().navigation), "Sailed and anchored inside the actual docking radius"):
		return
	_record("Reached the island through real drift and any necessary paddle clicks, then anchored")
	await _tap(KEY_H)
	if not (await _walk(Vector2(555, 288), "island-facing raft edge")):
		return
	if not (await _capture("02-near-shore.png")) or not (await _menu_action("land")):
		return
	if not _check(_player().area == "island" and _state().chart.visited, "Landed through the visible nearby action menu"):
		return
	if not (await _capture("03-landed.png")):
		return
	if not (await _gather_island("stone_0")):
		return
	if not _check(_count("stone") == 4, "Natural shore rock supplies the remaining axe and hoe materials"):
		return
	for recipe in ["axe", "hoe"]:
		if not (await _craft_item(recipe)):
			return
	_record("Used the handmade pickaxe on the actual shore rock, then hand-crafted the axe and hoe from its stone")
	for id in ["palm_0", "wood_1", "seeds_0", "palm_1"]:
		if not (await _gather_island(id)):
			return
	await _tap(KEY_M)
	if not _check(main.island_atlas.visible and not main.chart_ui.visible, "M opens the actual island atlas"):
		return
	await _click(main.island_atlas.region_buttons.harbor.get_global_rect().get_center())
	await _capture("04-island-region.png")
	await _tap(KEY_M)
	# A real boundary crossing proves the atlas represents walkable world space.
	for target in [Vector2(840, 280), Vector2(960, 352)]:
		if not (await _walk(target, "walk into next island page")):
			return
	if not _check(IslandMap.page_origin(Vector2(_player().x, _player().y)).x == 896, "Walking changes the page without teleport input"):
		return
	await _capture("05-next-page.png")
	var fiber_id := ""
	for id in IslandMap.nodes_near(Vector2(960, 352)):
		var node: Dictionary = IslandMap.node(id)
		if node.kind == "fiber" and IslandState.active(_state().island,str(id),int(_state().day)) and node.x >= 896 and node.x < 1792 and node.y < 544:
			fiber_id = id
			break
	if not _check(not fiber_id.is_empty(), "Second page has natural fiber") or not (await _gather_island(fiber_id)):
		return
	# Variable hook catches can leave two partial wood stacks after crafting tools.
	# Use the player's visible sort control to make room for the canopy result.
	await _tap(KEY_B)
	await _click(main.inventory_ui.sort_bag_button.get_global_rect().get_center())
	await _tap(KEY_B)
	# Advanced farm kit is assembled at the actual shared raft workbench.
	for target in [Vector2(840, 280), Vector2(640, 320), IslandState.DOCK]:
		if not (await _walk(target, "return to raft workbench")):
			return
	if not (await _menu_action("board_raft")) or not (await _walk(Vector2(453, 337), "workbench")):
		return
	if not (await _craft_item("canopy")):
		return
	if not (await _walk(Vector2(555, 288), "return ashore")) or not (await _menu_action("land")):
		return
	_record("Returned to the built raft workbench to assemble the canopy, then carried it ashore")
	for target in [Vector2(960, 352), Vector2(640, 320), Vector2(640, 430)]:
		if not (await _walk(target, "return to freshwater")):
			return
	if not (await _menu_action("refill_can")):
		return
	if not _check(int(_player().can_water) == 20, "Watering can fills at the visible freshwater pool"):
		return
	if not (await _walk(Vector2(520, 365), "farm clearing")):
		return
	var first := Vector2(496, 336)
	var second := Vector2(528, 336)
	await _hold_item("hoe")
	await _click_world(first)
	await _click_world(second)
	if not _check(_state().island.plots.size() == 2, "Two separate clicks till exactly two cells"):
		return
	await _hold_item("canopy")
	await _click_world(second)
	await _hold_item("seed")
	var seed_before := _count("seed")
	await _click_world(first)
	await _click_world(second)
	if not _check(_count("seed") == seed_before - 2 and _state().island.plots["16,10"].covered, "Each cell consumes one seed and crafted canopy covers only its chosen cell"):
		return
	await _hold_item("watering_can")
	await _click_world(first)
	if not _check(int(_player().can_water) == 19 and _state().island.plots["15,10"].watered and not _state().island.plots["16,10"].watered, "Water click spends one charge only on its own cell"):
		return
	await _capture("06-planted-two-cells.png")
	await _settle(2.0)
	if not _check(int(_state().island.plots["15,10"].growth) == 0, "Waiting in real time cannot ripen an island crop"):
		return
	await _tap(KEY_H)
	for night in 4:
		if night > 0:
			if not (await _walk(Vector2(520, 365), "daily watering")):
				return
			await _hold_item("watering_can")
			await _click_world(first)
			await _tap(KEY_H)
		if not (await _walk(IslandState.CAMP, "island camp")):
			return
		var old_day := int(_state().day)
		if not (await _menu_action("sleep")):
			return
		if not _check(int(_state().day) == old_day + 1 and int(_state().island.plots["15,10"].growth) == night + 1 and int(_state().island.plots["16,10"].growth) == 0, "Normal camp sleep grows watered crop once and leaves dry covered crop unchanged"):
			return
	if not (await _walk(Vector2(520, 365), "harvest mature crop")):
		return
	await _capture("07-four-day-crop.png")
	var before_veg := _count("veg")
	await _click_world(first)
	if not _check(_count("veg") == before_veg + 2 and _state().island.plots["15,10"].crop == "" and _state().island.plots["16,10"].crop == "seed", "Harvest picks only the mature clicked cell after four watered nights"):
		return
	_record("Walked across island pages, gathered timed tool resources, crafted a canopy, planted two cells and harvested after four actual camp nights")
	if not (await _town_journey()):
		return
	if not (await _homestead_journey()):
		return
	expected_save = _saved_progress()
	if not (await _save_and_title()):
		return
	await _click(main.continue_button.get_global_rect().get_center())
	if not (await _until(func() -> bool: return main.mode == "solo", "Continue island farm", 3)):
		return
	restored_save = _saved_progress()
	if not _check(_player().area == "island" and Vector2(_player().x, _player().y).distance_to(Vector2(520, 365)) < 5, "Continue returns the island farmer to the saved field instead of resetting to the raft"):
		return
	if not _check(_same_progress(restored_save, expected_save), "Save/Continue preserves sparse farmland, personal can water and gathered resources"):
		return
	await _capture("08-resumed-farm.png")
	_record("Normal Save and Continue preserved the island journey exactly")
	_release_keys()
	finished = true
	if not _write_report(true):
		get_tree().quit(1)
		return
	print("ISLAND FARM PLAYTHROUGH PASS: %.2fs; %d hooked objects; no state grants or clock changes" % [_seconds(), hook_count])
	get_tree().quit(0)

func _town_journey() -> bool:
	for target in [Vector2(840, 352), Vector2(1344, 352), IslandMap.LANDMARKS.market.door + Vector2(0, 40)]:
		if not (await _walk(target, "walk from reclaimed field to the town market")):
			return false
	if not (await _until(func() -> bool: return IslandTown.open_at("lin_sui", _state().minute), "wait for normal market opening time", 25)):
		return false
	if not (await _enter_town_room("market")) or not (await _approach_resident("lin_sui")):
		return false
	await _click_world(IslandTown.position("lin_sui", _state().minute))
	if not _check(main.dialogue_ui.visible and "林穗" in main.dialogue_ui.speaker.text, "Left click speaks with the owner inside the market without spending money"):
		return false
	await _capture("09-town-conversation.png")
	await _tap(KEY_ESCAPE)
	var before_money := int(_state().money)
	for index in 2:
		if not (await _town_menu("town_trade", "sell_veg")):
			return false
	if not _check(_count("veg") == 0 and int(_state().money) == before_money + 8, "Two real farm harvests sell for eight coins through the visible market menu"):
		return false
	var before_seed := _count("seed")
	if not (await _town_menu("town_trade", "buy_seed")):
		return false
	if not _check(_count("seed") == before_seed + 1 and int(_state().money) == before_money + 5, "Seasonal seed purchase uses exactly three earned coins"):
		return false
	if not (await _leave_town_room("market")):
		return false
	for target in [Vector2(1344, 912), Vector2(1344, 280), Vector2(1840, 280)]:
		if not (await _walk(target, "town road to wild land")):
			return false
	var obstruction: Dictionary = {}
	for node: Dictionary in IslandMap.nodes_near(Vector2(2000, 280)).values():
		if str(node.id).begins_with("clear_2_0_") and node.kind == "fiber" and node.y < 350:
			obstruction = node
			break
	if not _check(not obstruction.is_empty(), "Natural uncultivated land contains real scythe-cleared grass"):
		return false
	var point := Vector2(obstruction.x, obstruction.y)
	if not (await _walk(point, "overgrown grass cell")):
		return false
	await _hold_item("hoe")
	var old_plots: int = _state().island.plots.size()
	await _click_world(point)
	if not _check(_state().island.plots.size() == old_plots, "Hoe cannot skip uncleared wild grass"):
		return false
	if not (await _gather_island(str(obstruction.id))):
		return false
	await _hold_item("hoe")
	await _click_world(point)
	await _hold_item("seed")
	await _click_world(point)
	await _hold_item("watering_can")
	await _click_world(point)
	if not _check(_state().island.plots.size() == old_plots + 1 and _state().island.plots[Farming.plot_key(point)].watered and _state().island.plots[Farming.plot_key(point)].crop == "seed", "Clear then hoe then sow then water creates exactly one new reclaimed plot"):
		return false
	await _capture("10-self-reclaimed-land.png")
	await _tap(KEY_H)
	for target in [Vector2(1840, 280), Vector2(1344, 280), Vector2(1344, 576), IslandMap.LANDMARKS.bathhouse.door + Vector2(0, 36)]:
		if not (await _walk(target, "return to town bathhouse")):
			return false
	if not (await _until(func() -> bool: return IslandTown.open_at("tang_he", _state().minute), "wait for real bathhouse opening at ten", 45)):
		return false
	if not (await _enter_town_room("bathhouse")) or not (await _walk(Vector2(400, 560), "walk through bathhouse corridor into the actual pool")):
		return false
	if not _check(Rooms.bathing(_player()), "Bath service starts only after walking into real pool water"):
		return false
	var money := int(_state().money)
	if not (await _town_menu("town_bath")):
		return false
	if not _check(_player().activity.get("kind") == "town_bath" and int(_state().money) == money, "Bath starts visibly and does not charge before completion"):
		return false
	await _capture("11-town-bath.png")
	if not (await _until(func() -> bool: return _player().activity.is_empty(), "eight real seconds of bathing", 10)):
		return false
	if not _check(int(_state().money) == money - 3, "Finished bathing charges only three coins"):
		return false
	if not (await _leave_town_room("bathhouse")):
		return false
	for target in [Vector2(1344, 576), Vector2(1344, 280), Vector2(960, 352), Vector2(840, 280), Vector2(520, 365)]:
		if not (await _walk(target, "walk home to preserved farm")):
			return false
	_record("Entered the market and found its working owner, sold crops and bought seed, reclaimed wild grass, then entered the bathhouse pool and paid only after eight real bath seconds")
	return true

func _enter_town_room(id: String) -> bool:
	if not _check(_player().area == "island", "Approach the actual exterior before entering " + id):
		return false
	await _tap(KEY_H)
	await _click_world(IslandMap.LANDMARKS[id].door)
	return await _until(func() -> bool: return _player().area == "room" and _player().room == id, "actual doorway enters " + id, 3.0)

func _leave_town_room(id: String) -> bool:
	if not _check(_player().area == "room" and _player().room == id, "Exit the same room through its doorway: " + id):
		return false
	await _tap(KEY_H)
	if not (await _walk(Rooms.entry(id), "walk back to " + id + " entrance")) or not (await _menu_action("room_exit")):
		return false
	return await _until(func() -> bool: return _player().area == "island" and Vector2(_player().x, _player().y).distance_to(IslandMap.LANDMARKS[id].door) < 5, "doorway returns to the correct " + id + " exterior", 3.0)

func _approach_resident(id: String) -> bool:
	var at_work := func() -> bool:
		var place: Dictionary = IslandTown.location(id, float(_state().minute))
		return IslandTown.open_at(id, float(_state().minute)) and place.area == _player().area and place.room == _player().room and not place.moving
	if not (await _until(at_work, "wait for the actual resident to arrive at work: " + id, 25.0)):
		return false
	var point: Vector2 = IslandTown.position(id, float(_state().minute))
	var here := Vector2(_player().x, _player().y)
	var candidates: Array[Vector2] = [point + Vector2(0, 32), point + Vector2(32, 0), point - Vector2(32, 0), point - Vector2(0, 32)]
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return here.distance_squared_to(a) < here.distance_squared_to(b))
	for candidate in candidates:
		if Rooms.can_stand(str(_player().room), candidate):
			if not (await _walk(candidate, "walk to working resident " + id)):
				return false
			return _check(at_work.call() and Vector2(_player().x, _player().y).distance_to(IslandTown.position(id, float(_state().minute))) <= IslandTown.REACH, "Resident is actually present and within conversation reach: " + id)
	_fail("No legal standing cell near resident " + id)
	return false

func _town_menu(verb: String, offer: String = "") -> bool:
	await _settle(0.18)
	var selected := -1
	for index in main.current_options.size():
		var option: Dictionary = main.current_options[index]
		if option.action == verb and (offer.is_empty() or option.args.get("offer") == offer):
			selected = index
			break
	if not _check(selected >= 0, "Town menu offers " + verb + ":" + offer):
		return false
	await _tap(KEY_P)
	if not _check(main.context_ui.visible, "P opens town services"):
		return false
	await _click(main.context_ui.buttons[selected].get_global_rect().get_center())
	return not finished

func _menu_action(verb: String) -> bool:
	await _settle(0.16)
	var index := -1
	for at in main.current_options.size():
		if str(main.current_options[at].action) == verb:
			index = at
			break
	if not _check(index >= 0, "Nearby menu offers " + verb):
		return false
	await _tap(KEY_P)
	if not _check(main.context_ui.visible and main.context_ui.buttons.size() > index, "P opens action menu"):
		return false
	await _click(main.context_ui.buttons[index].get_global_rect().get_center())
	return not finished

func _gather_island(id: String) -> bool:
	var resource: Dictionary = IslandMap.node(id)
	var at := Vector2(float(resource.x), float(resource.y))
	var before := _count(str(resource.item))
	var approach := at
	if resource.kind in ["tree", "stone", "ore"]:
		var candidates: Array[Vector2] = [at+Vector2(0,30),at+Vector2(30,0),at-Vector2(30,0),at-Vector2(0,30)]
		var here:=Vector2(_player().x,_player().y)
		candidates.sort_custom(func(a:Vector2,b:Vector2):return here.distance_squared_to(a)<here.distance_squared_to(b))
		for candidate in candidates:
			if IslandMap.can_stand(candidate):
				approach=candidate
				break
	if not (await _walk(approach, "island resource " + id)):
		return false
	await _equip_tool(str(resource.tool))
	await _click_world(at)
	if not _check(_player().activity.get("kind") == "island_gather", "Click starts timed island gathering: " + id):
		return false
	return await _until(func() -> bool: return _player().activity.is_empty() and _count(str(resource.item)) == before + int(resource.amount), "Real tool work completes " + id, float(resource.duration) + 2)

func _saved_progress() -> Dictionary:
	var result: Dictionary = super._saved_progress()
	result.chart = _state().chart.duplicate(true)
	result.island = _state().island.duplicate(true)
	result.rooms = _state().rooms.duplicate(true)
	result.can_water = int(_player().can_water)
	return result

func _walk_segment(target: Vector2, label: String) -> bool:
	if _player().area == "room":
		var room: String = str(_player().room)
		if not _check(Rooms.can_stand(room, target), "Indoor walking target is actual floor: " + label):
			return false
		# Observe the same connected floor cells as residents, then issue normal WASD.
		# Each cell-center segment avoids walls; no room-arrival or position mutation.
		var route: PackedVector2Array = ResidentRoutes.path(room, Vector2(_player().x, _player().y), target)
		if not _check(not route.is_empty(), "A connected indoor path exists: " + label):
			return false
		for point in route:
			if not (await super._walk_segment(point, label)):
				return false
		return true
	if _player().area != "island":
		return await super._walk_segment(target, label)
	var start:=Vector2(_player().x,_player().y)
	var bounds:=Rect2(start,Vector2.ZERO).expand(target).grow(80)
	var solids:=IslandState.blockers(_state().island,int(_state().day),bounds.position,bounds.end)
	for i in solids.size(): solids[i]=solids[i].grow(5)
	if _island_keyboard_clear(start,target,solids):
		return await _walk_island_straight(target,label)
	# The driver observes obstacles and sends normal WASD around them. It never
	# removes resources, teleports, or changes collision rules to finish a journey.
	# https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html
	var grid:=AStarGrid2D.new()
	grid.offset=start
	grid.cell_size=Vector2(16,16)
	grid.region=Rect2i(Vector2i(((bounds.position-start)/16).floor()),Vector2i((bounds.size/16).ceil())+Vector2i.ONE)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for y in range(grid.region.position.y,grid.region.end.y):
		for x in range(grid.region.position.x,grid.region.end.x):
			var point:=start+Vector2(x,y)*16
			grid.set_point_solid(Vector2i(x,y),not _island_line_clear(point,point,solids))
	var goal:=Vector2i(((target-start)/16).round())
	var best_distance:=INF
	for y in range(goal.y-1,goal.y+2):
		for x in range(goal.x-1,goal.x+2):
			var cell:=Vector2i(x,y)
			var point:=start+Vector2(cell)*16
			var distance:=point.distance_squared_to(target)
			if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell) and distance<best_distance and _island_line_clear(point,target,solids):
				goal=cell
				best_distance=distance
	var route:=grid.get_point_path(Vector2i.ZERO,goal)
	if route.is_empty():
		_fail("No physical walking route to "+label)
		return false
	# Skip intermediate grid points only when the whole segment remains clear.
	var cursor:=0
	while cursor<route.size()-1:
		var next:=cursor+1
		while next+1<route.size() and _island_keyboard_clear(route[cursor],route[next+1],solids): next+=1
		if not (await _walk_island_straight(route[next],label)): return false
		cursor=next
	return await _walk_island_straight(target,label)

func _island_keyboard_clear(from:Vector2,to:Vector2,solids:Array[Rect2]) -> bool:
	# WASD travels at 45 degrees until one axis arrives, then on the other axis.
	# A geometric straight line is not the same route for unequal x/y distances.
	var delta:=to-from
	var elbow:=from+delta.sign()*minf(absf(delta.x),absf(delta.y))
	return _island_line_clear(from,elbow,solids) and _island_line_clear(elbow,to,solids)

func _island_line_clear(from:Vector2,to:Vector2,solids:Array[Rect2]) -> bool:
	var steps:=maxi(1,ceili(from.distance_to(to)/4.0))
	for i in steps+1:
		var point:=from.lerp(to,float(i)/steps)
		if not IslandMap.can_stand(point) or not IslandState.feet_clear(point,point,solids): return false
	return true

func _walk_island_straight(target:Vector2,label:String) -> bool:
	var deadline := Time.get_ticks_msec() + 12000
	while not finished:
		var offset := target - Vector2(float(_player().x), float(_player().y))
		if absf(offset.x) < 3.5 and absf(offset.y) < 3.5:
			_release_keys()
			await _settle(0.12)
			return true
		if Time.get_ticks_msec() > deadline:
			_fail("Island walking stalled: " + label)
			return false
		for key in MOVE_KEYS:
			var down: bool = (key == KEY_D and offset.x >= 3.5) or (key == KEY_A and offset.x <= -3.5) or (key == KEY_S and offset.y >= 3.5) or (key == KEY_W and offset.y <= -3.5)
			if bool(held.get(key, false)) != down or Input.is_physical_key_pressed(key) != down:
				_send_key(key, down)
				held[key] = down
		await get_tree().physics_frame
	return false

func _hold_item(item: String) -> void:
	await _settle(0.16)
	for index in _bag().size():
		if _bag()[index].get("item", "") == item:
			var before: Array = _bag().duplicate(true)
			await _click(main.hud.slots[index].button.get_global_rect().get_center())
			_check(Farming.held_item(main.active_tool, main.active_seed) == item and _bag() == before, "Actual bag toolbar equips " + item + " without consuming it")
			return
	_fail("No carried item to equip: " + item)

func _click_world(point: Vector2) -> void:
	if _player().area == "room":
		var rendered: Vector2 = main.view.world_to_screen(point, "room")
		await _click(main.view.position + rendered * main.view.scale)
	else:
		await super._click_world(point)


func _homestead_journey() -> bool:
	await _tap(KEY_H)
	for target in [Vector2(840, 352), Vector2(1344, 352), Vector2(1344, 784), Vector2(1792, 784), IslandMap.LANDMARKS.townhall.door + Vector2(0, 40)]:
		if not (await _walk(target, "walk east street to mayor")):
			return false
	if not (await _enter_town_room("townhall")) or not (await _approach_resident("xu_an")):
		return false
	await _click_world(IslandTown.position("xu_an", _state().minute))
	if not _check(main.dialogue_ui.visible and main.dialogue_ui.choice_button.visible, "Mayor offers rental in conversation without starting a quest"):
		return false
	await _click(main.dialogue_ui.choice_button.get_global_rect().get_center())
	if not _check(_state().island.homestead.rented, "Accepting the dialogue choice rents the shared yard without clearing requirements"):
		return false
	await _click(main.dialogue_ui.choice_button.get_global_rect().get_center())
	if not _check(_state().island.homestead.claimed.host, "Mayor gives seasonal seeds and tools through the normal inventory"):
		return false
	await _capture("12-mayor-gift.png")
	await _tap(KEY_ESCAPE)
	if not (await _leave_town_room("townhall")):
		return false
	for target in [Vector2(1792, 784), Vector2(1792, 1152), Vector2(1792, 1536), Vector2(1792, 1792), IslandMap.YARD_GATE + Vector2(80, 0)]:
		if not (await _walk(target, "walk south lane into abandoned yard")):
			return false
	await _tap(KEY_M)
	await _capture("13-yard-map.png")
	await _tap(KEY_ESCAPE)
	var grass: Dictionary = {}
	for node: Dictionary in IslandMap.nodes_near(IslandMap.YARD_GATE).values():
		if node.kind == "fiber" and IslandState.active(_state().island,str(node.id),int(_state().day)) and node.x > 1980 and node.x < 2336 and node.y > 1680 and node.y < 1930:
			grass = node
			break
	if not _check(not grass.is_empty(), "Yard has naturally untended grass beside its entrance"):
		return false
	var at := Vector2(grass.x, grass.y)
	if not (await _walk(at, "choose a small patch of yard freely")) or not (await _gather_island(str(grass.id))):
		return false
	for item in ["hoe", "seed", "watering_can"]:
		await _hold_item(item)
		await _click_world(at)
	if not _check(_state().island.plots.has(Farming.plot_key(at)) and _state().island.plots[Farming.plot_key(at)].watered, "Cleared yard cell supports actual held tools and planting"):
		return false
	await _capture("14-yard-farming.png")
	await _tap(KEY_H)
	for target in [IslandMap.YARD_GATE + Vector2(80, 0), Vector2(1792, 1792), Vector2(1792, 1152), Vector2(1792, 784), Vector2(1344, 784), Vector2(1344, 280), Vector2(840, 280), Vector2(520, 365)]:
		if not (await _walk(target, "return along town roads to preserved coastal farm")):
			return false
	_record("Walked to mayor, rented a shared 48x36 yard, received personal supplies once, walked in and farmed a self-cleared cell; no beginner task or clearing quota")
	return true

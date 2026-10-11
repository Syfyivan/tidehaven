extends SceneTree
## Explicit map positions, inventory and crop-state fixtures; no normal-play claim.
## Farm actions and day transitions use the same helper called by the host.

const Farming = preload("res://scripts/farming.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Recipes = preload("res://scripts/recipes.gd")
const IslandMap = preload("res://scripts/island_map.gd")
var checks := 0
var failures := 0
var spots: Array[Vector2] = []


func _initialize() -> void:
	spots = _clear_spots()
	if not _check(spots.size() == 4, "the real map exposes four clear tillable fixture cells"):
		quit(1)
		return
	_test_calendar_and_items()
	_test_tilling_and_authority()
	_test_daily_growth()
	_test_water_and_refill()
	_test_seasons_and_shelter()
	_test_capacity_and_races()
	_test_plot_restore()
	print("FARMING CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
	return condition


func _clear_spots() -> Array[Vector2]:
	var found: Array[Vector2] = []
	for ty in range(4, 15):
		for tx in range(8, 24):
			var point := Vector2(tx * 32 + 16, ty * 32 + 16)
			if not IslandMap.tillable(point):
				continue
			var occupied := false
			for node: Dictionary in IslandMap.nodes_near(point).values():
				occupied = occupied or Farming.plot_key(Vector2(float(node.x), float(node.y))) == Farming.plot_key(point)
			if not occupied:
				found.append(point)
				if found.size() == 4:
					return found
	return found


func _data(day := 1) -> Dictionary:
	return {"day": day, "island": {"depleted": {}, "plots": {}}}


func _player(point: Vector2, items: Dictionary = {}) -> Dictionary:
	var player := {"area": "island", "x": point.x, "y": point.y, "bag": Inventory.empty_slots(Inventory.BAG_SIZE), "can_water": 0}
	for item in items:
		Inventory.add(player.bag, item, int(items[item]))
	return player


func _at(player: Dictionary, point: Vector2) -> void:
	player.x = point.x
	player.y = point.y


func _act(data: Dictionary, player: Dictionary, verb: String, point: Vector2, seed := "") -> String:
	var args := {"x": point.x, "y": point.y}
	if not seed.is_empty():
		args.seed = seed
	return Farming.action(data, player, verb, args)


func _plot(data: Dictionary, point: Vector2, crop := "", growth := 0, watered := false, covered := false, dead := false) -> Dictionary:
	var value := {"crop": crop, "growth": growth, "watered": watered, "covered": covered, "dead": dead}
	data.island.plots[Farming.plot_key(point)] = value
	return value


func _snapshot(data: Dictionary, players: Array) -> Dictionary:
	return {"data": data.duplicate(true), "players": players.duplicate(true)}


func _day(data: Dictionary) -> void:
	Farming.advance_day(data.island, int(data.day), int(data.day) + 1)
	data.day += 1


func _test_calendar_and_items() -> void:
	for row in [[1, 0], [28, 0], [29, 1], [56, 1], [57, 2], [84, 2], [85, 3], [112, 3], [113, 0], [141, 1]]:
		_check(Farming.season(row[0]) == row[1], "season changes only after each full 28-day month: " + str(row[0]))
	_check(Farming.date_label(1) == "第1年 · 春 第1天" and Farming.date_label(112) == "第1年 · 冬 第28天" and Farming.date_label(113) == "第2年 · 春 第1天", "calendar labels preserve the year, season and date")
	var definitions := [["seed", "春萝卜", 4, [0]], ["summer_seed", "玉米", 7, [1, 2]], ["autumn_seed", "南瓜", 10, [2]], ["winter_seed", "雪根", 6, [3]]]
	for index in definitions.size():
		var row: Array = definitions[index]
		var crop: Dictionary = Farming.CROPS[row[0]]
		_check(crop.name == row[1] and crop.days == row[2] and crop.seasons == row[3] and crop["yield"] == 2 and Farming.crop_for_season(index * 28 + 1) == row[0], "four named plants retain their own duration, suitable seasons and seasonal seed")
	var items := ["fiber", "hoe", "scythe", "watering_can", "canopy", "summer_seed", "autumn_seed", "winter_seed"]
	var bag := Inventory.empty_slots(Inventory.BAG_SIZE)
	for item in items:
		_check(Inventory.add(bag, item, 1) == 0 and Inventory.ITEM_NAMES.has(item), "new farming item has a real finite inventory slot and label: " + item)
	Inventory.sort_slots(bag)
	_check(Inventory.validate_slots(JSON.parse_string(JSON.stringify(bag)), Inventory.BAG_SIZE) and Inventory.total_count(bag) == 8 and Inventory.ITEM_NAMES.seed == "春萝卜种子", "sorting and JSON preserve all new tools and seasonal seeds")
	var costs := {"hoe": {"wood": 3, "stone": 2, "rope": 1}, "scythe": {"wood": 2, "scrap": 2, "rope": 1}, "watering_can": {"plastic": 4, "scrap": 2}, "canopy": {"wood": 6, "fiber": 4, "plastic": 4}, "fiber_rope": {"fiber": 2}}
	for recipe_id in costs:
		var recipe: Dictionary = Recipes.ALL[recipe_id]
		_check(recipe.costs == costs[recipe_id] and recipe.result == ("rope" if recipe_id == "fiber_rope" else recipe_id) and recipe.amount == 1 and recipe.structure.is_empty(), "handcrafted farm recipe retains its exact non-free material cost: " + recipe_id)
	_check(not Recipes.ALL.has("summer_seed") and not Recipes.ALL.has("autumn_seed") and not Recipes.ALL.has("winter_seed") and Recipes.ALL.rope.costs == {"leaf": 2}, "season seeds have no free crafting shortcut and original palm-leaf rope remains available")


func _test_tilling_and_authority() -> void:
	var data := _data()
	var player := _player(spots[0])
	data.chest = {"slots": _player(spots[0], {"hoe": 1}).bag}
	var before := _snapshot(data, [player])
	_act(data, player, "till", spots[0])
	_check(_snapshot(data, [player]) == before, "a hoe in another container cannot be used to till")
	Inventory.add(player.bag, "hoe", 1)
	_act(data, player, "till", spots[0])
	var key := Farming.plot_key(spots[0])
	_check(data.island.plots.size() == 1 and data.island.plots[key] == Farming.new_plot() and Inventory.count(player.bag, "hoe") == 1, "one hoe action opens exactly one empty persistent cell without consuming its tool")
	before = _snapshot(data, [player])
	_act(data, player, "till", spots[0] + Vector2(10, -10))
	_check(_snapshot(data, [player]) == before, "clicks within the same cell cannot create duplicate plots")
	player.area = "deck"
	before = _snapshot(data, [player])
	for verb in ["till", "plant", "water", "harvest", "cover", "clear_crop", "refill_can"]:
		_act(data, player, verb, spots[1])
	_check(_snapshot(data, [player]) == before, "all farm operations reject a player outside the island")
	player.area = "island"
	_at(player, spots[1] + Vector2(64.01, 0))
	before = _snapshot(data, [player])
	_act(data, player, "till", spots[1])
	_check(_snapshot(data, [player]) == before, "a player beyond 64 pixels cannot till even a valid clear cell")
	_at(player, spots[1] + Vector2(64, 0))
	_act(data, player, "till", spots[1])
	_check(data.island.plots.has(Farming.plot_key(spots[1])), "exact 64-pixel boundary remains reachable")
	_at(player, spots[0])
	before = _snapshot(data, [player])
	for args in [{}, {"x": spots[0].x}, {"x": "240", "y": 160}, {"x": true, "y": 160}, {"x": INF, "y": 160}, {"x": 240, "y": NAN}, {"x": -1, "y": 160}, {"x": IslandMap.SIZE.x, "y": 160}, {"x": 240, "y": IslandMap.SIZE.y}, {"x": spots[0].x, "y": spots[0].y, "reward": 100}]:
		Farming.action(data, player, "till", args)
	_check(_snapshot(data, [player]) == before, "missing, forged, non-finite and outside-map arguments cannot mutate farming state")
	_at(player, Vector2(448, 288))
	before = _snapshot(data, [player])
	_act(data, player, "till", Vector2(448, 288))
	var path_center := Farming.plot_center(Farming.plot_key(Vector2(448, 288)))
	_check(_snapshot(data, [player]) == before and not IslandMap.tillable(path_center), "a real map path is not arable soil")
	var found_blocker := false
	for id in IslandMap.nodes_near(spots[0]):
		var node: Dictionary = IslandMap.node(id)
		var point := Farming.plot_center(Farming.plot_key(Vector2(float(node.x), float(node.y))))
		if not IslandMap.tillable(point):
			continue
		found_blocker = true
		data = _data()
		_at(player, point)
		before = _snapshot(data, [player])
		_act(data, player, "till", point)
		_check(_snapshot(data, [player]) == before, "an active node must be cleared before its cell can be tilled")
		data.island.depleted[id] = 2
		_act(data, player, "till", point)
		_check(data.island.plots.has(Farming.plot_key(point)), "cleared resource ground becomes arable while its depletion lasts")
		data.island.plots.clear()
		data.day = 2
		before = _snapshot(data, [player])
		_act(data, player, "till", point)
		_check(_snapshot(data, [player]) == before, "resource is active on its exact regrowth day when there is no existing plot")
		break
	_check(found_blocker, "node occupancy checks use an actual tillable resource cell from the map")


func _test_daily_growth() -> void:
	for seed in Farming.CROPS:
		var definition: Dictionary = Farming.CROPS[seed]
		var data := _data(int(definition.seasons[0]) * 28 + 1)
		var player := _player(spots[0], {"hoe": 1, "watering_can": 1, seed: 2})
		player.can_water = 20
		_act(data, player, "till", spots[0])
		_act(data, player, "plant", spots[0], seed)
		var plot: Dictionary = data.island.plots[Farming.plot_key(spots[0])]
		_check(plot.crop == seed and plot.growth == 0 and Inventory.count(player.bag, seed) == 1, "planting consumes one selected seasonal seed and starts at zero growth")
		var before := _snapshot(data, [player])
		_act(data, player, "plant", spots[0], seed)
		_act(data, player, "harvest", spots[0])
		_check(_snapshot(data, [player]) == before, "occupied or immature crop cannot consume another seed or be harvested")
		_day(data)
		_check(plot.growth == 0 and not plot.watered, "an unwatered night makes no crop progress")
		for index in int(definition.days):
			_act(data, player, "water", spots[0])
			_check(plot.growth == index and plot.watered and not Farming.mature(plot), "watering never advances growth immediately")
			_day(data)
			_check(plot.growth == index + 1 and not plot.watered and Farming.mature(plot) == (index + 1 == int(definition.days)), "one watered night gives one day of growth and maturity appears at the exact duration")
		before = _snapshot(data, [player])
		_act(data, player, "plant", spots[0], seed)
		_check(_snapshot(data, [player]) == before, "a mature standing crop cannot be overwritten by new seed")
		_act(data, player, "harvest", spots[0])
		_check(plot.crop.is_empty() and plot.growth == 0 and Inventory.count(player.bag, "veg") == 2 and Inventory.count(player.bag, seed) == 2, "each named crop yields exactly two vegetables and its own replacement seed")
	var data := _data()
	var player := _player(spots[0], {"seed": 1, "watering_can": 1})
	player.can_water = 3
	var plot := _plot(data, spots[0])
	_act(data, player, "water", spots[0])
	_act(data, player, "plant", spots[0])
	_day(data)
	_check(plot.crop == "seed" and plot.growth == 1 and player.can_water == 2, "prewatering prepared soil works with default spring seed planting")
	plot.watered = true
	var before: Dictionary = plot.duplicate(true)
	Farming.advance_day(data.island, 2, 2)
	Farming.advance_day(data.island, 2, 1)
	_check(plot == before, "same-day and backward-date calls do not consume water or duplicate growth")
	Farming.advance_day(data.island, 2, 9)
	_check(plot.growth == 2 and not plot.watered, "skipping several dates cannot multiply one watering into several growth days")


func _test_water_and_refill() -> void:
	var data := _data()
	var player := _player(spots[0], {"watering_can": 2})
	var plot := _plot(data, spots[0], "seed")
	var before := _snapshot(data, [player])
	_act(data, player, "water", spots[0])
	_check(_snapshot(data, [player]) == before, "an empty held can does not water a plot")
	var bank := Vector2(640, 430)
	_check(IslandMap.water_near(bank), "the first real freshwater bank is reachable by the refill fixture")
	_at(player, bank)
	_act(data, player, "refill_can", bank)
	_check(player.can_water == 20 and Inventory.count(player.bag, "watering_can") == 2, "freshwater fills only the player's 20-use capacity even with two cans")
	before = _snapshot(data, [player])
	_act(data, player, "refill_can", bank)
	_check(_snapshot(data, [player]) == before, "refilling an already-full can neither duplicates water nor changes items")
	_at(player, spots[0])
	_act(data, player, "water", spots[0])
	_check(plot.watered and player.can_water == 19, "watering one tile uses exactly one unit")
	before = _snapshot(data, [player])
	_act(data, player, "water", spots[0])
	_check(_snapshot(data, [player]) == before, "repeated watering on the same day never wastes another unit")
	plot.watered = false
	Inventory.remove(player.bag, "watering_can", 2)
	before = _snapshot(data, [player])
	_act(data, player, "water", spots[0])
	_check(_snapshot(data, [player]) == before, "stored or discarded cans cannot use the player's retained water balance")
	Inventory.add(player.bag, "watering_can", 1)
	_at(player, Vector2(40, 430))
	before = _snapshot(data, [player])
	_act(data, player, "refill_can", Vector2(40, 430))
	_check(_snapshot(data, [player]) == before, "sea water cannot refill the farm watering can")
	_at(player, Vector2(576, 430))
	before = _snapshot(data, [player])
	_act(data, player, "refill_can", bank)
	_check(_snapshot(data, [player]) == before, "clicking an in-range shore point cannot refill while the player is too far from freshwater")
	for invalid in [-1, 21, 0.5, INF, true, "20"]:
		player.can_water = invalid
		_at(player, bank)
		before = _snapshot(data, [player])
		_act(data, player, "refill_can", bank)
		_check(_snapshot(data, [player]) == before, "invalid water counters never become valid through refill")
		_at(player, spots[0])
		before = _snapshot(data, [player])
		_act(data, player, "water", spots[0])
		_check(_snapshot(data, [player]) == before, "invalid water counters cannot water a plot")


func _test_seasons_and_shelter() -> void:
	var data := _data(28)
	var spring := _plot(data, spots[0], "seed", 3, true)
	var ready := _plot(data, spots[1], "seed", 4)
	var protected := _plot(data, spots[2], "seed", 1, true, true)
	_day(data)
	_check(spring.dead and ready.dead and not Farming.mature(spring) and not Farming.mature(ready), "spring crops wither on summer arrival even if just matured or already ripe")
	_check(not protected.dead and protected.growth == 2 and not protected.watered, "one covered crop survives the same season change and gains only its watered night")
	var player := _player(spots[0], {"canopy": 2, "summer_seed": 2, "watering_can": 1})
	player.can_water = 20
	var before := _snapshot(data, [player])
	for verb in ["harvest", "water", "cover", "clear_crop"]:
		_act(data, player, verb, spots[0])
	_check(_snapshot(data, [player]) == before, "dead crop cannot be harvested, watered, revived by cover or cleared without a scythe")
	Inventory.add(player.bag, "scythe", 1)
	_act(data, player, "clear_crop", spots[0])
	_check(spring == Farming.new_plot() and Inventory.count(player.bag, "scythe") == 1, "scythe clears only the dead crop while preserving the prepared cell and reusable tool")
	_act(data, player, "plant", spots[0], "summer_seed")
	_check(spring.crop == "summer_seed" and Inventory.count(player.bag, "summer_seed") == 1, "cleared summer ground accepts a suitable replacement crop")
	var corn := _plot(data, spots[3], "summer_seed", 6, true)
	Farming.advance_day(data.island, 56, 57)
	_check(not corn.dead and corn.growth == 7 and Farming.mature(corn), "summer-autumn corn survives that season boundary and can mature there")
	Farming.advance_day(data.island, 84, 85)
	_check(corn.dead and not Farming.mature(corn), "the same corn withers when winter begins")
	data = _data(85)
	var empty := _plot(data, spots[0])
	player = _player(spots[0], {"seed": 2, "canopy": 1, "watering_can": 1})
	player.can_water = 20
	before = _snapshot(data, [player])
	_act(data, player, "plant", spots[0], "seed")
	_check(_snapshot(data, [player]) == before, "winter rejects exposed spring seed without consuming it")
	_act(data, player, "cover", spots[0])
	_check(empty.covered and Inventory.count(player.bag, "canopy") == 0, "one canopy kit covers exactly one prepared soil cell")
	before = _snapshot(data, [player])
	_act(data, player, "cover", spots[0])
	_check(_snapshot(data, [player]) == before, "a second cover request is free of duplicate effects")
	_act(data, player, "plant", spots[0], "seed")
	_check(empty.crop == "seed" and empty.covered, "a covered cell permits out-of-season planting")
	_day(data)
	_check(empty.growth == 0 and not empty.dead, "warm shelter never replaces watering")
	for index in 4:
		_act(data, player, "water", spots[0])
		_day(data)
	_act(data, player, "harvest", spots[0])
	_check(empty.crop.is_empty() and empty.covered and not empty.watered, "harvesting leaves the warm shelter and soil in place")
	_plot(data, spots[1], "seed", 1, true)
	Farming.advance_day(data.island, 1, 113)
	_check(data.island.plots[Farming.plot_key(spots[1])].dead, "skipping a full year cannot hide an intervening unsuitable season")


func _test_capacity_and_races() -> void:
	var data := _data()
	var first := _player(spots[0], {"hoe": 1, "seed": 2, "watering_can": 1})
	var second := _player(spots[0], {"hoe": 1, "seed": 2, "watering_can": 1})
	first.can_water = 2
	second.can_water = 2
	_act(data, first, "till", spots[0])
	_act(data, second, "till", spots[0])
	_act(data, first, "plant", spots[0])
	_act(data, second, "plant", spots[0])
	_act(data, first, "water", spots[0])
	_act(data, second, "water", spots[0])
	var plot: Dictionary = data.island.plots[Farming.plot_key(spots[0])]
	_check(data.island.plots.size() == 1 and Inventory.count(first.bag, "seed") == 1 and Inventory.count(second.bag, "seed") == 2 and first.can_water == 1 and second.can_water == 2, "racing shared-cell actions consume only the successful player's seed and water")
	plot.growth = 4
	_act(data, first, "harvest", spots[0])
	_act(data, second, "harvest", spots[0])
	_check(Inventory.count(first.bag, "veg") == 2 and Inventory.count(second.bag, "veg") == 0 and Inventory.count(first.bag, "seed") == 2 and plot.crop.is_empty(), "two harvest requests cannot duplicate one crop or its replacement seed")
	plot = _plot(data, spots[0], "seed", 4, false, true)
	first.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Inventory.add(first.bag, "wood", 240)
	first.bag[0] = {"item": "veg", "count": 19}
	first.bag[1] = {"item": "seed", "count": 20}
	var before := _snapshot(data, [first, second])
	_act(data, first, "harvest", spots[0])
	_check(_snapshot(data, [first, second]) == before, "a two-vegetable reward never partially fills the final available stack")
	first.bag[0].count = 18
	before = _snapshot(data, [first, second])
	_act(data, first, "harvest", spots[0])
	_check(_snapshot(data, [first, second]) == before, "vegetables that fit do not commit if the matching replacement seed cannot fit")
	first.bag[1].count = 19
	_act(data, first, "harvest", spots[0])
	_check(Inventory.count(first.bag, "veg") == 20 and Inventory.count(first.bag, "seed") == 20 and plot.crop.is_empty() and plot.covered, "full bag can harvest when both matching stacks have exactly enough room")
	first = _player(spots[0], {"watering_can": 1})
	second = _player(spots[1], {"watering_can": 1})
	first.can_water = 2
	second.can_water = 3
	var left := _plot(data, spots[0], "seed")
	var right := _plot(data, spots[1], "seed")
	_act(data, first, "water", spots[0])
	_day(data)
	_check(left.growth == 1 and right.growth == 0 and first.can_water == 1 and second.can_water == 3, "neighboring plots grow independently and never share another player's water")
	var before_independent := _snapshot(data, [first, second])
	_act(data, first, "plant", spots[2], "seed")
	_act(data, first, "water", spots[2])
	_act(data, first, "cover", spots[2])
	_check(_snapshot(data, [first, second]) == before_independent, "planting, watering and cover all require an existing tilled cell")


func _test_plot_restore() -> void:
	var data := _data()
	_plot(data, spots[0], "seed", 2)
	_plot(data, spots[1], "summer_seed", 7, true)
	_plot(data, spots[2], "", 0, true, true)
	_plot(data, spots[3], "winter_seed", 3, false, false, true)
	var decoded: Variant = JSON.parse_string(JSON.stringify(data.island.plots))
	var restored: Variant = Farming.restore_plots(decoded)
	_check(restored is Dictionary and restored == data.island.plots and typeof(restored[Farming.plot_key(spots[0])].growth) == TYPE_INT, "JSON sparse fields restore growth as integers with every watered, covered, ripe and dead state intact")
	decoded[Farming.plot_key(spots[0])].growth = 0
	_check(restored[Farming.plot_key(spots[0])].growth == 2, "restored plot state does not alias caller-owned dictionaries")
	_check(Farming.restore_plots({}) == {} and Farming.restore_plots(null) == null and Farming.restore_plots([]) == null, "valid empty plot dictionary is distinct from failed restoration")
	var cases: Array = [true, "plots"]
	for key in ["-1,4", "01,4", "+1,4", "1.5,4", "4", "1,2,3", "999999,4", "0,0", "4294967296,4", 4]:
		cases.append({key: Farming.new_plot()})
	var baseline: Dictionary = data.island.plots.duplicate(true)
	var key := Farming.plot_key(spots[0])
	for field in ["crop", "growth", "watered", "covered", "dead"]:
		var bad: Dictionary = baseline.duplicate(true)
		bad[key].erase(field)
		cases.append(bad)
	for change in [{"growth": -1}, {"growth": 5}, {"growth": 0.5}, {"growth": INF}, {"growth": "2"}, {"growth": true}, {"crop": "unknown"}, {"crop": 1}, {"crop": "", "growth": 1}, {"crop": "", "growth": 0, "dead": true}, {"watered": 1}, {"covered": 1}, {"dead": 1}, {"dead": true, "covered": true}, {"dead": true, "watered": true}, {"extra": 1}]:
		var bad: Dictionary = baseline.duplicate(true)
		for field in change:
			bad[key][field] = change[field]
		cases.append(bad)
	for malformed in cases:
		var before: Variant = malformed.duplicate(true) if malformed is Dictionary else malformed
		_check(Farming.restore_plots(malformed) == null and malformed == before and data.island.plots == baseline, "malformed keys or crop fields reject without mutating the input or live state")

extends SceneTree
## Explicit resident, inventory and time fixtures. Tests the host service helper,
## not ENet, normal-entry progression, interiors or a full villager life schedule.
const Town = preload("res://scripts/island_town.gd")
const Map = preload("res://scripts/island_map.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Farming = preload("res://scripts/farming.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_residents_and_hours()
	_test_options_and_distance()
	_test_seed_and_sales()
	_test_tools_and_capacity()
	_test_treatment()
	_test_bath()
	_test_bath_cancellation_and_validation()
	_test_shared_money_races()
	print("ISLAND TOWN CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)


func _data(minute := 720.0, money := 100, day := 1) -> Dictionary:
	return {"minute": minute, "money": money, "day": day, "chests": {"ignored": {"slots": [{"item": "fish", "count": 20}]}}}


func _player(npc_id := "lin_sui", minute := 720.0, items: Dictionary = {}) -> Dictionary:
	var at: Vector2 = Town.position(npc_id, minute)
	var player := {"online": true, "area": "island", "x": at.x, "y": at.y, "bag": Inventory.empty_slots(Inventory.BAG_SIZE), "stamina": 40.0, "hunger": 60.0, "thirst": 65.0, "resting": false, "sleep_ready": false, "activity": {}, "hook": {}, "fishing": {}}
	for item: String in items:
		Inventory.add(player.bag, item, int(items[item]))
	return player


func _snapshot(data: Dictionary, player: Dictionary) -> Dictionary:
	return {"data": data.duplicate(true), "player": player.duplicate(true)}


func _trade(data: Dictionary, player: Dictionary, npc_id: String, offer: String) -> String:
	return Town.action(data, player, "town_trade", {"id": npc_id, "offer": offer})


func _test_residents_and_hours() -> void:
	var data := _data()
	var original := data.duplicate(true)
	var rows: Dictionary = Town.residents(data)
	_check(rows.size() == 8, "eight independent residents are available")
	var names: Dictionary = {}
	var roles: Dictionary = {}
	var variants: Dictionary = {}
	var off_duty_positions: Dictionary = {}
	for npc_id: String in rows:
		var row: Dictionary = rows[npc_id]
		var meta: Dictionary = Town.NPCS[npc_id]
		names[row.name] = true
		roles[row.role] = true
		variants[row.variant] = true
		_check(Map.LANDMARKS.has(row.landmark) and row.id == npc_id and row.talk.length() > 20 and row.hours.length() > 8, "resident has a real landmark, name, practical dialogue and hours: " + npc_id)
		_check(row.sprite_slot in ["host", "guest"] and row.variant >= 0 and row.variant < 8 and row.color is Color, "resident appearance only selects existing authorized character variants: " + npc_id)
		_check(Town.open_at(npc_id, float(meta.start)) and not Town.open_at(npc_id, float(meta.start) - 0.01) and not Town.open_at(npc_id, float(meta.end)), "opening is inclusive and closing exclusive: " + npc_id)
		var at_work: Vector2 = Town.position(npc_id, float(meta.start))
		var after_work: Vector2 = Town.position(npc_id, float(meta.end))
		_check(at_work == Map.LANDMARKS[row.landmark].door and Map.walkable(at_work), "working resident stands at its actual accessible doorway: " + npc_id)
		_check(after_work == Map.LANDMARKS.plaza.door + Town.PLAZA_OFFSETS[int(row.variant)] and Map.walkable(after_work), "off-duty resident uses an accessible distinct plaza point: " + npc_id)
		off_duty_positions[after_work] = true
	_check(names.size() == 8 and roles.size() == 8 and variants.size() == 8 and off_duty_positions.size() == 8, "names, professions, appearance indexes and plaza positions are distinct")
	_check(data == original and rows == Town.residents(data), "resident positions are deterministic without adding save data")
	rows.lin_sui.name = "fixture edit"
	_check(Town.residents(data).lin_sui.name == "林穗", "returned resident dictionaries cannot mutate definitions")
	_check(not Town.open_at("missing", 720) and not Town.open_at("lin_sui", NAN) and Town.position("missing", 720).x < 0, "unknown residents and nonfinite schedules do not select a real doorway")


func _test_options_and_distance() -> void:
	var data := _data()
	var player := _player()
	var available: Array = Town.options(data, player)
	_check(available.size() == 3 and available[0].action == "town_talk", "market presents talk first and two explicit paid/trade choices")
	for entry: Dictionary in available:
		_check(entry.has_all(["action", "label", "args"]) and entry.args.id == "lin_sui", "nearby service targets a real resident without ambiguous nearest selection")
	var before := _snapshot(data, player)
	var line: String = Town.action(data, player, "town_talk", {"id": "lin_sui"})
	_check(line.contains("林穗") and line.contains("种子") and _snapshot(data, player) == before, "talk supplies personal guidance without changing any state")
	player.x += Town.REACH
	_check(Town.options(data, player).size() == 3, "service reach includes exactly 64 pixels")
	player.x += 0.01
	before = _snapshot(data, player)
	_trade(data, player, "lin_sui", "buy_seed")
	_check(Town.options(data, player).is_empty() and _snapshot(data, player) == before, "remote requests cannot buy from a resident just outside reach")
	for field in ["area", "online", "x", "y"]:
		var invalid := _player()
		match field:
			"area": invalid.area = "deck"
			"online": invalid.online = false
			"x": invalid.x = INF
			"y": invalid.y = INF
		var old_money: int = data.money
		_trade(data, invalid, "lin_sui", "buy_seed")
		_check(Town.options(data, invalid).is_empty() and data.money == old_money and Inventory.total_count(invalid.bag) == 0, "island, online and finite actor checks: " + field)
	data.minute = 1200.0
	player = _player("lin_sui", 1200)
	available = Town.options(data, player)
	_check(not available.is_empty(), "off-duty residents remain available to talk in the plaza")
	var market_actions: Array = []
	for entry: Dictionary in available:
		if entry.args.id == "lin_sui":
			market_actions.append(entry.action)
	before = _snapshot(data, player)
	_trade(data, player, "lin_sui", "buy_seed")
	_check(market_actions == ["town_talk"] and _snapshot(data, player) == before, "off-duty market resident cannot sell from the plaza")
	player.x = Map.LANDMARKS.market.door.x
	player.y = Map.LANDMARKS.market.door.y
	before = _snapshot(data, player)
	Town.action(data, player, "town_talk", {"id": "lin_sui"})
	_check(_snapshot(data, player) == before and not Town.action(data, player, "town_talk", {"id": "lin_sui"}).begins_with("林穗："), "old shop position does not impersonate the resident after closing")


func _test_seed_and_sales() -> void:
	for day in [1, 28, 29, 56, 57, 84, 85, 112, 113]:
		var data := _data(720, 3, day)
		var player := _player()
		_trade(data, player, "lin_sui", "buy_seed")
		_check(data.money == 0 and Inventory.count(player.bag, Farming.crop_for_season(day)) == 1 and Inventory.total_count(player.bag) == 1, "seed sale uses the current authoritative season at day " + str(day))
		var before := _snapshot(data, player)
		_trade(data, player, "lin_sui", "buy_seed")
		_check(_snapshot(data, player) == before, "repeating a purchase without funds adds nothing")
	for offer in ["sell_fish", "sell_veg"]:
		var npc_id := "zhou_chao" if offer == "sell_fish" else "lin_sui"
		var item := "fish" if offer == "sell_fish" else "veg"
		var data := _data(720, 0)
		var player := _player(npc_id, 720, {item: 1})
		_trade(data, player, npc_id, offer)
		_check(data.money == 4 and Inventory.count(player.bag, item) == 0, "selling consumes exactly one personal item before granting coins: " + offer)
		var before := _snapshot(data, player)
		_trade(data, player, npc_id, offer)
		_check(_snapshot(data, player) == before, "empty personal bag cannot mint coins, even if a shared chest has fish: " + offer)
	var data := _data(720, Town.MONEY_LIMIT)
	var player := _player("zhou_chao", 720, {"fish": 1})
	var before := _snapshot(data, player)
	_trade(data, player, "zhou_chao", "sell_fish")
	_check(_snapshot(data, player) == before, "currency overflow leaves the sold item in its original slot")


func _test_tools_and_capacity() -> void:
	for row in [["he_mu", "buy_rope", "rope", 3], ["yan_zhen", "buy_axe", "axe", 12], ["yan_zhen", "buy_pickaxe", "pickaxe", 14], ["tian_qing", "buy_can", "watering_can", 10]]:
		var data := _data(720, int(row[3]))
		var player := _player(str(row[0]))
		player.resting = true
		player.sleep_ready = true
		_trade(data, player, str(row[0]), str(row[1]))
		_check(data.money == 0 and Inventory.count(player.bag, str(row[2])) == 1 and not player.resting and not player.sleep_ready, "tool purchase is personal, costs its fixed price and cancels sleep readiness: " + str(row[1]))
	var data := _data()
	var player := _player("yan_zhen")
	for index in Inventory.BAG_SIZE:
		player.bag[index] = {"item": "stone", "count": Inventory.STACK_LIMIT}
	var before := _snapshot(data, player)
	_trade(data, player, "yan_zhen", "buy_axe")
	_check(_snapshot(data, player) == before, "full backpack does not spend shared money for a tool that cannot fit")
	player = _player("he_mu")
	for index in Inventory.BAG_SIZE:
		player.bag[index] = {"item": "stone", "count": Inventory.STACK_LIMIT}
	player.bag[0] = {"item": "wood", "count": 3}
	before = _snapshot(data, player)
	_trade(data, player, "he_mu", "swap_fiber")
	_check(_snapshot(data, player) == before, "material exchange rolls back taken wood when resulting fiber cannot fit")
	player.bag[0].count = 2
	_trade(data, player, "he_mu", "swap_fiber")
	_check(Inventory.count(player.bag, "wood") == 0 and Inventory.count(player.bag, "fiber") == 3 and data.money == 100, "exchange may reuse the exact slot emptied by its cost")
	var invalid_args := [{"id": "he_mu", "offer": "buy_axe"}, {"id": "he_mu", "offer": "unknown"}, {"id": "he_mu", "offer": "buy_rope", "price": -99}, {"id": "he_mu", "offer": "buy_rope", "amount": 100}, {"id": "he_mu", "offer": 2}, {"id": "missing", "offer": "buy_seed"}, {"id": 9, "offer": "buy_seed"}, {}]
	for args: Dictionary in invalid_args:
		before = _snapshot(data, player)
		Town.action(data, player, "town_trade", args)
		_check(_snapshot(data, player) == before, "client cannot choose prices, quantities, another merchant's offer or malformed IDs: " + str(args))
	for busy_key in ["activity", "hook", "fishing"]:
		player = _player("he_mu", 720, {"wood": 2})
		player[busy_key] = {"kind": "fixture"}
		before = _snapshot(data, player)
		_trade(data, player, "he_mu", "swap_fiber")
		_check(_snapshot(data, player) == before, "paid services cannot overlap active work: " + busy_key)
		Town.action(data, player, "town_talk", {"id": "he_mu"})
		_check(_snapshot(data, player) == before, "talk preserves current activity: " + busy_key)


func _test_treatment() -> void:
	var data := _data(720, Town.TREAT_PRICE)
	var player := _player("su_qin")
	player.stamina = 75.0
	player.hunger = 90.0
	player.thirst = 95.0
	player.resting = true
	player.sleep_ready = true
	Town.action(data, player, "town_treat", {"id": "su_qin"})
	_check(data.money == 0 and player.stamina == 100 and player.hunger == 100 and player.thirst == 100 and not player.resting and not player.sleep_ready, "clinic spends exactly five coins, caps existing vitals and cancels resting/readiness")
	data.money = 100
	var before := _snapshot(data, player)
	Town.action(data, player, "town_treat", {"id": "su_qin"})
	_check(_snapshot(data, player) == before, "fully replenished visitors are not charged repeatedly")
	data.money = 4
	player.stamina = 10.0
	before = _snapshot(data, player)
	Town.action(data, player, "town_treat", {"id": "su_qin"})
	_check(_snapshot(data, player) == before, "insufficient clinic payment grants nothing and preserves all state")
	player = _player("lin_sui")
	before = _snapshot(data, player)
	Town.action(data, player, "town_treat", {"id": "lin_sui"})
	_check(_snapshot(data, player) == before, "request cannot use a nearby different resident as the doctor")


func _test_bath() -> void:
	var data := _data(720, Town.BATH_PRICE)
	var player := _player("tang_he")
	player.stamina = 20.0
	player.thirst = 90.0
	player.sleep_ready = true
	player.resting = true
	Town.action(data, player, "town_bath", {"id": "tang_he"})
	_check(Town.valid(player.activity) and player.activity.size() == 6 and data.money == 3 and not player.resting and not player.sleep_ready, "bath starts one bounded transient activity without charging early or granting free camp rest")
	_check(Town.valid(JSON.parse_string(JSON.stringify(player.activity))), "bath activity accepts JSON numeric roundtrip without permanent NPC state")
	Town.tick(data, player, 7.5)
	_check(player.activity.remaining == 0.5 and player.stamina == 20 and player.thirst == 90 and data.money == 3, "incomplete bath neither pays nor restores vitals")
	Town.tick(data, player, 0.5)
	_check(player.activity.is_empty() and player.stamina == 80 and player.thirst == 100 and player.hunger == 60 and data.money == 0, "completed bath restores capped stamina and water only, charging once")
	var before := _snapshot(data, player)
	Town.tick(data, player, 99)
	_check(_snapshot(data, player) == before, "repeated tick cannot settle a completed bath again")
	player = _player("tang_he")
	player.stamina = 100.0
	player.thirst = 100.0
	data.money = 20
	before = _snapshot(data, player)
	Town.action(data, player, "town_bath", {"id": "tang_he"})
	_check(_snapshot(data, player) == before, "bath does not charge or start for full stamina and water, even if hungry")
	player.stamina = 10.0
	data.money = 2
	before = _snapshot(data, player)
	Town.action(data, player, "town_bath", {"id": "tang_he"})
	_check(_snapshot(data, player) == before, "bath requires available shared funds even though it settles later")


func _test_bath_cancellation_and_validation() -> void:
	for reason in ["moved", "closed", "offline", "area", "right_click", "funds"]:
		var data := _data(720, 3)
		var player := _player("tang_he")
		Town.action(data, player, "town_bath", {"id": "tang_he"})
		match reason:
			"moved": player.x += 8.01
			"closed": data.minute = float(Town.NPCS.tang_he.end)
			"offline": player.online = false
			"area": player.area = "water"
			"right_click": player.activity = {} # Same generic cancel contract used by WorldState.
			"funds": data.money = 2 # The other player legitimately spent shared money first.
		Town.tick(data, player, 8)
		_check(player.activity.is_empty() and player.stamina == 40 and player.thirst == 65 and data.money == (2 if reason == "funds" else 3), "interrupted or unaffordable bath loses no payment and gives no unearned recovery: " + reason)
	var data := _data()
	var player := _player("tang_he")
	Town.action(data, player, "town_bath", {"id": "tang_he"})
	var valid_activity: Dictionary = player.activity.duplicate(true)
	for row in [["kind", "island_gather"], ["id", "su_qin"], ["duration", 0.1], ["remaining", -1], ["remaining", 8.01], ["start_x", INF], ["start_y", 900000], ["remaining", "8"]]:
		var invalid: Dictionary = valid_activity.duplicate(true)
		invalid[row[0]] = row[1]
		_check(not Town.valid(invalid), "malformed bath save state is rejected: " + str(row))
	var extra := valid_activity.duplicate(true)
	extra.reward = 999
	_check(not Town.valid(extra) and not Town.valid({}) and not Town.valid([]), "bath validator forbids extra reward fields and wrong shapes")
	var before := _snapshot(data, player)
	Town.tick(data, player, NAN)
	Town.tick(data, player, -1)
	_check(_snapshot(data, player) == before, "nonfinite and negative time cannot progress or corrupt the bath")
	player.activity = {"kind": "island_gather", "fixture": true}
	before = _snapshot(data, player)
	Town.tick(data, player, 8)
	_check(_snapshot(data, player) == before, "town tick never mutates another system's activity")


func _test_shared_money_races() -> void:
	var data := _data(720, 3)
	var host := _player("tang_he")
	var guest := _player("tang_he")
	Town.action(data, host, "town_bath", {"id": "tang_he"})
	Town.action(data, guest, "town_bath", {"id": "tang_he"})
	_check(not host.activity.is_empty() and not guest.activity.is_empty() and data.money == 3, "two visitors may rest independently without hidden shared reservation state")
	Town.tick(data, host, 8)
	Town.tick(data, guest, 8)
	_check(data.money == 0 and host.stamina == 100 and guest.stamina == 40 and host.activity.is_empty() and guest.activity.is_empty(), "serialized host settlement cannot overdraw shared coins or grant two baths for one fee")
	data.money = 12
	host = _player("yan_zhen")
	guest = _player("yan_zhen")
	_trade(data, host, "yan_zhen", "buy_axe")
	_trade(data, guest, "yan_zhen", "buy_axe")
	_check(data.money == 0 and Inventory.count(host.bag, "axe") == 1 and Inventory.count(guest.bag, "axe") == 0, "sequential authoritative purchases cannot spend the same shared coins twice")
	data.money = 0
	host = _player("zhou_chao", 720, {"fish": 1})
	guest = _player("zhou_chao")
	_trade(data, guest, "zhou_chao", "sell_fish")
	_check(data.money == 0 and Inventory.count(host.bag, "fish") == 1, "guest cannot sell host personal inventory")
	_trade(data, host, "zhou_chao", "sell_fish")
	_trade(data, guest, "zhou_chao", "sell_fish")
	_check(data.money == 4 and Inventory.count(host.bag, "fish") == 0 and Inventory.count(guest.bag, "fish") == 0, "a real sale is shared income exactly once and never duplicates the item")

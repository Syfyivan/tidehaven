extends SceneTree
## End-to-end rule, atomicity, old-save fast-forward, ocean NPC chronicle actions,
## and v16 / v17 -> v18 migration checks for all 4 flagship chronicles:
## P2-09 《候潮院》, P2-10 《今晚留一碗》, P2-11 《重新有人靠岸》, P2-12 《海里也有邻居》.
const WorldState = preload("res://scripts/world_state.gd")
const LongStories = preload("res://scripts/long_stories.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const IslandTown = preload("res://scripts/island_town.gd")
const OceanResidents = preload("res://scripts/ocean_residents.gd")
const Restaurant = preload("res://scripts/restaurant.gd")
const Rooms = preload("res://scripts/rooms.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
const Inventory = preload("res://scripts/inventory.gd")
const ResidentDialogue = preload("res://scripts/resident_dialogue.gd")
var checks := 0
var failures := 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL chronicle: ", label)

func _place_near_npc(world, slot: String, npc_id: String) -> void:
	world.data.minute = 660.0
	if OceanResidents.NPCS.has(npc_id):
		var room: String = OceanResidents.NPCS[npc_id].room
		if room.begins_with("island_"):
			var coast := Archipelago.island_position(world.data.chart, room)
			world.data.navigation.x = coast.x
			world.data.navigation.y = coast.y
			world.data.navigation.anchored = true
		elif room == "sea_3":
			world.data.rooms.opened.sea = 3
		Rooms._arrive(world.data, world.data.players[slot], room, OceanResidents.position(npc_id) + Vector2(36, 0))
		return
	var host_dock := Archipelago.island_position(world.data.chart, Archipelago.HOME_ID)
	world.data.navigation.x = host_dock.x
	world.data.navigation.y = host_dock.y
	world.data.navigation.anchored = true
	var loc := IslandTown.location(npc_id, 660.0, world.data)
	if loc.area == "room" and not str(loc.room).is_empty():
		world.data.rooms.visited[loc.room] = true
	world.data.players[slot].area = loc.area
	world.data.players[slot].room = loc.room
	world.data.players[slot].x = loc.at.x
	world.data.players[slot].y = loc.at.y + 20.0

func _initialize() -> void:
	var world := WorldState.new()
	world.join("host", "船长")
	world.join("guest", "伙伴")
	var dock_at := Archipelago.island_position(world.data.chart, Archipelago.HOME_ID)
	world.data.navigation.x = dock_at.x
	world.data.navigation.y = dock_at.y
	world.data.navigation.anchored = true
	world.data.chart.visited = true

	_test_hou_chao_yuan(world)
	_test_liu_yi_wan(world)
	_test_kao_an(world)
	_test_hai_lin_ju(world)
	_test_kan_jian_hai(world)
	_test_wai_luo_bo(world)
	_test_liu_yi_ba_yi_zi(world)
	_test_jin_nian_sha_tan(world)
	_test_migrations(world)

	print("CHRONICLE CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_hou_chao_yuan(world) -> void:
	world.data.players.host.area = "island"
	world.data.players.host.room = ""
	world.data.players.host.x = IslandMap.YARD_GATE.x
	world.data.players.host.y = IslandMap.YARD_GATE.y
	world.action("host", "yard_inspect")
	_check(int(LongStories.record(world.data).step) == 0, "unrented yard does not start hou_chao_yuan")

	_place_near_npc(world, "host", "xu_an")
	world.action("host", "town_rent", {"id": "xu_an"})
	world.data.players.host.area = "island"
	world.data.players.host.room = ""
	world.data.players.host.x = IslandMap.YARD_GATE.x
	world.data.players.host.y = IslandMap.YARD_GATE.y
	_check(world.interaction_options("host").any(func(o): return o.action == "yard_inspect"), "rented yard gate offers carving inspection")
	world.action("host", "yard_inspect")
	_check(int(LongStories.record(world.data).step) == 1, "inspecting gate advances hou_chao_yuan to step 1")

	_place_near_npc(world, "host", "xu_an")
	world.action("host", "town_chronicle_reply", {"id": "xu_an", "arc": "hou_chao_yuan", "step": 1, "reply": 0})
	_place_near_npc(world, "guest", "he_mu")
	var before_shortage: Dictionary = world.snapshot()
	world.action("guest", "town_chronicle_reply", {"id": "he_mu", "arc": "hou_chao_yuan", "step": 2, "reply": 1})
	_check(world.snapshot() == before_shortage, "hou_chao_yuan step 2 without 6 wood is atomic")
	Inventory.add(world.data.players.guest.bag, "wood", 6)
	world.action("guest", "town_chronicle_reply", {"id": "he_mu", "arc": "hou_chao_yuan", "step": 2, "reply": 1})
	_check(int(LongStories.record(world.data).step) == 3, "hou_chao_yuan step 2 advances to step 3")

	var repaired_world := WorldState.new()
	repaired_world.join("host", "老档")
	repaired_world.data.island.homestead.rented = true
	repaired_world.data.housing.level = 1
	repaired_world.data.housing.cabin = {"x": 480.0, "y": 224.0}
	repaired_world.data.housing.carpenter = true
	repaired_world.data.rooms.visited["raft_cabin"] = true
	repaired_world.data.chronicles.hou_chao_yuan = {"step": 2, "day": 1, "choices": [0], "style": ""}
	_place_near_npc(repaired_world, "host", "he_mu")
	repaired_world.action("host", "town_chronicle_reply", {"id": "he_mu", "arc": "hou_chao_yuan", "step": 2, "reply": 0})
	_check(int(LongStories.record(repaired_world.data).step) == 3, "already-repaired house skips wood on hou_chao_yuan")

	_place_near_npc(world, "host", "qiao_xin")
	Inventory.add(world.data.players.host.bag, "fiber", 2)
	world.action("host", "town_chronicle_reply", {"id": "qiao_xin", "arc": "hou_chao_yuan", "step": 3, "reply": 1})
	world.data.day += 1
	world.action("host", "town_chronicle_reply", {"id": "qiao_xin", "arc": "hou_chao_yuan", "step": 4, "reply": 1})
	_check(int(LongStories.record(world.data).step) == 5 and LongStories.record(world.data).style == "inn", "hou_chao_yuan completes with inn style")
	world.data.players.host.area = "island"
	world.data.players.host.room = ""
	world.data.players.host.x = IslandMap.YARD_GATE.x
	world.data.players.host.y = IslandMap.YARD_GATE.y
	world.action("host", "yard_style")
	_check(LongStories.record(world.data).style == "farm", "yard_style toggles plaque to farm")

func _test_liu_yi_wan(world) -> void:
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Rooms._arrive(world.data, world.data.players.host, "restaurant", Restaurant.counter() + Vector2(0, 24))
	world.action("host", "shop_inspect")
	_check(int(LongStories.record(world.data, "liu_yi_wan").step) == 0, "unrented restaurant cannot start liu_yi_wan")

	world.data.restaurant.rented = true
	_check(world.interaction_options("host").any(func(o): return o.action == "shop_inspect"), "rented restaurant counter offers shop_inspect")
	world.action("host", "shop_inspect")
	_check(int(LongStories.record(world.data, "liu_yi_wan").step) == 1, "shop_inspect advances liu_yi_wan to step 1")

	_place_near_npc(world, "host", "chen_yu")
	world.action("host", "town_chronicle_reply", {"id": "chen_yu", "arc": "liu_yi_wan", "step": 1, "reply": 1})
	_check(int(LongStories.record(world.data, "liu_yi_wan").step) == 2, "chen_yu advances liu_yi_wan to step 2")

	# Verify old-save operated-shop branch skips veg x2
	var operated_world := WorldState.new()
	operated_world.join("host", "店主")
	operated_world.data.restaurant.rented = true
	operated_world.data.restaurant.last = {"day": 1, "served": 2, "missed": 0, "revenue": 28}
	operated_world.data.chronicles.liu_yi_wan = {"step": 2, "day": 1, "choices": [0], "style": ""}
	_place_near_npc(operated_world, "host", "tian_qing")
	operated_world.action("host", "town_chronicle_reply", {"id": "tian_qing", "arc": "liu_yi_wan", "step": 2, "reply": 0})
	_check(int(LongStories.record(operated_world.data, "liu_yi_wan").step) == 3, "already-operated shop skips veg cost at Tian Qing")

	# Normal path with veg x2 -> su_qin fish x2 -> overnight -> 3-way choice #2 (seafood)
	_place_near_npc(world, "host", "tian_qing")
	Inventory.add(world.data.players.host.bag, "veg", 2)
	world.action("host", "town_chronicle_reply", {"id": "tian_qing", "arc": "liu_yi_wan", "step": 2, "reply": 0})
	_place_near_npc(world, "host", "su_qin")
	Inventory.add(world.data.players.host.bag, "fish", 2)
	world.action("host", "town_chronicle_reply", {"id": "su_qin", "arc": "liu_yi_wan", "step": 3, "reply": 1})
	_check(int(LongStories.record(world.data, "liu_yi_wan").step) == 4 and LongStories.waiting_overnight(world.data, "liu_yi_wan"), "su_qin advances liu_yi_wan to step 4 overnight prep")

	world.data.day += 1
	_place_near_npc(world, "host", "chen_yu")
	var money_before := int(world.data.money)
	world.action("host", "town_chronicle_reply", {"id": "chen_yu", "arc": "liu_yi_wan", "step": 4, "reply": 2})
	var rec := LongStories.record(world.data, "liu_yi_wan")
	_check(int(rec.step) == 5 and rec.style == "seafood", "liu_yi_wan 3rd option sets seafood style")
	_check(int(world.data.money) == money_before + 40 and Inventory.count(world.data.players.host.bag, "maki") == 2, "liu_yi_wan awards 40 coins and 2 maki")

	Rooms._arrive(world.data, world.data.players.host, "restaurant", Restaurant.counter() + Vector2(0, 24))
	world.action("host", "shop_style")
	_check(LongStories.record(world.data, "liu_yi_wan").style == "home", "shop_style cycles seafood -> home")
	_check(not ResidentDialogue.chronicle_line(world.data, "chen_yu").is_empty(), "chen_yu daily dialogue reflects liu_yi_wan")

func _test_kao_an(world) -> void:
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	world.data.players.host.area = "island"
	world.data.players.host.room = ""
	world.data.players.host.x = IslandMap.DOCK.x
	world.data.players.host.y = IslandMap.DOCK.y
	world.action("host", "dock_inspect")
	_check(int(LongStories.record(world.data, "kao_an").step) == 0, "unlit beacon does not start kao_an")

	world.data.journal.story_step = 1
	world.action("host", "dock_inspect")
	_check(int(LongStories.record(world.data, "kao_an").step) == 1, "lit beacon unlocks dock_inspect to step 1")

	_place_near_npc(world, "host", "xu_an")
	world.action("host", "town_chronicle_reply", {"id": "xu_an", "arc": "kao_an", "step": 1, "reply": 0})
	_place_near_npc(world, "host", "lu_yao")
	world.action("host", "town_chronicle_reply", {"id": "lu_yao", "arc": "kao_an", "step": 2, "reply": 1})
	_check(int(LongStories.record(world.data, "kao_an").step) == 3, "lu_yao sends player to Mist Island Bai Fan")

	# Sail to Mist Island & advance via ocean_chronicle_reply on Bai Fan
	_place_near_npc(world, "host", "bai_fan")
	_check(world.interaction_options("host").any(func(o): return o.action == "ocean_chronicle_open"), "bai_fan offers ocean_chronicle_open")
	Inventory.add(world.data.players.host.bag, "wood", 4)
	Inventory.add(world.data.players.host.bag, "rope", 1)
	world.action("host", "ocean_chronicle_reply", {"id": "bai_fan", "arc": "kao_an", "step": 3, "reply": 0})
	_check(int(LongStories.record(world.data, "kao_an").step) == 4, "bai_fan lashes reef marker and advances kao_an to step 4")

	world.data.day += 1
	_place_near_npc(world, "host", "qiao_xin")
	var money_before := int(world.data.money)
	world.action("host", "town_chronicle_reply", {"id": "qiao_xin", "arc": "kao_an", "step": 4, "reply": 1})
	var rec := LongStories.record(world.data, "kao_an")
	_check(int(rec.step) == 5 and rec.style == "ferry", "kao_an completes with ferry style")
	_check(int(world.data.money) == money_before + 45 and Inventory.count(world.data.players.host.bag, "cooked_fish") == 2, "kao_an awards 45 coins and 2 cooked_fish")
	world.data.players.host.area = "island"
	world.data.players.host.room = ""
	world.data.players.host.x = IslandMap.DOCK.x
	world.data.players.host.y = IslandMap.DOCK.y
	world.action("host", "dock_style")
	_check(LongStories.record(world.data, "kao_an").style == "supply", "dock_style toggles ferry -> supply")

func _test_hai_lin_ju(world) -> void:
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	world.data.players.host.area = "island"
	world.data.players.host.room = ""
	world.data.players.host.x = LongStories.COAST_SITE.x
	world.data.players.host.y = LongStories.COAST_SITE.y
	world.action("host", "coast_inspect")
	_check(int(LongStories.record(world.data, "hai_lin_ju").step) == 1, "coast_inspect starts hai_lin_ju at step 1")

	_place_near_npc(world, "host", "wen_zhi")
	world.action("host", "town_chronicle_reply", {"id": "wen_zhi", "arc": "hai_lin_ju", "step": 1, "reply": 0})
	_check(int(LongStories.record(world.data, "hai_lin_ju").step) == 2, "wen_zhi advances hai_lin_ju to step 2")

	# Before tide_speech, magic sea NPC rejects conversation cleanly without mutating state
	_place_near_npc(world, "host", "chao_jia")
	var pre_speech: Dictionary = world.snapshot()
	var blocked_msg: String = world.action("host", "ocean_chronicle_reply", {"id": "chao_jia", "arc": "hai_lin_ju", "step": 2, "reply": 0})
	_check(blocked_msg.contains("不能理解") and world.snapshot() == pre_speech, "chao_jia requires tide_speech before chronicle dialogue")

	# Unlock tide_speech + existing spell -> verify spells stay intact throughout chronicle!
	world.data.journal.story_step = 3
	world.data.journal.tide_speech = true
	world.data.journal.spells["breath"] = true
	world.action("host", "ocean_chronicle_reply", {"id": "chao_jia", "arc": "hai_lin_ju", "step": 2, "reply": 0})
	_check(int(LongStories.record(world.data, "hai_lin_ju").step) == 3, "chao_jia advances hai_lin_ju to step 3")

	_place_near_npc(world, "host", "lan_ying")
	Inventory.add(world.data.players.host.bag, "stone", 2)
	world.action("host", "ocean_chronicle_reply", {"id": "lan_ying", "arc": "hai_lin_ju", "step": 3, "reply": 0})
	_check(int(LongStories.record(world.data, "hai_lin_ju").step) == 4, "lan_ying accepts 2 stone and advances hai_lin_ju to step 4")

	world.data.day += 1
	_place_near_npc(world, "host", "wen_zhi")
	var money_before := int(world.data.money)
	world.action("host", "town_chronicle_reply", {"id": "wen_zhi", "arc": "hai_lin_ju", "step": 4, "reply": 1})
	var rec := LongStories.record(world.data, "hai_lin_ju")
	_check(int(rec.step) == 5 and rec.style == "chime" and bool(world.data.journal.spells.get("breath", false)), "hai_lin_ju completes with chime style while preserving existing spells")
	_check(int(world.data.money) == money_before + 45 and Inventory.count(world.data.players.host.bag, "salad") == 2, "hai_lin_ju awards 45 coins and 2 salad")
	world.data.players.host.area = "island"
	world.data.players.host.room = ""
	world.data.players.host.x = LongStories.COAST_SITE.x
	world.data.players.host.y = LongStories.COAST_SITE.y
	world.action("host", "coast_style")
	_check(LongStories.record(world.data, "hai_lin_ju").style == "stone", "coast_style toggles chime -> stone")

func _test_kan_jian_hai(world) -> void:
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	var c_door: Vector2 = IslandMap.LANDMARKS.carpenter.door
	world.data.players.host.area = "island"
	world.data.players.host.room = ""
	world.data.players.host.x = c_door.x
	world.data.players.host.y = c_door.y
	world.data.housing.level = 0
	world.data.housing.carpenter = false
	world.action("host", "workshop_inspect")
	_check(int(LongStories.record(world.data, "kan_jian_hai").step) == 0, "unrepaired house does not start kan_jian_hai")

	world.data.housing.level = 1
	world.action("host", "workshop_inspect")
	_check(int(LongStories.record(world.data, "kan_jian_hai").step) == 1, "repaired house unlocks workshop_inspect")

	# Verify old-save settled carpenter branch waives wood x4 + ingot x1 at Yan Zhen
	var cabin_world := WorldState.new()
	cabin_world.join("host", "老船长")
	cabin_world.data.housing.carpenter = true
	cabin_world.data.housing.cabin = {"x": 480.0, "y": 224.0}
	cabin_world.data.rooms.visited["raft_cabin"] = true
	cabin_world.data.chronicles.kan_jian_hai = {"step": 2, "day": 1, "choices": [0], "style": ""}
	_place_near_npc(cabin_world, "host", "yan_zhen")
	cabin_world.action("host", "town_chronicle_reply", {"id": "yan_zhen", "arc": "kan_jian_hai", "step": 2, "reply": 0})
	_check(int(LongStories.record(cabin_world.data, "kan_jian_hai").step) == 3, "settled raft carpenter skips wood+ingot cost on kan_jian_hai")

	_place_near_npc(world, "host", "he_mu")
	world.action("host", "town_chronicle_reply", {"id": "he_mu", "arc": "kan_jian_hai", "step": 1, "reply": 0})
	_place_near_npc(world, "host", "yan_zhen")
	Inventory.add(world.data.players.host.bag, "wood", 4)
	Inventory.add(world.data.players.host.bag, "ingot", 1)
	world.action("host", "town_chronicle_reply", {"id": "yan_zhen", "arc": "kan_jian_hai", "step": 2, "reply": 1})
	_place_near_npc(world, "host", "bai_fan")
	Inventory.add(world.data.players.host.bag, "rope", 1)
	world.action("host", "ocean_chronicle_reply", {"id": "bai_fan", "arc": "kan_jian_hai", "step": 3, "reply": 0})
	_check(int(LongStories.record(world.data, "kan_jian_hai").step) == 4, "bai_fan advances kan_jian_hai to step 4")

	world.data.day += 1
	_place_near_npc(world, "host", "he_mu")
	var money_before := int(world.data.money)
	world.action("host", "town_chronicle_reply", {"id": "he_mu", "arc": "kan_jian_hai", "step": 4, "reply": 1})
	var rec := LongStories.record(world.data, "kan_jian_hai")
	_check(int(rec.step) == 5 and rec.style == "lamp", "kan_jian_hai completes with lamp style")
	_check(int(world.data.money) == money_before + 40 and Inventory.count(world.data.players.host.bag, "meal") == 2, "kan_jian_hai awards 40 coins and 2 meal")
	world.data.players.host.area = "island"
	world.data.players.host.room = ""
	world.data.players.host.x = c_door.x
	world.data.players.host.y = c_door.y
	world.action("host", "workshop_style")
	_check(LongStories.record(world.data, "kan_jian_hai").style == "breeze", "workshop_style toggles lamp -> breeze")

func _test_wai_luo_bo(world) -> void:
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	var f_door: Vector2 = IslandMap.LANDMARKS.farmhouse.door
	world.data.players.host.area = "island"
	world.data.players.host.room = ""
	world.data.players.host.x = f_door.x
	world.data.players.host.y = f_door.y
	world.action("host", "farm_inspect")
	_check(int(LongStories.record(world.data, "wai_luo_bo").step) == 1, "farm_inspect starts wai_luo_bo")

	_place_near_npc(world, "host", "tian_qing")
	world.action("host", "town_chronicle_reply", {"id": "tian_qing", "arc": "wai_luo_bo", "step": 1, "reply": 0})
	_place_near_npc(world, "host", "lin_sui")
	world.action("host", "town_chronicle_reply", {"id": "lin_sui", "arc": "wai_luo_bo", "step": 2, "reply": 1})
	_place_near_npc(world, "host", "chen_yu")
	Inventory.add(world.data.players.host.bag, "veg", 3)
	Inventory.add(world.data.players.host.bag, "mushroom", 1)
	world.action("host", "town_chronicle_reply", {"id": "chen_yu", "arc": "wai_luo_bo", "step": 3, "reply": 0})
	world.data.day += 1
	_place_near_npc(world, "host", "tian_qing")
	var money_before := int(world.data.money)
	world.action("host", "town_chronicle_reply", {"id": "tian_qing", "arc": "wai_luo_bo", "step": 4, "reply": 1})
	var rec := LongStories.record(world.data, "wai_luo_bo")
	_check(int(rec.step) == 5 and rec.style == "crock" and int(world.data.money) == money_before + 35 and Inventory.count(world.data.players.host.bag, "salad") == 2, "wai_luo_bo completes with crock style, 35 coins and 2 salad")
	world.data.players.host.area = "island"
	world.data.players.host.room = ""
	world.data.players.host.x = f_door.x
	world.data.players.host.y = f_door.y
	world.action("host", "farm_style")
	_check(LongStories.record(world.data, "wai_luo_bo").style == "basket", "farm_style toggles crock -> basket")

func _test_liu_yi_ba_yi_zi(world) -> void:
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	_place_near_npc(world, "host", "chi_sheng")
	world.action("host", "pirate_inspect")
	_check(int(LongStories.record(world.data, "liu_yi_ba_yi_zi").step) == 1, "pirate_inspect starts liu_yi_ba_yi_zi on Reef Island")

	world.action("host", "ocean_chronicle_reply", {"id": "chi_sheng", "arc": "liu_yi_ba_yi_zi", "step": 1, "reply": 0})
	_place_near_npc(world, "host", "zhou_chao")
	var zc_text := LongStories.open(world.data, "周潮", {"id": "zhou_chao", "arc": "liu_yi_ba_yi_zi", "step": 2})
	_check(zc_text.contains("不是什么误会") and zc_text.contains("备用粗缆"), "zhou_chao confirms real past theft rather than misunderstanding")
	world.action("host", "town_chronicle_reply", {"id": "zhou_chao", "arc": "liu_yi_ba_yi_zi", "step": 2, "reply": 0})

	_place_near_npc(world, "host", "chi_sheng")
	Inventory.add(world.data.players.host.bag, "rope", 2)
	Inventory.add(world.data.players.host.bag, "scrap", 2)
	world.action("host", "ocean_chronicle_reply", {"id": "chi_sheng", "arc": "liu_yi_ba_yi_zi", "step": 3, "reply": 0})
	world.data.day += 1
	_place_near_npc(world, "host", "chen_yu")
	var money_before := int(world.data.money)
	world.action("host", "town_chronicle_reply", {"id": "chen_yu", "arc": "liu_yi_ba_yi_zi", "step": 4, "reply": 2})
	var rec := LongStories.record(world.data, "liu_yi_ba_yi_zi")
	_check(int(rec.step) == 5 and rec.style == "slate" and int(world.data.money) == money_before + 45 and Inventory.count(world.data.players.host.bag, "cooked_fish") == 2, "liu_yi_ba_yi_zi 3rd option sets slate style and awards 45 coins + 2 cooked_fish")
	var r_door: Vector2 = IslandMap.LANDMARKS.restaurant.door
	world.data.players.host.area = "island"
	world.data.players.host.room = ""
	world.data.players.host.x = r_door.x
	world.data.players.host.y = r_door.y
	world.action("host", "pirate_style")
	_check(LongStories.record(world.data, "liu_yi_ba_yi_zi").style == "stool", "pirate_style cycles slate -> stool")

func _test_jin_nian_sha_tan(world) -> void:
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	var coast := Archipelago.island_position(world.data.chart, "island_reef")
	world.data.navigation.x = coast.x
	world.data.navigation.y = coast.y
	world.data.navigation.anchored = true
	var reef_pt := OceanResidents.position("chao_jia") + LongStories.REEF_OFFSET
	Rooms._arrive(world.data, world.data.players.host, "island_reef", reef_pt)
	world.action("host", "reef_inspect")
	_check(int(LongStories.record(world.data, "jin_nian_sha_tan").step) == 1, "reef_inspect starts jin_nian_sha_tan")

	_place_near_npc(world, "host", "chao_jia")
	world.action("host", "ocean_chronicle_reply", {"id": "chao_jia", "arc": "jin_nian_sha_tan", "step": 1, "reply": 0})
	_place_near_npc(world, "host", "lu_zhou")
	world.action("host", "town_chronicle_reply", {"id": "lu_zhou", "arc": "jin_nian_sha_tan", "step": 2, "reply": 0})
	_place_near_npc(world, "host", "tai_lu")
	Inventory.add(world.data.players.host.bag, "fiber", 3)
	world.action("host", "ocean_chronicle_reply", {"id": "tai_lu", "arc": "jin_nian_sha_tan", "step": 3, "reply": 0})
	world.data.day += 1
	_place_near_npc(world, "host", "chao_jia")
	var money_before := int(world.data.money)
	world.action("host", "ocean_chronicle_reply", {"id": "chao_jia", "arc": "jin_nian_sha_tan", "step": 4, "reply": 0})
	var rec := LongStories.record(world.data, "jin_nian_sha_tan")
	_check(int(rec.step) == 5 and rec.style == "sand" and int(world.data.money) == money_before + 40 and Inventory.count(world.data.players.host.bag, "sashimi") == 2, "jin_nian_sha_tan completes with sand style, 40 coins and 2 sashimi")
	Rooms._arrive(world.data, world.data.players.host, "island_reef", reef_pt)
	world.action("host", "reef_style")
	_check(LongStories.record(world.data, "jin_nian_sha_tan").style == "marker", "reef_style toggles sand -> marker")

func _test_migrations(world) -> void:
	# Ensure host is anchored at home island before snapshot
	var dock_at := Archipelago.island_position(world.data.chart, Archipelago.HOME_ID)
	world.data.navigation.x = dock_at.x
	world.data.navigation.y = dock_at.y
	world.data.navigation.anchored = true
	world.data.players.host.area = "island"
	world.data.players.host.room = ""
	world.data.players.host.x = IslandMap.DOCK.x
	world.data.players.host.y = IslandMap.DOCK.y
	var roundtrip := WorldState.new()
	_check(roundtrip.restore(JSON.parse_string(JSON.stringify(world.snapshot()))) and roundtrip.data.chronicles == world.data.chronicles, "v19 all 8 chronicles survive JSON round-trip")

	# v18 save with 4 arcs migrates losslessly to v19 with 4 new blank arcs
	var v18_copy: Dictionary = world.snapshot()
	v18_copy.version = 18
	v18_copy.chronicles = {
		"hou_chao_yuan": world.data.chronicles.hou_chao_yuan.duplicate(true),
		"liu_yi_wan": world.data.chronicles.liu_yi_wan.duplicate(true),
		"kao_an": world.data.chronicles.kao_an.duplicate(true),
		"hai_lin_ju": world.data.chronicles.hai_lin_ju.duplicate(true),
	}
	var from_v18 := WorldState.new()
	_check(from_v18.restore(JSON.parse_string(JSON.stringify(v18_copy))) and int(from_v18.data.version) == 19 and from_v18.data.chronicles.liu_yi_wan == v18_copy.chronicles.liu_yi_wan and int(from_v18.data.chronicles.kan_jian_hai.step) == 0, "v18 save migrates losslessly to v19 preserving all 4 0.20 arcs")

	# v17 save with only hou_chao_yuan migrates losslessly to v19
	var v17_copy: Dictionary = world.snapshot()
	v17_copy.version = 17
	v17_copy.chronicles = {"hou_chao_yuan": world.data.chronicles.hou_chao_yuan.duplicate(true)}
	var from_v17 := WorldState.new()
	_check(from_v17.restore(JSON.parse_string(JSON.stringify(v17_copy))) and int(from_v17.data.version) == 19 and from_v17.data.chronicles.hou_chao_yuan == v17_copy.chronicles.hou_chao_yuan and int(from_v17.data.chronicles.liu_yi_ba_yi_zi.step) == 0, "v17 save migrates losslessly to v19 preserving Hou Chao Yuan")

	# v16 save without chronicles migrates losslessly to v19
	var v16_copy: Dictionary = world.snapshot()
	v16_copy.version = 16
	v16_copy.erase("chronicles")
	var from_v16 := WorldState.new()
	_check(from_v16.restore(JSON.parse_string(JSON.stringify(v16_copy))) and int(from_v16.data.version) == 19 and int(from_v16.data.chronicles.jin_nian_sha_tan.step) == 0, "v16 save migrates cleanly to v19")

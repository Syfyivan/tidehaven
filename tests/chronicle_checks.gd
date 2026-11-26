extends SceneTree
## End-to-end rule, atomicity, old-save housing skip, and v16->v17 migration checks for P2-09 《候潮院》.
const WorldState = preload("res://scripts/world_state.gd")
const LongStories = preload("res://scripts/long_stories.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const IslandTown = preload("res://scripts/island_town.gd")
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
	var loc := IslandTown.location(npc_id, 660.0, world.data)
	if loc.area == "room" and not str(loc.room).is_empty():
		world.data.rooms.visited[loc.room] = true
	world.data.players[slot].area = loc.area
	world.data.players[slot].room = loc.room
	world.data.players[slot].x = loc.at.x
	world.data.players[slot].y = loc.at.y + 20.0

func _initialize() -> void:
	var Archipelago = preload("res://scripts/archipelago.gd")
	var world := WorldState.new()
	world.join("host", "船长")
	world.join("guest", "伙伴")
	var dock_at := Archipelago.island_position(world.data.chart, Archipelago.HOME_ID)
	world.data.navigation.x = dock_at.x
	world.data.navigation.y = dock_at.y
	world.data.navigation.anchored = true
	world.data.chart.visited = true

	# Gate inspect requires renting homestead first
	world.data.players.host.area = "island"
	world.data.players.host.x = IslandMap.YARD_GATE.x
	world.data.players.host.y = IslandMap.YARD_GATE.y
	world.action("host", "yard_inspect")
	_check(int(LongStories.record(world.data).step) == 0, "unrented yard does not start chronicle")

	# Rent homestead -> inspect gate carving (0 -> 1), partner repeat is idempotent
	_place_near_npc(world, "host", "xu_an")
	world.action("host", "town_rent", {"id": "xu_an"})
	world.data.players.host.area = "island"
	world.data.players.host.x = IslandMap.YARD_GATE.x
	world.data.players.host.y = IslandMap.YARD_GATE.y
	var opts := world.interaction_options("host")
	_check(opts.any(func(o): return o.action == "yard_inspect"), "rented yard gate offers carving inspection")
	world.action("host", "yard_inspect")
	_check(int(LongStories.record(world.data).step) == 1, "inspecting gate advances hou_chao_yuan to step 1")
	world.data.players.guest.area = "island"
	world.data.players.guest.x = IslandMap.YARD_GATE.x
	world.data.players.guest.y = IslandMap.YARD_GATE.y
	world.action("guest", "yard_inspect")
	_check(int(LongStories.record(world.data).step) == 1, "partner repeat inspection does not skip steps")

	# Step 1 -> 2 at Xu An
	_place_near_npc(world, "host", "xu_an")
	var open_1 := world.action("host", "town_chronicle_open", {"id": "xu_an", "arc": "hou_chao_yuan", "step": 1})
	_check(open_1.contains("候潮院") and open_1.contains("岑婆"), "step 1 dialogue introduces Hou Chao Yuan and Cen Po")
	world.action("host", "town_chronicle_reply", {"id": "xu_an", "arc": "hou_chao_yuan", "step": 1, "reply": 0})
	_check(int(LongStories.record(world.data).step) == 2 and int(world.data.journal.host.friendship.get("xu_an", 0)) == 15, "step 1 reply advances to step 2 and grants Xu An friendship")

	# Step 2 -> 3 at He Mu: test shortage atomicity first, then 6 wood payment
	_place_near_npc(world, "guest", "he_mu")
	var before_shortage := world.snapshot()
	world.action("guest", "town_chronicle_reply", {"id": "he_mu", "arc": "hou_chao_yuan", "step": 2, "reply": 1})
	_check(world.snapshot() == before_shortage, "step 2 without 6 wood is atomic")
	Inventory.add(world.data.players.guest.bag, "wood", 6)
	world.action("guest", "town_chronicle_reply", {"id": "he_mu", "arc": "hou_chao_yuan", "step": 2, "reply": 1})
	_check(int(LongStories.record(world.data).step) == 3 and Inventory.count(world.data.players.guest.bag, "wood") == 0, "step 2 deducts 6 wood and advances to step 3")

	# Also verify old-save repaired-house branch + He Mu in raft_cabin skips wood requirement
	var repaired_world := WorldState.new()
	repaired_world.join("host", "老档")
	repaired_world.data.island.homestead.rented = true
	repaired_world.data.housing.site = 0
	repaired_world.data.housing.level = 1
	repaired_world.data.housing.cabin = {"x": 480.0, "y": 224.0}
	repaired_world.data.housing.carpenter = true
	repaired_world.data.rooms.visited["raft_cabin"] = true
	repaired_world.data.chronicles.hou_chao_yuan = {"step": 2, "day": 1, "choices": [0], "style": ""}
	_place_near_npc(repaired_world, "host", "he_mu")
	repaired_world.action("host", "town_chronicle_reply", {"id": "he_mu", "arc": "hou_chao_yuan", "step": 2, "reply": 0})
	_check(int(LongStories.record(repaired_world.data).step) == 3, "already-repaired house and raft-cabin He Mu advance without re-paying wood")

	# Step 3 -> 4 at Qiao Xin (requires 2 fiber, then waits 1 overnight)
	_place_near_npc(world, "host", "qiao_xin")
	Inventory.add(world.data.players.host.bag, "fiber", 2)
	world.action("host", "town_chronicle_reply", {"id": "qiao_xin", "arc": "hou_chao_yuan", "step": 3, "reply": 1})
	_check(int(LongStories.record(world.data).step) == 4 and LongStories.waiting_mail(world.data), "mailing letter advances to step 4 and waits for overnight")
	var same_day := world.snapshot()
	world.action("host", "town_chronicle_reply", {"id": "qiao_xin", "arc": "hou_chao_yuan", "step": 4, "reply": 1})
	_check(world.snapshot() == same_day, "cannot open reply letter before overnight")

	# Advance 1 day -> test full-bag protection -> clear slot -> complete step 4 -> 5!
	world.data.day += 1
	_check(not LongStories.waiting_mail(world.data), "next day unlocks Cen Po's reply letter")
	for i in Inventory.BAG_SIZE:
		world.data.players.host.bag[i] = {"item": "stone", "count": Inventory.STACK_LIMIT}
	var full_bag_snap := world.snapshot()
	world.action("host", "town_chronicle_reply", {"id": "qiao_xin", "arc": "hou_chao_yuan", "step": 4, "reply": 1})
	_check(world.snapshot() == full_bag_snap, "full bag preserves step 4 reward atomically")

	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	world.action("host", "town_chronicle_reply", {"id": "qiao_xin", "arc": "hou_chao_yuan", "step": 4, "reply": 1})
	var final_rec := LongStories.record(world.data)
	_check(int(final_rec.step) == 5 and final_rec.style == "inn", "completing step 4 sets step 5 and chosen inn style")
	_check(int(world.data.money) == 35 and Inventory.count(world.data.players.host.bag, "meal") == 2, "completing chronicle awards 35 coins and 2 harbor meals once")

	# Gate plaque style can be freely switched afterward
	world.data.players.host.area = "island"
	world.data.players.host.x = IslandMap.YARD_GATE.x
	world.data.players.host.y = IslandMap.YARD_GATE.y
	world.action("host", "yard_style")
	_check(LongStories.record(world.data).style == "farm", "yard_style switches plaque from inn to farm")
	_check(not ResidentDialogue.chronicle_line(world.data, "xu_an").is_empty(), "daily dialogue reflects completed Hou Chao Yuan")

	# Strict JSON restore & v16 -> v17 lossless migration
	var roundtrip := WorldState.new()
	_check(roundtrip.restore(JSON.parse_string(JSON.stringify(world.snapshot()))) and roundtrip.data.chronicles == world.data.chronicles, "v17 chronicles survive JSON round-trip")
	var bad := world.snapshot()
	bad.chronicles.hou_chao_yuan.style = "castle"
	_check(not WorldState.new().restore(bad), "invalid chronicle style rejected by strict restore")
	var v16_copy := world.snapshot()
	v16_copy.version = 16
	v16_copy.erase("chronicles")
	v16_copy.stories.host["lu_zhou"] = {"step": 2, "day": 1, "choices": [0, 1]}
	var migrated := WorldState.new()
	_check(migrated.restore(JSON.parse_string(JSON.stringify(v16_copy))) and int(migrated.data.version) == 17 and migrated.data.stories == v16_copy.stories and int(LongStories.record(migrated.data).step) == 0, "v16 save migrates cleanly to v17 while preserving personal 3-step stories")

	print("CHRONICLE CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

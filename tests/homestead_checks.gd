extends SceneTree
const World = preload("res://scripts/world_state.gd")
const Map = preload("res://scripts/island_map.gd")
const Town = preload("res://scripts/island_town.gd")
const Farm = preload("res://scripts/farming.gd")
const Inv = preload("res://scripts/inventory.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run()
	print("HOMESTEAD CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func _at_mayor(world, slot: String) -> void:
	world.join(slot, slot)
	world.data.minute = 720.0
	var at: Vector2 = Town.position("xu_an", 720)
	preload("res://scripts/rooms.gd")._arrive(world.data,world.data.players[slot],Town.location("xu_an",720).room,at)
	world.data.players[slot].x = at.x
	world.data.players[slot].y = at.y

func _run() -> void:
	var world = World.new()
	_at_mayor(world, "host")
	var host: Dictionary = world.data.players.host
	check(Map.YARD_BOUNDS.size == Vector2(1536, 1152), "48 by 36 yard exterior")
	check(Map.TOWN_BOUNDS.size.x > 2400 and Map.TOWN_BOUNDS.size.y > 2300, "walkable town district expanded")
	check(world.data.island.plots.is_empty(), "new game gives no cultivated land")
	var original: Dictionary = world.snapshot()
	world.action("host", "town_talk", {"id": "xu_an"})
	original.journal=world.data.journal.duplicate(true)
	check(world.snapshot() == original and world.data.journal.host.friendship.xu_an==2, "talk adds daily friendship without accepting lease or granting items")
	world.action("host", "town_claim", {"id": "xu_an"})
	check(not world.data.island.homestead.claimed.host, "gifts require lease")
	host.x += 100
	world.action("host", "town_rent", {"id": "xu_an"})
	check(not world.data.island.homestead.rented, "distant lease rejected")
	_at_mayor(world, "host")
	world.action("host", "town_rent", {"id": "lin_sui"})
	check(not world.data.island.homestead.rented, "wrong resident cannot rent")
	world.action("host", "town_rent", {"id": "xu_an"})
	check(world.data.island.homestead.rented and world.data.money == 0, "lease without fees or clearing quota")
	check(world.data.island.plots.is_empty() and world.data.island.depleted.is_empty(), "lease does not pre-clear or pre-till")
	for index in Inv.BAG_SIZE:
		host.bag[index] = {"item": "wood", "count": 20}
	var before: Array = host.bag.duplicate(true)
	world.action("host", "town_claim", {"id": "xu_an"})
	check(host.bag == before and not world.data.island.homestead.claimed.host, "full bag retains complete unclaimed gift")
	host.bag[0] = {}
	host.bag[1] = {}
	before = host.bag.duplicate(true)
	world.action("host", "town_claim", {"id": "xu_an"})
	check(host.bag == before and not world.data.island.homestead.claimed.host, "two available slots cannot partially settle a three-item gift")
	host.bag = Inv.empty_slots(Inv.BAG_SIZE)
	world.action("host", "town_claim", {"id": "xu_an"})
	check(Inv.count(host.bag, "seed") == 6 and Inv.count(host.bag, "hoe") == 1 and Inv.count(host.bag, "watering_can") == 1, "seasonal seeds and two tools delivered")
	check(Inv.count(host.bag, "axe") + Inv.count(host.bag, "pickaxe") + Inv.count(host.bag, "scythe") == 0, "other tools remain self-crafted")
	before = host.bag.duplicate(true)
	world.action("host", "town_claim", {"id": "xu_an"})
	check(before == host.bag, "repeated claim does not duplicate items")
	_at_mayor(world, "guest")
	world.data.day = 29
	world.action("guest", "town_claim", {"id": "xu_an"})
	check(Inv.count(world.data.players.guest.bag, "summer_seed") == 6, "late joiner gets current season independently")
	world.leave("guest")
	_at_mayor(world, "guest")
	world.action("guest", "town_claim", {"id": "xu_an"})
	check(Inv.count(world.data.players.guest.bag, "summer_seed") == 6, "rejoin cannot claim twice")
	var tiles := 0
	for y in range(38, 74):
		for x in range(60, 108):
			if Map.tillable(Vector2(x + 0.5, y + 0.5) * 32):
				tiles += 1
	check(tiles > 1300, "large usable yard beyond paths and pond")
	check(Map.walkable(Map.YARD_GATE), "yard entrance is accessible")
	var route := [Vector2(1344, 784), Vector2(1792, 784), Map.LANDMARKS.townhall.door, Vector2(1792, 784), Vector2(1792, 1792), Map.YARD_GATE + Vector2(80, 0)]
	var connected := true
	for index in range(1, route.size()):
		var steps := ceili(route[index - 1].distance_to(route[index]) / 8)
		for step in range(steps + 1):
			connected = connected and Map.walkable(route[index - 1].lerp(route[index], float(step) / steps))
	check(connected, "town hall and yard gate share an actually walkable road")
	var yard_nodes := 0
	for node: Dictionary in Map.nodes_near(Map.YARD_BOUNDS.get_center()).values():
		if Map.YARD_BOUNDS.has_point(Vector2(node.x, node.y)):
			yard_nodes += 1
	check(yard_nodes >= 60, "yard contains untended resources, not a prepared field")
	# A normal save fixture must have actually reached the island coast.
	world.data.chart.visited = true
	var coast: Vector2 = preload("res://scripts/archipelago.gd").island_position(world.data.chart)
	world.data.navigation.x = coast.x
	world.data.navigation.y = coast.y
	world.data.navigation.anchored = true
	var restored = World.new()
	check(restored.restore(world.snapshot()), "new save restores")
	check(restored.data.island.homestead == world.data.island.homestead, "lease and both claims persist")
	var malformed: Dictionary = world.snapshot()
	malformed.island.homestead.claimed.host = 1
	check(not restored.restore(malformed), "malformed claim flags reject atomically")
	var old: Dictionary = world.snapshot()
	old.version = 10
	for v14_key in ["rooms","gardens","restaurant","wardrobe","housing","journal","stories","chronicles"]:old.erase(v14_key)
	for v14_player in old.players.values():
		v14_player.erase("room");v14_player.area="island";v14_player.x=Map.LANDMARKS.townhall.door.x;v14_player.y=Map.LANDMARKS.townhall.door.y
	old.erase("threats")
	for player in old.players.values(): player.erase("dive_status")
	old.island.erase("homestead")
	old.island.plots["60,22"] = {"crop": "seed", "growth": 3, "watered": true, "covered": true, "dead": false}
	check(restored.restore(old), "v10 farm under added town hall safely migrates")
	check(restored.data.island.plots.size() == 1 and restored.data.island.plots.values()[0] == old.island.plots.values()[0], "migration preserves crop age water and shelter")
	var legacy_player: Dictionary = old.duplicate(true)
	legacy_player.players.host.x = 1936.0
	legacy_player.players.host.y = 720.0
	check(restored.restore(legacy_player) and Vector2(restored.data.players.host.x, restored.data.players.host.y) == Vector2(1936,720), "v10 player retains coordinates now that the town hall has moved away")
	check(not restored.data.island.homestead.rented and not restored.data.island.homestead.claimed.host, "old worlds start unclaimed")

	var previous: Dictionary = world.snapshot()
	previous.version=11
	for v14_key in ["rooms","gardens","restaurant","wardrobe","housing","journal","stories","chronicles"]:previous.erase(v14_key)
	for v14_player in previous.players.values():v14_player.erase("room");v14_player.area="island"
	previous.erase("threats")
	for player in previous.players.values(): player.erase("dive_status")
	previous.players.guest.area = "deck"
	previous.players.guest.x = 450.0
	previous.players.guest.y = 270.0
	var changed := Vector2.ZERO
	for y in range(480, 824, 32):
		for x in range(720, 1200, 32):
			var candidate := Vector2(x+16, y+16)
			if Map.v11_terrain(candidate)=="grass" and Map.terrain(candidate)=="building": changed=candidate
	check(changed!=Vector2.ZERO, "scene migration fixture was genuinely free grass in v11")
	previous.players.host.x = changed.x
	previous.players.host.y = changed.y
	previous.island.plots.clear()
	previous.island.plots[preload("res://scripts/farming.gd").plot_key(changed)] = {"crop":"seed","growth":3,"watered":true,"covered":true,"dead":false}
	check(restored.restore(previous), "v11 scene layout restores the player and occupied farmland")
	check(Map.can_stand(Vector2(restored.data.players.host.x,restored.data.players.host.y)), "player is recovered to nearby walkable ground")
	check(restored.data.island.plots.size()==1 and restored.data.island.plots.values()[0]==previous.island.plots.values()[0], "v11 relocation preserves every crop property")
	check(not restored.migration_notice.is_empty(), "scene migration is explained before playing")
	var migrated: Dictionary=restored.snapshot()
	check(restored.restore(migrated) and restored.snapshot().island.plots==migrated.island.plots, "a second load does not move the relocated crop again")

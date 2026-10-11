extends SceneTree
## Explicit historical map/crop fixtures. This tests restore, not normal progression.
## Godot is run by the root validator, never by the authoring subagent.
const WorldState = preload("res://scripts/world_state.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Map = preload("res://scripts/island_map.gd")
const Island = preload("res://scripts/island_state.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
const Farming = preload("res://scripts/farming.gd")
var checks := 0
var failures := 0
var old_save: Dictionary = {}
var conflict_keys: Array[String] = []
var stable_keys: Array[String] = []
var blocked_node := ""
var clear_node := ""


func _initialize() -> void:
	if not _fixture():
		quit(1)
		return
	_test_conflicts_and_roundtrip()
	_test_inflight_old_activity()
	_test_unchanged_notice()
	_test_rejections()
	print("ISLAND MIGRATION 10 CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _fixture() -> bool:
	var world = WorldState.new()
	world.join("host", "旧档船长")
	world.join("guest", "旧档伙伴")
	var destination: Vector2 = Archipelago.island_position(world.data.chart)
	world.data.navigation.x = destination.x
	world.data.navigation.y = destination.y
	world.data.navigation.anchored = true
	world.data.chart.visited = true
	world.data.money = 71
	Inventory.add(world.data.players.host.bag, "fish", 4)
	Inventory.add(world.data.players.host.bag, "fins", 1)
	Inventory.add(world.data.players.guest.bag, "watering_can", 1)
	Inventory.add(world.data.players.guest.bag, "winter_seed", 3)
	world.data.players.host.can_water = 13
	world.data.players.guest.can_water = 5
	old_save = world.snapshot()
	old_save.version = 9
	var buildings := _conflicts(Rect2(Map.LANDMARKS.market.bounds), "building", 2)
	var lake := _conflicts(Rect2(Vector2(Map.WATER_FEATURES.mirror_lake.center) - Vector2.ONE * 128, Vector2.ONE * 256), "water", 1)
	var road := _conflicts(Map.TOWN_BOUNDS, "path", 1)
	if not _check(buildings.size() == 2 and lake.size() == 1 and road.size() == 1, "actual v9 grass cells are now covered by building, lake and town road geometry"):
		return false
	conflict_keys.assign([buildings[0], buildings[1], lake[0], road[0]])
	var crops := [
		_plot("seed", 1, true, false),
		_plot("summer_seed", 5, false, true),
		_plot("autumn_seed", 9, true, true),
		_plot("winter_seed", 6, false, true),
	]
	for index in conflict_keys.size():
		old_save.island.plots[conflict_keys[index]] = crops[index]
	stable_keys.assign([Farming.plot_key(Vector2(496, 336)), Farming.plot_key(Vector2(560, 336))])
	old_save.island.plots[stable_keys[0]] = _plot("seed", 4, true, false)
	old_save.island.plots[stable_keys[1]] = _plot("", 0, false, true)
	var old_position := Farming.plot_center(buildings[0])
	old_save.players.host.area = "island"
	old_save.players.host.x = old_position.x
	old_save.players.host.y = old_position.y
	old_save.players.guest.area = "island"
	old_save.players.guest.x = 560.0
	old_save.players.guest.y = 336.0
	# Retain a real old id whose new terrain is blocked; do not forge node coordinates.
	for landmark: Dictionary in Map.LANDMARKS.values():
		blocked_node = _blocked_old_node(Map.nodes_near(landmark.door), "building")
		if not blocked_node.is_empty():
			break
	if blocked_node.is_empty():
		blocked_node = _blocked_old_node(Map.nodes_near(Map.WATER_FEATURES.mirror_lake.center), "water")
	if not _check(not blocked_node.is_empty(), "a real historical n_* node survives lookup under changed impassable geography"):
		return false
	old_save.island.depleted[blocked_node] = 6
	old_save.island.depleted["palm_0"] = 4
	for id: String in Map.nodes_near(Vector2(2400, 800)):
		if id.begins_with("clear_"):
			clear_node = id
			break
	if not _check(not clear_node.is_empty(), "a real v10 wilderness-clearing id is available for the new-save fixture"):
		return false
	# Persistence reads JSON string keys, not StringName keys created by dot insertion.
	old_save = _canonical(old_save)
	print("MIGRATION FIXTURE old_node=", blocked_node, " terrain=", Map.terrain(_node_point(blocked_node)), " clear_node=", clear_node)
	return true


func _conflicts(bounds: Rect2, terrain: String, count_value: int) -> Array[String]:
	var result: Array[String] = []
	for ty in range(floori(bounds.position.y / 32), ceili(bounds.end.y / 32)):
		for tx in range(floori(bounds.position.x / 32), ceili(bounds.end.x / 32)):
			var point := Vector2(tx * 32 + 16, ty * 32 + 16)
			if Map.legacy_tillable(point) and Map.terrain(point) == terrain:
				result.append(Farming.plot_key(point))
				if result.size() == count_value:
					return result
	return result


func _blocked_old_node(nodes: Dictionary, terrain: String) -> String:
	for id: String in nodes:
		if id.begins_with("n_") and Map.terrain(_node_point(id)) == terrain:
			return id
	return ""


func _node_point(id: String) -> Vector2:
	var node: Dictionary = Map.node(id)
	return Vector2(float(node.x), float(node.y))


func _plot(crop: String, growth: int, watered: bool, covered: bool) -> Dictionary:
	return {"crop": crop, "growth": growth, "watered": watered, "covered": covered, "dead": false}


func _test_conflicts_and_roundtrip() -> void:
	var source := old_save.duplicate(true)
	var before := source.duplicate(true)
	var restored = WorldState.new()
	if not _check(restored.restore(source), "valid v9 crop and landed-player fixture migrates to v10"):
		return
	_check(source == before, "migration does not mutate its original saved dictionary or nested crop records")
	_check(int(restored.data.version) == 10 and not restored.migration_notice.is_empty(), "successful conflicting migration upgrades version and explicitly reports the moved plots")
	_check(restored.data.island.plots.size() == source.island.plots.size(), "migration neither loses nor duplicates any crop cell")
	var reserved: Dictionary = {}
	for key: String in stable_keys:
		_check(_canonical(restored.data.island.plots.get(key)) == _canonical(source.island.plots[key]), "unaffected crop or empty covered soil stays at its original key: " + key)
		reserved[key] = true
	var sorted: Array[String] = conflict_keys.duplicate()
	sorted.sort()
	for old_key: String in sorted:
		var found: Array[String] = []
		for new_key: String in restored.data.island.plots:
			if _canonical(restored.data.island.plots[new_key]) == _canonical(source.island.plots[old_key]):
				found.append(new_key)
		if not _check(found.size() == 1, "every displaced crop retains its complete growth, water, cover and maturity state exactly once: " + old_key):
			continue
		var key: String = found[0]
		_check(key != old_key and not reserved.has(key) and Map.tillable(Farming.plot_center(key)), "displaced crop lands on distinct valid new ground: " + old_key)
		_check(_nearest_free_ring(old_key, key, reserved), "displaced crop uses the closest available grid ring while respecting existing plots: " + old_key)
		reserved[key] = true
	_check(restored.data.players.host.area == "island" and Vector2(float(restored.data.players.host.x), float(restored.data.players.host.y)) == Island.DOCK, "a landed player at a valid old point inside a new building resumes safely at the dock")
	_check(restored.data.players.guest.area == "island" and float(restored.data.players.guest.x) == 560.0 and float(restored.data.players.guest.y) == 336.0, "a landed partner on unchanged ground keeps its island coordinates")
	for slot: String in ["host", "guest"]:
		_check(_canonical([restored.data.players[slot].bag, restored.data.players[slot].can_water]) == _canonical([source.players[slot].bag, source.players[slot].can_water]), "migration preserves ordered personal bag and can water: " + slot)
	_check(_canonical([restored.data.money, restored.data.structures, restored.data.chests, restored.data.deck_tiles]) == _canonical([source.money, source.structures, source.chests, source.deck_tiles]), "migration preserves money, raft layout, facilities and chest contents")
	_check(_canonical(restored.data.island.depleted) == _canonical(source.island.depleted) and not Map.node(blocked_node).is_empty(), "old depleted n_* records remain intact and resolvable after terrain changes")
	_check(not Island.active(restored.data.island, blocked_node, 99), "a historical resource covered by new water or a building cannot be gathered even after its regrow date")
	_check(Island.active(restored.data.island, clear_node, 1), "new wilderness clearing nodes remain real collectable resources")
	restored.data.island.depleted[clear_node] = 7
	var saved: Dictionary = restored.snapshot()
	var encoded: Variant = JSON.parse_string(JSON.stringify(saved, "", true, true))
	var resumed = WorldState.new()
	if not _check(encoded is Dictionary and resumed.restore(encoded), "migrated v10 state including new clear_* depletion restores from actual JSON numeric types"):
		return
	_check(_canonical(resumed.snapshot()) == _canonical(saved), "a second save/restore keeps exact v10 world state without another relocation")
	_check(resumed.migration_notice.is_empty(), "ordinary v10 continuation produces no historical migration notice")
	_check(int(resumed.data.island.depleted.get(clear_node, 0)) == 7 and not Island.active(resumed.data.island, clear_node, 1), "new clearing-resource progress persists without an early regrowth")


func _nearest_free_ring(old_key: String, new_key: String, reserved: Dictionary) -> bool:
	# The migration contract is nearest Chebyshev grid ring, with deterministic ties.
	var origin := Farming.plot_center(old_key)
	var offset := (Farming.plot_center(new_key) - origin) / Map.TILE
	var distance := maxi(absi(int(offset.x)), absi(int(offset.y)))
	for y in range(-distance + 1, distance):
		for x in range(-distance + 1, distance):
			var point := origin + Vector2(x, y) * Map.TILE
			var key := Farming.plot_key(point)
			if not key.is_empty() and not reserved.has(key) and Map.tillable(point):
				return false
	return distance > 0


func _test_inflight_old_activity() -> void:
	# This branch existed in v9. Its nearby former grass is now the bathhouse wall.
	var node: Dictionary = Map.node("n_1_0_0")
	var bounds: Rect2 = Map.LANDMARKS.bathhouse.bounds
	var start := Vector2.ZERO
	for y in range(int(bounds.position.y), int(bounds.end.y), 8):
		for x in range(int(bounds.position.x), int(bounds.end.x), 8):
			var at := Vector2(x + 4, y + 4)
			if Map.legacy_walkable(at) and not Map.walkable(at) and at.distance_to(_node_point(node.id)) <= 64:
				start = at
				break
		if start != Vector2.ZERO:
			break
	if not _check(start != Vector2.ZERO, "a real v9 gathering position beside its target is now inside a building"):
		return
	var source := old_save.duplicate(true)
	source.players.host.x = start.x
	source.players.host.y = start.y
	source.players.host.activity = {"kind": "island_gather", "id": str(node.id), "duration": float(node.duration), "remaining": float(node.duration) * 0.5, "start_x": start.x, "start_y": start.y}
	Inventory.add(source.players.host.bag, str(node.tool), 1)
	source = _canonical(source)
	var before := source.duplicate(true)
	var restored = WorldState.new()
	if not _check(restored.restore(source), "v9 in-progress island gathering validates its old-map start coordinates"):
		return
	_check(restored.data.players.host.activity.is_empty() and Vector2(float(restored.data.players.host.x), float(restored.data.players.host.y)) == Island.DOCK, "migration cancels old in-progress gathering and relocates the blocked actor to dock")
	_check(_canonical([restored.data.players.host.bag, restored.data.players.host.stamina]) == _canonical([source.players.host.bag, source.players.host.stamina]) and not restored.data.island.depleted.has(node.id), "cancelled historical gathering grants no resource and spends no stamina or node")
	_check(source == before and not source.players.host.activity.is_empty(), "in-flight migration leaves the original JSON fixture and its activity untouched")


func _test_unchanged_notice() -> void:
	var source := old_save.duplicate(true)
	source.island.plots = {}
	# Reverse insertion order deliberately differs from migration's sorted iteration.
	for index in range(stable_keys.size() - 1, -1, -1):
		var key: String = stable_keys[index]
		source.island.plots[key] = old_save.island.plots[key].duplicate(true)
	source.players.host.x = Island.DOCK.x
	source.players.host.y = Island.DOCK.y
	var world = WorldState.new()
	_check(world.restore(source), "v9 file with only unchanged farmland remains loadable")
	_check(_canonical(world.data.island.plots) == _canonical(source.island.plots) and world.migration_notice.is_empty(), "dictionary insertion-order normalization never falsely reports plot movement")
	var empty := source.duplicate(true)
	empty.island.plots = {}
	_check(world.restore(empty) and world.migration_notice.is_empty(), "v9 file with no crops upgrades silently without inventing migration work")


func _test_rejections() -> void:
	var cases: Array = []
	var bad := old_save.duplicate(true)
	bad.island.plots[Farming.plot_key(Vector2(720, 430))] = _plot("seed", 0, false, false)
	cases.append([bad, "old freshwater cannot be laundered into a valid relocated crop"])
	bad = old_save.duplicate(true)
	bad.island.plots[Farming.plot_key(Island.DOCK)] = _plot("seed", 0, false, false)
	cases.append([bad, "old paved landing ground is still forbidden farmland"])
	for malformed: Variant in [1.5, -1, INF, "2", true, 99]:
		bad = old_save.duplicate(true)
		bad.island.plots[conflict_keys[0]].growth = malformed
		cases.append([bad, "invalid historical growth is rejected: " + str(malformed)])
	bad = old_save.duplicate(true)
	bad.island.plots[conflict_keys[0]].watered = 1
	cases.append([bad, "integer water flags cannot bypass strict old crop validation"])
	bad = old_save.duplicate(true)
	bad.island.plots["015,10"] = _plot("seed", 0, false, false)
	cases.append([bad, "noncanonical old plot keys remain rejected"])
	bad = old_save.duplicate(true)
	bad.island.depleted[blocked_node] = 1.5
	cases.append([bad, "historical node regrowth dates remain integral"])
	bad = old_save.duplicate(true)
	bad.island.depleted["clear_2_0_999"] = 5
	cases.append([bad, "unknown clearing-resource ids remain rejected"])
	bad = old_save.duplicate(true)
	bad.players.host.can_water = 21
	cases.append([bad, "later invalid player data cannot commit an earlier computed plot migration"])
	bad = old_save.duplicate(true)
	bad.players.host.x = 720.0
	bad.players.host.y = 430.0
	cases.append([bad, "invalid old player water positions cannot use the safe-dock migration shortcut"])
	bad = old_save.duplicate(true)
	bad.version = 10
	cases.append([bad, "v10 cannot reuse the v9 exception to admit farmland inside current water or buildings"])
	for entry: Array in cases:
		_rejected(entry[0], str(entry[1]))


func _rejected(source: Dictionary, label: String) -> void:
	var world = WorldState.new()
	world.data.money = 932
	var before: Dictionary = world.snapshot()
	var untouched: Dictionary = source.duplicate(true)
	_check(not world.restore(source), label)
	_check(world.snapshot() == before, "rejected file leaves the existing live world untouched: " + label)
	_check(source == untouched, "rejected file leaves its input dictionary untouched: " + label)
	_check(world.migration_notice.is_empty(), "rejected file never announces a successful relocation: " + label)


func _canonical(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
	return condition

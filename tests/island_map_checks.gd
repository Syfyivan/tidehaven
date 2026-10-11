extends SceneTree
## Read-only geometry, deterministic resource definitions and fixed page transforms.
## godot --headless --path <project> --script res://tests/island_map_checks.gd
const Map = preload("res://scripts/island_map.gd")
const WorldView = preload("res://scripts/world_view.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_check(Map.TILE == 32 and Map.PAGE == Vector2(896, 544), "tiles and view pages retain the agreed pixel dimensions")
	_check(Map.PAGES == Vector2i(16, 12) and Map.SIZE == Vector2(14336, 6528), "island contains exactly sixteen by twelve pages")
	_check(Map.SIZE / Map.TILE == Vector2(448, 204), "reported tile dimensions match real island coordinates")
	_check(Map.page_origin(Vector2.ZERO) == Vector2.ZERO and Map.page_origin(Vector2(895.99, 543.99)) == Vector2.ZERO, "page zero includes points just before its right and bottom boundaries")
	_check(Map.page_origin(Vector2(896, 544)) == Map.PAGE, "crossing both boundaries selects the next page without rounding early")
	_check(Map.page_origin(Map.SIZE) == Map.SIZE - Map.PAGE and Map.page_origin(Vector2(-8, -12)) == Vector2.ZERO, "page origins clamp outside finite coordinates")
	_check(Map.page_origin(Vector2(INF, 0)) == Vector2.ZERO and not Map.walkable(Vector2(NAN, 0)), "nonfinite coordinates cannot enter map geometry")
	_check(not Map.walkable(Vector2(-1, 280)) and not Map.walkable(Map.SIZE), "outside edges cannot be walked onto")
	_check(Map.walkable(Map.DOCK) and Map.walkable(Vector2(305, 385)), "legacy dock and new camp are reachable ground")
	_check(Map.tillable(Vector2(496, 336)), "the original farm cell remains tillable for migrated crops")
	_check(Map.tillable(Vector2(560, 336)), "the second normal-playthrough crop cell remains tillable")
	_check(Map.water_near(Vector2(640, 430)) and Map.walkable(Vector2(640, 430)), "the first pond has a usable fresh-water bank")
	_check(not Map.walkable(Vector2(720, 430)) and not Map.tillable(Vector2(720, 430)), "freshwater itself is not walkable or tillable")
	_check(not Map.water_near(Vector2(150, 380)), "sea-facing shore is not a freshwater source")
	_check(not Map.tillable(Vector2(210, 380)), "landing path cannot be tilled")
	_regions_and_paths()
	_nodes()
	_town()
	_waterways()
	_old_plot_conflicts()
	_transforms()
	print("ISLAND MAP CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _regions_and_paths() -> void:
	var regions: Dictionary = {}
	var partitioned := true
	var connected := true
	var pond_bounds := true
	for row in Map.PAGES.y:
		for column in Map.PAGES.x:
			var origin: Vector2 = Vector2(column, row) * Map.PAGE
			var center: Vector2 = origin + Map.PAGE * 0.5
			var region: Dictionary = Map.region(center)
			regions[region.id] = true
			var memberships := 0
			for candidate: Dictionary in Map.REGIONS:
				var region_bounds: Rect2 = candidate.bounds
				memberships += 1 if region_bounds.has_point(center) else 0
			partitioned = partitioned and memberships == 1 and Rect2(region.bounds).has_point(center)
			if column > 0:
				var border_x: float = origin.x
				var crossing_y: float = Map.horizontal_path_y(border_x, row)
				for offset: float in [-12.0, 0.0, 12.0]:
					connected = connected and Map.walkable(Vector2(border_x + offset, crossing_y))
			if row > 0:
				var border_y: float = origin.y
				var crossing_x: float = Map.vertical_path_x(border_y, column)
				for offset: float in [-12.0, 0.0, 12.0]:
					connected = connected and Map.walkable(Vector2(crossing_x, border_y + offset))
			var page_bounds := Rect2(origin, Map.PAGE)
			for pond: Dictionary in Map.ponds_near(center):
				if page_bounds.has_point(pond.center):
					var pond_rect := Rect2(Vector2(pond.center) - Vector2(pond.radius), Vector2(pond.radius) * 2)
					pond_bounds = pond_bounds and page_bounds.encloses(pond_rect)
	_check(regions.size() == 6 and partitioned, "all 192 page centers belong to one of six nonoverlapping regions")
	_check(connected, "every neighboring page pair has a walkable road crossing in both axes")
	_check(pond_bounds, "pond collision lookup is safe because each pond fits wholly inside its own page")
	_check(Map.region(Vector2(4500, 300)).id == "woodland" and Map.region(Vector2(9900, 3500)).id == "ruins", "region edges follow the agreed five/six/five page partition")


func _nodes() -> void:
	var unique: Dictionary = {}
	var definitions_valid := true
	var positions_valid := true
	var page_bounded := true
	var nearby_bounded := true
	var clearing_count := 0
	var clearing_kinds: Dictionary = {}
	var region_clearing_counts: Dictionary = {}
	var region_pages: Dictionary = {}
	var changed_ground := 0
	var expected_tools := {"tree": "axe", "branch": "axe", "fiber": "scythe", "stone": "pickaxe", "ore": "pickaxe", "dig_seed": "hoe", "dig_treasure": "hoe"}
	for row in Map.PAGES.y:
		for column in Map.PAGES.x:
			var page_bounds := Rect2(Vector2(column, row) * Map.PAGE, Map.PAGE)
			var nearby: Dictionary = Map.nodes_near(page_bounds.get_center())
			nearby_bounded = nearby_bounded and nearby.size() <= 297
			var area_id: String = str(Map.region(page_bounds.get_center()).id)
			region_pages[area_id] = int(region_pages.get(area_id, 0)) + 1
			var count_value := 0
			for id: String in nearby:
				var entry: Dictionary = nearby[id]
				var at := Vector2(float(entry.x), float(entry.y))
				if not page_bounds.has_point(at):
					continue
				count_value += 1
				positions_valid = positions_valid and Map.legacy_walkable(at) and not unique.has(id)
				if id.begins_with("clear_"):
					clearing_count += 1
					clearing_kinds[entry.kind] = true
					region_clearing_counts[area_id] = int(region_clearing_counts.get(area_id, 0)) + 1
					positions_valid = positions_valid and Map.tillable(at) and at == (at / Map.TILE).floor() * Map.TILE + Vector2.ONE * 16
				elif not Map.walkable(at):
					changed_ground += 1
				unique[id] = entry.duplicate(true)
				definitions_valid = definitions_valid and entry.id == id and entry.tool == expected_tools[entry.kind] and float(entry.duration) > 0 and int(entry.amount) > 0 and int(entry.regrow) >= 1 and float(entry.radius) > 0 and Map.node(id) == entry
			page_bounded = page_bounded and count_value >= 1 and count_value <= 33
	_check(nearby_bounded, "nearby resource lookup stays bounded to nine pages including wilderness clumps")
	_check(page_bounded and unique.size() < 6336, "all pages retain bounded resource density and substantial uncultivated ground")
	_check(positions_valid, "legacy coordinates remain on original ground and new clearing nodes occupy valid grass grid cells")
	_check(clearing_count > 500 and clearing_kinds.has_all(["tree", "fiber", "branch", "stone"]), "wilderness adds tool-clearable trees, weeds, branches and stones across the real island")
	_check(float(region_clearing_counts.get("woodland", 0)) / int(region_pages.woodland) > float(region_clearing_counts.get("harbor", 0)) / int(region_pages.harbor), "forest pages contain denser clearing work than harbor grassland")
	_check(changed_ground > 0, "changed geography retains blocked old node definitions for save compatibility instead of renumbering them")
	_check(definitions_valid, "every node has an actual tool, duration, yield, regrow day and reversible id lookup")
	for id: String in Map.LEGACY:
		var entry: Dictionary = Map.node(id)
		var legacy: Dictionary = Map.LEGACY[id]
		_check(entry.x == legacy.x and entry.y == legacy.y and entry.kind == legacy.kind, "legacy node remains at its original coordinate: " + id)
	_check(Map.node("palm_1").item == "fiber" and Map.node("seeds_0").item == "seed", "first-page fiber is distinct from palm leaves and the legacy seed remains spring seed")
	var preserved := {"n_1_0_0": Vector2(1443, 414), "n_1_0_1": Vector2(1129, 203), "n_1_0_2": Vector2(1347, 368), "n_1_0_3": Vector2(1255, 324)}
	for id: String in preserved:
		var entry: Dictionary = Map.node(id)
		_check(Vector2(float(entry.x), float(entry.y)) == preserved[id], "v9 second-page resource keeps its exact deterministic coordinate: " + id)
	_check(Map.walkable(preserved.n_1_0_1) and Map.node("n_1_0_1").item == "fiber", "the normal-playthrough second-page fiber remains accessible beside town")
	for invalid: String in ["", "n_16_0_0", "n_0_12_0", "n_-1_0_0", "n_1_1_999", "n_x_0_0", "n_01_1_0", "clear_16_0_0", "clear_1_1_0", "clear_0_0_0", "clear_2_0_999", "clear_02_0_0", "clear_9999999999999999999999999999999999999999_0_0"]:
		_check(Map.node(invalid).is_empty(), "invalid node id is rejected: " + invalid)
	Map._pages.clear()
	var regenerated := true
	for id: String in unique:
		regenerated = regenerated and Map.node(id) == unique[id]
	_check(regenerated, "clearing the page cache regenerates identical ids, positions and resource definitions")


func _town() -> void:
	var wanted := ["market", "clinic", "bathhouse", "carpenter", "smith", "fishery", "farmhouse", "plaza"]
	_check(Map.LANDMARKS.has_all(wanted) and Map.LANDMARKS.has("mine_entrance"), "town exposes all eight destinations and a distinct closed mine entrance")
	var nearby: Dictionary = Map.landmarks_near(Map.LANDMARKS.plaza.door)
	_check(nearby.has_all(wanted) and not nearby.has("mine_entrance"), "local landmark lookup includes town without leaking the distant mine marker")
	var region := Rect2(160, 96, 1536, 960)
	var reachable := _walk_region(Map.DOCK, region)
	_check(reachable.has(_cell(Vector2(960, 280), region)), "the original dock connects on foot to the second-page town approach")
	for id: String in wanted:
		var landmark: Dictionary = Map.LANDMARKS[id]
		var door: Vector2 = landmark.door
		_check(Map.settlement(door) and Map.walkable(door) and reachable.has(_cell(door, region)), "town door is physically reachable from the original dock: " + id)
		if id != "plaza":
			_check(Map.terrain(Rect2(landmark.bounds).get_center()) == "building" and not Map.walkable(Rect2(landmark.bounds).get_center()) and not Map.tillable(Rect2(landmark.bounds).get_center()), "building footprint blocks walking and farming: " + id)
	_check(Map.terrain(Map.LANDMARKS.plaza.door) == "path" and not Map.tillable(Map.LANDMARKS.plaza.door), "plaza is real pedestrian ground rather than pre-tilled farmland")
	var ring_valid := true
	for radius: float in [48.0, 64.0, 80.0]:
		for index in 8:
			var offset := Vector2.RIGHT.rotated(index * TAU / 8.0) * radius
			ring_valid = ring_valid and Map.walkable(Vector2(Map.LANDMARKS.plaza.door) + offset)
	_check(ring_valid, "all eight evening gathering positions remain on accessible plaza ground")
	_check(not bool(Map.LANDMARKS.mine_entrance.open) and Map.walkable(Map.LANDMARKS.mine_entrance.door) and not Map.walkable(Rect2(Map.LANDMARKS.mine_entrance.bounds).get_center()), "mine has an accessible marked entrance but its sealed interior is not playable")
	_check(Map.landmarks_near(Map.LANDMARKS.mine_entrance.door).has("mine_entrance") and not Map.settlement(Map.LANDMARKS.mine_entrance.door), "mine belongs to the distant foothills rather than the harbor settlement")


func _walk_region(start: Vector2, bounds: Rect2) -> Dictionary:
	# Independent 16px flood fill follows actual terrain, not the declared road graph.
	var visited: Dictionary = {}
	var first := _cell(start, bounds)
	var pending: Array[Vector2i] = [first]
	visited[first] = true
	var index := 0
	while index < pending.size():
		var current: Vector2i = pending[index]
		index += 1
		var point := bounds.position + (Vector2(current) + Vector2.ONE * 0.5) * 16
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := current + direction
			var at := bounds.position + (Vector2(next) + Vector2.ONE * 0.5) * 16
			if visited.has(next) or not bounds.has_point(at) or not Map.walkable(at) or not Map.walkable((point + at) * 0.5):
				continue
			visited[next] = true
			pending.append(next)
	return visited


func _cell(point: Vector2, bounds: Rect2) -> Vector2i:
	return Vector2i(((point - bounds.position) / 16).floor())


func _waterways() -> void:
	var lake: Dictionary = Map.WATER_FEATURES.mirror_lake
	_check(Vector2(lake.radius).x >= 600 and Vector2(lake.radius).y >= 350 and not Map.walkable(lake.center), "forest lake occupies a real broad impassable body rather than a map-only icon")
	var lake_shore := Vector2(lake.center) + Vector2(float(lake.radius.x) + 24, 0)
	_check(Map.walkable(lake_shore) and Map.water_near(lake_shore), "large lake has an accessible freshwater shore")
	var continuous := true
	var river_water := 0
	var bridge_water := 0
	for id: String in ["reed_river", "stone_stream"]:
		var feature: Dictionary = Map.WATER_FEATURES[id]
		var points: Array = feature.points
		for segment in range(1, points.size()):
			var from: Vector2 = points[segment - 1]
			var to: Vector2 = points[segment]
			var steps := maxi(1, ceili(from.distance_to(to) / 16))
			for step in range(steps + 1):
				var at := from.lerp(to, float(step) / steps)
				continuous = continuous and Map._feature_contains(at, feature)
				var ground: String = Map.terrain(at)
				if ground == "water":
					river_water += 1
					continuous = continuous and not Map.walkable(at)
				elif ground == "bridge":
					bridge_water += 1
					continuous = continuous and Map.walkable(at) and not Map.tillable(at)
				else:
					continuous = false
	_check(continuous and river_water > 100 and bridge_water > 0, "river and stream remain continuous water across page edges, with walkable crossings only marked as bridges")
	_check(Map._feature_contains(Map.WATER_FEATURES.reed_river.points[0], lake) and Map._feature_contains(Map.WATER_FEATURES.stone_stream.points.back(), lake), "mountain stream and downstream river physically connect into the forest lake")
	var bridge_point := Vector2.ZERO
	for y in range(4300, 4850, 8):
		var at := Vector2(Map.vertical_path_x(float(y), 3), y)
		if Map.terrain(at) == "bridge":
			bridge_point = at
			break
	_check(bridge_point != Vector2.ZERO, "an actual timber crossing spans the river on the westland road")
	if bridge_point != Vector2.ZERO:
		var crossing := true
		for dy in range(-200, 201, 8):
			var y: float = bridge_point.y + dy
			crossing = crossing and Map.walkable(Vector2(Map.vertical_path_x(y, 3), y))
		_check(crossing, "the bridge provides a continuous walkable route between both riverbanks")
		var bridges: Array = Map.bridges_near(bridge_point)
		var rendered := not bridges.is_empty()
		for bridge: Dictionary in bridges:
			var bounds: Rect2 = bridge.bounds
			rendered = rendered and bridge.has("id") and bounds.has_area() and Map.terrain(bounds.get_center()) == "bridge"
		_check(rendered, "nearby bridge descriptors correspond to real collidable bridge deck")
	var kinds: Dictionary = {}
	for at: Vector2 in [Vector2(lake.center), bridge_point, Vector2(10900, 1280), Vector2(640, 430)]:
		for feature: Dictionary in Map.water_features_near(at):
			kinds[feature.kind] = true
	_check(kinds.has_all(["lake", "river", "stream", "pond"]), "rendering and shore actions can query lakes, continuous waterways and retained local ponds")


func _old_plot_conflicts() -> void:
	var conflict := Vector2.ZERO
	var lake_bounds: Rect2 = Map.WATER_FEATURES.mirror_lake.bounds
	for y in range(int(lake_bounds.position.y), int(lake_bounds.end.y), 32):
		for x in range(int(lake_bounds.position.x), int(lake_bounds.end.x), 32):
			var at := Vector2(floori(float(x) / 32) * 32 + 16, floori(float(y) / 32) * 32 + 16)
			if Map.legacy_tillable(at) and not Map.tillable(at):
				conflict = at
				break
		if conflict != Vector2.ZERO:
			break
	_check(conflict != Vector2.ZERO and Map.legacy_walkable(conflict), "legacy terrain exposes newly conflicting crop ground so migration can preserve and relocate old plots explicitly")


func _transforms() -> void:
	var view = WorldView.new()
	view.state = {"elapsed": 23.0, "players": {"host": {"area": "island", "x": 210.0, "y": 380.0}}}
	view.local_slot = "host"
	var roundtrip := true
	var fixed := true
	var other_areas := true
	for page: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(5, 6), Vector2i(15, 11)]:
		var origin: Vector2 = Vector2(page) * Map.PAGE
		view.state.players.host.x = origin.x + 310
		view.state.players.host.y = origin.y + 280
		for local: Vector2 in [Vector2.ZERO, Vector2(210, 380), Vector2(895, 543)]:
			var world: Vector2 = origin + local
			var screen: Vector2 = view.world_to_screen(world, "island")
			roundtrip = roundtrip and screen == local and view.screen_to_world(screen, "island") == world
			other_areas = other_areas and view.world_to_screen(world, "water") == world and view.screen_to_world(world, "drift") == world
		var before: Vector2 = view.world_to_screen(origin + Vector2(500, 320), "island")
		view.state.players.host.x += 42
		view.state.players.host.y += 38
		view.state.elapsed += 10.0
		fixed = fixed and before == view.world_to_screen(origin + Vector2(500, 320), "island")
	_check(roundtrip, "first, inland and far-corner island pages invert mouse coordinates exactly")
	_check(fixed, "walking inside a page and elapsed wave time never pan or bob the island camera")
	_check(other_areas, "island paging does not transform water or drift coordinates")
	view.free()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

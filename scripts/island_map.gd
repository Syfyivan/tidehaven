extends RefCounted
## Deterministic island geometry and read-only node definitions, never save data.
const TILE := 32
const PAGE := Vector2(896, 544)
const PAGES := Vector2i(16, 12)
const SIZE := Vector2(14336, 6528)
const DOCK := Vector2(210, 380)
const OLD_TOWN_BOUNDS := Rect2(952, 88, 728, 960)
const V11_TOWN_BOUNDS := Rect2(952, 88, 2568, 2408)
const TOWN_BOUNDS := Rect2(640, 88, 2880, 2408)
const YARD_BOUNDS := Rect2(1920, 1216, 1536, 1152)
const YARD_GATE := Vector2(1920, 1792)
const NEW_BUILDINGS := ["townhall", "east_house", "orchard_house"]
const V11_BOUNDS := {
	"townhall":Rect2(1856, 624, 256, 144),
	"east_house":Rect2(2368, 848, 192, 144),
	"orchard_house":Rect2(2912, 880, 192, 144),
	"market":Rect2(992, 352, 192, 112),
	"clinic":Rect2(1472, 128, 160, 112),
	"bathhouse":Rect2(1432, 464, 192, 96),
	"carpenter":Rect2(1024, 624, 176, 128),
	"smith":Rect2(1472, 624, 176, 128),
	"fishery":Rect2(976, 112, 128, 96),
	"farmhouse":Rect2(1024, 896, 160, 112),
	"plaza":Rect2(1248, 456, 176, 176),
	"mine_entrance":Rect2(11584, 1072, 160, 96),
	"mirror_lake":Rect2(6788, 1932, 1400, 840),
	"reed_river":Rect2(59, 2555, 7086, 3110),
	"stone_stream":Rect2(7883, 1033, 3734, 1234),
}
const V11_LANDMARKS := {
	"townhall": {"id": "townhall", "name": "潮芽镇公所", "kind": "townhall", "bounds": Rect2(1856, 624, 256, 144), "door": Vector2(1984, 784), "open": true},
	"east_house": {"id": "east_house", "name": "东街民居", "kind": "house", "bounds": Rect2(2368, 848, 192, 144), "door": Vector2(2464, 1008), "open": true},
	"orchard_house": {"id": "orchard_house", "name": "榕荫民居", "kind": "house", "bounds": Rect2(2912, 880, 192, 144), "door": Vector2(3008, 1040), "open": true},
	"market": {"id": "market", "name": "潮芽超市", "kind": "shop", "bounds": Rect2(992, 352, 192, 112), "door": Vector2(1088, 480), "open": true},
	"clinic": {"id": "clinic", "name": "海风诊所", "kind": "clinic", "bounds": Rect2(1472, 128, 160, 112), "door": Vector2(1552, 256), "open": true},
	"bathhouse": {"id": "bathhouse", "name": "暖泉澡堂", "kind": "bathhouse", "bounds": Rect2(1432, 464, 192, 96), "door": Vector2(1528, 576), "open": true},
	"carpenter": {"id": "carpenter", "name": "木匠工坊", "kind": "workshop", "bounds": Rect2(1024, 624, 176, 128), "door": Vector2(1112, 768), "open": true},
	"smith": {"id": "smith", "name": "炉火铁匠铺", "kind": "workshop", "bounds": Rect2(1472, 624, 176, 128), "door": Vector2(1560, 768), "open": true},
	"fishery": {"id": "fishery", "name": "岸边渔铺", "kind": "shop", "bounds": Rect2(976, 112, 128, 96), "door": Vector2(1040, 224), "open": true},
	"farmhouse": {"id": "farmhouse", "name": "苔瓦民居", "kind": "house", "bounds": Rect2(1024, 896, 160, 112), "door": Vector2(1104, 1024), "open": true},
	"plaza": {"id": "plaza", "name": "潮芽广场", "kind": "plaza", "bounds": Rect2(1248, 456, 176, 176), "door": Vector2(1344, 544), "open": true},
	"mine_entrance": {"id": "mine_entrance", "name": "封闭矿洞 · 尚未开放", "kind": "mine", "bounds": Rect2(11584, 1072, 160, 96), "door": Vector2(11664, 1184), "open": false},
}
const LANDMARKS := {
	"restaurant": {"id":"restaurant","name":"潮间寿司屋","kind":"shop","bounds":Rect2(2784,352,320,112),"door":Vector2(3024,480),"open":true},
	"greenhouse": {"id":"greenhouse","name":"旧日温室 · 可修复","kind":"greenhouse","bounds":Rect2(3152,816,224,128),"door":Vector2(3264,960),"open":true},
	"townhall": {"id": "townhall", "name": "潮芽镇公所", "kind": "townhall", "bounds": Rect2(2464, 624, 256, 144), "door": Vector2(2592, 784), "open": true},
	"east_house": {"id": "east_house", "name": "东街民居", "kind": "house", "bounds": Rect2(2368, 848, 192, 144), "door": Vector2(2464, 1008), "open": true},
	"orchard_house": {"id": "orchard_house", "name": "榕荫民居", "kind": "house", "bounds": Rect2(2912, 880, 192, 144), "door": Vector2(3008, 1040), "open": true},
	"market": {"id": "market", "name": "潮芽超市", "kind": "shop", "bounds": Rect2(880, 704, 320, 112), "door": Vector2(1088, 832), "open": true},
	"clinic": {"id": "clinic", "name": "海风诊所", "kind": "clinic", "bounds": Rect2(720, 672, 160, 112), "door": Vector2(832, 800), "open": true},
	"bathhouse": {"id": "bathhouse", "name": "暖泉澡堂", "kind": "bathhouse", "bounds": Rect2(1712, 448, 512, 96), "door": Vector2(1856, 560), "open": true},
	"carpenter": {"id": "carpenter", "name": "木匠工坊", "kind": "workshop", "bounds": Rect2(1000, 1104, 224, 128), "door": Vector2(1112, 1248), "open": true},
	"smith": {"id": "smith", "name": "炉火铁匠铺", "kind": "workshop", "bounds": Rect2(1448, 1104, 256, 128), "door": Vector2(1560, 1248), "open": true},
	"fishery": {"id": "fishery", "name": "岸边渔铺", "kind": "shop", "bounds": Rect2(960, 240, 288, 96), "door": Vector2(1040, 352), "open": true},
	"farmhouse": {"id": "farmhouse", "name": "苔瓦民居", "kind": "house", "bounds": Rect2(928, 1552, 256, 112), "door": Vector2(1104, 1680), "open": true},
	"plaza": {"id": "plaza", "name": "潮芽广场", "kind": "plaza", "bounds": Rect2(1216, 672, 512, 480), "door": Vector2(1488, 912), "open": true},
	"mine_entrance": {"id": "mine_entrance", "name": "灰岩矿洞 · 三层矿脉", "kind": "mine", "bounds": Rect2(11728, 1232, 160, 96), "door": Vector2(11808, 1344), "open": true},
}
const WATER_FEATURES := {
	"mirror_lake": {"id": "mirror_lake", "name": "映林湖", "kind": "lake", "center": Vector2(7488, 2352), "radius": Vector2(700, 420), "bounds": Rect2(6788, 1932, 1400, 840)},
	"reed_river": {"id": "reed_river", "name": "芦苇河", "kind": "river", "points": [Vector2(7100, 2600), Vector2(6350, 3000), Vector2(5550, 3500), Vector2(4650, 3970), Vector2(3500, 4420), Vector2(2450, 4870), Vector2(1300, 5250), Vector2(104, 5620)], "width": 90.0, "bounds": Rect2(59, 2555, 7086, 3110)},
	"stone_stream": {"id": "stone_stream", "name": "石间溪", "kind": "stream", "points": [Vector2(11600, 1050), Vector2(10800, 1300), Vector2(9900, 1680), Vector2(9000, 1820), Vector2(8100, 2100), Vector2(7900, 2250)], "width": 34.0, "bounds": Rect2(7883, 1033, 3734, 1234)},
}
const REGIONS := [
	{"id": "harbor", "name": "潮汐港湾", "color": Color("92a779"), "bounds": Rect2(0, 0, 4480, 3264), "description": "西岸码头通往潮芽镇。镇公所在东街，荒废院子在东南；向镇长问问那块地。"},
	{"id": "woodland", "name": "风语林地", "color": Color("749168"), "bounds": Rect2(4480, 0, 5376, 3264), "description": "树木与纤维较多。带上石斧，沿林间小径寻找空地。"},
	{"id": "foothills", "name": "灰岩山麓", "color": Color("a3a48a"), "bounds": Rect2(9856, 0, 4480, 3264), "description": "裸岩与矿脉露出地面。石镐能缩短开采时间。"},
	{"id": "wetland", "name": "芦苇湿地", "color": Color("789c8d"), "bounds": Rect2(0, 3264, 4480, 3264), "description": "池塘与芦苇间留有连通小径。淡水就在池边。"},
	{"id": "farmland", "name": "旧日农庄", "color": Color("aba96f"), "bounds": Rect2(4480, 3264, 5376, 3264), "description": "开阔草地适合整理田地。清走杂物，再松土种植。"},
	{"id": "ruins", "name": "苔石古迹", "color": Color("94917d"), "bounds": Rect2(9856, 3264, 4480, 3264), "description": "旧石基间散落矿石与埋藏痕迹。这里还没有开放建筑。"},
]
const LEGACY := {
	"palm_0": {"kind": "tree", "x": 330.0, "y": 280.0},
	"palm_1": {"kind": "fiber", "x": 405.0, "y": 200.0},
	"seeds_0": {"kind": "dig_seed", "x": 470.0, "y": 270.0},
	"stone_0": {"kind": "stone", "x": 630.0, "y": 180.0},
	"ore_0": {"kind": "ore", "x": 690.0, "y": 240.0},
	"wood_1": {"kind": "branch", "x": 380.0, "y": 350.0},
}
const NODE_TYPES := {
	"mushroom": {"item":"mushroom","amount":2,"label":"采摘林菇","tool":"","duration":2.0,"cost":2.0,"regrow":2,"radius":10.0},
	"tree": {"item": "wood", "amount": 3, "label": "砍伐树木", "tool": "axe", "duration": 6.0, "cost": 6.0, "regrow": 3, "radius": 18.0},
	"branch": {"item": "wood", "amount": 3, "label": "砍开枯枝", "tool": "axe", "duration": 2.0, "cost": 2.0, "regrow": 1, "radius": 12.0},
	"fiber": {"item": "fiber", "amount": 3, "label": "割取纤维", "tool": "scythe", "duration": 1.5, "cost": 3.0, "regrow": 2, "radius": 12.0},
	"stone": {"item": "stone", "amount": 3, "label": "开采石料", "tool": "pickaxe", "duration": 3.0, "cost": 6.0, "regrow": 3, "radius": 18.0},
	"ore": {"item": "ore", "amount": 2, "label": "开采矿石", "tool": "pickaxe", "duration": 4.0, "cost": 8.0, "regrow": 4, "radius": 18.0},
	"dig_seed": {"item": "seed", "amount": 2, "label": "挖掘野生种子", "tool": "hoe", "duration": 2.0, "cost": 3.0, "regrow": 3, "radius": 12.0},
	"dig_treasure": {"item": "treasure", "amount": 1, "label": "挖掘埋藏物", "tool": "hoe", "duration": 4.0, "cost": 4.0, "regrow": 7, "radius": 12.0},
}
static var _v11_streets: Array = []
static var _streets: Array = []
static var _pages: Dictionary = {}
static var _ponds: Dictionary = {}
static var _bridges: Dictionary = {}
static var _route_cache: Dictionary = {}
const FOREST_SITES := {
	"mushrooms":{"name":"林菇湿地","at":Vector2(5264,1168),"kinds":["mushroom","mushroom","fiber","mushroom"]},
	"seeds":{"name":"野种洼地","at":Vector2(6256,1552),"kinds":["dig_seed","dig_seed","fiber","dig_seed"]},
	"cache":{"name":"旧林营地","at":Vector2(8848,2640),"kinds":["dig_treasure","branch","ore","dig_treasure"]},
}
static var _forest:Dictionary={}

static func forest_nodes()->Dictionary:
	if not _forest.is_empty():return _forest
	for site_id:String in FOREST_SITES:
		var site:Dictionary=FOREST_SITES[site_id]
		for i in site.kinds.size():
			for attempt in 50:
				var at:Vector2=site.at+Vector2(cos(i*1.7+attempt)*48*(1+attempt/5),sin(i*1.7+attempt)*48*(1+attempt/5))
				at=(at/32).floor()*32+Vector2(16,16)
				if not tillable(at) or _forest.values().any(func(n:Dictionary):return at.distance_to(Vector2(n.x,n.y))<48):continue
				var nearby:Dictionary=_page_nodes(Vector2i(page_origin(at)/PAGE))
				if nearby.values().any(func(n:Dictionary):return at.distance_to(Vector2(n.x,n.y))<78):continue
				var id:="forest_%s_%d"%[site_id,i]
				_forest[id]=_definition(site.kinds[i],at,id)
				if site_id=="seeds" and site.kinds[i]=="dig_seed":_forest[id].item=["seed","summer_seed","autumn_seed","winter_seed"][i]
				break
	return _forest


static func page_origin(point: Vector2) -> Vector2:
	if not point.is_finite():
		return Vector2.ZERO
	return Vector2(clampi(floori(point.x / PAGE.x), 0, PAGES.x - 1), clampi(floori(point.y / PAGE.y), 0, PAGES.y - 1)) * PAGE


static func region(point: Vector2) -> Dictionary:
	var safe := Vector2(clampf(point.x, 0, SIZE.x - 1), clampf(point.y, 0, SIZE.y - 1)) if point.is_finite() else Vector2.ZERO
	for entry: Dictionary in REGIONS:
		var bounds: Rect2 = entry.bounds
		if bounds.has_point(safe):
			return entry
	return REGIONS[0]


static func _fraction(seed_value: int) -> float:
	# Fixed integer arithmetic; map layout is independent of global RNG and day.
	var mixed: int = posmod(seed_value * 16807 + 15731, 2147483647)
	mixed = posmod(mixed * 48271 + 17, 2147483647)
	return float(mixed % 100003) / 100003.0


static func _coast_x(y: float) -> float:
	return 106.0 + sin(y / 280.0) * 35.0 + sin(y / 93.0) * 10.0


static func _coast_y(x: float) -> float:
	return 67.0 + sin(x / 430.0) * 21.0 + sin(x / 117.0) * 8.0


static func _legacy_on_path(point: Vector2) -> bool:
	var vertical: float = absf(point.x - vertical_path_x(point.y, floori(point.x / PAGE.x)))
	var horizontal: float = absf(point.y - horizontal_path_y(point.x, floori(point.y / PAGE.y)))
	if vertical < 19.0 or horizontal < 18.0:
		return true
	# The landing leads inland, instead of ending at the old enclosed shoreline.
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, DOCK, Vector2(448, 308))) < 18.0


static func settlement(point: Vector2) -> bool:
	return point.is_finite() and TOWN_BOUNDS.has_point(point)


static func landmarks_near(point: Vector2) -> Dictionary:
	var nearby := Rect2(page_origin(point) - PAGE, PAGE * 3)
	var result: Dictionary = {}
	for id: String in LANDMARKS:
		if nearby.intersects(Rect2(LANDMARKS[id].bounds).grow(32)):
			result[id] = LANDMARKS[id]
	return result


static func _v10_landmark_path(point: Vector2) -> bool:
	if OLD_TOWN_BOUNDS.has_point(point):
		if absf(point.x - 1344) < 24:
			return true
		if Rect2(V11_LANDMARKS.plaza.bounds).has_point(point):
			return true
		for id: String in V11_LANDMARKS:
			if id == "mine_entrance" or id in NEW_BUILDINGS:
				continue
			var door: Vector2 = V11_LANDMARKS[id].door
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, door, Vector2(1344, door.y))) < 18:
				return true
	var mine_door: Vector2 = V11_LANDMARKS.mine_entrance.door
	var junction := Vector2(mine_door.x, horizontal_path_y(mine_door.x, floori(mine_door.y / PAGE.y)))
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, mine_door, junction)) < 18


static func _v11_town_streets() -> Array:
	if not _v11_streets.is_empty():
		return _v11_streets
	var result: Array = [PackedVector2Array([Vector2(1344, 88), Vector2(1344, 2400)]), PackedVector2Array([Vector2(1792, 768), Vector2(1792, 2400)]), PackedVector2Array([Vector2(1344, 1792), YARD_GATE + Vector2(96, 0)])]
	for landmark: Dictionary in V11_LANDMARKS.values():
		if landmark.id != "mine_entrance":
			result.append(PackedVector2Array([landmark.door, Vector2(1344 if landmark.door.x < 1792 else 1792, landmark.door.y)]))
	_v11_streets = result
	return _v11_streets

static func _v11_landmark_path(point: Vector2) -> bool:
	if _v10_landmark_path(point):
		return true
	if not V11_TOWN_BOUNDS.has_point(point):
		return false
	for line: PackedVector2Array in _v11_town_streets():
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, line[0], line[1])) < 18:
			return true
	return false


static func town_streets() -> Array:
	if not _streets.is_empty():
		return _streets
	var result: Array = [PackedVector2Array([Vector2(1344, 88), Vector2(1344, 2400)]), PackedVector2Array([Vector2(1792, 560), Vector2(1792, 2400)]), PackedVector2Array([Vector2(1344, 1792), YARD_GATE + Vector2(96, 0)])]
	for landmark: Dictionary in LANDMARKS.values():
		if landmark.id not in ["mine_entrance","clinic","restaurant","greenhouse"]:
			result.append(PackedVector2Array([landmark.door, Vector2(1344 if landmark.door.x < 1792 else 1792, landmark.door.y)]))
	# A clinic route through the market and a northern road through the bathhouse
	# would look connected on a map while being blocked in the world.
	for pair in [[Vector2(832,800),Vector2(832,864)],[Vector2(832,864),Vector2(1344,864)],[Vector2(3024,480),Vector2(2336,480)],[Vector2(2336,480),Vector2(2336,576)],[Vector2(2336,576),Vector2(1792,576)],[Vector2(3264,960),Vector2(3264,1056)],[Vector2(3264,1056),Vector2(1792,1056)]]:
		result.append(PackedVector2Array(pair))
	_streets = result
	return _streets

static func _landmark_path(point: Vector2) -> bool:
	if Rect2(LANDMARKS.plaza.bounds).has_point(point): return true
	if not TOWN_BOUNDS.has_point(point): return false
	for line: PackedVector2Array in town_streets():
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,line[0],line[1])) < (18 if YARD_BOUNDS.has_point(point) else 28): return true
	return false

static func on_path(point: Vector2) -> bool:
	if TOWN_BOUNDS.has_point(point):return _landmark_path(point)
	var door:Vector2=LANDMARKS.mine_entrance.door
	var junction:=Vector2(door.x,horizontal_path_y(door.x,floori(door.y/PAGE.y)))
	return _legacy_on_path(point) or _v10_landmark_path(point) or point.distance_to(Geometry2D.get_closest_point_to_segment(point,door,junction))<18

static func yard_fence(point: Vector2) -> bool:
	if not YARD_BOUNDS.grow(8).has_point(point):
		return false
	if absf(point.x - YARD_GATE.x) <= 8 and absf(point.y - YARD_GATE.y) < 56:
		return false
	return absf(point.x - YARD_BOUNDS.position.x) < 8 or absf(point.x - YARD_BOUNDS.end.x) < 8 or absf(point.y - YARD_BOUNDS.position.y) < 8 or absf(point.y - YARD_BOUNDS.end.y) < 8


static func _building_contains(point: Vector2, old_map := false, old_art := false) -> bool:
	for landmark: Dictionary in LANDMARKS.values():
		if (old_map or old_art) and not V11_BOUNDS.has(landmark.id): continue
		if landmark.kind != "plaza" and (not old_map or landmark.id not in NEW_BUILDINGS) and Rect2(V11_BOUNDS[landmark.id] if old_map or old_art else landmark.bounds).has_point(point):
			return true
	return false


static func vertical_path_x(y: float, column: int) -> float:
	var offset: float = sin(y / 320.0) * 40.0
	# Curve around the original farm clearing so migrated crops remain tillable.
	if column == 0 and y < PAGE.y:
		offset -= 38.0 * exp(-pow((y - 350.0) / 95.0, 2))
	return (column + 0.5) * PAGE.x + offset


static func horizontal_path_y(x: float, row: int) -> float:
	return (row + 0.5) * PAGE.y + sin(x / 270.0) * 35.0


static func ponds_near(point: Vector2) -> Array:
	var result: Array = []
	var page := Vector2i(page_origin(point) / PAGE)
	for row in range(maxi(0, page.y - 1), mini(PAGES.y, page.y + 2)):
		for column in range(maxi(0, page.x - 1), mini(PAGES.x, page.x + 2)):
			var pond: Dictionary = _page_pond(Vector2i(column, row))
			if not pond.is_empty() and pond_visible(pond):
				result.append(pond)
	return result


static func _page_pond(page: Vector2i) -> Dictionary:
	var key: int = page.y * PAGES.x + page.x
	if _ponds.has(key):
		return _ponds[key]
	var origin: Vector2 = Vector2(page) * PAGE
	var wet: bool = region(origin + PAGE * 0.5).id == "wetland"
	if key % 3 == 2 and not wet:
		_ponds[key] = {}
		return {}
	var center := origin + Vector2(640 + _fraction(key + 25) * 90, 395 + _fraction(key + 63) * 38)
	var radius := Vector2(68 + _fraction(key + 41) * 34, 39 + _fraction(key + 52) * 19) * (1.25 if wet else 1.0)
	if key == 0:
		center = Vector2(720, 430)
		radius = Vector2(64, 42)
	_ponds[key] = {"center": center, "radius": radius}
	return _ponds[key]


static func _pond_contains(point: Vector2) -> bool:
	# Every pond lies wholly in its own page, so collision needs one lookup.
	var pond: Dictionary = _page_pond(Vector2i(page_origin(point) / PAGE))
	return not pond.is_empty() and ((point - Vector2(pond.center)) / Vector2(pond.radius)).length_squared() < 1.0


static func legacy_terrain(point: Vector2) -> String:
	# Frozen v9 terrain keeps old n_* ids/coordinates stable and validates old saves.
	if not point.is_finite() or not Rect2(Vector2.ZERO, SIZE).has_point(point):
		return "water"
	if point.x < _coast_x(point.y) or point.y < _coast_y(point.x) or point.x >= SIZE.x - 56 or point.y >= SIZE.y - 56:
		return "water"
	if _legacy_on_path(point):
		return "path"
	if _pond_contains(point):
		return "water"
	if point.x < _coast_x(point.y) + 52 or point.y < _coast_y(point.x) + 48 or point.x >= SIZE.x - 100 or point.y >= SIZE.y - 100:
		return "sand"
	var area_id: String = str(region(point).id)
	if area_id in ["foothills", "ruins"] and sin(point.x / 151.0) + cos(point.y / 117.0) > 0.72:
		return "rock"
	return "grass"


static func legacy_walkable(point: Vector2) -> bool:
	return legacy_terrain(point) != "water"


static func legacy_tillable(point: Vector2) -> bool:
	return legacy_terrain(point) == "grass"


static func _feature_distance(point: Vector2, feature: Dictionary) -> float:
	var points: Array = feature.points
	var distance := INF
	for index in range(1, points.size()):
		distance = minf(distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[index - 1], points[index])))
	return distance


static func _feature_contains(point: Vector2, feature: Dictionary) -> bool:
	if not Rect2(feature.bounds).has_point(point):
		return false
	if feature.has("center"):
		return ((point - Vector2(feature.center)) / Vector2(feature.radius)).length_squared() < 1.0
	return _feature_distance(point, feature) < float(feature.width) * 0.5


static func _new_water_contains(point: Vector2) -> bool:
	for feature: Dictionary in WATER_FEATURES.values():
		if _feature_contains(point, feature):
			return true
	return false


static func v10_terrain(point: Vector2) -> String:
	var previous := legacy_terrain(point)
	if not point.is_finite() or not Rect2(Vector2.ZERO, SIZE).has_point(point):
		return "water"
	if _building_contains(point, true):
		return "building"
	if _new_water_contains(point):
		return "bridge" if (_legacy_on_path(point) or _v10_landmark_path(point)) else "water"
	if _v10_landmark_path(point):
		return "bridge" if previous == "water" else "path"
	return previous


static func v11_terrain(point: Vector2) -> String:
	if not point.is_finite() or not Rect2(Vector2.ZERO,SIZE).has_point(point):
		return "water"
	var previous := v10_terrain(point)
	if _building_contains(point,false,true) or yard_fence(point):
		return "building"
	if YARD_BOUNDS.has_point(point):
		if _pond_contains(point):
			return "water"
		return "path" if _v11_landmark_path(point) else "grass"
	if _pond_contains(point) and (_legacy_on_path(point) or _v11_landmark_path(point)):
		return "bridge"
	if _v11_landmark_path(point):
		return "bridge" if previous == "water" else "path"
	return previous

static func terrain(point: Vector2) -> String:
	if not point.is_finite() or not Rect2(Vector2.ZERO,SIZE).has_point(point): return "water"
	if _building_contains(point) or yard_fence(point): return "building"
	if TOWN_BOUNDS.has_point(point):
		if current_pond_contains(point) or _new_water_contains(point): return "bridge" if on_path(point) else "water"
		return "path" if on_path(point) else "grass"
	# Keep historical geometry for save migration, not an invisible wall at the
	# former sealed mine. The playable entrance now fits wholly inside its page.
	var old:=v10_terrain(point)
	if old=="building" and Rect2(V11_BOUNDS.mine_entrance).has_point(point):old=legacy_terrain(point)
	if on_path(point):return "bridge" if old in ["water","bridge"] else "path"
	return old

static func walkable(point: Vector2) -> bool:
	return terrain(point) not in ["water", "building"]


static func tillable(point: Vector2) -> bool:
	return terrain(point) == "grass"


static func water_near(point: Vector2) -> bool:
	if not point.is_finite() or not walkable(point):
		return false
	for feature: Dictionary in water_features_near(point):
		if feature.has("center"):
			if ((point - Vector2(feature.center)) / (Vector2(feature.radius) + Vector2.ONE * 64)).length_squared() <= 1.0:
				return true
		elif _feature_distance(point, feature) <= float(feature.width) * 0.5 + 64:
			return true
	return false


static func water_features_near(point: Vector2) -> Array:
	var result: Array = []
	var nearby := Rect2(page_origin(point) - PAGE, PAGE * 3)
	for feature: Dictionary in WATER_FEATURES.values():
		if nearby.intersects(Rect2(feature.bounds)):
			result.append(feature)
	for pond: Dictionary in ponds_near(point):
		var entry: Dictionary = pond.duplicate()
		entry.id = "pond_%d_%d" % [floori(Vector2(pond.center).x / PAGE.x), floori(Vector2(pond.center).y / PAGE.y)]
		entry.kind = "pond"
		entry.name = "林间水泊"
		entry.bounds = Rect2(Vector2(pond.center) - Vector2(pond.radius), Vector2(pond.radius) * 2)
		result.append(entry)
	return result


static func bridges_near(point: Vector2) -> Array:
	# Only the visible page needs bridge sprites. Cache its 476 tile samples once.
	var result: Array = []
	var page := Vector2i(page_origin(point) / PAGE)
	for row in range(page.y, page.y + 1):
		for column in range(page.x, page.x + 1):
			var key := "%d,%d" % [column, row]
			if not _bridges.has(key):
				var spans: Array = []
				var origin := Vector2(column, row) * PAGE
				for ty in int(PAGE.y / TILE):
					var start := -1
					for tx in range(int(PAGE.x / TILE) + 1):
						var at := origin + Vector2(tx + 0.5, ty + 0.5) * TILE
						var bridge := tx < int(PAGE.x / TILE) and terrain(at) == "bridge"
						if bridge and start < 0:
							start = tx
						if not bridge and start >= 0:
							spans.append({"id": "bridge_%s_%d_%d" % [key, ty, start], "bounds": Rect2(origin + Vector2(start, ty) * TILE, Vector2((tx - start) * TILE, TILE))})
							start = -1
				_bridges[key] = spans
			result.append_array(_bridges[key])
	return result


static func _definition(kind: String, at: Vector2, id: String) -> Dictionary:
	var result: Dictionary = NODE_TYPES[kind].duplicate()
	result.merge({"id": id, "kind": kind, "x": at.x, "y": at.y})
	if kind == "dig_seed" and id != "seeds_0":
		result.item = {"wetland": "summer_seed", "farmland": "autumn_seed", "ruins": "winter_seed"}.get(str(region(at).id), "seed")
	return result


static func _page_nodes(page: Vector2i) -> Dictionary:
	var key := "%d,%d" % [page.x, page.y]
	if _pages.has(key):
		return _pages[key]
	var result: Dictionary = {}
	if page == Vector2i.ZERO:
		for id: String in LEGACY:
			var old: Dictionary = LEGACY[id]
			result[id] = _definition(str(old.kind), Vector2(float(old.x), float(old.y)), id)
		_pages[key] = result
		return result
	var origin: Vector2 = Vector2(page) * PAGE
	var area_id: String = str(region(origin + PAGE * 0.5).id)
	var palettes := {
		"harbor": ["branch", "fiber", "tree", "dig_seed"],
		"woodland": ["tree", "tree", "fiber", "branch", "dig_seed", "tree", "fiber"],
		"foothills": ["stone", "ore", "stone", "branch", "ore", "dig_seed"],
		"wetland": ["fiber", "dig_seed", "branch", "fiber", "tree"],
		"farmland": ["dig_seed", "branch", "fiber"],
		"ruins": ["stone", "dig_treasure", "ore", "dig_seed"],
	}
	var kinds: Array = palettes[area_id]
	var seed_value: int = page.x + page.y * PAGES.x
	# Occasional quiet clearings keep the island from becoming a resource grid.
	var count_value: int = 2 if seed_value % 7 == 0 else kinds.size()
	for index in count_value:
		for attempt in 18:
			var seed_offset: int = seed_value * 131 + index * 37 + attempt * 11
			var at := origin + Vector2(110 + _fraction(seed_offset) * 660, 122 + _fraction(seed_offset + 19) * 316)
			if not legacy_walkable(at) or _legacy_on_path(at):
				continue
			var crowded := false
			for existing: Dictionary in result.values():
				if at.distance_to(Vector2(float(existing.x), float(existing.y))) < 78:
					crowded = true
			if crowded:
				continue
			var id := "n_%d_%d_%d" % [page.x, page.y, index]
			result[id] = _definition(str(kinds[index]), at.round(), id)
			break
	_add_clearings(page, result)
	_add_yard_nodes(page, result)
	_pages[key] = result
	return result


static func _add_clearings(page: Vector2i, result: Dictionary) -> void:
	# Preserve the landing tutorial and town gardens; wilderness grows in loose clumps.
	if page == Vector2i.ZERO or (page.x == 1 and page.y < 2):
		return
	var origin := Vector2(page) * PAGE
	var area_id: String = str(region(origin + PAGE * 0.5).id)
	var counts := {"harbor": 16, "woodland": 26, "foothills": 10, "wetland": 18, "farmland": 14, "ruins": 10}
	var kinds := ["fiber", "branch", "fiber", "stone", "fiber"]
	if area_id == "woodland":
		kinds = ["tree", "fiber", "branch", "fiber", "tree"]
	var seed_value: int = page.x + page.y * PAGES.x
	for index in int(counts[area_id]):
		var group: int = index % 3
		var center := origin + Vector2(115 + _fraction(seed_value * 239 + group * 47) * 665, 100 + _fraction(seed_value * 193 + group * 79) * 335)
		for attempt in 16:
			var seed_offset: int = seed_value * 467 + index * 61 + attempt * 97
			var angle: float = _fraction(seed_offset) * TAU
			var radius: float = 24 + sqrt(_fraction(seed_offset + 31)) * (88 if area_id == "woodland" else 104)
			var candidate := center + Vector2(cos(angle), sin(angle)) * radius
			var at := (candidate / TILE).floor() * TILE + Vector2.ONE * (TILE / 2.0)
			if not Rect2(origin + Vector2.ONE * 48, PAGE - Vector2.ONE * 96).has_point(at) or v10_terrain(at) != "grass":
				continue
			var crowded := false
			for existing: Dictionary in result.values():
				if at.distance_to(Vector2(float(existing.x), float(existing.y))) < 31:
					crowded = true
					break
			if crowded:
				continue
			var id := "clear_%d_%d_%d" % [page.x, page.y, index]
			result[id] = _definition(str(kinds[index % kinds.size()]), at, id)
			break


static func _add_yard_nodes(page: Vector2i, result: Dictionary) -> void:
	var page_rect := Rect2(Vector2(page) * PAGE, PAGE)
	if not page_rect.intersects(YARD_BOUNDS):
		return
	var kinds := ["fiber", "branch", "fiber", "tree", "stone", "dig_seed", "fiber", "dig_treasure"]
	for index in 44:
		var seed_value := page.x * 8191 + page.y * 131 + index * 397
		var at := page_rect.position + Vector2(48 + _fraction(seed_value) * (PAGE.x - 96), 48 + _fraction(seed_value + 19) * (PAGE.y - 96))
		at = (at / TILE).floor() * TILE + Vector2(16, 16)
		if not YARD_BOUNDS.grow(-48).has_point(at) or not tillable(at):
			continue
		var crowded := false
		for existing: Dictionary in result.values():
			if at.distance_to(Vector2(existing.x, existing.y)) < 40:
				crowded = true
		if not crowded:
			var id := "yard_%d_%d_%d" % [page.x, page.y, index]
			result[id] = _definition(kinds[index % kinds.size()], at, id)

static func nodes_near(point: Vector2) -> Dictionary:
	var page := Vector2i(page_origin(point) / PAGE)
	var result: Dictionary = {}
	for row in range(maxi(0, page.y - 1), mini(PAGES.y, page.y + 2)):
		for column in range(maxi(0, page.x - 1), mini(PAGES.x, page.x + 2)):
			result.merge(_page_nodes(Vector2i(column, row)))
	for id:String in forest_nodes():
		if Rect2(page_origin(point)-PAGE,PAGE*3).has_point(Vector2(_forest[id].x,_forest[id].y)):result[id]=_forest[id]
	return result


static func node(id: String) -> Dictionary:
	if id.begins_with("forest_"):return forest_nodes().get(id,{})
	if LEGACY.has(id):
		return _page_nodes(Vector2i.ZERO)[id].duplicate()
	var parts := id.split("_")
	if id.length() > 40 or parts.size() != 4 or parts[0] not in ["n", "clear", "yard"] or not parts[1].is_valid_int() or not parts[2].is_valid_int() or not parts[3].is_valid_int():
		return {}
	var page := Vector2i(int(parts[1]), int(parts[2]))
	if page.x < 0 or page.y < 0 or page.x >= PAGES.x or page.y >= PAGES.y:
		return {}
	return _page_nodes(page).get(id, {}).duplicate()

# Shared by the ground renderer and the map; callers treat cached arrays as read-only.
static func route_segments(points: PackedVector2Array) -> Array:
	var key := hash(points)
	if _route_cache.has(key): return _route_cache[key]
	var pieces:Array=[]
	for index in range(1,points.size()):
		var before:Vector2=points[index-1]
		var after:Vector2=points[index]
		var steps:=maxi(1,ceili(before.distance_to(after)/8.0))
		for step in steps:
			var a:=before.lerp(after,float(step)/steps)
			var b:=before.lerp(after,float(step+1)/steps)
			var ground:=terrain((a+b)*0.5)
			if ground in ["path","bridge"]:
				pieces.append({"a":a,"b":b,"kind":ground})
	# Viewport sizes contribute different endpoints; keep old resized views bounded.
	if _route_cache.size() >= 128:
		_route_cache.erase(_route_cache.keys()[0])
	_route_cache[key]=pieces
	return pieces

static func can_stand(point:Vector2) -> bool:
	for offset in [Vector2.ZERO,Vector2(-6,-3),Vector2(6,-3),Vector2(-6,3),Vector2(6,3)]:
		if not walkable(point+offset): return false
	return true

static func nearby_standing_point(point:Vector2) -> Vector2:
	if can_stand(point): return point
	for radius in range(2,17,2):
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var candidate:Vector2=point+direction*radius
			if can_stand(candidate): return candidate
	return point

static func recover_standing_point(point:Vector2) -> Vector2:
	if can_stand(point): return point
	for radius in range(4,513,4):
		for direction in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,1),Vector2(1,1),Vector2(-1,-1),Vector2(1,-1)]:
			var candidate:Vector2=point+direction*radius
			if can_stand(candidate): return candidate
	return DOCK

static func pond_visible(pond:Dictionary) -> bool:
	if not TOWN_BOUNDS.has_point(pond.center): return true
	var bounds:=Rect2(Vector2(pond.center)-Vector2(pond.radius),Vector2(pond.radius)*2)
	for place:Dictionary in LANDMARKS.values():
		if bounds.intersects(Rect2(place.bounds).grow(24)): return false
	return true

static func current_pond_contains(point:Vector2) -> bool:
	var pond:=_page_pond(Vector2i(page_origin(point)/PAGE))
	return not pond.is_empty() and pond_visible(pond) and ((point-Vector2(pond.center))/Vector2(pond.radius)).length_squared()<1.0

static func landmark_label(data:Dictionary,id:String)->String:
	if id=="greenhouse":return "旧日温室 · "+("已修复" if data.get("gardens",{}).get("greenhouse",false) else "待修复")
	if id=="restaurant":return "潮间寿司屋 · "+("营业中" if data.get("restaurant",{}).get("open",false) else "已承租" if data.get("restaurant",{}).get("rented",false) else "可承租")
	return str(LANDMARKS[id].name)

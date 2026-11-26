extends RefCounted
## Shared chart definitions only. WorldState owns travel, docking and mutations.

const HOME_ID := "island_home"
const DOCK_RADIUS := 110.0
const ISLAND_WORLD_RADIUS := 150.0
const ISLAND_BODY_OFFSET := Vector2(210, -60)
const DOCK_RECT := Rect2(130, 350, 160, 60)
const MAP_SIZE := Vector2(1800, 1400)
const MAP_OFFSET := Vector2(-520, -650)
const ISLANDS := {
	"island_home": {"id": "island_home", "name": "潮芽岛", "offset": Vector2(520, 120), "unlocked": true, "description": "海流下游的大岛。沿西岸港口入岛，扩建的潮芽镇向东街与南巷展开；镇公所东南的大院可向镇长承租。森林、湖河与山麓在内陆。"},
	"island_mist": {"id": "island_mist", "name": "雾岬", "offset": Vector2(1000, -410), "unlocked": true, "description": "山地湖岸与露天矿脉。带上石镐，沿山路寻找海商白帆；他愿意交换海上带来的物资。"},
	"island_reef": {"id": "island_reef", "name": "珊湾", "offset": Vector2(-290, 470), "unlocked": true, "description": "沙滩与潮汐小桥，漂来旧箱和海苔。海盗赤绳在岸边歇脚，老海龟常在沙地晒太阳。"},
	"island_wind": {"id": "island_wind", "name": "风栖岛", "offset": Vector2(990, 570), "unlocked": true, "description": "林间的旧农庄，枯枝和野菇散落在树下。若能听懂潮声，也许会听见精灵的问候。"},
}
const LAND_SPOTS := {
	"dock": Vector2(210, 380),
	"wood_0": Vector2(330, 280), "wood_1": Vector2(405, 200),
	"ore_0": Vector2(630, 180), "ore_1": Vector2(690, 240),
	"garden": Vector2(500, 335), "shore_fishing": Vector2(270, 425),
	"future_shop": Vector2(640, 395),
}


static func create(navigation: Dictionary) -> Dictionary:
	return {"origin_x": float(navigation.get("x", 0.0)), "origin_y": float(navigation.get("y", 0.0)), "visited": false, "destination": ""}


static func restore(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 4:
		return {}
	for key in ["origin_x", "origin_y"]:
		var number: Variant = value.get(key)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or absf(float(number)) > 1.0e15:
			return {}
	if not value.get("visited") is bool or not value.get("destination") is String:
		return {}
	if str(value.destination) != "" and not ISLANDS.has(value.destination):
		return {}
	return {"origin_x": float(value.origin_x), "origin_y": float(value.origin_y), "visited": bool(value.visited), "destination": str(value.destination)}


static func origin(chart: Dictionary) -> Vector2:
	return Vector2(float(chart.get("origin_x", 0.0)), float(chart.get("origin_y", 0.0)))


static func island_position(chart: Dictionary, id: String = HOME_ID) -> Vector2:
	if not ISLANDS.has(id):
		return origin(chart)
	var offset: Vector2 = ISLANDS[id].offset
	return origin(chart) + offset


static func map_rect(chart: Dictionary) -> Rect2:
	return Rect2(origin(chart) + MAP_OFFSET, MAP_SIZE)


static func within_docking_range(chart: Dictionary, navigation: Dictionary, id: String = HOME_ID) -> bool:
	if not ISLANDS.has(id) or not ISLANDS[id].unlocked:
		return false
	var raft := Vector2(float(navigation.get("x", 0.0)), float(navigation.get("y", 0.0)))
	return raft.distance_to(island_position(chart, id)) <= DOCK_RADIUS

static func nearby_island(chart:Dictionary,navigation:Dictionary)->String:
	for id:String in ISLANDS:
		if within_docking_range(chart,navigation,id):return id
	return ""


static func land_polygon() -> PackedVector2Array:
	# Local 900x560 island scene. The southwest beach contains land_entry().
	return PackedVector2Array([
		Vector2(144, 320), Vector2(176, 224), Vector2(256, 160),
		Vector2(336, 112), Vector2(448, 96), Vector2(544, 128),
		Vector2(640, 144), Vector2(736, 224), Vector2(784, 320),
		Vector2(752, 400), Vector2(656, 448), Vector2(560, 480),
		Vector2(416, 464), Vector2(320, 496), Vector2(224, 448),
		Vector2(176, 400),
	])


static func land_bounds() -> Rect2:
	return Rect2(144, 96, 640, 400)


static func land_entry() -> Vector2:
	return LAND_SPOTS.dock


static func land_contains(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, land_polygon())


static func land_walkable(point: Vector2) -> bool:
	return DOCK_RECT.has_point(point) or land_contains(point)


static func island_world_radius() -> float:
	return ISLAND_WORLD_RADIUS


extends RefCounted
## Original atlas pixels, shared geometry and bounded crops. See vendor source manifest.
const Farming = preload("res://scripts/farming.gd")
const SEASONS := ["spring", "summer", "fall", "winter"]
const ROOT := "res://assets/vendor/stardew-island/"
const SOURCES := {
	"greenhouse": preload(ROOT + "Greenhouse.png"),
	"spring": preload(ROOT + "spring_outdoorsTileSheet.png"),
	"summer": preload(ROOT + "summer_outdoorsTileSheet.png"),
	"fall": preload(ROOT + "fall_outdoorsTileSheet.png"),
	"winter": preload(ROOT + "winter_outdoorsTileSheet.png"),
	"town_spring": preload(ROOT + "spring_town.png"),
	"town_summer": preload(ROOT + "summer_town.png"),
	"town_fall": preload(ROOT + "fall_town.png"),
	"town_winter": preload(ROOT + "winter_town.png"),
	"tree_spring": preload(ROOT + "tree1_spring.png"),
	"tree_summer": preload(ROOT + "tree1_summer.png"),
	"tree_fall": preload(ROOT + "tree1_fall.png"),
	"tree_winter": preload(ROOT + "tree1_winter.png"),
	"cabin": preload(ROOT + "Log Cabin.png"),
	"fence": preload(ROOT + "Fence1.png"),
	"grass": preload(ROOT + "grass.png"),
	"soil": preload(ROOT + "hoeDirt.png"),
	"crops": preload(ROOT + "crops.png"),
	"objects": preload(ROOT + "springobjects.png"),
}
const REGIONS := {
	"ground": Rect2i(64, 208, 16, 16), "dirt": Rect2i(16, 144, 16, 16),
	"water": Rect2i(144, 208, 16, 16), "paving": Rect2i(80, 336, 16, 16),
	"tree": Rect2i(0, 0, 48, 96), "stump": Rect2i(16, 144, 16, 16),
	"cabin": Rect2i(0, 0, 80, 112), "house": Rect2i(0, 0, 112, 144),
	"townhall": Rect2i(128, 0, 128, 176),
	"fence_h": Rect2i(16, 64, 16, 32), "fence_v": Rect2i(0, 288, 16, 32),
}
# Source ids describe artwork only. Tidehaven's recipes and crop timing stay independent.
const OBJECTS := {"stone": 343, "ore": 751, "branch": 294, "fiber": 674, "dig_seed": 590, "dig_treasure": 590,"mushroom":404}
const CROP_ROWS := {"seed": 0, "summer_seed": 15, "autumn_seed": 18, "winter_seed": 23}
const CROP_LAST := {"seed": 5, "summer_seed": 6, "autumn_seed": 6, "winter_seed": 3}
const TREE_SCALE := 2.0
const TREE_FOOT := Vector2(24, 84)
const BUILDINGS := {
	"greenhouse": {"source":"greenhouse","region":Rect2i(0,160,112,160),"foot":Vector2(56,160),"scale":2.0},
	"townhall": {"source": "town", "region": Rect2i(128, 0, 128, 176), "foot": Vector2(64, 176), "scale": 2.0, "outline": [Vector2(0,66),Vector2(48,12),Vector2(72,12),Vector2(128,66),Vector2(128,176),Vector2(0,176)]},
	"east_house": {"source": "cabin", "region": Rect2i(0, 0, 80, 96), "foot": Vector2(40,96), "scale": 2.0},
	"orchard_house": {"source": "cabin", "region": Rect2i(160, 0, 80, 96), "foot": Vector2(40,96), "scale": 2.0},
}
const DOORS := {"townhall": Rect2i(176,144,16,32), "east_house": Rect2i(32,64,16,32), "orchard_house": Rect2i(192,64,16,32)}
const DOOR_RECT := Rect2(-16,-64,32,64)
const CROP_RECT := Rect2(-16, -48, 32, 64)
const RESOURCE_RECT := Rect2(-16, -24, 32, 32)
static var _cache: Dictionary = {}
static var _images: Dictionary = {}

static func season(day: int) -> String:
	return SEASONS[Farming.season(day)]

static func region(source: String, rect: Rect2i, repeatable := false) -> Texture2D:
	var key := source + str(rect) + str(repeatable)
	if not _cache.has(key):
		assert(SOURCES.has(source) and Rect2i(Vector2i.ZERO, Vector2i(SOURCES[source].get_size())).encloses(rect))
		if repeatable:
			if not _images.has(source):
				_images[source] = SOURCES[source].get_image()
			_cache[key] = ImageTexture.create_from_image(_images[source].get_region(rect))
		else:
			var atlas := AtlasTexture.new()
			atlas.atlas = SOURCES[source]
			atlas.region = Rect2(rect)
			atlas.filter_clip = true
			_cache[key] = atlas
	return _cache[key]

static func ground(key: String, day: int) -> Texture2D:
	# The winter dirt cell contains transition pixels, not a full repeatable surface.
	var source := "spring" if key == "dirt" and season(day) == "winter" else season(day)
	return region(source, REGIONS[key], true)

static func tree(day: int, active := true) -> Texture2D:
	return region("tree_" + season(day), REGIONS.tree if active else REGIONS.stump)

static func tree_rect(at: Vector2, active := true) -> Rect2:
	return Rect2((at - TREE_FOOT * TREE_SCALE).round(), Vector2(48, 96) * TREE_SCALE) if active else Rect2(at - Vector2(12, 18), Vector2(24, 24))

static func building_rect(id: String, at: Vector2) -> Rect2:
	var spec: Dictionary = BUILDINGS[id]
	return Rect2((at - Vector2(spec.foot) * float(spec.scale)).round(), Vector2(spec.region.size) * float(spec.scale))

static func fence_rect(at: Vector2, horizontal: bool) -> Rect2:
	return Rect2(at - Vector2(16 if horizontal else 4,48),Vector2(32,64))

static func object_texture(kind: String) -> Texture2D:
	var id: int = OBJECTS[kind]
	return region("objects", Rect2i((id % 24) * 16, (id / 24) * 16, 16, 16))

static func crop_region(crop: String, growth: int, dead: bool) -> Rect2i:
	if dead:
		return Rect2i(192, 384, 16, 32)
	var index: int = CROP_ROWS[crop]
	var last: int = CROP_LAST[crop]
	var days: int = Farming.CROPS[crop].days
	var stage := last if growth >= days else mini(last - 1, floori(float(maxi(growth, 0)) / days * last))
	return Rect2i((index % 2) * 128 + stage * 16, (index / 2) * 32, 16, 32)

static func crop(crop_id: String, growth: int, dead: bool) -> Texture2D:
	return region("crops", crop_region(crop_id, growth, dead))

static func soil(watered: bool,neighbors: int=0) -> Texture2D:
	var x:=0 if (neighbors & 3) == 0 else (1 if (neighbors & 1) == 0 else (3 if (neighbors & 2) == 0 else 2))
	var y:=3 if (neighbors & 12) == 0 else (0 if (neighbors & 4) == 0 else (2 if (neighbors & 8) == 0 else 1))
	return region("soil",Rect2i((64 if watered else 0)+x*16,y*16,16,16))

static func map_color(day: int) -> Color:
	return [Color("70a63d"), Color("66a548"), Color("c7924f"), Color("bccfdf")][Farming.season(day)]

static func ground_base(key: String, day: int) -> Color:
	if key == "ground":
		return [Color("80a858"),Color("6c9a51"),Color("bd935b"),Color("d4e2e6")][Farming.season(day)]
	return Color("bba475") if key == "dirt" else Color.WHITE

static func grass(day: int, variant: int) -> Texture2D:
	# Three 16-pixel tufts, then transparent padding. Row seven is cobwebs.
	var row: int = [0, 1, 2, 4][Farming.season(day)]
	return region("grass", Rect2i(posmod(variant, 3)*16, row*20, 16, 20))

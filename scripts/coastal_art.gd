extends RefCounted
## Generated original source PNGs stay untouched. Fixed crops and a logical pixel
## grid are display metadata, shared by world props and inventory illustrations.
## Generation records and source/region review: assets/coastal/PROMPTS.md.

const SOURCES := {
	"hatch": preload("res://assets/coastal/hatch-0.13.png"),
	"canopy": preload("res://assets/coastal/canopy-0.13.png"),
	"sea_chest": preload("res://assets/coastal/sea_chest-0.13.png"),
	"sea_chest_open": preload("res://assets/coastal/sea_chest-0.13.png"),
	"bed": preload("res://assets/coastal/bed.png"),
	"bedroll": preload("res://assets/coastal/bedroll.png"),
	"chest": preload("res://assets/coastal/chest.png"),
	"chest_open": preload("res://assets/coastal/chest_open.png"),
	"barrel": preload("res://assets/coastal/barrel.png"),
	"purifier": preload("res://assets/coastal/purifier.png"),
	"grill": preload("res://assets/coastal/grill.png"),
	"wood": preload("res://assets/coastal/wood.png"),
	"leaf": preload("res://assets/coastal/leaf.png"),
	"plastic": preload("res://assets/coastal/plastic.png"),
	"scrap": preload("res://assets/coastal/scrap.png"),
}
const REGIONS := {
	"hatch": Rect2i(300, 310, 420, 890),
	"canopy": Rect2i(210, 378, 665, 718),
	"sea_chest": Rect2i(138, 540, 564, 366),
	"sea_chest_open": Rect2i(883, 382, 580, 524),
	"bed": Rect2i(71, 65, 830, 1496),
	"bedroll": Rect2i(39, 197, 915, 1307),
	"chest": Rect2i(248, 234, 962, 614),
	"chest_open": Rect2i(260, 95, 932, 777),
	"barrel": Rect2i(231, 215, 720, 918),
	"purifier": Rect2i(168, 133, 939, 972),
	"grill": Rect2i(232, 363, 866, 566),
	"wood": Rect2i(283, 214, 898, 665),
	"leaf": Rect2i(107, 88, 937, 1303),
	"plastic": Rect2i(157, 205, 856, 1039),
	"scrap": Rect2i(153, 131, 1060, 884),
}
const WIDTHS := {"hatch": 12, "canopy": 16, "sea_chest": 24, "sea_chest_open": 24, "bed": 32, "bedroll": 32, "chest": 32, "chest_open": 32, "barrel": 28, "purifier": 36, "grill": 36, "wood": 32, "leaf": 24, "plastic": 24, "scrap": 28}
const ALIASES := {"treasure": "chest", "kitchen": "grill"}
static var _cache: Dictionary = {}

static func has(key: String) -> bool:
	return SOURCES.has(str(ALIASES.get(key, key)))

static func texture(key: String) -> Texture2D:
	key = str(ALIASES.get(key, key))
	if not SOURCES.has(key):
		return null
	if not _cache.has(key):
		var bitmap: Image = SOURCES[key].get_image()
		if bitmap.is_compressed():
			bitmap.decompress()
		bitmap = bitmap.get_region(REGIONS[key])
		var width: int = WIDTHS[key]
		var height := roundi(float(bitmap.get_height()) * width / bitmap.get_width())
		bitmap.resize(width, height, Image.INTERPOLATE_NEAREST)
		# Fractional-alpha fringe in a large draft must not become a halo on water.
		# Preserve every solid interior colour; quantise only the display alpha.
		for y in height:
			for x in width:
				var color := bitmap.get_pixel(x, y)
				color.a = 1.0 if color.a >= (0.96 if key in ["hatch", "canopy", "sea_chest", "sea_chest_open"] else 0.5) else 0.0
				bitmap.set_pixel(x, y, color)
		_cache[key] = ImageTexture.create_from_image(bitmap)
	return _cache[key]

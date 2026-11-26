extends RefCounted
## Original coastal sprites, licensed Kenney/Yapi fallbacks and fixed-grid tools.
## Coordinates were selected from the actual source images, not inferred names.

const TOWN: Texture2D = preload("res://assets/vendor/tiny-town/Tilemap_tilemap_packed.png")
const DUNGEON: Texture2D = preload("res://assets/vendor/tiny-dungeon/Tilemap_tilemap_packed.png")
const FARM: Texture2D = preload("res://assets/vendor/tiny-farm/Tilemap_tilemap_packed.png")
const CRAFTABLES: Texture2D = preload("res://assets/vendor/stardew-island/Craftables.png")
const PropArt = preload("res://scripts/prop_art.gd")
const SurvivalArt = preload("res://scripts/survival_art.gd")
const CoastalArt = preload("res://scripts/coastal_art.gd")

# Rendering budgets only; do not change placement cells, collisions or saves.
# Each family locks its contact point across states. A bag lies flat, so its
# foot reaches the cell's near edge; raised furniture rests nearer the centre.
const WORLD_PROPS := {
	"cabin":{"box":Vector2(224,256),"contact_y":32.0,"anchor_x":144.0},
	"sea_chest": {"box": Vector2(48, 32), "contact_y": 16.0},
	"sea_chest_open": {"box": Vector2(48, 46), "contact_y": 16.0},
	"canopy": {"box": Vector2(32, 38), "contact_y": 16.0},
	"workbench": {"box": Vector2(32, 54), "contact_y": 18.0},
	"bedroll": {"box": Vector2(46, 64), "contact_y": 30.0},
	"bed": {"box": Vector2(44, 76), "contact_y": 30.0},
	"chest": {"box": Vector2(42, 36), "contact_y": 16.0},
	"chest_open": {"box": Vector2(42, 44), "contact_y": 16.0},
	"treasure": {"box": Vector2(42, 36), "contact_y": 16.0},
	"barrel": {"box": Vector2(30, 38), "contact_y": 18.0},
	"purifier": {"box": Vector2(48, 50), "contact_y": 18.0},
	"grill": {"box": Vector2(46, 36), "contact_y": 17.0},
	"kitchen": {"box": Vector2(46, 36), "contact_y": 17.0},
	"furnace": {"box": Vector2(32, 64), "contact_y": 18.0},
	"furnace_active": {"box": Vector2(32, 64), "contact_y": 18.0},
	"garden": {"box": Vector2(32, 96), "contact_y": 16.0},
	"garden_empty": {"box": Vector2(32, 96), "contact_y": 16.0},
	"garden_growing": {"box": Vector2(32, 96), "contact_y": 16.0},
	"orders": {"box": Vector2(32, 64), "contact_y": 16.0},
	"hatch": {"box": Vector2(24, 52), "contact_y": 16.0},
}

static func fitted_size(key: String, box: Vector2) -> Vector2:
	var image: Texture2D = texture(key)
	if image == null:
		return Vector2.ZERO
	var source := image.get_size()
	return source * minf(box.x / source.x, box.y / source.y)

static func world_rect(key: String, at: Vector2) -> Rect2:
	var spec: Dictionary = WORLD_PROPS.get(key, {"box": Vector2(40, 40), "contact_y": 16.0})
	var extent := fitted_size(key, spec.box)
	return Rect2(Vector2(at.x - float(spec.get("anchor_x",extent.x*0.5)), at.y + float(spec.contact_y) - extent.y).round(), extent)

# Original individual PNGs from Yapi's CC0 pack, with no pixel changes.
# Unreplaced items use this fallback mapping; CoastalArt takes precedence.
const MATERIAL_ICONS := {
	"wood": preload("res://assets/vendor/material-pack-yapi/icons/wood.png"),
	"plastic": preload("res://assets/vendor/material-pack-yapi/icons/plastic.png"),
	"scrap": preload("res://assets/vendor/material-pack-yapi/icons/junk parts.png"),
	"rope": preload("res://assets/vendor/material-pack-yapi/icons/rope.png"),
	"hammer": preload("res://assets/vendor/material-pack-yapi/icons/hammer.png"),
}

const REGIONS := {
	"floor": ["farm", 7, 8], "floor_alt": ["farm", 7, 9],
	"chest": ["dungeon", 6, 7], "chest_open": ["dungeon", 8, 7],
	"treasure": ["dungeon", 5, 7], "barrel": ["farm", 1, 7],
	"bedroll": ["dungeon", 4, 0], "bed": ["dungeon", 4, 0, 1, 2],
	"purifier": ["town", 8, 8], "grill": ["dungeon", 7, 2],
	"fire": ["dungeon", 9, 10], "hatch": ["town", 7, 8],
	"garden": ["farm", 11, 4], "garden_empty": ["farm", 4, 6],
	"garden_growing": ["farm", 11, 1], "orders": ["town", 11, 6],
	"kitchen": ["dungeon", 7, 2], "plant": ["farm", 6, 6],
	"seaweed": ["farm", 8, 6], "rock": ["farm", 5, 7],
	"tree": ["town", 4, 0, 1, 2],
	"wood": ["farm", 2, 1], "leaf": ["farm", 5, 2],
	"plastic": ["dungeon", 5, 9], "scrap": ["farm", 5, 7],
	"rope": ["dungeon", 8, 4], "cup": ["town", 10, 10],
	"saltwater": ["town", 11, 10], "freshwater": ["dungeon", 8, 9],
	"veg": ["farm", 8, 4], "seed": ["farm", 9, 4],
	"meal": ["dungeon", 2, 6], "hook": ["town", 9, 8],
	"rod": ["town", 9, 8], "hammer": ["farm", 3, 7],
	"coin": ["town", 9, 7], "fish": ["original", 0, 0],
	"cooked_fish": ["original", 0, 0],
}

const ROPE_PIXELS := [
	"................",
	".....ooooo......",
	"...oohhlltoo....",
	"..ohltooollto...",
	".ohlt.....olto..",
	".olto.....ohlo..",
	".ohlo.....olto..",
	".olto.....ohlo..",
	".ohlo.....olto..",
	".olto.....ohlo..",
	"..olto...olto...",
	"..ohltooollto...",
	"...ottllhtoo....",
	".....oooottlo...",
	".........otllo..",
	"..........oooo..",
]

const CUP_PIXELS := [
	"................",
	"................",
	"..ooooooooo.....",
	"..ohwwwwwso.....",
	"..ohwggwwso.....",
	"..ohhhhhhsoooo..",
	"..ohbbbbbsohho..",
	"..ohbbbbbso..o..",
	"..ohbbbbbso..o..",
	"..ohbbbbbsohho..",
	"..ohbbbbbsoooo..",
	"..ohbbbbbso.....",
	"...ohbbbsso.....",
	"....oooooo......",
	"................",
	"................",
]

const ROD_PIXELS := [
	"................",
	"..........ooo...",
	".........othol..",
	"........otho.l..",
	"........oto..l..",
	".......otho..l..",
	"......otho...l..",
	"......oto....l..",
	".....otho....l..",
	"....otho.....l..",
	"...ooro......l..",
	"..otorr.....obo.",
	"..otro......obo.",
	".oto........olo.",
	".oo.........oo..",
	"................",
]

const SURVIVAL_ICONS := {
	"harpoon": {
		"pixels": [
			"................",
			"............h...",
			".........h.hhho.",
			".........h.hhmo.",
			".........hhhm.o.",
			"........ohhmmoo.",
			".......ottho....",
			"......ottho.....",
			".....ottho......",
			"....ottho.......",
			"...ottho........",
			"..ottho.........",
			".ottho..........",
			".otlo...........",
			"..oo............",
			"................",
		],
		"colors": {"o": Color("596c67"), "h": Color("d1ddd0"), "m": Color("8baba7"), "t": Color("b28d62"), "l": Color("d4ba8b")},
	},
	"compass": {
		"pixels": [
			"......oooo......",
			".....ohhhto.....",
			"...oohlllltoo...",
			"..ohhllllllhto..",
			".ohllllrlllllto.",
			".ohlllrrlllllto.",
			"ohlwwlrrllwwllto",
			"ohllllrrrlllllto",
			"ohlllllbblllllto",
			"ohlwwllbbllwwlto",
			".otllllbbllllto.",
			".otllllblllllto.",
			"..otllllllllto..",
			"...ottlllttto...",
			".....oooooo.....",
			"................",
		],
		"colors": {"o": Color("817963"), "h": Color("dcc69a"), "t": Color("b49e75"), "l": Color("e8e0bc"), "r": Color("b86c56"), "b": Color("67999b"), "w": Color("9baa91")},
	},
	"leaf": {
		"pixels": [
			"................",
			"............ho..",
			"........h..hso..",
			"......h.hs.hso..",
			".....hsmhshtso..",
			"....ohsmmhtsoo..",
			"...ohhsmhtsmso..",
			"..ohhsmmtsmmho..",
			".ohhmmmtsmmhso..",
			"..osmmtmmmhso...",
			"...omtmmsso.....",
			"..ootmmso.......",
			"..otsso.........",
			".oto............",
			".oo.............",
			"................",
		],
		"colors": {"o": Color("35453c"), "h": Color("a5b969"), "m": Color("778e53"), "s": Color("53684b"), "t": Color("c5b679")},
	},
	"paddle": {
		"pixels": [
			"................",
			"...........oo...",
			"..........ohso..",
			".........ohso...",
			"........ohso....",
			".......ohso.....",
			"......ohso......",
			".....ohtso......",
			"...oohtso.......",
			"..ohhttso.......",
			".ohhttso........",
			".ohttso.........",
			".ottso..........",
			"..oso...........",
			"...o............",
			"................",
		],
		"colors": {"o": Color("463e35"), "h": Color("c5b38a"), "t": Color("a08a67"), "s": Color("76634c")},
	},
	"anchor": {
		"pixels": [
			"......oooo......",
			".....othhto.....",
			".....ot..to.....",
			".....ot..to.....",
			"......otto......",
			".......to.......",
			"...oooooooooo...",
			"..ohhhhthhhmmo..",
			"..ohmmmtmmmsoo..",
			"...omthtmtsso...",
			"...ommtmtsmso...",
			"....ommtmsso....",
			"....omtmtsso....",
			".....oooooo.....",
			"................",
			"................",
		],
		"colors": {"o": Color("3c4241"), "h": Color("bdc2b5"), "m": Color("84968e"), "s": Color("596f68"), "t": Color("baa174")},
	},
	"fins": {
		"pixels": [
			"................",
			"...ooo...ooo....",
			"..otsto.otsto...",
			"..ototo.ototo...",
			"..otsto.otsto...",
			"..olhlo.olhlo...",
			"..olhlo.olhlo...",
			".ollhlo.olhllo..",
			".olhhlo.olhhlo..",
			".ollhlo.olhllo..",
			"olllhlo.olhlllo.",
			"olllhlo.olhlllo.",
			"olhhhlo.olhhhlo.",
			"ottttto.ottttto.",
			".ooooo...ooooo..",
			"................",
		],
		"colors": {"o": Color("284e4a"), "s": Color("284139"), "t": Color("397b69"), "l": Color("51aa8e"), "h": Color("91d2af")},
	},
	"reinforced_hook": {
		"pixels": [
			"....oooo........",
			"...othhto.......",
			"...otooto.......",
			"....otto........",
			".....oto........",
			".....oto........",
			".....oto........",
			"....omho........",
			"....omho....oo..",
			"....omho...ohho.",
			"....omho....omo.",
			"....omho....omo.",
			"....omhhhoohhmo.",
			".....ommhhhhmo..",
			"......ommmmoo...",
			".......oooo.....",
		],
		"colors": {"o": Color("414b4b"), "t": Color("bd955e"), "h": Color("d8e7d9"), "m": Color("899da0")},
	},
}

static var _cache: Dictionary = {}


static func texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var source: Texture2D = source_texture(key)
	if source == null:
		return null
	if key in ["floor", "floor_alt", "foundation"]:
		_cache[key] = source
		return source
	# The one presentation exit shared by world, inventory, recipes and previews.
	# Yapi's supplied 32px files use two pixels for each original 16px pixel.
	var material_key: String = str({"harpoon": "reinforced_hook", "axe": "stone", "pickaxe": "stone", "compass": "anchor"}.get(key, key))
	_cache[key] = PropArt.adapt(source, material_key, 2 if MATERIAL_ICONS.has(key) and not CoastalArt.has(key) and not SurvivalArt.has(key) else 1)
	return _cache[key]


static func keys() -> Array[String]:
	# Stable exhaustive list for state galleries and catalog coverage checks.
	var result: Array[String] = []
	for group: Dictionary in [REGIONS, MATERIAL_ICONS, SURVIVAL_ICONS]:
		for key in group:
			if str(key) not in result:
				result.append(str(key))
	result.append("foundation")
	result.append("workbench")
	result.append("cabin")
	for key in SurvivalArt.keys()+CoastalArt.SOURCES.keys():
		if key not in result: result.append(key)
	result.sort()
	return result


static func source_texture(key: String) -> Texture2D:
	if key=="cabin":
		var atlas:=AtlasTexture.new()
		atlas.atlas=preload("res://assets/vendor/stardew-island/spring_town.png")
		atlas.region=Rect2(0,512,112,128)
		return atlas
	if SurvivalArt.has(key):
		return SurvivalArt.texture(key)
	if key == "workbench":
		var station := AtlasTexture.new()
		station.atlas = CRAFTABLES
		# Native index 208, eight columns, 16x32. Trim only five transparent rows.
		station.region = Rect2(0, 837, 16, 27)
		return station
	# Logical source before edge treatment; full generated PNGs stay in assets/coastal.
	if CoastalArt.has(key):
		return CoastalArt.texture(key)
	if key in ["floor", "floor_alt", "foundation"]:
		return PropArt.floor_texture(key == "floor_alt")
	if key == "hook":
		return _pixel_texture(SURVIVAL_ICONS.reinforced_hook.pixels, {
			"o": Color("687971"), "t": Color("b59971"), "h": Color("b8c7ae"), "m": Color("829384"),
		})
	if MATERIAL_ICONS.has(key):
		return MATERIAL_ICONS[key]
	if SURVIVAL_ICONS.has(key):
		var art: Dictionary = SURVIVAL_ICONS[key]
		return _pixel_texture(art.pixels, art.colors)
	if key in ["cup", "saltwater", "freshwater", "rod"]:
		return _tool_texture(key)
	if not REGIONS.has(key):
		return null
	var region: Array = REGIONS[key]
	var atlas := AtlasTexture.new()
	atlas.atlas = {"town": TOWN, "dungeon": DUNGEON, "farm": FARM}[region[0]]
	var width: int = int(region[3]) if region.size() > 3 else 1
	var height: int = int(region[4]) if region.size() > 4 else 1
	atlas.region = Rect2(int(region[1]) * 16, int(region[2]) * 16, width * 16, height * 16)
	atlas.filter_clip = true
	return atlas


static func item_icon(item: String) -> Texture2D:
	return texture("floor" if item == "foundation" else item)


static func _tool_texture(item: String) -> Texture2D:
	if item == "rope":
		return _pixel_texture(ROPE_PIXELS, {
			"o": Color("76553c"), "h": Color("ffe3ad"), "l": Color("d1ac70"), "t": Color("a37a4d"),
		})
	if item == "rod":
		return _pixel_texture(ROD_PIXELS, {
			"o": Color("59483d"), "t": Color("d4ae70"), "h": Color("f4dfae"),
			"l": Color("cfddd1"), "b": Color("c96d53"), "r": Color("8da69d"),
		})
	# One handled ceramic cup silhouette makes the reusable vessel recognisable.
	var colors := {
		"o": Color("5c4a3c"), "h": Color("fff5d5"), "b": Color("e8d0a4"), "s": Color("bca078"),
		"w": Color("978771"), "g": Color("b6a58b"),
	}
	if item == "saltwater":
		colors["w"] = Color("396b91")
		colors["g"] = Color("76a9c5")
	elif item == "freshwater":
		colors["w"] = Color("69c4ca")
		colors["g"] = Color("e4fff0")
	return _pixel_texture(CUP_PIXELS, colors)


static func _pixel_texture(pixels: Array, colors: Dictionary) -> Texture2D:
	var bitmap := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	bitmap.fill(Color.TRANSPARENT)
	for y in 16:
		for x in 16:
			var code: String = pixels[y].substr(x, 1)
			if colors.has(code):
				bitmap.set_pixel(x, y, colors[code])
	return ImageTexture.create_from_image(bitmap)

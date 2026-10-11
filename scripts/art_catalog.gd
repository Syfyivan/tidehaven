extends RefCounted
## Kenney / Yapi CC0 art, with original fixed-grid tools and survival icons.
## Coordinates were selected from the actual source images, not inferred names.

const TOWN: Texture2D = preload("res://assets/vendor/tiny-town/Tilemap_tilemap_packed.png")
const DUNGEON: Texture2D = preload("res://assets/vendor/tiny-dungeon/Tilemap_tilemap_packed.png")
const FARM: Texture2D = preload("res://assets/vendor/tiny-farm/Tilemap_tilemap_packed.png")
const PropArt = preload("res://scripts/prop_art.gd")

# Original individual PNGs from Yapi's CC0 pack, with no pixel changes.
# Both world props and inventory/crafting use this single item mapping.
const MATERIAL_ICONS := {
	"wood": preload("res://assets/vendor/material-pack-yapi/icons/wood.png"),
	"plastic": preload("res://assets/vendor/material-pack-yapi/icons/plastic.png"),
	"scrap": preload("res://assets/vendor/material-pack-yapi/icons/junk parts.png"),
	"rope": preload("res://assets/vendor/material-pack-yapi/icons/rope.png"),
	"stone": preload("res://assets/vendor/material-pack-yapi/icons/rock.png"),
	"ingot": preload("res://assets/vendor/material-pack-yapi/icons/steel.png"),
	"fish": preload("res://assets/vendor/material-pack-yapi/icons/fish.png"),
	"seed": preload("res://assets/vendor/material-pack-yapi/icons/seed.png"),
	"veg": preload("res://assets/vendor/material-pack-yapi/icons/carrot.png"),
	"meal": preload("res://assets/vendor/material-pack-yapi/icons/stew.png"),
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
	"axe": {
		"pixels": [
			"................",
			".........oooo...",
			"........ohhhmo..",
			".......ohhmmmo..",
			"......othmmmmo..",
			".....ottrmmsso..",
			".....otlrssso...",
			"....otltoooo....",
			"...otlto........",
			"...otto.........",
			"..otlto.........",
			".otlto..........",
			".otto...........",
			".oto............",
			"..o.............",
			"................",
		],
		"colors": {"o": Color("676e60"), "h": Color("cbd0b8"), "m": Color("a5ad9a"), "s": Color("818d7d"), "t": Color("b08a5d"), "l": Color("d5b783"), "r": Color("e1c79a")},
	},
	"pickaxe": {
		"pixels": [
			"................",
			".....oooooo.....",
			"...oohhhmmmoo...",
			"..ohhmmrmmmso...",
			".ohmsooorrmsso..",
			".omso..otlmosso.",
			".oso..otlto.oso.",
			"..o...otto...oo.",
			".....otlto....o.",
			"....otlto.......",
			"....otto........",
			"...otlto........",
			"..otlto.........",
			"..otto..........",
			"...oo...........",
			"................",
		],
		"colors": {"o": Color("676e60"), "h": Color("cbd0b8"), "m": Color("a5ad9a"), "s": Color("818d7d"), "t": Color("b08a5d"), "l": Color("d5b783"), "r": Color("e1c79a")},
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
	"stone": {
		"pixels": [
			"................",
			"................",
			"......ooo.......",
			"....oohhhoo.....",
			"...ohhhmmhho....",
			"..ohhmmmmmmho...",
			"..ohmmmsmmmmo...",
			".ohmmmssmmmmoo..",
			".ohmmssssmmmoo..",
			".ommmssssssmmo..",
			"..omsssssssso...",
			"..ossssssssso...",
			"...ooooooooo....",
			"................",
			"................",
			"................",
		],
		"colors": {"o": Color("55504c"), "h": Color("b9ad95"), "m": Color("92897b"), "s": Color("6e6a61")},
	},
	"ore": {
		"pixels": [
			"................",
			"........oo......",
			".....ooohto.....",
			"...oohhrrhho....",
			"...omrrrtmmho...",
			"..ohmtrmmmmmo...",
			"..ohmmrmmmroo...",
			".ohmmmrtmrrmmo..",
			".ohmrrrttrmmmo..",
			".ommrttmmmrmmo..",
			"..omrrmmmrrso...",
			"..osmmrrrssso...",
			"...ooooooooo....",
			"................",
			"................",
			"................",
		],
		"colors": {"o": Color("454c4c"), "h": Color("a1a79d"), "m": Color("777f79"), "s": Color("535f59"), "r": Color("b96d3e"), "t": Color("e5ad62")},
	},
	"ingot": {
		"pixels": [
			"................",
			"................",
			"................",
			".....ooooooooo..",
			"....ohhhhhhhho..",
			"...ohhhllllhmo..",
			"..ohhllllllmmo..",
			".ohhhhhhhhmmo...",
			".ommmmmmmmsso...",
			".ommmmmmmssso...",
			"..osssssssso....",
			"...oooooooo.....",
			"................",
			"................",
			"................",
			"................",
		],
		"colors": {"o": Color("3d525b"), "h": Color("d2e3da"), "l": Color("9abcc5"), "m": Color("638796"), "s": Color("436271")},
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
	"furnace": {
		"pixels": [
			".........oooo...",
			".........ohso...",
			".........omso...",
			".........omso...",
			"....oooooomsoo..",
			"...ohhhhmmmsmmo.",
			"..ohhmmommmmomo.",
			"..ohmmmommmmomo.",
			"..ohmmoooooommo.",
			"..ohmohxxxhommso",
			"..omohxxxxxhomo.",
			"..omohxxxxxhomo.",
			"..ommooooooommo.",
			"..ossssssssssso.",
			"...ooo....ooo...",
			"................",
		],
		"colors": {"o": Color("4d4845"), "h": Color("c3ae92"), "m": Color("96826e"), "s": Color("705e51"), "x": Color("272d2c")},
	},
}

const FARM_PIXELS := {
	"hoe": ["................", "................", "...mmmmmm.......", "...mhhhmm.......", "...mmmmt........", ".......tt.......", ".......tt.......", ".......tt.......", ".......tt.......", ".......tt.......", ".......tt.......", ".......tt.......", ".......tt.......", ".......tt.......", "................", "................"],
	"scythe": ["................", ".....mmmm.......", "...mmhhhmm......", "..mm.....mm.....", "..m.......mt....", "..........tt....", ".........tt.....", "........tt......", ".......tt.......", "......tt........", ".....tt.........", "....tt..........", "...tt...........", "..tt............", "................", "................"],
	"watering_can": ["................", "................", "......tttt......", ".....tt..tt.....", ".....t....t.....", ".....mmmmmm.....", ".....mwwwwm.....", ".....mwhwwm...mm", ".....mwhwwm..mmm", "...mmmwwwwmmmm..", "...m.mwwwwmmm...", "...mmmwwwwm.....", ".....mmmmmm.....", "................", "................", "................"],
	"canopy": ["................", ".....mmmmmm.....", "...mmhhhhhhmm...", "..mhhhhhhhhhhm..", "..mhhhhhhhhhhm..", ".mhhmhmmmhmhhhm.", ".mhhmhhhhhmhhhm.", ".mhhmhhhhhmhhhm.", ".mhhmhhhhhmhhhm.", ".mhhmhhhhhmhhhm.", ".mhhmhhhhhmhhhm.", ".mhhmhhhhhmhhhm.", ".mmmmmmmmmmmmmm.", ".tttttttttttttt.", "................", "................"],
	"fiber": ["................", "....s......s....", ".....s....s.....", ".....ss..ss.....", "...s.sssss......", "....ssssss.s....", ".....ssssss.....", "....sssssss.....", ".....sttts......", ".....sttts......", ".....sssss......", "....ss.s.ss.....", "....s..s..s.....", "...s...s...s....", "................", "................"],
	"seeds": ["................", "................", "...tttttttttt...", "...thhhhhhhht...", "...thhhhhhhht...", "...thhsssshht...", "...thsshhssht...", "...thsshhssht...", "...thhsssshht...", "...thhhhhhhht...", "...thhhhhhhht...", "...thhhhhhhht...", "...tttttttttt...", "................", "................", "................"],
}
static var _cache: Dictionary = {}


static func texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var source: Texture2D = source_texture(key)
	if source == null:
		return null
	# The one presentation exit shared by world, inventory, recipes and previews.
	# Yapi's supplied 32px files use two pixels for each original 16px pixel.
	var material_key: String = str({"harpoon": "reinforced_hook", "axe": "stone", "pickaxe": "stone", "compass": "anchor"}.get(key, key))
	_cache[key] = PropArt.adapt(source, material_key, 2 if MATERIAL_ICONS.has(key) else 1)
	return _cache[key]


static func keys() -> Array[String]:
	# Stable exhaustive list for state galleries and catalog coverage checks.
	var result: Array[String] = []
	for group: Dictionary in [REGIONS, MATERIAL_ICONS, SURVIVAL_ICONS, FARM_PIXELS, {"summer_seed": 1, "autumn_seed": 1, "winter_seed": 1}]:
		for key in group:
			if str(key) not in result:
				result.append(str(key))
	result.append("foundation")
	result.sort()
	return result


static func source_texture(key: String) -> Texture2D:
	# Original texture access is for before/after inspection; gameplay uses texture.
	if FARM_PIXELS.has(key) or key in ["summer_seed", "autumn_seed", "winter_seed"]:
		var pixels: Array = FARM_PIXELS.get(key, FARM_PIXELS.seeds)
		return _pixel_texture(pixels, {"t": Color("aa8c63"), "m": Color("7c9690"), "h": Color("cdd6b3"), "w": Color("78a7ac"), "s": {"summer_seed": Color("d9bd69"), "autumn_seed": Color("c98658"), "winter_seed": Color("9bb7c9")}.get(key, Color("8ca76b"))})
	if key in ["floor", "floor_alt", "foundation"]:
		return PropArt.floor_texture(key == "floor_alt")
	if key == "bedroll":
		return PropArt.bedroll_texture()
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
	if key in ["fish", "cooked_fish"]:
		return _fish_texture(key == "cooked_fish")
	var region: Array = REGIONS[key]
	var atlas := AtlasTexture.new()
	atlas.atlas = {"town": TOWN, "dungeon": DUNGEON, "farm": FARM}[region[0]]
	var width: int = int(region[3]) if region.size() > 3 else 1
	var height: int = int(region[4]) if region.size() > 4 else 1
	atlas.region = Rect2(int(region[1]) * 16, int(region[2]) * 16, width * 16, height * 16)
	atlas.filter_clip = true
	return atlas


static func item_icon(item: String) -> Texture2D:
	return texture(item)


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


static func _fish_texture(cooked: bool) -> Texture2D:
	var pixels := [
		"................", "................", "......oo........", ".....ottto......",
		".oo.ottlltooo...", ".otoolllllltto..", "..otllllllllxto.", "...olllllllwwto.",
		"..otttlllllwwto.", ".ottottttlltoo..", ".oo..otttooo....", "......oo........",
		"................", "................", "................", "................",
	]
	var colors := {
		"o": Color("#493b46"), "t": Color("#c88d63") if cooked else Color("#639aa3"),
		"l": Color("#efb578") if cooked else Color("#9ac9bf"),
		"w": Color("#ffe0a1") if cooked else Color("#d7e7c3"), "x": Color("#241f31"),
	}
	return _pixel_texture(pixels, colors)


static func _pixel_texture(pixels: Array, colors: Dictionary) -> Texture2D:
	var bitmap := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	bitmap.fill(Color.TRANSPARENT)
	for y in 16:
		for x in 16:
			var code: String = pixels[y].substr(x, 1)
			if colors.has(code):
				bitmap.set_pixel(x, y, colors[code])
	return ImageTexture.create_from_image(bitmap)

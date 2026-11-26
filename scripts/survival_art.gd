extends RefCounted
## Original licensed atlas cells, selected against upstream data and real pixels.
## No gameplay IDs, times, prices or footprints are imported from the reference.
const ROOT := "res://assets/vendor/stardew-island/"
const SOURCES := {
	"tools": preload(ROOT + "tools.png"),
	"weapons": preload(ROOT + "weapons.png"),
	"objects": preload(ROOT + "springobjects.png"),
	"craftables": preload(ROOT + "Craftables.png"),
	"crops": preload(ROOT + "crops.png"),
	"aquarium": preload(ROOT + "AquariumFish.png"),
}
const OBJECT_IDS := {"mushroom":404,"rice":423,"seaweed":152,"sashimi":227,"maki":228,"salad":196,"stone":390,"ore":378,"ingot":335,"fish":142,"cooked_fish":198,"meal":228,"veg":24,"seed":472,"seeds":472,"summer_seed":487,"autumn_seed":490,"winter_seed":498,"fiber":771}
const TOOL_IDS := {"axe":215,"pickaxe":131,"hoe":47,"watering_can":296}
const CRAFT_IDS := {"furnace":13,"furnace_active":14,"orders":37}
static var _cache: Dictionary = {}

static func keys() -> Array:
	return OBJECT_IDS.keys()+TOOL_IDS.keys()+CRAFT_IDS.keys()+["scythe","fish_swim","garden","garden_empty","garden_growing"]

static func has(key:String) -> bool:
	return key in keys()

static func cell(source:String,index:int,size:Vector2i=Vector2i(16,16)) -> Image:
	var image:Image=SOURCES[source].get_image()
	if image.is_compressed():image.decompress()
	var columns:int=image.get_width()/size.x
	return image.get_region(Rect2i((index%columns)*size.x,(index/columns)*size.y,size.x,size.y))

static func texture(key:String) -> Texture2D:
	if not has(key):return null
	if _cache.has(key):return _cache[key]
	var bitmap:Image
	if OBJECT_IDS.has(key):bitmap=cell("objects",OBJECT_IDS[key])
	elif TOOL_IDS.has(key):bitmap=cell("tools",TOOL_IDS[key])
	elif CRAFT_IDS.has(key):bitmap=cell("craftables",CRAFT_IDS[key],Vector2i(16,32))
	elif key=="scythe":bitmap=cell("weapons",47)
	elif key=="fish_swim":
		# Carp: AquariumFish[142] index 11. Each native row has 24px fish + 24px turn.
		bitmap=SOURCES.aquarium.get_image().get_region(Rect2i(264,0,24,24))
	else:
		# Same pot and base across all growth states. Plant sprouts from its soil.
		bitmap=Image.create(16,48,false,Image.FORMAT_RGBA8)
		bitmap.fill(Color.TRANSPARENT)
		var pot:=cell("craftables",62,Vector2i(16,32))
		bitmap.blend_rect(pot,Rect2i(0,0,16,32),Vector2i(0,16))
		if key!="garden_empty":
			var crop:=SOURCES.crops.get_image().get_region(Rect2i(80 if key=="garden" else 48,0,16,32))
			bitmap.blend_rect(crop,Rect2i(0,0,16,32),Vector2i(0,8))
	_cache[key]=ImageTexture.create_from_image(bitmap)
	return _cache[key]

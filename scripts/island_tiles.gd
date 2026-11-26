extends RefCounted
## Pinned TMX-derived cells, kept separate from host-owned gameplay state.
const ROOT := "res://assets/vendor/stardew-island/"
static var _maps: Dictionary = {}
static var _textures: Dictionary = {}
static var _tiles: Dictionary = {}
const FACADES := {
	"yard_home":{"map":"Town","cells":Rect2i(19,80,8,10),"foot":Vector2(1.5,9)},
	"mine_entrance":{"map":"Mountain","cells":Rect2i(51,2,7,4),"foot":Vector2(3.5,3),"layers":[]},
	"restaurant":{"map":"Town","cells":Rect2i(38,62,10,9),"foot":Vector2(7.5,9)},
	"market":{"map":"Town","cells":Rect2i(38,47,10,10),"foot":Vector2(6.5,10)},
	"clinic":{"map":"Town","cells":Rect2i(33,47,5,9),"foot":Vector2(3.5,9)},
	"smith":{"map":"Town","cells":Rect2i(90,76,8,7),"foot":Vector2(3.5,7)},
	"fishery":{"map":"Beach","cells":Rect2i(28,25,9,10),"foot":Vector2(2.5,10)},
	"farmhouse":{"map":"Town","cells":Rect2i(19,80,8,10),"foot":Vector2(5.5,10)},
	"carpenter":{"source":"spring_outdoorsTileSheet","region":Rect2(128,608,112,144),"foot":Vector2(3.5,9)},
	"bathhouse":{"source":"spring_outdoorsTileSheet","region":Rect2(0,848,256,192),"foot":Vector2(4.5,12)},
}

static func facade_rect(id: String,foot: Vector2) -> Rect2:
	var spec:Dictionary=FACADES[id]
	var size:Vector2=Vector2(spec.cells.size)*32 if spec.has("map") else Vector2(spec.region.size)*2
	return Rect2(foot-Vector2(spec.foot)*32,size)

static func draw_facade(canvas:CanvasItem,id:String,foot:Vector2,day:int,tint:Color) -> void:
	var spec:Dictionary=FACADES[id]
	var rect:=facade_rect(id,foot)
	if spec.has("map"):
		draw_patch(canvas,spec.map,spec.cells,rect.position,2.0,day,spec.get("layers",["Buildings","Buildings2","Front","AlwaysFront"]),tint,0.0,"spring_town" if spec.map=="Town" else "spring_beach" if spec.map=="Beach" else "")
	else:
		canvas.draw_texture_rect_region(texture(spec.source,day),rect,spec.region,tint)

static func map_data(name: String) -> Dictionary:
	if _maps.is_empty():
		_maps = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "maps/maps.json"))
		var interiors: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "maps/interiors.json"))
		if interiors is Dictionary:
			# Door leaves are open in Tidehaven; preserve jambs and the source TMX.
			for map: Dictionary in interiors.values():
				var doors := str(map.properties.get("Doors", "")).split(" ",false)
				for i in range(0,doors.size()-3,4):
					var x := int(doors[i]); var y := int(doors[i+1])
					if x<0 or y<0 or x>=int(map.width) or y>=int(map.height): continue
					for layer: Dictionary in map.layers:
						if layer.name == "Buildings": layer.cells[y*int(map.width)+x]=0
						if layer.name == "Front" and y>0: layer.cells[(y-1)*int(map.width)+x]=0
			_maps.merge(interiors)
	return _maps[name]

static func season(day: int) -> String:
	return ["spring", "summer", "fall", "winter"][posmod((day-1)/28,4)]

static func texture(source: String, day: int) -> Texture2D:
	var path := source.replace("spring_", season(day)+"_")
	if not _textures.has(path):
		_textures[path] = load(ROOT+path+".png")
	return _textures[path]

static func tile(map_name: String, gid: int) -> Dictionary:
	if gid == 0:
		return {}
	var key := map_name+":"+str(gid)
	if _tiles.has(key):
		return _tiles[key]
	var data := map_data(map_name)
	var selected: Dictionary = {}
	for sheet: Dictionary in data.tilesets:
		if int(sheet.first) <= gid:
			selected = sheet
	var index := gid-int(selected.first)
	var columns := int(selected.columns)
	var result := {"source":selected.source, "region":Rect2((index%columns)*16,(index/columns)*16,16,16), "properties":selected.properties.get(str(index),{}), "animation":selected.animations.get(str(index),[]), "index":index, "columns":columns}
	_tiles[key] = result
	return result

static func draw_patch(canvas: CanvasItem, name: String, cells: Rect2i, at: Vector2, scale_value: float = 2.0, day: int = 1, layer_names: Array = [], tint: Color = Color.WHITE, elapsed: float = 0.0, source_only: String = "") -> void:
	var data := map_data(name)
	var width := int(data.width)
	var height := int(data.height)
	for layer: Dictionary in data.layers:
		if str(layer.name)=="Paths" or (not layer_names.is_empty() and layer.name not in layer_names):
			continue
		for y in range(maxi(0,cells.position.y),mini(height,cells.end.y)):
			for x in range(maxi(0,cells.position.x),mini(width,cells.end.x)):
				var entry := tile(name,int(layer.cells[y*width+x]))
				if entry.is_empty() or (not source_only.is_empty() and entry.source!=source_only):
					continue
				var region: Rect2 = entry.region
				var animation: Array = entry.animation
				if not animation.is_empty():
					var total := 0
					for frame: Dictionary in animation: total += int(frame.duration)
					var tick := posmod(int(elapsed*1000),maxi(1,total))
					for frame: Dictionary in animation:
						tick -= int(frame.duration)
						if tick < 0:
							var index := int(frame.tileid)
							region.position=Vector2((index%int(entry.columns))*16,(index/int(entry.columns))*16)
							break
				var position := at+Vector2(Vector2i(x,y)-cells.position)*16*scale_value
				canvas.draw_texture_rect_region(texture(entry.source,day),Rect2(position,Vector2.ONE*16*scale_value),region,tint)

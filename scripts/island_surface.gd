extends RefCounted
## Native terrain edges over the existing island geometry; no random visual state.
const Map=preload("res://scripts/island_map.gd")
const Tiles=preload("res://scripts/island_tiles.gd")
const Art=preload("res://scripts/island_art.gd")
static var _cells: Dictionary={}
static var _river_shapes: Dictionary={}
static var _quarter_cache: Dictionary={}
static var _plaza_images: Dictionary={}
static var _plaza_masks: Dictionary={}
static var _plaza_edges: Dictionary={}
const PLAZA_EDGE_CELLS := {
	"nw":Vector2i(0,19),"n":Vector2i(1,19),"ne":Vector2i(2,19),
	"w":Vector2i(0,20),"e":Vector2i(2,20),
	"sw":Vector2i(0,21),"s":Vector2i(1,21),"se":Vector2i(2,21),
}
# Exact baked grass palette in the pinned spring Town edge cells. The same fixed
# silhouette masks the matching seasonal cells; no broad hue/alpha threshold.
const PLAZA_GRASS_COLORS := [0x44a318ff,0x70c725ff,0x328530ff,0x6bb724ff,0x3a9311ff,0x58ac14ff,0x0e5d3aff]
const TERRAIN_NEIGHBORS := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]
# Native atlas corners, ordered NW, NE, SW, SE. Source pixels remain untouched.
const CONCAVE_CELLS := {
	"dirt": [Vector2i(2,8),Vector2i(2,7),Vector2i(2,10),Vector2i(3,7)],
	"grass": [Vector2i(3,13),Vector2i(3,15),Vector2i(3,16),Vector2i(3,14)],
}

static func cell_kind(cell: Vector2i) -> String:
	if _cells.has(cell): return _cells[cell]
	var at:=Vector2(cell)*32+Vector2(16,16)
	var kind:=Map.terrain(at)
	if kind=="building": kind="grass"
	var pond:=Map._page_pond(Vector2i(Map.page_origin(at)/Map.PAGE))
	if not pond.is_empty() and Rect2(Vector2(pond.center)-Vector2(pond.radius),Vector2(pond.radius)*2).grow(32).has_point(at) and kind in ["water","sand"]:
		kind="grass"
	for feature:Dictionary in Map.WATER_FEATURES.values():
		if kind in ["water","sand"] and Rect2(feature.bounds).grow(32).has_point(at):
			if feature.has("center") or Map._feature_distance(at,feature)<float(feature.width)*0.5+32:
				kind="grass"
	if kind=="grass":
		# Road shoulders use native transition tiles; farming eligibility stays in Map.
		for offset in [Vector2(-24,0),Vector2(24,0),Vector2(0,-24),Vector2(0,24)]:
			if Map.terrain(at+offset)=="path":
				kind="path"
				break
	# A water sprite must never cover walkable feet, including bridge approaches.
	if kind=="water":
		for offset in [Vector2(-15,-15),Vector2(15,-15),Vector2(-15,15),Vector2(15,15),Vector2(-15,0),Vector2(15,0),Vector2(0,-15),Vector2(0,15)]:
			if Map.walkable(at+offset):
				kind="sand"
				break
	if _cells.size()>12000: _cells.clear()
	_cells[cell]=kind
	return kind

static func _dirt(cell: Vector2i) -> bool:
	return cell_kind(cell) in ["path","sand","bridge","water"]

static func _grass_patch(cell: Vector2i) -> bool:
	# A patch cannot continue through a road, bare bank or water drawn on the next cell.
	if cell_kind(cell)!="grass": return false
	var at:=Vector2(cell)*32
	return sin(at.x/137.0+sin(at.y/83.0))*0.7+cos(at.y/123.0+cos(at.x/191.0))*0.6>0.45

static func terrain_mask(cell: Vector2i, material: String) -> int:
	var mask := 0
	for index in TERRAIN_NEIGHBORS.size():
		var neighbor: Vector2i = cell + TERRAIN_NEIGHBORS[index]
		var connected: bool = _grass_patch(neighbor) if material=="grass" else _dirt(neighbor)
		if connected: mask |= 1 << index
	return mask

static func terrain_quarters(material: String, mask: int) -> Array:
	# Each corner observes its two adjoining sides and diagonal. Four-neighbour
	# whole-cell selection misses inside corners and loses one side of thin strips.
	assert(CONCAVE_CELLS.has(material) and mask>=0 and mask<=255)
	var key := material+str(mask)
	if _quarter_cache.has(key): return _quarter_cache[key]
	var pieces: Array[Rect2i] = []
	var center := Vector2i(1,14) if material=="grass" else Vector2i(1,9)
	for index in 4:
		var right: bool = index%2==1
		var bottom: bool = index>=2
		var horizontal: bool = (mask & (2 if right else 1))!=0
		var vertical: bool = (mask & (8 if bottom else 4))!=0
		var source := center
		if not horizontal: source.x=(2 if material=="grass" else 3) if right else 0
		if not vertical: source.y=center.y+(1 if bottom else -1)
		if horizontal and vertical and (mask & (1 << (index+4)))==0:
			source=CONCAVE_CELLS[material][index]
		pieces.append(Rect2i(source*16+Vector2i(8 if right else 0,8 if bottom else 0),Vector2i(8,8)))
	_quarter_cache[key]=pieces
	return pieces

static func _transition(canvas: CanvasItem, cell: Vector2i, material: String, day: int) -> void:
	var pieces := terrain_quarters(material,terrain_mask(cell,material))
	for index in 4:
		var destination := Rect2(Vector2(cell)*32+Vector2(index%2,index/2)*16,Vector2(16,16))
		canvas.draw_texture_rect_region(Tiles.texture("spring_outdoorsTileSheet",day),destination,Rect2(pieces[index]))

static func _tile(canvas: CanvasItem, cell: Vector2i, source_cell: Vector2i, day: int, source: String="spring_outdoorsTileSheet") -> void:
	canvas.draw_texture_rect_region(Tiles.texture(source,day),Rect2(Vector2(cell)*32,Vector2(32,32)),Rect2(Vector2(source_cell)*16,Vector2(16,16)))

static func _edge(cell: Vector2i, material: String) -> Vector2i:
	var left:bool=cell_kind(cell+Vector2i.LEFT)==material if material=="water" else _dirt(cell+Vector2i.LEFT)
	var right:bool=cell_kind(cell+Vector2i.RIGHT)==material if material=="water" else _dirt(cell+Vector2i.RIGHT)
	var up:bool=cell_kind(cell+Vector2i.UP)==material if material=="water" else _dirt(cell+Vector2i.UP)
	var down:bool=cell_kind(cell+Vector2i.DOWN)==material if material=="water" else _dirt(cell+Vector2i.DOWN)
	if material=="water":
		return Vector2i(8 if not left else (10 if not right else 9),7 if not up else (10 if not down else 8))
	return Vector2i(0 if not left else (3 if not right else 1),8 if not up else (10 if not down else 9))

static func draw(canvas: CanvasItem,bounds: Rect2,day: int,elapsed: float) -> void:
	var start:=Vector2i((bounds.position/32).floor())
	var end:=Vector2i((bounds.end/32).ceil())
	for y in range(start.y,end.y):
		for x in range(start.x,end.x):
			var cell:=Vector2i(x,y)
			var kind:=cell_kind(cell)
			_tile(canvas,cell,Vector2i(0,7),day)
			if kind in ["path","sand","bridge","water"]:
				_transition(canvas,cell,"dirt",day)
			elif kind=="rock":
				_tile(canvas,cell,Vector2i(11,22),day)
			else:
				var patch:=_grass_patch(cell)
				if patch:
					_transition(canvas,cell,"grass",day)
				# Sparse original flowers/grass, arranged within patches rather than a grid.
				var code:=posmod(x*131+y*71,101)
				if code in [7,42] and patch and not Map.YARD_BOUNDS.has_point(Vector2(cell)*32):
					_tile(canvas,cell,Vector2i(1 if code==7 else 2,6),day)
			if kind=="water":
				_tile(canvas,cell,Vector2i(8+posmod(int(elapsed*2),4),13),day)
				var edge:=_edge(cell,"water")
				if edge.x!=9 or edge.y!=8: _tile(canvas,cell,edge,day)
			elif kind=="bridge":
				_bridge(canvas,cell,day)
			elif kind=="path" and posmod(x*13+y*7,17)==0 and terrain_mask(cell,"dirt")==255:
				_tile(canvas,cell,Vector2i(2,9),day)
	for pond:Dictionary in Map.ponds_near(bounds.get_center()):
		if bounds.grow(150).has_point(pond.center): _pond(canvas,pond,day,elapsed)
	for feature:Dictionary in Map.WATER_FEATURES.values():
		if not bounds.intersects(Rect2(feature.bounds).grow(32)):continue
		if feature.has("center"):_pond(canvas,feature,day,elapsed)
		else:_river(canvas,feature,day,elapsed)
	# Reapply every physical crossing above water; never draw water over a path.
	for y in range(start.y,end.y):
		for x in range(start.x,end.x):
			if Map.terrain(Vector2(x,y)*32+Vector2(16,16))=="bridge":_bridge(canvas,Vector2i(x,y),day)

static func pond_shoulder(pond:Dictionary,angle:float) -> float:
	# Continuous low-frequency variation, with the original 4..12px dry-bank budget.
	var phase: float = Vector2(pond.center).x*0.01+Vector2(pond.center).y*0.007
	return 8.0+2.0*sin(angle*3+phase)+1.5*cos(angle*2-phase)

static func pond_shape(pond:Dictionary,bank:bool=false) -> PackedVector2Array:
	var shape:=PackedVector2Array()
	for i in 48:
		var angle:float=i*TAU/48
		var normal:=Vector2(cos(angle),sin(angle))
		var shoulder:float=pond_shoulder(pond,angle) if bank else 0.0
		shape.append(((Vector2(pond.center)+normal*(Vector2(pond.radius)+Vector2.ONE*shoulder))/2).round()*2)
	return shape

static func bank_texture(day:int) -> Texture2D:
	# Art.ground("dirt") deliberately falls back to spring for old farm surfaces.
	# A snow-covered shore instead uses the actual opaque winter snow tile.
	return Art.region("winter",Rect2i(0,112,16,16),true) if not season_warm(day) else Art.ground("dirt",day)

static func _pond(canvas:CanvasItem,pond:Dictionary,day:int,elapsed:float) -> void:
	var edge:=pond_shape(pond,true)
	var water:=pond_shape(pond)
	var uv:=PackedVector2Array()
	var bank_uv:=PackedVector2Array()
	var water_texture:=Art.region(Tiles.season(day),Rect2i((8+posmod(int(elapsed*2),4))*16,208,16,16),true)
	for i in 48:
		bank_uv.append(edge[i]/32)
		uv.append(water[i]/32)
	canvas.draw_colored_polygon(edge,Color.WHITE,bank_uv,bank_texture(day))
	canvas.draw_colored_polygon(water,Color.WHITE,uv,water_texture)
	# Small tufts, pebbles and broken bank accents cluster at different shores.
	# They have no tall silhouette and never imply a solid obstacle.
	for i in [2,3,5,18,19,28,42]:
		var at:Vector2=edge[i]
		if Map.terrain(at)=="grass" and not Map.on_path(at):
			if i%2==0:
				canvas.draw_texture_rect(Art.grass(day,i),Rect2(at-Vector2(8,16),Vector2(16,20)),false)
			else:
				canvas.draw_line(at,edge[(i+1)%48],Color("d7b76d") if season_warm(day) else Color("d6e5e8"),2,false)

static func river_shape(feature:Dictionary,bank:bool=false) -> Array:
	var key:String=str(feature.id)+str(bank)
	if not _river_shapes.has(key):
		# Same centerline and radius as IslandMap collision and IslandAtlas.
		_river_shapes[key]=Geometry2D.offset_polyline(PackedVector2Array(feature.points),float(feature.width)*0.5+(8 if bank else 0),Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
	return _river_shapes[key]

static func _river(canvas:CanvasItem,feature:Dictionary,day:int,elapsed:float)->void:
	for bank:bool in [true,false]:
		var texture:Texture2D=bank_texture(day) if bank else Art.region(Tiles.season(day),Rect2i((8+posmod(int(elapsed*2),4))*16,208,16,16),true)
		for polygon:PackedVector2Array in river_shape(feature,bank):
			var uv:=PackedVector2Array()
			for point in polygon:uv.append(point/32)
			canvas.draw_colored_polygon(polygon,Color.WHITE,uv,texture)

static func _plaza_image(day:int) -> Image:
	var season:String=Tiles.season(day)
	if not _plaza_images.has(season):_plaza_images[season]=Tiles.texture("spring_town",day).get_image()
	return _plaza_images[season]

static func plaza_edge_mask(cell:Vector2i) -> PackedByteArray:
	assert(cell in PLAZA_EDGE_CELLS.values())
	if not _plaza_masks.has(cell):
		var source:=_plaza_image(1)
		var mask:=PackedByteArray()
		for y in 16:
			for x in 16:
				mask.append(0 if source.get_pixel(cell.x*16+x,cell.y*16+y).to_rgba32() in PLAZA_GRASS_COLORS else 1)
		_plaza_masks[cell]=mask
	return _plaza_masks[cell]

static func plaza_edge_texture(cell:Vector2i,day:int) -> Texture2D:
	var key:String=Tiles.season(day)+str(cell)
	if not _plaza_edges.has(key):
		var result:=_plaza_image(day).get_region(Rect2i(cell*16,Vector2i(16,16)))
		var mask:=plaza_edge_mask(cell)
		for y in 16:
			for x in 16:
				if mask[y*16+x]==0:result.set_pixel(x,y,Color.TRANSPARENT)
		_plaza_edges[key]=ImageTexture.create_from_image(result)
	return _plaza_edges[key]

static func plaza_edge_pieces(bounds:Rect2) -> Array:
	var size:=Vector2i(bounds.size/32)
	var pieces:Array=[]
	for y in size.y:
		for x in size.x:
			if x>0 and x<size.x-1 and y>0 and y<size.y-1:continue
			var edge:String=("n" if y==0 else "s" if y==size.y-1 else "")+("w" if x==0 else "e" if x==size.x-1 else "")
			pieces.append({"cell":PLAZA_EDGE_CELLS[edge],"rect":Rect2(bounds.position+Vector2(x,y)*32,Vector2(32,32))})
	return pieces

static func draw_plaza(canvas:CanvasItem,bounds:Rect2,day:int) -> void:
	# The imported central composition stays intact. Native curb tiles replace only
	# its abruptly cropped outer ring, within the original walkable plaza footprint.
	Tiles.draw_patch(canvas,"Town",Rect2i(23,61,14,13),bounds.position+Vector2(32,32),2.0,day,["Back","Back2"])
	for piece:Dictionary in plaza_edge_pieces(bounds):
		canvas.draw_texture_rect(plaza_edge_texture(piece.cell,day),piece.rect,false)

static func _bridge(canvas:CanvasItem,cell:Vector2i,day:int) -> void:
	_tile(canvas,cell,Vector2i(12,17),day,"spring_beach")
	var at:=Vector2(cell)*32
	# Edge beams only over water; entrances and the full walkable width stay clear.
	for side in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		if Map.terrain(Vector2(cell+side)*32+Vector2(16,16))!="water":continue
		var vertical:bool=side.x!=0
		var offset:=Vector2(0 if side.x<0 else 30,0) if vertical else Vector2(0,0 if side.y<0 else 30)
		var size:=Vector2(2,32) if vertical else Vector2(32,2)
		canvas.draw_rect(Rect2(at+offset,size),Color("ae7948"))
		canvas.draw_rect(Rect2(at+offset,Vector2(2,2)),Color("e7c183"))

static func season_warm(day:int) -> bool:
	return Tiles.season(day)!="winter"

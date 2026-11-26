extends SceneTree
## Protect the actual water outline and native stone edge pixels while fixing presentation.
const Surface = preload("res://scripts/island_surface.gd")
const Map = preload("res://scripts/island_map.gd")
const Tiles = preload("res://scripts/island_tiles.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	for pond in [Map._page_pond(Vector2i(0,0)),Map.WATER_FEATURES.mirror_lake]:
		check(not pond.is_empty(), "actual pond fixture exists")
		if pond.is_empty(): continue
		var water: PackedVector2Array = Surface.pond_shape(pond)
		var bank: PackedVector2Array = Surface.pond_shape(pond,true)
		check(water.size() == 48 and bank.size() == 48, "existing water tessellation remains 48 vertices")
		for index in 48:
			var angle: float = index * TAU / 48
			var normal := Vector2(cos(angle),sin(angle))
			var expected: Vector2 = ((Vector2(pond.center)+normal*Vector2(pond.radius))/2).round()*2
			check(water[index] == expected, "painted water uses the exact previous ellipse, not the new shore")
			var delta: Vector2 = (bank[index]-Vector2(pond.center))/Vector2(pond.radius)
			check(delta.length() > 1.0 and bank[index] == (bank[index]/2).round()*2, "dry shore stays outside physical water on the 2x pixel grid")
			var shoulder: float = Surface.pond_shoulder(pond,angle)
			var next: float = Surface.pond_shoulder(pond,angle+TAU/48)
			check(shoulder >= 4.0 and shoulder <= 12.0 and absf(shoulder-next) < 1.3, "shore has no alternating per-vertex teeth and keeps its original width budget")
		check(is_equal_approx(Surface.pond_shoulder(pond,0),Surface.pond_shoulder(pond,TAU)), "shore closes smoothly at the final vertex")
	var winter := Surface.bank_texture(85).get_image()
	var snow := Tiles.texture("spring_outdoorsTileSheet",85).get_image().get_region(Rect2i(0,112,16,16))
	check(winter.get_data() == snow.get_data(), "winter pond and river bank use actual native snow, never spring yellow dirt")
	check(winter.get_data() != Surface.bank_texture(1).get_image().get_data(), "winter shore visibly differs from spring")
	var bounds: Rect2 = Map.LANDMARKS.plaza.bounds
	var pieces: Array = Surface.plaza_edge_pieces(bounds)
	check(pieces.size() == 58, "all four edges and four corners cover the existing 16x15 plaza perimeter")
	for piece: Dictionary in pieces:
		check(bounds.encloses(piece.rect) and piece.rect.size == Vector2(32,32), "every new edge stays inside the existing plaza at 2x native scale")
		check(not bounds.grow(-32).intersects(piece.rect), "perimeter does not overwrite the preserved central TMX artwork")
	for day in [1,29,57,85]:
		var original: Image = Tiles.texture("spring_town",day).get_image()
		for cell: Vector2i in Surface.PLAZA_EDGE_CELLS.values():
			var texture: Image = Surface.plaza_edge_texture(cell,day).get_image()
			var mask: PackedByteArray = Surface.plaza_edge_mask(cell)
			var removed := 0
			var changed_stones := 0
			for y in 16:
				for x in 16:
					if mask[y*16+x] == 0:
						if texture.get_pixel(x,y).a == 0: removed += 1
					elif texture.get_pixel(x,y) != original.get_pixel(cell.x*16+x,cell.y*16+y): changed_stones += 1
			check(removed > 0 and changed_stones == 0, "native seasonal stone/curb pixels are preserved; baked grass reveals the existing ground")
	check(Surface._plaza_edges.size() == 32 and Surface._plaza_masks.size() == 8, "edge cache is bounded by eight cells and four seasons")
	print("TERRAIN DETAILS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + label)

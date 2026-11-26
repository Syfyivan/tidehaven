extends SceneTree
## Native terrain topology only; existing island_surface_checks owns water/collision checks.
const Surface = preload("res://scripts/island_surface.gd")
const Tiles = preload("res://scripts/island_tiles.gd")
const Map = preload("res://scripts/island_map.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	# A path's inside corner must be visible even when both cardinal neighbours connect.
	# Bit order: W,E,N,S,NW,NE,SW,SE. Each missing diagonal affects its own quarter.
	for material in ["dirt", "grass"]:
		var filled: Array = Surface.terrain_quarters(material, 255)
		var inside: Array = [Vector2i(2,8), Vector2i(2,7), Vector2i(2,10), Vector2i(3,7)] if material == "dirt" else [Vector2i(3,13), Vector2i(3,15), Vector2i(3,16), Vector2i(3,14)]
		for quarter in 4:
			var cut: Array = Surface.terrain_quarters(material, 255 ^ (1 << (quarter + 4)))
			var offset := Vector2i(quarter % 2, quarter / 2) * 8
			check(cut[quarter] == Rect2i(inside[quarter] * 16 + offset, Vector2i(8,8)), material + " missing diagonal uses its native concave corner")
			for other in 4:
				if other != quarter: check(cut[other] == filled[other], material + " a diagonal does not replace unrelated corners")
		# A one-cell strip needs both edge faces, unlike selecting just left or right.
		var strip: Array = Surface.terrain_quarters(material, 12)
		check(strip[0].position.x < filled[0].position.x and strip[1].position.x > filled[1].position.x, material + " narrow vertical strip preserves both banks")
		for day in [1,29,57,85]:
			var atlas: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(Tiles.texture("spring_outdoorsTileSheet",day).get_size()))
			for mask in 256:
				var pieces: Array = Surface.terrain_quarters(material,mask)
				check(pieces.size() == 4 and pieces.all(func(piece: Rect2i): return piece.size == Vector2i(8,8) and atlas.encloses(piece)), "%s day %d mask %d has four bounded native quarters" % [material,day,mask])
	# Find a real grass patch at the yard edge, then simulate the road cutting one neighbour.
	# Only the render cache is a fixture; IslandMap stays unchanged.
	var patch := Vector2i.ZERO
	for y in range(42,70):
		for x in range(61,100):
			var cell := Vector2i(x,y)
			if Surface._grass_patch(cell) and Surface._grass_patch(cell + Vector2i.RIGHT):
				patch = cell
				break
		if patch != Vector2i.ZERO: break
	check(patch != Vector2i.ZERO, "real yard has connected grass patches")
	if patch != Vector2i.ZERO:
		var neighbor := patch + Vector2i.RIGHT
		var original: String = Surface.cell_kind(neighbor)
		for obstacle in ["path","water","sand","bridge","rock"]:
			Surface._cells[neighbor] = obstacle
			check(not Surface._grass_patch(neighbor) and (Surface.terrain_mask(patch,"grass") & 2) == 0, obstacle + " interrupts grass instead of leaving a cut-off solid patch")
		Surface._cells[neighbor] = original
		check((Surface.terrain_mask(patch,"grass") & 2) != 0, "restoring grass reconnects the same patch")
	var real_concave := 0
	for y in range(44,67):
		for x in range(48,80):
			var cell := Vector2i(x,y)
			if not Surface._dirt(cell): continue
			var mask: int = Surface.terrain_mask(cell,"dirt")
			for corner in 4:
				var sides: int = (1 << (corner % 2)) | (1 << (2 + corner / 2))
				if (mask & sides) == sides and (mask & (1 << (corner + 4))) == 0: real_concave += 1
	check(real_concave > 0, "yard access has real concave road corners covered by the new selection")
	check(Surface._quarter_cache.size() <= 512, "quarter cache is bounded by two materials and 256 masks")
	check(Map.YARD_BOUNDS == Rect2(1920,1216,1536,1152) and Map.YARD_GATE == Vector2(1920,1792), "yard geometry is not resized to hide visual seams")
	Surface._cells.clear()
	print("TERRAIN SEAMS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + label)

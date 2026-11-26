extends RefCounted
## Native coastal materials. Presentation only: no collision or save ownership.
const IslandArt = preload("res://scripts/island_art.gd")
const Tiles = preload("res://scripts/island_tiles.gd")
const WORLD_SCALE := 2.0
const MINI_SCALE := 0.5 # Cartographic models, never a character-size reference.
const REGIONS := {
	"mine_ladder": {"source":"Mines/mine", "rect":Rect2i(48,64,16,48)},
	"raft": {"source":"spring_beach", "rect":Rect2i(192,272,32,16)},
	"sand": {"source":"spring_beach", "rect":Rect2i(240,272,32,32)},
	"rock": {"source":"spring_beach", "rect":Rect2i(192,160,48,48)},
	"rock_fill": {"source":"spring_beach", "rect":Rect2i(208,176,16,16)},
	"pebbles": {"source":"spring_beach", "rect":Rect2i(48,160,32,32)},
	"kelp": {"source":"spring_beach", "rect":Rect2i(208,128,32,32)},
	"wreck": {"source":"spring_beach", "rect":Rect2i(0,128,48,48)},
}
static var _cache: Dictionary = {}

static func texture(key: String, submerged := false) -> Texture2D:
	var cache_key := key + str(submerged)
	if not _cache.has(cache_key):
		var spec: Dictionary = REGIONS[key]
		var bitmap: Image = Tiles.texture(spec.source,1).get_image().get_region(spec.rect)
		if key == "raft":
			var boards := Image.create(32,32,false,Image.FORMAT_RGBA8)
			boards.blit_rect(bitmap,Rect2i(0,0,32,16),Vector2i.ZERO)
			boards.blit_rect(bitmap,Rect2i(0,0,32,16),Vector2i(0,16))
			bitmap = boards
			# Sunlit wood retains its original grain rather than thresholding the shadows.
			for y in 32:
				for x in 32:
					bitmap.set_pixel(x,y,bitmap.get_pixel(x,y).lightened(0.18))
		if submerged:
			# Water lighting, not a replacement source file. Preserve alpha and relief.
			for y in bitmap.get_height():
				for x in bitmap.get_width():
					var color := bitmap.get_pixel(x,y)
					var light := color.get_luminance()
					var water_tone := Color("294e62").lerp(Color("a9c8b8"),light)
					color = color.lerp(water_tone,0.72)
					color.a = bitmap.get_pixel(x,y).a
					bitmap.set_pixel(x,y,color)
		_cache[cache_key] = ImageTexture.create_from_image(bitmap)
	return _cache[cache_key]

static func noise(seed_value: float) -> float:
	return fposmod(sin(seed_value * 12.9898 + 78.233) * 43758.5453,1.0)

static func polygon(canvas: CanvasItem, points: PackedVector2Array, material: Texture2D, scale_value: float, tint := Color.WHITE, origin := Vector2.ZERO) -> void:
	var uv := PackedVector2Array()
	for point in points: uv.append((point-origin)/(material.get_size()*scale_value))
	canvas.draw_colored_polygon(points,tint,uv,material)

static func outline(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 120:
		var angle := i*TAU/120
		var r := radius*(0.96+sin(angle*3+0.6)*0.035+sin(angle*7)*0.015)
		var point := ((center+Vector2(cos(angle),sin(angle))*r)/2).round()*2
		if points.is_empty() or points[-1]!=point: points.append(point)
	return points

static func draw_ocean(canvas: CanvasItem, bounds: Rect2, travel: Vector2, elapsed: float) -> void:
	canvas.draw_rect(bounds.grow(2),Color("487f9b"))
	var material := IslandArt.region("spring",Rect2i((8+posmod(int(elapsed*2),4))*16,208,16,16),true)
	var corners := PackedVector2Array([bounds.position,bounds.position+Vector2(bounds.size.x,0),bounds.end,bounds.position+Vector2(0,bounds.size.y)])
	polygon(canvas,corners,material,2.0,Color(0.73,1.0,1.0,0.13),-travel+Vector2(elapsed*3,0))

static func draw_island(canvas: CanvasItem, center: Vector2, dock: Vector2, day: int, elapsed: float,id:String="island_home") -> void:
	# Silhouette stays inside the existing 150-unit navigation obstacle.
	var shore := outline(center,146)
	var shallows := outline(center,153)
	canvas.draw_colored_polygon(shallows,Color(0.40,0.72,0.74,0.52))
	polygon(canvas,shore,texture("sand"),WORLD_SCALE,Color.WHITE,center)
	canvas.draw_polyline(shore+PackedVector2Array([shore[0]]),Color("b5d6c5"),2,false)
	var grass := outline(center+Vector2(4,-10),114)
	polygon(canvas,grass,IslandArt.region(IslandArt.season(day),Rect2i(0,112,16,16),true),1.0,Color.WHITE,center)
	canvas.draw_polyline(grass+PackedVector2Array([grass[0]]),Color("a7b16a") if Tiles.season(day)!="winter" else Color("d7daca"),2,false)
	if id!="island_home":
		Tiles.draw_patch(canvas,"Beach",Rect2i(14,23,4,2),dock+Vector2(32,-16),1.0,day,[],Color.WHITE,elapsed)
		if id=="island_mist":
			polygon(canvas,outline(center+Vector2(30,10),43),IslandArt.region("spring",IslandArt.REGIONS.water,true),1.0,Color("8db8b1"),center)
			for offset:Vector2 in [Vector2(-40,-60),Vector2(8,-74),Vector2(64,-66)]:
				canvas.draw_texture_rect(texture("rock"),Rect2(center+offset-Vector2(20,20),Vector2(56,56)),false)
		elif id=="island_reef":
			polygon(canvas,outline(center+Vector2(24,32),85),texture("sand"),1.0,Color.WHITE,center)
			for offset:Vector2 in [Vector2(-58,-35),Vector2(38,-28),Vector2(72,40)]:
				canvas.draw_texture_rect(texture("pebbles"),Rect2(center+offset,Vector2(32,32)),false)
		else:
			for offset:Vector2 in [Vector2(-48,-48),Vector2(-12,-60),Vector2(26,-48),Vector2(61,-24),Vector2(-58,18),Vector2(-20,40),Vector2(26,40),Vector2(64,55)]:
				canvas.draw_texture_rect(IslandArt.tree(day),Rect2((center+offset-IslandArt.TREE_FOOT*MINI_SCALE).round(),Vector2(48,96)*MINI_SCALE),false)
		return
	# West port, town, southeast yard and northern woodland are readable landmarks.
	var path := PackedVector2Array([dock+Vector2(64,0),center+Vector2(-78,0),center+Vector2(-20,8),center+Vector2(57,39)])
	canvas.draw_polyline(path,Color("c4a768"),10,false)
	canvas.draw_polyline(path,Color("dfc58e"),6,false)
	Tiles.draw_patch(canvas,"Beach",Rect2i(14,23,4,2),dock+Vector2(32,-16),1.0,day,[],Color.WHITE,elapsed)
	# Native small roofs and complete trees: no stretched icons or recoloured NPCs.
	var houses := [Vector2(-50,-14),Vector2(-10,0),Vector2(35,-8)]
	for i in houses.size():
		var source := Rect2i(0 if i!=1 else 160,0,80,96)
		canvas.draw_texture_rect(IslandArt.region("cabin",source),Rect2((center+houses[i]-Vector2(20,48)).round(),Vector2(40,48)),false)
	var yard := Rect2((center+Vector2(12,47)).round(),Vector2(64,40))
	canvas.draw_rect(yard,Color("8aab5e") if Tiles.season(day)!="winter" else Color("cdd6cd"))
	for i in 5:
		for y in [yard.position.y,yard.end.y]:
			canvas.draw_texture_rect(IslandArt.region("fence",IslandArt.REGIONS.fence_h),Rect2(Vector2(yard.position.x+i*14,y-12),Vector2(16,32)*MINI_SCALE),false)
	for offset: Vector2 in [Vector2(-52,-78),Vector2(-25,-65),Vector2(12,-76),Vector2(40,-62),Vector2(66,-55),Vector2(85,-25),Vector2(-79,41),Vector2(-57,73),Vector2(-24,86),Vector2(81,65)]:
		canvas.draw_texture_rect(IslandArt.tree(day),Rect2((center+offset-IslandArt.TREE_FOOT*MINI_SCALE).round(),Vector2(48,96)*MINI_SCALE),false)
	canvas.draw_texture_rect(texture("rock"),Rect2(center+Vector2(72,-91),Vector2(48,48)),false)
	canvas.draw_texture_rect(texture("pebbles"),Rect2(center+Vector2(-84,77),Vector2(32,32)),false)

static func ridge(canvas: CanvasItem, points: PackedVector2Array, bounds: Rect2, tint: Color) -> void:
	var edge := PackedVector2Array()
	for i in range(points.size()-1):
		var start := points[i]
		var end := points[i+1]
		for x in range(int(start.x),int(end.x),4):
			var t := (x-start.x)/maxf(1,end.x-start.x)
			edge.append(Vector2(x,roundf(lerpf(start.y,end.y,t)/4)*4))
	edge.append(points[-1])
	var body := edge.duplicate()
	body.append(Vector2(points[-1].x,maxf(580,bounds.end.y+4)))
	body.append(Vector2(points[0].x,maxf(580,bounds.end.y+4)))
	canvas.draw_colored_polygon(body,Color(0.18*tint.r,0.35*tint.g,0.40*tint.b,tint.a))
	polygon(canvas,body,texture("rock_fill",true),WORLD_SCALE,Color(tint.r,tint.g,tint.b,tint.a*0.32))
	canvas.draw_polyline(edge,Color(0.44,0.67,0.64,tint.a*0.22),2,false)

static func draw_reef(canvas: CanvasItem, bounds: Rect2, elapsed: float) -> void:
	var left := minf(-40,bounds.position.x-8)
	var right := maxf(950,bounds.end.x+8)
	# Low-contrast distant banks; the open upper water remains readable for fishing.
	ridge(canvas,PackedVector2Array([Vector2(left,465),Vector2(88,430),Vector2(192,454),Vector2(286,375),Vector2(360,410),Vector2(470,383),Vector2(568,454),Vector2(685,396),Vector2(803,420),Vector2(right,382)]),bounds,Color(0.47,0.68,0.76,0.43))
	ridge(canvas,PackedVector2Array([Vector2(200,388),Vector2(275,323),Vector2(315,320),Vector2(390,365),Vector2(470,337),Vector2(510,349),Vector2(574,492)]),bounds,Color("729498"))
	ridge(canvas,PackedVector2Array([Vector2(580,476),Vector2(649,343),Vector2(690,369),Vector2(755,408),Vector2(800,367),Vector2(858,405),Vector2(right,412)]),bounds,Color("83a5a4"))
	var floor_edge := PackedVector2Array()
	for x in range(int(left),int(right)+9,8):
		floor_edge.append(Vector2(x,roundf((533+sin(x/95.0)*13+sin(x/37.0)*3)/2)*2))
	var floor_poly := floor_edge.duplicate()
	floor_poly.append(Vector2(right+8,maxf(585,bounds.end.y+8)))
	floor_poly.append(Vector2(left,maxf(585,bounds.end.y+8)))
	polygon(canvas,floor_poly,texture("sand",true),WORLD_SCALE,Color("91b5b3"))
	canvas.draw_polyline(floor_edge,Color("9abcb4"),2,false)
	# Complete rock silhouettes overlap the distant material without repeating a wall.
	for entry: Vector3 in [Vector3(60,550,1),Vector3(262,552,2),Vector3(333,566,2),Vector3(658,552,2),Vector3(725,566,1),Vector3(885,545,2)]:
		var size_value := Vector2(48,48)*entry.z
		canvas.draw_texture_rect(texture("rock",true),Rect2(Vector2(entry.x,entry.y)-Vector2(size_value.x/2,size_value.y),size_value),false,Color("95b6b8"))
	for i in 12:
		var at := Vector2(left+35+noise(i+50)*(right-left-70),536+sin(i)*8)
		var size_value := Vector2(32,32)*(1.0 if i%3==0 else 2.0)
		var sway := roundf(sin(elapsed*0.6+i)*1.4)
		canvas.draw_texture_rect(texture("kelp",true),Rect2((at-Vector2(size_value.x/2,size_value.y)+Vector2(sway,0)).round(),size_value),false,Color("84b0a5"))
	for i in 9:
		var at := Vector2(left+noise(i+91)*(right-left),548+noise(i+100)*10)
		canvas.draw_texture_rect(texture("pebbles",true),Rect2(at,Vector2(32,32)),false,Color("9ab8b6"))

static func draw_deposit(canvas: CanvasItem, at: Vector2, salt: int) -> void:
	# Artwork follows the actual interaction point; no new solid obstacle is implied.
	var size_value := Vector2(48,48)*WORLD_SCALE
	canvas.draw_texture_rect(texture("rock",true),Rect2((at-Vector2(48,17)).round(),size_value),false,Color("a0bdba"))
	if posmod(salt,3)==0:
		canvas.draw_texture_rect(texture("kelp",true),Rect2((at+Vector2(23,-4)).round(),Vector2(32,32)),false)

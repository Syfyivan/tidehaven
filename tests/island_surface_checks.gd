extends SceneTree
const Map=preload("res://scripts/island_map.gd")
const Art=preload("res://scripts/island_art.gd")
const World=preload("res://scripts/world_state.gd")
var checks:=0
var failures:=0
func _initialize():
	var hidden_crossings:=0
	var example:=Vector2.ZERO
	for y in 4:
		for x in 5:
			var pond:=Map._page_pond(Vector2i(x,y))
			if pond.is_empty(): continue
			for dx in range(-100,101,8):
				for dy in range(-70,71,8):
					var at:Vector2=pond.center+Vector2(dx,dy)
					if Map.current_pond_contains(at) and Map.walkable(at) and Map.terrain(at)!="bridge":
						hidden_crossings+=1
						example=at
	check(hidden_crossings==0,"pond paths must be visible bridges, not invisible walkable water: %d at %s"%[hidden_crossings,example])
	var surface=preload("res://scripts/island_surface.gd")
	for feature:Dictionary in Map.WATER_FEATURES.values():
		if feature.has("center"):continue
		var shapes:Array=surface.river_shape(feature)
		var mismatches:=0
		# Test both banks and bends; ignore the 2px boundary rasterization tolerance.
		for segment in range(1,feature.points.size()):
			var a:Vector2=feature.points[segment-1]
			var b:Vector2=feature.points[segment]
			var normal:Vector2=(b-a).normalized().orthogonal()
			for fraction in [0.1,0.5,0.9]:
				for offset in [-float(feature.width)*0.5-4,-float(feature.width)*0.5+4,0.0,float(feature.width)*0.5-4,float(feature.width)*0.5+4]:
					var point:Vector2=a.lerp(b,fraction)+normal*offset
					var painted:bool=shapes.any(func(shape):return Geometry2D.is_point_in_polygon(point,shape))
					if painted!=Map._feature_contains(point,feature):mismatches+=1
		check(mismatches==0,"rendered river width and collision share geometry: "+str(feature.id))
		check(surface._river_shapes.size()<=4,"fixed water geometry cache never grows per frame")
	for id in Map.NEW_BUILDINGS:
		var building:Dictionary=Map.LANDMARKS[id]
		var foot:Vector2=Vector2(building.door.x,building.bounds.end.y)
		var image:=Art.building_rect(id,foot)
		check(image.position.x>=building.bounds.position.x and image.end.x<=building.bounds.end.x,"facade base stays inside solid building bounds: "+id)
	var tiles=preload("res://scripts/island_tiles.gd")
	for id in tiles.FACADES:
		if id=="yard_home":
			var housing=preload("res://scripts/housing.gd")
			for site in housing.SITES.size():
				var rect:Rect2=tiles.facade_rect(id,housing.SITES[site])
				check(rect.position.x>=housing.footprint(site).position.x and rect.end.x<=housing.footprint(site).end.x,"house facade aligns with protected footprint")
			continue
		var place:Dictionary=Map.LANDMARKS[id]
		var rect:Rect2=tiles.facade_rect(id,Vector2(place.door.x,place.bounds.end.y))
		check(rect.position.x>=place.bounds.position.x-(32 if id=="mine_entrance" else 0) and rect.end.x<=place.bounds.end.x+(32 if id=="mine_entrance" else 0),"native facade fits foundation or registered 32px mine rock overhang: "+id)
		check(Map.can_stand(place.door),"native facility doorway is walkable: "+id)
	var island_state=preload("res://scripts/island_state.gd")
	var untouched:Dictionary=island_state.create()
	for id in ["palm_0","wood_1","seeds_0","stone_0","palm_1"]:
		check(island_state.active(untouched,id,1),"maintained streets preserve landing supplies: "+id)
	var w:=World.new()
	w.join("host","旅人")
	var p:Dictionary=w.data.players.host
	p.area="island"
	p.x=640.0
	p.y=430.0
	for i in 100: w._move_player(p,Vector2(4,0))
	check(p.x<=652,"footprint stops before visible pond edge, actual x="+str(p.x))
	p.x=330.0
	p.y=315.0
	for i in 30: w._move_player(p,Vector2(0,-2))
	check(p.y>=286,"solid trunk blocks feet while its canopy remains passable")
	w.data.island.depleted.palm_0=999
	for i in 30: w._move_player(p,Vector2(0,-2))
	check(p.y<280,"clearing the tree opens the actual walking space")
	# A real curved road must remain walkable across both riverbanks with full feet.
	var bridge:=Vector2.ZERO
	for y in range(4300,4850,8):
		var at:=Vector2(Map.vertical_path_x(y,3),y)
		if Map.terrain(at)=="bridge":
			bridge=at
			break
	check(bridge!=Vector2.ZERO,"river has an explicit bridge")
	p.y=bridge.y-140
	p.x=Map.vertical_path_x(p.y,3)
	for y in range(int(p.y)+2,int(bridge.y)+200,2):
		w._move_player(p,Vector2(Map.vertical_path_x(y,3),y)-Vector2(p.x,p.y))
	check(p.y>bridge.y+180,"full footprint crosses both banks along the bridge")
	for edge in [Vector2(656,430),Vector2(2113,720),Vector2(1912,1700)]:
		var corrected:=Map.nearby_standing_point(edge)
		check(corrected.distance_to(edge)<=16 and Map.can_stand(corrected),"historical edge position can safely step away")
	# Different viewport edges must not leave unlimited per-size route entries.
	for width in range(160,360):
		Map.route_segments(PackedVector2Array([Vector2(width,300),Vector2(width+8,300)]))
	check(Map._route_cache.size()<=128,"resizing and visiting pages keeps the route cache bounded")
	print("ISLAND SURFACES: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
func check(ok:bool,label:String):
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL "+label)

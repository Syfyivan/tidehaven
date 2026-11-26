extends SceneTree
const Art = preload("res://scripts/island_art.gd")
const View = preload("res://scripts/world_view.gd")
const World = preload("res://scripts/world_state.gd")
const Map = preload("res://scripts/island_map.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	for day in [1,29,57,85]:
		for ground in ["ground","dirt","water","paving"]:
			check(not Art.ground(ground,day).get_image().is_invisible(), "seasonal ground has actual pixels")
		for active in [true,false]:
			check(not Art.tree(day,active).get_image().is_invisible(), "seasonal tree and stump contain pixels")
	for kind in Art.OBJECTS:
		check(Art.object_texture(kind).get_size() == Vector2(16,16) and not Art.object_texture(kind).get_image().is_invisible(), "resource atlas bounds and content " + kind)
	for crop in Art.CROP_ROWS:
		for age in range(Art.Farming.CROPS[crop].days + 1):
			check(not Art.crop(crop,age,false).get_image().is_invisible(), "every crop age has visible art " + crop)
		check(not Art.crop(crop,0,true).get_image().is_invisible(), "dead crop visible " + crop)
	check(Art.soil(false).get_image().get_data() != Art.soil(true).get_image().get_data(), "watering visibly changes actual soil pixels")
	for id in Map.NEW_BUILDINGS:
		check(Art.BUILDINGS.has(id) and Art.DOORS.has(id), "every replaced facade has registered body and door " + id)
		var door: Rect2i = Art.DOORS[id]
		check(Art.DOOR_RECT.size.x / door.size.x == Art.DOOR_RECT.size.y / door.size.y, "door never stretched " + id)
		check(Art.DOOR_RECT.size == Vector2(32,64) and Art.DOOR_RECT.end == Vector2(16,0), "native door and complete adult use the same two-times pixel scale " + id)
	var world := World.new()
	world.join("host", "旅人")
	world.data.players.host.area = "island"
	world.data.players.host.x = 2250.0
	world.data.players.host.y = 1800.0
	var view := View.new()
	view.state=world.data
	var before := JSON.stringify(world.data)
	var order := view.island_draw_order(Rect2(1792,1632,896,544))
	var has_player := false
	for i in order.size():
		if i > 0: check(order[i-1].y <= order[i].y, "island actors ordered by ground contact")
		has_player = has_player or order[i].kind == "player"
	check(has_player, "player participates in scenery depth instead of unconditional foreground")
	check(before == JSON.stringify(world.data), "render collection never mutates world or inventory")
	check(Art.tree_rect(Vector2(100,200)).size == Vector2(96,192), "mature tree shares the same integer pixel scale as people and terrain")
	view.free()
	print("ISLAND ART: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL "+label)

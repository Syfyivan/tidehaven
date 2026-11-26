extends Node2D
## Read-only scenery. Only the raft moves; the camera and gameplay coordinates stay fixed.

const MaritimeArt = preload("res://scripts/maritime_art.gd")
const SeaCreatures = preload("res://scripts/sea_creature_art.gd")
const SeaThreats = preload("res://scripts/sea_threats.gd")
const Art = preload("res://scripts/art_catalog.gd")
const IslandArt = preload("res://scripts/island_art.gd")
const IslandSurface = preload("res://scripts/island_surface.gd")
const IslandTiles = preload("res://scripts/island_tiles.gd")
const ChoppingArt = preload("res://scripts/chopping_art.gd")
const ToolMotion = preload("res://scripts/tool_motion.gd")
const CharacterArt = preload("res://scripts/character_art.gd")
const SwimmingArt=preload("res://scripts/swimming_art.gd")
const Navigation = preload("res://scripts/navigation.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
const IslandState = preload("res://scripts/island_state.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const Farming = preload("res://scripts/farming.gd")
const IslandTown = preload("res://scripts/island_town.gd")
const Rooms = preload("res://scripts/rooms.gd")
const Restaurant=preload("res://scripts/restaurant.gd")
const Gardens = preload("res://scripts/gardens.gd")
const Housing=preload("res://scripts/housing.gd")
const OceanResidents=preload("res://scripts/ocean_residents.gd")
const OceanArt=preload("res://scripts/ocean_resident_art.gd")
const INK := Color("363b3b")
const CREAM := Color("eddfb9")
const MINT := Color("a3c5a0")
const GOLD := Color("dcb277")

var feedback = preload("res://scripts/scene_feedback.gd").new()
var state: Dictionary = {}
var local_slot: String = "host"
var hovered_id: String = ""
var placement: Dictionary = {}
var farm_preview: Dictionary = {}
var canvas_bounds := Rect2(0, 0, 900, 560)
var _font := SystemFont.new()
var _local: Dictionary = {}
var _elapsed: float = 0.0
var _tiles: Dictionary = {}
var _focus := ""
var _character_states: Dictionary = {}
var open_chest_id := ""

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "sans-serif"])

## These transforms are in this Node2D's local canvas, before its position/scale.
## Drift and underwater positions are already in the canvas and are not transformed.
func deck_transform() -> Transform2D:
	var time: float = float(state.get("elapsed", 0.0))
	var pivot := Vector2(480, 288)
	var bob := Vector2(sin(time * 0.57) * 0.35, sin(time * 0.76) * 1.1 + sin(time * 1.19) * 0.25)
	var roll: float = deg_to_rad(0.10) * sin(time * 0.49)
	return Transform2D(roll, pivot + bob - pivot.rotated(roll))

func world_to_screen(point: Vector2, area: String = "deck") -> Vector2:
	if area == "room": return point - _room_origin()
	if area == "island":
		return point - _island_origin()
	return deck_transform() * point if area == "deck" else point

func screen_to_world(point: Vector2, area: String = "deck") -> Vector2:
	if area == "room": return point + _room_origin()
	if area == "island":
		return point + _island_origin()
	return deck_transform().affine_inverse() * point if area == "deck" else point

func _island_origin() -> Vector2:
	var player: Dictionary = state.get("players", {}).get(local_slot, {})
	return IslandMap.page_origin(Vector2(float(player.get("x", 210)), float(player.get("y", 380))))

func _room_origin() -> Vector2:
	return Rooms.camera(state.players[local_slot])

func _draw() -> void:
	_local = state.get("players", {}).get(local_slot, {})
	_elapsed = float(state.get("elapsed", 0.0))
	_tiles.clear()
	for tile in state.get("deck_tiles", []):
		_tiles[str(tile)] = true
	_focus = _focused_facility()
	if str(_local.get("area", "deck")) == "room":
		_draw_room()
	elif str(_local.get("area", "deck")) == "water":
		_draw_water()
		_draw_players()
	elif str(_local.get("area", "deck")) == "island":
		_ocean()
		draw_set_transform_matrix(Transform2D(0, -_island_origin()))
		_draw_island()
	else:
		_ocean()
		_draw_navigation()
		_draw_drift()
		_draw_distant_island()
		draw_set_transform_matrix(deck_transform())
		_draw_deck()
		var cabin:Dictionary=state.get("housing",{}).get("cabin",{})
		if not cabin.is_empty():_prop("cabin",Vector2(cabin.x,cabin.y))
		_draw_players()
		if not placement.is_empty():
			_draw_placement()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_feedback()

func _r(at: Vector2, size_value: Vector2, color: Color) -> void:
	draw_rect(Rect2(at.round(), size_value), color)

func _sprite(key: String, at: Vector2, size_value: Vector2 = Vector2(40, 40), tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = Art.texture(key)
	if texture != null:
		var fitted := Art.fitted_size(key, size_value)
		draw_texture_rect(texture, Rect2((at - fitted * 0.5).round(), fitted), false, tint)

func _prop(key: String, at: Vector2, tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = Art.texture(key)
	if texture != null:
		draw_texture_rect(texture, Art.world_rect(key, at), false, tint)

func _item(key: String, at: Vector2, extent: float) -> void:
	_sprite(key, at, Vector2.ONE * extent)

func _label(text: String, at: Vector2, color: Color = CREAM, font_size: int = 11) -> void:
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var start := Vector2(roundf(at.x - width * 0.5), roundf(at.y))
	draw_string(_font, start + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(INK, color.a))
	draw_string(_font, start, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _near(at: Vector2, radius: float = 64.0) -> bool:
	return not _local.is_empty() and Vector2(float(_local.get("x", 0)), float(_local.get("y", 0))).distance_to(at) < radius

func _ring(at: Vector2, radius: float, tint: Color) -> void:
	draw_arc(at.round(), radius, 0, TAU, 24, tint, 1, false)

func _noise(seed_value: float) -> float:
	return fposmod(sin(seed_value * 12.9898 + 78.233) * 43758.5453, 1.0)

func _polygon(at: Vector2, offsets: PackedVector2Array, color: Color) -> void:
	var points := PackedVector2Array()
	for point in offsets:
		points.append((point + at).round())
	draw_colored_polygon(points, color)

func _shadow(at: Vector2, extent: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 12:
		var angle: float = float(index) * TAU / 12.0
		points.append((at + Vector2(cos(angle), sin(angle)) * extent).round())
	draw_colored_polygon(points, color)

func _gradient(top: Color, bottom: Color) -> void:
	var left := floorf(canvas_bounds.position.x) - 1
	for y in range(int(floorf(canvas_bounds.position.y)) - 1, int(ceilf(canvas_bounds.end.y)) + 4, 4):
		_r(Vector2(left, y), Vector2(ceilf(canvas_bounds.size.x) + 3, 4), top.lerp(bottom, clampf(float(y) / 560.0, 0, 1)))

func _ocean() -> void:
	var swell: float = preload("res://scripts/salvage_hook.gd").wave(_elapsed)
	var nav: Dictionary = state.get("navigation", Navigation.create())
	var travel := Vector2(float(nav.x), float(nav.y))
	MaritimeArt.draw_ocean(self, canvas_bounds, travel, _elapsed)
	# Independent positions and staggered lifetimes avoid a visible lattice.
	# Every crest travels to the right with the same current as the supplies.
	for index in 92:
		var seed_value := float(index + 1)
		var x: float = canvas_bounds.position.x - 60 + fposmod(_noise(seed_value) * (canvas_bounds.size.x + 120) + _elapsed * (7.5 + _noise(seed_value + 92) * 3.0) - travel.x, canvas_bounds.size.x + 120)
		var y: float = canvas_bounds.position.y - 10 + fposmod(_noise(seed_value + 184) * (canvas_bounds.size.y + 20) - travel.y, canvas_bounds.size.y + 20) + sin(_elapsed * 0.42 + seed_value) * (1.0 + swell * 1.6)
		var life: float = 0.5 + 0.5 * sin(_elapsed * 0.51 + _noise(seed_value + 276) * TAU)
		var span: float = 9 + _noise(seed_value + 368) * 27
		var at := Vector2(x, y).round()
		var tint := Color(0.68, 0.83, 0.78, 0.07 + life * (0.12 + swell * 0.14))
		draw_polyline(PackedVector2Array([at, at + Vector2(span * 0.28, -1), at + Vector2(span * 0.74, -1), at + Vector2(span, -3)]), tint, 1, false)
		if index % 3 == 0:
			draw_line(at + Vector2(-5, 4), at + Vector2(span * 0.40, 4), Color(0.19, 0.40, 0.47, 0.14 * life), 1, false)
	# Brief surface glints are small, asymmetric, and drift rather than flash in place.
	for index in 13:
		var life: float = sin(_elapsed * 0.65 + float(index) * 2.37)
		if life > 0.68:
			var at := Vector2(fposmod(_noise(index + 702) * 970 + _elapsed * 9, 970) - 35, 25 + _noise(index + 741) * 500)
			_r(at, Vector2(5, 1), Color(0.81, 0.89, 0.78, (life - 0.68) * 0.9))
			_r(at + Vector2(2, -1), Vector2(2, 3), Color(0.81, 0.89, 0.78, (life - 0.68) * 0.65))
	for index in 3:
		var x: float = fposmod(140 + index * 283 + _elapsed * 4.0, 1000) - 50
		var y: float = 140 + index * 135 + sin(_elapsed * 0.25 + index) * 6
		_sprite("fish_swim", Vector2(x, y), Vector2(25, 20), Color(0.29, 0.49, 0.51, 0.23))
		_sprite("fish_swim", Vector2(x - 24, y + 11), Vector2(19, 15), Color(0.29, 0.49, 0.51, 0.17))

func _draw_navigation() -> void:
	var nav: Dictionary = state.get("navigation", Navigation.create())
	var bounds := Rect2(384, 192, 192, 192)
	for key in _tiles:
		bounds = bounds.merge(Rect2(_cell(str(key)) * 64, Vector2(64, 64)))
	if bool(nav.get("moored", false)):
		var dock := Vector2(480, 288) + Archipelago.island_position(state.chart,Archipelago.nearby_island(state.chart,nav)) - Vector2(float(nav.x), float(nav.y))
		var tie := world_to_screen(Vector2(bounds.end.x - 6, bounds.end.y - 12))
		draw_line(tie, dock, Color("c5b28a"), 2, false)
		_sprite("rope", dock, Vector2(24, 24))
		return
	if bool(nav.anchored):
		var tie := world_to_screen(Vector2(bounds.position.x + 8, bounds.end.y - 12))
		var weight := tie + Vector2(-32, 37)
		draw_polyline(PackedVector2Array([tie, tie + Vector2(-22, 7), weight]), Color("c5b28a"), 2, false)
		_sprite("anchor", weight, Vector2(27, 27), Color(0.82, 0.94, 0.90, 0.85))
		_ring(weight + Vector2(0, 3), 17, Color(0.70, 0.87, 0.81, 0.18))
		return
	var velocity := Navigation.velocity(nav)
	var direction := velocity.normalized()
	var side := Vector2(-direction.y, direction.x)
	var radius := maxf(bounds.size.x, bounds.size.y) * 0.5 + 12
	var stern := world_to_screen(bounds.get_center()) - direction * radius
	for index in 4:
		var phase := fposmod(_elapsed * 0.9 + float(index) * 0.25, 1.0)
		var center := stern - direction * (phase * 56)
		var width := 10 + phase * 28
		var points := PackedVector2Array([center + side * width + direction * 8, center, center - side * width + direction * 8])
		draw_polyline(points, Color(0.72, 0.88, 0.82, (1.0 - phase) * minf(0.32, velocity.length() * 0.015)), 1, false)

func _cell(key: String) -> Vector2:
	var parts := key.split(",")
	return Vector2(int(parts[0]), int(parts[1])) if parts.size() == 2 else Vector2.ZERO

func _cell_key(cell: Vector2) -> String:
	return "%d,%d" % [int(cell.x), int(cell.y)]

func _draw_deck() -> void:
	# Low, translucent contact shadows bind the floating hull to the water.
	for key in _tiles:
		var origin: Vector2 = _cell(str(key)) * 64
		_r(origin + Vector2(-3, 9), Vector2(70, 63), Color(0.08, 0.23, 0.27, 0.10))
		_r(origin + Vector2(1, 12), Vector2(66, 59), Color(0.08, 0.23, 0.27, 0.12))
	for key in _tiles:
		_draw_planks(_cell(str(key)))
	for key in _tiles:
		_draw_raft_edge(_cell(str(key)))
	_draw_structures()
	for id in state.get("chests", {}):
		if state.chests[id].get("area", "deck") == "deck":
			_draw_chest(str(id), state.chests[id])

func _draw_planks(cell: Vector2) -> void:
	draw_texture_rect(Art.texture("floor"), Rect2(cell * 64, Vector2(64, 64)), false)

func _draw_raft_edge(cell: Vector2) -> void:
	var at := cell * 64
	if not _tiles.has(_cell_key(cell + Vector2.UP)):
		_r(at + Vector2(0, -2), Vector2(64, 4), Color("97714f"))
		_r(at + Vector2(0, -2), Vector2(64, 1), Color("dcc08b"))
		_rope_tie(at + Vector2(13, -3), false)
		_rope_tie(at + Vector2(49, -3), false)
	if not _tiles.has(_cell_key(cell + Vector2.DOWN)):
		_r(at + Vector2(0, 61), Vector2(64, 9), Color("815d43"))
		_r(at + Vector2(0, 61), Vector2(64, 3), Color("b38a5b"))
		_r(at + Vector2(3, 67), Vector2(58, 2), Color("66523f"))
		_rope_tie(at + Vector2(13, 58), false)
		_rope_tie(at + Vector2(49, 58), false)
		var ripple: float = sin(_elapsed * 0.8 + cell.x * 1.7) * 4
		draw_line(at + Vector2(9 + ripple, 73), at + Vector2(40 + ripple, 73), Color(0.66, 0.80, 0.73, 0.25), 1, false)
	if not _tiles.has(_cell_key(cell + Vector2.LEFT)):
		_r(at + Vector2(-2, 0), Vector2(4, 64), Color("98724f"))
		_r(at + Vector2(-2, 2), Vector2(1, 58), Color("ddbb83"))
		_rope_tie(at + Vector2(-3, 29), true)
	if not _tiles.has(_cell_key(cell + Vector2.RIGHT)):
		_r(at + Vector2(61, 0), Vector2(4, 64), Color("916746"))
		_r(at + Vector2(61, 2), Vector2(1, 58), Color("ceaa76"))
		_rope_tie(at + Vector2(57, 29), true)

func _rope_tie(at: Vector2, horizontal: bool) -> void:
	var extent := Vector2(11, 3) if horizontal else Vector2(3, 13)
	_r(at + Vector2(1, 1), extent, Color("685d45"))
	_r(at, extent, Color("bcad81"))
	_r(at + Vector2(0, 4) if not horizontal else at + Vector2(4, 0), Vector2(4, 2) if not horizontal else Vector2(2, 4), Color("ded0a0"))

func _draw_drift() -> void:
	var drift: Dictionary = state.get("drift", {})
	for id in drift:
		var object: Dictionary = drift[id]
		if not bool(object.get("active", false)) or _returning_drift(str(id)):
			continue
		var at := Vector2(float(object.get("x", 0)), float(object.get("y", 0)))
		if not surface_is_clear(at):
			continue
		var kind: String = str(object.get("kind", "wood"))
		var extent: float = 34.0 if kind == "barrel" else 28.0
		_shadow(at + Vector2(0, 12), Vector2(extent * 0.48, 3), Color(0.12, 0.34, 0.39, 0.31))
		draw_line(at + Vector2(-extent * 0.62, 13), at + Vector2(-extent * 0.20, 13), Color(0.74, 0.85, 0.76, 0.36), 1, false)
		_sprite(kind, at, Vector2(extent, extent), Color(0.94, 0.97, 0.91))

func surface_is_clear(point: Vector2) -> bool:
	if not state.has("chart") or not state.has("navigation"):
		return true
	var nav: Dictionary = state.navigation
	for id:String in Archipelago.ISLANDS:
		var center:Vector2=Vector2(480,288)+Archipelago.island_position(state.chart,id)+Archipelago.ISLAND_BODY_OFFSET-Vector2(nav.x,nav.y)
		if point.distance_to(center)<=Archipelago.ISLAND_WORLD_RADIUS+20:return false
	return true

func _returning_drift(id: String) -> bool:
	for player in state.get("players", {}).values():
		var hook: Dictionary = player.get("hook", {})
		if id in hook.get("cargo", []):
			return true
	return false

func _focused_facility() -> String:
	if str(_local.get("area", "deck")) != "deck":
		return ""
	var found := ""
	var nearest := 65.0
	var player_at := Vector2(float(_local.get("x", 480)), float(_local.get("y", 288)))
	for objects in [state.get("structures", {}), state.get("chests", {})]:
		for id in objects:
			var object: Dictionary = objects[id]
			var at := Vector2(float(object.x), float(object.y))
			if hovered_id in [str(id), "structure:" + str(id), "chest:" + str(id)] and player_at.distance_to(at) <= 100:
				return str(id)
			var distance: float = player_at.distance_to(at)
			if distance < nearest:
				nearest = distance
				found = str(id)
	return found

func _draw_chest(id: String, chest: Dictionary) -> void:
	var at := Vector2(float(chest.get("x", 0)), float(chest.get("y", 0)))
	_shadow(at + Vector2(0, 17), Vector2(21, 5), Color(0.20, 0.19, 0.16, 0.26))
	_prop("chest_open" if id == open_chest_id else "chest", at)
	if id == _focus:
		_label(str(chest.get("name", "木箱")), at + Vector2(0, 33))

func _draw_structures() -> void:
	var structures: Dictionary = state.get("structures", {})
	var labels := {"workbench": "工作台", "bedroll": "睡袋", "bed": "床", "purifier": "净水器", "grill": "烤架", "furnace": "熔炉", "kitchen": "厨房", "garden": "种植箱", "orders": "订单", "hatch": "潜水梯"}
	for id in structures:
		var structure: Dictionary = structures[id]
		var at := Vector2(float(structure.get("x", 0)), float(structure.get("y", 0)))
		var kind: String = str(structure.get("kind", "bedroll"))
		var key: String = kind
		var remaining: float = float(structure.get("remaining", 0))
		var output: String = str(structure.get("output", ""))
		if kind == "furnace" and remaining > 0:
			key = "furnace_active"
		if kind == "garden":
			key = "garden_empty"
		var contact_y: float = float(Art.WORLD_PROPS.get(key, {}).get("contact_y", 18))
		_shadow(at + Vector2(0, contact_y), Vector2(20, 3 if kind == "bedroll" else 5), Color(0.20, 0.18, 0.16, 0.18))
		_prop(key, at)
		if kind=="garden":
			var plot:Dictionary=state.get("gardens",{}).get("planters",{}).get(id,Farming.new_plot())
			if plot.crop!="":
				draw_texture_rect(IslandArt.crop(plot.crop,int(plot.growth),bool(plot.dead)),Rect2(at+Vector2(-16,-64),Vector2(32,64)),false)
			if plot.watered:_ring(at+Vector2(0,6),9,Color(0.4,0.7,0.8,0.45))
			if plot.covered:_prop("canopy",at)
			if str(id)==_focus and plot.crop!="":_label("%d/%d天%s" % [plot.growth,Farming.CROPS[plot.crop].days," · 已浇水" if plot.watered else ""],at+Vector2(0,-65),MINT,10)
		if remaining > 0.0:
			if kind in ["grill", "kitchen", "furnace"]:
				_sprite("fire", at + Vector2(0, -16), Vector2(19, 25 + sin(_elapsed * 7) * 2))
			for index in 3:
				var rise: float = fmod(_elapsed * 8 + index * 11, 34)
				_r(at + Vector2(-5 + index * 5 + rise * 0.17, -27 - rise), Vector2(3, 4), Color(0.86, 0.87, 0.76, 0.37 * (1.0 - rise / 38)))
			if str(id) == _focus:
				_label("%d 秒" % ceili(remaining), at + Vector2(0, -39), GOLD)
		elif not output.is_empty():
			_item(output, at + Vector2(0, -44), 23)
			_r(at + Vector2(12, -47), Vector2(3, 3), GOLD)
		if str(id) == _focus:
			_label(str(labels.get(kind, kind)), at + Vector2(0, 43 if kind in ["bedroll", "bed"] else 33))

func _draw_placement() -> void:
	var at := Vector2(float(placement.get("x", 0)), float(placement.get("y", 0)))
	var valid: bool = bool(placement.get("valid", false))
	var tint := Color(0.54, 0.79, 0.61, 0.28) if valid else Color(0.87, 0.43, 0.36, 0.30)
	draw_rect(Rect2(at - Vector2(32, 32), Vector2(64, 64)), tint)
	draw_rect(Rect2(at - Vector2(31, 31), Vector2(62, 62)), Color("c5dcaf") if valid else Color("e6a087"), false, 2)
	var kind: String = str(placement.get("kind", "floor"))
	if kind=="cabin":draw_rect(Rect2(at-Vector2(160,96),Vector2(256,128)),tint)
	if kind in ["foundation", "deck", "tile", "floor"]:
		draw_texture_rect(Art.texture("floor"), Rect2(at - Vector2(32, 32), Vector2(64, 64)), false, Color(1, 1, 1, 0.65))
	else:
		_prop(kind, at, Color(1, 1, 1, 0.65))

func _draw_feedback() -> void:
	var area := str(_local.get("area", "deck"))
	for effect in feedback.effects:
		if effect.area != area and not (effect.area == "sea" and area == "deck"):
			continue
		var at: Vector2 = world_to_screen(effect.at, str(effect.area))
		var progress: float = float(effect.age) / float(effect.duration)
		var fade := 1.0 - progress
		if effect.kind == "build":
			# Keep the real footprint and sprite still; a few settling motes mark success.
			if effect.area == "deck":
				draw_set_transform_matrix(deck_transform())
				at = effect.at
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var point: Vector2 = at + corner * (28 + progress * 9)
				_r(point, Vector2(3, 3), Color(0.91, 0.80, 0.58, fade))
			draw_rect(Rect2(at - Vector2(30, 30), Vector2(60, 60)), Color(0.89, 0.84, 0.60, fade * 0.6), false, 2)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		elif effect.kind == "splash":
			for index in 8:
				var angle := index * TAU / 8.0
				var point := at + Vector2(cos(angle) * (7 + progress * 23), sin(angle) * (4 + progress * 9) - sin(progress * PI) * 8)
				_r(point, Vector2(3, 2), Color(0.78, 0.90, 0.85, fade * 0.8))
		elif effect.kind == "ready":
			for index in 4:
				var point := at + Vector2(-18 + index * 12, -46 - sin(progress * PI) * 7)
				_r(point, Vector2(2, 5), Color(0.91, 0.80, 0.54, fade))
		elif effect.kind == "gain":
			# Inventory deltas, never a prediction of the item under the pointer.
			var items: Array = effect.items
			var shown := mini(items.size(), 4)
			var width := shown * 48.0
			var start := Vector2(clampf(at.x + 24, canvas_bounds.position.x + 8, canvas_bounds.end.x - width - 8), clampf(at.y - 44 - progress * 14, canvas_bounds.position.y + 36, canvas_bounds.end.y - 24))
			_r(start + Vector2(-3, -12), Vector2(width + 4, 25), Color(0.21, 0.35, 0.34, minf(0.75, fade * 2)))
			for index in shown:
				var item: Dictionary = items[index]
				_sprite(str(item.item), start + Vector2(index * 48 + 10, 0), Vector2(19, 19), Color(1, 1, 1, minf(1.0, fade * 3)))
				_label("+%d" % int(item.amount), start + Vector2(index * 48 + 31, 4), Color(CREAM, minf(1.0, fade * 3)), 11)
			if items.size() > shown:
				_label("另有%d种" % (items.size() - shown), start + Vector2(width * 0.5, 22), CREAM, 10)


func _draw_water() -> void:
	_gradient(Color("487f9b"), Color("18394f"))
	# Broken surface light and a few soft shafts leave the playable water clear.
	for index in 27:
		var x: float = fposmod(index * 39 + _elapsed * 9, 960) - 30
		var y: float = 40 + sin(index * 2.1 + _elapsed * 0.4) * 3
		draw_line(Vector2(x, y), Vector2(x + 15 + _noise(index + 8) * 18, y), Color(0.76, 0.88, 0.79, 0.30), 1, false)
	for offset in [115, 450, 733]:
		var sway: float = sin(_elapsed * 0.11 + offset) * 10
		_polygon(Vector2(sway, 0), PackedVector2Array([Vector2(offset, 43), Vector2(offset + 19, 43), Vector2(offset + 105, 540), Vector2(offset - 37, 540)]), Color(0.66, 0.82, 0.74, 0.032))
	_draw_reef()
	for index in 36:
		var x: float = fposmod(_noise(index + 402) * 980 + _elapsed * 2.6, 980) - 40
		var y: float = 65 + fposmod(_noise(index + 440) * 455 - _elapsed * 1.3, 455)
		_r(Vector2(x, y), Vector2(1 if index % 3 else 2, 1), Color(0.60, 0.78, 0.76, 0.23))
	var entities: Dictionary = state.get("entities", {})
	# Embedded deposits remain at their actual interaction coordinates.
	for id in entities:
		var object: Dictionary = entities[id]
		var kind: String = str(object.get("kind", "fish"))
		var active: bool = bool(object.get("active", false))
		var at := Vector2(float(object.get("x", 0)), float(object.get("y", 0)))
		if kind in ["stone", "ore", "wreck"]:
			_draw_ground_anchor(at, str(id))
			if kind == "wreck":
				_draw_wreck(at, active)
			elif active:
				_sprite(kind, at, Vector2(40, 40), Color(0.85, 0.96, 0.89))
			else:
				_r(at + Vector2(-7, 11), Vector2(6, 3), Color("71857a"))
				_r(at + Vector2(7, 13), Vector2(4, 2), Color("849386"))
		elif active and kind == "fish":
			var phase: float = float(object.get("phase", 0))
			var facing: float = 1.0 if cos(_elapsed * 1.1 + phase) >= 0 else -1.0
			_draw_fish(at, phase, facing)
		elif active:
			_sprite(kind, at, Vector2(32, 32), Color(0.77, 0.91, 0.83))
		if active and (hovered_id == str(id) or _near(at, 43)):
			_ring(at, 22, Color(0.86, 0.88, 0.66, 0.50))
			if kind in ["ore", "stone", "wreck"]:
				_label({"ore": "矿石", "stone": "石料", "wreck": "沉船物资"}[kind], at + Vector2(0, -27), GOLD)
	_draw_buoy()
	_draw_sea_threats()
	# The actual deep-water doorway stays at the same point as the host trigger.
	_shadow(Rooms.SEA_ENTRY,Vector2(40,25),Color("102c3b"))
	for offset in [Vector2(-43,13),Vector2(43,13),Vector2(0,-23)]:
		draw_texture_rect(MaritimeArt.texture("rock",true),Rect2(Rooms.SEA_ENTRY+offset-Vector2(32,40),Vector2(64,64)),false,Color("799e9c"))
	_label("回声海洞 · 40米",Rooms.SEA_ENTRY+Vector2(-20,45),CREAM,11)

func _draw_room() -> void:
	var id := str(_local.room)
	var origin := _room_origin()
	var bounds := Rect2(origin+canvas_bounds.position,canvas_bounds.size)
	_r(canvas_bounds.position,canvas_bounds.size,Color("243336"))
	draw_set_transform_matrix(Transform2D(0,-origin))
	if id.begins_with("sea_"):
		draw_rect(bounds,Color("17394a"))
		var top := PackedVector2Array([Vector2(bounds.position.x-4,bounds.position.y-4),Vector2(bounds.end.x+4,bounds.position.y-4)])
		var bottom := PackedVector2Array()
		for x in range(int(bounds.position.x)-8,int(bounds.end.x)+16,8):
			bottom.append(Vector2(x,roundf(Rooms.seabed(x,Rooms.floor_number(id))/2)*2))
		for x in range(int(bounds.end.x)+8,int(bounds.position.x)-16,-8):
			top.append(Vector2(x,roundf(Rooms.ceiling(x,Rooms.floor_number(id))/2)*2))
		bottom.append(Vector2(bounds.end.x+8,bounds.end.y+8)); bottom.append(Vector2(bounds.position.x-8,bounds.end.y+8))
		MaritimeArt.polygon(self,top,MaritimeArt.texture("rock_fill",true),2,Color("91b5b3"))
		MaritimeArt.polygon(self,bottom,MaritimeArt.texture("rock_fill",true),2,Color("91b5b3"))
		for i in 14:
			var at := Vector2(30+i*67,Rooms.seabed(30+i*67,Rooms.floor_number(id))+12)
			draw_texture_rect(MaritimeArt.texture("rock",true),Rect2(at-Vector2(32,42),Vector2(64,64)),false,Color("789e9b"))
		var air := Rooms.entry(id)
		_draw_cave_mouth(air,true)
		for i in 8:
			var x:=120+i*96
			_draw_seaweed(Vector2(x,Rooms.seabed(x,Rooms.floor_number(id))+2),36 if i%3==0 else 22,i*4.1)
		for i in 5: _ring(air+Vector2(-25+i*13,-fposmod(_elapsed*12+i*7,40)),2,Color("add6cc"))
		_label("空气洞 · 停留补氧",air+Vector2(26,-58),MINT,11)
	else:
		var cells := Rect2i(Vector2i(bounds.position/32)-Vector2i(2,2),Vector2i(bounds.size/32)+Vector2i(5,5))
		IslandTiles.draw_patch(self,Rooms.source(id),cells,Vector2(cells.position)*32,2,int(state.day),["Back","Back2","Buildings","Buildings2"],Color.WHITE,_elapsed)
		if id=="greenhouse":
			for key:String in state.gardens.plots:
				var at:=Farming.plot_center(key)
				_draw_island_plot(at,state.gardens.plots[key],false,state.gardens.plots)
			_label("装水",Gardens.TAP+Vector2(0,14),MINT,11)
	for node: Dictionary in Rooms.nodes(id).values():
		var at := Vector2(node.x,node.y)
		if Rooms.active(state,node):
			if Rooms.underwater(_local):
				_draw_ground_anchor(at,node.id)
				_sprite(node.kind,at,Vector2(40,40),Color("bbd3c7"))
			elif node.kind in ["treasure","seaweed","seed","wood","fiber","mushroom"]:
				if node.kind=="treasure":_prop("treasure",at)
				elif node.kind=="wood":draw_texture_rect(IslandArt.object_texture("branch"),Rect2(at+IslandArt.RESOURCE_RECT.position,IslandArt.RESOURCE_RECT.size),false)
				else:_sprite(node.kind,at,Vector2(32,32))
			else:
				_shadow(at+Vector2(0,5),Vector2(15,5),Color(0.1,0.1,0.1,0.3))
				draw_texture_rect(IslandArt.object_texture(node.kind),Rect2(at+IslandArt.RESOURCE_RECT.position,IslandArt.RESOURCE_RECT.size),false)
		else: _sprite("stone",at+Vector2(0,8),Vector2(12,12),Color("79877f"))
	if (id.begins_with("sea_") or id.begins_with("mine_")) and Rooms.floor_number(id)<3:
		var stairs:=Rooms.onward(id)
		if id.begins_with("sea_"):_draw_cave_mouth(stairs,false)
		else:draw_texture_rect(MaritimeArt.texture("mine_ladder"),Rect2(stairs-Vector2(16,80),Vector2(32,96)),false)
	var actors: Array=[]
	for npc_id:String in OceanResidents.NPCS:
		if OceanResidents.NPCS[npc_id].room==id:actors.append({"type":"ocean_npc","y":OceanResidents.position(npc_id).y,"id":npc_id})
	for prop:Dictionary in state.housing.furniture:
		if prop.room==id:actors.append({"type":"furniture","y":prop.y,"prop":prop})
	if id=="restaurant":
		for customer:Dictionary in state.restaurant.customers:actors.append({"type":"customer","y":customer.y,"customer":customer})
	if id=="greenhouse":
		for key:String in state.gardens.plots:
			var plot:Dictionary=state.gardens.plots[key].duplicate();plot.covered=false
			actors.append({"type":"crop","y":Farming.plot_center(key).y,"at":Farming.plot_center(key),"plot":plot})
	for npc: Dictionary in IslandTown.residents(state).values():
		if npc.area=="room" and npc.room==id: actors.append({"type":"npc","y":npc.y,"npc":npc})
	for slot: String in state.players:
		var person: Dictionary=state.players[slot]
		if person.online and person.area=="room" and person.room==id: actors.append({"type":"player","y":person.y,"slot":slot})
	actors.sort_custom(func(a:Dictionary,b:Dictionary):return float(a.y)<float(b.y))
	for actor:Dictionary in actors:
		if actor.type=="player":_draw_players(actor.slot)
		elif actor.type=="ocean_npc":
			var at:=OceanResidents.position(actor.id)
			draw_texture_rect(OceanArt.texture(actor.id,_elapsed),OceanArt.rect(actor.id,at),false,Color("9ec66c") if actor.id=="tai_lu" else Color.WHITE)
			_label(str(OceanResidents.NPCS[actor.id].name),at+Vector2(0,23),CREAM,11)
		elif actor.type=="furniture":_prop("chest_open" if actor.prop.id==open_chest_id else actor.prop.item,Vector2(actor.prop.x,actor.prop.y))
		elif actor.type=="customer":_draw_customer(actor.customer)
		elif actor.type=="crop":_draw_island_plot(actor.at,actor.plot,true)
		else:_draw_town_npc(actor.npc)
	if not id.begins_with("sea_"):
		var cells := Rect2i(Vector2i(bounds.position/32)-Vector2i(2,2),Vector2i(bounds.size/32)+Vector2i(5,5))
		IslandTiles.draw_patch(self,Rooms.source(id),cells,Vector2(cells.position)*32,2,int(state.day),["Front","Front2","Front3","AlwaysFront"],Color.WHITE,_elapsed)
	if id=="restaurant":_draw_restaurant_counters()
	if id=="yard_home" and int(state.housing.level)>=2:
		_label("书房 →",Rooms.onward(id)+Vector2(0,-35),GOLD,13)
	if not placement.is_empty():_draw_placement()
	if not id.begins_with("sea_") and Vector2(_local.x,_local.y).distance_to(Rooms.entry(id))>110:_label("返回 ↑",Rooms.entry(id)+Vector2(0,32),CREAM,11)
	if id.begins_with("sea_") or id.begins_with("mine_"):
		if Rooms.floor_number(id)<3:
			var onward := Rooms.onward(id)
			_label("更深处 ↓",onward+Vector2(0,32),GOLD,11)
		else: _label("矿脉尽头 · 原路返回",Rooms.onward(id)+Vector2(0,-26),GOLD,11)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_label(Rooms.room_name(id),Vector2(450,24),CREAM,14)

func _draw_cave_mouth(at:Vector2,air:bool)->void:
	# Reuse coastal rock at its native two-times pixel density around a real opening.
	var opening:=PackedVector2Array([Vector2(-38,30),Vector2(-38,-24),Vector2(-24,-42),Vector2(24,-42),Vector2(38,-24),Vector2(38,30)])
	_polygon(at,opening,Color("203f48") if air else Color("102936"))
	for offset in [Vector2(-68,-4),Vector2(68,-4),Vector2(0,-66)]:
		draw_texture_rect(MaritimeArt.texture("rock",true),Rect2(at+offset-Vector2(48,48),Vector2(96,96)),false,Color("8eadab"))
	if air:
		_r(at+Vector2(-34,22),Vector2(68,4),Color("8fbeb7"))
		for i in 4:_r(at+Vector2(-28+i*16,24+roundf(sin(_elapsed*1.4+i)*2)),Vector2(10,2),Color("c6d9c6"))

func _draw_customer(customer:Dictionary)->void:
	var at:=Vector2(customer.x,customer.y)
	var id:String=["chen_yu","wen_zhi","qiao_xin","shi_xun","sen_ke"][int(customer.variant)]
	var frame:=CharacterArt.step_frame(float(customer.distance)) if customer.phase in ["arrive","leave"] else 0
	draw_texture_rect(CharacterArt.npc_texture(id,int(customer.direction),frame),CharacterArt.world_rect(at),false)
	if customer.phase=="wait":
		draw_style_box(preload("res://scripts/ui_style.gd").box("paper"),Rect2(at+Vector2(-18,-101),Vector2(36,34)))
		_sprite(customer.recipe,at+Vector2(0,-84),Vector2(24,24))
		_r(at+Vector2(-16,-66),Vector2(32,3),Color("836b56"))
		_r(at+Vector2(-16,-66),Vector2(32*float(customer.remaining)/65,3),Color("a6bc7e"))
	elif customer.phase=="eat":_sprite(customer.recipe,at+Vector2(0,-23),Vector2(24,24))

func _draw_restaurant_counters()->void:
	if Restaurant.near(_local,Restaurant.pantry(),120):_label("备料柜 · B",Restaurant.pantry()+Vector2(0,-66),CREAM,10)
	if Restaurant.near(_local,Restaurant.counter(),120):_label("收银台 · 左键",Restaurant.counter()+Vector2(0,-66),CREAM,10)
	for i in 2:
		var work:Dictionary=state.restaurant.stations[i]
		var at:=Restaurant.station(i)+Vector2(0,-44)
		if not work.is_empty():
			_sprite(work.recipe,at,Vector2(28,28))
			_label("可取餐" if float(work.remaining)==0 else "%.1f秒"%work.remaining,at+Vector2(0,-24),MINT,10)
		elif Restaurant.near(_local,Restaurant.station(i),96):_label("案板%d"%(i+1),at+Vector2(0,-8),CREAM,10)

func _draw_sea_threats() -> void:
	for enemy: Dictionary in state.get("threats", {}).values():
		var at := Vector2(enemy.x, enemy.y)
		var direction := Vector2(enemy.dx,enemy.dy)
		if enemy.phase == "windup":
			var spec: Dictionary = SeaThreats.DEFINITIONS[enemy.kind]
			var strength := 1.0-float(enemy.remaining)/float(spec.windup)
			for i in 8:
				var start := at+direction*(36+i*20)
				draw_line(start,start+direction*9,Color(0.96,0.69,0.42,0.20+strength*0.32),2)
			_label("!",at+Vector2(0,-43),Color("f0b668"),20)
		var transform := Transform2D(direction.angle() - (PI if direction.x < 0 else 0.0),at.round())
		transform.x *= -1.0 if direction.x < 0 else 1.0
		draw_set_transform_matrix(transform)
		var frame_index := SeaCreatures.frame(enemy)
		draw_texture_rect(SeaCreatures.texture(enemy.kind,frame_index),SeaCreatures.rect(enemy.kind,frame_index),false,Color("c3d9cb"))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		if enemy.phase == "repelled" and _near(at,200): _label("退避中",at+Vector2(0,-39),MINT,10)

func _draw_reef() -> void:
	MaritimeArt.draw_reef(self, canvas_bounds, _elapsed)

func _draw_ground_anchor(at: Vector2, id: String) -> void:
	MaritimeArt.draw_deposit(self, at, id.hash())
	var seed_value: float = float(id.hash() % 997)
	var width: float = 24 + _noise(seed_value) * 21
	_shadow(at + Vector2(1, 16), Vector2(width * 0.52, 3), Color(0.10, 0.22, 0.24, 0.38))
	for index in 4:
		var x: float = -width * 0.65 + _noise(seed_value + index * 9) * width * 1.3
		var y: float = 17 + _noise(seed_value + index * 11 + 3) * 6
		var tint := Color("a0a68b") if index % 2 == 0 else Color("6d877b")
		_r(at + Vector2(x, y), Vector2(2 + _noise(seed_value + index * 13) * 4, 1), tint)
	if _noise(seed_value + 2) > 0.87:
		_draw_seaweed(at + Vector2(-24, 20), 16 + _noise(seed_value + 1) * 11, seed_value)

func _draw_seaweed(at: Vector2, height_value: float, phase: float) -> void:
	var extent := Vector2(32,32) * (1.0 if height_value < 36 else MaritimeArt.WORLD_SCALE)
	var sway := roundf(sin(_elapsed * 0.7 + phase))
	draw_texture_rect(MaritimeArt.texture("kelp", true),Rect2((at-Vector2(extent.x/2,extent.y)+Vector2(sway,0)).round(),extent),false)

func _draw_wreck(at: Vector2, active: bool) -> void:
	# Native broken boat timbers share the raft's wood family.
	draw_texture_rect(MaritimeArt.texture("wreck",true),Rect2((at-Vector2(48,32)).round(),Vector2(96,96)),false,Color("99b9b0"))
	_prop("sea_chest" if active else "sea_chest_open", at, Color("d4e4d1") if active else Color("c0d6ca"))
	_polygon(at, PackedVector2Array([Vector2(-25, 14), Vector2(-8, 12), Vector2(5, 16), Vector2(22, 14), Vector2(28, 23), Vector2(-29, 23)]), Color("8b9b87"))
	_draw_seaweed(at + Vector2(24, 18), 22, 4.7)
	if active:
		var glint: float = maxf(0.0, sin(_elapsed * 1.3 + at.x)) * 0.55
		_r(at + Vector2(-2, -6), Vector2(5, 2), Color(0.96, 0.80, 0.43, glint))
		_r(at + Vector2(0, -8), Vector2(1, 6), Color(0.96, 0.80, 0.43, glint))

func _draw_fish(at: Vector2, phase: float, facing: float) -> void:
	var tilt: float = sin(_elapsed * 0.7 + phase) * 0.035
	var transform := Transform2D(tilt, at)
	transform.x *= facing
	draw_set_transform_matrix(transform)
	# Native side-view silhouette; keep body aspect constant instead of stretching.
	_sprite("fish_swim", Vector2(0, roundf(sin(_elapsed * 3 + phase))), Vector2(48,48), Color("c2ded0"))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_buoy() -> void:
	var at := Vector2(120, 65)
	_r(at + Vector2(-2, 0), Vector2(2, 61), Color("89aea6"))
	_sprite("barrel", at, Vector2(32, 32), Color("c9d2b7"))
	_r(at + Vector2(-1, -36), Vector2(2, 31), CREAM)
	_polygon(at, PackedVector2Array([Vector2(1, -35), Vector2(21, -33), Vector2(18, -23), Vector2(1, -25)]), Color("d78d6c"))
	if _near(at, 90):
		_label("返回木筏", at + Vector2(0, 42))

func _draw_players(only_slot: String = "") -> void:
	for person:String in ["host","guest"]:
		CharacterArt.Player.configure(person,state.get("wardrobe",{}).get(person,CharacterArt.Player.Appearance.default_for(person)))
	var players: Dictionary = state.get("players", {})
	var area: String = str(_local.get("area", "deck"))
	for slot in players:
		if not only_slot.is_empty() and slot != only_slot:
			continue
		var player: Dictionary = players[slot]
		if not bool(player.get("online", false)) or str(player.get("area", "deck")) != area:
			continue
		if area == "room" and player.get("room") != _local.get("room"): continue
		var at := Vector2(float(player.get("x", 480)), float(player.get("y", 288)))
		if area == "island" and not Rect2(canvas_bounds.position + _island_origin(), canvas_bounds.size).grow(70).has_point(at):
			continue
		var pose := _character_pose(str(slot), at, area)
		if not Rooms.underwater(player):
			_shadow(at + Vector2(0, 3), Vector2(11, 4), Color(0.20, 0.19, 0.20, 0.25))
			var activity: Dictionary = player.get("activity", {})
			var resource: Dictionary = IslandMap.node(str(activity.get("id", ""))) if activity.get("kind", "") == "island_gather" else {}
			if activity.get("kind")=="room_mine":resource=Rooms.nodes(player.room).get(str(activity.id),{})
			if resource.get("tool", "") == "axe" and not activity.get("approach",false):
				var motion := ToolMotion.sample(activity, at, Vector2(resource.x, resource.y),str(resource.kind))
				ChoppingArt.draw(self,str(slot),at,motion.direction,motion.frame,Transform2D(0,-_island_origin() if area=="island" else -_room_origin()))
				pose.direction = motion.direction
			elif Rooms.bathing(player):
				draw_texture_rect(CharacterArt.pool_texture(str(slot),int(pose.direction)),Rect2((at-Vector2(16,36)).round(),Vector2(32,38)),false)
				for ring in 2:
					var width:=18+ring*8+roundf(sin(_elapsed*2+ring)*2)
					draw_line(at+Vector2(-width,2+ring*5),at+Vector2(width,2+ring*5),Color(0.6,0.84,0.81,0.6-ring*0.2),2)
			else:
				draw_texture_rect(CharacterArt.texture(str(slot), int(pose.direction), int(pose.frame)), CharacterArt.world_rect(at), false)
			var hook: Dictionary = player.get("hook", {})
			if not hook.is_empty():
				_draw_hook(at, hook)
			var fishing: Dictionary = player.get("fishing", {})
			if not fishing.is_empty():
				_draw_fishing(at, fishing, str(slot))
			if area in ["island","room"]:
				_draw_activity(at, player.get("activity", {}))
			var cooldown: float = float(state.get("navigation", {}).get(str(slot) + "_cooldown", 0.0))
			if cooldown > 0:
				var paddle_at := at + Vector2(21, 5 + sin(cooldown / Navigation.COOLDOWN * PI) * 7)
				_sprite("paddle", paddle_at, Vector2(30, 30))
				_ring(paddle_at + Vector2(2, 11), 5 + (1.0 - cooldown / Navigation.COOLDOWN) * 10, Color(0.68, 0.85, 0.81, cooldown * 0.5))
		else:
			_draw_swimmer(at, player, str(slot), pose)
			_draw_activity(at, player.get("activity", {}))
			if float(player.get("dive_status", {}).get("hurt", 0)) > 0.0:
				_ring(at,32,Color(0.96,0.57,0.38,0.5))
		if slot == local_slot:
			var marker_y := -44.0 if Rooms.bathing(player) else -70.0 if not Rooms.underwater(player) else -26.0
			_polygon(at, PackedVector2Array([Vector2(-3, marker_y), Vector2(3, marker_y), Vector2(0, marker_y + 4)]), CREAM)
		elif _near(at, 115):
			_label(str(player.get("name", "伙伴")).left(8), at + Vector2(0, -70 if area != "water" else -28), MINT)
		if bool(player.get("sleep_ready", false)):
			_label("等你入睡", at + Vector2(0, -65))
		elif bool(player.get("resting", false)):
			_label("休息中", at + Vector2(0, -65))

func _character_pose(slot: String, at: Vector2, area: String) -> Dictionary:
	var pose: Dictionary = _character_states.get(slot, {})
	if pose.is_empty() or str(pose.area) != area or at.distance_to(pose.at) > 70 or _elapsed < float(pose.last_move):
		pose = {"at": at, "area": area, "direction": 0, "facing": 1.0, "distance": 0.0, "last_move": -1.0, "frame": CharacterArt.IDLE_FRAME}
	var movement: Vector2 = at - Vector2(pose.at)
	if movement.length() > 0.03:
		pose.direction = (2 if movement.x > 0 else 1) if absf(movement.x) > absf(movement.y) else (0 if movement.y > 0 else 3)
		if absf(movement.x) > 0.03:
			pose.facing = 1.0 if movement.x > 0 else -1.0
		pose.distance = float(pose.distance) + movement.length()
		pose.last_move = _elapsed
	pose.frame = CharacterArt.step_frame(float(pose.distance)) if _elapsed - float(pose.last_move) < 0.14 else CharacterArt.IDLE_FRAME
	pose.at = at
	_character_states[slot] = pose
	return pose

func _draw_swimmer(at: Vector2, player: Dictionary, slot: String, pose: Dictionary) -> void:
	var facing: float = float(pose.facing)
	var base := Transform2D(0,-_room_origin()) if player.area=="room" else Transform2D.IDENTITY
	var tilt:=0.0
	if _elapsed-float(pose.last_move)<0.18:
		if pose.direction==3:tilt=-PI/5*facing
		elif pose.direction==0:tilt=PI/5*facing
	var transform := base * Transform2D(tilt, at)
	transform.x *= facing
	draw_set_transform_matrix(transform)
	var skin:int=int(state.get("wardrobe",{}).get(slot,{}).get("skin",0))
	var frame:int=SwimmingArt.frame(player,pose,_elapsed)
	draw_texture_rect(SwimmingArt.texture(slot,frame,skin),Rect2(-SwimmingArt.ANCHOR*2,SwimmingArt.WORLD_SIZE),false)
	var equipped_fins := false
	for stack in player.get("bag", []):
		if stack.get("item", "") == "fins":
			equipped_fins = true
	if equipped_fins:
		_item("fins", Vector2(-24, 6), 25)
	for index in 3:
		var rise: float = fmod(_elapsed * 9 + index * 13, 40)
		_ring(Vector2(21 + index * 5, -6 - rise), 2, Color(0.68, 0.85, 0.81, 0.50 - rise * 0.01))
	draw_set_transform_matrix(base)

func _draw_hook(at: Vector2, hook: Dictionary) -> void:
	var tip := screen_to_world(Vector2(float(hook.x), float(hook.y)))
	var hand := at + Vector2(8, -12)
	draw_line(hand, tip, Color("766950"), 2, false)
	draw_line(hand, tip, Color("d5c6a1"), 1, false)
	var wake := (tip - hand).normalized()
	if str(hook.phase) == "reel":
		wake = -wake
	for index in 3:
		var behind := tip - wake * (12 + index * 7)
		_r(behind + Vector2(0, sin(_elapsed * 5 + index) * 2), Vector2(3, 2), Color(0.76, 0.87, 0.81, 0.45 - index * 0.10))
	_sprite("hook", tip, Vector2(18, 18))
	# A compact bundle shows every material kind; repeated objects share a count.
	var kinds: Array[String] = []
	var counts: Dictionary = {}
	for id in hook.get("cargo", []):
		var object: Dictionary = state.drift.get(str(id), {})
		if object.is_empty():
			continue
		var kind: String = str(object.kind)
		if not counts.has(kind):
			kinds.append(kind)
			counts[kind] = 0
		counts[kind] += 1
	var offsets := [Vector2(-12, 10), Vector2(13, 10), Vector2(-12, 33), Vector2(13, 33), Vector2(0, 55)]
	for index in kinds.size():
		var kind: String = kinds[index]
		var offset: Vector2 = Vector2(0, 8) if kinds.size() == 1 else offsets[mini(index, offsets.size() - 1)]
		var center: Vector2 = tip + offset
		_sprite(kind, center, Vector2(23, 23))
		if int(counts[kind]) > 1:
			_label("×%d" % int(counts[kind]), center + Vector2(8, 12), CREAM, 10)

func _draw_activity(at: Vector2, activity: Dictionary) -> void:
	if activity.is_empty():
		return
	if activity.kind == "room_mine":
		if activity.get("approach",false):_label("靠近木枝",at+Vector2(0,24),CREAM,10);return
		var progress := 1.0-float(activity.remaining)/float(activity.duration)
		var node: Dictionary = Rooms.nodes(activity.room)[activity.id]
		var side := -1.0 if float(node.x)<at.x else 1.0
		var hand := at+Vector2(side*13,-20 if not Rooms.underwater(_local) else 0)
		var swing := fposmod((float(activity.duration)-float(activity.remaining))*1.5,1.0)
		var tool := hand+Vector2(side*15,-18).rotated(sin(swing*TAU)*side*0.8)
		var tool_id:String=str(node.get("tool","pickaxe"))
		if tool_id!="axe":draw_line(hand,tool,Color("b2956a"),3)
		if not tool_id.is_empty() and tool_id!="axe":_item(tool_id,tool,24)
		if tool_id=="axe":
			var motion:=ToolMotion.sample(activity,at,Vector2(node.x,node.y),"wood")
			if motion.impact:
				for i in 3:_r(Vector2(node.x,node.y)+Vector2((i-1)*motion.chip_age*16,-sin(motion.chip_age*PI)*12),Vector2(2,2),GOLD)
		elif swing>0.55 and swing<0.75:
			for i in 3: _r(Vector2(node.x,node.y)+Vector2((i-1)*swing*15,-8-sin(swing*PI)*15),Vector2(2,2),GOLD)
		_r(at+Vector2(-22,23),Vector2(44,4),Color("34565a"))
		_r(at+Vector2(-22,23),Vector2(44*progress,4),GOLD)
		_label("%.1f秒" % float(activity.remaining),at+Vector2(0,43),CREAM,10)
	elif activity.kind == "island_gather":
		if activity.get("approach",false):
			_label("靠近树干",at+Vector2(0,22),CREAM,10)
			return
		var progress: float = clampf(1.0 - float(activity.remaining) / maxf(0.01, float(activity.duration)), 0, 1)
		_r(at + Vector2(-24, 12), Vector2(48, 4), Color("515e4b"))
		_r(at + Vector2(-24, 12), Vector2(48 * progress, 4), Color("d3bc80"))
		_label("%.1f 秒" % float(activity.remaining), at + Vector2(0, 29), CREAM, 10)
		var resource: Dictionary = IslandMap.node(str(activity.id))
		if not resource.is_empty():
			var target := Vector2(float(resource.x), float(resource.y))
			var motion := ToolMotion.sample(activity, at, target,str(resource.kind))
			if resource.tool not in ["axe", ""]:
				var side: float = -1.0 if target.x < at.x else 1.0
				var hand := at + Vector2(side * 12, -20)
				var tip := hand + Vector2(side * 13, -19).rotated(sin(float(motion.phase) * TAU) * 0.65 * side)
				draw_line(hand, tip, Color("b2956a"), 3, false)
				_item(str(resource.tool), tip, 22)
			if motion.impact:
				var phase: float = motion.chip_age
				var contact := ToolMotion.contact(target,int(motion.direction),str(resource.kind)) if resource.tool=="axe" else target + (at-target).normalized()*12 + Vector2(0,-3)
				for chip in 3:
					_r(contact + Vector2((chip - 1) * phase * 18, -sin(phase*PI) * (14 - chip * 2)), Vector2(2, 2), Color(0.86, 0.81, 0.61, 1 - phase))
	elif activity.kind == "town_bath":
		var progress: float = 1.0 - float(activity.remaining) / float(activity.duration)
		_r(at + Vector2(-22, 17), Vector2(44, 5), Color("6c796c"))
		_r(at + Vector2(-21, 18), Vector2(42 * progress, 3), Color("b9d2b2"))
		_label("泡澡 %.1f秒" % float(activity.remaining), at + Vector2(0, 37), CREAM, 10)
	elif activity.kind == "gather":
		var progress := 1.0 - float(activity.remaining) / float(activity.duration)
		_r(at + Vector2(-28, 31), Vector2(56, 5), Color("34565a"))
		_r(at + Vector2(-28, 31), Vector2(56 * progress, 5), Color("d3bc80"))
		_label("%.1f 秒" % float(activity.remaining), at + Vector2(0, 51), CREAM)
		var node: Dictionary = state.entities.get(str(activity.id), {})
		if not node.is_empty():
			var point := Vector2(float(node.x), float(node.y))
			var pulse := fposmod(_elapsed * 2, 1.0)
			_ring(point + Vector2(0, -5), 4 + pulse * 9, Color(0.82, 0.76, 0.56, (1 - pulse) * 0.5))
	elif activity.phase != "cooldown":
		var tip := Vector2(float(activity.x), float(activity.y))
		var direction := Vector2(float(activity.dx), float(activity.dy))
		draw_line(tip - direction * 23, tip, Color("c3ae7e"), 3, false)
		draw_line(tip, tip - direction.rotated(0.5) * 9, Color("c3d6d0"), 2, false)
		draw_line(tip, tip - direction.rotated(-0.5) * 9, Color("c3d6d0"), 2, false)
	else:
		var progress := 1 - float(activity.remaining) / float(activity.duration)
		_r(at + Vector2(-18, 30), Vector2(36 * progress, 3), Color("93b4ae"))

func _fishing_direction(at: Vector2) -> Vector2:
	var cell := Vector2(floorf(at.x / 64), floorf(at.y / 64))
	var best := Vector2.LEFT
	var best_distance: float = INF
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		if _tiles.has(_cell_key(cell + direction)):
			continue
		var edge: Vector2 = cell * 64 + Vector2(32, 32) + direction * 32
		var distance: float = at.distance_to(edge)
		if distance < best_distance:
			best_distance = distance
			best = direction
	return best

func _draw_fishing(at: Vector2, fishing: Dictionary, slot: String) -> void:
	var ready: bool = float(fishing.get("remaining", 0)) <= 0
	var direction: Vector2 = _fishing_direction(at)
	var on_island: bool = str(_local.get("area", "deck")) == "island"
	if on_island:
		direction = Vector2(-0.65, 0.76)
	var hand: Vector2 = at + Vector2(8, -12)
	var tip: Vector2 = hand + direction * 31 + Vector2(0, -26)
	var water_at: Vector2 = at + direction * 92 + Vector2(0, 8 if slot == "guest" else 0)
	water_at.y += sin(_elapsed * 1.8) * 1.2
	if not on_island:
		water_at.x = clampf(water_at.x, 14, 886)
		water_at.y = clampf(water_at.y, 16, 540)
	var bobber: Vector2 = water_at if on_island else screen_to_world(water_at)
	draw_line(hand, tip, INK, 4, false)
	draw_line(hand, tip, GOLD, 2, false)
	draw_line(tip, bobber, CREAM, 1, false)
	# Draw the float in the ocean frame; only its fishing line follows the hull.
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var screen_water: Vector2 = world_to_screen(water_at, "island") if on_island else water_at
	_shadow(screen_water + Vector2(0, 7), Vector2(11, 2), Color(0.65, 0.78, 0.70, 0.31))
	_r(screen_water + Vector2(-2, -5), Vector2(4, 10), CREAM)
	_r(screen_water + Vector2(-2, 0), Vector2(4, 5), Color("dd9274"))
	if ready:
		_label("!", screen_water + Vector2(0, -12), GOLD, 20)
	draw_set_transform_matrix(Transform2D(0, -_island_origin()) if on_island else deck_transform())
	if ready and slot == local_slot:
		_label("上钩了 · 收竿", at + Vector2(0, -49), GOLD, 12)

func _draw_distant_island() -> void:
	if not state.has("chart"):
		return
	var nav: Dictionary = state.navigation
	for id:String in Archipelago.ISLANDS:
		var dock:Vector2=Vector2(480,288)+Archipelago.island_position(state.chart,id)-Vector2(nav.x,nav.y)
		var center:Vector2=dock+Archipelago.ISLAND_BODY_OFFSET
		if not canvas_bounds.grow(220).has_point(center):continue
		MaritimeArt.draw_island(self,center,dock,int(state.day),_elapsed,id)
		_label(str(Archipelago.ISLANDS[id].name),center+Vector2(0,-156),CREAM,14)
		if Archipelago.within_docking_range(state.chart,nav,id):_label("抛锚后，在筏边登岛",dock+Vector2(58,41),CREAM,12)

func _draw_island() -> void:
	var origin: Vector2 = _island_origin()
	var bounds := Rect2(canvas_bounds.position + origin, canvas_bounds.size).grow(40)
	_draw_island_ground(bounds)
	if bounds.has_point(IslandMap.DOCK):
		IslandTiles.draw_patch(self,"Beach",Rect2i(14,23,4,2),Vector2(128,348),2.0,int(state.get("day",1)),["Back","Buildings"],Color.WHITE,_elapsed,"spring_beach")
		_sprite("anchor", Vector2(142, 377), Vector2(25, 25))
		_prop("bedroll", Vector2(305, 385))
		_sprite("rod", Vector2(248, 435), Vector2(26, 26))
		if _near(Vector2(305, 385), 55):
			_label("海岸营地", Vector2(305, 430), CREAM, 11)
	var island: Dictionary = state.get("island", {})
	var plots: Dictionary = island.get("plots", {})
	for key: String in plots:
		var at: Vector2 = (_cell(key) + Vector2.ONE * 0.5) * IslandMap.TILE
		if bounds.has_point(at):
			_draw_island_plot(at, plots[key])
	_draw_yard(bounds)
	for actor: Dictionary in island_draw_order(bounds):
		match str(actor.kind):
			"node": _draw_island_node(actor.resource, actor.at, actor.active)
			"player": _draw_players(actor.id)
			"building": _draw_town_building(actor.resource)
			"npc": _draw_town_npc(actor.resource)
			"fence": _draw_fence(actor.at, actor.horizontal)
			"crop": _draw_island_plot(actor.at, actor.resource, true)
			"chest": _draw_chest(actor.id, actor.resource)
			"beacon": _draw_beacon(actor.at)
	if not placement.is_empty():
		_draw_placement()
	if not farm_preview.is_empty():
		var at := Vector2(float(farm_preview.x), float(farm_preview.y))
		var tint := Color("c8dca4") if bool(farm_preview.get("valid", false)) else Color("b68f86")
		draw_rect(Rect2(at - Vector2(15, 15), Vector2(30, 30)), tint, false, 1)
		for corner in [Vector2(-15, -15), Vector2(15, -15), Vector2(-15, 15), Vector2(15, 15)]:
			_r(at + corner - Vector2.ONE, Vector2(3, 3), tint)

func _draw_island_ground(bounds: Rect2) -> void:
	IslandSurface.draw(self,bounds,int(state.get("day",1)),_elapsed)

func _draw_beacon(at:Vector2)->void:
	var repaired:=int(state.journal.story_step)>=1
	# Native Town street lamp: one 16x64 source, always drawn at 2x.
	draw_texture_rect_region(IslandTiles.texture("spring_town",int(state.day)),Rect2(at-Vector2(16,120),Vector2(32,128)),Rect2(176,448,16,64),Color.WHITE if repaired else Color("999b8d"))
	if repaired and float(state.minute)>=1080:
		draw_circle(at+Vector2(0,-103),25,Color(1.0,0.83,0.43,0.13))
		draw_circle(at+Vector2(0,-103),8,Color(1.0,0.91,0.65,0.28))
	if int(state.journal.story_step)>=2:
		for offset in [Vector2(32,0),Vector2(64,0)]:_draw_fence(at+offset,true)
	if _near(at,100):_label("码头引航灯 · "+("已修复" if repaired else "待修复"),at+Vector2(0,28),CREAM,11)

func _draw_yard(bounds: Rect2) -> void:
	var gate: Vector2 = IslandMap.YARD_GATE
	if bounds.has_point(gate):
		draw_texture_rect(IslandArt.region(IslandArt.season(int(state.get("day", 1))), Rect2i(144, 256, 32, 32)), Rect2(gate + Vector2(-57, -92), Vector2(48, 48)), false)
		_label("旧院", gate + Vector2(-34, -60), Color("f1d6a6"), 11)
		if _near(gate, 130):
			_label("你们的院子" if state.island.homestead.rented else "荒废的院子 · 镇长在东街", gate + Vector2(42, 48), CREAM, 12)

func _draw_fence(at: Vector2, horizontal: bool) -> void:
	var rect: Rect2i = IslandArt.REGIONS.fence_h if horizontal else IslandArt.REGIONS.fence_v
	draw_texture_rect(IslandArt.region("fence", rect), IslandArt.fence_rect(at, horizontal), false)

func island_draw_order(bounds: Rect2) -> Array:
	var actors: Array = []
	var beacon:Vector2=preload("res://scripts/journal.gd").BEACON
	if bounds.grow(128).has_point(beacon):actors.append({"kind":"beacon","id":"beacon","at":beacon,"y":beacon.y})
	var island: Dictionary = state.get("island", {})
	var plots: Dictionary = island.get("plots", {})
	var player: Dictionary = state.get("players", {}).get(local_slot, {})
	var center := Vector2(float(player.get("x", 210)), float(player.get("y", 380)))
	for id: String in IslandMap.nodes_near(center):
		var resource: Dictionary = IslandMap.node(id)
		var at := Vector2(float(resource.x), float(resource.y))
		if Housing.bounds(state).grow(16).has_point(at):continue
		if not bounds.grow(150).has_point(at) or not IslandMap.walkable(at) or (IslandMap.TOWN_BOUNDS.has_point(at) and IslandMap.terrain(at) in ["path", "bridge"]) or plots.has(Farming.plot_key(at)):
			continue
		actors.append({"kind": "node", "id": id, "at": at, "y": at.y, "resource": resource, "active": IslandState.active(island, id, int(state.get("day", 1)), state.get("chests", {}))})
	for id: String in plots:
		var at := (_cell(id) + Vector2.ONE * 0.5) * IslandMap.TILE
		if bounds.grow(64).has_point(at):
			actors.append({"kind": "crop", "id": id, "at": at, "y": at.y, "resource": plots[id]})
	for building: Dictionary in IslandMap.landmarks_near(center).values():
		if Rect2(building.bounds).grow(240).intersects(bounds):
			actors.append({"kind": "building", "id": building.id, "y": -1 if building.kind == "plaza" else Rect2(building.bounds).end.y, "resource": building})
	if int(state.get("housing",{}).get("site",-1))>=0 and Housing.bounds(state).grow(240).intersects(bounds):
		var home:=Housing.landmark(state)
		actors.append({"kind":"building","id":"yard_home","y":home.bounds.end.y,"resource":home})
	for npc: Dictionary in IslandTown.residents(state).values():
		var at := Vector2(float(npc.x), float(npc.y))
		if npc.area == "island" and bounds.grow(64).has_point(at):
			actors.append({"kind": "npc", "id": npc.id, "y": at.y, "resource": npc})
	for slot: String in state.get("players", {}):
		var entry: Dictionary = state.players[slot]
		if bool(entry.get("online", false)) and str(entry.get("area", "deck")) == "island":
			actors.append({"kind": "player", "id": slot, "y": float(entry.y)})
	var yard: Rect2 = IslandMap.YARD_BOUNDS
	for edge in [PackedVector2Array([yard.position, Vector2(yard.end.x, yard.position.y)]), PackedVector2Array([Vector2(yard.position.x, yard.end.y), yard.end]), PackedVector2Array([yard.position, Vector2(yard.position.x, yard.end.y)]), PackedVector2Array([Vector2(yard.end.x, yard.position.y), yard.end])]:
		var steps := roundi(edge[0].distance_to(edge[1]) / 32)
		for index in steps:
			var at: Vector2 = edge[0].lerp(edge[1], (float(index) + 0.5) / steps)
			if not bounds.grow(64).has_point(at) or (at.x == yard.position.x and absf(at.y - IslandMap.YARD_GATE.y) < 56):
				continue
			actors.append({"kind": "fence", "id": str(at), "y": at.y, "at": at, "horizontal": edge[0].y == edge[1].y})
	for id in state.get("chests", {}):
		var chest: Dictionary = state.chests[id]
		var at := Vector2(chest.x, chest.y)
		if chest.get("area", "deck") == "island" and bounds.grow(64).has_point(at):
			actors.append({"kind": "chest", "id": id, "y": at.y + 16, "resource": chest})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id) if a.y == b.y else a.y < b.y)
	return actors

func _draw_town_building(building: Dictionary) -> void:
	var footprint: Rect2 = building.bounds
	var door: Vector2 = building.door
	if building.id=="yard_home":
		IslandTiles.draw_facade(self,"yard_home",Vector2(door.x,footprint.end.y),int(state.day),Color("a1a38e") if int(state.housing.level)==0 else Color.WHITE)
		if int(state.housing.level)==0:
			for i in 3:_r(door+Vector2(-18,-30-i*12),Vector2(36,5),Color("92764e"))
		if _near(door,180):_label(building.name,door+Vector2(0,20),CREAM,11)
		return
	if building.kind == "plaza":
		IslandSurface.draw_plaza(self,footprint,int(state.get("day",1)))
		_label("潮芽镇", footprint.position + Vector2(footprint.size.x * 0.5, -10), CREAM, 16)
		return
	if building.kind == "mine":
		IslandTiles.draw_facade(self,"mine_entrance",door,int(state.day),Color.WHITE)
		if _near(door,160):_label(IslandMap.landmark_label(state,building.id),door+Vector2(0,22),CREAM,11)
		return
	if not building.open:
		_shadow(door + Vector2(0, -22), Vector2(24, 28), Color("575f55"))
		for index in 3:
			_r(door + Vector2(-27, -33 + index * 11), Vector2(59, 5), Color("b49a6d"))
		_label(IslandMap.landmark_label(state,building.id), door + Vector2(0, 21), CREAM, 11)
		return
	if IslandTiles.FACADES.has(str(building.id)):
		var contact:=Vector2(door.x,footprint.end.y)
		var facade:=IslandTiles.facade_rect(str(building.id),contact)
		var person:=Vector2(float(_local.get("x",0)),float(_local.get("y",0)))
		var tint:=Color(1,1,1,0.4 if person.y<footprint.position.y and facade.intersects(CharacterArt.world_rect(person)) else 1.0)
		IslandTiles.draw_facade(self,str(building.id),contact,int(state.get("day",1)),tint)
		if _near(door,160): _label(IslandMap.landmark_label(state,building.id),contact+Vector2(0,20),CREAM,11)
		return
	var threshold := Vector2(door.x, footprint.end.y)
	var spec: Dictionary = IslandArt.BUILDINGS[str(building.id)]
	var source: String = str(spec.source)
	if source == "town":
		source += "_" + IslandArt.season(int(state.get("day", 1)))
	var region: Rect2i = spec.region
	if building.id=="greenhouse" and not state.get("gardens",{}).get("greenhouse",false):region.position.y=0
	var scale_value: float = spec.scale
	var drawn := IslandArt.building_rect(str(building.id), threshold)
	var person := Vector2(float(_local.get("x", 0)), float(_local.get("y", 0)))
	var facade_tint := Color(1, 1, 1, 0.38 if person.y < footprint.position.y and drawn.intersects(CharacterArt.world_rect(person)) else 1.0)
	_shadow(threshold + Vector2(-25, 0), Vector2(footprint.size.x * 0.45, 10), Color(0.20, 0.26, 0.17, 0.16))
	if building.id == "townhall":
		# Clip unrelated atlas neighbours above the sloping roof, retaining original pixels.
		var roof_outline := PackedVector2Array(spec.outline)
		var shape := PackedVector2Array()
		var uv := PackedVector2Array()
		for point in roof_outline:
			shape.append(drawn.position + point * scale_value)
			uv.append(point / Vector2(region.size))
		draw_colored_polygon(shape, facade_tint, uv, IslandArt.region(source, region, true))
	else:
		draw_texture_rect(IslandArt.region(source, region), drawn, false, facade_tint)
	# Native doors now share the character's 2x pixel scale; no oversized overlay.
	_label(IslandMap.landmark_label(state,building.id), threshold + Vector2(0, 19), CREAM, 11)

func _draw_town_npc(npc: Dictionary) -> void:
	var at := Vector2(float(npc.x), float(npc.y))
	_shadow(at+Vector2(0,2),Vector2(9,3),Color(0.22,0.29,0.18,0.24))
	draw_texture_rect(CharacterArt.npc_texture(str(npc.id),int(npc.get("direction",0)),CharacterArt.step_frame(float(npc.get("distance",0))) if npc.get("moving",false) else 0),CharacterArt.world_rect(at),false)
	_label(str(npc.name),at+Vector2(0,16),CREAM,10)

func _draw_island_node(resource: Dictionary, at: Vector2, active: bool) -> void:
	var kind: String = str(resource.kind)
	if kind == "tree":
		_shadow(at + Vector2(0, 1), Vector2(20, 5), Color(0.18, 0.28, 0.10, 0.24))
		var drawn := IslandArt.tree_rect(at, active)
		if active:
			for player in state.players.values():
				var activity:Dictionary=player.get("activity",{})
				if player.online and activity.get("kind","")=="island_gather" and activity.get("id","")==resource.id:
					var motion:=ToolMotion.sample(activity,Vector2(player.x,player.y),at)
					if motion.impact:
						drawn.position.x+=roundf(sin(float(motion.chip_age)*TAU)*2*(1-float(motion.chip_age)))
		var person := Vector2(float(_local.get("x", 0)), float(_local.get("y", 0)))
		var canopy_alpha := 0.38 if active and person.y < at.y and drawn.intersects(CharacterArt.world_rect(person)) else 1.0
		draw_texture_rect(IslandArt.tree(int(state.get("day", 1)), active), drawn, false, Color(1, 1, 1, canopy_alpha))
		if not active:
			for effect in feedback.effects:
				if effect.kind!="tree_fall" or effect.items[0].id!=resource.id:continue
				var phase:=clampf(float(effect.age)/float(effect.duration),0,1)
				var lean:=float(effect.items[0].side)*pow(phase,1.7)*0.8
				var fade:=1.0-clampf((phase-0.55)/0.45,0,1)
				draw_set_transform_matrix(Transform2D(0,-_island_origin())*Transform2D(lean,at))
				draw_texture_rect(IslandArt.tree(int(state.day),true),IslandArt.tree_rect(Vector2.ZERO,true),false,Color(1,1,1,fade))
				draw_set_transform_matrix(Transform2D(0,-_island_origin()))
				for leaf in 5:
					_r(at+Vector2((leaf-2)*phase*14,-12-sin(phase*PI)*(12+leaf*3)),Vector2(3,2),Color(0.64,0.71,0.35,1-phase))
	elif active and kind == "fiber":
		var offset := Vector2(sin(_elapsed*1.3+at.x)*0.7,0).round()
		draw_texture_rect(IslandArt.grass(int(state.get("day",1)),int(at.x+at.y)),Rect2(at+Vector2(-16,-32)+offset,Vector2(32,40)),false)
	elif active:
		_shadow(at + Vector2(1, 7), Vector2(13, 4), Color(0.24, 0.30, 0.20, 0.17))
		draw_texture_rect(IslandArt.object_texture(kind), Rect2(at + IslandArt.RESOURCE_RECT.position, IslandArt.RESOURCE_RECT.size), false)
	if active and (str(resource.id) == hovered_id or "island:" + str(resource.id) == hovered_id):
		draw_arc(at + Vector2(0, 5), 21, 0.12, PI - 0.12, 12, Color(0.90, 0.85, 0.62, 0.7), 1, false)

func _draw_island_plot(at: Vector2, plot: Dictionary, plants_only := false, soil_plots: Dictionary = {}) -> void:
	if not plants_only:
		if soil_plots.is_empty():soil_plots=state.island.plots
		var neighbors:=0
		var directions: Array[Vector2]=[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]
		for index in directions.size():
			if soil_plots.has(Farming.plot_key(at+directions[index]*32)): neighbors|=1<<index
		var soil := IslandArt.soil(bool(plot.get("watered", false)),neighbors)
		draw_texture_rect(soil, Rect2(at - Vector2(16, 16), Vector2(32, 32)), false)
		return
	var covered: bool = bool(plot.get("covered", false))
	if covered:
		_prop("canopy", at)
	var crop: String = str(plot.get("crop", ""))
	if Farming.CROPS.has(crop):
		var tint := Color.WHITE
		draw_texture_rect(IslandArt.crop(crop, int(plot.get("growth", 0)), bool(plot.get("dead", false))), Rect2(at + IslandArt.CROP_RECT.position, IslandArt.CROP_RECT.size), false, tint)
	if covered:
		# Front wood rim occludes only the plant roots; the open lid stays behind.
		var frame: Rect2 = Art.world_rect("canopy", at)
		var texture: Texture2D = Art.texture("canopy")
		var h: float = texture.get_height()
		draw_texture_rect_region(texture, Rect2(frame.position+Vector2(0,frame.size.y-6),Vector2(frame.size.x,6)),Rect2(0,h-3,texture.get_width(),3))

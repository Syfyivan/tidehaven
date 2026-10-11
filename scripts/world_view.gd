extends Node2D
## Read-only scenery. Only the raft moves; the camera and gameplay coordinates stay fixed.

const Art = preload("res://scripts/art_catalog.gd")
const CharacterArt = preload("res://scripts/character_art.gd")
const Navigation = preload("res://scripts/navigation.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
const IslandState = preload("res://scripts/island_state.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const Farming = preload("res://scripts/farming.gd")
const IslandTown = preload("res://scripts/island_town.gd")
const INK := Color("363b3b")
const CREAM := Color("eddfb9")
const MINT := Color("a3c5a0")
const GOLD := Color("dcb277")
const PLANKS := [Color("987b5d"), Color("917458"), Color("9e8061"), Color("8e755d"), Color("a18463")]

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

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	if area == "island":
		return point - _island_origin()
	return deck_transform() * point if area == "deck" else point

func screen_to_world(point: Vector2, area: String = "deck") -> Vector2:
	if area == "island":
		return point + _island_origin()
	return deck_transform().affine_inverse() * point if area == "deck" else point

func _island_origin() -> Vector2:
	var player: Dictionary = state.get("players", {}).get(local_slot, {})
	return IslandMap.page_origin(Vector2(float(player.get("x", 210)), float(player.get("y", 380))))

func _draw() -> void:
	_local = state.get("players", {}).get(local_slot, {})
	_elapsed = float(state.get("elapsed", 0.0))
	_tiles.clear()
	for tile in state.get("deck_tiles", []):
		_tiles[str(tile)] = true
	_focus = _focused_facility()
	if str(_local.get("area", "deck")) == "water":
		_draw_water()
		_draw_players()
	elif str(_local.get("area", "deck")) == "island":
		_ocean()
		draw_set_transform_matrix(Transform2D(0, -_island_origin()))
		_draw_island()
		_draw_players()
	else:
		_ocean()
		_draw_navigation()
		_draw_drift()
		_draw_distant_island()
		draw_set_transform_matrix(deck_transform())
		_draw_deck()
		_draw_players()
		if not placement.is_empty():
			_draw_placement()
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _r(at: Vector2, size_value: Vector2, color: Color) -> void:
	draw_rect(Rect2(at.round(), size_value), color)

func _sprite(key: String, at: Vector2, size_value: Vector2 = Vector2(40, 40), tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = Art.texture(key)
	if texture != null:
		draw_texture_rect(texture, Rect2((at - size_value * 0.5).round(), size_value), false, tint)

func _item(key: String, at: Vector2, extent: float) -> void:
	var texture: Texture2D = Art.item_icon(key)
	if texture != null:
		draw_texture_rect(texture, Rect2((at - Vector2.ONE * extent * 0.5).round(), Vector2.ONE * extent), false)

func _label(text: String, at: Vector2, color: Color = CREAM, font_size: int = 11) -> void:
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var start := Vector2(roundf(at.x - width * 0.5), roundf(at.y))
	draw_string(_font, start + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
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
	_gradient(Color("4c959a"), Color("326f7e"))
	var swell: float = preload("res://scripts/salvage_hook.gd").wave(_elapsed)
	var nav: Dictionary = state.get("navigation", Navigation.create())
	var travel := Vector2(float(nav.x), float(nav.y))
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
		_sprite("fish", Vector2(x, y), Vector2(25, 20), Color(0.29, 0.49, 0.51, 0.23))
		_sprite("fish", Vector2(x - 24, y + 11), Vector2(19, 15), Color(0.29, 0.49, 0.51, 0.17))

func _draw_navigation() -> void:
	var nav: Dictionary = state.get("navigation", Navigation.create())
	var bounds := Rect2(384, 192, 192, 192)
	for key in _tiles:
		bounds = bounds.merge(Rect2(_cell(str(key)) * 64, Vector2(64, 64)))
	if bool(nav.get("moored", false)):
		var dock := Vector2(480, 288) + Archipelago.island_position(state.chart) - Vector2(float(nav.x), float(nav.y))
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
		_draw_chest(str(id), state.chests[id])

func _draw_planks(cell: Vector2) -> void:
	var origin := cell * 64
	_r(origin, Vector2(64, 64), Color("655543"))
	for row in 4:
		var global_row := int(cell.y) * 4 + row
		var board_width: float = 96 + posmod(global_row, 3) * 16
		var stagger: float = board_width * 0.5 if global_row % 2 == 0 else 11.0
		var first_board := floori((origin.x + stagger) / board_width)
		for board in range(first_board, first_board + 2):
			var start: float = board * board_width - stagger
			var left: float = maxf(origin.x, start)
			var right: float = minf(origin.x + 64, start + board_width)
			if right <= left:
				continue
			var y: float = origin.y + row * 16
			var seed_value := float(global_row * 31 + board * 13)
			var tone: Color = PLANKS[posmod(global_row + board * 3, PLANKS.size())]
			_r(Vector2(left, y + 1), Vector2(right - left, 14), tone)
			_r(Vector2(left, y + 1), Vector2(right - left, 1), Color(0.78, 0.65, 0.47, 0.36))
			_r(Vector2(left, y + 14), Vector2(right - left, 1), Color(0.33, 0.26, 0.20, 0.24))
			if start >= origin.x:
				_r(Vector2(start, y + 1), Vector2(1, 14), Color("6b5743"))
				_r(Vector2(start + 4, y + 4), Vector2(2, 2), Color("695e4d"))
			for grain in 3:
				var grain_start: float = start + 11 + _noise(seed_value + grain * 7) * (board_width - 36)
				var grain_left: float = maxf(left, grain_start)
				var grain_right: float = minf(right, grain_start + 9 + _noise(seed_value + grain * 17 + 3) * 27)
				if grain_right > grain_left:
					_r(Vector2(grain_left, y + 4 + grain * 3), Vector2(grain_right - grain_left, 1), Color(0.38, 0.31, 0.23, 0.19))
			var knot_x: float = start + board_width * 0.63
			if knot_x > left + 3 and knot_x < right - 3 and global_row % 3 == 0:
				_r(Vector2(knot_x - 3, y + 7), Vector2(7, 2), Color(0.37, 0.29, 0.21, 0.29))
				_r(Vector2(knot_x - 1, y + 6), Vector2(3, 4), Color(0.37, 0.29, 0.21, 0.22))

func _draw_raft_edge(cell: Vector2) -> void:
	var at := cell * 64
	if not _tiles.has(_cell_key(cell + Vector2.UP)):
		_r(at + Vector2(0, -2), Vector2(64, 4), Color("71604b"))
		_r(at + Vector2(0, -2), Vector2(64, 1), Color("b19a76"))
		_rope_tie(at + Vector2(13, -3), false)
		_rope_tie(at + Vector2(49, -3), false)
	if not _tiles.has(_cell_key(cell + Vector2.DOWN)):
		_r(at + Vector2(0, 61), Vector2(64, 9), Color("5d4c3d"))
		_r(at + Vector2(0, 61), Vector2(64, 3), Color("917553"))
		_r(at + Vector2(3, 67), Vector2(58, 2), Color("4c463b"))
		_rope_tie(at + Vector2(13, 58), false)
		_rope_tie(at + Vector2(49, 58), false)
		var ripple: float = sin(_elapsed * 0.8 + cell.x * 1.7) * 4
		draw_line(at + Vector2(9 + ripple, 73), at + Vector2(40 + ripple, 73), Color(0.66, 0.80, 0.73, 0.25), 1, false)
	if not _tiles.has(_cell_key(cell + Vector2.LEFT)):
		_r(at + Vector2(-2, 0), Vector2(4, 64), Color("655743"))
		_r(at + Vector2(-2, 2), Vector2(1, 58), Color("ae9570"))
		_rope_tie(at + Vector2(-3, 29), true)
	if not _tiles.has(_cell_key(cell + Vector2.RIGHT)):
		_r(at + Vector2(61, 0), Vector2(4, 64), Color("65513f"))
		_r(at + Vector2(61, 2), Vector2(1, 58), Color("aa8e68"))
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
	var center: Vector2 = Vector2(480, 288) + Archipelago.island_position(state.chart) + Archipelago.ISLAND_BODY_OFFSET - Vector2(float(nav.x), float(nav.y))
	return point.distance_to(center) > Archipelago.ISLAND_WORLD_RADIUS + 20

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
	_sprite("chest", at + Vector2(0, -5), Vector2(43, 43), Color(0.96, 0.96, 0.91))
	if id == _focus:
		_label(str(chest.get("name", "木箱")), at + Vector2(0, 33))

func _draw_structures() -> void:
	var structures: Dictionary = state.get("structures", {})
	var labels := {"bedroll": "睡袋", "bed": "床", "purifier": "净水器", "grill": "烤架", "furnace": "熔炉", "kitchen": "厨房", "garden": "种植箱", "orders": "订单", "hatch": "潜水梯"}
	for id in structures:
		var structure: Dictionary = structures[id]
		var at := Vector2(float(structure.get("x", 0)), float(structure.get("y", 0)))
		var kind: String = str(structure.get("kind", "bedroll"))
		var key: String = kind
		var extent := Vector2(42, 42)
		var remaining: float = float(structure.get("remaining", 0))
		var output: String = str(structure.get("output", ""))
		if kind in ["bed", "bedroll"]:
			extent = Vector2(30, 45) if kind == "bedroll" else Vector2(30, 52)
		elif kind == "garden":
			var stage: int = int(state.get("crop", {}).get("stage", 0))
			key = "garden" if stage == 2 else ("garden_growing" if stage == 1 else "garden_empty")
		_shadow(at + Vector2(0, 18), Vector2(20, 5), Color(0.20, 0.18, 0.16, 0.23))
		_sprite(key, at + Vector2(0, -5), extent, Color(0.97, 0.98, 0.92))
		if kind == "purifier":
			_item("freshwater", at + Vector2(11, -20), 20)
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
			_label(str(labels.get(kind, kind)), at + Vector2(0, 33))

func _draw_placement() -> void:
	var at := Vector2(float(placement.get("x", 0)), float(placement.get("y", 0)))
	var valid: bool = bool(placement.get("valid", false))
	var tint := Color(0.54, 0.79, 0.61, 0.28) if valid else Color(0.87, 0.43, 0.36, 0.30)
	draw_rect(Rect2(at - Vector2(32, 32), Vector2(64, 64)), tint)
	draw_rect(Rect2(at - Vector2(31, 31), Vector2(62, 62)), Color("c5dcaf") if valid else Color("e6a087"), false, 2)
	var kind: String = str(placement.get("kind", "floor"))
	if kind in ["foundation", "deck", "tile", "floor"]:
		for row in 3:
			_r(at + Vector2(-21, -17 + row * 12), Vector2(42, 10), Color(0.65, 0.54, 0.39, 0.65))
	else:
		_sprite(kind, at, Vector2(43, 43), Color(1, 1, 1, 0.65))

func _draw_water() -> void:
	_gradient(Color("438c99"), Color("193f55"))
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

func _draw_reef() -> void:
	# Three large reefs have roots all the way to the sand. Deposits belong to
	# these shared landforms rather than receiving their own isolated podiums.
	_reef_mass(PackedVector2Array([Vector2(182, 365), Vector2(240, 337), Vector2(274, 306), Vector2(332, 310), Vector2(399, 344), Vector2(473, 317), Vector2(521, 350), Vector2(584, 415), Vector2(650, 335), Vector2(716, 359), Vector2(800, 338), Vector2(853, 363), Vector2(916, 386)]), Color("305d66"), Color("3c6870"))
	_reef_mass(PackedVector2Array([Vector2(224, 357), Vector2(250, 328), Vector2(280, 296), Vector2(317, 298), Vector2(348, 321), Vector2(388, 337), Vector2(421, 332), Vector2(457, 311), Vector2(478, 306), Vector2(504, 313), Vector2(531, 352), Vector2(552, 412), Vector2(583, 461)]), Color("456b6b"), Color("84968a"))
	_reef_mass(PackedVector2Array([Vector2(575, 426), Vector2(605, 361), Vector2(634, 320), Vector2(660, 317), Vector2(689, 339), Vector2(723, 359), Vector2(762, 368), Vector2(788, 355), Vector2(811, 357), Vector2(840, 379), Vector2(872, 399), Vector2(919, 390)]), Color("50736f"), Color("8b9c88"))
	# Broad submerged faces form stepped shelves and occasional shadowed fissures.
	_polygon(Vector2.ZERO, PackedVector2Array([Vector2(267, 333), Vector2(319, 322), Vector2(369, 350), Vector2(353, 397), Vector2(373, 453), Vector2(343, 517), Vector2(253, 553), Vector2(262, 407)]), Color(0.18, 0.34, 0.37, 0.23))
	_polygon(Vector2.ZERO, PackedVector2Array([Vector2(469, 334), Vector2(491, 328), Vector2(524, 379), Vector2(503, 425), Vector2(541, 498), Vector2(512, 560), Vector2(442, 560), Vector2(468, 447)]), Color(0.20, 0.36, 0.38, 0.20))
	_polygon(Vector2.ZERO, PackedVector2Array([Vector2(653, 348), Vector2(677, 357), Vector2(714, 419), Vector2(702, 481), Vector2(756, 560), Vector2(670, 560), Vector2(662, 453)]), Color(0.23, 0.39, 0.39, 0.26))
	# A low foreground terrace links the lower deposits into one sandy shelf.
	_reef_mass(PackedVector2Array([Vector2(184, 521), Vector2(240, 506), Vector2(291, 490), Vector2(328, 483), Vector2(369, 494), Vector2(408, 482), Vector2(446, 488), Vector2(488, 480), Vector2(521, 478), Vector2(560, 495), Vector2(609, 513), Vector2(655, 513), Vector2(700, 526), Vector2(738, 490), Vector2(775, 499), Vector2(826, 514), Vector2(915, 515)]), Color("658176"), Color("97a28b"))
	var shore_left: float = minf(-35, canvas_bounds.position.x - 5)
	var shore_right: float = maxf(945, canvas_bounds.end.x + 5)
	var shore_bottom: float = maxf(580, canvas_bounds.end.y + 5)
	var shore := PackedVector2Array([Vector2(shore_left, shore_bottom)])
	for x in range(int(shore_left), int(shore_right) + 49, 49):
		shore.append(Vector2(x, 536 + sin(float(x) / 49 * 0.68) * 11 + _noise(float(x) / 49 + 780) * 8))
	shore.append(Vector2(shore_right + 49, shore_bottom))
	draw_colored_polygon(shore, Color("778d7c"))
	for index in 23:
		var x: float = 7 + _noise(index + 802) * 890
		var y: float = 541 + _noise(index + 830) * 17
		_r(Vector2(x, y), Vector2(3 + _noise(index + 859) * 5, 2), Color("a0a88d"))
		if index % 4 == 0:
			_draw_seaweed(Vector2(x, y + 4), 26 + _noise(index + 890) * 32, index)
		elif index % 7 == 1:
			_sprite("plant", Vector2(x + 12, y - 4), Vector2(26, 30), Color("ab9e8b"))
	# Broken seams and small gravel pockets replace uniformly framed resource pads.
	for index in 24:
		var x: float = 274 + _noise(index + 910) * 600
		var y: float = 427 + _noise(index + 944) * 100
		var length_value: float = 9 + _noise(index + 975) * 24
		draw_polyline(PackedVector2Array([Vector2(x, y).round(), Vector2(x + length_value * 0.4, y + 2).round(), Vector2(x + length_value, y + 1).round()]), Color(0.19, 0.34, 0.35, 0.27), 1, false)

func _reef_mass(ridge: PackedVector2Array, color: Color, crest: Color) -> void:
	if ridge[ridge.size() - 1].x >= 900 and canvas_bounds.end.x > ridge[ridge.size() - 1].x:
		ridge.append(Vector2(canvas_bounds.end.x + 5, ridge[ridge.size() - 1].y))
	var body: PackedVector2Array = ridge.duplicate()
	body.append(Vector2(ridge[ridge.size() - 1].x, maxf(575, canvas_bounds.end.y + 5)))
	body.append(Vector2(ridge[0].x, maxf(575, canvas_bounds.end.y + 5)))
	draw_colored_polygon(body, color)
	draw_polyline(ridge, crest, 2, false)

func _draw_ground_anchor(at: Vector2, id: String) -> void:
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
	for blade in 3:
		var base := at + Vector2((blade - 1) * 5, 0)
		var height: float = height_value * (0.65 + blade * 0.14)
		var bend: float = sin(_elapsed * 0.7 + phase + blade * 0.6) * 3 + 4
		var color := Color("527f6f") if blade != 1 else Color("789983")
		draw_polyline(PackedVector2Array([base.round(), (base + Vector2(bend * 0.2, -height * 0.4)).round(), (base + Vector2(bend, -height)).round()]), color, 3, false)
		draw_line((base + Vector2(bend * 0.3, -height * 0.4)).round(), (base + Vector2(bend - 6, -height * 0.6)).round(), color, 2, false)

func _draw_wreck(at: Vector2, active: bool) -> void:
	# Broken hull boards and sand overlap the chest's lower edge, not its hit point.
	_polygon(at, PackedVector2Array([Vector2(-37, 13), Vector2(-32, 9), Vector2(34, 19), Vector2(32, 24)]), Color("5d6857"))
	_polygon(at, PackedVector2Array([Vector2(-22, 23), Vector2(-25, 18), Vector2(25, -2), Vector2(29, 2)]), Color("74806a"))
	_sprite("treasure" if active else "chest_open", at + Vector2(0, -2), Vector2(47, 43), Color("d4d5b9") if active else Color("c0cbb7"))
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
	var flick: float = sin(_elapsed * 7 + phase) * 2
	_polygon(Vector2.ZERO, PackedVector2Array([Vector2(-10, 0), Vector2(-20, -5 + flick), Vector2(-18, 6 + flick)]), Color("77aeb0"))
	_sprite("fish", Vector2.ZERO, Vector2(38, 31 + sin(_elapsed * 5 + phase)), Color("c2ded0"))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_buoy() -> void:
	var at := Vector2(120, 65)
	_r(at + Vector2(-2, 0), Vector2(2, 61), Color("89aea6"))
	_sprite("barrel", at, Vector2(32, 32), Color("c9d2b7"))
	_r(at + Vector2(-1, -36), Vector2(2, 31), CREAM)
	_polygon(at, PackedVector2Array([Vector2(1, -35), Vector2(21, -33), Vector2(18, -23), Vector2(1, -25)]), Color("d78d6c"))
	if _near(at, 90):
		_label("返回木筏", at + Vector2(0, 42))

func _draw_players() -> void:
	var players: Dictionary = state.get("players", {})
	var area: String = str(_local.get("area", "deck"))
	for slot in players:
		var player: Dictionary = players[slot]
		if not bool(player.get("online", false)) or str(player.get("area", "deck")) != area:
			continue
		var at := Vector2(float(player.get("x", 480)), float(player.get("y", 288)))
		if area == "island" and not Rect2(canvas_bounds.position + _island_origin(), canvas_bounds.size).grow(70).has_point(at):
			continue
		var pose := _character_pose(str(slot), at, area)
		if area != "water":
			_shadow(at + Vector2(0, 3), Vector2(11, 4), Color(0.20, 0.19, 0.20, 0.25))
			draw_texture_rect(CharacterArt.texture(str(slot), int(pose.direction), int(pose.frame)), Rect2((at + Vector2(-24, -45)).round(), Vector2(48, 48)), false)
			var hook: Dictionary = player.get("hook", {})
			if not hook.is_empty():
				_draw_hook(at, hook)
			var fishing: Dictionary = player.get("fishing", {})
			if not fishing.is_empty():
				_draw_fishing(at, fishing, str(slot))
			if area == "island":
				_draw_activity(at, player.get("activity", {}))
			var cooldown: float = float(state.get("navigation", {}).get(str(slot) + "_cooldown", 0.0))
			if cooldown > 0:
				var paddle_at := at + Vector2(21, 5 + sin(cooldown / Navigation.COOLDOWN * PI) * 7)
				_sprite("paddle", paddle_at, Vector2(30, 30))
				_ring(paddle_at + Vector2(2, 11), 5 + (1.0 - cooldown / Navigation.COOLDOWN) * 10, Color(0.68, 0.85, 0.81, cooldown * 0.5))
		else:
			_draw_swimmer(at, player, str(slot), pose)
			_draw_activity(at, player.get("activity", {}))
		if slot == local_slot:
			var marker_y := -52.0 if area != "water" else -26.0
			_polygon(at, PackedVector2Array([Vector2(-3, marker_y), Vector2(3, marker_y), Vector2(0, marker_y + 4)]), CREAM)
		elif _near(at, 115):
			_label(str(player.get("name", "伙伴")).left(8), at + Vector2(0, -52 if area != "water" else -28), MINT)
		if bool(player.get("sleep_ready", false)):
			_label("等你入睡", at + Vector2(0, -65))
		elif bool(player.get("resting", false)):
			_label("休息中", at + Vector2(0, -65))

func _character_pose(slot: String, at: Vector2, area: String) -> Dictionary:
	var pose: Dictionary = _character_states.get(slot, {})
	if pose.is_empty() or str(pose.area) != area or at.distance_to(pose.at) > 70 or _elapsed < float(pose.last_move):
		pose = {"at": at, "area": area, "direction": 0, "facing": 1.0, "distance": 0.0, "last_move": -1.0, "frame": 1}
	var movement: Vector2 = at - Vector2(pose.at)
	if movement.length() > 0.03:
		pose.direction = (2 if movement.x > 0 else 1) if absf(movement.x) > absf(movement.y) else (0 if movement.y > 0 else 3)
		if absf(movement.x) > 0.03:
			pose.facing = 1.0 if movement.x > 0 else -1.0
		pose.distance = float(pose.distance) + movement.length()
		pose.last_move = _elapsed
	pose.frame = CharacterArt.step_frame(float(pose.distance)) if _elapsed - float(pose.last_move) < 0.14 else 1
	pose.at = at
	_character_states[slot] = pose
	return pose

func _draw_swimmer(at: Vector2, player: Dictionary, slot: String, pose: Dictionary) -> void:
	var facing: float = float(pose.facing)
	var transform := Transform2D(0, at)
	transform.x *= facing
	draw_set_transform_matrix(transform * Transform2D(PI * 0.5, Vector2.ZERO))
	draw_texture_rect(CharacterArt.texture(slot, 0, 1), Rect2(-24, -24, 48, 48), false)
	draw_set_transform_matrix(transform)
	# Runtime diving kit; the source pack has walking frames, not swimming frames.
	_r(Vector2(-8, -15), Vector2(18, 7), Color("43666e"))
	_r(Vector2(-6, -15), Vector2(14, 4), Color("9cb3a7"))
	_r(Vector2(12, -7), Vector2(13, 11), Color("354951"))
	_r(Vector2(14, -5), Vector2(9, 6), Color("a1d4d3"))
	_r(Vector2(15, -5), Vector2(4, 2), Color("d5e7d7"))
	var equipped_fins := false
	for stack in player.get("bag", []):
		if stack.get("item", "") == "fins":
			equipped_fins = true
	if equipped_fins:
		_item("fins", Vector2(-24, 6), 25)
	else:
		var kick: float = sin(_elapsed * 5.5) * 2
		_r(Vector2(-25, 8 + kick), Vector2(10, 4), Color("d5ad72"))
		_r(Vector2(-25, -3 - kick), Vector2(10, 4), Color("d5ad72"))
	for index in 3:
		var rise: float = fmod(_elapsed * 9 + index * 13, 40)
		_ring(Vector2(21 + index * 5, -6 - rise), 2, Color(0.68, 0.85, 0.81, 0.50 - rise * 0.01))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_hook(at: Vector2, hook: Dictionary) -> void:
	var tip := screen_to_world(Vector2(float(hook.x), float(hook.y)))
	var hand := at + Vector2(8, -12)
	draw_line(hand, tip, Color("766950"), 2, false)
	draw_line(hand, tip, Color("d5c6a1"), 1, false)
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
	if activity.kind == "island_gather":
		var progress: float = clampf(1.0 - float(activity.remaining) / maxf(0.01, float(activity.duration)), 0, 1)
		_r(at + Vector2(-24, 12), Vector2(48, 4), Color("515e4b"))
		_r(at + Vector2(-24, 12), Vector2(48 * progress, 4), Color("d3bc80"))
		_label("%.1f 秒" % float(activity.remaining), at + Vector2(0, 29), CREAM, 10)
		var resource: Dictionary = IslandMap.node(str(activity.id))
		if not resource.is_empty():
			var target := Vector2(float(resource.x), float(resource.y))
			var side: float = -1.0 if target.x < at.x else 1.0
			var hand := at + Vector2(side * 14, -20)
			var tip := hand + Vector2(side * 13, -19).rotated(sin(_elapsed * 9.0) * 0.65 * side)
			draw_line(hand, tip, Color("b2956a"), 3, false)
			_item(str(resource.tool), tip, 22)
			var phase: float = fposmod(_elapsed * 2.6, 1.0)
			for chip in 3:
				_r(target + Vector2((chip - 1) * phase * 14, -phase * (13 - chip * 2)), Vector2(2, 2), Color(0.86, 0.81, 0.61, 1 - phase))
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

func _coastal_tree(at: Vector2, scale_value: float = 1.0) -> void:
	_shadow(at + Vector2(12, 4), Vector2(27, 7) * scale_value, Color(0.29, 0.38, 0.24, 0.15))
	_sprite("tree", at + Vector2(sin(_elapsed * 0.65 + at.x) * 0.7, -43) * scale_value, Vector2(48, 96) * scale_value)

func _pixel_coast(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in points.size():
		var start: Vector2 = points[index]
		var finish: Vector2 = points[(index + 1) % points.size()]
		var steps := maxi(1, ceili(start.distance_to(finish) / 4.0))
		for step in steps:
			var at: Vector2 = (start.lerp(finish, float(step) / steps) / 4.0).round() * 4.0
			if result.is_empty() or result[result.size() - 1] != at:
				result.append(at)
	return result

func _island_shapes(points: PackedVector2Array, center: Vector2) -> void:
	var shallow := PackedVector2Array()
	var grass := PackedVector2Array()
	for point in points:
		shallow.append((center + (point - center) * 1.07).round())
		grass.append((center + (point - center) * 0.84).round())
	shallow = _pixel_coast(shallow)
	grass = _pixel_coast(grass)
	var sand := _pixel_coast(points)
	draw_colored_polygon(shallow, Color("70aaa0"))
	draw_colored_polygon(sand, Color("d2c493"))
	var surf := sand.duplicate()
	surf.append(points[0])
	draw_polyline(surf, Color("b4d3bd"), 3, false)
	draw_colored_polygon(grass, Color("8ea16c"))
	for index in range(0, grass.size(), 2):
		draw_line(grass[index], grass[(index + 1) % grass.size()], Color("aabb7c"), 4, false)

func _draw_distant_island() -> void:
	if not state.has("chart"):
		return
	var nav: Dictionary = state.navigation
	var dock: Vector2 = Vector2(480, 288) + Archipelago.island_position(state.chart) - Vector2(float(nav.x), float(nav.y))
	var center: Vector2 = dock + Archipelago.ISLAND_BODY_OFFSET
	if not canvas_bounds.grow(220).has_point(center):
		return
	var points := PackedVector2Array()
	for index in 14:
		var angle := index * TAU / 14
		var radius := 136.0 + _noise(float(index)) * 14
		points.append((center + Vector2(cos(angle), sin(angle)) * radius).round())
	_island_shapes(points, center)
	for index in 6:
		var offset := Vector2(-55 + (index % 3) * 45, -35 + (index / 3) * 72)
		_coastal_tree(center + offset, 0.8)
	_sprite("rock", center + Vector2(57, -60), Vector2(48, 48))
	for index in 8:
		_r(dock + Vector2(40 + index * 7, -14), Vector2(6, 28), Color("bca17a") if index % 2 == 0 else Color("af926b"))
	_r(dock + Vector2(42, -18), Vector2(4, 7), Color("dbc39a"))
	_r(dock + Vector2(84, 10), Vector2(4, 7), Color("dbc39a"))
	if Archipelago.within_docking_range(state.chart, nav):
		_label("抛锚后，在筏边登岛", dock + Vector2(58, 41), CREAM, 12)

func _draw_island() -> void:
	var origin: Vector2 = _island_origin()
	var bounds := Rect2(canvas_bounds.position + origin, canvas_bounds.size).grow(40)
	_draw_island_ground(bounds)
	if bounds.has_point(IslandMap.DOCK):
		for index in 11:
			_r(Vector2(133 + index * 10, 354), Vector2(9, 48), Color("b79c70") if index % 2 == 0 else Color("c5aa7c"))
		for at in [Vector2(133, 350), Vector2(133, 398), Vector2(226, 350), Vector2(226, 398)]:
			_r(at, Vector2(5, 9), Color("dfc791"))
		_sprite("floor", Vector2(114, 380), Vector2(47, 47))
		_sprite("anchor", Vector2(114, 377), Vector2(25, 25))
		_sprite("bedroll", Vector2(305, 385), Vector2(42, 42))
		_sprite("rod", Vector2(248, 435), Vector2(26, 26))
		if _near(Vector2(305, 385), 55):
			_label("海岸营地", Vector2(305, 414), CREAM, 11)
	var island: Dictionary = state.get("island", {})
	var plots: Dictionary = island.get("plots", {})
	for key: String in plots:
		var at: Vector2 = (_cell(key) + Vector2.ONE * 0.5) * IslandMap.TILE
		if bounds.has_point(at):
			_draw_island_plot(at, plots[key])
	var depleted: Dictionary = island.get("depleted", {})
	var nodes: Dictionary = IslandMap.nodes_near(Vector2(float(_local.x), float(_local.y)))
	for id: String in nodes:
		var resource: Dictionary = nodes[id]
		var at := Vector2(float(resource.x), float(resource.y))
		if not bounds.grow(64).has_point(at):
			continue
		var plot_key := "%d,%d" % [floori(at.x / IslandMap.TILE), floori(at.y / IslandMap.TILE)]
		if plots.has(plot_key):
			continue
		var active: bool = IslandState.active(island, id, int(state.get("day", 1)))
		if not IslandMap.walkable(at):
			continue
		_draw_island_node(resource, at, active)
	_draw_town(bounds)
	if not farm_preview.is_empty():
		var at := Vector2(float(farm_preview.x), float(farm_preview.y))
		var tint := Color("c8dca4") if bool(farm_preview.get("valid", false)) else Color("b68f86")
		draw_rect(Rect2(at - Vector2(15, 15), Vector2(30, 30)), tint, false, 1)
		for corner in [Vector2(-15, -15), Vector2(15, -15), Vector2(-15, 15), Vector2(15, 15)]:
			_r(at + corner - Vector2.ONE, Vector2(3, 3), tint)

func _draw_island_ground(bounds: Rect2) -> void:
	var land := bounds.intersection(Rect2(Vector2.ZERO, IslandMap.SIZE - Vector2(56, 56)))
	if not land.has_area():
		return
	var area: Dictionary = IslandMap.region(_island_origin() + IslandMap.PAGE * 0.5)
	var ground: Color = area.color
	var top := PackedVector2Array()
	var left := PackedVector2Array()
	var first_x: float = maxf(land.position.x, IslandMap._coast_x(maxf(land.position.y, 96)))
	var first_y: float = maxf(land.position.y, IslandMap._coast_y(first_x))
	for x in range(int(first_x), int(land.end.x) + 17, 16):
		var px: float = minf(x, land.end.x)
		top.append(Vector2(px, maxf(land.position.y, IslandMap._coast_y(px))))
	for y in range(int(land.end.y), int(first_y), -16):
		var py: float = y
		left.append(Vector2(maxf(land.position.x, IslandMap._coast_x(py)), py))
	var shape: PackedVector2Array = top.duplicate()
	shape.append(land.end)
	shape.append_array(left)
	draw_colored_polygon(_pixel_coast(shape), ground)
	if land.position.y < 110:
		for index in range(1, top.size()):
			draw_line(top[index - 1] + Vector2(0, 23), top[index] + Vector2(0, 23), Color("c3b887"), 44, false)
		draw_polyline(top, Color("adc6a1"), 4, false)
	if land.position.x < 170:
		for index in range(1, left.size()):
			draw_line(left[index - 1] + Vector2(23, 0), left[index] + Vector2(23, 0), Color("c3b887"), 44, false)
		draw_polyline(left, Color("adc6a1"), 4, false)
	if bounds.end.x > IslandMap.SIZE.x - 100:
		_r(Vector2(IslandMap.SIZE.x - 100, land.position.y), Vector2(44, land.size.y), Color("c3b887"))
	if bounds.end.y > IslandMap.SIZE.y - 100:
		_r(Vector2(land.position.x, IslandMap.SIZE.y - 100), Vector2(land.size.x, 44), Color("c3b887"))
	# Bare stone forms joined patches, with no per-cell borders or checkerboard.
	if str(area.id) in ["foothills", "ruins"]:
		for row in range(floori(land.position.y / 32), ceili(land.end.y / 32)):
			for column in range(floori(land.position.x / 32), ceili(land.end.x / 32)):
				var at := Vector2(column, row) * 32
				if IslandMap.terrain(at + Vector2(16, 16)) == "rock":
					_r(at, Vector2(32, 32), Color("a3a391") if str(area.id) == "foothills" else Color("a29c87"))
	for pond: Dictionary in IslandMap.ponds_near(_island_origin() + IslandMap.PAGE * 0.5):
		var center: Vector2 = pond.center
		var radius: Vector2 = pond.radius
		if not bounds.grow(130).has_point(center):
			continue
		var edge := PackedVector2Array()
		var water := PackedVector2Array()
		for index in 24:
			var angle: float = index * TAU / 24.0
			var unit := Vector2(cos(angle), sin(angle))
			edge.append(center + unit * (radius + Vector2(7, 7)))
			water.append(center + unit * radius)
		draw_colored_polygon(_pixel_coast(edge), Color("b6b68b"))
		draw_colored_polygon(_pixel_coast(water), Color("649d97"))
		for index in 4:
			var drift: float = fposmod(_elapsed * 3 + index * 23, radius.x * 1.2) - radius.x * 0.6
			_r(center + Vector2(drift, -16 + index * 10), Vector2(15, 1), Color(0.74, 0.85, 0.73, 0.40))
		if _near(center, 150):
			_label("淡水", center + Vector2(0, 4), Color("d7e3bd"), 10)
	_draw_island_water(bounds)
	for page_x in range(maxi(0, floori(bounds.position.x / IslandMap.PAGE.x)), mini(16, ceili(bounds.end.x / IslandMap.PAGE.x))):
		var points := PackedVector2Array()
		for y in range(int(bounds.position.y), int(bounds.end.y) + 17, 16):
			points.append(Vector2(IslandMap.vertical_path_x(y, page_x), y))
		_draw_island_path(points)
	for page_y in range(maxi(0, floori(bounds.position.y / IslandMap.PAGE.y)), mini(12, ceili(bounds.end.y / IslandMap.PAGE.y))):
		var points := PackedVector2Array()
		for x in range(int(bounds.position.x), int(bounds.end.x) + 17, 16):
			points.append(Vector2(x, IslandMap.horizontal_path_y(x, page_y)))
		_draw_island_path(points)
	if bounds.has_point(IslandMap.DOCK):
		_draw_island_path(PackedVector2Array([IslandMap.DOCK, Vector2(448, 308)]))
	for points: PackedVector2Array in _town_streets(bounds):
		_draw_island_path(points)
	_draw_island_bridges(bounds)
	for index in 145:
		var at := _island_origin() + Vector2(_noise(index + _island_origin().x) * 940 - 20, _noise(index + _island_origin().y + 321) * 590 - 20)
		if IslandMap.terrain(at) == "grass":
			_r(at, Vector2(3, 2), ground.lightened(0.12))
			if index % 4 == 0:
				_r(at + Vector2(4, -3), Vector2(2, 4), ground.darkened(0.15))

func _draw_island_water(bounds: Rect2) -> void:
	var features: Array = IslandMap.water_features_near(bounds.get_center())
	features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.kind == "lake") < int(b.kind == "lake"))
	for feature: Dictionary in features:
		if feature.kind == "pond":
			continue # Existing small pools already share the map's pond geometry.
		if feature.has("center"):
			var center: Vector2 = feature.center
			var radius: Vector2 = feature.radius
			var polygon := PackedVector2Array()
			for index in 64:
				var angle := index * TAU / 64.0
				polygon.append(center + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(_pixel_coast(polygon), Color("60998d"))
			draw_polyline(_pixel_coast(polygon), Color("afbd92"), 6, false)
		else:
			var points := PackedVector2Array(feature.points)
			draw_polyline(points, Color("a8b68c"), float(feature.width) + 10, false)
			draw_polyline(points, Color("60998d"), float(feature.width), false)
			for index in range(1, points.size()):
				var midpoint: Vector2 = (points[index - 1] + points[index]) * 0.5
				if bounds.has_point(midpoint):
					draw_line(midpoint + Vector2(-14, 0), midpoint + Vector2(14, -3), Color("a4c9ab"), 1, false)
	# Ripples use the terrain definition, so none are drawn on bridges or soil.
	for index in 65:
		var at := bounds.position + Vector2(_noise(index + 911) * bounds.size.x, _noise(index + 631) * bounds.size.y)
		if IslandMap.terrain(at) == "water":
			_r(at + Vector2(sin(_elapsed * 0.6 + index) * 3, 0), Vector2(12 + index % 13, 1), Color(0.76, 0.86, 0.69, 0.34))

func _town_streets(bounds: Rect2) -> Array:
	var result: Array = []
	if not bounds.intersects(IslandMap.TOWN_BOUNDS):
		return result
	result.append(PackedVector2Array([Vector2(1344, 88), Vector2(1344, 1048)]))
	for landmark: Dictionary in IslandMap.LANDMARKS.values():
		if IslandMap.TOWN_BOUNDS.has_point(landmark.door):
			result.append(PackedVector2Array([landmark.door, Vector2(1344, landmark.door.y)]))
	return result

func _draw_island_bridges(bounds: Rect2) -> void:
	var routes: Array = _town_streets(bounds)
	for column in range(maxi(0, floori(bounds.position.x / IslandMap.PAGE.x)), mini(16, ceili(bounds.end.x / IslandMap.PAGE.x))):
		var points := PackedVector2Array()
		for y in range(int(bounds.position.y), int(bounds.end.y) + 9, 8):
			points.append(Vector2(IslandMap.vertical_path_x(y, column), y))
		routes.append(points)
	for row in range(maxi(0, floori(bounds.position.y / IslandMap.PAGE.y)), mini(12, ceili(bounds.end.y / IslandMap.PAGE.y))):
		var points := PackedVector2Array()
		for x in range(int(bounds.position.x), int(bounds.end.x) + 9, 8):
			points.append(Vector2(x, IslandMap.horizontal_path_y(x, row)))
		routes.append(points)
	for points: PackedVector2Array in routes:
		for index in range(1, points.size()):
			var before: Vector2 = points[index - 1]
			var after: Vector2 = points[index]
			var steps := maxi(1, ceili(before.distance_to(after) / 8))
			for step in steps:
				var a := before.lerp(after, float(step) / steps)
				var b := before.lerp(after, float(step + 1) / steps)
				var at := (a + b) * 0.5
				if not bounds.grow(24).has_point(at) or IslandMap.terrain(at) != "bridge":
					continue
				var normal := (b - a).normalized().orthogonal()
				draw_line(a, b, Color("b6a17a"), 34, false)
				draw_line(at - normal * 16, at + normal * 16, Color("93815f"), 1, false)
				draw_line(a + normal * 17, b + normal * 17, Color("d3bd92"), 2, false)
				draw_line(a - normal * 17, b - normal * 17, Color("877150"), 2, false)

func _draw_town(bounds: Rect2) -> void:
	for building: Dictionary in IslandMap.landmarks_near(bounds.get_center()).values():
		var footprint: Rect2 = building.bounds
		if not footprint.grow(55).intersects(bounds):
			continue
		var door: Vector2 = building.door
		if building.kind == "plaza":
			draw_rect(footprint, Color("b5af8c"))
			for x in range(int(footprint.position.x) + 5, int(footprint.end.x), 24):
				for y in range(int(footprint.position.y) + 5, int(footprint.end.y), 18):
					_r(Vector2(x, y), Vector2(21, 15), Color("c1b99a"))
			_sprite("wood", footprint.position + Vector2(18, 10), Vector2(35, 25))
			_label("潮芽镇", footprint.position + Vector2(footprint.size.x * 0.5, -10), Color("ede7c4"), 16)
			continue
		if not building.open:
			_shadow(footprint.get_center(), footprint.size * 0.48, Color("83877b"))
			_shadow(door + Vector2(0, -22), Vector2(24, 28), Color("575f55"))
			for x in [-25, 25]:
				_r(door + Vector2(x, -51), Vector2(7, 51), Color("9b8667"))
			_r(door + Vector2(-27, -51), Vector2(59, 8), Color("b5a27c"))
			for index in 3:
				_r(door + Vector2(-27, -33 + index * 11), Vector2(59, 5), Color("b49a6d"))
			_label(str(building.name), door + Vector2(0, 21), CREAM, 11)
			continue
		var roof: Color = {"market": Color("b97659"), "clinic": Color("72968b"), "bathhouse": Color("7f8e9c"), "carpenter": Color("98846a"), "smith": Color("77838a"), "fishery": Color("63959b"), "farmhouse": Color("a48662")}.get(str(building.id), Color("a67e66"))
		var face := Rect2(footprint.position + Vector2(0, footprint.size.y * 0.32), Vector2(footprint.size.x, footprint.size.y * 0.68))
		_shadow(footprint.get_center() + Vector2(6, footprint.size.y * 0.49), Vector2(footprint.size.x * 0.56, 12), Color(0.20, 0.26, 0.17, 0.16))
		draw_rect(face, Color("cabc95"))
		draw_rect(Rect2(face.position, Vector2(7, face.size.y)), Color("a49273"))
		for y in range(int(face.position.y) + 8, int(face.end.y), 12):
			draw_line(Vector2(face.position.x + 8, y), Vector2(face.end.x - 6, y), Color("b5a984"), 1, false)
		var roof_rect := Rect2(footprint.position - Vector2(6, 7), Vector2(footprint.size.x + 12, footprint.size.y * 0.46))
		draw_rect(roof_rect, roof)
		for row in range(0, int(roof_rect.size.y), 9):
			draw_line(roof_rect.position + Vector2(0, row), roof_rect.position + Vector2(roof_rect.size.x, row), roof.lightened(0.12), 2, false)
			for column in range(5 + (row % 2) * 7, int(roof_rect.size.x), 17):
				_r(roof_rect.position + Vector2(column, row + 2), Vector2(1, 5), roof.darkened(0.1))
		_r(Vector2(roof_rect.position.x, roof_rect.end.y), Vector2(roof_rect.size.x, 4), roof.darkened(0.22))
		var threshold := Vector2(door.x, footprint.end.y)
		_r(threshold + Vector2(-13, -30), Vector2(26, 30), Color("81765e"))
		_r(threshold + Vector2(-10, -28), Vector2(20, 26), Color("a28d68"))
		_r(threshold + Vector2(6, -13), Vector2(2, 3), Color("ddd19d"))
		_r(threshold + Vector2(-18, 0), Vector2(36, 5), Color("cbb78e"))
		for side in [-1, 1]:
			var window := threshold + Vector2(side * footprint.size.x * 0.32 - 10, -29)
			_r(window - Vector2(3, 3), Vector2(26, 24), Color("a18b65"))
			_r(window, Vector2(20, 18), Color("83aca4"))
			_r(window + Vector2(9, 0), Vector2(2, 18), Color("d9cc9f"))
			_r(window + Vector2(0, 8), Vector2(20, 2), Color("d9cc9f"))
			_sprite("plant", window + Vector2(10, 25), Vector2(22, 22))
		if building.id == "market":
			for index in 8:
				_r(threshold + Vector2(-40 + index * 10, -41), Vector2(10, 12), Color("d3bc80") if index % 2 == 0 else Color("8b9a69"))
		elif building.id == "clinic":
			_r(footprint.get_center() + Vector2(-3, -21), Vector2(6, 20), Color("ece1b6"))
			_r(footprint.get_center() + Vector2(-10, -14), Vector2(20, 6), Color("ece1b6"))
		elif building.id == "bathhouse":
			for index in 3:
				var at := footprint.position + Vector2(20 + index * 11 + sin(_elapsed + index) * 3, -4 - fposmod(_elapsed * 5 + index * 9, 25))
				_r(at, Vector2(6, 9), Color(0.9, 0.91, 0.81, 0.38))
		_label(str(building.name), threshold + Vector2(0, -45), Color("f2e7c1"), 11)
	for npc: Dictionary in IslandTown.residents(state).values():
		var at := Vector2(float(npc.x), float(npc.y))
		if not bounds.grow(30).has_point(at):
			continue
		_shadow(at + Vector2(0, 3), Vector2(12, 4), Color(0.22, 0.29, 0.18, 0.24))
		var tints := [Color("e7d4ac"), Color("e5eeeb"), Color("c8dfd2"), Color("dcba9e"), Color("bec7d3"), Color("badad9"), Color("c3dba1"), Color("e8d9b8")]
		draw_texture_rect(CharacterArt.texture(str(npc.sprite_slot), 0, 1), Rect2(at + Vector2(-20, -38), Vector2(40, 40)), false, tints[int(npc.variant) % tints.size()])
		if int(npc.variant) in [0, 3, 6]:
			_r(at + Vector2(-11, -32), Vector2(22, 4), Color("cdb787"))
			_r(at + Vector2(-7, -37), Vector2(14, 6), Color("decc9d"))
		elif int(npc.variant) == 1:
			_r(at + Vector2(-7, -32), Vector2(14, 4), Color("ece8d6"))
		_label(str(npc.name), at + Vector2(0, 16), CREAM, 10)
		if _near(at):
			_label(str(npc.role) + " · 左键交谈 / P 服务", at + Vector2(0, -48), Color("e1dfb0"), 10)

func _draw_island_path(points: PackedVector2Array) -> void:
	for index in range(1, points.size()):
		var before: Vector2 = points[index - 1]
		var after: Vector2 = points[index]
		if IslandMap.walkable(before) and IslandMap.walkable(after):
			draw_line(before.round(), after.round(), Color("b1aa7c"), 35, false)
			draw_line(before.round(), after.round(), Color("bdb58a"), 29, false)

func _draw_island_node(resource: Dictionary, at: Vector2, active: bool) -> void:
	var kind: String = str(resource.kind)
	if not active:
		if kind == "tree":
			_shadow(at + Vector2(0, 3), Vector2(11, 4), Color(0.24, 0.29, 0.19, 0.20))
			_r(at + Vector2(-6, -5), Vector2(12, 9), Color("8b7752"))
			_r(at + Vector2(-5, -6), Vector2(10, 3), Color("b7a178"))
		else:
			_r(at + Vector2(-5, 2), Vector2(3, 2), Color("aaa980"))
		return
	_shadow(at + Vector2(1, 7), Vector2(17, 4), Color(0.24, 0.30, 0.20, 0.17))
	match kind:
		"tree":
			_coastal_tree(at, 0.90 + _noise(at.x + at.y) * 0.17)
		"fiber":
			_sprite("plant", at + Vector2(-6, -8), Vector2(26, 34))
			_sprite("leaf", at + Vector2(8, -3), Vector2(23, 28), Color("b4c28e"))
		"stone", "ore":
			_sprite("rock", at + Vector2(0, -3), Vector2(39, 33), Color("b8c2af"))
			if kind == "ore":
				_item("ore", at + Vector2(3, -7), 22)
		"dig_seed", "dig_treasure":
			_r(at + Vector2(-9, 1), Vector2(18, 6), Color("92815e"))
			for index in 3:
				draw_line(at + Vector2(-7 + index * 6, 1), at + Vector2(-5 + index * 6, -5 - index % 2 * 3), Color("c4b895"), 2, false)
			if kind == "dig_seed":
				_sprite("leaf", at + Vector2(0, -4), Vector2(14, 13), Color("b2bf8a"))
		"branch":
			_sprite("wood", at, Vector2(34, 28))
	if str(resource.id) == hovered_id or "island:" + str(resource.id) == hovered_id:
		draw_arc(at + Vector2(0, 5), 21, 0.12, PI - 0.12, 12, Color(0.90, 0.85, 0.62, 0.7), 1, false)

func _draw_island_plot(at: Vector2, plot: Dictionary) -> void:
	var watered: bool = bool(plot.get("watered", false))
	_r(at - Vector2(16, 16), Vector2(32, 32), Color("77644b") if watered else Color("9e855f"))
	for row in 3:
		_r(at + Vector2(-13, -11 + row * 9), Vector2(26, 2), Color("625842") if watered else Color("b59b72"))
	var crop: String = str(plot.get("crop", ""))
	if not crop.is_empty() and Farming.CROPS.has(crop):
		var config: Dictionary = Farming.CROPS[crop]
		var growth: int = int(plot.get("growth", 0))
		var mature: bool = growth >= int(config.days)
		var tint: Color = {"seed": Color("b0c68b"), "summer_seed": Color("dbb791"), "autumn_seed": Color("d5c080"), "winter_seed": Color("afc9c7")}.get(crop, Color.WHITE)
		if bool(plot.get("dead", false)):
			_sprite("leaf", at + Vector2(0, -3), Vector2(20, 17), Color("8d7960"))
			draw_line(at + Vector2(-4, 1), at + Vector2(5, 7), Color("6d604a"), 2, false)
		elif mature:
			_sprite("garden_growing", at + Vector2(0, -6), Vector2(27, 27), tint)
			match crop:
				"summer_seed":
					_r(at + Vector2(-3, -13), Vector2(7, 17), Color("dfc375"))
					for row in 4:
						_r(at + Vector2(-2, -11 + row * 4), Vector2(5, 1), Color("b8a05e"))
				"autumn_seed":
					_shadow(at + Vector2(1, -3), Vector2(10, 8), Color("c69b65"))
					_r(at + Vector2(0, -12), Vector2(3, 5), Color("73845d"))
					draw_line(at + Vector2(1, -9), at + Vector2(1, 3), Color("a87e4f"), 1, false)
				_:
					_sprite("veg", at + Vector2(3, -6), Vector2(20, 20), tint)
		else:
			var extent: float = 10 + 12 * float(growth) / maxf(1, int(config.days) - 1)
			_sprite("leaf", at + Vector2(0, -2), Vector2(extent, extent), tint)
			if growth > 0:
				_r(at + Vector2(-1, 4), Vector2(2, 5), Color("91a475"))
	if watered:
		_r(at + Vector2(11, 9), Vector2(2, 4), Color("9ec4c0"))
	if bool(plot.get("covered", false)):
		var arch := PackedVector2Array([at + Vector2(-16, 14), at + Vector2(-16, -8), at + Vector2(-10, -19), at + Vector2(10, -19), at + Vector2(16, -8), at + Vector2(16, 14)])
		draw_colored_polygon(arch, Color(0.74, 0.86, 0.81, 0.19))
		draw_polyline(arch, Color(0.79, 0.85, 0.75, 0.75), 1, false)
		draw_line(at + Vector2(0, -19), at + Vector2(0, 14), Color(0.76, 0.82, 0.72, 0.50), 1, false)


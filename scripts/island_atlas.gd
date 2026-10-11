extends Control
## Local island notebook. Buttons change the view, never player/world state.
signal closed
signal sea_requested

const UI = preload("res://scripts/ui_style.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const IslandState = preload("res://scripts/island_state.gd")
const NODE_NAMES := {"tree": "树木", "branch": "枯枝", "fiber": "纤维", "stone": "石料", "ore": "矿石", "dig_seed": "野生种子", "dig_treasure": "埋藏物"}
const NODE_COLORS := {"tree": Color("456b4c"), "branch": Color("896b4a"), "fiber": Color("b4c47e"), "stone": Color("d4d1bb"), "ore": Color("668883"), "dig_seed": Color("d6bd7c"), "dig_treasure": Color("b28369")}

var close_button: Button
var sea_button: Button
var back_button: Button
var region_buttons: Dictionary = {}
var page_buttons: Dictionary = {}
var selected_region: String = ""
var selected_page := Vector2i.ZERO
var map_canvas: Control
var title_label: Label
var position_label: Label
var detail_label: Label
var resources_label: Label
var _shade: ColorRect
var _subtitle: Label
var _page_title: Label
var _water_label: Label
var _heading: Label
var _data: Dictionary = {}
var _slot: String = "host"


func _ready() -> void:
	size = Vector2(1280, 800)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shade = ColorRect.new()
	_shade.size = size
	_shade.color = UI.SHADE
	add_child(_shade)
	UI.panel(self, Rect2(72, 64, 1136, 672), "paper")
	_heading = UI.label(self, "潮芽岛 · 岛内地图", Rect2(108, 88, 810, 43), 30)
	_subtitle = UI.label(self, "六片地貌，一条条走出来的小径。", Rect2(110, 136, 900, 27), 16, UI.MUTED)
	close_button = UI.button(self, "×", Rect2(1138, 88, 38, 38), func() -> void: closed.emit())
	close_button.tooltip_text = "合上地图 · M / Esc"
	map_canvas = Control.new()
	map_canvas.position = Vector2(108, 184)
	map_canvas.size = Vector2(740, 486)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	map_canvas.draw.connect(_draw_map)
	add_child(map_canvas)
	for entry: Dictionary in IslandMap.REGIONS:
		var id: String = str(entry.id)
		var button: Button = UI.button(map_canvas, str(entry.name), Rect2(), func() -> void: _select_region(id))
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_color", Color("304c3b"))
		button.add_theme_color_override("font_hover_color", Color("243f31"))
		for appearance: String in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(appearance, UI.box("quick_hover" if appearance == "hover" else "clear"))
		button.tooltip_text = str(entry.description)
		region_buttons[id] = button
	UI.label(self, "岛上札记", Rect2(884, 184, 280, 26), 15, UI.MUTED)
	title_label = UI.label(self, "潮芽岛", Rect2(882, 225, 288, 43), 28)
	detail_label = UI.label(self, "", Rect2(884, 280, 286, 94), 17)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_title = UI.label(self, "", Rect2(884, 389, 286, 28), 20)
	_water_label = UI.label(self, "", Rect2(884, 425, 286, 46), 15, UI.ACCENT)
	_water_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resources_label = UI.label(self, "", Rect2(884, 478, 286, 110), 16, UI.MUTED)
	resources_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	back_button = UI.button(self, "六区总览", Rect2(884, 609, 132, 42), _show_overview)
	sea_button = UI.button(self, "返回海图", Rect2(1030, 609, 140, 42), func() -> void: sea_requested.emit())
	position_label = UI.label(self, "", Rect2(110, 686, 760, 26), 15, UI.MUTED)
	UI.label(self, "地图只作查看，不会传送。", Rect2(884, 686, 286, 25), 14, UI.MUTED)
	hide()


func present(data: Dictionary, slot: String) -> void:
	selected_region = ""
	var player: Dictionary = data.get("players", {}).get(slot, {})
	selected_page = Vector2i(IslandMap.page_origin(Vector2(float(player.get("x", 210)), float(player.get("y", 380)))) / IslandMap.PAGE)
	refresh(data, slot)
	show()


func refresh(data: Dictionary, slot: String) -> void:
	_data = data
	_slot = slot
	if not is_instance_valid(map_canvas):
		return
	var player: Dictionary = data.get("players", {}).get(slot, {})
	var at := Vector2(float(player.get("x", 210)), float(player.get("y", 380)))
	var page := Vector2i(IslandMap.page_origin(at) / IslandMap.PAGE)
	position_label.text = "你在 %s · 第 %d 列 / %d 行  |  绿点：你  蓝点：伙伴  浅蓝：淡水" % [IslandMap.region(at).name, page.x + 1, page.y + 1]
	back_button.disabled = selected_region.is_empty()
	for id: String in region_buttons:
		var button: Button = region_buttons[id]
		button.visible = selected_region.is_empty()
		var entry: Dictionary = _region_by_id(id)
		button.position = _project_rect(entry.bounds).position
		button.size = _project_rect(entry.bounds).size
	for key: String in page_buttons:
		var button: Button = page_buttons[key]
		button.visible = not selected_region.is_empty()
		button.add_theme_stylebox_override("normal", UI.box("quick_selected" if key == _page_key(selected_page) else "clear"))
	_refresh_details()
	map_canvas.queue_redraw()


func _select_region(id: String) -> void:
	var entry: Dictionary = _region_by_id(id)
	if entry.is_empty():
		return
	selected_region = id
	var bounds: Rect2 = entry.bounds
	var player: Dictionary = _data.get("players", {}).get(_slot, {})
	var at := Vector2(float(player.get("x", 210)), float(player.get("y", 380)))
	selected_page = Vector2i(IslandMap.page_origin(at if bounds.has_point(at) else bounds.position + IslandMap.PAGE * 0.5) / IslandMap.PAGE)
	for old: Button in page_buttons.values():
		old.get_parent().remove_child(old)
		old.queue_free()
	page_buttons.clear()
	var first := Vector2i(bounds.position / IslandMap.PAGE)
	var end := Vector2i(bounds.end / IslandMap.PAGE)
	for row in range(first.y, end.y):
		for column in range(first.x, end.x):
			var page := Vector2i(column, row)
			var rect: Rect2 = _project_rect(Rect2(Vector2(page) * IslandMap.PAGE, IslandMap.PAGE))
			var button: Button = UI.button(map_canvas, "", rect, func() -> void: _select_page(page))
			for appearance: String in ["normal", "hover", "pressed"]:
				button.add_theme_stylebox_override(appearance, UI.box("quick_hover" if appearance == "hover" else "clear"))
			button.tooltip_text = "查看第 %d 列 / %d 行；不会移动角色" % [column + 1, row + 1]
			page_buttons[_page_key(page)] = button
	refresh(_data, _slot)


func _select_page(page: Vector2i) -> void:
	selected_page = page
	refresh(_data, _slot)


func _show_overview() -> void:
	selected_region = ""
	refresh(_data, _slot)


func _region_by_id(id: String) -> Dictionary:
	for entry: Dictionary in IslandMap.REGIONS:
		if str(entry.id) == id:
			return entry
	return {}


func _view_bounds() -> Rect2:
	var entry: Dictionary = _region_by_id(selected_region)
	return entry.bounds if not entry.is_empty() else Rect2(Vector2.ZERO, IslandMap.SIZE)


func _scale() -> float:
	var bounds: Rect2 = _view_bounds()
	return minf((map_canvas.size.x - 28) / bounds.size.x, (map_canvas.size.y - 28) / bounds.size.y)


func _project(point: Vector2) -> Vector2:
	var bounds: Rect2 = _view_bounds()
	return (map_canvas.size - bounds.size * _scale()) * 0.5 + (point - bounds.position) * _scale()


func _project_rect(rect: Rect2) -> Rect2:
	return Rect2(_project(rect.position), rect.size * _scale())


func _page_key(page: Vector2i) -> String:
	return "%d,%d" % [page.x, page.y]


func _active_node(id: String, node: Dictionary) -> bool:
	return not node.is_empty() and IslandState.active(_data.island, id, int(_data.day))


func _refresh_details() -> void:
	if selected_region.is_empty():
		_heading.text = "潮芽岛 · 岛内地图"
		_subtitle.text = "选择一片区域，查看小径、淡水与物资分布。"
		title_label.text = "六片地貌"
		detail_label.text = "近港小镇有超市、诊所与澡堂。沿路可去森林、湖河、山麓和荒地。"
		_page_title.text = "16 列 × 12 行"
		_water_label.text = "码头与营地在西北角。"
		resources_label.text = "未开垦土地不赠送农田：清理树枝、草和石头，再用锄头开地。矿洞入口尚未开放。"
		return
	var entry: Dictionary = _region_by_id(selected_region)
	_heading.text = "潮芽岛 · " + str(entry.name)
	_subtitle.text = "点选一页查看记录；镜头只在你走过边界时换页。"
	title_label.text = str(entry.name)
	detail_label.text = str(entry.description)
	_page_title.text = "第 %d 列 / %d 行" % [selected_page.x + 1, selected_page.y + 1]
	var page_rect := Rect2(Vector2(selected_page) * IslandMap.PAGE, IslandMap.PAGE)
	var fresh_water := false
	for feature: Dictionary in IslandMap.water_features_near(page_rect.get_center()):
		if page_rect.intersects(feature.bounds):
			fresh_water = true
	_water_label.text = "淡水岸边 · 可补满水壶和钓鱼" if fresh_water else "这页没有淡水；可查看邻页。"
	if selected_page == Vector2i.ZERO:
		_water_label.text = "码头 / 海岸营地 / 淡水池"
	var counts: Dictionary = {}
	var waiting: int = 0
	for id: String in IslandMap.nodes_near(page_rect.get_center()):
		var node: Dictionary = IslandMap.node(id)
		if not page_rect.has_point(Vector2(float(node.x), float(node.y))):
			continue
		if _active_node(id, node):
			counts[node.kind] = int(counts.get(node.kind, 0)) + 1
		else:
			waiting += 1
	var lines := PackedStringArray()
	for kind: String in counts:
		lines.append("%s %d处" % [NODE_NAMES[kind], counts[kind]])
	resources_label.text = "  ·  ".join(lines) if not lines.is_empty() else "这一页暂时没有可采集节点。"
	if waiting > 0:
		resources_label.text += "\n已采集 / 已开垦 %d处" % waiting
	var places := PackedStringArray()
	for landmark: Dictionary in IslandMap.landmarks_near(page_rect.get_center()).values():
		if page_rect.has_point(landmark.door):
			places.append(str(landmark.name))
	for feature: Dictionary in IslandMap.water_features_near(page_rect.get_center()):
		if feature.kind != "pond" and page_rect.intersects(feature.bounds):
			places.append(str(feature.name))
	if not places.is_empty():
		detail_label.text = "这一页：" + "、".join(places)


func _draw_map() -> void:
	map_canvas.draw_rect(Rect2(Vector2.ZERO, map_canvas.size), Color("acc0ad"))
	var bounds: Rect2 = _view_bounds()
	for entry: Dictionary in IslandMap.REGIONS:
		var rect: Rect2 = entry.bounds
		if not rect.intersects(bounds):
			continue
		var drawn: Rect2 = _project_rect(rect.intersection(bounds))
		map_canvas.draw_rect(drawn, entry.color)
		map_canvas.draw_rect(drawn, Color(0.29, 0.39, 0.29, 0.28), false, 1)
	if selected_region.is_empty():
		for column in range(1, IslandMap.PAGES.x):
			map_canvas.draw_line(_project(Vector2(column * IslandMap.PAGE.x, 0)), _project(Vector2(column * IslandMap.PAGE.x, IslandMap.SIZE.y)), Color(0.92, 0.93, 0.81, 0.09), 1, false)
		for row in range(1, IslandMap.PAGES.y):
			map_canvas.draw_line(_project(Vector2(0, row * IslandMap.PAGE.y)), _project(Vector2(IslandMap.SIZE.x, row * IslandMap.PAGE.y)), Color(0.92, 0.93, 0.81, 0.09), 1, false)
	else:
		_draw_region_pages(bounds)
	_draw_landmarks(bounds)
	var dock: Vector2 = _project(IslandMap.DOCK)
	if bounds.has_point(IslandMap.DOCK):
		map_canvas.draw_rect(Rect2(dock - Vector2(4, 3), Vector2(8, 6)), Color("c7ad79"))
		map_canvas.draw_line(dock + Vector2(-7, 0), dock + Vector2(7, 0), Color("665442"), 2, false)
	for slot: String in _data.get("players", {}):
		var player: Dictionary = _data.players[slot]
		if not player.get("online", false) or player.get("area", "deck") != "island":
			continue
		var at := Vector2(float(player.x), float(player.y))
		if not bounds.has_point(at):
			continue
		var screen: Vector2 = _project(at)
		map_canvas.draw_circle(screen, 6, Color("efe7c2"))
		map_canvas.draw_circle(screen, 3.5, Color("365d46") if slot == _slot else Color("4b7893"))
		if slot == _slot:
			var page_rect := Rect2(IslandMap.page_origin(at), IslandMap.PAGE)
			map_canvas.draw_rect(_project_rect(page_rect), Color("f0e6bb"), false, 2)


func _draw_region_pages(bounds: Rect2) -> void:
	var first := Vector2i(bounds.position / IslandMap.PAGE)
	var end := Vector2i(bounds.end / IslandMap.PAGE)
	for row in range(first.y, end.y):
		for column in range(first.x, end.x):
			var page_rect := Rect2(Vector2(column, row) * IslandMap.PAGE, IslandMap.PAGE)
			var drawn: Rect2 = _project_rect(page_rect)
			map_canvas.draw_rect(drawn, Color(0.37, 0.43, 0.31, 0.3), false, 1)
			map_canvas.draw_line(_project(page_rect.position + Vector2(0, 272)), _project(page_rect.position + Vector2(896, 272)), Color(0.88, 0.84, 0.65, 0.65), 1, false)
			map_canvas.draw_line(_project(page_rect.position + Vector2(448, 0)), _project(page_rect.position + Vector2(448, 544)), Color(0.88, 0.84, 0.65, 0.65), 1, false)
			map_canvas.draw_string(get_theme_default_font(), drawn.position + Vector2(4, 13), "%d,%d" % [column + 1, row + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("415b43"))
			for pond: Dictionary in IslandMap.ponds_near(page_rect.get_center()):
				if page_rect.has_point(pond.center):
					var extent: Vector2 = Vector2(pond.radius) * _scale()
					map_canvas.draw_style_box(_pond_style(), Rect2(_project(pond.center) - extent, extent * 2))
			for id: String in IslandMap.nodes_near(page_rect.get_center()):
				var node: Dictionary = IslandMap.node(id)
				var at := Vector2(float(node.x), float(node.y))
				if page_rect.has_point(at) and _active_node(id, node):
					map_canvas.draw_rect(Rect2(_project(at) - Vector2(2, 2), Vector2(4, 4)), NODE_COLORS[node.kind])


func _draw_landmarks(bounds: Rect2) -> void:
	for feature: Dictionary in IslandMap.WATER_FEATURES.values():
		if not bounds.intersects(feature.bounds):
			continue
		if feature.kind == "lake":
			var polygon := PackedVector2Array()
			for index in 48:
				var angle := index * TAU / 48.0
				polygon.append(Vector2(feature.center) + Vector2(cos(angle), sin(angle)) * Vector2(feature.radius))
			var clip := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
			for part: PackedVector2Array in Geometry2D.intersect_polygons(polygon, clip):
				var projected := PackedVector2Array()
				for at: Vector2 in part:
					projected.append(_project(at))
				map_canvas.draw_colored_polygon(projected, Color("76a99b"))
		else:
			var points: Array = feature.points
			for index in range(1, points.size()):
				var before: Vector2 = points[index - 1]
				var after: Vector2 = points[index]
				var samples := ceili(before.distance_to(after) / 32)
				for step in samples:
					var a := before.lerp(after, float(step) / samples)
					var b := before.lerp(after, float(step + 1) / samples)
					if bounds.has_point(a) and bounds.has_point(b):
						map_canvas.draw_line(_project(a), _project(b), Color("76a99b"), maxf(2, float(feature.width) * _scale()), false)
	for landmark: Dictionary in IslandMap.LANDMARKS.values():
		var at: Vector2 = landmark.door
		if not bounds.has_point(at):
			continue
		var position: Vector2 = _project(at)
		map_canvas.draw_rect(Rect2(position - Vector2(3, 3), Vector2(6, 6)), Color("ba855a") if landmark.open else Color("747868"))
		# Name the town once at island/region scale; page details list each building.
		if landmark.id in ["plaza", "mine_entrance"]:
			map_canvas.draw_string(get_theme_default_font(), position + Vector2(7, 3), "潮芽镇" if landmark.id == "plaza" else "矿洞（未开放）", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("3f5544"))

func _pond_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("88b6b0")
	style.set_corner_radius_all(7)
	style.anti_aliasing = false
	return style

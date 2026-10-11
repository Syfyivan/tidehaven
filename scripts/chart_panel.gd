extends Control
## Read-only chart view. Selecting a destination emits an intent, never a move.

signal close_requested
signal destination_selected(id: String)

const UI = preload("res://scripts/ui_style.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
const Inventory = preload("res://scripts/inventory.gd")
const LOCAL_RADIUS := 400.0
const SEA := Color("9fbfba")
const SEA_LINE := Color("78a39e")
const SHORE := Color("ddd3a9")
const LAND := Color("879968")
const DARK_LAND := Color("61795b")
const ROUTE := Color("a0744f")

var close_button: Button
var destination_button: Button
var island_buttons: Dictionary = {}
var selected_island := Archipelago.HOME_ID
var full_chart := false
var map_canvas: Control
var title_label: Label
var status_label: Label
var description_label: Label
var distance_label: Label
var travel_label: Label
var guidance_label: Label
var position_label: Label
var raft_label: Label
var feedback_label: Label
var _data: Dictionary = {}
var _slot := "host"
var _island_labels: Dictionary = {}
var _island_states: Dictionary = {}
var _feedback := ""
var _heading: Label
var _subtitle: Label
var _north_label: Label


func _ready() -> void:
	size = Vector2(1280, 800)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shade := ColorRect.new()
	shade.size = size
	shade.color = UI.SHADE
	add_child(shade)
	UI.panel(self, Rect2(72, 64, 1136, 672), "paper")
	_heading = UI.label(self, "附近海域", Rect2(108, 88, 480, 43), 30)
	_subtitle = UI.label(self, "随身携带罗盘，才能查看完整海图。", Rect2(110, 136, 900, 27), 16, UI.MUTED)
	close_button = UI.button(self, "×", Rect2(1138, 88, 38, 38), func(): close_requested.emit())
	close_button.tooltip_text = "合上海图 · M / Esc"
	map_canvas = Control.new()
	map_canvas.position = Vector2(108, 184)
	map_canvas.size = Vector2(740, 486)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	map_canvas.draw.connect(_draw_map)
	add_child(map_canvas)
	_north_label = UI.label(map_canvas, "北", Rect2(39, 13, 24, 20), 12, Color("557c71"))
	_north_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_north_label.hide()
	for id in Archipelago.ISLANDS:
		var island_id := str(id)
		var entry: Dictionary = Archipelago.ISLANDS[id]
		var button := UI.button(map_canvas, "", Rect2(0, 0, 136, 112), func(): _select_island(island_id))
		for appearance in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(appearance, UI.box("clear"))
		button.hide()
		island_buttons[id] = button
		var name_label := UI.label(button, "", Rect2(0, 73, 136, 24), 17, UI.INK if bool(entry.unlocked) else Color("516e6b"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_island_labels[id] = name_label
		var state_label := UI.label(button, "", Rect2(0, 97, 136, 19), 12, Color("486c67"))
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_island_states[id] = state_label
	raft_label = UI.label(map_canvas, "我的木筏", Rect2(0, 0, 130, 24), 14, Color("364f4b"))
	raft_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position_label = UI.label(self, "", Rect2(110, 686, 730, 25), 14, UI.MUTED)
	UI.label(self, "航行札记", Rect2(884, 184, 286, 27), 15, UI.MUTED)
	title_label = UI.label(self, "身边的海", Rect2(882, 227, 290, 42), 29)
	status_label = UI.label(self, "", Rect2(884, 278, 286, 26), 15, UI.ACCENT)
	description_label = UI.label(self, "", Rect2(884, 326, 286, 106), 18)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	distance_label = UI.label(self, "", Rect2(884, 450, 286, 31), 22)
	travel_label = UI.label(self, "", Rect2(884, 491, 286, 29), 15, UI.MUTED)
	guidance_label = UI.label(self, "", Rect2(884, 540, 286, 75), 15, UI.MUTED)
	guidance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	destination_button = UI.button(self, "携带罗盘后设置航标", Rect2(884, 630, 286, 43), _choose_destination, true)
	destination_button.disabled = true
	feedback_label = UI.label(self, "观察海图不会移动木筏。", Rect2(884, 688, 286, 24), 13, UI.MUTED)
	feedback_label.clip_text = true
	hide()


func refresh(data: Dictionary, slot: String) -> void:
	_data = data
	_slot = slot
	var previous_full: bool = full_chart
	full_chart = _has_compass(data, slot)
	if not is_instance_valid(map_canvas) or not data.has("chart") or not data.has("navigation"):
		return
	var chart: Dictionary = data.chart
	if previous_full != full_chart:
		_feedback = ""
	if not _island_visible(selected_island):
		selected_island = Archipelago.HOME_ID if _island_visible(Archipelago.HOME_ID) else ""
		_feedback = ""
	_heading.text = "群岛海图" if full_chart else "附近海域"
	_subtitle.text = "循着海流，找到第一处岸。" if full_chart else "只记录木筏附近可见的海域 · 随身携带罗盘解锁完整海图"
	_north_label.visible = full_chart
	for id in island_buttons:
		var button: Button = island_buttons[id]
		button.visible = _island_visible(str(id))
		button.disabled = not button.visible
		# Clear hidden labels and hover text as well as hiding the controls.
		if not button.visible:
			button.tooltip_text = ""
			_island_labels[id].text = ""
			_island_states[id].text = ""
			continue
		var at := _island_map_center(str(id))
		button.position = (at - Vector2(68, 50)).round()
		var entry: Dictionary = Archipelago.ISLANDS[id]
		_island_labels[id].text = str(entry.name)
		button.tooltip_text = str(entry.name) + (" · 可设为航标" if full_chart and bool(entry.unlocked) else (" · 附近可见岛岸" if not full_chart else " · 后续海域，尚未开放"))
		_island_states[id].text = (("已登岛" if bool(chart.visited) else "可到达") if bool(entry.unlocked) else "尚未开放") if full_chart else "附近可见"
		_island_labels[id].add_theme_color_override("font_color", UI.INK if selected_island == id else Color("486962"))
	var raft := _raft_position()
	var drawn_raft := _clamped_map_point(raft)
	raft_label.position = Vector2(clampf(drawn_raft.x - 65, 6, map_canvas.size.x - 136), clampf(drawn_raft.y + 17, 6, map_canvas.size.y - 28))
	raft_label.text = "木筏在图外" if full_chart and not Archipelago.map_rect(chart).has_point(raft) else "我的木筏"
	var navigation: Dictionary = data.navigation
	position_label.text = "木筏已停泊" if bool(navigation.anchored) else "木筏正在随流漂行 · 3 选桨可调整方向"
	if data.has("players") and data.players.has(slot):
		var area := str(data.players[slot].get("area", "deck"))
		if area == "water":
			position_label.text = "你在水下 · 回到木筏后再操船"
		elif area == "island":
			position_label.text = "你在岛上 · 木筏留在停泊处"
	_refresh_details()
	map_canvas.queue_redraw()


func _select_island(id: String) -> void:
	if not _island_visible(id):
		return
	selected_island = id
	_feedback = ""
	if not _data.is_empty():
		refresh(_data, _slot)


func _choose_destination() -> void:
	if not full_chart or not _has_compass(_data, _slot) or selected_island != Archipelago.HOME_ID:
		return
	destination_selected.emit(selected_island)
	_feedback = "已请求设置航标 · 需要亲自航行"
	_refresh_details()


func _refresh_details() -> void:
	if _data.is_empty() or not _data.has("chart"):
		return
	if not full_chart:
		var nearby: bool = _island_visible(selected_island)
		title_label.text = str(Archipelago.ISLANDS[selected_island].name) if nearby else "身边的海"
		status_label.text = "附近可见的岛岸" if nearby else "尚未看见岛岸"
		status_label.add_theme_color_override("font_color", UI.ACCENT if nearby else UI.MUTED)
		description_label.text = "前方的岛岸已经能看见了。可以亲自划近，在岸边停稳木筏后登岛。" if nearby else "随海流前行，也可以用船桨探索周围。接近岛岸时，这里会出现它的轮廓。"
		distance_label.text = ""
		travel_label.text = "随身罗盘可辨认更远的海域"
		guidance_label.text = "C 打开制作手册，在「探索与升级」手工制作罗盘。\n材料可从海面打捞获得。"
		destination_button.disabled = true
		destination_button.text = "携带罗盘后设置航标"
		feedback_label.text = "无需罗盘也能靠近可见岛岸。"
		feedback_label.tooltip_text = feedback_label.text
		return
	if not Archipelago.ISLANDS.has(selected_island):
		return
	var entry: Dictionary = Archipelago.ISLANDS[selected_island]
	var accessible := bool(entry.unlocked)
	var chart: Dictionary = _data.chart
	title_label.text = str(entry.name)
	description_label.text = str(entry.description)
	status_label.text = ("已探索 · 可再次靠岸" if bool(chart.visited) else "首个可到达岛屿") if accessible else "后续海域 · 尚未开放"
	status_label.add_theme_color_override("font_color", UI.ACCENT if accessible else UI.MUTED)
	var distance := _raft_position().distance_to(Archipelago.island_position(chart, selected_island))
	# Match the HUD's 16 navigation units per displayed metre.
	distance_label.text = "距木筏约 %d 米" % ceili(distance / 16.0) if accessible else "岛屿轮廓"
	travel_label.text = "已进入靠岸范围" if accessible and distance <= Archipelago.DOCK_RADIUS else ("沿虚线方向航行" if accessible else "目前不能靠岸或设置航标")
	if accessible:
		guidance_label.text = "靠近后停稳木筏，再从筏边登岛。\n海图只作导航，不会自动开船。"
	else:
		guidance_label.text = "这里只标出未来海域的位置。\n可游玩的目的地仍是潮芽岛。"
	destination_button.disabled = not accessible
	destination_button.text = "设为航标" if accessible else "尚未开放"
	feedback_label.text = _feedback if not _feedback.is_empty() else ("当前航标 · " + str(Archipelago.ISLANDS[chart.destination].name) if Archipelago.ISLANDS.has(chart.destination) else "观察海图不会移动木筏。")
	feedback_label.tooltip_text = feedback_label.text


func _has_compass(data: Dictionary, slot: String) -> bool:
	var players: Dictionary = data.get("players", {})
	if not players.has(slot):
		return false
	var bag: Variant = players[slot].get("bag", [])
	return bag is Array and Inventory.count(bag, "compass") > 0


func _island_visible(id: String) -> bool:
	if not Archipelago.ISLANDS.has(id) or not _data.has("chart") or not _data.has("navigation"):
		return false
	if full_chart:
		return true
	return bool(Archipelago.ISLANDS[id].unlocked) and _raft_position().distance_to(Archipelago.island_position(_data.chart, id)) <= LOCAL_RADIUS


func _map_scale() -> float:
	if not full_chart:
		return minf(map_canvas.size.x - 144, map_canvas.size.y - 144) / (LOCAL_RADIUS * 2.0)
	return minf((map_canvas.size.x - 32) / Archipelago.MAP_SIZE.x, (map_canvas.size.y - 32) / Archipelago.MAP_SIZE.y)


func _map_area() -> Rect2:
	var extent: Vector2 = (Archipelago.MAP_SIZE if full_chart else Vector2.ONE * LOCAL_RADIUS * 2.0) * _map_scale()
	return Rect2((map_canvas.size - extent) * 0.5, extent)


func _map_point(point: Vector2) -> Vector2:
	var origin: Vector2 = Archipelago.map_rect(_data.chart).position if full_chart else _raft_position() - Vector2.ONE * LOCAL_RADIUS
	return _map_area().position + (point - origin) * _map_scale()


func _island_map_center(id: String) -> Vector2:
	var point := Archipelago.island_position(_data.chart, id)
	if full_chart and id == Archipelago.HOME_ID:
		point += Archipelago.ISLAND_BODY_OFFSET
	return _map_point(point)


func _clamped_map_point(point: Vector2) -> Vector2:
	var result := _map_point(point)
	var area := _map_area().grow(-12)
	return Vector2(clampf(result.x, area.position.x, area.end.x), clampf(result.y, area.position.y, area.end.y))


func _raft_position() -> Vector2:
	return Vector2(float(_data.navigation.x), float(_data.navigation.y))


func _draw_map() -> void:
	var entire := Rect2(Vector2.ZERO, map_canvas.size)
	map_canvas.draw_rect(entire, SEA)
	map_canvas.draw_rect(entire, Color("658c85"), false, 2)
	for row in range(1, 8):
		var y := float(row) * map_canvas.size.y / 8
		map_canvas.draw_line(Vector2(1, y), Vector2(map_canvas.size.x - 1, y), Color(0.34, 0.52, 0.48, 0.14), 1)
	for column in range(1, 11):
		var x := float(column) * map_canvas.size.x / 11
		map_canvas.draw_line(Vector2(x, 1), Vector2(x, map_canvas.size.y - 1), Color(0.34, 0.52, 0.48, 0.14), 1)
	for index in 24:
		var wave := Vector2(24 + (index * 137) % 690, 24 + (index * 79) % 440)
		map_canvas.draw_polyline(PackedVector2Array([wave, wave + Vector2(7, 2), wave + Vector2(15, 0), wave + Vector2(23, 2)]), Color(0.35, 0.54, 0.50, 0.30), 1, false)
	if full_chart:
		_draw_compass(Vector2(51, 65))
	else:
		map_canvas.draw_arc(map_canvas.size * 0.5, LOCAL_RADIUS * _map_scale(), 0, TAU, 64, Color(0.35, 0.54, 0.50, 0.30), 1, false)
	if _data.is_empty() or not _data.has("chart"):
		return
	var chart: Dictionary = _data.chart
	var start := _clamped_map_point(_raft_position())
	if full_chart and str(chart.get("destination", "")) == Archipelago.HOME_ID:
		var target := _map_point(Archipelago.island_position(chart))
		_draw_route(start, target)
	for id in Archipelago.ISLANDS:
		if not _island_visible(str(id)):
			continue
		var entry: Dictionary = Archipelago.ISLANDS[id]
		var center := _island_map_center(str(id))
		var unlocked := bool(entry.unlocked)
		if unlocked and full_chart:
			var dock := _map_point(Archipelago.island_position(chart, str(id)))
			map_canvas.draw_arc(dock, Archipelago.DOCK_RADIUS * _map_scale(), 0, TAU, 32, Color(0.30, 0.47, 0.39, 0.44), 1, false)
			map_canvas.draw_line(dock, center + Vector2(-32, 15), Color("947858"), 4)
			map_canvas.draw_rect(Rect2(dock - Vector2(4, 4), Vector2(8, 8)), Color("e7ddb1"))
		if str(id) == selected_island:
			map_canvas.draw_arc(center, 48, 0, TAU, 32, Color("eaf0d1") if unlocked else Color("bdd1c5"), 2, false)
		_draw_island(center, str(id), unlocked)
		if full_chart and unlocked and str(chart.destination) == id:
			_draw_flag(center + Vector2(17, -13))
	_draw_raft(start)
	if full_chart and not Archipelago.map_rect(chart).has_point(_raft_position()):
		var direction := (_map_point(_raft_position()) - start).normalized()
		map_canvas.draw_line(start + direction * 16, start + direction * 25, Color("744f38"), 3)
		var tip := start + direction * 27
		map_canvas.draw_colored_polygon(PackedVector2Array([tip, tip - direction.rotated(0.6) * 8, tip - direction.rotated(-0.6) * 8]), Color("744f38"))


func _draw_route(start: Vector2, target: Vector2) -> void:
	var difference := target - start
	var length := difference.length()
	if length < 1:
		return
	var direction := difference / length
	for index in range(ceili(length / 15.0)):
		var distance := float(index) * 15.0
		map_canvas.draw_line(start + direction * distance, start + direction * minf(distance + 6, length), ROUTE, 2)


func _draw_island(center: Vector2, id: String, unlocked: bool) -> void:
	var silhouette := PackedVector2Array([
		Vector2(-42, 7), Vector2(-34, -15), Vector2(-19, -20), Vector2(-11, -31),
		Vector2(10, -32), Vector2(20, -23), Vector2(31, -23), Vector2(40, -8),
		Vector2(44, 10), Vector2(31, 23), Vector2(10, 28), Vector2(-5, 22), Vector2(-22, 26), Vector2(-35, 18),
	])
	var stretch := Vector2(1, 1)
	if id == "island_mist":
		stretch = Vector2(0.87, 1.16)
	elif id == "island_reef":
		stretch = Vector2(1.14, 0.70)
	elif id == "island_wind":
		stretch = Vector2(1.13, 0.79)
	var coast := PackedVector2Array()
	var beach := PackedVector2Array()
	var grass := PackedVector2Array()
	for vertex in silhouette:
		coast.append((center + vertex * stretch * 1.14).round())
		beach.append((center + vertex * stretch).round())
		grass.append((center + vertex * stretch * 0.77 + Vector2(0, -2)).round())
	map_canvas.draw_colored_polygon(coast, Color("b9d0ba") if unlocked else Color("a7c3b6"))
	map_canvas.draw_colored_polygon(beach, SHORE if unlocked else Color("93aca0"))
	map_canvas.draw_colored_polygon(grass, LAND if unlocked else Color("7f9d93"))
	if unlocked:
		for tree in [Vector2(-17, 0), Vector2(5, -12), Vector2(22, 2)]:
			var at: Vector2 = center + tree
			map_canvas.draw_rect(Rect2(at + Vector2(-1, 0), Vector2(3, 9)), Color("71644a"))
			map_canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-8, 1), at + Vector2(-4, -5), at + Vector2(5, -7), at + Vector2(9, 0), at + Vector2(4, 5), at + Vector2(-4, 5)]), DARK_LAND)
		map_canvas.draw_rect(Rect2(center + Vector2(-31, 15), Vector2(16, 5)), Color("947858"))
	else:
		var at := center + Vector2(0, -3)
		map_canvas.draw_arc(at + Vector2(0, -4), 5, PI, TAU, 8, Color("d1dac8"), 2, false)
		map_canvas.draw_rect(Rect2(at + Vector2(-7, -3), Vector2(14, 11)), Color("d1dac8"))
		map_canvas.draw_rect(Rect2(at + Vector2(-1, 0), Vector2(2, 4)), Color("6c8a80"))


func _draw_raft(center: Vector2) -> void:
	map_canvas.draw_circle(center, 18, Color(0.92, 0.91, 0.72, 0.60))
	map_canvas.draw_rect(Rect2(center - Vector2(12, 9), Vector2(24, 18)), Color("6b5843"))
	for plank in 4:
		map_canvas.draw_rect(Rect2(center + Vector2(-11 + plank * 6, -8), Vector2(5, 16)), Color("c9ad78"))
	map_canvas.draw_line(center + Vector2(-11, -4), center + Vector2(11, -4), Color("8b704b"), 1)
	map_canvas.draw_line(center + Vector2(-11, 5), center + Vector2(11, 5), Color("8b704b"), 1)
	map_canvas.draw_rect(Rect2(center + Vector2(-2, -15), Vector2(3, 13)), Color("485b4d"))
	map_canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(1, -15), center + Vector2(11, -11), center + Vector2(1, -7)]), Color("a5634e"))


func _draw_flag(at: Vector2) -> void:
	map_canvas.draw_line(at, at + Vector2(0, -21), Color("5e5942"), 2)
	map_canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(1, -21), at + Vector2(17, -17), at + Vector2(1, -11)]), Color("a5634e"))


func _draw_compass(at: Vector2) -> void:
	map_canvas.draw_arc(at, 22, 0, TAU, 24, SEA_LINE, 1, false)
	map_canvas.draw_line(at - Vector2(30, 0), at + Vector2(30, 0), SEA_LINE, 1)
	map_canvas.draw_line(at - Vector2(0, 31), at + Vector2(0, 31), SEA_LINE, 1)
	map_canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -23), at + Vector2(7, 0), at + Vector2(0, -4)]), Color("557c71"))
	map_canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, 23), at + Vector2(-7, 0), at + Vector2(0, 4)]), Color("d6dbc0"))

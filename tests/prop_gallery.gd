extends SceneTree
## Standalone rendered catalog; needs a graphical renderer, not --headless.
## godot --path <project> --script res://tests/prop_gallery.gd
## Optional user arg: -- --output=<absolute png path>
const Art = preload("res://scripts/art_catalog.gd")
const COLUMNS: int = 6
const CARD_SIZE: Vector2 = Vector2(248, 176)
const ORIGIN: Vector2 = Vector2(20, 100)
var viewport: SubViewport
var canvas: Node2D
var font: SystemFont
var entries: Array[Dictionary] = []
var output: String = ""
var sheet_size: Vector2i = Vector2i.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("PROP GALLERY requires a graphical renderer; remove --headless. Pixel checks support headless independently.")
		quit(2)
		return
	output = ProjectSettings.globalize_path("res://artifacts/prop-gallery-0.8.png")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if directory_error != OK:
		printerr("PROP GALLERY output folder failed: ", error_string(directory_error))
		quit(1)
		return
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Segoe UI"])
	for key: String in Art.keys():
		var before: Texture2D = Art.source_texture(key)
		var after: Texture2D = Art.texture(key)
		if before == null or after == null:
			printerr("PROP GALLERY missing catalog texture: ", key)
			quit(1)
			return
		entries.append({"key": key, "before": before, "after": after})
	sheet_size = Vector2i(1600, int(ORIGIN.y) + ceili(float(entries.size()) / float(COLUMNS)) * 188 + 52)
	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.size = sheet_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	canvas = Node2D.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(canvas)
	canvas.draw.connect(_draw_sheet)
	canvas.queue_redraw()
	# The sheet has an independent render target, so display-size/DPI clamping
	# cannot crop rows. A smaller root-window preview is only a convenience.
	root.title = "Tidehaven 0.8 · prop catalog"
	root.size = Vector2i(800, 828)
	root.content_scale_size = Vector2i(800, 828)
	var preview: TextureRect = TextureRect.new()
	preview.texture = viewport.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.size = Vector2(800, 828)
	root.add_child(preview)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = viewport.get_texture().get_image()
	if screenshot == null or screenshot.is_empty() or screenshot.get_size() != sheet_size:
		printerr("PROP GALLERY render target is missing or has incorrect dimensions")
		quit(1)
		return
	var saved: Error = screenshot.save_png(output)
	if saved != OK:
		printerr("PROP GALLERY saving failed: ", error_string(saved))
		quit(1)
		return
	print("PROP GALLERY: %d before/after pairs saved to %s (%dx%d)" % [entries.size(), output, sheet_size.x, sheet_size.y])
	quit(0)


func _draw_sheet() -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(sheet_size)), Color("d9decb"))
	_text("潮间小屋 · 全部物资与设施", Vector2(22, 39), 28, Color("3f5750"))
	_text("%d 个键 · 左：当前源图  /  右：统一材质边缘 · 人物不在本目录中" % entries.size(), Vector2(22, 73), 18, Color("63796a"))
	for index: int in entries.size():
		var row: int = floori(float(index) / float(COLUMNS))
		var at: Vector2 = ORIGIN + Vector2(float(index % COLUMNS) * 260.0, float(row) * 188.0)
		var entry: Dictionary = entries[index]
		canvas.draw_rect(Rect2(at, CARD_SIZE), Color("f3ebd8"))
		_text(str(entry.key), at + Vector2(10, 24), 18, Color("435b50"))
		_text("源图", at + Vector2(30, 47), 13, Color("7c8270"))
		_text("材质边缘", at + Vector2(145, 47), 13, Color("507864"))
		_draw_sample(entry.before, Rect2(at + Vector2(12, 54), Vector2(100, 100)))
		_draw_sample(entry.after, Rect2(at + Vector2(136, 54), Vector2(100, 100)))
		var dimensions: Vector2 = entry.after.get_size()
		_text("%d × %d" % [int(dimensions.x), int(dimensions.y)], at + Vector2(10, 169), 12, Color("8a917c"))
	_text("背景上下分别模拟纸面与海水。原始 PNG 不变；工具、睡袋与地板为代码原生图。明暗与状态的最终判断仍需场景截图。", Vector2(22, sheet_size.y - 29), 16, Color("63796a"))


func _draw_sample(texture: Texture2D, area: Rect2) -> void:
	canvas.draw_rect(area, Color("e4dcc6"))
	canvas.draw_rect(Rect2(area.position + Vector2(0, 50), Vector2(100, 50)), Color("4c8d91"))
	var dimensions: Vector2 = texture.get_size()
	var scale_value: float = floorf(minf(96.0 / dimensions.x, 96.0 / dimensions.y))
	var extent: Vector2 = dimensions * maxf(1.0, scale_value)
	canvas.draw_texture_rect(texture, Rect2((area.get_center() - extent * 0.5).round(), extent), false)


func _text(text: String, at: Vector2, font_size: int, color: Color) -> void:
	canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

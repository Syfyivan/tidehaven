extends RefCounted
## Shared pixel skin: fixed corners, warm paper and sea-green selection.
const INK := Color("514332")
const MUTED := Color("857256")
const PAPER := Color("f3e6c9")
const ACCENT := Color("3f715f")
const SHADE := Color(0.07, 0.14, 0.13, 0.56)
static var _textures: Dictionary = {}

static var _styles: Dictionary = {}

static func box(tone: String = "paper") -> StyleBox:
	if _styles.has(tone):
		return _styles[tone]
	var style: StyleBox
	if tone in ["clear", "reply"]:
		style = StyleBoxEmpty.new()
	elif tone in ["map_hover", "map_selected"]:
		var outline := StyleBoxFlat.new()
		outline.draw_center = false
		outline.border_color = ACCENT if tone == "map_selected" else Color("a0744f")
		outline.set_border_width_all(3 if tone == "map_selected" else 2)
		style = outline
	elif tone in ["paper", "wood", "hud", "button", "button_hover", "button_pressed", "primary", "primary_hover", "disabled", "quick", "quick_hover", "quick_selected", "slot", "slot_hover", "slot_selected", "reply_hover"]:
		var textured := StyleBoxTexture.new()
		if tone == "reply_hover":
			textured.texture = atlas("cursors", Rect2(375, 357, 3, 3))
			textured.set_texture_margin_all(1)
		elif tone in ["quick", "quick_hover", "quick_selected", "slot", "slot_hover", "slot_selected"]:
			# Menu tiles 10 and 56 are the original inventory recess and selected outline.
			textured.texture = atlas("menu", Rect2(0, 896, 64, 64) if tone in ["quick_selected", "slot_selected"] else Rect2(128, 128, 64, 64))
			textured.set_texture_margin_all(12)
			textured.modulate_color = Color("fff0c9") if tone in ["quick_hover", "slot_hover"] else Color.WHITE
		else:
			textured.texture = atlas("menu", Rect2(0, 256, 60, 60))
			textured.set_texture_margin_all(20 if tone in ["paper", "wood"] else 10)
			textured.modulate_color = {"wood": Color("deba88"), "hud": Color("405a52"), "button_hover": Color("fff5ca"), "button_pressed": Color("dfb77c"), "primary": Color("d9e5b4"), "primary_hover": Color("ebf6c7"), "disabled": Color("c3b18d")}.get(tone, Color.WHITE)
		style = textured
	else:
		var skin: String = {"hud": "dark", "quick": "slot", "quick_hover": "slot_hover", "quick_selected": "slot_selected"}.get(tone, tone)
		var textured := StyleBoxTexture.new()
		textured.texture = _texture("res://assets/ui/" + skin + ".svg")
		textured.set_texture_margin_all(10 if skin == "paper" else 8)
		style = textured
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 9
	_styles[tone] = style
	return style

static func rule(parent: Node, rect: Rect2) -> ColorRect:
	var result := ColorRect.new()
	result.position = rect.position
	result.size = rect.size
	result.color = Color("d7c3a0")
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]

static func symbol(key: String) -> Texture2D:
	return _texture("res://assets/ui/icon_" + key + ".svg")

static func atlas(sheet: String, region: Rect2) -> AtlasTexture:
	var key := "%s:%s" % [sheet, region]
	if not _textures.has(key):
		var result := AtlasTexture.new()
		result.atlas = _texture("res://assets/vendor/stardew-island/ui/" + ("Cursors.png" if sheet == "cursors" else "MenuTiles.png"))
		result.region = region
		result.filter_clip = true
		_textures[key] = result
	return _textures[key]

static func panel(parent: Node, rect: Rect2, tone: String = "paper") -> Panel:
	var result := Panel.new()
	result.position = rect.position
	result.size = rect.size
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.add_theme_stylebox_override("panel", box(tone))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

static func label(parent: Node, value: String, rect: Rect2, points: int = 18, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = value
	result.position = rect.position
	result.size = rect.size
	result.add_theme_font_size_override("font_size", points)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

static func button(parent: Node, value: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = value
	result.position = rect.position
	result.size = rect.size
	result.focus_mode = Control.FOCUS_NONE
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.add_theme_font_size_override("font_size", 18)
	for appearance in ["normal", "hover", "pressed", "disabled"]:
		var tone: String = {"normal": "primary" if primary else "button", "hover": "primary_hover" if primary else "button_hover", "pressed": "button_pressed", "disabled": "disabled"}[appearance]
		result.add_theme_stylebox_override(appearance, box(tone))
		result.add_theme_color_override("font_" + appearance + "_color" if appearance != "normal" else "font_color", MUTED if appearance == "disabled" else INK)
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

static func icon(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var result := TextureRect.new()
	result.position = rect.position
	result.size = rect.size
	result.texture = texture
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

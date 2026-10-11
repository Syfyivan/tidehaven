extends RefCounted
## Quiet canvas, ink and timber surfaces. Gameplay does not live here.
const INK := Color("3d3930")
const MUTED := Color("807869")
const PAPER := Color("e9e1c9")
const ACCENT := Color("597966")
const SHADE := Color(0.07, 0.13, 0.14, 0.48)
static var _textures: Dictionary = {}

static func box(tone: String = "paper") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var fills := {
		"paper": Color("e9e1c9"), "wood": Color("665949"),
		"dark": Color(0.10, 0.19, 0.20, 0.90), "hud": Color(0.10, 0.18, 0.18, 0.76),
		"clear": Color.TRANSPARENT, "button": Color("d7ceb5"),
		"button_hover": Color("e3dac1"), "button_pressed": Color("bcb598"),
		"primary": Color("597966"), "primary_hover": Color("6b8b75"),
		"disabled": Color("d4cfbf"), "slot": Color("d5cbb1"),
		"slot_hover": Color("e2d8bc"), "slot_selected": Color("bfcca9"),
		"quick": Color(0.80, 0.82, 0.70, 0.06),
		"quick_hover": Color(0.80, 0.82, 0.70, 0.18),
		"quick_selected": Color(0.80, 0.82, 0.70, 0.24),
	}
	style.bg_color = fills.get(tone, PAPER)
	style.border_color = Color("aaa084")
	style.set_border_width_all(1)
	if tone in ["paper", "wood"]:
		style.border_color = Color("62584a")
		style.shadow_color = Color(0.05, 0.10, 0.10, 0.25)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 4)
	elif tone in ["hud", "dark", "clear", "quick", "quick_hover"]:
		style.set_border_width_all(0)
	elif tone in ["primary", "primary_hover"]:
		style.border_color = Color("425c50")
	elif tone in ["slot_selected", "quick_selected"]:
		style.border_color = Color("c7cba2") if tone == "quick_selected" else ACCENT
		style.border_width_bottom = 3
	style.set_corner_radius_all(2)
	style.anti_aliasing = false
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 9
	return style

static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]

static func symbol(key: String) -> Texture2D:
	return _texture("res://assets/ui/icon_" + key + ".svg")

static func panel(parent: Node, rect: Rect2, tone: String = "paper") -> Panel:
	var result := Panel.new()
	result.position = rect.position
	result.size = rect.size
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.add_theme_stylebox_override("panel", box(tone))
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
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.add_theme_font_size_override("font_size", 18)
	for appearance in ["normal", "hover", "pressed", "disabled"]:
		var tone: String = {"normal": "primary" if primary else "button", "hover": "primary_hover" if primary else "button_hover", "pressed": "button_pressed", "disabled": "disabled"}[appearance]
		result.add_theme_stylebox_override(appearance, box(tone))
		result.add_theme_color_override("font_" + appearance + "_color" if appearance != "normal" else "font_color", PAPER if primary and appearance in ["normal", "hover"] else (MUTED if appearance == "disabled" else INK))
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

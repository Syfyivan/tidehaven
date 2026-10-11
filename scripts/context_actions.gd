extends Control
## Explicit nearby choices; action authority remains in WorldState.
signal chosen(option: Dictionary)
const UI = preload("res://scripts/ui_style.gd")
var buttons: Array[Button] = []

func _ready() -> void:
	size = Vector2(1280, 800)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func present(options: Array, at: Vector2) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	buttons.clear()
	if options.is_empty():
		hide()
		return
	var content_height := options.size() * 38.0
	var height := minf(608, 48.0 + content_height)
	var panel := UI.panel(self, Rect2(Vector2(clampf(at.x, 20, 770), clampf(at.y, 100, 780 - height)), Vector2(490, height)))
	UI.label(panel, "附近可以做的事", Rect2(14, 10, 285, 24), 16)
	UI.button(panel, "×", Rect2(448, 6, 32, 30), hide)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 40)
	scroll.size = Vector2(470, height - 48)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var contents := Control.new()
	contents.custom_minimum_size = Vector2(454, content_height)
	scroll.add_child(contents)
	for index in options.size():
		var option: Dictionary = options[index].duplicate(true)
		buttons.append(UI.button(contents, str(option.label), Rect2(0, index * 38, 454, 34), func():
			hide()
			chosen.emit(option)))
		buttons[-1].add_theme_font_size_override("font_size", 16)
	show()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide()
		accept_event()

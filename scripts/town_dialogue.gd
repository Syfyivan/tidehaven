extends Control
## Bottom conversation window. Body and replies scroll independently without losing choices.
signal action_requested(verb: String, args: Dictionary)
const UI = preload("res://scripts/ui_style.gd")
const Portraits = preload("res://scripts/portrait_art.gd")
const Frame = preload("res://scripts/dialogue_frame.gd")
var speaker: Label
var role: Label
var topic: Label
var portrait: TextureRect
var portrait_frame: TextureRect
var body: Label
var body_scroll: ScrollContainer
var close_button: Button
var choice_button: Button
var choice_buttons: Array[Button] = []
var choices_scroll: ScrollContainer
var choice_list: VBoxContainer

func _ready() -> void:
	size = Vector2(1280, 800)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var frame := Frame.new()
	frame.position = Vector2(64, 436)
	frame.size = Vector2(1152, 332)
	add_child(frame)
	portrait_frame = UI.icon(self, UI.atlas("cursors", Rect2(583, 411, 115, 97)), Rect2(950, 480, 230, 194))
	portrait = UI.icon(self, null, Rect2(1000, 496, 128, 128))
	speaker = UI.label(self, "", Rect2(974, 637, 184, 30), 22)
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role = UI.label(self, "", Rect2(966, 685, 200, 24), 16, UI.MUTED)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	topic = UI.label(self, "", Rect2(100, 466, 824, 26), 17, UI.MUTED)
	body_scroll = ScrollContainer.new()
	body_scroll.position = Vector2(98, 470)
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(body_scroll)
	body = UI.label(body_scroll, "", Rect2(0, 0, 826, 104), 20)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_constant_override("line_spacing", 4)
	close_button = UI.button(self, "×", Rect2(1160, 454, 34, 32), hide)
	close_button.tooltip_text = "结束交谈 · Esc"
	choices_scroll = ScrollContainer.new()
	choices_scroll.position = Vector2(98, 586)
	choices_scroll.size = Vector2(830, 126)
	choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(choices_scroll)
	choice_list = VBoxContainer.new()
	choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_list.add_theme_constant_override("separation", 4)
	choices_scroll.add_child(choice_list)
	UI.label(self, "滚轮翻阅 · 点击回应", Rect2(102, 728, 720, 22), 14, UI.MUTED)
	hide()

func present(npc: Dictionary, message: String, choices: Array = [], npc_id: String = "") -> void:
	portrait.texture = Portraits.texture(npc_id)
	var has_portrait := portrait.texture != null
	portrait.visible = has_portrait
	portrait_frame.visible = has_portrait
	speaker.text = str(npc.name)
	role.text = str(npc.role)
	speaker.position = Vector2(974, 637) if has_portrait else Vector2(100, 464)
	speaker.size = Vector2(184, 30) if has_portrait else Vector2(240, 30)
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if has_portrait else HORIZONTAL_ALIGNMENT_LEFT
	role.position = Vector2(966, 685) if has_portrait else Vector2(346, 470)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if has_portrait else HORIZONTAL_ALIGNMENT_LEFT
	body_scroll.position.y = 500
	topic.position = Vector2(100, 466) if has_portrait else Vector2(580, 468)
	topic.size.x = 824 if has_portrait else 546
	topic.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if has_portrait else HORIZONTAL_ALIGNMENT_RIGHT
	var width := 830.0 if has_portrait else 1062.0
	var text := message.trim_prefix(str(npc.name) + "：")
	topic.text = ""
	if text.begins_with(str(npc.name) + " · ") and text.contains("\n"):
		var heading_end := text.find("\n")
		topic.text = text.left(heading_end).trim_prefix(str(npc.name) + " · ")
		text = text.substr(heading_end).strip_edges()
	body.text = text
	body_scroll.scroll_vertical = 0
	for child: Node in choice_list.get_children():
		choice_list.remove_child(child)
		child.queue_free()
	choice_buttons.clear()
	choice_button = null
	choices_scroll.size.x = width
	choices_scroll.visible = not choices.is_empty()
	for option: Dictionary in choices:
		var choice: Dictionary = option.duplicate(true)
		var button := UI.button(choice_list, "›  " + str(choice.label), Rect2(0, 0, width - 18, 40), func(): action_requested.emit(str(choice.action), choice.args))
		button.custom_minimum_size = Vector2(0, 40)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_stylebox_override("normal", UI.box("reply"))
		button.add_theme_stylebox_override("hover", UI.box("reply_hover"))
		button.add_theme_stylebox_override("pressed", UI.box("reply_hover"))
		choice_buttons.append(button)
	if not choice_buttons.is_empty():
		choice_button = choice_buttons[0]
	var choice_height := minf(126.0, choice_list.get_combined_minimum_size().y)
	choices_scroll.position.y = 712.0 - choice_height
	choices_scroll.size.y = choice_height if not choices.is_empty() else 0.0
	var body_end := choices_scroll.position.y - 12 if not choices.is_empty() else 712.0
	body_scroll.size = Vector2(width, body_end - body_scroll.position.y)
	choices_scroll.scroll_vertical = 0
	show()

extends Control
## One conversation panel, using the existing UI palette and normal modal rules.
const UI = preload("res://scripts/ui_style.gd")
var speaker: Label
var body: Label
var close_button: Button

func _ready() -> void:
	size = Vector2(1280, 800)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.panel(self, Rect2(224, 496, 832, 222), "paper")
	speaker = UI.label(self, "", Rect2(254, 516, 730, 32), 23)
	body = UI.label(self, "", Rect2(256, 564, 768, 118), 20)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	close_button = UI.button(self, "×", Rect2(996, 514, 36, 36), hide)
	close_button.tooltip_text = "结束交谈 · Esc"
	hide()

func present(npc: Dictionary, message: String) -> void:
	speaker.text = "%s · %s" % [npc.name, npc.role]
	body.text = message.trim_prefix(str(npc.name) + "：")
	show()

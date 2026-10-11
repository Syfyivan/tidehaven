extends Control

signal command(verb: String, args: Dictionary)
signal close_requested

const Inventory = preload("res://scripts/inventory.gd")
const SlotButton = preload("res://scripts/inventory_slot.gd")
const Art = preload("res://scripts/art_catalog.gd")
const UI = preload("res://scripts/ui_style.gd")
const SLOT_SIZE := 72
const SLOT_PITCH := 84

var bag_buttons: Array = []
var chest_buttons: Array = []
var selected: Dictionary = {}
var chest_id := ""
var data: Dictionary = {}
var slot := "host"
var bag_title: Label
var chest_title: Label
var selection_note: Label
var feedback: Label
var vitals: Label
var open_button: Button
var discard_button: Button
var discard_dialog: Control
var discard_confirm_button: Button
var discard_cancel_button: Button
var discard_note: Label
var discard_request: Dictionary = {}
var deposit_button: Button
var sort_chest: Button
var sort_bag_button: Button
var close_button: Button

var paper: Panel
var title_label: Label
var detail_hint: Label
var footer_note: Label
var discard_icon: TextureRect
var hovered: Dictionary = {}
var _with_chest := false
var detail_icon: TextureRect
var usage_label: Label
var source_label: Label
var _usage_heading: Label
var _source_heading: Label
var _capacity_note: Label

func _ready() -> void:
	size = Vector2(1280, 800)
	var shade := ColorRect.new()
	shade.size = size
	shade.color = UI.SHADE
	add_child(shade)
	paper = UI.panel(self, Rect2())
	title_label = UI.label(self, "随身物品", Rect2(), 26)
	vitals = UI.label(self, "", Rect2(), 16, UI.MUTED)
	bag_title = UI.label(self, "背包", Rect2(), 20)
	chest_title = UI.label(self, "木箱", Rect2(), 20)
	for index in Inventory.BAG_SIZE:
		bag_buttons.append(_slot_button("bag", index))
	for index in Inventory.CHEST_SIZE:
		chest_buttons.append(_slot_button("chest", index))
	detail_icon = UI.icon(self, null, Rect2())
	selection_note = UI.label(self, "选择物品", Rect2(), 22, UI.MUTED)
	_usage_heading = UI.label(self, "用途", Rect2(), 14, UI.MUTED)
	usage_label = UI.label(self, "", Rect2(), 17)
	usage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_source_heading = UI.label(self, "获得方式", Rect2(), 14, UI.MUTED)
	source_label = UI.label(self, "", Rect2(), 16, UI.MUTED)
	source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_hint = UI.label(self, "左键整堆 · 右键拆分", Rect2(), 14, UI.MUTED)
	detail_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_capacity_note = UI.label(self, "", Rect2(), 15, UI.MUTED)
	sort_bag_button = UI.button(self, "整理", Rect2(), func():
		selected = {}
		command.emit("sort_inventory", {"container": "bag"}))
	open_button = UI.button(self, "打开宝箱", Rect2(), _open_treasure, true)
	discard_button = UI.button(self, "丢弃", Rect2(), _confirm_discard)
	deposit_button = UI.button(self, "存入木箱", Rect2(), func():
		selected = {}
		command.emit("deposit", {"container": chest_id}))
	sort_chest = UI.button(self, "整理木箱", Rect2(), func():
		selected = {}
		command.emit("sort_inventory", {"container": chest_id}))
	close_button = UI.button(self, "×", Rect2(), func(): close_requested.emit())
	close_button.tooltip_text = "关闭背包 · B / Esc"
	feedback = UI.label(self, "", Rect2(), 17, UI.ACCENT)
	feedback.clip_text = true
	feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	feedback.mouse_filter = Control.MOUSE_FILTER_PASS
	footer_note = UI.label(self, "", Rect2(), 15, UI.MUTED)
	_build_discard_confirmation()
	_apply_layout(false)
	_refresh_details()
	hide()

func _apply_layout(with_chest: bool) -> void:
	_with_chest = with_chest
	var left := 128.0 if with_chest else 256.0
	var width := 1024.0 if with_chest else 768.0
	var bag_left := left + 32.0
	var chest_left := left + 668.0
	var detail_left := left + 388.0
	var detail_width := 248.0 if with_chest else 348.0
	_set_rect(paper, Rect2(left, 80, width, 640))
	_set_rect(title_label, Rect2(bag_left, 106, width - 132, 36))
	_set_rect(close_button, Rect2(left + width - 68, 106, 36, 34))
	_set_rect(vitals, Rect2(bag_left, 151, width - 64, 23))
	_set_rect(bag_title, Rect2(bag_left, 190, 324, 27))
	_set_rect(chest_title, Rect2(chest_left, 190, 324, 27))
	chest_title.visible = with_chest
	for index in bag_buttons.size():
		_set_rect(bag_buttons[index], Rect2(bag_left + (index % 4) * SLOT_PITCH, 228 + floori(index / 4.0) * SLOT_PITCH, SLOT_SIZE, SLOT_SIZE))
	for index in chest_buttons.size():
		_set_rect(chest_buttons[index], Rect2(chest_left + (index % 4) * SLOT_PITCH, 228 + floori(index / 4.0) * SLOT_PITCH, SLOT_SIZE, SLOT_SIZE))
		chest_buttons[index].visible = with_chest
	_set_rect(detail_icon, Rect2(detail_left, 224, 64, 64))
	_set_rect(selection_note, Rect2(detail_left, 300, detail_width, 32))
	_set_rect(_usage_heading, Rect2(detail_left, 351, detail_width, 22))
	_set_rect(usage_label, Rect2(detail_left, 379, detail_width, 66))
	_set_rect(_source_heading, Rect2(detail_left, 461, detail_width, 22))
	_set_rect(source_label, Rect2(detail_left, 489, detail_width, 54))
	_set_rect(detail_hint, Rect2(detail_left, 563, detail_width, 47))
	_set_rect(sort_bag_button, Rect2(bag_left, 494, 92, 40))
	_set_rect(_capacity_note, Rect2(bag_left, 547, 324, 25))
	_set_rect(open_button, Rect2(detail_left, 628, 140, 40))
	_set_rect(discard_button, Rect2(detail_left + 152, 628, 96, 40))
	_set_rect(deposit_button, Rect2(chest_left, 576, 156, 40))
	_set_rect(sort_chest, Rect2(chest_left + 168, 576, 156, 40))
	deposit_button.visible = with_chest
	sort_chest.visible = with_chest
	_set_rect(feedback, Rect2(bag_left, 589, 324, 55))
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_rect(footer_note, Rect2(bag_left, 684, width - 64, 23))

func _build_discard_confirmation() -> void:
	discard_dialog = Control.new()
	discard_dialog.size = size
	add_child(discard_dialog)
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0.16, 0.18, 0.15, 0.38)
	discard_dialog.add_child(shade)
	UI.panel(discard_dialog, Rect2(416, 277, 448, 246))
	UI.label(discard_dialog, "丢弃这些物品？", Rect2(448, 300, 364, 36), 26)
	discard_icon = UI.icon(discard_dialog, null, Rect2(448, 352, 56, 56))
	discard_note = UI.label(discard_dialog, "", Rect2(520, 350, 306, 62), 21)
	UI.label(discard_dialog, "丢弃后无法找回。", Rect2(448, 422, 370, 25), 17, UI.MUTED)
	discard_cancel_button = UI.button(discard_dialog, "保留", Rect2(448, 467, 176, 36), func(): discard_dialog.hide(), true)
	discard_confirm_button = UI.button(discard_dialog, "确认丢弃", Rect2(640, 467, 192, 36), func():
		selected = {}
		discard_dialog.hide()
		command.emit("discard", discard_request))
	discard_dialog.hide()

func refresh(state: Dictionary, player_slot: String, nearby: String, message: String, multiplayer_mode: bool) -> void:
	data = state
	slot = player_slot
	if nearby != chest_id:
		selected = {}
		hovered = {}
	chest_id = nearby
	var with_chest := not chest_id.is_empty()
	if with_chest != _with_chest:
		_apply_layout(with_chest)
	var bag: Array = data.players[slot].bag
	var player: Dictionary = data.players[slot]
	vitals.text = "水下 · 氧气 %d / 100" % int(player.oxygen) if player.area == "water" else ("潮芽岛" if player.area == "island" else "甲板") + " · 饱食 %d · 饮水 %d" % [int(player.get("hunger", 100)), int(player.get("thirst", 100))]
	if player.area == "water" and Inventory.count(player.bag, "fins") > 0:
		vitals.text += " · 脚蹼"
	vitals.add_theme_color_override("font_color", Color("b45e49") if player.area == "water" and float(player.oxygen) < 25 else UI.MUTED)
	bag_title.text = "背包   %d / %d 格" % [Inventory.used(bag), bag.size()]
	_capacity_note.text = "每格最多 %d 件 · 剩余 %d 格" % [Inventory.STACK_LIMIT, bag.size() - Inventory.used(bag)]
	_capacity_note.add_theme_color_override("font_color", Color("b45543") if Inventory.used(bag) == bag.size() else UI.MUTED)
	var chest_slots: Array = data.chests[chest_id].slots if with_chest else []
	chest_title.text = "%s   %d / %d 格" % [data.chests[chest_id].name, Inventory.used(chest_slots), chest_slots.size()] if with_chest else ""
	for index in bag_buttons.size():
		bag_buttons[index].show_stack(bag[index], selected.get("container") == "bag" and int(selected.get("index", -1)) == index)
	for index in chest_buttons.size():
		if with_chest:
			chest_buttons[index].show_stack(chest_slots[index], selected.get("container") == chest_id and int(selected.get("index", -1)) == index)
	deposit_button.disabled = not with_chest
	sort_chest.disabled = not with_chest
	footer_note.text = ("联机时间继续 · 木箱由两人共享" if multiplayer_mode else "整理时世界暂停 · 木箱共享") if with_chest else ("联机时间继续 · 靠近木箱可存取" if multiplayer_mode else "整理时世界暂停 · 靠近木箱可存取")
	feedback.text = message
	feedback.tooltip_text = message
	_refresh_details()

func clear_selection() -> void:
	selected = {}
	hovered = {}
	if is_instance_valid(discard_dialog):
		discard_dialog.hide()
	_refresh_details()

func get_slot_button(container: String, index: int) -> Button:
	var buttons: Array = bag_buttons if container == "bag" else chest_buttons
	return buttons[index] if index >= 0 and index < buttons.size() else null

func _slot_button(container: String, index: int) -> Button:
	var button = SlotButton.new()
	button.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	add_child(button)
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_clicked(container, index, event.button_index == MOUSE_BUTTON_RIGHT)
			button.accept_event())
	button.mouse_entered.connect(func():
		hovered = {"container": container, "index": index}
		_refresh_details())
	button.mouse_exited.connect(func():
		if hovered.get("container") == container and int(hovered.get("index", -1)) == index:
			hovered = {}
			_refresh_details())
	return button

func _refresh_details() -> void:
	if not is_instance_valid(selection_note):
		return
	var item := ""
	var amount := 0
	if not selected.is_empty():
		item = str(selected.item)
		amount = int(selected.amount)
	elif not hovered.is_empty() and not data.is_empty():
		var contents: Array = data.players[slot].bag if hovered.container == "bag" else (data.chests[chest_id].slots if not chest_id.is_empty() else [])
		var index: int = int(hovered.index)
		if index >= 0 and index < contents.size() and not contents[index].is_empty():
			item = str(contents[index].item)
			amount = int(contents[index].count)
	selection_note.text = "%s  ×%d" % [Inventory.ITEM_NAMES.get(item, item), amount] if not item.is_empty() else "选择物品"
	selection_note.add_theme_color_override("font_color", UI.INK if not item.is_empty() else UI.MUTED)
	detail_icon.texture = Art.item_icon(item) if not item.is_empty() else UI.symbol("bag")
	detail_icon.modulate = Color.WHITE if not item.is_empty() else Color(UI.MUTED, 0.55)
	_usage_heading.visible = not item.is_empty()
	_source_heading.visible = not item.is_empty()
	usage_label.text = SlotButton.item_usage(item) if not item.is_empty() else "悬停或选择一格，\n查看用途与获得方式。"
	source_label.text = SlotButton.item_source(item) if not item.is_empty() else ""
	detail_hint.text = "点击目标格移动\n右键放 1 件 · 原格取消" if not selected.is_empty() else "左键整堆 · 右键拆分\n点击空格移动或叠放。"
	open_button.visible = item == "treasure"
	open_button.disabled = selected.get("container") != "bag" or selected.get("item") != "treasure"
	discard_button.disabled = selected.is_empty() or selected.get("container") != "bag"
	discard_button.text = "丢弃 ×%d" % int(selected.get("amount", 0)) if not discard_button.disabled else "丢弃"

func _clicked(container: String, index: int, right: bool) -> void:
	var resolved := chest_id if container == "chest" else "bag"
	if resolved.is_empty() or data.is_empty() or discard_dialog.visible:
		return
	var contents: Array = data.players[slot].bag if resolved == "bag" else data.chests[resolved].slots
	var stack: Dictionary = contents[index]
	if selected.is_empty():
		if not stack.is_empty():
			selected = {"container": resolved, "index": index, "item": stack.item, "amount": int(ceil(float(stack.count) / 2.0)) if right else int(stack.count)}
	elif selected.container == resolved and int(selected.index) == index:
		selected = {}
	else:
		var request := {"from_container": selected.container, "from_index": selected.index, "to_container": resolved, "to_index": index, "amount": 1 if right else selected.amount, "expected_item": selected.item}
		selected = {}
		command.emit("inventory_move", request)
	_refresh_details()

func _open_treasure() -> void:
	if selected.get("container") == "bag" and selected.get("item") == "treasure":
		var index := int(selected.index)
		selected = {}
		command.emit("open_treasure", {"index": index})

func _confirm_discard() -> void:
	if selected.is_empty() or selected.get("container") != "bag":
		return
	discard_request = {"index": int(selected.index), "amount": int(selected.amount), "expected_item": str(selected.item)}
	discard_note.text = "%s ×%d" % [Inventory.ITEM_NAMES[selected.item], int(selected.amount)]
	discard_icon.texture = Art.item_icon(str(selected.item))
	discard_dialog.show()

func _set_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

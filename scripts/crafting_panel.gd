extends Control

signal craft_requested(recipe: String)
signal close_requested

const Recipes = preload("res://scripts/recipes.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Art = preload("res://scripts/art_catalog.gd")
const UI = preload("res://scripts/ui_style.gd")
const ItemSlot = preload("res://scripts/inventory_slot.gd")
const SHORT_NAMES := {"purifier": "净水器", "chest": "储物箱", "reinforced_hook": "强化钩", "anchor": "简易锚"}
const SHORTAGE := Color("b45543")

var selected_recipe := "rope"
var title_label: Label
var description_label: Label
var cost_label: Label
var note: Label
var picture: TextureRect
var make_button: Button
var close_button: Button
var recipe_buttons: Dictionary = {}
var category_buttons: Dictionary = {}
var selected_category := "survival"
var exploration_note: Label
var _recipe_labels: Dictionary = {}
var _cost_rows: Array = []
var _category_label: Label
var _shown_recipe := ""
var result_message := ""
var recipe_scroll: ScrollContainer
var _recipe_grid: Control


func _ready() -> void:
	size = Vector2(1280, 800)
	var shade := ColorRect.new()
	shade.size = size
	shade.color = UI.SHADE
	add_child(shade)
	UI.panel(self, Rect2(180, 96, 920, 608), "paper")
	UI.label(self, "制作手册", Rect2(216, 120, 420, 39), 28)
	UI.label(self, "选一张配方，看看还需要什么。", Rect2(216, 163, 575, 23), 15, UI.MUTED)
	close_button = UI.button(self, "×", Rect2(1028, 120, 38, 38), func(): close_requested.emit())
	close_button.add_theme_font_size_override("font_size", 25)
	close_button.tooltip_text = "关闭 · C / Esc"

	category_buttons.survival = UI.button(self, "生存建造", Rect2(216, 203, 122, 34), func(): _select_category("survival"))
	category_buttons.farming = UI.button(self, "农具暖棚", Rect2(346, 203, 122, 34), func(): _select_category("farming"))
	category_buttons.exploration = UI.button(self, "探索升级", Rect2(476, 203, 122, 34), func(): _select_category("exploration"))
	for tab in category_buttons.values():
		tab.add_theme_font_size_override("font_size", 15)
	recipe_scroll = ScrollContainer.new()
	recipe_scroll.position = Vector2(216, 251)
	recipe_scroll.size = Vector2(392, 310)
	recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	recipe_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(recipe_scroll)
	_recipe_grid = Control.new()
	_recipe_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_scroll.add_child(_recipe_grid)
	var indices := {"survival": 0, "farming": 0, "exploration": 0}
	for id in Recipes.ALL:
		var recipe: Dictionary = Recipes.ALL[id]
		var recipe_id: String = str(id)
		var group := _recipe_group(recipe_id)
		var index: int = indices[group]
		var button: Button = UI.button(_recipe_grid, "", Rect2((index % 4) * 96, floori(index / 4.0) * 102, 88, 94), func(): selected_recipe = recipe_id)
		button.add_theme_stylebox_override("normal", UI.box("slot"))
		button.add_theme_stylebox_override("hover", UI.box("slot_hover"))
		button.add_theme_stylebox_override("pressed", UI.box("slot_selected"))
		button.tooltip_text = str(recipe.name)
		UI.icon(button, _recipe_texture(recipe), Rect2(20, 8, 48, 48))
		var caption: Label = UI.label(button, str(SHORT_NAMES.get(id, recipe.name)), Rect2(2, 64, 84, 22), 14)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		recipe_buttons[id] = button
		_recipe_labels[id] = caption
		indices[group] += 1
	UI.label(self, "可用材料 = 你的背包 + 甲板木箱\n先用背包里的材料。", Rect2(216, 584, 388, 48), 15, UI.MUTED)
	exploration_note = UI.label(self, "石料、矿石在水下采集；金属锭由熔炉炼制。", Rect2(216, 646, 380, 37), 14, UI.MUTED)
	exploration_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	UI.panel(self, Rect2(656, 209, 88, 88), "slot")
	picture = UI.icon(self, null, Rect2(668, 221, 64, 64))
	title_label = UI.label(self, "", Rect2(762, 214, 300, 40), 26)
	_category_label = UI.label(self, "", Rect2(764, 261, 300, 27), 14, UI.MUTED)
	description_label = UI.label(self, "", Rect2(656, 316, 408, 54), 17)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost_label = UI.label(self, "所需材料", Rect2(656, 382, 165, 26), 16, UI.MUTED)
	var quantity_label: Label = UI.label(self, "可用 / 所需", Rect2(914, 382, 150, 26), 13, UI.MUTED)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for row_index in 3:
		var row := Control.new()
		row.position = Vector2(656, 418 + row_index * 54)
		row.size = Vector2(408, 47)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(row)
		var material_icon: TextureRect = UI.icon(row, null, Rect2(0, 3, 38, 38))
		var material_name: Label = UI.label(row, "", Rect2(52, 0, 192, 25), 17)
		var source: Label = UI.label(row, "", Rect2(52, 27, 242, 20), 12, UI.MUTED)
		source.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		source.clip_text = true
		var owned_label: Label = UI.label(row, "", Rect2(286, 0, 58, 26), 20)
		owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		UI.label(row, "/", Rect2(354, 0, 16, 26), 17, UI.MUTED)
		var needed_label: Label = UI.label(row, "", Rect2(375, 0, 32, 26), 20)
		needed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var deficit: Label = UI.label(row, "", Rect2(298, 27, 110, 20), 13, SHORTAGE)
		deficit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_cost_rows.append({"root": row, "icon": material_icon, "name": material_name, "owned": owned_label, "needed": needed_label, "source": source, "deficit": deficit})
	note = UI.label(self, "", Rect2(656, 588, 408, 37), 14, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	make_button = UI.button(self, "制作", Rect2(848, 640, 216, 42), func(): craft_requested.emit(selected_recipe), true)
	visibility_changed.connect(func(): result_message = "")
	_show_category()
	hide()


func refresh(data: Dictionary, slot: String) -> void:
	if _recipe_group(selected_recipe) != selected_category:
		selected_category = _recipe_group(selected_recipe)
		_show_category()
	var recipe: Dictionary = Recipes.ALL[selected_recipe]
	var available: Dictionary = Inventory.totals(data.players[slot].bag)
	for chest in (data.chests.values() if data.players[slot].area == "deck" else []):
		for item in Inventory.ITEMS:
			available[item] += Inventory.count(chest.slots, item)
	title_label.text = str(recipe.name)
	description_label.text = str(recipe.description)
	picture.texture = _recipe_texture(recipe)
	var is_structure: bool = not str(recipe.structure).is_empty()
	_category_label.text = "甲板设施" if is_structure else "随身工具 · 每次制作 %d 件" % int(recipe.amount)
	var enough := true
	var material_index := 0
	for item in recipe.costs:
		var owned: int = int(available.get(item, 0))
		var needed: int = int(recipe.costs[item])
		var row: Dictionary = _cost_rows[material_index]
		row.root.show()
		row.icon.texture = Art.item_icon(str(item))
		row.name.text = str(Inventory.ITEM_NAMES.get(item, item))
		row.owned.text = str(owned)
		row.owned.add_theme_color_override("font_color", UI.ACCENT if owned >= needed else SHORTAGE)
		row.needed.text = str(needed)
		row.source.text = ItemSlot.item_source(str(item))
		row.deficit.text = "还缺 %d" % (needed - owned) if owned < needed else ""
		row.root.tooltip_text = "%s\n来源：%s" % [ItemSlot.item_usage(str(item)), ItemSlot.item_source(str(item))]
		if owned < needed:
			enough = false
		material_index += 1
	for row_index in range(material_index, _cost_rows.size()):
		_cost_rows[row_index].root.hide()
	make_button.disabled = not enough
	make_button.text = ("选择放置位置" if is_structure else "制作  ×%d" % int(recipe.amount)) if enough else "材料不足"
	note.text = "可接在已有木筏的边缘。" if recipe.structure == "foundation" else ("需要一格空着的甲板。" if is_structure else "成品放入背包。")
	if selected_recipe in ["fins", "reinforced_hook"]:
		note.text = "随身携带生效 · 同类不叠加"
	if data.players[slot].area != "deck":
		note.text = "岛上只使用随身材料。设施请回到甲板建造。"
		if is_structure or data.players[slot].area == "water":
			make_button.disabled = true
			make_button.text = "请返回甲板"
	if _shown_recipe != selected_recipe:
		result_message = ""
		_shown_recipe = selected_recipe
		for id in recipe_buttons:
			var chosen: bool = id == selected_recipe
			var button: Button = recipe_buttons[id]
			button.add_theme_stylebox_override("normal", UI.box("slot_selected" if chosen else "slot"))
			button.add_theme_stylebox_override("hover", UI.box("slot_selected" if chosen else "slot_hover"))
			_recipe_labels[id].add_theme_color_override("font_color", UI.ACCENT if chosen else UI.INK)
	if not result_message.is_empty():
		note.text = result_message


func _recipe_group(id: String) -> String:
	if id in ["fiber_rope", "hoe", "scythe", "watering_can", "canopy"]:
		return "farming"
	return "exploration" if Recipes.ALL[id].category == "exploration" else "survival"


func _select_category(group: String) -> void:
	selected_category = group
	for id in Recipes.ALL:
		if _recipe_group(id) == group:
			selected_recipe = id
			break
	_show_category()


func _show_category() -> void:
	exploration_note.visible = selected_category == "exploration"
	var count := 0
	for id in recipe_buttons:
		recipe_buttons[id].visible = _recipe_group(id) == selected_category
		if recipe_buttons[id].visible:
			count += 1
	_recipe_grid.custom_minimum_size = Vector2(376, maxf(94, ceili(count / 4.0) * 102 - 8))
	recipe_scroll.scroll_vertical = 0
	for group in category_buttons:
		category_buttons[group].add_theme_stylebox_override("normal", UI.box("slot_selected" if group == selected_category else "button"))


func _recipe_texture(recipe: Dictionary) -> Texture2D:
	if not str(recipe.result).is_empty():
		return Art.item_icon(str(recipe.result))
	return Art.texture("floor" if recipe.structure == "foundation" else str(recipe.structure))

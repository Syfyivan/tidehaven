extends Control

signal bag_requested
signal crafting_requested
signal menu_requested
signal tool_selected(tool: String)
signal item_used(index: int)
signal anchor_requested
signal map_requested
const Rooms = preload("res://scripts/rooms.gd")
const Farming = preload("res://scripts/farming.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const UI = preload("res://scripts/ui_style.gd")
const Art = preload("res://scripts/art_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Navigation = preload("res://scripts/navigation.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
var bars: Dictionary = {}
var vitals: Panel
var clock_label: Label
var partner_label: Label
var toast: Label
var toast_box: Panel
var prompt: Label
var prompt_box: Panel
var prompt_key: Label
var prompt_more: Label
var hint: Label
var placement_reason := ""
var build_box: Panel
var build_reason: Label
var tool_buttons: Dictionary = {}
var tool_icons: Dictionary = {}
var slots: Array = []
var hover_label: Label
var oxygen_box: Panel
var oxygen_label: Label
var calendar: Panel
var bag_button: Button
var crafting_button: Button
var menu_button: Button
var toolbar: Panel
var hook_icon: TextureRect
var fins_icon: TextureRect
var quick_buttons: Array = []
var navigation_label: Label
var anchor_button: Button
var weather_label: Label
var map_button: Button
var farm_seed := "seed"
var held_index := -1
var danger_label: Label

func _ready() -> void:
	size = Vector2(1280, 800)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals = UI.panel(self, Rect2(28, 26, 190, 88), "paper")
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in 3:
		var key: String = ["stamina", "hunger", "thirst"][index]
		UI.icon(vitals, UI.symbol(["energy", "food", "drop"][index]), Rect2(14, 12 + index * 22, 16, 16))
		var bar := ColorRect.new()
		bar.position = Vector2(44, 16 + index * 22)
		bar.size = Vector2(128, 10)
		bar.color = Color("c9b28a")
		bar.mouse_filter = Control.MOUSE_FILTER_PASS
		var fill := ColorRect.new()
		fill.size = bar.size
		fill.color = [Color("c49a45"), Color("c58258"), Color("528e8a")][index]
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(fill)
		vitals.add_child(bar)
		bars[key] = {"track": bar, "fill": fill}
	oxygen_box = UI.panel(self, Rect2(28, 24, 152, 48), "paper")
	oxygen_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oxygen_label = UI.label(oxygen_box, "", Rect2(16, 12, 108, 24), 16, UI.INK)
	fins_icon = UI.icon(oxygen_box, Art.item_icon("fins"), Rect2(116, 12, 24, 24))
	danger_label = UI.label(self,"",Rect2(28,125,530,25),14,UI.PAPER)
	danger_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_label.add_theme_color_override("font_shadow_color",Color("18394f"))
	danger_label.add_theme_constant_override("shadow_offset_y",2)
	calendar = UI.panel(self, Rect2(1092, 26, 160, 68), "paper")
	calendar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.icon(calendar, UI.symbol("sun"), Rect2(16, 22, 24, 24))
	clock_label = UI.label(calendar, "", Rect2(54, 8, 98, 52), 17, UI.INK)
	partner_label = UI.label(self, "", Rect2(1006, 143, 246, 28), 14, UI.PAPER)
	partner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	partner_label.add_theme_color_override("font_shadow_color", Color("254e52"))
	partner_label.add_theme_constant_override("shadow_offset_y", 2)
	bag_button = _icon_button("bag", Rect2(1120, 98, 38, 36), "背包 · B", func(): bag_requested.emit())
	crafting_button = _icon_button("hammer", Rect2(1167, 98, 38, 36), "制作 · C", func(): crafting_requested.emit())
	menu_button = _icon_button("gear", Rect2(1214, 98, 38, 36), "菜单 · Esc", func(): menu_requested.emit())
	map_button = UI.button(self, "海图 M", Rect2(1017, 98, 91, 36), func(): map_requested.emit())
	map_button.add_theme_font_size_override("font_size", 15)
	navigation_label = UI.label(self, "", Rect2(1000, 179, 252, 45), 14, UI.PAPER)
	navigation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	navigation_label.add_theme_color_override("font_shadow_color", Color("254e52"))
	navigation_label.add_theme_constant_override("shadow_offset_y", 2)
	anchor_button = UI.button(self, "抛锚 · G", Rect2(1120, 229, 132, 34), func(): anchor_requested.emit())
	anchor_button.add_theme_font_size_override("font_size", 15)
	weather_label = UI.label(self, "", Rect2(1000, 270, 252, 24), 13, UI.PAPER)
	weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast_box = UI.panel(self, Rect2(28, 621, 328, 56), "paper")
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast = UI.label(toast_box, "", Rect2(16, 10, 296, 44), 15, UI.INK)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.mouse_filter = Control.MOUSE_FILTER_PASS
	prompt_box = UI.panel(self, Rect2(0, 0, 180, 32), "hud")
	prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_background := UI.panel(prompt_box, Rect2(6, 5, 23, 22), "slot")
	key_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_key = UI.label(key_background, "E", Rect2(0, 0, 23, 22), 14, UI.INK)
	prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt = UI.label(prompt_box, "", Rect2(38, 5, 222, 25), 15, UI.PAPER)
	prompt_more = UI.label(prompt_box, "", Rect2(0, 35, 240, 22), 12, UI.PAPER)
	prompt_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_more.add_theme_color_override("font_shadow_color", Color("21494d"))
	prompt_more.add_theme_constant_override("shadow_offset_y", 2)
	build_box = UI.panel(self, Rect2(400, 615, 588, 62), "paper")
	build_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_reason = UI.label(build_box, "", Rect2(16, 8, 556, 26), 16, UI.INK)
	UI.label(build_box, "左键 / O 放置  ·  右键 / P 取消", Rect2(16, 34, 556, 22), 13, UI.INK)
	build_box.hide()
	hint = UI.label(self, "", Rect2(28, 691, 1224, 24), 13, UI.PAPER)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint.add_theme_color_override("font_shadow_color", Color("21494d"))
	hint.add_theme_constant_override("shadow_offset_y", 2)
	toolbar = UI.panel(self, Rect2(367, 720, 546, 68), "wood")
	toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in 4 + Inventory.BAG_SIZE:
		var button := UI.button(self, "", Rect2(382 + index * 58, 727, 54, 51), func(): _quick_click(index))
		button.add_theme_stylebox_override("normal", UI.box("quick"))
		button.add_theme_stylebox_override("hover", UI.box("quick_hover"))
		button.add_theme_stylebox_override("pressed", UI.box("quick_selected"))
		button.add_theme_stylebox_override("disabled", UI.box("disabled"))
		quick_buttons.append(button)
		var icon := UI.icon(button, null, Rect2(9, 4, 34, 34))
		var count := UI.label(button, "", Rect2(5, 32, 43, 17), 12, UI.INK)
		count.add_theme_color_override("font_outline_color", UI.PAPER)
		count.add_theme_constant_override("outline_size", 3)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if index < 4:
			var tool: String = ["hook", "rod", "paddle", "harpoon"][index]
			icon.texture = Art.item_icon(tool)
			if tool == "hook":
				hook_icon = icon
			UI.label(button, "H" if index == 0 else "", Rect2(4, 2, 17, 16), 10, UI.MUTED)
			tool_buttons[tool] = button
			tool_icons[tool] = icon
		else:
			UI.label(button, ["1","2","3","4","5","6","7","8","9","0","-","="][index-4], Rect2(4,2,17,16),10,UI.MUTED)
			slots.append({"button": button, "icon": icon, "count": count})
	hover_label = UI.label(self, "", Rect2(0, 0, 240, 28), 14, UI.PAPER)
	hover_label.add_theme_color_override("font_shadow_color", Color("21494d"))
	hover_label.add_theme_constant_override("shadow_offset_y", 2)
	for floating_text: Label in [navigation_label, weather_label, partner_label, prompt_more, hint, hover_label]:
		floating_text.add_theme_color_override("font_outline_color", Color("3d4034"))
		floating_text.add_theme_constant_override("outline_size", 2)
	_layout_toolbar(false)

func _layout_toolbar(island: bool) -> void:
	# The island shows actual bag slots, not a second row of farming commands.
	var count := 1 + Inventory.BAG_SIZE
	var width := count * 58.0 + 20.0
	var left := (1280.0 - width) * 0.5
	toolbar.position = Vector2(left, 720)
	toolbar.size = Vector2(width, 68)
	for index in quick_buttons.size():
		var button: Button = quick_buttons[index]
		button.visible = index == 0 or index >= 4
		var column := index - 3 if index >= 4 else 0
		button.position = Vector2(left + 12 + column * 58, 728) if button.visible else Vector2(0, 728)

func _quick_click(index: int) -> void:
	if index < 4:
		tool_selected.emit(["hook", "rod", "paddle", "harpoon"][index])
	else:
		item_used.emit(index - 4)

func _icon_button(key: String, rect: Rect2, tip: String, callback: Callable) -> Button:
	var button := UI.button(self, "", rect, callback)
	button.tooltip_text = tip
	UI.icon(button, UI.symbol(key), Rect2(11, 9, 16, 16))
	return button

func refresh(data: Dictionary, local_slot: String, options: Array, selected: int, tool: String, toast_time: float, placement_recipe: String, hovered: String) -> void:
	var player: Dictionary = data.players[local_slot]
	var nav: Dictionary = data.navigation
	var velocity := Navigation.velocity(nav)
	var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var arrow: String = arrows[posmod(roundi(velocity.angle() / (PI / 4)), 8)]
	navigation_label.text = "已抛锚 · 可下潜" if bool(nav.anchored) else ("划桨前进 " if Vector2(float(nav.push_x), float(nav.push_y)).length() > 3 else "随流漂行 ") + arrow
	var target_id:String=data.chart.destination if Archipelago.ISLANDS.has(data.chart.destination) else Archipelago.HOME_ID
	var island_offset: Vector2 = Archipelago.island_position(data.chart,target_id) - Vector2(float(nav.x), float(nav.y))
	var island_arrow: String = arrows[posmod(roundi(island_offset.angle() / (PI / 4)), 8)]
	if Inventory.count(player.bag, "compass") > 0:
		navigation_label.text += "\n%s %s %d 米" % [Archipelago.ISLANDS[target_id].name,island_arrow, ceili(island_offset.length() / 16.0)]
	else:
		navigation_label.text += "\n附近海域 · M"
	if bool(nav.get("moored", false)):
		navigation_label.text = "已系泊码头 · 可登岸 / 下潜"
	if player.area == "island":
		navigation_label.text = "潮芽岛 · %s\nM 岛内分区图 · 西岸码头返筏" % IslandMap.region(Vector2(player.x, player.y)).name
	elif player.area == "water":
		navigation_label.text = "浅海 · 珊瑚湾\n左上浮标处返航"
	elif player.area == "room":
		navigation_label.text = "M 查看本层地图\n沿入口原路返回"
	anchor_button.text = "收锚出发 · G" if bool(nav.anchored) else "抛锚停船 · G"
	weather_label.visible = player.area == "deck"
	var weather = preload("res://scripts/salvage_hook.gd")
	var wind: Vector2 = weather.wind(float(data.elapsed))
	weather_label.text = ("微风" if wind.length() < 6 else "阵风") + arrows[posmod(roundi(wind.angle() / (PI / 4)), 8)] + (" · 轻浪" if weather.wave(float(data.elapsed)) < 0.55 else " · 涌浪")
	anchor_button.visible = player.area == "deck"
	anchor_button.disabled = bool(nav.get("moored", false))
	if anchor_button.disabled:
		anchor_button.text = "已系泊码头"
	anchor_button.tooltip_text = "所有人返航后收回背包；需留出空间" if bool(nav.anchored) else "C 手工制作简易锚后，随身携带并按 G 抛锚"
	# The buoy stays visible in the water scene.
	vitals.position = Vector2(198, 26) if Rooms.underwater(player) else Vector2(28, 26)
	for key in bars:
		bars[key].fill.size.x = 128 * clampf(float(player.get(key, 100)) / 100.0, 0, 1)
		bars[key].track.tooltip_text = "%s %d / 100" % [{"stamina": "体力", "hunger": "饱食", "thirst": "饮水"}[key], int(player.get(key, 100))]
	oxygen_box.visible = Rooms.underwater(player)
	oxygen_box.position = Vector2(28, 24)
	oxygen_label.text = "氧气  %d" % int(player.oxygen)
	fins_icon.visible = Inventory.count(player.bag, "fins") > 0
	oxygen_box.tooltip_text = "脚蹼已生效 · 游泳速度提升 30%" if fins_icon.visible else "返回浮标处上浮"
	oxygen_label.add_theme_color_override("font_color", Color("a53c2e") if float(player.oxygen) < 25 else UI.INK)
	danger_label.visible = player.area == "water" or float(player.get("dive_status",{}).get("recovery",0)) > 0.0
	if player.area == "water":
		var protected: bool = preload("res://scripts/sea_threats.gd").safe(Vector2(player.x,player.y))
		danger_label.text = "浅水安全 · 浮标旁可上浮" if protected else "深水有掠食者 · 避开冲刺线 · 鱼叉可击退"
		var danger_score := INF
		for enemy: Dictionary in data.get("threats",{}).values():
			if enemy.target == local_slot:
				var score := Vector2(enemy.x,enemy.y).distance_to(Vector2(player.x,player.y)) + (1000 if enemy.phase == "chase" else 0)
				if score < danger_score:
					danger_score=score
					danger_label.text = ("鲨鱼" if enemy.kind == "shark" else "海鳗") + ("蓄势！向冲刺线两侧游开" if enemy.phase == "windup" else "正在追击 · 鱼叉可击退")
		if float(player.stamina) <= 25: danger_label.text += " · 体力低，尽快返航"
	else:
		danger_label.text = "救援后恢复 %d 秒 · 休息或吃喝后再下潜" % ceili(float(player.get("dive_status",{}).get("recovery",0)))
	if player.area == "room":
		danger_label.visible = true
		danger_label.text = Rooms.room_name(player.room) + (" · 入口空气洞可补氧" if Rooms.underwater(player) else "")
	var minute := int(data.minute)
	clock_label.text = "%s %d 日\n%02d:%02d" % [Farming.SEASONS[Farming.season(int(data.day))], posmod(int(data.day) - 1, 28) + 1, minute / 60, minute % 60]
	calendar.tooltip_text = Farming.date_label(int(data.day))
	map_button.text = ("岛图 M" if str(player.room).begins_with("island_") else "洞图 M" if str(player.room).begins_with("sea_") or str(player.room).begins_with("mine_") else "室内 M") if player.area=="room" else "岛图 M" if player.area == "island" else "海图 M"
	_layout_toolbar(player.area == "island")
	var crop: Dictionary = Farming.CROPS.get(farm_seed, Farming.CROPS.seed)
	var other: Dictionary = data.players["guest" if local_slot == "host" else "host"]
	partner_label.text = str(other.name) + (" · "+Rooms.room_name(other.room) if other.area=="room" else str({"water": " · 水下", "island": " · 潮芽岛", "deck": " · 甲板"}.get(other.area, ""))) if other.online else ""
	toast_box.visible = toast_time > 0 and not toast.text.is_empty() and placement_recipe.is_empty()
	toast_box.modulate.a = clampf(toast_time, 0, 1)
	toast.tooltip_text = toast.text
	toast_box.size.y = maxf(44, toast.get_minimum_size().y + 22)
	toast_box.position.y = 677 - toast_box.size.y
	prompt_box.visible = not options.is_empty() and placement_recipe.is_empty() and player.get("activity", {}).is_empty()
	if not options.is_empty():
		var choice: Dictionary = options[clampi(selected, 0, options.size() - 1)]
		var title := str(choice.label).split(" · ")[0].replace("附近", "").replace("从筏边", "").replace("恢复体力", "")
		prompt.text = title
		var width := clampf(float(title.length()) * 15 + 52, 116, 290)
		prompt_box.size = Vector2(width, 32)
		prompt_key.text = "E" if tool != "hook" else "O"
		prompt_more.text = "右键 / P · 更多操作" if options.size() > 1 else "也可点击目标"
		prompt_more.size.x = width
		var at := Vector2(float(player.x) * 1.4 + 10, float(player.y) * 1.4 + 64)
		prompt_box.position = Vector2(clampf(at.x - width * 0.5, 20, 1260 - width), clampf(at.y, 130, 623))
	for key in tool_buttons:
		tool_buttons[key].add_theme_stylebox_override("normal", UI.box("quick_selected" if key == tool else "quick"))
		tool_buttons[key].add_theme_stylebox_override("hover", UI.box("quick_selected" if key == tool else "quick_hover"))
		tool_buttons[key].disabled = (player.area == "water" and key in ["rod", "paddle"]) or (player.area != "water" and key == "harpoon")
		tool_icons[key].modulate.a = 0.35 if tool_buttons[key].disabled else 1.0
	var upgraded_hook := Inventory.count(player.bag, "reinforced_hook") > 0
	hook_icon.texture = Art.item_icon("reinforced_hook") if upgraded_hook else Art.item_icon("hook")
	tool_buttons.hook.tooltip_text = "强化打捞钩 · H\n距离更远，收钩更快 · 沿途可带回多件" if upgraded_hook else "打捞钩 · H\n朝海面方向抛钩 · 沿途可带回多件，不锁定物资"
	tool_buttons.rod.tooltip_text = "钓竿 · 点背包格选持\n筏边点击水面抛竿" if Inventory.count(player.bag, "rod") > 0 else "钓竿 · C 制作后可用"
	tool_buttons.paddle.tooltip_text = "船桨 · 点背包格选持\n点击海面方向划桨 · 2 体力" if Inventory.count(player.bag, "paddle") > 0 else "船桨 · C 用木板、塑料、绳子制作"
	tool_buttons.harpoon.tooltip_text = "鱼叉 · 点背包格选持\n水下朝鼠标方向出手 · C 制作后携带"
	if player.area == "island":
		tool_buttons.hook.tooltip_text = "收起手持物品 · H\n采集 / 收获 / 与居民交谈"
	var selected_item := Farming.held_item(tool, farm_seed)
	var selection_shown := false
	for index in slots.size():
		var stack: Dictionary = player.bag[index]
		var item := str(stack.get("item", ""))
		slots[index].icon.texture = Art.item_icon(item) if not stack.is_empty() else null
		slots[index].count.text = ("%d/20" % int(player.get("can_water", 0))) if item == "watering_can" else (str(stack.count) if not stack.is_empty() else "")
		var selected_stack: bool = index == held_index and not item.is_empty()
		selection_shown = selection_shown or selected_stack
		slots[index].button.add_theme_stylebox_override("normal", UI.box("quick_selected" if selected_stack else "quick"))
		slots[index].button.add_theme_stylebox_override("hover", UI.box("quick_selected" if selected_stack else "quick_hover"))
		slots[index].button.tooltip_text = ("%s ×%d" % [Inventory.ITEM_NAMES.get(item, ""), int(stack.count)]) if not stack.is_empty() else ""
		if item == "watering_can":
			slots[index].button.tooltip_text += " · 选中后点击土地浇水；池边P装水"
		elif item == "hoe":
			slots[index].button.tooltip_text += " · 选中后点击空地开垦"
		elif item == "canopy":
			slots[index].button.tooltip_text += " · 选中后点击一格耕地搭建"
		elif Farming.CROPS.has(item):
			var seed_info: Dictionary = Farming.CROPS[item]
			var seasons := PackedStringArray()
			for season_index in seed_info.seasons:
				seasons.append(Farming.SEASONS[season_index])
			slots[index].button.tooltip_text += " · 选中后点击耕地播种\n%s季 · 浇水过夜%d天成熟" % ["、".join(seasons), seed_info.days]
	hint.text = ""
	if not placement_recipe.is_empty():
		hint.text = "搬移 · 左键放置 · 右键取消" if placement_recipe == "relocate" else "左键放置  ·  右键取消"
	else:
		hint.text = "WASD 移动 · 左键 / O 操作 · 右键 / P 更多 · M 地图 · J 手记"
	if not player.get("hook", {}).is_empty():
		var hook: Dictionary = player.hook
		var cargo: Array = hook.get("cargo", [])
		hint.text = "右键 / P 收绳 · 沿途可带回多件"
		if not cargo.is_empty():
			hint.text = "已挂 %d 件 · 沿途可多捞 · 右键 / P 收绳" % cargo.size()
		if str(hook.phase) == "reel":
			hint.text = "收绳中 · 已挂 %d 件 · 沿途可多捞" % cargo.size()
	if tool == "paddle" and player.area == "deck":
		hint.text = "先起锚 · 点击海面方向划桨 · G 抛锚" if bool(nav.anchored) else "点击海面方向划桨 · 每划 2 体力 · G 抛锚"
	if player.area == "water":
		hint.text = "点格子选鱼叉 · H收起 · 左键 / O 操作 · 右键 / P 取消"
		if tool == "harpoon":
			hint.text = "鱼叉：朝鼠标方向左键 / O 出手 · H收起"
	if player.area == "island":
		hint.text = "点选背包中的工具或种子，再点击地块 · H收起 · 水壶 %d/20" % int(player.get("can_water", 0))
		if tool in ["till", "plant", "water", "cover"]:
			hint.text = "%s · 点击身边一格 · 右键收起 / 菜单 · 水壶 %d/20" % [{"till": "手持锄头", "plant": "手持%s种子 · %d天成熟" % [crop.name, crop.days], "water": "手持水壶 / 池边P装水", "cover": "手持暖棚套件"}[tool], int(player.get("can_water", 0))]
	if player.get("hook", {}).is_empty() and held_index >= 0 and held_index < player.bag.size() and not player.bag[held_index].is_empty():
		hint.text = "手持：%s · 左键/O使用 · 点其他格切换 · B背包" % Inventory.ITEM_NAMES.get(str(player.bag[held_index].item), "")
	if float(player.get("thirst", 100)) < 15:
		hint.text = "口渴了，喝些淡水。"
	elif float(player.get("hunger", 100)) < 15:
		hint.text = "肚子饿了，吃些熟食。"
	build_box.visible = not placement_recipe.is_empty()
	if build_box.visible:
		build_reason.text = "这里可以放置" if placement_reason.is_empty() else placement_reason
		hint.text = ""
	hover_label.text = ""
	hover_label.position = get_global_mouse_position() + Vector2(16, -24)


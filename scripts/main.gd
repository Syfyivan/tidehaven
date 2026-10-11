extends Node2D

const WorldState = preload("res://scripts/world_state.gd")
const WorldView = preload("res://scripts/world_view.gd")
const Inventory = preload("res://scripts/inventory.gd")
const InventoryPanel = preload("res://scripts/inventory_panel.gd")
const GameHUD = preload("res://scripts/game_hud.gd")
const CraftingPanel = preload("res://scripts/crafting_panel.gd")
const ChartPanel = preload("res://scripts/chart_panel.gd")
const IslandAtlas = preload("res://scripts/island_atlas.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const Farming = preload("res://scripts/farming.gd")
const IslandTown = preload("res://scripts/island_town.gd")
const ContextActions = preload("res://scripts/context_actions.gd")
const Recipes = preload("res://scripts/recipes.gd")
const UI = preload("res://scripts/ui_style.gd")
const PORT := 24872
const INK := Color("193c48")
const PAPER := Color("f0e6cd")
const MUTED := Color("a8c8c6")
const WORLD_SIZE := Vector2(900, 560)
const UI_SIZE := Vector2(1280, 800)

var world = WorldState.new()
var mode := "menu"
var local_slot := "host"
var remote_peer := 0
var received: Dictionary = {}
var view: Node2D
var ui: Control
var overlay: Control
var pause_overlay: Control
var inventory_ui: Control
var hud: Control
var crafting_ui: Control
var chart_ui: Control
var island_atlas: Control
var active_seed := "seed"
var dialogue_ui: Control
var pending_talk := ""
var context_ui: Control
var status: Label
var selected_option := 0
var active_tool := "hook"
var placement_recipe := ""
var relocation: Dictionary = {}
var hovered_drift := ""
var pointer_position := Vector2.ZERO
var last_notice_id := 0
var nickname: LineEdit
var address: LineEdit
var menu_status: Label
var new_game_button: Button
var continue_button: Button
var return_title_button: Button
var room_pause_button: Button
var menu_panel: Panel
var pause_panel: Panel
var menu_actions: Control
var coop_actions: Control
var pause_note: Label
var font: SystemFont
var pause_open := false
var room_paused := false
var save_path := "user://world_v10.json"
var net_clock := 0.0
var hud_clock := 0.0
var input_clock := 0.0
var autosave_clock := 0.0
var toast_clock := 0.0
var connecting_since := 0
var last_action_ms := {}
var current_options: Array = []
var options_signature := ""
var cli := {}
var automation_input := Vector2.ZERO
var automated := false
var screenshot_pending := false
var save_error := ""
var restored_backup := false
var _window_shades: Array[ColorRect] = []

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--"):
			var pair := argument.substr(2).split("=", true, 1)
			cli[pair[0]] = pair[1] if pair.size() > 1 else "true"
	if cli.has("save-path"):
		save_path = str(cli["save-path"])
	automated = cli.has("test-role") or cli.has("playthrough") or cli.has("island-playthrough") or cli.has("treasure-probe") or cli.has("ui-gallery") or cli.has("progression-net") or cli.has("skill-playthrough")
	if automated and not cli.has("save-path"):
		push_error("Tests require an isolated --save-path")
		get_tree().quit(2)
		return
	world.join("host", "旅人")
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	view = WorldView.new()
	add_child(view)
	_build_ui()
	get_viewport().size_changed.connect(_layout_viewport)
	_layout_viewport()
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	get_tree().auto_accept_quit = false
	_update_hud()
	if cli.has("ui-gallery"):
		var gallery = load("res://tests/ui_gallery.gd").new()
		add_child(gallery)
	elif cli.has("treasure-probe"):
		var driver = load("res://tests/treasure_ui_probe.gd").new()
		driver.name = "TreasureProbe"
		add_child(driver)
	elif cli.has("skill-playthrough"):
		var driver = load("res://tests/skill_playthrough.gd").new()
		driver.name = "SkillPlaythrough"
		add_child(driver)
	elif cli.has("island-playthrough"):
		var driver = load("res://tests/island_playthrough.gd").new()
		driver.name = "IslandPlaythrough"
		add_child(driver)
	elif cli.has("playthrough"):
		var driver = load("res://tests/playthrough.gd").new()
		driver.name = "Playthrough"
		add_child(driver)
	elif cli.has("town-net"):
		var driver = load("res://tests/town_network_probe.gd").new()
		add_child(driver)
	elif cli.has("island-net"):
		var driver = load("res://tests/island_network_probe.gd").new()
		driver.name = "IslandNetworkProbe"
		add_child(driver)
	elif cli.has("skill-net"):
		var driver = load("res://tests/skill_network_probe.gd").new()
		add_child(driver)
	elif cli.has("progression-net"):
		var driver = load("res://tests/progression_network_probe.gd").new()
		driver.name = "ProgressionNetworkProbe"
		add_child(driver)
	elif automated:
		var driver = load("res://tests/network_probe.gd").new()
		driver.name = "NetworkProbe"
		add_child(driver)
	elif cli.has("capture"):
		if str(cli.get("area", "deck")) != "menu":
			_start("solo", false)
		if str(cli.get("area", "deck")) == "water":
			world.data.players.host.area = "water"
			world.data.players.host.x = 160.0
			world.data.players.host.y = 180.0
		screenshot_pending = true
	elif cli.has("host"):
		_start("host", bool(cli.get("continue", "false") == "true"))
	elif cli.has("join"):
		address.text = str(cli["join"])
		_join()

## The viewport can expand beyond the design aspect, while both layers retain
## uniform scales. Extra space belongs to the ocean, never an outer frame.
static func viewport_layout(available: Vector2) -> Dictionary:
	var safe_size := Vector2(maxf(1, available.x), maxf(1, available.y))
	var world_scale: float = minf(safe_size.x / WORLD_SIZE.x, safe_size.y / WORLD_SIZE.y)
	var ui_scale: float = minf(safe_size.x / UI_SIZE.x, safe_size.y / UI_SIZE.y)
	var world_position: Vector2 = (safe_size - WORLD_SIZE * world_scale) * 0.5
	var ui_position: Vector2 = (safe_size - UI_SIZE * ui_scale) * 0.5
	return {
		"world_scale": world_scale, "world_position": world_position,
		"ui_scale": ui_scale, "ui_position": ui_position,
		"canvas_bounds": Rect2(-world_position / world_scale, safe_size / world_scale),
		"shade_bounds": Rect2(-ui_position / ui_scale, safe_size / ui_scale),
	}

func _layout_viewport() -> void:
	if not is_instance_valid(view) or not is_instance_valid(ui):
		return
	var layout: Dictionary = viewport_layout(get_viewport_rect().size)
	view.position = layout.world_position
	view.scale = Vector2.ONE * float(layout.world_scale)
	view.canvas_bounds = layout.canvas_bounds
	ui.position = layout.ui_position
	ui.scale = Vector2.ONE * float(layout.ui_scale)
	ui.size = UI_SIZE
	var shade_bounds: Rect2 = layout.shade_bounds
	for shade in _window_shades:
		shade.position = shade_bounds.position
		shade.size = shade_bounds.size
	view.queue_redraw()
	_update_hud()

func _register_window_shades(parent: Control) -> void:
	for child in parent.get_children():
		if child is ColorRect and child.size.is_equal_approx(UI_SIZE):
			_window_shades.append(child)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.size = UI_SIZE
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	theme.set_stylebox("panel", "TooltipPanel", UI.box("dark"))
	theme.set_color("font_color", "TooltipLabel", UI.PAPER)
	theme.set_font_size("font_size", "TooltipLabel", 15)
	ui.theme = theme
	ui.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.add_child(ui)
	hud = GameHUD.new()
	ui.add_child(hud)
	status = hud.toast
	hud.bag_requested.connect(_toggle_inventory)
	hud.crafting_requested.connect(_toggle_crafting)
	hud.menu_requested.connect(_toggle_pause)
	hud.tool_selected.connect(func(tool: String): active_tool = tool)
	hud.item_used.connect(_use_hotbar)
	hud.anchor_requested.connect(_toggle_anchor)
	hud.map_requested.connect(_toggle_chart)
	inventory_ui = InventoryPanel.new()
	ui.add_child(inventory_ui)
	inventory_ui.command.connect(perform)
	inventory_ui.close_requested.connect(_toggle_inventory)
	crafting_ui = CraftingPanel.new()
	ui.add_child(crafting_ui)
	crafting_ui.craft_requested.connect(_choose_recipe)
	crafting_ui.close_requested.connect(_toggle_crafting)
	chart_ui = ChartPanel.new()
	ui.add_child(chart_ui)
	chart_ui.close_requested.connect(_toggle_chart)
	chart_ui.destination_selected.connect(func(id: String): perform("set_destination", {"id": id}))
	island_atlas = IslandAtlas.new()
	ui.add_child(island_atlas)
	island_atlas.closed.connect(func(): island_atlas.hide())
	island_atlas.sea_requested.connect(func(): island_atlas.hide(); chart_ui.show(); _update_hud())
	context_ui = ContextActions.new()
	ui.add_child(context_ui)
	context_ui.chosen.connect(func(option: Dictionary): perform(str(option.action), option.get("args", {})))
	dialogue_ui = preload("res://scripts/town_dialogue.gd").new()
	ui.add_child(dialogue_ui)
	_build_main_menu()
	_build_pause_menu()
	_register_window_shades(inventory_ui)
	_register_window_shades(inventory_ui.discard_dialog)
	_register_window_shades(crafting_ui)
	_register_window_shades(chart_ui)
	_register_window_shades(island_atlas)

func _build_main_menu() -> void:
	overlay = _shade(ui)
	var title := UI.label(overlay, "潮间小屋", Rect2(88, 107, 500, 80), 54, UI.PAPER)
	title.add_theme_color_override("font_outline_color", Color("28545a"))
	title.add_theme_constant_override("outline_size", 6)
	UI.label(overlay, "T I D E H A V E N", Rect2(92, 191, 380, 33), 18, Color("d0dfc5"))
	UI.label(overlay, "单人游戏  /  双人联机", Rect2(94, 236, 370, 28), 17, Color("e6e4c7"))
	menu_panel = UI.panel(overlay, Rect2(810, 165, 360, 470))
	var panel := menu_panel
	UI.label(panel, "开始游戏", Rect2(30, 26, 295, 38), 28)
	UI.label(panel, "玩家名字", Rect2(30, 83, 280, 25), 15, UI.MUTED)
	nickname = _text_input(panel, "旅人", Vector2(28, 113), Vector2(304, 42))
	nickname.max_length = 16
	menu_actions = Control.new()
	menu_actions.position = Vector2(28, 179)
	menu_actions.size = Vector2(304, 258)
	panel.add_child(menu_actions)
	continue_button = UI.button(menu_actions, "继续游戏", Rect2(0, 0, 304, 52), func(): _start("solo", true), true)
	new_game_button = UI.button(menu_actions, "新游戏", Rect2(0, 65, 304, 48), func(): _confirm_new("solo"))
	UI.button(menu_actions, "联机游戏", Rect2(0, 126, 304, 48), func():
		menu_actions.hide()
		coop_actions.show()
		menu_status.text = "同一网络的朋友可以一起登船。")
	UI.button(menu_actions, "退出游戏", Rect2(0, 211, 304, 44), func(): get_tree().quit())
	coop_actions = Control.new()
	coop_actions.position = Vector2(28, 179)
	coop_actions.size = Vector2(304, 279)
	panel.add_child(coop_actions)
	UI.button(coop_actions, "创建房间", Rect2(0, 0, 304, 48), func(): _start("host", true), true)
	UI.label(coop_actions, "房主地址", Rect2(3, 69, 285, 26), 15, UI.MUTED)
	address = _text_input(coop_actions, "127.0.0.1", Vector2(0, 98), Vector2(304, 42))
	address.max_length = 64
	UI.button(coop_actions, "加入房间", Rect2(0, 151, 304, 46), _join)
	UI.button(coop_actions, "返回", Rect2(0, 215, 304, 40), func():
		coop_actions.hide()
		menu_actions.show()
		menu_status.text = "")
	coop_actions.hide()
	menu_status = UI.label(panel, "", Rect2(30, 465, 300, 63), 14, UI.MUTED)
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(overlay, "0.7", Rect2(1180, 754, 77, 25), 14, Color("c3d8c8"))

func _build_pause_menu() -> void:
	pause_overlay = _shade(ui)
	pause_overlay.hide()
	pause_panel = UI.panel(pause_overlay, Rect2(446, 218, 388, 364))
	var panel := pause_panel
	UI.icon(panel, UI.symbol("gear"), Rect2(30, 32, 30, 30))
	UI.label(panel, "游戏菜单", Rect2(75, 26, 250, 43), 28)
	pause_note = UI.label(panel, "", Rect2(30, 89, 328, 50), 16, UI.MUTED)
	pause_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(panel, "继续游戏", Rect2(28, 153, 332, 49), _toggle_pause, true)
	UI.button(panel, "保存世界", Rect2(28, 215, 332, 45), func():
		if mode == "client":
			pause_note.text = "共同世界由房主保存。"
		else:
			pause_note.text = "世界已保存。" if _persist() else "保存失败：" + save_error
		_toast(pause_note.text))
	room_pause_button = UI.button(panel, "暂停房间", Rect2(28, 272, 332, 43), func():
		if mode == "host":
			room_paused = not room_paused
			pause_note.text = "房间已暂停。" if room_paused else "伙伴仍在行动，时间继续流动。"
			room_pause_button.text = "继续房间" if room_paused else "暂停房间"
			_toast("房间已暂停" if room_paused else "房间继续运行"))
	return_title_button = UI.button(panel, "保存并返回标题", Rect2(28, 284, 332, 48), _return_title)

func _panel(parent: Node, rect: Rect2, _color: Color) -> Panel:
	return UI.panel(parent, rect)

func _shade(parent: Node) -> Control:
	var layer := Control.new()
	layer.size = UI_SIZE
	parent.add_child(layer)
	var shade := ColorRect.new()
	shade.size = UI_SIZE
	shade.color = UI.SHADE
	layer.add_child(shade)
	_window_shades.append(shade)
	return layer

func _label(parent: Node, value: String, pos: Vector2, box: Vector2, point_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = box
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _text_input(parent: Node, value: String, pos: Vector2, box: Vector2) -> LineEdit:
	var input := LineEdit.new()
	input.text = value
	input.position = pos
	input.size = box
	input.add_theme_stylebox_override("normal", UI.box("slot"))
	input.add_theme_stylebox_override("focus", UI.box("slot_selected"))
	input.add_theme_color_override("font_color", UI.INK)
	input.add_theme_color_override("caret_color", UI.INK)
	input.add_theme_color_override("selection_color", Color("9bb798"))
	parent.add_child(input)
	return input

func _button(parent: Node, value: String, pos: Vector2, box: Vector2, callback: Callable) -> Button:
	return UI.button(parent, value, Rect2(pos, box), callback)

func _confirm_new(next_mode: String) -> void:
	if not FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path + ".bak"):
		_start(next_mode, false)
		return
	var confirm := ConfirmationDialog.new()
	confirm.title = "开始新的海上生活"
	confirm.dialog_text = "当前世界会先另存为备份，再开始新世界。"
	confirm.ok_button_text = "备份并开始"
	confirm.cancel_button_text = "取消"
	confirm.confirmed.connect(func():
		if not _backup_before_new():
			menu_status.text = "无法备份旧世界，已取消创建。"
			return
		_start(next_mode, false))
	ui.add_child(confirm)
	confirm.popup_centered(Vector2i(430, 160))

func _backup_before_new() -> bool:
	var absolute := ProjectSettings.globalize_path(save_path)
	var archive := absolute + ".before-new-" + str(Time.get_unix_time_from_system())
	# Either file may be the only valid copy. Preserve both before replacing a world.
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(absolute + suffix):
			if DirAccess.copy_absolute(absolute + suffix, archive + suffix + ".json") != OK:
				return false
	return true

func _start(next_mode: String, load_existing: bool) -> bool:
	_reset_network()
	world = WorldState.new()
	restored_backup = false
	if load_existing and _has_saved_world():
		if not _load_saved():
			menu_status.text = "存档未通过检查，已保留原文件。" + save_error
			return false
	mode = next_mode
	local_slot = "host"
	world.join("host", nickname.text.strip_edges().left(16) if not nickname.text.strip_edges().is_empty() else "旅人")
	if mode == "host":
		var peer := ENetMultiplayerPeer.new()
		var error := peer.create_server(int(cli.get("port", PORT)), 1)
		if error != OK:
			mode = "menu"
			menu_status.text = "房间创建失败，端口可能被占用：" + str(error)
			return false
		multiplayer.multiplayer_peer = peer
	overlay.hide()
	pause_overlay.hide()
	pause_open = false
	inventory_ui.hide()
	inventory_ui.clear_selection()
	crafting_ui.hide()
	placement_recipe = ""
	relocation = {}
	last_notice_id = int(world.data.players.host.get("notice_id", 0))
	room_paused = false
	options_signature = ""
	_toast("回到岛上 · 点选底栏的工具或种子，再点击地块。" if world.data.players.host.area == "island" else "朝海面抛钩，沿途碰到的物资都能带回。")
	if not world.migration_notice.is_empty():
		_toast(world.migration_notice)
	return true

func _join() -> void:
	_reset_network()
	var target := address.text.strip_edges()
	if target.is_empty():
		menu_status.text = "请填写房主 IP。"
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(target, int(cli.get("port", PORT)))
	if error != OK:
		menu_status.text = "连接地址无效：" + str(error)
		return
	mode = "connecting"
	local_slot = "guest"
	multiplayer.multiplayer_peer = peer
	connecting_since = Time.get_ticks_msec()
	menu_status.text = "正在连接 " + target + "…"

func _reset_network() -> void:
	if is_instance_valid(dialogue_ui):
		dialogue_ui.hide()
	pending_talk = ""
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	remote_peer = 0
	received = {}
	last_action_ms.clear()
	connecting_since = 0

func _peer_connected(id: int) -> void:
	if mode == "host":
		remote_peer = id

func _connected() -> void:
	if mode != "connecting":
		return
	mode = "client"
	connecting_since = 0
	register_guest.rpc_id(1, nickname.text.strip_edges().left(16))
	menu_status.text = "已连接，正在接收世界…"

func _peer_disconnected(id: int) -> void:
	if mode == "host" and id == remote_peer:
		world.leave("guest")
		remote_peer = 0
		if _persist():
			_toast("伙伴已离开，物品已保留。你可以继续游玩。")
		else:
			_toast("伙伴已离开，但写入存档失败：" + save_error)

func _connection_failed() -> void:
	_reset_network()
	mode = "menu"
	overlay.show()
	menu_status.text = "未能连接。请确认房主已开房、地址和网络可达。"

func _server_disconnected() -> void:
	_reset_network()
	mode = "menu"
	pause_open = false
	pause_overlay.hide()
	inventory_ui.hide()
	crafting_ui.hide()
	placement_recipe = ""
	relocation = {}
	overlay.show()
	menu_status.text = "房主已离开。共同世界由房主保存，可重新加入。"

@rpc("any_peer", "call_remote", "reliable")
func register_guest(display_name: String) -> void:
	if mode != "host" or multiplayer.get_remote_sender_id() != remote_peer:
		return
	world.join("guest", display_name.left(16) if not display_name.is_empty() else "伙伴")
	initial_world.rpc_id(remote_peer, world.snapshot())
	_toast("伙伴登船了！现在可以自由分工。")

@rpc("authority", "call_remote", "reliable")
func initial_world(snapshot: Dictionary) -> void:
	if mode != "client":
		return
	received = snapshot
	overlay.hide()
	last_notice_id = int(received.players[local_slot].get("notice_id", 0))
	pause_open = false
	pause_overlay.hide()
	options_signature = ""
	_toast("已登船。你们可以各自行动，也可以一起下水。")

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func world_snapshot(snapshot: Dictionary, paused: bool) -> void:
	if mode == "client":
		received = snapshot
		room_paused = paused

@rpc("any_peer", "call_remote", "unreliable_ordered", 0)
func movement_request(x: float, y: float) -> void:
	if mode == "host" and multiplayer.get_remote_sender_id() == remote_peer and is_finite(x) and is_finite(y):
		world.set_move("guest", Vector2(x, y))

@rpc("any_peer", "call_remote", "reliable")
func action_request(verb: String, args: Dictionary = {}) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if mode != "host" or sender != remote_peer or room_paused:
		return
	var now := Time.get_ticks_msec()
	if now - int(last_action_ms.get(sender, -1000)) < 80:
		action_feedback.rpc_id(sender, "操作太快，请稍等后再试。", world.snapshot())
		return
	if args.size() > 8:
		return
	for value in args.values():
		if typeof(value) not in [TYPE_STRING, TYPE_INT, TYPE_FLOAT] or (value is String and value.length() > 80):
			return
	last_action_ms[sender] = now
	var message: String = _world_action("guest", verb.left(32), args)
	action_feedback.rpc_id(sender, message, world.snapshot(), str(args.get("id", "")) if verb == "town_talk" else "")
	_send_snapshot()

@rpc("authority", "call_remote", "reliable")
func action_feedback(message: String, snapshot: Dictionary, talk_id: String = "") -> void:
	if mode == "client":
		received = snapshot
	_action_message(message, talk_id)
	_update_hud()

func current_state() -> Dictionary:
	return received if mode == "client" else world.data

func perform(verb: String, args: Dictionary = {}) -> void:
	if verb == "open_chest":
		if not inventory_ui.visible:
			_toggle_inventory()
		return
	if room_paused:
		_toast("房间暂停中。")
		return
	if verb == "relocate" and not args.has("x"):
		relocation = args.duplicate(true)
		placement_recipe = ""
		_toast("选择新位置 · 右键取消")
		return
	pending_talk = str(args.get("id", "")) if verb == "town_talk" else ""
	if mode == "client":
		action_request.rpc_id(1, verb, args)
	elif mode in ["solo", "host"]:
		_action_message(_world_action("host", verb, args), pending_talk)
		_send_snapshot()
	options_signature = ""
	_update_hud()

func _action_message(message: String, talk_id: String = "") -> void:
	var available := mode in ["solo", "host", "client"] and not (pause_open or inventory_ui.visible or crafting_ui.visible or chart_ui.visible or island_atlas.visible or context_ui.visible)
	if available and talk_id == pending_talk and IslandTown.NPCS.has(talk_id) and message.begins_with(str(IslandTown.NPCS[talk_id].name) + "："):
		dialogue_ui.present(IslandTown.NPCS[talk_id], message)
	else:
		_toast(message)
	if talk_id == pending_talk:
		pending_talk = ""

func _world_action(slot: String, verb: String, args: Dictionary = {}) -> String:
	var previous_day := int(world.data.day)
	var message: String = world.action(slot, verb, args)
	if int(world.data.day) != previous_day:
		message += " 世界已保存。" if _persist() else " 保存失败：" + save_error
	return message

func _physics_process(delta: float) -> void:
	if mode == "connecting" and Time.get_ticks_msec() - connecting_since > 8500:
		_connection_failed()
	if mode not in ["solo", "host", "client"]:
		return
	var direction := Vector2.ZERO
	if automated and not cli.has("playthrough") and not cli.has("island-playthrough") and not cli.has("skill-playthrough"):
		direction = automation_input
	elif not _modal_open() and not overlay.visible:
		direction = Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	input_clock += delta
	if input_clock >= 0.04:
		input_clock = 0.0
		if mode == "client":
			if not received.is_empty():
				movement_request.rpc_id(1, direction.x, direction.y)
	# Local movement must react every physics frame, including key release.
	# Only network packets need the send interval above.
	if mode in ["solo", "host"]:
		world.set_move("host", direction)
	if mode in ["host", "solo"] and not room_paused and not (mode == "solo" and _modal_open()):
		var previous_day := int(world.data.day)
		world.tick(delta)
		if int(world.data.day) != previous_day:
			_persist()
			_toast("新的一天开始了。世界已保存，海域也迎来了新的收获。")
	if mode == "host":
		net_clock += delta
		if net_clock >= 0.08:
			net_clock = 0.0
			_send_snapshot()
	if mode in ["host", "solo"] and not automated and not cli.has("capture"):
		autosave_clock += delta
		if autosave_clock > 60.0:
			autosave_clock = 0.0
			if not _persist():
				_toast("自动保存失败：" + save_error)

func _process(delta: float) -> void:
	if not is_instance_valid(view):
		return
	view.state = current_state()
	view.local_slot = local_slot
	_update_pointer()
	view.queue_redraw()
	hud_clock += delta
	toast_clock = maxf(0.0, toast_clock - delta)
	if hud_clock >= 0.1:
		hud_clock = 0.0
		_update_hud()
	if screenshot_pending:
		screenshot_pending = false
		_capture.call_deferred()

func _send_snapshot() -> void:
	if mode == "host" and remote_peer > 0 and world.data.players.has("guest"):
		world_snapshot.rpc_id(remote_peer, world.snapshot(), room_paused)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_F11:
		var window := get_window()
		window.mode = Window.MODE_WINDOWED if window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_EXCLUSIVE_FULLSCREEN
		get_viewport().set_input_as_handled()
		return
	if mode not in ["solo", "host", "client"]:
		return
	if dialogue_ui.visible:
		if key in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
			dialogue_ui.hide()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_ESCAPE:
		if context_ui.visible:
			context_ui.hide()
		elif island_atlas.visible:
			island_atlas.hide()
		elif chart_ui.visible:
			_toggle_chart()
		elif not placement_recipe.is_empty() or not relocation.is_empty():
			placement_recipe = ""
			relocation = {}
		elif crafting_ui.visible:
			_toggle_crafting()
		elif inventory_ui.visible:
			_toggle_inventory()
		else:
			_toggle_pause()
	elif key == KEY_B and not pause_open:
		_toggle_inventory()
	elif key == KEY_C and not pause_open:
		_toggle_crafting()
	elif key == KEY_M and not pause_open:
		_toggle_chart()
	elif key == KEY_P and context_ui.visible:
		context_ui.hide()
	elif not _modal_open():
		if key == KEY_1:
			active_tool = "hook"
		elif key == KEY_2:
			active_tool = "rod"
		elif key == KEY_3:
			active_tool = "paddle"
		elif key == KEY_4:
			active_tool = "harpoon"
		elif current_state().players[local_slot].area == "island" and key in [KEY_5, KEY_6, KEY_7, KEY_8]:
			_equip_farm_item({KEY_5: "hoe", KEY_6: active_seed, KEY_7: "watering_can", KEY_8: "canopy"}[key])
		elif key == KEY_N and current_state().players[local_slot].area == "island":
			_cycle_seed()
		elif key == KEY_G:
			_toggle_anchor()
		elif key == KEY_O:
			_primary_action(true)
		elif key == KEY_P:
			_secondary_action()
		elif key == KEY_TAB and not current_options.is_empty():
			selected_option = (selected_option + 1) % current_options.size()
		elif key in [KEY_E, KEY_F] and not current_options.is_empty() and placement_recipe.is_empty() and relocation.is_empty():
			var index: int = (selected_option + (1 if key == KEY_F else 0)) % current_options.size()
			var option: Dictionary = current_options[index]
			perform(str(option.action), option.get("args", {}))
		elif key == KEY_R:
			perform("eat")

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		pointer_position = event.position

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or mode not in ["solo", "host", "client"]:
		return
	if _modal_open() or overlay.visible:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_secondary_action()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	_primary_action(false)

func _primary_action(keyboard: bool = false) -> void:
	_update_pointer()
	if not relocation.is_empty():
		if view.placement.get("valid", false):
			var move_args := relocation.duplicate(true)
			move_args["x"] = view.placement.x
			move_args["y"] = view.placement.y
			relocation = {}
			perform("relocate", move_args)
		else:
			_toast("这里不能放置，请靠近原设施并选择空甲板格。")
		return
	if not placement_recipe.is_empty():
		if view.placement.get("valid", false):
			perform("craft", {"recipe": placement_recipe, "x": view.placement.x, "y": view.placement.y})
			placement_recipe = ""
		else:
			_toast("这里不能放置，试试空着的甲板。")
		return
	var player: Dictionary = current_state().players[local_slot]
	_sync_held_item(player)
	var target: Vector2 = view.get_global_transform_with_canvas().affine_inverse() * pointer_position
	if player.area == "island" and active_tool in ["till", "plant", "water", "cover"]:
		var point: Vector2 = view.screen_to_world(target, "island")
		var args := {"x": point.x, "y": point.y}
		if active_tool == "plant":
			args.seed = active_seed
		perform(active_tool, args)
		return
	var origin := Vector2(float(player.x), float(player.y))
	if player.area == "deck":
		origin = view.world_to_screen(origin)
	var direction := (target - origin).normalized()
	if not player.get("hook", {}).is_empty():
		_toast("右键 / P 收钩")
	elif player.area == "water" and active_tool == "harpoon":
		perform("spear", {"x": direction.x, "y": direction.y})
	elif _clicked_interaction(keyboard and active_tool == "hook"):
		pass
	elif active_tool == "rod" and player.area != "water":
		perform("reel" if not player.get("fishing", {}).is_empty() else "cast")
	elif active_tool == "paddle" and player.area == "deck":
		perform("paddle", {"x": direction.x, "y": direction.y})
	elif active_tool == "hook" and player.area == "deck":
		perform("hook", {"x": direction.x, "y": direction.y})

func _clicked_interaction(keyboard: bool) -> bool:
	# The resident can move on a schedule boundary between HUD refreshes.
	# Resolve the click against the current world rather than stale prompt text.
	current_options = _rules().interaction_options(local_slot)
	if current_options.is_empty():
		return false
	var player: Dictionary = current_state().players[local_slot]
	var mouse: Vector2 = view.get_global_transform_with_canvas().affine_inverse() * pointer_position
	var local_mouse: Vector2 = view.screen_to_world(mouse, str(player.area))
	var data := current_state()
	var best: Dictionary = {}
	var distance := 48.0
	var safe_options: Array = []
	for option in current_options:
		var verb := str(option.action)
		if verb.begins_with("town_") and verb != "town_talk":
			continue
		if verb in ["eat", "drink", "cast", "reel", "relocate", "sleep", "deposit", "take_meal", "drop_anchor", "raise_anchor", "sell", "build"]:
			continue
		safe_options.append(option)
		if not keyboard and verb in ["land", "dive", "fill_cup"]:
			continue
		var target := Vector2(float(player.x), float(player.y))
		var id := str(option.get("args", {}).get("id", ""))
		for collection in [data.structures, data.chests, data.entities]:
			if collection.has(id):
				target = Vector2(float(collection[id].x), float(collection[id].y))
		if verb in ["catch", "collect"]:
			var entity_id: String = _rules()._nearest_entity(player, "fish" if verb == "catch" else "wood")
			if data.entities.has(entity_id):
				target = Vector2(float(data.entities[entity_id].x), float(data.entities[entity_id].y))
		elif verb == "surface":
			target = WorldState.STATIONS.buoy
		if player.area == "island":
			var spots = preload("res://scripts/island_state.gd")
			if verb == "town_talk":
				target = IslandTown.position(id, float(data.minute))
			elif str(option.action) == "gather_island":
				var resource: Dictionary = IslandMap.node(id)
				target = Vector2(float(resource.x), float(resource.y))
			elif str(option.action) in ["plant", "water", "harvest", "clear_crop", "refill_can"]:
				var args: Dictionary = option.get("args", {})
				target = Vector2(float(args.get("x", player.x)), float(args.get("y", player.y)))
			elif id == "island_camp":
				target = spots.CAMP
			elif str(option.action) == "board_raft":
				target = spots.DOCK
		var gap := local_mouse.distance_to(target)
		if gap < distance:
			distance = gap
			best = option
	if best.is_empty() and keyboard and not safe_options.is_empty():
		var selected: Dictionary = current_options[clampi(selected_option, 0, current_options.size() - 1)]
		best = selected if selected in safe_options else safe_options[0]
	if best.is_empty():
		return false
	perform(str(best.action), best.get("args", {}))
	return true

func _secondary_action() -> void:
	current_options = _rules().interaction_options(local_slot)
	if not placement_recipe.is_empty() or not relocation.is_empty():
		placement_recipe = ""
		relocation = {}
		return
	var player: Dictionary = current_state().players[local_slot]
	if not player.get("activity", {}).is_empty():
		perform("cancel_activity")
	elif active_tool in ["till", "plant", "water", "cover"]:
		active_tool = "hook"
		if not current_options.is_empty():
			var at: Vector2 = ui.get_global_transform_with_canvas().affine_inverse() * pointer_position
			context_ui.present(current_options, at)
	elif not player.get("hook", {}).is_empty():
		perform("pull_hook")
	elif not player.get("fishing", {}).is_empty():
		perform("reel")
	elif not current_options.is_empty():
		var at: Vector2 = ui.get_global_transform_with_canvas().affine_inverse() * pointer_position
		context_ui.present(current_options, at)
	else:
		_toast("靠近设施、物资或筏边，再按右键 / P。")

func _modal_open() -> bool:
	return pause_open or inventory_ui.visible or crafting_ui.visible or chart_ui.visible or island_atlas.visible or context_ui.visible or dialogue_ui.visible

func _toggle_chart() -> void:
	if mode not in ["solo", "host", "client"] or pause_open:
		return
	if current_state().players[local_slot].area == "island":
		if island_atlas.visible:
			island_atlas.hide()
		else:
			island_atlas.present(current_state(), local_slot)
		chart_ui.hide()
	else:
		chart_ui.visible = not chart_ui.visible
	inventory_ui.hide()
	crafting_ui.hide()
	context_ui.hide()
	placement_recipe = ""
	relocation = {}
	_update_hud()

func _toggle_anchor() -> void:
	var data := current_state()
	if data.is_empty() or mode not in ["solo", "host", "client"] or _modal_open():
		return
	perform("raise_anchor" if bool(data.navigation.anchored) else "drop_anchor")

func _rules():
	if mode != "client":
		return world
	var mirror = WorldState.new()
	mirror.data = received.duplicate(true)
	return mirror

func _equip_farm_item(item: String) -> void:
	var player: Dictionary = current_state().players[local_slot]
	if player.area != "island":
		_toast("上岛后，选中这件物品并点击土地使用。")
		return
	if Inventory.count(player.bag, item) <= 0:
		_toast("背包里没有%s。" % Inventory.ITEM_NAMES.get(item, item))
		return
	if Farming.CROPS.has(item):
		active_seed = item
		active_tool = "plant"
	else:
		active_tool = str(Farming.ACTION_ITEMS.find_key(item))
	_update_hud()

func _cycle_seed() -> void:
	var player: Dictionary = current_state().players[local_slot]
	var seeds: Array = []
	for item in Farming.CROPS:
		if Inventory.count(player.bag, item) > 0:
			seeds.append(item)
	if seeds.is_empty():
		_toast("背包里没有种子。")
		return
	_equip_farm_item(str(seeds[(seeds.find(active_seed) + 1) % seeds.size()]))

func _sync_held_item(player: Dictionary) -> void:
	if active_tool in ["till", "plant", "water", "cover"]:
		if player.area != "island" or Inventory.count(player.bag, Farming.held_item(active_tool, active_seed)) == 0:
			active_tool = "hook"


func _update_pointer() -> void:
	view.farm_preview = {}
	var state := current_state()
	if not state.is_empty() and state.players[local_slot].area == "island" and active_tool in ["till", "plant", "water", "cover"] and not _modal_open():
		var mouse: Vector2 = view.get_global_transform_with_canvas().affine_inverse() * pointer_position
		var point: Vector2 = view.screen_to_world(mouse, "island")
		var key := Farming.plot_key(point)
		if not key.is_empty():
			var center := Farming.plot_center(key)
			var player: Dictionary = state.players[local_slot]
			view.farm_preview = {"x": center.x, "y": center.y, "tool": active_tool, "seed": active_seed, "valid": (state.island.plots.has(key) if active_tool != "till" else IslandMap.tillable(center) and Farming.obstruction(state, center).is_empty() and not state.island.plots.has(key)) and center.distance_to(Vector2(player.x, player.y)) <= 64}
	hovered_drift = ""
	view.hovered_id = ""
	view.placement = {}
	var data := current_state()
	if data.is_empty() or mode not in ["solo", "host", "client"] or _modal_open():
		return
	var mouse: Vector2 = view.get_global_transform_with_canvas().affine_inverse() * pointer_position
	# Only deck placement follows the gentle boat transform. Drift stays in sea space.
	var deck_mouse: Vector2 = view.screen_to_world(mouse, "deck")
	if not relocation.is_empty():
		var object_id := str(relocation.get("id", ""))
		var source: Dictionary = data.chests.get(object_id, data.structures.get(object_id, {}))
		if source.is_empty():
			relocation = {}
			_toast("设施已不在原处，请重新选择。")
			return
		if float(source.x) != float(relocation.from_x) or float(source.y) != float(relocation.from_y):
			relocation = {}
			_toast("伙伴已搬动这个设施，请在新位置重新选择。")
			return
		var snapped := Vector2(floorf(deck_mouse.x / 64.0) * 64.0 + 32.0, floorf(deck_mouse.y / 64.0) * 64.0 + 32.0)
		view.placement = {"x": snapped.x, "y": snapped.y, "kind": source.get("kind", "chest"), "valid": _rules().can_relocate(local_slot, object_id, float(relocation.from_x), float(relocation.from_y), snapped.x, snapped.y)}
	elif not placement_recipe.is_empty():
		var snapped := Vector2(floorf(deck_mouse.x / 64.0) * 64.0 + 32.0, floorf(deck_mouse.y / 64.0) * 64.0 + 32.0)
		view.placement = {"x": snapped.x, "y": snapped.y, "kind": str(Recipes.ALL[placement_recipe].structure), "valid": _rules().can_place(local_slot, placement_recipe, snapped.x, snapped.y)}


func _toggle_crafting() -> void:
	if mode not in ["solo", "host", "client"] or pause_open:
		return
	crafting_ui.visible = not crafting_ui.visible
	chart_ui.hide()
	island_atlas.hide()
	context_ui.hide()
	inventory_ui.hide()
	placement_recipe = ""
	relocation = {}
	_update_hud()

func _choose_recipe(recipe: String) -> void:
	if not Recipes.ALL.has(recipe):
		return
	if str(Recipes.ALL[recipe].structure).is_empty():
		perform("craft", {"recipe": recipe})
	else:
		placement_recipe = recipe
		crafting_ui.hide()
		_toast("选择放置位置 · 右键取消")

func _use_hotbar(index: int) -> void:
	var data := current_state()
	if data.is_empty() or mode not in ["solo", "host", "client"]:
		return
	if index < 0 or index >= Inventory.BAG_SIZE or _modal_open():
		return
	var stack: Dictionary = data.players[local_slot].bag[index]
	var item := str(stack.get("item", ""))
	if item in Farming.ACTION_ITEMS.values() or Farming.CROPS.has(item):
		_equip_farm_item(item)
	elif item.is_empty():
		active_tool = "hook"
		_update_hud()
	elif item == "freshwater":
		perform("drink")
	elif item in ["meal", "cooked_fish"]:
		perform("eat", {"item": item})
	elif item == "rod":
		active_tool = "rod"
	elif item == "harpoon":
		active_tool = "harpoon"
	elif item == "paddle":
		active_tool = "paddle"
	elif item == "anchor":
		_toggle_anchor()
	else:
		_toggle_inventory()

func _toggle_pause() -> void:
	if mode not in ["solo", "host", "client"]:
		return
	pause_open = not pause_open
	chart_ui.hide()
	island_atlas.hide()
	context_ui.hide()
	inventory_ui.hide()
	crafting_ui.hide()
	placement_recipe = ""
	relocation = {}
	pause_overlay.visible = pause_open
	pause_panel.size.y = 420 if mode == "host" else 364
	pause_panel.position.y = (800 - pause_panel.size.y) / 2
	return_title_button.position.y = 340 if mode == "host" else 284
	return_title_button.text = "返回标题" if mode == "client" else "保存并返回标题"
	room_pause_button.text = "继续房间" if room_paused else "暂停房间"
	if mode == "solo":
		pause_note.text = "世界已暂停。"
		room_pause_button.hide()
	else:
		pause_note.text = "房间已暂停。" if room_paused else "伙伴仍在行动，时间继续流动。\n水下请留意氧气。"
		room_pause_button.visible = mode == "host"

func _toggle_inventory() -> void:
	if mode not in ["solo", "host", "client"] or pause_open:
		return
	inventory_ui.visible = not inventory_ui.visible
	chart_ui.hide()
	island_atlas.hide()
	context_ui.hide()
	crafting_ui.hide()
	placement_recipe = ""
	relocation = {}
	inventory_ui.clear_selection()
	_update_hud()

func _update_hud() -> void:
	if overlay.visible:
		continue_button.disabled = not _has_saved_world()
	menu_status.visible = not menu_status.text.is_empty()
	menu_panel.size.y = 550 if menu_status.visible else 470
	menu_panel.position.y = (800 - menu_panel.size.y) / 2
	var data := current_state()
	hud.visible = mode in ["solo", "host", "client"] and not overlay.visible
	if data.is_empty() or not data.get("players", {}).has(local_slot):
		return
	var rules = _rules()
	current_options = rules.interaction_options(local_slot)
	var signature := JSON.stringify(current_options)
	if signature != options_signature:
		options_signature = signature
		selected_option = clampi(selected_option, 0, maxi(0, current_options.size() - 1))
	var player: Dictionary = data.players[local_slot]
	if int(player.get("notice_id", 0)) != last_notice_id:
		last_notice_id = int(player.get("notice_id", 0))
		_toast(str(player.get("notice", "")))
	var hover := ""
	if not hovered_drift.is_empty():
		var kind := str(data.drift[hovered_drift].kind)
		hover = ("漂流桶" if kind == "barrel" else str(Inventory.ITEM_NAMES.get(kind, kind))) + " · 点击打捞"
	_sync_held_item(player)
	hud.farm_seed = active_seed
	hud.refresh(data, local_slot, current_options, selected_option, active_tool, toast_clock, "relocate" if not relocation.is_empty() else placement_recipe, hover)
	if hud.prompt_box.visible:
		var logical := Vector2(float(player.x), float(player.y))
		var viewport_at: Vector2 = view.get_global_transform_with_canvas() * view.world_to_screen(logical, str(player.area))
		var hud_at: Vector2 = hud.get_global_transform_with_canvas().affine_inverse() * viewport_at
		var prompt_width: float = hud.prompt_box.size.x
		var prompt_y: float = hud_at.y + 56
		if prompt_y > 623:
			var character_height: float = 48.0 * view.get_global_transform_with_canvas().y.length() / hud.get_global_transform_with_canvas().y.length()
			prompt_y = hud_at.y - character_height - hud.prompt_box.size.y - 47
		hud.prompt_box.position = Vector2(clampf(hud_at.x - prompt_width * 0.5, 20, UI_SIZE.x - prompt_width - 20), clampf(prompt_y, 130, 623))
	var hover_at: Vector2 = hud.get_global_transform_with_canvas().affine_inverse() * pointer_position
	hud.hover_label.position = Vector2(clampf(hover_at.x + 16, 12, UI_SIZE.x - hud.hover_label.size.x - 12), clampf(hover_at.y - 24, 12, UI_SIZE.y - hud.hover_label.size.y - 12))
	var modal_open: bool = _modal_open()
	hud.hint.visible = not modal_open
	if modal_open:
		hud.prompt_box.hide()
		hud.toast_box.hide()
	if inventory_ui.visible:
		inventory_ui.refresh(data, local_slot, rules.nearby_chest(local_slot), status.text if toast_clock > 0 else "", mode != "solo")
	if crafting_ui.visible:
		crafting_ui.refresh(data, local_slot)
	if island_atlas.visible:
		island_atlas.refresh(data, local_slot)
	if chart_ui.visible:
		chart_ui.refresh(data, local_slot)

func _toast(message: String) -> void:
	if is_instance_valid(crafting_ui) and crafting_ui.visible:
		crafting_ui.result_message = message
	if is_instance_valid(status):
		status.text = message
		status.add_theme_color_override("font_color", Color("f1ac8c") if ("不足" in message or "已满" in message or "失败" in message) else UI.PAPER)
	toast_clock = 3.5

func _persist() -> bool:
	if mode == "client" or cli.has("capture"):
		return false
	save_error = ""
	var absolute := ProjectSettings.globalize_path(save_path)
	var parent := absolute.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(parent)
	if directory_error != OK:
		save_error = "无法创建存档目录"
		return false
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		save_error = "无法写入存档"
		return false
	file.store_string(JSON.stringify({"format": "tidehaven", "version": 10, "state": world.snapshot()}, "", false, true))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		save_error = "存档写入失败"
		return false
	if FileAccess.file_exists(absolute) and not restored_backup:
		if DirAccess.copy_absolute(absolute, absolute + ".bak") != OK:
			save_error = "无法保留上一个存档"
			return false
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		save_error = "无法替换存档"
		return false
	restored_backup = false
	return true

func _save_candidates() -> Array:
	if save_path == "user://world_v10.json" and not FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path + ".bak"):
		for previous in ["user://world_v9.json", "user://world_v8.json", "user://world_v7.json", "user://world_v6.json", "user://world_v5.json", "user://world_v4.json", "user://world_v3.json", "user://world_v2.json", "user://world_v1.json"]:
			if FileAccess.file_exists(previous) or FileAccess.file_exists(previous + ".bak"):
				return [previous, previous + ".bak"]
	return [save_path, save_path + ".bak"]

func _has_saved_world() -> bool:
	for path in _save_candidates():
		if FileAccess.file_exists(path):
			return true
	return false

func _load_saved() -> bool:
	for path in _save_candidates():
		if not FileAccess.file_exists(path):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK:
			continue
		var parsed: Variant = parser.data
		if not parsed is Dictionary:
			continue
		var version_value: Variant = parsed.get("version")
		if typeof(version_value) not in [TYPE_INT, TYPE_FLOAT]:
			continue
		# JSON reads integer-looking values as floats; validate before converting.
		if float(version_value) not in [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]:
			continue
		if parsed.get("format", "") == "tidehaven" and parsed.get("state") is Dictionary:
			if world.restore(parsed.state):
				if path == save_path + ".bak":
					restored_backup = true
					# Keep the corrupt original for inspection before subsequent normal autosaves.
					if FileAccess.file_exists(save_path):
						DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path) + ".recovered-original")
				return true
	save_error = "主存档和备份均不可用。"
	return false

func _return_title() -> void:
	if mode in ["host", "solo"] and not _persist():
		_toast("保存失败，仍留在游戏中：" + save_error)
		return
	_reset_network()
	mode = "menu"
	local_slot = "host"
	pause_open = false
	room_paused = false
	pause_overlay.hide()
	chart_ui.hide()
	island_atlas.hide()
	context_ui.hide()
	inventory_ui.hide()
	crafting_ui.hide()
	placement_recipe = ""
	relocation = {}
	overlay.show()
	menu_status.text = "世界已保留。可以继续单人，也可以创建双人房间。"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if mode in ["host", "solo"] and not automated and not cli.has("capture"):
			if not _persist():
				_toast("保存失败，请检查存储空间后重试。")
				return
		get_tree().quit()

func _capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := str(cli["capture"])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " result=", error)
	get_tree().quit(0 if error == OK else 1)



extends Node
## A controlled rare-drop UI fixture, separate from the normal-input playthrough.
const Inventory = preload("res://scripts/inventory.gd")
var game
var directory := ""
var finished := false

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			directory = argument.trim_prefix("--evidence-dir=")
	if directory.is_empty():
		_fail("Require an isolated evidence directory")
		return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(15).timeout.connect(func():
		if not finished:
			_fail("Rare-drop UI check timed out"))
	game = get_parent()
	game.automated = true
	game.save_path = directory.path_join("unused-world.json")
	game._start("solo", false)
	var player: Dictionary = game.world.data.players.host
	player.area = "water"
	player.x = 120.0
	player.y = 100.0
	player.oxygen = 20.0
	Inventory.add(player.bag, "treasure", 1)
	await _tap(KEY_B)
	if not game.inventory_ui.visible or not "氧气" in game.inventory_ui.vitals.text or not "水下" in game.inventory_ui.vitals.text:
		_fail("Inventory must display oxygen and underwater location")
		return
	await _click(game.inventory_ui.bag_buttons[0].get_global_rect().get_center())
	await _shot("05-treasure-and-oxygen.png")
	await _click(game.inventory_ui.open_button.get_global_rect().get_center())
	if Inventory.count(player.bag, "treasure") != 0 or Inventory.count(player.bag, "wood") != 3 or Inventory.count(player.bag, "seed") != 2 or Inventory.count(player.bag, "fish") != 1:
		_fail("Open Treasure button failed to grant exact contents")
		return
	# A full source stack cannot free a slot when opening one treasure.
	player.bag = Inventory.empty_slots(12)
	player.bag[0] = {"item": "treasure", "count": 20}
	for index in range(1, 12):
		player.bag[index] = {"item": "meal", "count": 20}
	await get_tree().create_timer(0.2).timeout
	var before: Array = player.bag.duplicate(true)
	await _click(game.inventory_ui.bag_buttons[0].get_global_rect().get_center())
	await _click(game.inventory_ui.open_button.get_global_rect().get_center())
	if player.bag != before:
		_fail("Full-pack treasure click consumed or changed items")
		return
	await _shot("06-full-pack-feedback.png")
	finished = true
	print("TREASURE UI PASS: real B and button input; visible underwater oxygen; exact rewards; full-pack refusal preserves every item. Controlled fixture, not a natural drop.")
	game.mode = "menu"
	get_tree().quit(0)

func _tap(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().create_timer(0.2).timeout

func _click(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	game.get_viewport().push_input(event, true)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	game.get_viewport().push_input(event, true)
	await get_tree().create_timer(0.2).timeout

func _shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = game.get_viewport().get_texture().get_image()
	if picture.save_png(directory.path_join(filename)) != OK:
		_fail("Could not save screenshot")

func _fail(message: String) -> void:
	finished = true
	push_error(message)
	get_tree().quit(1)

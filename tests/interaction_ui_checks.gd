extends SceneTree
const Inventory = preload("res://scripts/inventory.gd")
const Map=preload("res://scripts/island_map.gd")
const MainScene = preload("res://main.tscn")
var main
var checks:=0
var failures:=0
var evidence:=(OS.get_environment("TIDEHAVEN_TEST_ROOT") if not OS.get_environment("TIDEHAVEN_TEST_ROOT").is_empty() else ProjectSettings.globalize_path("res://artifacts")).path_join("interaction-ui-")+str(Time.get_unix_time_from_system()).replace(".","-")
func _initialize()->void:
	call_deferred("_run")
func _run()->void:
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate()
	root.add_child(main)
	main.save_path=evidence.path_join("world.json")
	main.automated=true
	create_timer(80).timeout.connect(func():printerr("FAIL interaction UI timeout");quit(1))
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	main.world.data.players.host.bag=Inventory.empty_slots(12)
	var p:Dictionary=main.world.data.players.host
	p.bag[0]={"item":"axe","count":1}
	p.bag[1]={"item":"pickaxe","count":1}
	p.bag[2]={"item":"freshwater","count":2}
	p.bag[3]={"item":"wood","count":999}
	p.bag[10]={"item":"chest","count":2}
	p.bag[11]={"item":"watering_can","count":1}
	await _settle()
	_check(main.hud.slots.all(func(v):return v.button.visible),"all twelve slots visible on deck")
	await _click(main.hud.slots[0].button.get_global_rect().get_center())
	_check(main.active_tool=="axe" and main.held_index==0 and not main.inventory_ui.visible,"click selects axe without opening bag")
	await _click(main.hud.slots[1].button.get_global_rect().get_center())
	_check(main.active_tool=="pickaxe" and main.held_index==1,"one click switches to pickaxe")
	var amount:int=Inventory.count(p.bag,"freshwater")
	await _click(main.hud.slots[2].button.get_global_rect().get_center())
	_check(main.active_tool=="freshwater" and Inventory.count(p.bag,"freshwater")==amount,"selecting drink never consumes it")
	await _tap(KEY_EQUAL)
	_check(main.active_tool=="water" and main.held_index==11,"equals selects twelfth actual bag item on deck")
	await _click(main.hud.slots[10].button.get_global_rect().get_center())
	_check(main.placement_recipe=="chest" and Inventory.count(p.bag,"chest")==2,"click portable chest enters preview without spending")
	await _tap(KEY_P)
	_check(main.placement_recipe.is_empty() and Inventory.count(p.bag,"chest")==2,"cancel preview retains both chest items")
	await _click(main.hud.slots[10].button.get_global_rect().get_center())
	var screen:Vector2=main.view.world_to_screen(Vector2(544,224))
	await _click(main.view.get_global_transform_with_canvas()*screen)
	_check(main.world.data.chests.size()==1 and Inventory.count(p.bag,"chest")==1,"world click places a chest and consumes one kit")
	await _tap(KEY_B)
	await _click(main.inventory_ui.bag_buttons[0].get_global_rect().get_center())
	_check(main.active_tool=="axe" and main.inventory_ui.visible,"inventory click also equips without closing or consuming")
	await _click(main.inventory_ui.bag_buttons[1].get_global_rect().get_center())
	_check(main.active_tool=="pickaxe" and p.bag[0].item=="axe" and p.bag[1].item=="pickaxe","second inventory click switches, never swaps stacks")
	await _drag(main.inventory_ui.bag_buttons[0].get_global_rect().get_center(),main.inventory_ui.bag_buttons[5].get_global_rect().get_center())
	_check(p.bag[0].is_empty() and p.bag[5].item=="axe","native real pointer drag moves a whole stack")
	await _right(main.inventory_ui.bag_buttons[3].get_global_rect().get_center())
	_check(not main.inventory_ui.moving.is_empty() and main.inventory_ui.moving.amount==500,"right click selects half of 999")
	await _right(main.inventory_ui.bag_buttons[6].get_global_rect().get_center())
	_check(p.bag[6].get("count",0)==1 and p.bag[3].count==998,"right target places one without losing remainder")
	await _click(main.inventory_ui.bag_buttons[6].get_global_rect().get_center())
	await _click(main.inventory_ui.discard_button.get_global_rect().get_center())
	_check(main.inventory_ui.discard_dialog.visible and p.bag[6].count==1,"discard is a separate confirmation")
	await _tap(KEY_B)
	_check(not main.inventory_ui.discard_dialog.visible and main.inventory_ui.visible and p.bag[6].count==1,"cancel discard keeps item and inventory")
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(evidence.path_join("inventory-999.png"))
	await _tap(KEY_B)
	await _tap(KEY_C)
	main.crafting_ui._select_category("survival")
	main.crafting_ui.selected_recipe="chest"
	Inventory.add(p.bag,"rope",1)
	await _settle()
	var old:int=Inventory.count(p.bag,"chest")
	await _click(main.crafting_ui.make_button.get_global_rect().get_center())
	_check(Inventory.count(p.bag,"chest")==old+1 and main.world.data.chests.size()==1,"craft button adds item, not furniture or placement mode")
	await _tap(KEY_B)
	var slot:int=-1
	for i in 12:
		if p.bag[i].get("item","")=="chest":slot=i
	await _click(main.inventory_ui.bag_buttons[slot].get_global_rect().get_center())
	await _tap(KEY_B)
	_check(main.placement_recipe=="chest","closing bag resumes selected chest preview")
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(evidence.path_join("held-chest.png"))
	await _tap(KEY_P)
	main.world.data.island.homestead.rented=true
	main.world.data.chart.visited=true
	main.world.data.navigation.anchored=true
	var port:Vector2=preload("res://scripts/archipelago.gd").island_position(main.world.data.chart)
	main.world.data.navigation.x=port.x
	main.world.data.navigation.y=port.y
	p.area="island"
	var found:=Vector2.ZERO
	for gx in range(32,52):
		for gy in range(21,34):
			var at:=Vector2(gx*64+32,gy*64+32)
			p.x=at.x;p.y=at.y+64
			if Map.can_stand(Vector2(p.x,p.y)) and main.world.island_chest_reason("host",at).is_empty():found=at;break
		if found!=Vector2.ZERO:break
	await _settle()
	_check(found!=Vector2.ZERO,"yard has a natural legal placement spot")
	await _click(main.hud.slots[slot].button.get_global_rect().get_center())
	await _click(main.view.get_global_transform_with_canvas()*main.view.world_to_screen(found,"island"))
	_check(main.world.data.chests.size()==2 and main.world.data.chests.chest_1.area=="island","real world click places portable chest on island")
	await _tap(KEY_P)
	await _tap(KEY_B)
	_check(main.inventory_ui.chest_id=="chest_1","island chest opens the same storage panel")
	await _drag(main.inventory_ui.bag_buttons[3].get_global_rect().get_center(),main.inventory_ui.chest_buttons[0].get_global_rect().get_center())
	var stored:int=main.world.data.chests.chest_1.slots[0].get("count",0)
	_check(stored>900 and p.bag[3].is_empty(),"native drag stores island materials")
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(evidence.path_join("island-storage.png"))
	await _tap(KEY_B)
	await _tap(KEY_ESCAPE)
	await _click(main.return_title_button.get_global_rect().get_center())
	_check(main.mode=="menu" and not main.continue_button.disabled,"save and return exposes Continue")
	await _click(main.continue_button.get_global_rect().get_center())
	_check(main.mode=="solo" and main.world.data.chests.chest_1.slots[0].count==stored and main.world.data.players.host.bag[3].is_empty(),"actual Continue restores island box without duplicating stack")
	print("INTERACTION UI: %d checks, %d failures; %s"%[checks,failures,evidence])
	quit(0 if failures==0 else 1)
func _right(at:Vector2)->void:
	await _move_mouse(at)
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down
		root.push_input(e,true);await process_frame
	await _settle()
func _drag(from:Vector2,to:Vector2)->void:
	await _move_mouse(from)
	var e:=InputEventMouseButton.new();e.position=from;e.global_position=from;e.button_index=MOUSE_BUTTON_LEFT;e.button_mask=MOUSE_BUTTON_MASK_LEFT;e.pressed=true
	root.push_input(e,true);await process_frame
	var previous:=from
	for i in range(1,9):
		var at:=from.lerp(to,i/8.0)
		var m:=InputEventMouseMotion.new();m.position=at;m.global_position=at;m.relative=at-previous;m.button_mask=MOUSE_BUTTON_MASK_LEFT
		root.push_input(m,true);previous=at;await _settle(0.04)
	e=InputEventMouseButton.new();e.position=to;e.global_position=to;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false
	root.push_input(e,true);await _settle()

func _tap(code: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()


func _move_mouse(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	await _settle()


func _click(at: Vector2) -> void:
	await _move_mouse(at)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	root.push_input(event, true)
	await _settle()


func _settle(seconds: float = 0.14) -> void:
	await create_timer(seconds).timeout
	await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", description)

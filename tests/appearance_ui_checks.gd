extends "res://tests/island_ui_checks.gd"
func _run()->void:
	evidence=ProjectSettings.globalize_path("res://artifacts/remaining-016/appearance-ui")
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate();root.add_child(main);main.save_path=evidence.path_join("world-%d.json"%Time.get_ticks_usec());main.automated=true
	await _settle()
	for viewport_size in [Vector2i(960,600),Vector2i(1280,800)]:
		root.size=viewport_size;await _settle()
		var title_button:=_button_named(main.overlay,"选择形象")
		await _click(title_button.get_global_rect().get_center())
		_check(main.appearance_ui.visible,"title appearance opens")
		var initial:Dictionary=main.appearance_ui.profile.duplicate()
		var arrows:Array=main.appearance_ui.get_children().filter(func(node):return node is Button and node.text=="›")
		for arrow:Button in arrows:await _click(arrow.get_global_rect().get_center())
		_check(main.appearance_ui.profile.body!=initial.body and main.appearance_ui.profile.hair!=initial.hair,"real clicks cycle actual layer choices")
		await _capture("appearance-%d.png"%viewport_size.x)
		await _click(_button_named(main.appearance_ui,"就这样出发").get_global_rect().get_center())
		_check(not main.appearance_ui.visible,"confirmed panel closes")
	await _click(main.new_game_button.get_global_rect().get_center())
	_check(main.world.data.wardrobe.host==main.selected_appearance,"new world uses chosen appearance")
	await _tap(KEY_ESCAPE)
	await _click(_button_named(main.pause_panel,"换装").get_global_rect().get_center())
	_check(main.appearance_ui.visible,"in-game appearance opens over pause")
	await _tap(KEY_ESCAPE)
	_check(not main.appearance_ui.visible and main.pause_open,"Escape closes top modal only")
	await _tap(KEY_ESCAPE)
	main.set_physics_process(false)
	var p:Dictionary=_player();p.area="water";p.x=460;p.y=220
	await _settle();await _capture("swimming-idle.png")
	for i in 12:
		var image:Image=preload("res://scripts/swimming_art.gd").texture("host",i,0).get_image()
		_check(image.get_used_rect().size.x>20 and image.get_used_rect().size.y>10,"complete non-empty swim frame")
	main.world.data.navigation.anchored=true;p.x=120;p.y=160
	main.automated=false
	main.set_physics_process(true)
	for direction in [KEY_D,KEY_W,KEY_A,KEY_S]:
		var start:=Vector2(p.x,p.y)
		var key:=InputEventKey.new();key.physical_keycode=direction;key.keycode=direction;key.pressed=true;Input.parse_input_event(key)
		for frame in 6:
			await create_timer(0.1).timeout
			await _capture("swim-%d-%d.png"%[direction,frame])
		key=InputEventKey.new();key.physical_keycode=direction;key.keycode=direction;key.pressed=false;Input.parse_input_event(key)
		_check(Vector2(p.x,p.y).distance_to(start)>20,"actual directional input moves swimmer")
		await create_timer(0.25).timeout
		await _capture("swim-idle-after-%d.png"%direction)
	main.set_physics_process(false)
	main.automated=true
	main._persist()
	var before:Dictionary=main.world.data.wardrobe.duplicate(true)
	main.world=preload("res://scripts/world_state.gd").new()
	_check(main._load_saved() and main.world.data.wardrobe==before,"actual save-file preserves choices")
	finished=true;print("APPEARANCE UI ",checks," failures=",failures);quit(1 if failures else 0)

func _button_named(parent:Node,label:String)->Button:
	for node:Node in parent.get_children():
		if node is Button and node.text==label:return node
	return null

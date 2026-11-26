extends "res://tests/island_ui_checks.gd"
const IslandArt = preload("res://scripts/island_art.gd")

func _run() -> void:
	create_timer(60).timeout.connect(func():
		if not finished:
			printerr("FAIL island art UI deadline")
			quit(1))
	evidence=ProjectSettings.globalize_path("res://artifacts/island-art-ui-%d" % Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate()
	main.save_path=evidence.path_join("world.json")
	root.add_child(main)
	main.automated=true
	await _settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	_check(main.mode == "solo", "actual title starts the isolated world")
	main.world.data.minute=720.0
	main.world.data.island.homestead.rented=true
	_fixture_player("island",IslandMap.YARD_GATE+Vector2(50,0))
	await _settle()
	for size in [Vector2i(960,600),Vector2i(1280,800)]:
		root.size=size
		await _settle()
		await _capture("yard-%d.png" % size.x)
	# Four seasons, actual imported pixels and unchanged generated terrain.
	for day in [1,29,57,85]:
		main.world.data.day=day
		_fixture_player("island",Vector2(1984,830))
		await _settle()
		await _capture("street-%s.png" % IslandArt.season(day))
	main.world.data.day=1
	_fixture_player("island",Vector2(1984,580))
	await _settle()
	await _capture("behind-roof.png")
	# All growth ages below are display fixtures, not proof of natural day progression.
	main.world.data.day=1
	_fixture_player("island",Vector2(2290,2070))
	for id: String in IslandMap.nodes_near(Vector2(2290,2070)):
		main.world.data.island.depleted[id]=999
	var row:=0
	for crop: String in Farming.CROPS:
		var config: Dictionary=Farming.CROPS[crop]
		var stages: Array=[0,1,int(config.days)/2,int(config.days),int(config.days)]
		for column in stages.size():
			var point := Vector2(2080+column*64,1744+row*80)
			main.world.data.island.plots[Farming.plot_key(point)]={"crop":crop,"growth":stages[column],"watered":column%2==0,"dead":column==4,"covered":false}
		row+=1
	await _settle()
	await _capture("crop-stages.png")
	await _tap(KEY_M)
	await _capture("island-map.png")
	await _tap(KEY_ESCAPE)
	# Real movement input remains independent of art and uses both walking strides.
	_fixture_player("island",IslandMap.YARD_GATE+Vector2(50,0))
	main.automated=false
	var x: float=_player().x
	var key:=InputEventKey.new()
	key.keycode=KEY_D
	key.physical_keycode=KEY_D
	key.pressed=true
	Input.parse_input_event(key)
	var frames: Dictionary={}
	for i in 8:
		await _settle(0.07)
		frames[int(main.view._character_states.host.frame)]=true
		if i in [1,3,5]: await _capture("walk-%d.png" % i)
	key=InputEventKey.new()
	key.keycode=KEY_D
	key.physical_keycode=KEY_D
	key.pressed=false
	Input.parse_input_event(key)
	await _settle(0.2)
	_check(float(_player().x)>x+35,"actual keyboard walking still crosses textured ground")
	_check(frames.has(1) and frames.has(3),"actual movement displays both alternating strides")
	_check(main.view._character_states.host.frame==0,"walking settles to neutral without idle animation")
	_fixture_player("water",Vector2(500,330))
	await _settle()
	await _capture("swim-existing-gap.png")
	finished=true
	print("ISLAND ART UI: %d checks, %d failures; evidence: %s" % [checks,failures,evidence])
	quit(0 if failures==0 else 1)

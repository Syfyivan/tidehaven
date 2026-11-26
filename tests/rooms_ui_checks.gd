extends "res://tests/island_ui_checks.gd"
const Rooms=preload("res://scripts/rooms.gd")
func _run()->void:
	evidence=ProjectSettings.globalize_path("res://artifacts/rooms-ui-%d" % Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate();root.add_child(main)
	main.save_path=evidence.path_join("world.json");main.automated=true
	create_timer(100).timeout.connect(func():if not finished:printerr("FAIL rooms UI deadline");quit(1))
	await _settle();await _click(main.new_game_button.get_global_rect().get_center())
	main.set_physics_process(false)
	for size in [Vector2i(960,600),Vector2i(1280,800)]:
		root.size=size
		_fixture_player("water",Rooms.SEA_ENTRY+Vector2(-40,0));_player().room=""
		_player().bag=Inventory.empty_slots(12);Inventory.add(_player().bag,"pickaxe",1)
		main.active_tool="hook"
		await _settle();await _click(_world_point(Rooms.SEA_ENTRY,"water"))
		_check(_player().area=="room" and _player().room=="sea_1","click deep doorway enters cave")
		await _capture("sea-entry-%d.png"%size.x)
		var node:Dictionary=Rooms.nodes("sea_1").values()[1]
		_player().x=node.x-30;_player().y=node.y-15
		await _settle();await _click(main.hud.slots[0].button.get_global_rect().get_center())
		_check(main.active_tool=="pickaxe","click selects actual pickaxe in cave")
		await _click(_world_point(Vector2(node.x,node.y),"room"))
		_check(_player().activity.get("kind")=="room_mine","world click starts cave mining")
		main.world.tick(1);await _settle();await _capture("mining-%d.png"%size.x)
		await _tap(KEY_M);_check(main.room_atlas.visible,"M shows actual floor map")
		await _capture("sea-map-%d.png"%size.x)
		await _tap(KEY_ESCAPE)
		_check(not main.room_atlas.visible,"Esc closes floor map")
		await _tap(KEY_P);_check(_player().activity.is_empty(),"P cancels cave mining")
		for id in ["mine_1","mine_2","mine_3","market","clinic","bathhouse","carpenter","smith","fishery","townhall","farmhouse","east_house","orchard_house","restaurant","greenhouse"]:
			Rooms._arrive(main.world.data,_player(),id)
			if id=="bathhouse":
				_player().x=400;_player().y=560;_player().stamina=20;main.world.data.minute=720;main.world.data.money=10
				await _settle();await _tap(KEY_E)
				_check(_player().activity.get("kind")=="town_bath","E starts bath from actual pool")
				main.world.tick(8.1);_check(_player().stamina>70,"pool bathing restores stamina")
			if id.begins_with("mine_"): _player().x=Rooms.onward(id).x;_player().y=Rooms.onward(id).y
			await _settle();await _capture("%s-%d.png"%[id,size.x])
			_check(Rooms.can_stand(id,Vector2(_player().x,_player().y)),id+" spawn reachable")
	finished=true
	print("ROOMS UI: %d checks, %d failures; %s"%[checks,failures,evidence]);quit(0 if failures==0 else 1)
func _settle(seconds:float=0.14)->void:
	await create_timer(seconds).timeout
	await process_frame
	RenderingServer.force_draw(false)

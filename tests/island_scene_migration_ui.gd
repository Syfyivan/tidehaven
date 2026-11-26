extends "res://tests/island_ui_checks.gd"
func _run() -> void:
	evidence=ProjectSettings.globalize_path("res://artifacts/scene-migration-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate()
	main.save_path=evidence.path_join("world.json")
	root.add_child(main)
	main.automated=true
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	var changed:=Vector2.ZERO
	for y in range(480,824,32):
		for x in range(720,1200,32):
			var at:=Vector2(x+16,y+16)
			if IslandMap.v11_terrain(at)=="grass" and IslandMap.terrain(at)=="building": changed=at
	_fixture_player("island",changed)
	main.world.data.chart.visited=true
	var coast:=Archipelago.island_position(main.world.data.chart)
	main.world.data.navigation.x=coast.x
	main.world.data.navigation.y=coast.y
	main.world.data.navigation.anchored=true
	main.world.data.island.plots[Farming.plot_key(changed)]={"crop":"seed","growth":3,"watered":true,"covered":true,"dead":false}
	await _tap(KEY_ESCAPE)
	await _click(main.return_title_button.get_global_rect().get_center())
	var historical:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(main.save_path))
	historical.version=11;historical.state.version=11
	for key in ["rooms","gardens","restaurant","threats","wardrobe","housing","journal","stories"]:historical.state.erase(key)
	for player in historical.state.players.values():player.erase("room");player.erase("dive_status")
	var file:=FileAccess.open(main.save_path,FileAccess.WRITE);file.store_string(JSON.stringify(historical));file.close()
	var original:=FileAccess.get_file_as_string(main.save_path)
	await _click(main.continue_button.get_global_rect().get_center())
	_check(main.mode=="solo","Continue accepts a historical v11 location under the new building")
	_check(FileAccess.get_file_as_string(main.save_path+".before-scene-0.11.3")==original,"scene backup preserves exact original save bytes")
	_check(IslandMap.can_stand(Vector2(_player().x,_player().y)),"Continue recovers walkable feet")
	var plots:Dictionary=main.world.data.island.plots.duplicate(true)
	_check(plots.size()==1 and plots.values()[0].growth==3 and plots.values()[0].covered,"Continue preserves crop age and shelter")
	await _tap(KEY_ESCAPE)
	await _click(main.return_title_button.get_global_rect().get_center())
	await _click(main.continue_button.get_global_rect().get_center())
	_check(main.mode=="solo" and main.world.data.island.plots==plots,"saved migrated scene continues without a second relocation")
	_check(FileAccess.get_file_as_string(main.save_path+".before-scene-0.11.3")==original,"normal autosaves cannot replace the pre-scene backup")
	finished=true
	print("SCENE MIGRATION UI: %d checks, %d failures; %s"%[checks,failures,evidence])
	quit(0 if failures==0 else 1)

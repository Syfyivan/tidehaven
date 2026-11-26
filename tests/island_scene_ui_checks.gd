extends "res://tests/island_ui_checks.gd"
const Tiles=preload("res://scripts/island_tiles.gd")
func _run() -> void:
	evidence=ProjectSettings.globalize_path("res://artifacts/island-scene-ui-%d" % Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate()
	main.save_path=evidence.path_join("world.json")
	root.add_child(main)
	main.automated=true
	create_timer(90).timeout.connect(func():
		if not finished: quit(1))
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	main.world.data.minute=720.0
	main.world.data.island.homestead.rented=true
	for point in [Vector2(960,820),Vector2(1400,430),Vector2(1400,912),Vector2(2592,830),IslandMap.YARD_GATE+Vector2(50,0),IslandMap.DOCK,Vector2(1400,1260)]:
		_fixture_player("island",IslandMap.recover_standing_point(point))
		await _settle()
		await _capture("scene-%d-%d.png"%[point.x,point.y])
	for day in [29,57,85]:
		main.world.data.day=day
		_fixture_player("island",Vector2(1400,912))
		await _settle()
		await _capture("shops-"+Tiles.season(day)+".png")
	main.world.data.day=1
	root.size=Vector2i(960,600)
	_fixture_player("island",IslandMap.YARD_GATE+Vector2(50,0))
	await _settle()
	await _capture("yard-small.png")
	await _tap(KEY_M)
	await _click(main.island_atlas.region_buttons.harbor.get_global_rect().get_center())
	await _capture("map-harbor.png")
	await _tap(KEY_ESCAPE)
	finished=true
	print("ISLAND SCENE UI: %d checks, %d failures; evidence: %s"%[checks,failures,evidence])
	quit(0 if failures==0 else 1)

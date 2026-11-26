extends "res://tests/island_ui_checks.gd"
## Actual renderer, fixed isolated world positions; screenshots are not human acceptance.
const Surface = preload("res://scripts/island_surface.gd")

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/terrain-018/ui-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world.json")
	root.add_child(main)
	main.automated = true
	create_timer(120).timeout.connect(func():
		if not finished:
			printerr("FAIL terrain screenshot watchdog")
			quit(2))
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	_check(main.mode == "solo", "normal new-game entry opens isolated terrain world")
	main.set_physics_process(false)
	main.world.data.minute = 720.0
	main.world.data.island.homestead.rented = true
	var sites := {
		"yard-gate": IslandMap.YARD_GATE + Vector2(96,0),
		"yard-trees": Vector2(2320,1904),
		"town-junction": Vector2(1264,1264),
		"plaza-north": Vector2(1488,640),
		# The smith occupies x1448..1704, y1104..1232. Stand on the main road,
		# not inside that facade; the southern paving edge remains in this page.
		"plaza-south": Vector2(1344,1190),
		"pond-bank": Vector2(640,430),
	}
	for shape in [Vector2i(960,600),Vector2i(1280,800)]:
		root.size = shape
		for day in [1,29,57,85]:
			main.world.data.day = day
			for label: String in sites:
				var at: Vector2 = IslandMap.nearby_standing_point(sites[label])
				_fixture_player("island",at)
				var before: String = JSON.stringify(main.world.data)
				await _settle(0.2)
				_check(JSON.stringify(main.world.data) == before, "terrain rendering does not rewrite world progress " + label)
				_check(IslandMap.can_stand(at), "same legal foothold remains on %s at %s (%s)" % [label,at,IslandMap.terrain(at)])
				await _capture("%s-day%d-%d.png" % [label,day,shape.x])
	finished = true
	print("TERRAIN SEAMS UI: %d checks, %d failures; evidence: %s" % [checks,failures,evidence])
	quit(0 if failures == 0 else 1)

extends "res://tests/island_ui_checks.gd"
## Compare the rendered map under its interaction overlays, not just click routing.

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/map-overlay-%d" % int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280, 800)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world.json")
	root.add_child(main)
	main.save_path = evidence.path_join("world.json")
	main.automated = true
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	main.set_physics_process(false)
	main.set_process(false) # Keep the same atlas data/draw state for pixel comparisons.
	_fixture_player("island", Vector2(1088, 480))
	main._update_hud()
	await _tap(KEY_M)
	await _clear_interior(main.island_atlas.region_buttons.harbor, "region-hover")
	await _click(main.island_atlas.region_buttons.harbor.get_global_rect().get_center())
	await _clear_interior(main.island_atlas.page_buttons["1,0"], "selected-page")
	await _clear_interior(main.island_atlas.page_buttons["2,0"], "page-hover")
	await _capture("atlas-overlays.png")
	finished = true
	print("MAP OVERLAYS: %d checks, %d failures; evidence: %s" % [checks, failures, evidence])
	quit(0 if failures == 0 else 1)

func _clear_interior(button: Button, label: String) -> void:
	var shown: StyleBox = button.get_theme_stylebox("normal" if label == "selected-page" else "hover")
	# The non-rendering suite still protects the transparent-centre contract.
	_check(shown is StyleBoxFlat and not shown.draw_center, label + ": outline does not paint over map contents")
	if DisplayServer.get_name() == "headless":
		return
	var bounds := button.get_global_rect()
	var caption: String = button.text
	button.text = "" # Labels remain allowed; only the background must be transparent.
	button.hide()
	await _move_mouse(Vector2(20, 20))
	await RenderingServer.frame_post_draw
	var original: Image = root.get_texture().get_image()
	button.show()
	if label != "selected-page":
		await _move_mouse(bounds.get_center())
	await RenderingServer.frame_post_draw
	var overlaid: Image = root.get_texture().get_image()
	var matching := true
	for row in range(1, 6):
		for column in range(1, 6):
			var sample := Vector2i(bounds.position + bounds.size * Vector2(column / 6.0, row / 6.0))
			matching = matching and original.get_pixelv(sample) == overlaid.get_pixelv(sample)
	_check(matching, label + ": 25 interior pixels preserve the original terrain beneath the visible control")
	button.text = caption

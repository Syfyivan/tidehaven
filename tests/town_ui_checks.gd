extends "res://tests/island_ui_checks.gd"
## Focused rendered rerun for the new town and wilderness input paths.
func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/town-ui-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world.json")
	root.add_child(main)
	main.save_path = evidence.path_join("world.json")
	main.automated = true
	create_timer(60).timeout.connect(func():
		if not finished:
			printerr("FAIL town UI exceeded 60 seconds")
			quit(1))
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	_check(main.world.data.island.plots.is_empty(), "a new island gives no pre-tilled farmland")
	await _town_input_checks()
	# Server replies identify their own speaker, not whichever request came last.
	main.dialogue_ui.hide()
	main.pending_talk = "su_qin"
	main._action_message("林穗：旧回复", "lin_sui")
	_check(not main.dialogue_ui.visible and main.pending_talk == "su_qin", "an earlier speaker response cannot consume a later talk request")
	main._action_message("苏芩：新的回复", "su_qin")
	_check(main.dialogue_ui.visible and "苏芩" in main.dialogue_ui.speaker.text, "matching reply opens the correct speaker")
	main.dialogue_ui.hide()
	await _tap(KEY_B)
	main.pending_talk = "su_qin"
	main._action_message("苏芩：迟到回复", "su_qin")
	_check(main.inventory_ui.visible and not main.dialogue_ui.visible, "a delayed conversation never covers a subsequently opened backpack")
	await _tap(KEY_B)
	_fixture_player("island", Vector2(1088, 480))
	main.world.data.minute = 480.01
	main.active_tool = "hook"
	main.current_options = []
	main.hud_clock = -100.0
	await _click(_world_point(Vector2(1088, 480), "island"))
	_check(main.dialogue_ui.visible and "林穗" in main.dialogue_ui.speaker.text, "click at opening time resolves the newly arrived resident even before HUD options refresh")
	main.hud_clock = 0.0
	await _tap(KEY_ESCAPE)
	finished = true
	print("TOWN UI CHECKS: %d checks, %d failures; evidence: %s" % [checks, failures, evidence])
	quit(0 if failures == 0 else 1)

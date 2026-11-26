extends "res://tests/stories_ui_checks.gd"
const Portraits = preload("res://scripts/portrait_art.gd")
const CharacterArt = preload("res://scripts/character_art.gd")
const Daily = preload("res://scripts/resident_dialogue.gd")

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/ui-018/skin-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world.json")
	root.add_child(main)
	main.automated = true
	create_timer(120).timeout.connect(func():
		if not finished: quit(2))
	await _settle()
	await _capture("title.png")
	await _click(main.new_game_button.get_global_rect().get_center())
	main.set_physics_process(false)
	for shape in [Vector2i(1280,800), Vector2i(960,600)]:
		root.size = shape
		main.world = World.new()
		main.world.join("host", "旅人")
		main.world.data.journal.tide_speech = true
		for id: String in Town.NPCS:
			visit(id)
			await _settle(0.04)
			await _click(_world_point(Town.position(id,660,main.world.data), _player().area))
			var ui = main.dialogue_ui
			_check(ui.visible and ui.portrait.visible, "actual conversation shows portrait " + id)
			_check(not main.hud.toolbar.visible and main.hud.quick_buttons.all(func(button:Button): return not button.visible), "conversation hides toolbar behind bottom frame " + id)
			var texture: AtlasTexture = ui.portrait.texture
			_check(texture != null and texture.region == Rect2(0,0,64,64) and texture.atlas.resource_path.get_file() == CharacterArt.NPC_SHEETS[id].resource_path.get_file(), "portrait identity matches complete world sprite " + id)
			_check(not ui.portrait.get_global_rect().intersects(ui.body_scroll.get_global_rect()), "portrait never covers readable text " + id)
			await choose(str(Stories.ARCS[id].title))
			_check(ui.topic.text == Stories.ARCS[id].title and ui.body.text.begins_with(Stories.ARCS[id].steps[0].text), "first screen starts with authored situation, not duplicated heading " + id)
			_check(ui.body_scroll.size.y >= ui.body.get_theme_font("font").get_height(20) * 3 + 8, "two responses leave at least three body lines " + id)
			if id in ["xu_an", "chen_yu", "lu_zhou"]: await _capture("dialogue-%s-%d.png" % [id,shape.x])
			await _tap(KEY_ESCAPE)
			await _click(_world_point(Town.position(id,660,main.world.data), _player().area))
			_check(ui.body.text.contains(Daily.line(main.world.data,"host",id)), "repeat visit shows this person's daily voice " + id)
			_check(main.world.data.journal.host.friendship[id] == 2, "repeated UI talk cannot farm affection " + id)
			if id == "lin_sui": await _capture("daily-%d.png" % shape.x)
			await _tap(KEY_ESCAPE)
		for id: String in Ocean.NPCS:
			visit(id)
			await _settle(0.04)
			await _click(_world_point(Ocean.position(id), _player().area))
			var ui = main.dialogue_ui
			_check(ui.visible and ui.portrait.visible and ui.portrait_frame.visible, "ocean NPC displays matching 64x64 portrait " + id)
			var otex: AtlasTexture = ui.portrait.texture
			_check(otex != null and otex.region == Rect2(0,0,64,64) and not ui.portrait.get_global_rect().intersects(ui.body_scroll.get_global_rect()), "ocean portrait crisp and never covers text " + id)
			await choose(str(Stories.ARCS[id].title))
			_check(ui.body_scroll.size.x == 830 and ui.body.text.begins_with(Stories.ARCS[id].steps[0].text), "ocean story begins with situation " + id)
			_check(ui.body_scroll.size.y >= ui.body.get_theme_font("font").get_height(20) * 3 + 8, "ocean answers do not squeeze out situation " + id)
			if id == "tai_lu": await _capture("ocean-dialogue-%d.png" % shape.x)
			await _click(ui.close_button.get_global_rect().get_center())
			_check(not ui.visible, "close button works after scrolling " + id)
			await _click(_world_point(Ocean.position(id), _player().area))
			_check(ui.body.text.contains(Daily.line(main.world.data,"host",id)), "sea daily voice uses the same conversation UI " + id)
			_check(main.world.data.journal.host.friendship[id] == 2, "sea UI repeats cannot farm affection " + id)
			await _tap(KEY_ESCAPE)
		main.dialogue_ui.present({"name":"远方船客","role":"旅人"}, "远方船客：顺风借过。", [], "missing_portrait_id")
		_check(main.dialogue_ui.visible and not main.dialogue_ui.portrait.visible and main.dialogue_ui.body_scroll.size.x == 1062, "unregistered speaker still falls back cleanly to full-width layout")
		main.dialogue_ui.hide()
		_fixture_player("deck", Vector2(480,288))
		main.world.data.navigation.anchored = true
		_player().bag = Inventory.empty_slots(12)
		Inventory.add(_player().bag,"axe",1)
		Inventory.add(_player().bag,"wood",999)
		await _settle()
		await _click(main.hud.slots[0].button.get_global_rect().get_center())
		_check(main.active_tool == "axe", "native slot still equips on one click")
		await _capture("deck-toolbar-%d.png" % shape.x)
		await _tap(KEY_ESCAPE)
		await _capture("pause-%d.png" % shape.x)
		await _tap(KEY_ESCAPE)
		_fixture_player("water", Vector2(500,400))
		_player().oxygen = 20
		await _settle()
		_check(main.hud.oxygen_box.visible and main.hud.oxygen_label.get_theme_color("font_color").r > 0.5, "underwater oxygen remains legible with danger color")
		await _capture("underwater-%d.png" % shape.x)
	finished = true
	print("DIALOGUE SKIN UI: %d checks, %d failures; evidence: %s" % [checks,failures,evidence])
	quit(0 if failures == 0 else 1)

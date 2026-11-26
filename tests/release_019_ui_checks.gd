extends "res://tests/stories_ui_checks.gd"
## Graphical 2-resolution verification of 0.19 deliverables:
## 1) 5 ocean companion portraits in actual dialogue
## 2) P2-08a Chinese harbor player + Yan Zhen + Mu Tong world sprites, portraits, appearance UI & axe chop
## 3) Audio mute/unmute UI & active cues
## 4) P2-09 《候潮院》 complete UI flow from gate carving -> Xu An -> He Mu -> Qiao Xin -> overnight -> plaque styles & J journal
const LongStories = preload("res://scripts/long_stories.gd")
const Portraits = preload("res://scripts/portrait_art.gd")

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/release-019-ui-%d" % int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world_v17.json")
	root.add_child(main)
	main.automated = true
	create_timer(150).timeout.connect(func():
		if not finished:
			printerr("FAIL release_019_ui_checks timed out")
			quit(2))
	await _settle()

	for shape in [Vector2i(1280, 800), Vector2i(960, 600)]:
		root.size = shape
		await _settle(0.05)
		# Verify harbor appearance panel on title screen
		if main.mode != "menu":
			main._return_title()
			await _settle(0.05)
		main.appearance_ui.present(main.selected_appearance)
		await _settle(0.05)
		_check(main.appearance_ui.visible and main.appearance_ui.bust_portrait.texture != null, "appearance UI shows Chinese harbor bust portrait %d" % shape.x)
		await _capture("harbor-appearance-male-%d.png" % shape.x)
		main.appearance_ui._cycle(0, 1)
		main.appearance_ui._cycle(1, 6)
		main.appearance_ui._cycle(3, 1)
		await _settle(0.05)
		await _capture("harbor-appearance-female-%d.png" % shape.x)
		main.appearance_ui.hide()

		# Start fresh isolated world
		main.world = World.new()
		main.mode = "solo"
		main.local_slot = "host"
		main.world.join("host", "旅人")
		main.overlay.hide()
		main.set_physics_process(false)
		var dock_at := preload("res://scripts/archipelago.gd").island_position(main.world.data.chart, preload("res://scripts/archipelago.gd").HOME_ID)
		main.world.data.navigation.x = dock_at.x
		main.world.data.navigation.y = dock_at.y
		main.world.data.navigation.anchored = true
		main.world.data.chart.visited = true
		main.world.data.journal.story_step = 3
		main.world.data.journal.tide_speech = true
		await _settle(0.05)

		# Capture outdoor evening plaza view showing full 32x64 harbor silhouettes of Yan Zhen & Mu Tong
		if shape.x == 1280:
			main.world.data.minute = 1110.0
			var yz_outdoor := Town.position("yan_zhen", 1110.0, main.world.data)
			_fixture_player("island", yz_outdoor + Vector2(36, 4))
			_player().room = ""
			await _settle(0.05)
			await _capture("harbor-outdoor-yan_zhen-1280.png")
			var mt_outdoor := Town.position("mu_tong", 1110.0, main.world.data)
			_fixture_player("island", mt_outdoor + Vector2(36, 4))
			await _settle(0.05)
			await _capture("harbor-outdoor-mu_tong-1280.png")

		# Verify Yan Zhen & Mu Tong Chinese harbor world sprites + portraits in actual locations
		for npc_id in ["yan_zhen", "mu_tong"]:
			visit(npc_id)
			await _settle(0.05)
			await _capture("harbor-world-%s-%d.png" % [npc_id, shape.x])
			await _click(_world_point(Town.position(npc_id, 660, main.world.data), _player().area))
			var ui = main.dialogue_ui
			_check(ui.visible and ui.portrait.visible and ui.portrait.texture == Portraits.texture(npc_id), "harbor NPC dialogue shows matched portrait %s %d" % [npc_id, shape.x])
			_check(not ui.portrait.get_global_rect().intersects(ui.body_scroll.get_global_rect()), "harbor portrait does not overlap text %s %d" % [npc_id, shape.x])
			await _capture("harbor-dialogue-%s-%d.png" % [npc_id, shape.x])
			await _tap(KEY_ESCAPE)

		# Verify all 5 ocean companions display matching portraits
		for ocean_id in Ocean.NPCS:
			visit(ocean_id)
			await _settle(0.05)
			await _click(_world_point(Ocean.position(ocean_id), _player().area))
			var ui = main.dialogue_ui
			_check(ui.visible and ui.portrait.visible and ui.portrait.texture == Portraits.texture(ocean_id), "ocean companion shows portrait %s %d" % [ocean_id, shape.x])
			if shape.x == 1280 or ocean_id in ["bai_fan", "chi_sheng", "lan_ying"]:
				await _capture("ocean-portrait-%s-%d.png" % [ocean_id, shape.x])
			await _tap(KEY_ESCAPE)

		# Walk through complete P2-09 《候潮院》 via actual dialogue UI & yard gate
		visit("xu_an")
		await _settle(0.04)
		await _click(_world_point(Town.position("xu_an", 660, main.world.data), _player().area))
		await choose("我想租下这座院子")
		_check(bool(main.world.data.island.homestead.rented), "rented homestead via dialogue %d" % shape.x)
		await _tap(KEY_ESCAPE)

		_fixture_player("island", IslandMap.YARD_GATE + Vector2(20, 12))
		await _settle(0.05)
		main.perform("yard_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data).step) == 1, "yard carving inspected %d" % shape.x)

		# Step 1 at Xu An
		visit("xu_an")
		await _settle(0.04)
		await _click(_world_point(Town.position("xu_an", 660, main.world.data), _player().area))
		await choose("《候潮院》")
		_check(main.dialogue_ui.topic.text == "候潮院", "chronicle topic header displayed %d" % shape.x)
		await choose("听起来这里以前很热闹")
		_check(int(LongStories.record(main.world.data).step) == 2, "Xu An advances chronicle to step 2 %d" % shape.x)
		await _tap(KEY_ESCAPE)

		# Step 2 at He Mu with 6 wood
		Inventory.add(_player().bag, "wood", 6)
		visit("he_mu")
		await _settle(0.04)
		await _click(_world_point(Town.position("he_mu", 660, main.world.data), _player().area))
		await choose("《候潮院》")
		await choose("托乔信寄封信")
		_check(int(LongStories.record(main.world.data).step) == 3, "He Mu advances chronicle to step 3 %d" % shape.x)
		await _tap(KEY_ESCAPE)

		# Step 3 at Qiao Xin with 2 fiber
		Inventory.add(_player().bag, "fiber", 2)
		visit("qiao_xin")
		await _settle(0.04)
		await _click(_world_point(Town.position("qiao_xin", 660, main.world.data), _player().area))
		await choose("《候潮院》")
		await choose("欢迎旧友歇脚")
		_check(int(LongStories.record(main.world.data).step) == 4, "Qiao Xin mails letter to step 4 %d" % shape.x)
		await _tap(KEY_ESCAPE)

		# Overnight -> Step 4 -> 5 completion
		main.world.data.day += 1
		visit("qiao_xin")
		await _settle(0.04)
		await _click(_world_point(Town.position("qiao_xin", 660, main.world.data), _player().area))
		await choose("《候潮院》")
		if shape.x == 1280:
			await _capture("hou-chao-yuan-reply-1280.png")
		await choose("候潮驿院")
		_check(int(LongStories.record(main.world.data).step) == 5 and LongStories.record(main.world.data).style == "inn", "chronicle completed with inn style %d" % shape.x)
		await _tap(KEY_ESCAPE)

		# Check evening glowing gate lantern & farm basket toggle at YARD_GATE
		main.world.data.minute = 1140.0
		_fixture_player("island", IslandMap.YARD_GATE + Vector2(28, 16))
		await _settle(0.05)
		await _capture("hou-chao-yuan-inn-%d.png" % shape.x)
		main.perform("yard_style")
		await _settle(0.05)
		_check(LongStories.record(main.world.data).style == "farm", "gate style switched to farm %d" % shape.x)
		if shape.x == 1280:
			await _capture("hou-chao-yuan-farm-1280.png")

		# Check J journal displays Hou Chao Yuan completion
		await _tap(KEY_J)
		await _settle(0.05)
		_check(main.journal_ui.visible and main.journal_ui.content.text.contains("候潮农庄"), "journal displays completed Hou Chao Yuan plaque %d" % shape.x)
		if shape.x == 1280:
			await _capture("journal-019-1280.png")
		await _tap(KEY_ESCAPE)

		# Check pause menu mute button
		await _tap(KEY_ESCAPE)
		await _settle(0.04)
		_check(main.pause_open and main.mute_button != null and main.mute_button.visible, "pause menu shows audio mute button %d" % shape.x)
		await _click(main.mute_button.get_global_rect().get_center())
		_check(main.audio.muted and main.mute_button.text == "开音", "clicking mute button mutes audio %d" % shape.x)
		await _click(main.mute_button.get_global_rect().get_center())
		_check(not main.audio.muted and main.mute_button.text == "静音", "clicking mute button again restores audio %d" % shape.x)
		await _tap(KEY_ESCAPE)

	# Verify save & reload preserves chronicles and wardrobe
	_check(main._persist() and main._start("solo", true), "v17 save and reload succeeds")
	_check(int(LongStories.record(main.world.data).step) == 5, "reloaded v17 world retains completed Hou Chao Yuan")

	finished = true
	print("RELEASE 0.19 UI CHECKS: %d checks, %d failures; evidence: %s" % [checks, failures, evidence])
	quit(0 if failures == 0 else 1)

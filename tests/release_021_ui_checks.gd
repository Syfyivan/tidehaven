extends "res://tests/stories_ui_checks.gd"
## Graphical 2-resolution verification of 0.21 deliverables:
## 1) Original redistributable world sprites + portraits for all 5 ocean companions (bai_fan, chi_sheng, chao_jia, tai_lu, lan_ying)
## 2) P2-14 《开门能看见海》 full UI flow (workshop_inspect -> He Mu -> Yan Zhen -> Bai Fan -> overnight He Mu -> workshop & cabin lamp/breeze)
## 3) P2-20 《歪萝卜也能上桌》 full UI flow (farm_inspect -> Tian Qing -> Lin Sui -> Chen Yu -> overnight Tian Qing -> basket/crock)
## 4) P2-28 《留一把椅子》 full UI flow (pirate_inspect -> Chi Sheng -> Zhou Chao -> Chi Sheng -> overnight Chen Yu -> 3-way porch rule)
## 5) P2-29 《今年的沙滩》 full UI flow (reef_inspect -> Chao Jia -> Lu Zhou -> Tai Lu -> overnight Chao Jia -> sand/marker)
## 6) J Journal 8-chronicle summary + v19 save & reload
const LongStories = preload("res://scripts/long_stories.gd")
const Portraits = preload("res://scripts/portrait_art.gd")
const OceanArt = preload("res://scripts/ocean_resident_art.gd")

func _dock_island(id: String) -> void:
	var coast := Archipelago.island_position(main.world.data.chart, id)
	main.world.data.navigation.x = coast.x
	main.world.data.navigation.y = coast.y
	main.world.data.navigation.anchored = true

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/release-021-ui-%d" % int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world_v19.json")
	root.add_child(main)
	main.automated = true
	create_timer(180).timeout.connect(func():
		if not finished:
			printerr("FAIL release_021_ui_checks timed out")
			quit(2))
	await _settle()

	for shape in [Vector2i(1280, 800), Vector2i(960, 600)]:
		root.size = shape
		await _settle(0.05)
		main.world = World.new()
		main.mode = "solo"
		main.local_slot = "host"
		main.world.join("host", "旅人")
		main.overlay.hide()
		main.set_physics_process(false)
		_dock_island(Archipelago.HOME_ID)
		main.world.data.chart.visited = true
		main.world.data.journal.story_step = 3
		main.world.data.journal.tide_speech = true
		main.world.data.rooms.opened.sea = 3
		main.world.data.island.homestead.rented = true
		main.world.data.housing.level = 1
		main.world.data.restaurant.rented = true
		await _settle(0.05)

		# 1. Verify all 5 ocean companions render original world sprites + portraits cleanly
		for ocean_id in ["bai_fan", "chi_sheng", "chao_jia", "tai_lu", "lan_ying"]:
			var room_id: String = Ocean.NPCS[ocean_id].room
			if room_id.begins_with("island_"):
				_dock_island(room_id)
			else:
				_dock_island(Archipelago.HOME_ID)
			visit(ocean_id)
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			if shape.x == 1280:
				await _capture("ocean-world-%s-1280.png" % ocean_id)
			await _click(_world_point(Ocean.position(ocean_id), _player().area))
			var ui = main.dialogue_ui
			_check(ui.visible and ui.portrait.visible and ui.portrait.texture == Portraits.texture(ocean_id), "ocean NPC dialogue portrait %s %d" % [ocean_id, shape.x])
			_check(OceanArt.SOURCES[ocean_id].resource_path.begins_with("res://assets/characters/ocean/"), "ocean NPC uses original world sprite %s %d" % [ocean_id, shape.x])
			await _tap(KEY_ESCAPE)

		# 2. Walk through P2-14 《开门能看见海》
		_dock_island(Archipelago.HOME_ID)
		_player().room = ""
		_fixture_player("island", IslandMap.LANDMARKS.carpenter.door + Vector2(0, 18))
		await _settle(0.04)
		main.perform("workshop_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "kan_jian_hai").step) == 1, "workshop_inspect starts kan_jian_hai %d" % shape.x)

		visit("he_mu")
		await _settle(0.04)
		await _click(_world_point(Town.position("he_mu", 660, main.world.data), _player().area))
		await choose("《开门能看见海》")
		_check(main.dialogue_ui.topic.text == "开门能看见海", "kan_jian_hai topic header %d" % shape.x)
		await choose("耐海盐的窗轴五金")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "wood", 4)
		Inventory.add(_player().bag, "ingot", 1)
		visit("yan_zhen")
		await _settle(0.04)
		await _click(_world_point(Town.position("yan_zhen", 660, main.world.data), _player().area))
		await choose("《开门能看见海》")
		await choose("去雾岬岛找白帆试风")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "rope", 1)
		_dock_island("island_mist")
		visit("bai_fan")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("bai_fan"), _player().area))
		await choose("《开门能看见海》")
		await choose("学会这个活结风钩")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		_dock_island(Archipelago.HOME_ID)
		visit("he_mu")
		await _settle(0.04)
		await _click(_world_point(Town.position("he_mu", 660, main.world.data), _player().area))
		await choose("《开门能看见海》")
		await choose("防潮风灯工角")
		_check(LongStories.record(main.world.data, "kan_jian_hai").style == "lamp", "kan_jian_hai completed with lamp style %d" % shape.x)
		await _tap(KEY_ESCAPE)

		# 3. Walk through P2-20 《歪萝卜也能上桌》
		_player().room = ""
		_fixture_player("island", IslandMap.LANDMARKS.farmhouse.door + Vector2(0, 18))
		await _settle(0.04)
		main.perform("farm_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "wai_luo_bo").step) == 1, "farm_inspect starts wai_luo_bo %d" % shape.x)

		visit("tian_qing")
		await _settle(0.04)
		await _click(_world_point(Town.position("tian_qing", 660, main.world.data), _player().area))
		await choose("《歪萝卜也能上桌》")
		await choose("我去超市跟林穗聊聊")
		await _tap(KEY_ESCAPE)

		visit("lin_sui")
		await _settle(0.04)
		await _click(_world_point(Town.position("lin_sui", 660, main.world.data), _player().area))
		await choose("《歪萝卜也能上桌》")
		await choose("去找陈鱼试菜")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "veg", 3)
		Inventory.add(_player().bag, "mushroom", 1)
		visit("chen_yu")
		await _settle(0.04)
		await _click(_world_point(Town.position("chen_yu", 660, main.world.data), _player().area))
		await choose("《歪萝卜也能上桌》")
		await choose("田间时令小钵")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		visit("tian_qing")
		await _settle(0.04)
		await _click(_world_point(Town.position("tian_qing", 660, main.world.data), _player().area))
		await choose("《歪萝卜也能上桌》")
		await choose("田间直供菜篓")
		_check(LongStories.record(main.world.data, "wai_luo_bo").style == "basket", "wai_luo_bo completed with basket style %d" % shape.x)
		await _tap(KEY_ESCAPE)

		if shape.x == 1280:
			main.world.data.minute = 1110.0
			_player().room = ""
			_fixture_player("island", IslandMap.LANDMARKS.carpenter.door + Vector2(28, 36))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("kan-jian-hai-porch-1280.png")
			_fixture_player("island", Vector2(1208, 1704))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("wai-luo-bo-porch-1280.png")

		# 4. Walk through P2-28 《留一把椅子》
		_dock_island("island_reef")
		visit("chi_sheng")
		await _settle(0.04)
		main.perform("pirate_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "liu_yi_ba_yi_zi").step) == 1, "pirate_inspect starts liu_yi_ba_yi_zi %d" % shape.x)

		await _click(_world_point(Ocean.position("chi_sheng"), _player().area))
		await choose("《留一把椅子》")
		await choose("先回渔铺问清楚")
		await _tap(KEY_ESCAPE)

		_dock_island(Archipelago.HOME_ID)
		visit("zhou_chao")
		await _settle(0.04)
		await _click(_world_point(Town.position("zhou_chao", 660, main.world.data), _player().area))
		await choose("《留一把椅子》")
		await choose("一码归一码")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "rope", 2)
		Inventory.add(_player().bag, "scrap", 2)
		_dock_island("island_reef")
		visit("chi_sheng")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("chi_sheng"), _player().area))
		await choose("《留一把椅子》")
		await choose("敢作敢当才像话")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		_dock_island(Archipelago.HOME_ID)
		visit("chen_yu")
		await _settle(0.04)
		await _click(_world_point(Town.position("chen_yu", 660, main.world.data), _player().area))
		await choose("《留一把椅子》")
		await choose("廊下矮凳席")
		_check(LongStories.record(main.world.data, "liu_yi_ba_yi_zi").style == "stool", "liu_yi_ba_yi_zi completed with stool style %d" % shape.x)
		await _tap(KEY_ESCAPE)

		if shape.x == 1280:
			_player().room = ""
			_fixture_player("island", IslandMap.LANDMARKS.restaurant.door + Vector2(-128, 34))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("liu-yi-ba-yi-zi-porch-1280.png")

		# 5. Walk through P2-29 《今年的沙滩》
		_dock_island("island_reef")
		Rooms._arrive(main.world.data, _player(), "island_reef", Ocean.position("chao_jia") + LongStories.REEF_OFFSET + Vector2(0, 20))
		await _settle(0.04)
		main.perform("reef_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "jin_nian_sha_tan").step) == 1, "reef_inspect starts jin_nian_sha_tan %d" % shape.x)

		visit("chao_jia")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("chao_jia"), _player().area))
		await choose("《今年的沙滩》")
		await choose("回岸边渔铺找陆舟")
		await _tap(KEY_ESCAPE)

		_dock_island(Archipelago.HOME_ID)
		visit("lu_zhou")
		await _settle(0.04)
		await _click(_world_point(Town.position("lu_zhou", 660, main.world.data), _player().area))
		await choose("《今年的沙滩》")
		await choose("去风栖岛找苔露")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "fiber", 3)
		_dock_island("island_wind")
		visit("tai_lu")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("tai_lu"), _player().area))
		await choose("《今年的沙滩》")
		await choose("顺着潮水留一道轻记号")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		_dock_island("island_reef")
		visit("chao_jia")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("chao_jia"), _player().area))
		await choose("《今年的沙滩》")
		await choose("向阳歇沙坪")
		_check(LongStories.record(main.world.data, "jin_nian_sha_tan").style == "sand", "jin_nian_sha_tan completed with sand style %d" % shape.x)
		await _tap(KEY_ESCAPE)

		if shape.x == 1280:
			Rooms._arrive(main.world.data, _player(), "island_reef", Ocean.position("chao_jia") + LongStories.REEF_OFFSET + Vector2(36, 20))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("jin-nian-sha-tan-reef-1280.png")

		# Verify J Journal shows all 4 new chronicles
		await _tap(KEY_J)
		await _settle(0.05)
		var jtxt: String = main.journal_ui.content.text
		_check(jtxt.contains("防潮风灯工角") and jtxt.contains("田间直供菜篓") and jtxt.contains("廊下矮凳席") and jtxt.contains("向阳歇沙坪"), "journal displays all 4 new 0.21 chronicle outcomes %d" % shape.x)
		if shape.x == 1280:
			await _capture("journal-021-1280.png")
		await _tap(KEY_ESCAPE)

	# Verify v19 save & reload preserves all chronicles
	_dock_island(Archipelago.HOME_ID)
	_player().room = ""
	_fixture_player("island", IslandMap.DOCK)
	_check(main._persist() and main._start("solo", true), "v19 save and reload succeeds")
	_check(int(LongStories.record(main.world.data, "kan_jian_hai").step) == 5 and int(LongStories.record(main.world.data, "wai_luo_bo").step) == 5 and int(LongStories.record(main.world.data, "liu_yi_ba_yi_zi").step) == 5 and int(LongStories.record(main.world.data, "jin_nian_sha_tan").step) == 5, "reloaded v19 world retains all 0.21 completed chronicles")

	finished = true
	print("RELEASE 0.21 UI CHECKS: %d checks, %d failures; evidence: %s" % [checks, failures, evidence])
	quit(0 if failures == 0 else 1)

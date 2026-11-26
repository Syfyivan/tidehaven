extends "res://tests/stories_ui_checks.gd"
## Graphical 2-resolution verification of 0.22 deliverables:
## 1) Original world sprites + 64x64 portraits for all 4 new characters (cen_po, a_yuan, mi_luo, san_jin)
## 2) New underwater habitat reef_grotto (entered from sea_2 coral arch, RoomAtlas M map, air pocket & exit)
## 3) P2-32 《这次不赶潮》 full UI flow (pilot_inspect -> Cen Po -> Xu An -> Bai Fan -> overnight Cen Po -> chair/chart)
## 4) P2-33 《空椅子展览》 full UI flow (chair_inspect -> A Yuan -> Lin Sui -> He Mu -> overnight A Yuan -> saloon & townhall gallery)
## 5) P2-34 《一口走不准的钟》 full UI flow (clock_inspect -> Mi Luo -> Gu Xing -> Yan Zhen -> overnight Mi Luo -> grotto chime)
## 6) P2-35 《这不是你的摊位》 full UI flow (morning Fishery shore San Jin -> Zhou Chao -> Lu Zhou -> Zhou Chao -> Reef San Jin pre/post tide_speech -> buoy)
## 7) J Journal 12-chronicle summary + v20 save & reload
const LongStories = preload("res://scripts/long_stories.gd")
const Portraits = preload("res://scripts/portrait_art.gd")
const CharacterArt = preload("res://scripts/character_art.gd")
const OceanArt = preload("res://scripts/ocean_resident_art.gd")

func _dock_island(id: String) -> void:
	var coast := Archipelago.island_position(main.world.data.chart, id)
	main.world.data.navigation.x = coast.x
	main.world.data.navigation.y = coast.y
	main.world.data.navigation.anchored = true

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/release-022-ui-%d" % int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world_v20.json")
	root.add_child(main)
	main.automated = true
	create_timer(210).timeout.connect(func():
		if not finished:
			printerr("FAIL release_022_ui_checks timed out")
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

		# 1. Verify sea_2 -> reef_grotto real doorway, M local map, and return exit
		Rooms._arrive(main.world.data, _player(), "sea_2", Rooms.GROTTO_ARCH + Vector2(0, 26))
		main.toast_clock = 0.0
		main._update_hud()
		await _settle(0.05)
		if shape.x == 1280:
			await _capture("sea2-grotto-arch-1280.png")
		main.perform("room_enter", {"id": "reef_grotto"})
		await _settle(0.05)
		_check(_player().room == "reef_grotto", "entered reef_grotto from sea_2 %d" % shape.x)
		await _tap(KEY_M)
		await _settle(0.05)
		_check(main.room_atlas.visible and main.room_atlas.title.text == "潮钟礁洞 · 55米", "reef_grotto displays RoomAtlas map %d" % shape.x)
		if shape.x == 1280:
			await _capture("reef-grotto-map-1280.png")
		await _tap(KEY_ESCAPE)

		# 2. Verify all 4 new characters render crisp world sprites + matched 64x64 portraits
		for town_id in ["cen_po", "a_yuan"]:
			_dock_island(Archipelago.HOME_ID)
			visit(town_id)
			var t_where := Town.location(town_id, 660, main.world.data)
			_fixture_player(t_where.area, t_where.at + Vector2(44, 0))
			_player().room = t_where.room
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			if shape.x == 1280:
				await _capture("world-%s-1280.png" % town_id)
			await _click(_world_point(Town.position(town_id, 660, main.world.data), _player().area))
			var ui = main.dialogue_ui
			_check(ui.visible and ui.portrait.visible and ui.portrait.texture == Portraits.texture(town_id), "new town NPC portrait %s %d" % [town_id, shape.x])
			_check(CharacterArt.NPC_SHEETS[town_id].resource_path.begins_with("res://assets/characters/harbor/"), "new town NPC original world sheet %s %d" % [town_id, shape.x])
			if shape.x == 1280:
				await _capture("dialogue-%s-1280.png" % town_id)
			await _tap(KEY_ESCAPE)

		for ocean_id in ["mi_luo", "san_jin"]:
			var room_id: String = Ocean.NPCS[ocean_id].room
			if room_id.begins_with("island_"):
				_dock_island(room_id)
			else:
				_dock_island(Archipelago.HOME_ID)
			visit(ocean_id)
			if ocean_id == "mi_luo":
				Rooms._arrive(main.world.data, _player(), room_id, Ocean.position("mi_luo") + Vector2(-48, 0))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			if shape.x == 1280:
				await _capture("world-%s-1280.png" % ocean_id)
			await _click(_world_point(Ocean.position(ocean_id), _player().area))
			var ui = main.dialogue_ui
			_check(ui.visible and ui.portrait.visible and ui.portrait.texture == Portraits.texture(ocean_id), "new ocean NPC portrait %s %d" % [ocean_id, shape.x])
			_check(OceanArt.SOURCES[ocean_id].resource_path.begins_with("res://assets/characters/ocean/"), "new ocean NPC original world sprite %s %d" % [ocean_id, shape.x])
			if shape.x == 1280:
				await _capture("dialogue-%s-1280.png" % ocean_id)
			await _tap(KEY_ESCAPE)

		# 3. Walk through P2-32 《这次不赶潮》
		_dock_island(Archipelago.HOME_ID)
		_player().room = ""
		_fixture_player("island", LongStories.PILOT_SITE + Vector2(0, 18))
		await _settle(0.04)
		main.perform("pilot_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "bu_gan_chao").step) == 1, "pilot_inspect starts bu_gan_chao %d" % shape.x)

		visit("cen_po")
		await _settle(0.04)
		await _click(_world_point(Town.position("cen_po", 660, main.world.data), _player().area))
		await choose("《这次不赶潮》")
		_check(main.dialogue_ui.topic.text == "这次不赶潮", "bu_gan_chao topic header %d" % shape.x)
		await choose("别摆迎客架子")
		await _tap(KEY_ESCAPE)

		visit("xu_an")
		await _settle(0.04)
		await _click(_world_point(Town.position("xu_an", 660, main.world.data), _player().area))
		await choose("《这次不赶潮》")
		await choose("带两份烤鱼去雾岬岛")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "cooked_fish", 2)
		_dock_island("island_mist")
		visit("bai_fan")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("bai_fan"), _player().area))
		await choose("《这次不赶潮》")
		await choose("回镇上找岑婆")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		_dock_island(Archipelago.HOME_ID)
		visit("cen_po")
		await _settle(0.04)
		await _click(_world_point(Town.position("cen_po", 660, main.world.data), _player().area))
		await choose("《这次不赶潮》")
		await choose("候船藤椅角")
		_check(LongStories.record(main.world.data, "bu_gan_chao").style == "chair", "bu_gan_chao completed with chair style %d" % shape.x)
		await _tap(KEY_ESCAPE)

		# 4. Walk through P2-33 《空椅子展览》
		Rooms._arrive(main.world.data, _player(), "restaurant", LongStories.CHAIR_SITE + Vector2(28, 12))
		await _settle(0.04)
		main.perform("chair_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "kong_yi_zi").step) == 1, "chair_inspect starts kong_yi_zi %d" % shape.x)

		visit("a_yuan")
		await _settle(0.04)
		await _click(_world_point(Town.position("a_yuan", 660, main.world.data), _player().area))
		await choose("《空椅子展览》")
		await choose("请林穗认认看")
		await _tap(KEY_ESCAPE)

		visit("lin_sui")
		await _settle(0.04)
		await _click(_world_point(Town.position("lin_sui", 660, main.world.data), _player().area))
		await choose("《空椅子展览》")
		await choose("找贺木做挂画木条")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "wood", 4)
		Inventory.add(_player().bag, "fiber", 2)
		visit("he_mu")
		await _settle(0.04)
		await _click(_world_point(Town.position("he_mu", 660, main.world.data), _player().area))
		await choose("《空椅子展览》")
		await choose("去找阿沅看布展")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		visit("a_yuan")
		await _settle(0.04)
		await _click(_world_point(Town.position("a_yuan", 660, main.world.data), _player().area))
		await choose("《空椅子展览》")
		await choose("镇公所日常画廊")
		_check(LongStories.record(main.world.data, "kong_yi_zi").style == "hall", "kong_yi_zi completed with hall style %d" % shape.x)
		await _tap(KEY_ESCAPE)

		if shape.x == 1280:
			Rooms._arrive(main.world.data, _player(), "restaurant", LongStories.CHAIR_SITE + Vector2(56, 20))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("kong-yi-zi-saloon-1280.png")
			Rooms._arrive(main.world.data, _player(), "townhall", Vector2(224, 304))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("kong-yi-zi-hall-1280.png")

		# 5. Walk through P2-34 《一口走不准的钟》
		Rooms._arrive(main.world.data, _player(), "reef_grotto", LongStories.CLOCK_SITE + Vector2(-28, 8))
		await _settle(0.04)
		main.perform("clock_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "zou_bu_zhun_zhong").step) == 1, "clock_inspect starts zou_bu_zhun_zhong %d" % shape.x)

		visit("mi_luo")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("mi_luo"), _player().area))
		await choose("《一口走不准的钟》")
		await choose("顾星专修测潮仪")
		await _tap(KEY_ESCAPE)

		visit("gu_xing")
		await _settle(0.04)
		await _click(_world_point(Town.position("gu_xing", 660, main.world.data), _player().area))
		await choose("《一口走不准的钟》")
		await choose("带材料去找严砧")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "ingot", 1)
		Inventory.add(_player().bag, "scrap", 2)
		visit("yan_zhen")
		await _settle(0.04)
		await _click(_world_point(Town.position("yan_zhen", 660, main.world.data), _player().area))
		await choose("《一口走不准的钟》")
		await choose("送去礁洞等米洛校好音簧")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		visit("mi_luo")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("mi_luo"), _player().area))
		await choose("《一口走不准的钟》")
		await choose("礁洞报潮八音钟")
		_check(LongStories.record(main.world.data, "zou_bu_zhun_zhong").style == "grotto", "zou_bu_zhun_zhong completed with grotto chime %d" % shape.x)
		await _tap(KEY_ESCAPE)

		if shape.x == 1280:
			Rooms._arrive(main.world.data, _player(), "reef_grotto", Vector2(430, 278))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("zou-bu-zhun-zhong-grotto-1280.png")

		# 6. Walk through P2-35 《这不是你的摊位》 (including morning coastal San Jin & pre/post tide_speech!)
		_dock_island(Archipelago.HOME_ID)
		main.world.data.minute = 480.0
		_player().room = ""
		_fixture_player("island", LongStories.SCALE_SITE + Vector2(56, 20))
		main.toast_clock = 0.0
		main._update_hud()
		await _settle(0.05)
		if shape.x == 1280:
			await _capture("san-jin-fishery-morning-1280.png")
		main.perform("scale_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "bu_shi_tan_wei").step) == 1, "scale_inspect starts bu_shi_tan_wei %d" % shape.x)

		visit("zhou_chao")
		await _settle(0.04)
		await _click(_world_point(Town.position("zhou_chao", 660, main.world.data), _player().area))
		await choose("《这不是你的摊位》")
		await choose("我去问问陆舟")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "wood", 3)
		Inventory.add(_player().bag, "rope", 1)
		visit("lu_zhou")
		await _settle(0.04)
		await _click(_world_point(Town.position("lu_zhou", 660, main.world.data), _player().area))
		await choose("《这不是你的摊位》")
		await choose("改用海苔引味")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "seaweed", 2)
		visit("zhou_chao")
		await _settle(0.04)
		await _click(_world_point(Town.position("zhou_chao", 660, main.world.data), _player().area))
		await choose("《这不是你的摊位》")
		await choose("去珊湾潮岸看看三斤")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		_dock_island("island_reef")
		visit("san_jin")
		await _settle(0.04)
		# Verify pre-tide_speech visible gesture in live UI!
		main.world.data.journal.tide_speech = false
		main.world.data.journal.story_step = 2
		await _click(_world_point(Ocean.position("san_jin"), _player().area))
		await choose("《这不是你的摊位》")
		_check(main.dialogue_ui.body.text.contains("条纹扇贝壳") and not main.dialogue_ui.body.text.contains("哼哼，珊湾这块石头"), "san_jin UI shows pure action before tide_speech %d" % shape.x)
		await _tap(KEY_ESCAPE)
		# Re-enable tide_speech and complete!
		main.world.data.journal.story_step = 3
		main.world.data.journal.tide_speech = true
		await _click(_world_point(Ocean.position("san_jin"), _player().area))
		await choose("《这不是你的摊位》")
		_check(main.dialogue_ui.body.text.contains("哼哼，珊湾这块石头"), "san_jin UI shows seal inner speech after tide_speech %d" % shape.x)
		await choose("浅滩浮球礼尚角")
		_check(LongStories.record(main.world.data, "bu_shi_tan_wei").style == "buoy", "bu_shi_tan_wei completed with buoy style %d" % shape.x)
		await _tap(KEY_ESCAPE)

		if shape.x == 1280:
			_dock_island(Archipelago.HOME_ID)
			main.world.data.minute = 480.0
			_player().room = ""
			_fixture_player("island", LongStories.PILOT_SITE + Vector2(44, 10))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("bu-gan-chao-dock-1280.png")
			_fixture_player("island", LongStories.SCALE_SITE + Vector2(-42, 16))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("bu-shi-tan-wei-coast-1280.png")

		# 7. Verify J Journal shows all 4 new 0.22 chronicles
		await _tap(KEY_J)
		await _settle(0.05)
		var jtxt: String = main.journal_ui.content.text
		_check(jtxt.contains("候船藤椅角") and jtxt.contains("镇公所日常画廊") and jtxt.contains("礁洞报潮八音钟") and jtxt.contains("浅滩浮球礼尚角"), "journal displays all 4 new 0.22 chronicle outcomes %d" % shape.x)
		if shape.x == 1280:
			await _capture("journal-022-1280.png")
		await _tap(KEY_ESCAPE)

	# Verify v20 save & reload preserves all 0.22 chronicles
	_dock_island(Archipelago.HOME_ID)
	_player().room = ""
	_fixture_player("island", IslandMap.DOCK)
	_check(main._persist() and main._start("solo", true), "v20 save and reload succeeds")
	_check(int(LongStories.record(main.world.data, "bu_gan_chao").step) == 5 and int(LongStories.record(main.world.data, "kong_yi_zi").step) == 5 and int(LongStories.record(main.world.data, "zou_bu_zhun_zhong").step) == 5 and int(LongStories.record(main.world.data, "bu_shi_tan_wei").step) == 5, "reloaded v20 world retains all 0.22 completed chronicles")

	finished = true
	print("RELEASE 0.22 UI CHECKS: %d checks, %d failures; evidence: %s" % [checks, failures, evidence])
	quit(0 if failures == 0 else 1)

extends "res://tests/stories_ui_checks.gd"
## Graphical 2-resolution verification of 0.23 deliverables:
## 1) P2-44 《一份用不上的救援记录》 full UI flow (rescue_inspect -> Lu Zhou -> Su Qin -> Sen Ke -> overnight Lu Zhou -> board & rack)
## 2) P2-45 《名字各不相同的草》 full UI flow (herb_inspect -> Mu Tong -> Wen Zhi -> Tai Lu -> overnight Mu Tong -> folio & stakes)
## 3) P2-46 《一张能用的误差表》 full UI flow (gauge_inspect -> Gu Xing -> Bai Fan -> Cen Po -> overnight Gu Xing -> brass & slate_tide)
## 4) P2-47 《被风认出来的旗》 full UI flow (pennant_inspect -> Xu Mian -> Bai Fan -> He Mu -> overnight Xu Mian -> 3-way raft pennant + synced M sea chart!)
## 5) J Journal 16-chronicle summary + v21 save & reload
const LongStories = preload("res://scripts/long_stories.gd")
const Portraits = preload("res://scripts/portrait_art.gd")

func _dock_island(id: String) -> void:
	var coast := Archipelago.island_position(main.world.data.chart, id)
	main.world.data.navigation.x = coast.x
	main.world.data.navigation.y = coast.y
	main.world.data.navigation.anchored = true

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/release-023-ui-%d" % int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world_v21.json")
	root.add_child(main)
	main.automated = true
	create_timer(240).timeout.connect(func():
		if not finished:
			printerr("FAIL release_023_ui_checks timed out")
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
		main.world.data.island.homestead.rented = true
		main.world.data.housing.level = 1
		main.world.data.restaurant.rented = true
		await _settle(0.05)

		# 1. Walk through P2-44 《一份用不上的救援记录》
		_dock_island(Archipelago.HOME_ID)
		_player().room = ""
		_fixture_player("island", LongStories.RESCUE_SITE + Vector2(0, 36))
		await _settle(0.04)
		main.perform("rescue_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "jiu_yuan_ji_lu").step) == 1, "rescue_inspect starts jiu_yuan_ji_lu %d" % shape.x)

		visit("lu_zhou")
		await _settle(0.04)
		await _click(_world_point(Town.position("lu_zhou", 660, main.world.data), _player().area))
		await choose("《一份用不上的救援记录》")
		_check(main.dialogue_ui.topic.text == "一份用不上的救援记录", "jiu_yuan_ji_lu topic header %d" % shape.x)
		if shape.x == 1280:
			await _capture("dialogue-lu-zhou-023-1280.png")
		await choose("风平浪静的日子练熟")
		await _tap(KEY_ESCAPE)

		visit("su_qin")
		await _settle(0.04)
		await _click(_world_point(Town.position("su_qin", 660, main.world.data), _player().area))
		await choose("《一份用不上的救援记录》")
		await choose("去找森柯约晴天演练")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "rope", 2)
		Inventory.add(_player().bag, "fiber", 2)
		visit("sen_ke")
		await _settle(0.04)
		await _click(_world_point(Town.position("sen_ke", 660, main.world.data), _player().area))
		await choose("《一份用不上的救援记录》")
		await choose("灯柱和屋脊对位置")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		visit("lu_zhou")
		await _settle(0.04)
		await _click(_world_point(Town.position("lu_zhou", 660, main.world.data), _player().area))
		await choose("《一份用不上的救援记录》")
		await choose("岸边救生圈绳架")
		_check(LongStories.record(main.world.data, "jiu_yuan_ji_lu").style == "rack", "jiu_yuan_ji_lu completed with rack style %d" % shape.x)
		await _tap(KEY_ESCAPE)

		if shape.x == 1280:
			_player().room = ""
			_fixture_player("island", LongStories.RESCUE_SITE + Vector2(-42, 36))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("harbor-rescue-rack-1280.png")

		# 2. Walk through P2-45 《名字各不相同的草》
		_dock_island(Archipelago.HOME_ID)
		_player().room = ""
		_fixture_player("island", LongStories.HERB_SITE + Vector2(28, 12))
		await _settle(0.04)
		main.perform("herb_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "ming_zi_bu_tong").step) == 1, "herb_inspect starts ming_zi_bu_tong %d" % shape.x)

		visit("mu_tong")
		await _settle(0.04)
		await _click(_world_point(Town.position("mu_tong", 660, main.world.data), _player().area))
		await choose("《名字各不相同的草》")
		await choose("问问温知老师")
		await _tap(KEY_ESCAPE)

		visit("wen_zhi")
		await _settle(0.04)
		await _click(_world_point(Town.position("wen_zhi", 660, main.world.data), _player().area))
		await choose("《名字各不相同的草》")
		await choose("去风栖岛找苔露")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "fiber", 2)
		Inventory.add(_player().bag, "mushroom", 1)
		_dock_island("island_wind")
		visit("tai_lu")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("tai_lu"), _player().area))
		await choose("《名字各不相同的草》")
		await choose("『听风耳』")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		_dock_island(Archipelago.HOME_ID)
		visit("mu_tong")
		await _settle(0.04)
		await _click(_world_point(Town.position("mu_tong", 660, main.world.data), _player().area))
		await choose("《名字各不相同的草》")
		await choose("四时生长图鉴匣")
		_check(LongStories.record(main.world.data, "ming_zi_bu_tong").style == "folio", "ming_zi_bu_tong completed with folio style %d" % shape.x)
		await _tap(KEY_ESCAPE)

		if shape.x == 1280:
			_player().room = ""
			_fixture_player("island", LongStories.HERB_SITE + Vector2(-56, 16))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("farmhouse-herb-folio-1280.png")
			Rooms._arrive(main.world.data, _player(), "townhall", Vector2(216, 268))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("townhall-herb-folio-1280.png")

		# 3. Walk through P2-46 《一张能用的误差表》
		_dock_island(Archipelago.HOME_ID)
		Rooms._arrive(main.world.data, _player(), "carpenter", LongStories.GAUGE_SITE + Vector2(-28, 16))
		await _settle(0.04)
		main.perform("gauge_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "wu_cha_biao").step) == 1, "gauge_inspect starts wu_cha_biao %d" % shape.x)

		visit("gu_xing")
		await _settle(0.04)
		await _click(_world_point(Town.position("gu_xing", 660, main.world.data), _player().area))
		await choose("《一张能用的误差表》")
		await choose("带材料去雾岬岛找白帆")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "wood", 2)
		Inventory.add(_player().bag, "scrap", 2)
		_dock_island("island_mist")
		visit("bai_fan")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("bai_fan"), _player().area))
		await choose("《一张能用的误差表》")
		await choose("回镇公所请教岑婆")
		await _tap(KEY_ESCAPE)

		_dock_island(Archipelago.HOME_ID)
		visit("cen_po")
		await _settle(0.04)
		await _click(_world_point(Town.position("cen_po", 660, main.world.data), _player().area))
		await choose("《一张能用的误差表》")
		await choose("正负一刻钟余量")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		visit("gu_xing")
		await _settle(0.04)
		await _click(_world_point(Town.position("gu_xing", 660, main.world.data), _player().area))
		await choose("《一张能用的误差表》")
		await choose("黄铜浮筒测潮仪")
		_check(LongStories.record(main.world.data, "wu_cha_biao").style == "brass", "wu_cha_biao completed with brass gauge %d" % shape.x)
		await _tap(KEY_ESCAPE)

		if shape.x == 1280:
			Rooms._arrive(main.world.data, _player(), "carpenter", LongStories.GAUGE_SITE + Vector2(48, 28))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("carpenter-brass-gauge-1280.png")

		# 4. Walk through P2-47 《被风认出来的旗》 + Raft Pennant & Sea Chart Sync!
		_dock_island(Archipelago.HOME_ID)
		Rooms._arrive(main.world.data, _player(), "market", LongStories.PENNANT_SITE + Vector2(-28, 16))
		await _settle(0.04)
		main.perform("pennant_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "feng_ren_chu_de_qi").step) == 1, "pennant_inspect starts feng_ren_chu_de_qi %d" % shape.x)

		visit("xu_mian")
		await _settle(0.04)
		await _click(_world_point(Town.position("xu_mian", 660, main.world.data), _player().area))
		await choose("《被风认出来的旗》")
		await choose("请教白帆船长")
		await _tap(KEY_ESCAPE)

		_dock_island("island_mist")
		visit("bai_fan")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("bai_fan"), _player().area))
		await choose("《被风认出来的旗》")
		await choose("带材料去找木匠贺木")
		await _tap(KEY_ESCAPE)

		_dock_island(Archipelago.HOME_ID)
		Inventory.add(_player().bag, "wood", 2)
		Inventory.add(_player().bag, "fiber", 3)
		Inventory.add(_player().bag, "rope", 1)
		visit("he_mu")
		await _settle(0.04)
		await _click(_world_point(Town.position("he_mu", 660, main.world.data), _player().area))
		await choose("《被风认出来的旗》")
		await choose("去超市找许棉挑旗子纹样")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		visit("xu_mian")
		await _settle(0.04)
		await _click(_world_point(Town.position("xu_mian", 660, main.world.data), _player().area))
		await choose("《被风认出来的旗》")
		await choose("潮青双燕尾旗")
		_check(LongStories.record(main.world.data, "feng_ren_chu_de_qi").style == "tide", "feng_ren_chu_de_qi completed with tide swallowtail pennant %d" % shape.x)
		await _tap(KEY_ESCAPE)

		if shape.x == 1280:
			Rooms._arrive(main.world.data, _player(), "market", LongStories.PENNANT_SITE + Vector2(-44, 18))
			main.toast_clock = 0.0
			main._update_hud()
			await _settle(0.05)
			await _capture("market-pennant-swatch-1280.png")

		# Board the raft and verify live bow pennant + synced M sea chart!
		Inventory.add(_player().bag, "compass", 1)
		var flag_tile := LongStories.pennant_tile_center(main.world.data)
		_player().area = "deck"
		_player().room = ""
		_player().x = flag_tile.x - 42.0
		_player().y = flag_tile.y + 18.0
		main.toast_clock = 0.0
		main._update_hud()
		await _settle(0.05)
		if shape.x == 1280:
			await _capture("raft-pennant-deck-1280.png")
		await _tap(KEY_M)
		await _settle(0.05)
		_check(main.chart_ui.visible and main.chart_ui.full_chart, "sea chart opens with synced raft pennant %d" % shape.x)
		if shape.x == 1280:
			await _capture("sea-chart-pennant-1280.png")
		await _tap(KEY_ESCAPE)
		await _settle(0.04)
		main.perform("pennant_style")
		await _settle(0.04)
		_check(LongStories.record(main.world.data, "feng_ren_chu_de_qi").style == "sun", "pennant_style toggles directly from raft deck %d" % shape.x)

		# 5. Verify J Journal 16-chronicle summary + v21 save/reload
		await _tap(KEY_J)
		await _settle(0.05)
		var j_text: String = main.journal_ui.content.text
		for expected in ["一份用不上的救援记录", "岸边救生圈绳架", "名字各不相同的草", "四时生长图鉴匣", "一张能用的误差表", "黄铜浮筒测潮仪", "被风认出来的旗", "暖赭归航三角旗"]:
			_check(j_text.contains(expected), "J journal shows %s at %d" % [expected, shape.x])
		if shape.x == 1280:
			main.journal_ui.content.scroll_to_line(main.journal_ui.content.get_line_count())
			await _settle(0.05)
			await _capture("journal-16-chronicles-1280.png")
		await _tap(KEY_ESCAPE)

		_check(main._persist(), "persists v21 world %d" % shape.x)
		var saved_chron: Dictionary = main.world.data.chronicles.duplicate(true)
		main.world = World.new()
		_check(main._load_saved() and int(main.world.data.version) == 21 and main.world.data.chronicles == saved_chron, "reloads v21 16-chronicle state %d" % shape.x)

	print("RELEASE 0.23 UI CHECKS: %d checks, %d failures, evidence %s" % [checks, failures, evidence])
	finished = true
	quit(0 if failures == 0 else 1)

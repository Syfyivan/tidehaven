extends "res://tests/stories_ui_checks.gd"
## Graphical 2-resolution verification of 0.20 deliverables:
## 1) Complete 18/18 early-modern Chinese harbor town NPC world sprites & portraits
## 2) P2-10 《今晚留一碗》 full UI flow (counter inspect -> Chen Yu -> Tian Qing -> Su Qin -> overnight -> 3 banquet styles)
## 3) P2-11 《重新有人靠岸》 full UI flow (dock inspect -> Xu An -> Lu Yao -> Mist Island Bai Fan -> overnight Qiao Xin -> pier styles)
## 4) P2-12 《海里也有邻居》 full UI flow (coast inspect -> Wen Zhi -> Reef Island Chao Jia -> Sea Cave 3 Lan Ying -> overnight Wen Zhi -> shore styles)
## 5) J Journal 4-chronicle summary + v18 save & reload
const LongStories = preload("res://scripts/long_stories.gd")
const Portraits = preload("res://scripts/portrait_art.gd")
const Restaurant = preload("res://scripts/restaurant.gd")

func _dock_island(id: String) -> void:
	var coast := Archipelago.island_position(main.world.data.chart, id)
	main.world.data.navigation.x = coast.x
	main.world.data.navigation.y = coast.y
	main.world.data.navigation.anchored = true

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://artifacts/release-020-ui-%d" % int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(evidence)
	main = MainScene.instantiate()
	main.save_path = evidence.path_join("world_v18.json")
	root.add_child(main)
	main.automated = true
	create_timer(180).timeout.connect(func():
		if not finished:
			printerr("FAIL release_020_ui_checks timed out")
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
		await _settle(0.05)

		# 1. Verify all 16 newly-completed harbor town NPCs show matched harbor portraits & world sprites
		for npc_id in ["xu_an", "he_mu", "lin_sui", "su_qin", "tang_he", "zhou_chao", "tian_qing", "lu_yao", "chen_yu", "wen_zhi", "qiao_xin", "shi_xun", "sen_ke", "lu_zhou", "gu_xing", "xu_mian"]:
			visit(npc_id)
			await _settle(0.04)
			await _click(_world_point(Town.position(npc_id, 660, main.world.data), _player().area))
			var ui = main.dialogue_ui
			_check(ui.visible and ui.portrait.visible and ui.portrait.texture == Portraits.texture(npc_id), "harbor NPC dialogue portrait %s %d" % [npc_id, shape.x])
			_check(not ui.portrait.get_global_rect().intersects(ui.body_scroll.get_global_rect()), "portrait never overlaps body %s %d" % [npc_id, shape.x])
			if shape.x == 1280 and npc_id in ["xu_an", "zhou_chao", "su_qin", "qiao_xin", "chen_yu", "gu_xing"]:
				await _capture("harbor-npc-%s-1280.png" % npc_id)
			await _tap(KEY_ESCAPE)

		# Capture outdoor evening plaza gathering with all-Chinese-harbor townsfolk!
		if shape.x == 1280:
			main.world.data.minute = 1110.0
			var p_at := Town.position("lu_yao", 1110.0, main.world.data)
			_fixture_player("island", p_at + Vector2(36, 12))
			_player().room = ""
			await _settle(0.05)
			await _capture("harbor-town-gathering-1280.png")

		# 2. Walk through P2-10 《今晚留一碗》
		main.world.data.money = 50
		Inventory.add(_player().bag, "wood", 12)
		visit("xu_an")
		await _settle(0.04)
		main.perform("town_shop", {"id": "xu_an"})
		await _settle(0.04)
		_check(bool(main.world.data.restaurant.rented), "rented restaurant via Xu An %d" % shape.x)
		await _tap(KEY_ESCAPE)

		Rooms._arrive(main.world.data, _player(), "restaurant", Restaurant.counter() + Vector2(0, 24))
		await _settle(0.04)
		main.perform("shop_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "liu_yi_wan").step) == 1, "shop_inspect starts liu_yi_wan %d" % shape.x)

		visit("chen_yu")
		await _settle(0.04)
		await _click(_world_point(Town.position("chen_yu", 660, main.world.data), _player().area))
		await choose("《今晚留一碗》")
		_check(main.dialogue_ui.topic.text == "今晚留一碗", "liu_yi_wan topic header %d" % shape.x)
		await choose("先把几道常备菜做稳")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "veg", 2)
		visit("tian_qing")
		await _settle(0.04)
		await _click(_world_point(Town.position("tian_qing", 660, main.world.data), _player().area))
		await choose("《今晚留一碗》")
		await choose("不挑长相的时令热菜")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "fish", 2)
		visit("su_qin")
		await _settle(0.04)
		await _click(_world_point(Town.position("su_qin", 660, main.world.data), _player().area))
		await choose("《今晚留一碗》")
		await choose("约明晚收工时分")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		visit("chen_yu")
		await _settle(0.04)
		await _click(_world_point(Town.position("chen_yu", 660, main.world.data), _player().area))
		await choose("《今晚留一碗》")
		if shape.x == 1280:
			await _capture("liu-yi-wan-finale-1280.png")
		await choose("海港鲜鱼席")
		_check(LongStories.record(main.world.data, "liu_yi_wan").style == "seafood", "liu_yi_wan completed with seafood style %d" % shape.x)
		await _tap(KEY_ESCAPE)
		Rooms._arrive(main.world.data, _player(), "restaurant", Restaurant.counter() + Vector2(-72, 36))
		main.toast_clock = 0.0
		main._update_hud()
		await _settle(0.05)
		if shape.x == 1280:
			await _capture("liu-yi-wan-counter-1280.png")

		# 3. Walk through P2-11 《重新有人靠岸》 (including ocean NPC Bai Fan!)
		_dock_island(Archipelago.HOME_ID)
		_fixture_player("island", IslandMap.DOCK + Vector2(18, 12))
		_player().room = ""
		await _settle(0.04)
		main.perform("dock_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "kao_an").step) == 1, "dock_inspect starts kao_an %d" % shape.x)

		visit("xu_an")
		await _settle(0.04)
		await _click(_world_point(Town.position("xu_an", 660, main.world.data), _player().area))
		await choose("《重新有人靠岸》")
		await choose("找陆遥把两份岸线记录比对清楚")
		await _tap(KEY_ESCAPE)

		visit("lu_yao")
		await _settle(0.04)
		await _click(_world_point(Town.position("lu_yao", 660, main.world.data), _player().area))
		await choose("《重新有人靠岸》")
		await choose("出海去雾岬岛找白帆")
		await _tap(KEY_ESCAPE)

		Inventory.add(_player().bag, "wood", 4)
		Inventory.add(_player().bag, "rope", 1)
		_dock_island("island_mist")
		visit("bai_fan")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("bai_fan"), _player().area))
		await choose("《重新有人靠岸》")
		_check(main.dialogue_ui.topic.text == "重新有人靠岸", "ocean NPC Bai Fan displays chronicle topic %d" % shape.x)
		await choose("盯紧绳结")
		_check(int(LongStories.record(main.world.data, "kao_an").step) == 4, "Bai Fan advances kao_an via ocean_chronicle_reply %d" % shape.x)
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		_dock_island(Archipelago.HOME_ID)
		visit("qiao_xin")
		await _settle(0.04)
		await _click(_world_point(Town.position("qiao_xin", 660, main.world.data), _player().area))
		await choose("《重新有人靠岸》")
		await choose("定期客船港")
		_check(LongStories.record(main.world.data, "kao_an").style == "ferry", "kao_an completed with ferry style %d" % shape.x)
		await _tap(KEY_ESCAPE)

		# 4. Walk through P2-12 《海里也有邻居》 (including Chao Jia & Lan Ying!)
		_fixture_player("island", LongStories.COAST_SITE + Vector2(18, 0))
		_player().room = ""
		await _settle(0.04)
		main.perform("coast_inspect")
		await _settle(0.04)
		_check(int(LongStories.record(main.world.data, "hai_lin_ju").step) == 1, "coast_inspect starts hai_lin_ju %d" % shape.x)

		visit("wen_zhi")
		await _settle(0.04)
		await _click(_world_point(Town.position("wen_zhi", 660, main.world.data), _player().area))
		await choose("《海里也有邻居》")
		await choose("先去珊湾找潮甲")
		await _tap(KEY_ESCAPE)

		_dock_island("island_reef")
		visit("chao_jia")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("chao_jia"), _player().area))
		await choose("《海里也有邻居》")
		await choose("去海洞三层找澜影")
		await _tap(KEY_ESCAPE)

		_dock_island(Archipelago.HOME_ID)
		Inventory.add(_player().bag, "stone", 2)
		visit("lan_ying")
		await _settle(0.04)
		await _click(_world_point(Ocean.position("lan_ying"), _player().area))
		await choose("《海里也有邻居》")
		await choose("轻敲木架三声")
		await _tap(KEY_ESCAPE)

		main.world.data.day += 1
		visit("wen_zhi")
		await _settle(0.04)
		await _click(_world_point(Town.position("wen_zhi", 660, main.world.data), _player().area))
		await choose("《海里也有邻居》")
		await choose("听潮海螺架")
		_check(LongStories.record(main.world.data, "hai_lin_ju").style == "chime", "hai_lin_ju completed with chime style %d" % shape.x)
		await _tap(KEY_ESCAPE)

		# Capture West Dock + Coast showing both new world landmarks together!
		_player().room = ""
		_fixture_player("island", Vector2(248, 304))
		main.toast_clock = 0.0
		main._update_hud()
		await _settle(0.05)
		if shape.x == 1280:
			await _capture("dock-and-coast-020-1280.png")

		# Verify J Journal shows all completed chronicles
		await _tap(KEY_J)
		await _settle(0.05)
		var jtxt: String = main.journal_ui.content.text
		_check(jtxt.contains("海港鲜鱼席") and jtxt.contains("定期客船港") and jtxt.contains("听潮海螺架"), "journal displays all 3 new chronicle outcomes %d" % shape.x)
		if shape.x == 1280:
			await _capture("journal-020-1280.png")
		await _tap(KEY_ESCAPE)

	# Verify v18 save & reload preserves all chronicles
	_dock_island(Archipelago.HOME_ID)
	_check(main._persist() and main._start("solo", true), "v18 save and reload succeeds")
	_check(int(LongStories.record(main.world.data, "liu_yi_wan").step) == 5 and int(LongStories.record(main.world.data, "kao_an").step) == 5 and int(LongStories.record(main.world.data, "hai_lin_ju").step) == 5, "reloaded v18 world retains all completed chronicles")

	finished = true
	print("RELEASE 0.20 UI CHECKS: %d checks, %d failures; evidence: %s" % [checks, failures, evidence])
	quit(0 if failures == 0 else 1)

extends "res://tests/island_ui_checks.gd"
const Threats=preload("res://scripts/sea_threats.gd")
const Creatures=preload("res://scripts/sea_creature_art.gd")
func _run()->void:
	evidence=(OS.get_environment("TIDEHAVEN_TEST_ROOT") if not OS.get_environment("TIDEHAVEN_TEST_ROOT").is_empty() else ProjectSettings.globalize_path("res://artifacts")).path_join("sea-threats-ui-"+str(Time.get_unix_time_from_system()).replace(".","-"))
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate();root.add_child(main)
	main.save_path=evidence.path_join("world.json");main.automated=true
	create_timer(100).timeout.connect(func():if not finished:printerr("FAIL sea threats UI timeout");quit(1))
	await _settle();await _click(main.new_game_button.get_global_rect().get_center())
	main.set_physics_process(false)
	for size in [Vector2i(960,600),Vector2i(1280,800)]:
		root.size=size
		_fixture_player("water",Vector2(530,265))
		_player().stamina=100
		_player().dive_status=Threats.player_state()
		_player().bag=Inventory.empty_slots(12);Inventory.add(_player().bag,"harpoon",1)
		main.world.data.threats=Threats.create()
		for phase in ["patrol","chase","windup","charge","repelled"]:
			for e in main.world.data.threats.values():
				e.phase=phase;e.target="host" if phase in ["chase","windup","charge"] else ""
				e.dx=-1.0;e.dy=0.0;e.remaining=0.75 if phase=="windup" else 0.3
			await _settle();await _capture("%s-%d.png"%[phase,size.x])
			_check(main.hud.danger_label.visible,"water danger hint visible "+phase)
		main.world.data.threats=Threats.create()
		var enemy:Dictionary=main.world.data.threats.shark
		enemy.x=650;enemy.y=265;enemy.phase="windup";enemy.target="host";enemy.remaining=1.15
		for e in main.world.data.entities.values():
			if e.kind=="fish":e.active=false
		await _click(main.hud.slots[0].button.get_global_rect().get_center())
		_check(main.active_tool=="harpoon" and _player().activity.is_empty(),"one slot click selects without firing")
		await _click(_world_point(Vector2(650,265),"water"))
		_check(_player().activity.get("kind")=="spear","world click starts actual spear")
		main.set_physics_process(true)
		await _settle(1.1)
		main.set_physics_process(false)
		_check(enemy.phase=="repelled" and _player().stamina==95,"real input flight repels without receiving damage")
		await _capture("spear-repel-%d.png"%size.x)
		_player().dive_status.hurt=1.8;_player().stamina=25
		await _settle();await _capture("hurt-%d.png"%size.x)
		_fixture_player("water",Vector2(120,100));_player().dive_status=Threats.player_state()
		await _settle();await _capture("safe-buoy-%d.png"%size.x)
		_check("安全" in main.hud.danger_label.text,"safe buoy explains return route")
		await _tap(KEY_H);await _click(_world_point(Vector2(120,65),"water"))
		_check(_player().area=="deck","normal buoy click returns to deck")
		_player().dive_status.recovery=7.5
		await _settle();await _capture("recovery-%d.png"%size.x)
	finished=true
	print("SEA THREATS UI: %d checks, %d failures; %s"%[checks,failures,evidence]);quit(0 if failures==0 else 1)
func _settle(seconds:float=0.14)->void:
	await create_timer(seconds).timeout
	await process_frame
	RenderingServer.force_draw(false)

extends "res://tests/island_ui_checks.gd"
## Positions/items are fixtures; collisions, harvesting and farming use real input.
func _run() -> void:
	evidence=ProjectSettings.globalize_path("res://artifacts/island-surfaces-ui-%d" % Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate()
	main.save_path=evidence.path_join("world.json")
	root.add_child(main)
	main.automated=true
	create_timer(60).timeout.connect(func():
		if not finished: quit(1))
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	main.world.data.minute=720.0
	main.world.data.island.homestead.rented=true
	main.automated=false
	for size in [Vector2i(960,600),Vector2i(1280,800)]:
		root.size=size
		_fixture_player("island",Vector2(640,430))
		await _hold(KEY_D,0.7)
		_check(_player().x<=652 and IslandMap.can_stand(Vector2(_player().x,_player().y)),"held movement stops feet before water at "+str(size.x))
		await _capture("pond-%d.png" % size.x)
		var hall:Rect2=IslandMap.LANDMARKS.townhall.bounds
		_fixture_player("island",Vector2(hall.end.x+28,hall.end.y-48))
		await _hold(KEY_A,0.7)
		_check(_player().x>=hall.end.x+6,"building facade blocks held movement at "+str(size.x))
		await _capture("wall-%d.png" % size.x)
	_fixture_player("island",Vector2(1880,1600))
	await _hold(KEY_D,0.7)
	_check(_player().x<=1906,"closed fence stops movement")
	_fixture_player("island",IslandMap.YARD_GATE-Vector2(40,0))
	await _hold(KEY_D,0.75)
	_check(_player().x>1960,"yard gate actually allows entry")
	await _capture("yard-gate.png")
	_fixture_player("island",Vector2(330,315))
	await _hold(KEY_W,0.6)
	_check(_player().y>=286,"visible trunk blocks walking")
	Inventory.add(_player().bag,"axe",1)
	await _tap(KEY_1)
	await _click(_world_point(Vector2(330,280),"island"))
	_check(await _wait_for(func():return not IslandState.active(main.world.data.island,"palm_0",1),8.0),"tool removes blocking tree through actual timed gathering")
	await _hold(KEY_W,0.4)
	_check(_player().y<280,"cleared trunk becomes passable")
	var grass:Dictionary={}
	for resource:Dictionary in IslandMap.nodes_near(IslandMap.YARD_GATE).values():
		if resource.kind=="fiber" and resource.x>1980 and resource.x<2336 and resource.y>1680 and resource.y<1930:
			grass=resource
			break
	_check(not grass.is_empty(),"yard contains real grass resources")
	var at:=Vector2(grass.x,grass.y)
	_fixture_player("island",at+Vector2(0,30))
	for item in ["scythe","hoe","seed","watering_can"]: Inventory.add(_player().bag,item,1)
	_player().can_water=20
	await _settle()
	await _capture("grass-before.png")
	await _select_item("scythe")
	await _click(_world_point(at,"island"))
	_check(await _wait_for(func():return not IslandState.active(main.world.data.island,str(grass.id),1),3.0),"cutting visible grass depletes that exact resource")
	_check(not main.world.data.island.plots.has(Farming.plot_key(at)),"clearing alone does not create tilled soil")
	await _capture("grass-cleared.png")
	for item in ["hoe","seed","watering_can"]:
		main._update_hud()
		await _settle()
		for index in _player().bag.size():
			if _player().bag[index].get("item","")==item:
				await _click(main.hud.slots[index].button.get_global_rect().get_center())
				break
		_check(main.active_tool=={"hoe":"till","seed":"plant","watering_can":"water"}[item],"visible toolbar equips "+item)
		await _click(_world_point(at,"island"))
	_check(main.world.data.island.plots.has(Farming.plot_key(at)) and main.world.data.island.plots[Farming.plot_key(at)].watered,"one cleared grass cell becomes a watered crop using carried tools")
	await _capture("yard-farming.png")
	await _tap(KEY_M)
	await _capture("island-map.png")
	await _tap(KEY_ESCAPE)
	finished=true
	print("ISLAND SURFACES UI: %d checks, %d failures; evidence: %s" %[checks,failures,evidence])
	quit(0 if failures==0 else 1)

func _hold(keycode:Key,seconds:float) -> void:
	var event:=InputEventKey.new()
	event.keycode=keycode
	event.physical_keycode=keycode
	event.pressed=true
	Input.parse_input_event(event)
	await _settle(seconds)
	event=InputEventKey.new()
	event.keycode=keycode
	event.physical_keycode=keycode
	event.pressed=false
	Input.parse_input_event(event)
	await _settle(0.18)

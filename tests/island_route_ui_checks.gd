extends "res://tests/island_ui_checks.gd"
class RouteDriver extends "res://tests/island_playthrough.gd":
	func _ready():
		main=get_parent()
		started_ms=Time.get_ticks_msec()
func _run():
	evidence=ProjectSettings.globalize_path("res://artifacts/island-route-ui-%d" % Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate()
	main.save_path=evidence.path_join("world.json")
	root.add_child(main)
	main.automated=true
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	main.world.data.minute=720.0
	main.world.data.day=5
	main.automated=false
	var driver:=RouteDriver.new()
	main.add_child(driver)
	_fixture_player("island",Vector2(1344,280))
	_check(await driver._walk_segment(Vector2(1344,480),"regrown tree on market lane"),"normal WASD goes around the regrown trunk")
	_check(await driver._walk_segment(Vector2(1088,480),"market entrance"),"normal WASD reaches market door")
	await _capture("market-route.png")
	for resource:Dictionary in IslandMap.nodes_near(Vector2(2000,280)).values():
		if str(resource.id).begins_with("clear_2_0_") and resource.kind=="fiber" and resource.y<350:
			_fixture_player("island",Vector2(resource.x,resource.y))
			break
	_check(await driver._walk_segment(Vector2(1840,280),"return from wild land"),"unequal-axis WASD route avoids solid resources")
	var bridge:=Vector2.ZERO
	for y in range(4300,4850,8):
		var point:=Vector2(IslandMap.vertical_path_x(y,3),y)
		if IslandMap.terrain(point)=="bridge":
			bridge=point
			break
	_fixture_player("island",Vector2(IslandMap.vertical_path_x(bridge.y-140,3),bridge.y-140))
	_check(await driver._walk_segment(bridge,"bridge deck"),"normal WASD reaches the visible bridge")
	await _capture("bridge.png")
	_check(await driver._walk_segment(Vector2(IslandMap.vertical_path_x(bridge.y+200,3),bridge.y+200),"far riverbank"),"normal WASD crosses to the other bank")
	driver.finished=true
	finished=true
	print("ISLAND ROUTE UI: %d checks, %d failures; evidence: %s" %[checks,failures,evidence])
	quit(0 if failures==0 else 1)

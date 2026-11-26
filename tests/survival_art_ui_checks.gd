extends "res://tests/island_ui_checks.gd"
const Art=preload("res://scripts/art_catalog.gd")
func _run()->void:
	evidence=(OS.get_environment("TIDEHAVEN_TEST_ROOT") if not OS.get_environment("TIDEHAVEN_TEST_ROOT").is_empty() else ProjectSettings.globalize_path("res://artifacts")).path_join("survival-art-ui-"+str(Time.get_unix_time_from_system()).replace(".","-"))
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate();root.add_child(main)
	main.save_path=evidence.path_join("world.json");main.automated=true
	create_timer(100).timeout.connect(func():if not finished:printerr("FAIL survival art UI timeout");quit(1))
	await _settle();await _click(main.new_game_button.get_global_rect().get_center())
	main.set_physics_process(false)
	var observed: Array[int] = []
	main.hud.item_used.connect(func(index: int): observed.append(index))
	var base:Dictionary=main.world.data.duplicate(true)
	for size in [Vector2i(960,600),Vector2i(1280,800)]:
		root.size=size
		main.world.data=base.duplicate(true)
		main.world.data.navigation.anchored=true
		_fixture_player("deck",Vector2(480,288))
		_player().bag=Inventory.empty_slots(12)
		var items=["axe","pickaxe","hoe","scythe","watering_can","fish","cooked_fish","meal","seed","summer_seed","autumn_seed","winter_seed"]
		for item in items:Inventory.add(_player().bag,item,999)
		await _settle()
		for i in 12:
			observed.clear()
			await _click(main.hud.slots[i].button.get_global_rect().get_center())
			print("SLOT %dpx %s signal=%s held=%d count=%d" % [size.x, items[i], observed, main.held_index, _player().bag[i].count])
			_check(main.held_index==i and _player().bag[i].count==999,"new icon selects actual stack without using "+items[i])
		await _tap(KEY_B);await _capture("inventory-%d.png"%size.x);await _tap(KEY_B)
		await _tap(KEY_C);await _capture("recipes-%d.png"%size.x);await _tap(KEY_ESCAPE)
		await _tap(KEY_H)
		main.world.data.structures={}
		for i in 6:
			var kind:String=["furnace","garden","hatch","orders","workbench","grill"][i]
			var at:=Vector2(416+(i%3)*64,224+(i/3)*128)
			main.world.data.structures[kind]=main.world._new_structure(kind,kind,at)
		for stage in 3:
			main.world.data.crop.stage=stage
			main.world.data.structures.furnace.remaining=0.0 if stage==0 else 10.0
			await _settle();await _capture("facilities-%d-%d.png"%[size.x,stage])
		main.world.data.structures=base.structures.duplicate(true)
		_fixture_player("water",Vector2(460,300))
		await _settle();await _capture("underwater-%d.png"%size.x)
		for point in [Vector2(640,430),Vector2(3350,4580),Vector2(7488,1900),Vector2(2000,1800)]:
			_fixture_player("island",point)
			await _settle();await _capture("shore-%d-%d-%d.png"%[size.x,point.x,point.y])
			await _tap(KEY_M)
			_check(main.island_atlas.visible,"map opens at world location "+str(point))
			await _capture("map-%d-%d-%d.png"%[size.x,point.x,point.y]);await _tap(KEY_ESCAPE)
		# Actual tool clicks put a canopy on a dry plot, then water it.
		_fixture_player("island",Vector2(520,365))
		_player().bag=Inventory.empty_slots(12)
		for item in ["hoe","canopy","watering_can"]:Inventory.add(_player().bag,item,1)
		_player().can_water=20
		await _settle()
		for index in 3:
			await _click(main.hud.slots[index].button.get_global_rect().get_center())
			await _click(_world_point(Vector2(496,336),"island"))
		_check(main.world.data.island.plots.get("15,10",{}).get("covered",false) and _player().can_water==19,"real held canopy and watering tool apply to one plot")
		for row in [[1,"seed",4],[29,"summer_seed",7],[57,"autumn_seed",10],[85,"winter_seed",6]]:
			main.world.data.day=row[0]
			main.world.data.island.plots["15,10"].crop=row[1]
			main.world.data.island.plots["15,10"].growth=row[2]
			await _settle();await _capture("crop-%d-%d.png"%[size.x,row[0]])
	finished=true
	print("SURVIVAL ART UI: %d checks, %d failures; %s"%[checks,failures,evidence])
	quit(0 if failures==0 else 1)

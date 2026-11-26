extends "res://tests/island_ui_checks.gd"
const Rooms=preload("res://scripts/rooms.gd")
const Home=preload("res://scripts/home_life.gd")

func _run()->void:
	evidence=ProjectSettings.globalize_path("res://artifacts/remaining-016/home-ui-%d"%Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate();root.add_child(main);main.save_path=evidence.path_join("world.json");main.automated=true
	await _settle();await _click(main.new_game_button.get_global_rect().get_center());main.set_physics_process(false)
	for shape in [Vector2i(960,600),Vector2i(1280,800)]:
		root.size=shape;main.world.data.housing.level=1
		var p:Dictionary=_player();p.bag=Inventory.empty_slots(12)
		Inventory.add(p.bag,"chest",1);Inventory.add(p.bag,"wood",2)
		var target:=Vector2.ZERO
		for cell:Vector2i in Rooms.geometry("yard_home").ordered:
			var at:Vector2=(Vector2(cell)*32/64).floor()*64+Vector2(32,32)
			for offset in [Vector2(64,0),Vector2(-64,0),Vector2(0,64)]:
				if not Rooms.can_stand("yard_home",at+offset):continue
				Rooms._arrive(main.world.data,p,"yard_home",at+offset)
				if Home.placement_reason(main.world.data,p,"chest",at).is_empty():target=at;break
			if target!=Vector2.ZERO:break
		_check(target!=Vector2.ZERO,"home has legal furniture space")
		await _settle();await _click(main.hud.slots[0].button.get_global_rect().get_center())
		await _move_mouse(_world_point(target,"room"));await _settle()
		_check(main.view.placement.get("valid",false),"home chest preview valid")
		await _capture("preview-%d.png"%shape.x)
		await _click(_world_point(target,"room"))
		_check(main.world.data.housing.furniture.size()==1 and Inventory.count(p.bag,"chest")==0,"actual placement spends exactly one kit")
		await _tap(KEY_H);await _click(_world_point(target,"room"))
		_check(main.inventory_ui.visible and main.inventory_ui.chest_id.begins_with("home_"),"home chest opens real finite inventory")
		await _click(main.inventory_ui.get_slot_button("bag",1).get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
		await _click(main.inventory_ui.get_slot_button("chest",0).get_global_rect().get_center())
		var prop:Dictionary=main.world.data.housing.furniture[0]
		_check(Inventory.count(p.bag,"wood")==1 and Inventory.count(prop.slots,"wood")==1,"manual split moves one unit into home chest")
		await _capture("storage-%d.png"%shape.x);await _tap(KEY_B)
		await _tap(KEY_P);await _choose_context("home_pack")
		_check(main.world.data.housing.furniture.size()==1,"non-empty chest stays placed")
		await _click(_world_point(target,"room"))
		await _click(main.inventory_ui.get_slot_button("chest",0).get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
		await _click(main.inventory_ui.get_slot_button("bag",1).get_global_rect().get_center())
		await _tap(KEY_B);await _tap(KEY_P);await _choose_context("home_pack")
		_check(main.world.data.housing.furniture.is_empty() and Inventory.count(p.bag,"chest")==1 and Inventory.count(p.bag,"wood")==2,"empty furniture returns to bag without losing stored items")
		Inventory.add(p.bag,"bed",1)
		var bed_index:int=p.bag.find(p.bag.filter(func(stack):return stack.get("item")=="bed")[0])
		await _settle();await _click(main.hud.slots[bed_index].button.get_global_rect().get_center())
		await _click(_world_point(target,"room"));await _tap(KEY_H)
		await _click(_world_point(target,"room"))
		_check(main.world.data.housing.furniture.size()==1 and Inventory.count(p.bag,"bed")==0,"left click cannot silently pack furniture")
		await _tap(KEY_P);await _choose_context("home_pack")
		_check(main.world.data.housing.furniture.is_empty() and Inventory.count(p.bag,"bed")==1,"right menu explicitly packs bed")
	finished=true;print("HOME UI ",checks," failures=",failures," evidence=",evidence);quit(1 if failures else 0)

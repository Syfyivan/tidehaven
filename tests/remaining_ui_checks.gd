extends "res://tests/island_ui_checks.gd"
const Rooms=preload("res://scripts/rooms.gd")
const Housing=preload("res://scripts/housing.gd")
const Ocean=preload("res://scripts/ocean_residents.gd")
func _run()->void:
	evidence=ProjectSettings.globalize_path("res://artifacts/remaining-016/scenes-%d"%Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate();main.save_path=evidence.path_join("world.json");root.add_child(main);main.save_path=evidence.path_join("world.json");main.automated=true
	create_timer(160).timeout.connect(func():if not finished:quit(2))
	await _settle();await _click(main.new_game_button.get_global_rect().get_center())
	_check(main.mode=="solo","normal title starts isolated game")
	main.set_physics_process(false)
	for viewport_size in [Vector2i(960,600),Vector2i(1280,800)]:
		main.world.data.deck_tiles=preload("res://scripts/world_state.gd").new().data.deck_tiles
		root.size=viewport_size;await _settle()
		await _tap(KEY_J);_check(main.journal_ui.visible,"J opens optional journal");await _capture("journal-%d.png"%viewport_size.x)
		await _tap(KEY_ESCAPE);_check(not main.journal_ui.visible and not main.pause_open,"top modal closes without pause leak")
		main.world.data.housing.level=0;main.world.data.island.homestead.rented=true
		var door:=Housing.door(main.world.data)
		_fixture_player("island",door+Vector2(32,32));await _settle();await _capture("abandoned-home-%d.png"%viewport_size.x)
		main.world.data.housing.level=2
		await _tap(KEY_H);await _tap(KEY_P);await _choose_context("room_enter")
		_check(_player().room=="yard_home","real context click enters home");await _capture("repaired-home-%d.png"%viewport_size.x)
		_player().x=Rooms.onward("yard_home").x;_player().y=Rooms.onward("yard_home").y
		await _settle();await _tap(KEY_P);await _choose_context("room_annex")
		_check(_player().room=="yard_annex","actual click enters annex");await _capture("annex-%d.png"%viewport_size.x)
		await _tap(KEY_M);_check(main.room_atlas.visible,"home map opens");await _capture("annex-map-%d.png"%viewport_size.x);await _tap(KEY_ESCAPE)
		for id:String in ["island_mist","island_reef","island_wind"]:
			_fixture_player("deck",Vector2(555,288))
			var dock:=Archipelago.island_position(main.world.data.chart,id)
			main.world.data.navigation.x=dock.x;main.world.data.navigation.y=dock.y;main.world.data.navigation.anchored=true
			await _settle();await _tap(KEY_H);await _tap(KEY_P);await _choose_context("land")
			_check(_player().room==id,"real island landing "+id);await _capture("%s-%d.png"%[id,viewport_size.x])
			await _tap(KEY_M);_check(main.room_atlas.visible,"island local map "+id);await _capture("%s-map-%d.png"%[id,viewport_size.x]);await _tap(KEY_ESCAPE)
			await _tap(KEY_P);await _choose_context("room_exit");_check(_player().area=="deck","island returns to actual raft")
		for id:String in Ocean.NPCS:
			var at:=Ocean.position(id)
			Rooms._arrive(main.world.data,_player(),Ocean.NPCS[id].room,at+Vector2(48,0))
			await _settle();await _tap(KEY_H)
			await _click(_world_point(at,"room"));_check(main.dialogue_ui.visible,"real NPC talk "+id)
			await _capture("%s-%d.png"%[id,viewport_size.x]);await _tap(KEY_ESCAPE)
		# Each new island tool must be selectable and usable by a world click.
		var player:Dictionary=_player()
		player.bag=Inventory.empty_slots(12)
		for item in ["axe","pickaxe","scythe","hoe"]:Inventory.add(player.bag,item,1)
		for item in ["axe","pickaxe","scythe","hoe"]:
			var island_id:="island_mist" if item=="pickaxe" else "island_wind"
			var resources:Array=Rooms.nodes(island_id).values().filter(func(n:Dictionary):return n.get("tool","")==item)
			if resources.is_empty():continue
			var node:Dictionary=resources[0]
			main.world.data.rooms.depleted.erase(node.id)
			var at:=Vector2(node.x,node.y);var stand:=at
			for offset in [Vector2(-48,0),Vector2(48,0),Vector2(0,48),Vector2(0,-48)]:
				if Rooms.can_stand(island_id,at+offset):stand=at+offset;break
			Rooms._arrive(main.world.data,player,island_id,stand)
			player.stamina=100
			await _settle()
			var index:int=player.bag.find(player.bag.filter(func(s:Dictionary):return s.get("item")==item)[0])
			await _click(main.hud.slots[index].button.get_global_rect().get_center())
			await _click(_world_point(at,"room"))
			_check(player.activity.get("kind")=="room_mine","held tool world click starts "+item)
			var before:int=Inventory.count(player.bag,node.kind)
			main.set_physics_process(true)
			var deadline:=Time.get_ticks_msec()+9000
			var seen:Dictionary={}
			while not player.activity.is_empty() and Time.get_ticks_msec()<deadline:
				if item=="axe" and not player.activity.get("approach",false):
					var pose:=preload("res://scripts/tool_motion.gd").sample(player.activity,Vector2(player.x,player.y),at)
					if not seen.has(pose.frame):
						seen[pose.frame]=true
						await _capture("island-axe-%d-%d.png"%[viewport_size.x,pose.frame])
				await create_timer(0.08).timeout
			main.set_physics_process(false)
			if item=="axe":_check(seen.size()==5,"new island shows all matched axe phases")
			_check(Inventory.count(player.bag,node.kind)==before+int(node.amount) and main.world.data.rooms.depleted.has(node.id),"timed tool action completes exactly once "+item)
			await _capture("tool-%s-%d.png"%[item,viewport_size.x])
		_fixture_player("deck",Vector2(544,352));main.world.data.deck_tiles=[]
		for x in range(2,12):
			for y in range(2,7):main.world.data.deck_tiles.append("%d,%d"%[x,y])
		main.world.data.housing.cabin={"x":608.0,"y":224.0}
		await _settle();await _capture("cabin-%d.png"%viewport_size.x)
		main.world.data.housing.cabin={}
	finished=true;print("REMAINING UI ",checks," failures=",failures," evidence=",evidence);quit(1 if failures else 0)

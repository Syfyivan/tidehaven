extends "res://tests/island_ui_checks.gd"
const World=preload("res://scripts/world_state.gd")
const Town=preload("res://scripts/island_town.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Journal=preload("res://scripts/journal.gd")
const Ocean=preload("res://scripts/ocean_residents.gd")

func _run()->void:
	evidence=ProjectSettings.globalize_path("res://artifacts/remaining-016/story-ui-%d"%Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate();root.add_child(main);main.save_path=evidence.path_join("world.json");main.automated=true
	create_timer(90).timeout.connect(func():if not finished:quit(2))
	await _settle();await _click(main.new_game_button.get_global_rect().get_center());main.set_physics_process(false)
	for shape in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size=shape
		main.world=World.new();main.world.join("host","旅人")
		var d:Dictionary=main.world.data
		d.minute=600;d.housing.level=1;d.rooms.visited.sea_3=true
		for step in Journal.STORY.size():
			var chapter:Dictionary=Journal.STORY[step]
			var location:=Town.location(chapter.npc,600,d)
			_fixture_player(location.area,location.at);_player().room=location.room
			if not location.room.is_empty():d.rooms.visited[location.room]=true
			for item:String in chapter.cost:Inventory.add(_player().bag,item,chapter.cost[item])
			await _settle();await _tap(KEY_P);await _choose_context("town_story_accept")
			_check(d.journal.story_accepted,"context accepts optional chapter")
			await _tap(KEY_P);await _choose_context("town_story_finish")
			_check(d.journal.story_step==step+1,"context delivers chapter once")
		_fixture_player("island",Journal.BEACON+Vector2(85,64));d.minute=1180
		await _settle();await _capture("repaired-beacon-%d.png"%shape.x)
		for id:String in ["lan_ying","tai_lu"]:
			Rooms._arrive(d,_player(),Ocean.NPCS[id].room,Ocean.position(id)+Vector2(48,0))
			var q:Dictionary=Journal.REQUESTS[id];Inventory.add(_player().bag,q.item,q.count)
			await _settle();await _tap(KEY_H);await _tap(KEY_P);await _choose_context("ocean_errand_accept")
			await _tap(KEY_P);await _choose_context("ocean_errand_finish")
			_check(d.journal.host.completed.has(id),"ocean NPC request delivered through actual menu")
		Rooms._arrive(d,_player(),"sea_3",Vector2(460,320));_player().oxygen=35;_player().stamina=100
		await _settle();await _tap(KEY_J);await _capture("magic-journal-%d.png"%shape.x)
		await _click(main.journal_ui.magic_buttons.breath.get_global_rect().get_center())
		_check(_player().oxygen==70 and d.journal.cooldown.host==30 and not main.journal_ui.visible,"actual spell button grants oxygen with personal cooldown")
		d.journal.cooldown.host=0
		_fixture_player("island",Vector2(2704,1808))
		d.island.plots={"84,56":{"crop":"seed","growth":2,"watered":false,"covered":false,"dead":false}}
		await _settle();await _tap(KEY_J);await _click(main.journal_ui.magic_buttons.rain.get_global_rect().get_center())
		_check(d.island.plots["84,56"].watered and d.island.plots["84,56"].growth==2,"rain button waters without instant growth")
		await _capture("rain-field-%d.png"%shape.x)
	finished=true;print("STORY UI ",checks," failures=",failures," evidence=",evidence);quit(1 if failures else 0)

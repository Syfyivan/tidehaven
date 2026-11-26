extends "res://tests/island_ui_checks.gd"
const World=preload("res://scripts/world_state.gd")
const Stories=preload("res://scripts/resident_stories.gd")
const Town=preload("res://scripts/island_town.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Ocean=preload("res://scripts/ocean_residents.gd")
const Atlas=preload("res://scripts/island_atlas.gd")

func visit(id:String)->void:
	main.world.data.minute=660
	if Ocean.NPCS.has(id):
		Rooms._arrive(main.world.data,_player(),Ocean.NPCS[id].room,Ocean.position(id)+Vector2(48,0))
		main.active_tool="hand";main.held_index=-1
		return
	var where:=Town.location(id,660,main.world.data)
	_fixture_player(where.area,where.at+Vector2(0,32))
	_player().room=where.room
	if where.area=="room":main.world.data.rooms.visited[where.room]=true
	main.active_tool="hand";main.held_index=-1

func _run()->void:
	evidence=ProjectSettings.globalize_path("res://artifacts/npc-017/ui-%d"%Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate();main.save_path=evidence.path_join("world.json");root.add_child(main);main.automated=true
	create_timer(180).timeout.connect(func():if not finished:quit(2))
	await _settle();await _click(main.new_game_button.get_global_rect().get_center())
	_check(main.mode=="solo","normal entry starts new world")
	main.set_physics_process(false)
	for shape in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size=shape;main.world=World.new();main.world.join("host","旅人")
		var d:Dictionary=main.world.data
		d.navigation.anchored=true;d.chart.visited=true;d.journal.story_step=3;d.journal.tide_speech=true
		var coast:=Archipelago.island_position(d.chart);d.navigation.x=coast.x;d.navigation.y=coast.y
		for owner:String in ["lu_zhou","mu_tong","gu_xing","xu_mian","tai_lu","tang_he","chen_yu"]:
			var arc:Dictionary=Stories.ARCS[owner]
			for step in 3:
				var beat:Dictionary=arc.steps[step]
				d.day+=int(beat.get("delay",0));visit(beat.at)
				for item:String in beat.get("cost",{}):Inventory.add(_player().bag,item,int(beat.cost[item]))
				await _settle()
				var at:=Town.position(beat.at,float(d.minute),d) if Town.NPCS.has(beat.at) else Ocean.position(beat.at)
				if step==0:await _capture("%s-character-%d.png"%[owner,shape.x])
				await _click(_world_point(at,_player().area))
				_check(main.dialogue_ui.visible,"world click talks to "+str(beat.at))
				var title:String=arc.title
				await choose(title)
				_check(str(beat.text) in main.dialogue_ui.body.text,"opening story shows authored current beat")
				await _capture("%s-story-%d-step%d.png"%[owner,shape.x,step])
				_check(main.dialogue_ui.body_scroll.get_global_rect().end.y<=main.dialogue_ui.choices_scroll.get_global_rect().position.y,"long dialogue is clipped above choice region")
				if beat.has("cost"):
					main.dialogue_ui.body_scroll.scroll_vertical=1000
					await _settle();await _capture("%s-cost-%d.png"%[owner,shape.x])
				var reply:int=mini(1,beat.replies.size()-1)
				await choose(str(beat.replies[reply].label))
				_check(int(d.stories.host.get(owner,{}).get("step",0))==step+1,"actual reply advances once "+owner)
				_check(d.stories.guest.is_empty(),"host story leaves guest progress untouched")
				await _tap(KEY_ESCAPE)
			await _tap(KEY_M)
			_check(main.room_atlas.visible,"resident's room has actual local map")
			await _capture("%s-map-%d.png"%[owner,shape.x]);await _tap(KEY_ESCAPE)
		# More than one option must not hide the existing mayor rental / starter tools.
		visit("xu_an");await _settle();await _click(_world_point(Town.position("xu_an",660,d),_player().area))
		_check(main.dialogue_ui.choice_buttons.size()>=2,"rental and personal story both offered")
		await choose("租");_check(d.island.homestead.rented,"rental button still works")
		await choose("领取");_check(d.island.homestead.claimed.host,"starter gift still works")
		await _tap(KEY_ESCAPE);await _tap(KEY_J)
		_check(main.journal_ui.visible and str(Stories.ARCS.xu_mian.title) in main.journal_ui.content.text,"J retains named stories and endings")
		await _capture("journal-%d.png"%shape.x);await _tap(KEY_ESCAPE)
		# Reproduce delayed/overlapping replies without depending on network timing.
		main.pending_talk="xu_an";main.pending_conversation=102
		main._action_message("许岸：较早的话题","xu_an",{},101)
		_check(not main.dialogue_ui.visible and main.pending_conversation==102,"older same-speaker reply cannot consume newer topic")
		main._action_message("许岸：最后选择的话题","xu_an",{},102)
		_check(main.dialogue_ui.visible and "最后选择" in main.dialogue_ui.body.text,"newest topic receives matching response")
		main.pending_talk="xu_an";main.pending_conversation=103
		await _tap(KEY_ESCAPE)
		main._action_message("许岸：迟到的话题","xu_an",{},103)
		_check(not main.dialogue_ui.visible,"closing cancels pending conversation response")
		main.pending_talk="xu_an";main.pending_conversation=104
		await _tap(KEY_J);main._action_message("许岸：迟到的话题","xu_an",{},104)
		_check(main.journal_ui.visible and not main.dialogue_ui.visible,"journal is not covered by delayed conversation")
		await _tap(KEY_ESCAPE)
		var markers:=Atlas.resident_markers(d)
		for id:String in ["lu_zhou","mu_tong","gu_xing","xu_mian"]:
			var place:=Town.location(id,float(d.minute),d)
			_check(markers[id]==IslandMap.LANDMARKS[place.room].door,"island marker uses real current building "+id)
		_check(main._persist(),"new stories save through real app")
		var saved:Dictionary=d.stories.duplicate(true)
		_check(main._start("solo",true) and main.world.data.stories==saved,"continue restores exact endings")
		main.set_physics_process(false)
	finished=true;print("STORIES UI ",checks," failures=",failures," evidence=",evidence);quit(1 if failures else 0)

func choose(label:String)->void:
	var found:Button=null
	for button:Button in main.dialogue_ui.choice_buttons:
		if label in button.text:found=button;break
	_check(found!=null,"dialogue offers "+label)
	if found==null:return
	main.dialogue_ui.choices_scroll.ensure_control_visible(found)
	await _settle(0.04)
	await _click(found.get_global_rect().get_center())

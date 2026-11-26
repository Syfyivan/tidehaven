extends "res://tests/progression_network_probe.gd"
const Stories=preload("res://scripts/resident_stories.gd")
const Town=preload("res://scripts/island_town.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Archipelago=preload("res://scripts/archipelago.gd")
const Appearance=preload("res://scripts/appearance.gd")
const OWNER:="lu_zhou"
var beat_index:=0
var current_args:Dictionary={}
var appearance:Dictionary=chosen_appearance()

func chosen_appearance()->Dictionary:
	var value:=Appearance.default_for("guest")
	value.hair=5;value.shirt=7;value.skin=4
	return value

func _setup_fixture()->void:
	var d:Dictionary=main.world.data
	d.navigation.anchored=true;d.chart.visited=true;d.minute=660;d.island.homestead.rented=true
	var dock:=Archipelago.island_position(d.chart);d.navigation.x=dock.x;d.navigation.y=dock.y
	for beat:Dictionary in Stories.ARCS[OWNER].steps:
		for item:String in beat.get("cost",{}):Inventory.add(d.players.guest.bag,item,int(beat.cost[item]))

func prepare(index:int)->void:
	var d:Dictionary=main.world.data
	var beat:Dictionary=Stories.ARCS[OWNER].steps[index]
	d.day+=int(beat.get("delay",0));d.minute=660
	var where:=Town.location(beat.at,660,d)
	Rooms._arrive(d,d.players.guest,where.room,where.at+Vector2(0,32))
	_signal_client("beat%d"%index)

func _host()->void:
	var d:Dictionary=main.world.data
	match phase:
		90:
			if d.players.guest.online:prepare(0);_next()
		91:
			if remote_stage=="done%d"%beat_index:
				_check(int(d.stories.guest.get(OWNER,{}).get("step",0))==beat_index+1,"guest reply advances exactly once, including replay")
				_check(d.stories.host.is_empty(),"host personal progress remains separate")
				beat_index+=1
				if beat_index<3:prepare(beat_index)
				else:
					_check(d.money==int(Stories.ARCS[OWNER].coins),"final story reward paid exactly once")
					if not _check(d.wardrobe.guest==appearance and d.wardrobe.host==Appearance.default_for("host"),"guest keeps independent chosen outfit"):return
					var gate:=preload("res://scripts/island_map.gd").YARD_GATE+Vector2(20,12)
					d.players.guest.area="island";d.players.guest.room="";d.players.guest.x=gate.x;d.players.guest.y=gate.y
					_signal_client("chronicle_gate");_next()
		92:
			if remote_stage=="chronicle_xu":
				_check(int(d.chronicles.hou_chao_yuan.step)==1,"guest yard inspect advances shared chronicle to step 1")
				var where:=Town.location("xu_an",660,d)
				Rooms._arrive(d,d.players.guest,where.room,where.at+Vector2(0,32))
				_signal_client("chronicle_xu_ready");_next()
		93:
			if remote_stage=="chronicle_done":
				_check(int(d.chronicles.hou_chao_yuan.step)==2 and d.chronicles.hou_chao_yuan.choices==[0],"chronicle reply advances once over ENet without duplicate replay")
				expected={"stories":d.stories.duplicate(true),"chronicles":d.chronicles.duplicate(true),"journal":d.journal.duplicate(true),"wardrobe":d.wardrobe.duplicate(true),"money":d.money}
				_check(main._persist(),"host persists ending, chronicle and personal outfit")
				var f:=FileAccess.open(str(main.save_path)+".expected.json",FileAccess.WRITE);f.store_string(JSON.stringify(expected,"",true,true));f.close()
				_signal_client("saved");_next()
		94:
			if not d.players.guest.online:_finish()

func _client()->void:
	var d:Dictionary=main.current_state()
	if d.is_empty():return
	match phase:
		0:
			if server_stage=="beat0":main.perform("appearance",appearance);_next()
		1:
			if d.wardrobe.guest==appearance and _age()>0.35:
				main.perform("town_personal_reply",{"id":"xu_mian","story":OWNER,"step":0,"reply":0});_next()
		2:
			if _age()>0.35:
				_check(d.stories.guest.is_empty(),"client cannot resolve a story through an unrelated distant NPC")
				phase=10;phase_ms=Time.get_ticks_msec()
		10:
			if server_stage=="beat%d"%beat_index and _age()>0.35:
				var beat:Dictionary=Stories.ARCS[OWNER].steps[beat_index]
				current_args={"id":beat.at,"story":OWNER,"step":beat_index}
				main.perform("town_personal_open",current_args);_next()
		11:
			if main.dialogue_ui.visible and _age()>0.35:
				_check(str(Stories.ARCS[OWNER].steps[beat_index].text) in main.dialogue_ui.body.text,"authoritative feedback opens the requested story beat")
				current_args.reply=1;main.perform("town_personal_reply",current_args);_next()
		12:
			if int(d.stories.guest.get(OWNER,{}).get("step",0))==beat_index+1 and _age()>0.35:
				main.perform("town_personal_reply",current_args);_next()
		13:
			if _age()>0.35:
				_check(int(d.stories.guest[OWNER].step)==beat_index+1,"duplicate RPC cannot advance another beat")
				main.dialogue_ui.hide();client_stage.rpc_id(1,"done%d"%beat_index)
				beat_index+=1;phase=14 if beat_index==3 else 10;phase_ms=Time.get_ticks_msec()
		14:
			if server_stage=="chronicle_gate" and _age()>0.35:
				main.perform("yard_inspect");_next()
		15:
			if int(d.get("chronicles",{}).get("hou_chao_yuan",{}).get("step",0))==1 and _age()>0.35:
				client_stage.rpc_id(1,"chronicle_xu");_next()
		16:
			if server_stage=="chronicle_xu_ready" and _age()>0.35:
				main.perform("town_chronicle_open",{"id":"xu_an","arc":"hou_chao_yuan","step":1});_next()
		17:
			if main.dialogue_ui.visible and "候潮院" in main.dialogue_ui.body.text and _age()>0.35:
				main.perform("town_chronicle_reply",{"id":"xu_an","arc":"hou_chao_yuan","step":1,"reply":0})
				main.perform("town_chronicle_reply",{"id":"xu_an","arc":"hou_chao_yuan","step":1,"reply":1})
				_next()
		18:
			if int(d.get("chronicles",{}).get("hou_chao_yuan",{}).get("step",0))==2 and _age()>0.35:
				main.dialogue_ui.hide();client_stage.rpc_id(1,"chronicle_done");_next()
		19:
			if server_stage=="saved":
				_check(d.stories.guest[OWNER].step==3 and int(d.chronicles.hou_chao_yuan.step)==2 and d.money==int(Stories.ARCS[OWNER].coins),"client receives final ending, shared chronicle and one shared reward")
				_finish()

func _resume()->void:
	var d:Dictionary=main.world.data
	_check(_json_fields({"stories":d.stories,"chronicles":d.chronicles,"journal":d.journal,"wardrobe":d.wardrobe,"money":d.money})==_json_fields(expected),"independent process restores both identities and full story/chronicle records")
	_check(d.stories.guest[OWNER].step==3 and d.stories.host.is_empty() and int(d.chronicles.hou_chao_yuan.step)==2,"guest ending remains personal and chronicle remains shared after reconnect")
	_check(d.money==int(Stories.ARCS[OWNER].coins),"restoring does not repeat reward")
	if not finished:_finish()

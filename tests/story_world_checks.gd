extends SceneTree
const World=preload("res://scripts/world_state.gd")
const Stories=preload("res://scripts/resident_stories.gd")
const Town=preload("res://scripts/island_town.gd")
const Ocean=preload("res://scripts/ocean_residents.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Inventory=preload("res://scripts/inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL "+label)
func near(w:RefCounted,slot:String,id:String)->void:
	var d:Dictionary=w.data
	var p:Dictionary=d.players[slot]
	d.minute=660
	if Town.NPCS.has(id):
		var where:=Town.location(id,660,d)
		p.area=where.area;p.room=where.room;p.x=where.at.x;p.y=where.at.y
		if p.area=="room":d.rooms.visited[p.room]=true
	else:Rooms._arrive(d,p,Ocean.NPCS[id].room,Ocean.position(id))
func _initialize()->void:
	var w:=World.new();w.join("host","船长");w.join("guest","伙伴")
	var d:Dictionary=w.data
	d.navigation.anchored=true;d.chart.visited=true
	var coast:=World.Archipelago.island_position(d.chart);d.navigation.x=coast.x;d.navigation.y=coast.y
	near(w,"host","tai_lu")
	var before:=w.snapshot();w.action("host","ocean_personal_reply",{"id":"tai_lu","story":"tai_lu","step":0,"reply":0})
	check(w.snapshot()==before,"untranslated magical dialogue cannot advance a story")
	w.action("host","ocean_personal_open",{"id":"tai_lu","story":"tai_lu","step":0})
	check(w.snapshot()==before,"untranslated magical topic cannot open or mutate progress")
	d.journal.story_step=3;d.journal.tide_speech=true
	for slot:String in ["host","guest"]:
		for owner:String in Stories.ARCS:
			var arc:Dictionary=Stories.ARCS[owner]
			for step in 3:
				var beat:Dictionary=arc.steps[step]
				d.day+=int(beat.get("delay",0));near(w,slot,beat.at)
				var prefix:="town_" if Town.NPCS.has(beat.at) else "ocean_"
				var args:Dictionary={"id":beat.at,"story":owner,"step":step}
				var message:String=w.action(slot,prefix+"personal_open",args)
				check(str(beat.text) in message,"world opens reachable "+owner+" stage "+str(step))
				for item:String in beat.get("cost",{}):Inventory.add(d.players[slot].bag,item,int(beat.cost[item]))
				args.reply=0 if slot=="host" else 1
				w.action(slot,prefix+"personal_reply",args)
				check(int(d.stories[slot].get(owner,{}).get("step",0))==step+1,"authoritative action advances personal beat")
				before=w.snapshot();w.action(slot,prefix+"personal_reply",args)
				check(w.snapshot()==before,"world rejects replay without repeat reward")
		near(w,slot,"xu_mian")
	var loaded:=World.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(w.snapshot()))),"full world accepts all finished stories in JSON")
	check(loaded.data.stories==d.stories and loaded.data.journal==d.journal,"restore preserves all choices and friend rewards")
	var old:=w.snapshot();old.version=15;old.erase("stories")
	check(loaded.restore(JSON.parse_string(JSON.stringify(old))),"actual v15 shape migrates")
	check(loaded.data.stories==Stories.create() and loaded.data.journal==d.journal and loaded.data.wardrobe==d.wardrobe,"v15 creates only missing personal story state")
	var probe:=World.new();probe.join("host","测试")
	near(probe,"host","lu_zhou")
	probe.data.players.host.area="island";before=probe.snapshot()
	probe.action("host","town_personal_reply",{"id":"lu_zhou","story":"lu_zhou","step":0,"reply":0})
	check(probe.snapshot()==before,"same coordinates in another scene do not reach resident")
	near(probe,"host","lu_zhou");probe.data.players.host.x+=65;before=probe.snapshot()
	probe.action("host","town_personal_reply",{"id":"lu_zhou","story":"lu_zhou","step":0,"reply":0})
	check(probe.snapshot()==before,"story reply outside reach cannot advance")
	probe.data.housing.carpenter=true;near(probe,"host","he_mu")
	probe.action("host","town_personal_reply",{"id":"he_mu","story":"he_mu","step":0,"reply":0})
	check(probe.data.players.host.room=="raft_cabin" and probe.data.stories.host.he_mu.step==1,"carpenter story follows relocated resident into cabin")
	print("STORY WORLD ",checks," failures=",failures);quit(1 if failures else 0)

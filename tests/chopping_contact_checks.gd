extends "res://tests/island_checks.gd"
const Motion=preload("res://scripts/tool_motion.gd")
const Activity=preload("res://scripts/island_activity.gd")
const Feedback=preload("res://scripts/scene_feedback.gd")
var tree:Dictionary={}

func _initialize()->void:
	var probe=_moored()
	for node in IslandMap.nodes_near(Vector2(2500,1700)).values():
		if node.kind!="tree" or not IslandState.active(probe.data.island,node.id,1):continue
		var clear:=true
		for offset in [Vector2(0,-56),Vector2(56,0),Vector2(-56,0),Vector2(0,56),Vector2(38,38),Vector2(-38,-38)]:
			if not Activity.chopping_stance(probe.data,_point(node)+offset,node).is_finite():clear=false
		if clear:tree=node;break
	_check(not tree.is_empty(),"real tree has unobstructed cardinal and diagonal approaches")
	if tree.is_empty():quit(1);return
	_test_approach_and_contact()
	_test_interruptions()
	_test_timing()
	_test_activity_validation()
	print("CHOP CONTACT: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)

func _fixture(offset:Vector2):
	var world=_moored()
	_place(world,"host","island",_point(tree)+offset)
	_give(world,"host","axe")
	return world

func _test_approach_and_contact()->void:
	for offset in [Vector2(0,-56),Vector2(56,0),Vector2(-56,0),Vector2(0,56),Vector2(38,38),Vector2(-38,-38),Vector2(20,0)]:
		var world=_fixture(offset)
		var p:Dictionary=world.data.players.host
		var before:=_point(p)
		world.action("host","gather_island",{"id":tree.id})
		_check(not p.activity.is_empty() and _point(p)==before,"click starts work without teleport: "+str(offset))
		for tick in 90:
			if not p.activity.get("approach",false):break
			var previous:=_point(p)
			world.tick(1.0/60)
			_check(_point(p).distance_to(previous)<=WorldState.DECK_SPEED/60+0.01,"approach never exceeds ordinary walking speed")
			_check(not p.activity.get("approach",false) or p.activity.remaining==p.activity.duration,"walking does not advance gathering or fake a swing")
		_check(not p.activity.is_empty() and not p.activity.get("approach",false),"legal nearby stance is reached")
		if p.activity.is_empty():continue
		var pose:=Motion.sample(p.activity,_point(p),_point(tree))
		var blade:Vector2=_point(p)+Motion.BLADE_OFFSETS[pose.direction]
		_check(blade.distance_to(Motion.contact(_point(tree),pose.direction))<0.1,"blade reaches trunk from near/far/diagonal click")
		var feedback=Feedback.new()
		feedback.update(world.data,"host",0)
		var guard:=0
		while not p.activity.is_empty() and guard<430:
			world.tick(1.0/60);feedback.update(world.data,"host",1.0/60);guard+=1
		_check(Inventory.count(p.bag,"wood")==int(tree.amount),"complete chopping awards exactly one tree")
		_check(feedback.effects.filter(func(e):return e.kind=="tree_fall").size()==1,"confirmed last hit produces one felling transition")
		feedback.update(world.snapshot(),"host",0)
		_check(feedback.effects.filter(func(e):return e.kind=="tree_fall").size()==1,"duplicate snapshot never replays felling")

func _test_interruptions()->void:
	for cancel in ["movement","right_click","lost_tool","full_bag"]:
		var world=_fixture(Vector2(0,56))
		var p:Dictionary=world.data.players.host
		world.action("host","gather_island",{"id":tree.id})
		if cancel=="movement":world.set_move("host",Vector2.RIGHT)
		elif cancel=="right_click":world.action("host","cancel_activity")
		elif cancel=="lost_tool":Inventory.remove(p.bag,"axe",1)
		else:Inventory.add(p.bag,"stone",(Inventory.BAG_SIZE-1)*Inventory.STACK_LIMIT)
		var feedback=Feedback.new();feedback.update(world.data,"host",0)
		for i in 420:world.tick(1.0/60);feedback.update(world.data,"host",1.0/60)
		_check(p.activity.is_empty() and Inventory.count(p.bag,"wood")==0 and IslandState.active(world.data.island,tree.id,1),cancel+" preserves uncut tree and gives no wood")
		_check(feedback.effects.all(func(e):return e.kind!="tree_fall"),cancel+" never plays success/falling animation")
	var world=_fixture(Vector2(0,70))
	var before:Dictionary=world.snapshot()
	world.action("host","gather_island",{"id":tree.id})
	_check(world.snapshot()==before,"out-of-reach click is rejected without movement or inventory change")

func _test_timing()->void:
	var activity:Dictionary={"duration":6.0,"remaining":6.0}
	var contact_starts:=0
	var was_contact:=false
	for tick in 601:
		activity.remaining=6.0-tick/100.0
		var pose:=Motion.sample(activity,Vector2(0,32),Vector2.ZERO)
		if pose.impact:
			_check(pose.frame==3,"only the downstroke/contact frame can shake the tree")
			if not was_contact:contact_starts+=1
		if pose.frame==4:_check(not pose.impact,"recovery has no hit particles")
		was_contact=pose.impact
	_check(contact_starts==8,"six-second tree has eight distinct strikes")
	var last:=Motion.sample(activity,Vector2(0,32),Vector2.ZERO)
	_check(last.frame==3 and last.final_hit and last.impact,"last strike leads directly into confirmed felling")

func _test_activity_validation()->void:
	var standing:=Motion.stance(_point(tree),3)
	var activity:Dictionary={"kind":"island_gather","id":tree.id,"duration":6.0,"remaining":6.0,"start_x":standing.x,"start_y":standing.y,"approach":true}
	_check(Activity.valid(activity),"registered approach survives serialized activity validation")
	for field in ["remaining","duration","start_x","start_y"]:
		var malformed:Dictionary=activity.duplicate();malformed.erase(field)
		_check(not Activity.valid(malformed),"missing "+field+" is rejected without an invalid dictionary access")
	for bad in [false,1,"true",null]:
		var malformed:Dictionary=activity.duplicate();malformed.approach=bad
		_check(not Activity.valid(malformed),"approach flag has a strict boolean schema")
	activity.start_x+=160
	_check(not Activity.valid(activity),"saved approach cannot point at an arbitrary remote location")

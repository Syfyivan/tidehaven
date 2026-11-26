extends SceneTree
const Inventory=preload("res://scripts/inventory.gd")
const Map=preload("res://scripts/island_map.gd")
const Activity=preload("res://scripts/island_activity.gd")
const Motion=preload("res://scripts/tool_motion.gd")
const MainScene=preload("res://main.tscn")
var main
var checks:=0
var failures:=0
var evidence:=(OS.get_environment("TIDEHAVEN_TEST_ROOT") if not OS.get_environment("TIDEHAVEN_TEST_ROOT").is_empty() else ProjectSettings.globalize_path("res://artifacts")).path_join("chopping-native-ui-")+str(Time.get_unix_time_from_system()).replace(".","-")
var captures:Array=[]
func _initialize()->void:call_deferred("_run")
func _run()->void:
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size=Vector2i(960,600) if OS.get_environment("TIDEHAVEN_CHOP_SMALL")=="1" else Vector2i(1280,800)
	main=MainScene.instantiate();root.add_child(main)
	main.save_path=evidence.path_join("world.json");main.automated=true
	create_timer(120).timeout.connect(func():printerr("CHOP UI timeout");quit(1))
	await _settle()
	await _click(main.new_game_button.get_global_rect().get_center())
	main.world.data.navigation.anchored=true
	var tree:Dictionary={}
	for node in Map.nodes_near(Vector2(2500,1700)).values():
		if node.kind=="tree" and [Vector2(0,48),Vector2(-48,0),Vector2(48,0),Vector2(0,-48),Vector2(38,38)].all(func(v):return Activity.chopping_stance(main.world.data,Vector2(node.x,node.y)+v,node).is_finite()):
			tree=node;break
	_check(not tree.is_empty(),"natural tree supports four legal approaches")
	if tree.is_empty():quit(1);return
	var target:=Vector2(tree.x,tree.y)
	for slot in ["host","guest"]:
		var p:Dictionary=main.world.data.players[slot]
		p.bag=Inventory.empty_slots(12);Inventory.add(p.bag,"axe",1)
		p.online=true;p.area="island";p.stamina=100.0
		main.world.data.players["guest" if slot=="host" else "host"].online=false
		main.local_slot=slot
		for direction in 4:
			main.world.data.island.depleted.erase(str(tree.id))
			var offset:Vector2=[Vector2(0,-48),Vector2(48,0),Vector2(-48,0),Vector2(0,48)][direction]
			p.x=target.x+offset.x;p.y=target.y+offset.y;p.activity={}
			p.stamina=100.0
			var wood_before:=Inventory.count(p.bag,"wood")
			main.view.feedback.reset()
			await _settle()
			if slot=="host":
				await _click(main.hud.slots[0].button.get_global_rect().get_center())
				await _click(main.view.get_global_transform_with_canvas()*main.view.world_to_screen(target,"island"))
			else:
				# Guest visual fixture only; real RPC checked independently.
				main.world.action("guest","gather_island",{"id":tree.id})
			_check(p.activity.get("kind","")=="island_gather","timed action starts %s direction %d"%[slot,direction])
			var seen:Array=[]
			var index:=0
			var began:=Time.get_ticks_msec()
			while not p.activity.is_empty() and index<85:
				if not p.activity.get("approach",false):
					var pose:=Motion.sample(p.activity,Vector2(p.x,p.y),target)
					if pose.frame not in seen:seen.append(pose.frame)
					_check(pose.direction==direction,"real approach preserves requested facing")
				_capture("%s-%d-%03d"%[slot,direction,index],target,Time.get_ticks_msec()-began)
				index+=1
				await _settle(0.09)
			_check(seen.size()==5,"all five native poses are visible %s/%d"%[slot,direction])
			_check(p.activity.is_empty() and Inventory.count(p.bag,"wood")==wood_before+int(tree.amount),"full action ends with one real inventory reward")
			# Physics can end the action just before this coroutine resumes; let the
			# ordinary Main._process observe that state before checking its feedback.
			await RenderingServer.frame_post_draw
			_check(main.view.feedback.effects.any(func(e):return e.kind=="tree_fall"),"actual last strike starts felling transition")
			for ending in 7:
				_capture("%s-%d-end-%d"%[slot,direction,ending],target,Time.get_ticks_msec()-began)
				await _settle(0.1)
		# Additional real input: cancel during a diagonal approach and during a swing.
		for delay in [0.0,0.45]:
			main.world.data.island.depleted.erase(str(tree.id))
			p.x=target.x+38;p.y=target.y+38;p.activity={}
			main.view.feedback.reset()
			await _settle()
			if slot=="host":await _click(main.view.get_global_transform_with_canvas()*main.view.world_to_screen(target,"island"))
			else:main.world.action("guest","gather_island",{"id":tree.id})
			await _settle(delay)
			var before_cancel:=Inventory.count(p.bag,"wood")
			if slot=="host":await _tap(KEY_P)
			else:main.world.action("guest","cancel_activity")
			_check(p.activity.is_empty() and not main.world.data.island.depleted.has(tree.id) and Inventory.count(p.bag,"wood")==before_cancel,"cancel diagonal approach/swing without reward")
	var report:=FileAccess.open(evidence.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"failures":failures,"size":[root.size.x,root.size.y],"captures":captures},"\t"));report.close()
	print("CHOP UI: %d checks, %d failures; %s"%[checks,failures,evidence])
	quit(0 if failures==0 else 1)
func _capture(name:String,target:Vector2,elapsed_ms:int)->void:
	RenderingServer.force_draw(false)
	var image:=root.get_texture().get_image()
	var center:Vector2=main.view.get_global_transform_with_canvas()*main.view.world_to_screen(target,"island")
	var crop:=Rect2i(Vector2i(center)-Vector2i(180,230),Vector2i(360,310)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	image.get_region(crop).save_png(evidence.path_join(name+".png"))
	captures.append({"file":name+".png","elapsed_ms":elapsed_ms})
func _right(at:Vector2)->void:
	await _move_mouse(at)
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down
		root.push_input(e,true);await process_frame
	await _settle()
func _drag(from:Vector2,to:Vector2)->void:
	await _move_mouse(from)
	var e:=InputEventMouseButton.new();e.position=from;e.global_position=from;e.button_index=MOUSE_BUTTON_LEFT;e.button_mask=MOUSE_BUTTON_MASK_LEFT;e.pressed=true
	root.push_input(e,true);await process_frame
	var previous:=from
	for i in range(1,9):
		var at:=from.lerp(to,i/8.0)
		var m:=InputEventMouseMotion.new();m.position=at;m.global_position=at;m.relative=at-previous;m.button_mask=MOUSE_BUTTON_MASK_LEFT
		root.push_input(m,true);previous=at;await _settle(0.04)
	e=InputEventMouseButton.new();e.position=to;e.global_position=to;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false
	root.push_input(e,true);await _settle()

func _tap(code: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()


func _move_mouse(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	await _settle()


func _click(at: Vector2) -> void:
	await _move_mouse(at)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	root.push_input(event, true)
	await _settle()


func _settle(seconds: float = 0.14) -> void:
	await create_timer(seconds).timeout
	await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", description)

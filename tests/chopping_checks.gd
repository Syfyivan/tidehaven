extends SceneTree
const Motion=preload("res://scripts/tool_motion.gd")
const Art=preload("res://scripts/chopping_art.gd")
const Player=preload("res://scripts/player_art.gd")
var checks:=0
var failures:=0
func _initialize()->void:
	var activity:Dictionary={"duration":6.0,"remaining":6.0}
	var original:=activity.duplicate(true)
	for i in 4:
		var target:Vector2=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][i]*48
		_check(Motion.sample(activity,Vector2.ZERO,target).direction==i,"actor faces resource in direction %d"%i)
	_check(activity==original,"drawing never changes authoritative activity")
	var frames:Array=[]
	for tick in 90:
		activity.remaining=6.0-tick/100.0
		var pose:Dictionary=Motion.sample(activity,Vector2.ZERO,Vector2.RIGHT)
		if pose.frame not in frames:frames.append(pose.frame)
		if pose.impact:_check(pose.frame==3,"chips only follow blade contact, never recovery")
	_check(frames.size()==5,"complete swing includes all five native tool poses")
	for slot in ["host","guest"]:
		for direction in 4:
			var contact:=Player.tool_pose(direction,3)
			var blade:Vector2=(contact.blade-Player.FOOT)*2
			_check(blade.distance_to(Motion.BLADE_OFFSETS[direction])<1.0,"native rendered blade agrees with registered stance contact")
			for frame in 5:
				var texture:Texture2D=Art.texture(slot,direction,frame)
				_check(texture.get_size()*2==Art.rect(Vector2.ZERO,direction,frame).size,"render preserves exact 2x pixel scale")
				var image:=texture.get_image()
				var opaque:=0
				var partial:=0
				for y in image.get_height():
					for x in image.get_width():
						var alpha:=image.get_pixel(x,y).a
						if alpha==1:opaque+=1
						elif alpha>0:partial+=1
				_check(opaque>80 and partial==0,"frame has full character without translucent haze")
	print("CHOP CHECKS: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
func _check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",message)

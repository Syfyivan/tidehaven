extends RefCounted
## Same native body as idle/walk, with the matching tool and foreground hands.
const Player=preload("res://scripts/player_art.gd")
static func texture(slot:String,direction:int,frame:int)->Texture2D:
	return Player.action_texture(slot,direction,frame)
static func rect(at:Vector2,_direction:int,_frame:int)->Rect2:
	return Rect2((at-Player.FOOT*2).round(),Vector2(32,64))
static func draw(canvas:Node2D,slot:String,at:Vector2,direction:int,frame:int,base:Transform2D=Transform2D.IDENTITY)->void:
	var tool:=Player.tool_pose(direction,frame)
	if tool.behind:_tool(canvas,at,direction,frame,base)
	canvas.draw_texture_rect(texture(slot,direction,frame),rect(at,direction,frame),false)
	if not tool.behind:
		_tool(canvas,at,direction,frame,base)
		canvas.draw_texture_rect(Player.action_arms_texture(slot,direction,frame),rect(at,direction,frame),false)
static func _tool(canvas:Node2D,at:Vector2,direction:int,frame:int,base:Transform2D)->void:
	var pose:=Player.tool_pose(direction,frame)
	if not pose.visible:return
	var at_tool:Vector2=(at-Player.FOOT*2+pose.position*2).round()
	var transform:=base*Transform2D(float(pose.rotation),at_tool)
	var drawn:=Rect2(-pose.origin*2,Vector2(32,64))
	if pose.flip:
		# AtlasTexture's clipped UVs do not support a negative destination width.
		transform=transform*Transform2D(Vector2(-1,0),Vector2(0,1),Vector2(32,0))
	canvas.draw_set_transform_matrix(transform)
	canvas.draw_texture_rect(Player.tool_texture(direction,frame),drawn,false)
	canvas.draw_set_transform_matrix(base)


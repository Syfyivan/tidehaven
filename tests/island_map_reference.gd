extends SceneTree
const Tiles = preload("res://scripts/island_tiles.gd")
var canvas: Node2D
var map_name := "Town"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--map="): map_name=argument.trim_prefix("--map=")
	var data := Tiles.map_data(map_name)
	root.size=Vector2i(int(data.width)*16,int(data.height)*16)
	root.content_scale_size=root.size
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	canvas=Node2D.new()
	canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(canvas)
	canvas.draw.connect(func():
		Tiles.draw_patch(canvas,map_name,Rect2i(0,0,data.width,data.height),Vector2.ZERO,1.0)
		if "--grid" in OS.get_cmdline_user_args():
			for y in range(0,int(data.height),5):
				for x in range(0,int(data.width),5):
					canvas.draw_rect(Rect2(x*16,y*16,80,80),Color(1,1,1,0.4),false)
					canvas.draw_string(ThemeDB.fallback_font,Vector2(x*16+2,y*16+13),"%d,%d"%[x,y],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	)
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	var path := ProjectSettings.globalize_path("res://artifacts/map-reference-0.11.3")
	DirAccess.make_dir_recursive_absolute(path)
	root.get_texture().get_image().save_png(path.path_join(map_name+".png"))
	print("MAP REFERENCE "+path.path_join(map_name+".png"))
	quit()

extends SceneTree
const Tiles = preload("res://scripts/island_tiles.gd")
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(1360, 960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var canvas := Node2D.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(canvas)
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(0,0,1360,960), Color("487a83"))
		for y in range(6,20):
			for x in range(0,17):
				var at := Vector2(x*78,(y-6)*62)
				canvas.draw_texture_rect_region(Tiles.texture("spring_beach",1),Rect2(at,Vector2(48,48)),Rect2(x*16,y*16,16,16))
				canvas.draw_string(ThemeDB.fallback_font,at+Vector2(0,59),"%d,%d"%[x,y],HORIZONTAL_ALIGNMENT_LEFT,-1,11)
	)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/maritime-palette.png")
	quit()

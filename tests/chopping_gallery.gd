extends SceneTree
var canvas:Node2D
const Art=preload("res://scripts/chopping_art.gd")
const Character=preload("res://scripts/character_art.gd")
func _initialize()->void:call_deferred("_run")
func _run()->void:
	root.size=Vector2i(1024,800)
	canvas=Node2D.new();root.add_child(canvas)
	canvas.draw.connect(_paint)
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/chop-0151/native-chopping-gallery.png")
	print("CHOP GALLERY saved")
	quit()
func _paint()->void:
	canvas.draw_rect(Rect2(0,0,1024,800),Color("859f65"))
	for s in 2:
		var slot:="host" if s==0 else "guest"
		for direction in 4:
			var y:=92+s*390+direction*96
			var at:=Vector2(58,y)
			canvas.draw_texture_rect(Character.texture(slot,direction,0),Character.world_rect(at),false)
			canvas.draw_line(Vector2(18,y),Vector2(980,y),Color("ead6a1"),1)
			for frame in 5:
				var point:=Vector2(170+frame*145,y)
				Art.draw(canvas,slot,point,direction,frame)

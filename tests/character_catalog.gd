extends SceneTree
const Art=preload("res://scripts/character_art.gd")
const IslandArt=preload("res://scripts/island_art.gd")
class Catalog extends Control:
	func _draw():
		draw_rect(Rect2(0,0,1280,900),Color("617b56"))
		draw_texture_rect(IslandArt.SOURCES.grass,Rect2(12,12,264,960),false)
		for row in 12:
			draw_line(Vector2(12,12+row*80),Vector2(276,12+row*80),Color.WHITE)
		for col in [16,32,48,64]:
			draw_line(Vector2(12+col*4,12),Vector2(12+col*4,892),Color.WHITE)
		for direction in 4:
			for frame in 4:
				var at=Vector2(340+frame*100,30+direction*160)
				draw_texture_rect(Art.texture("host",direction,frame),Rect2(at,Vector2(64,128)),false)
		var index=0
		for id in Art.NPC_SHEETS:
			var at=Vector2(810+index%3*120,40+int(index/3)*240)
			draw_texture_rect(Art.npc_texture(id),Rect2(at,Vector2(64,128)),false)
			draw_string(ThemeDB.fallback_font,at+Vector2(0,160),id,HORIZONTAL_ALIGNMENT_LEFT,-1,18)
			index+=1
func _initialize():
	_run.call_deferred()
func _run():
	root.size=Vector2i(1280,900)
	var canvas=Catalog.new()
	canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(canvas)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/0.11.2/character-catalog.png")
	quit()

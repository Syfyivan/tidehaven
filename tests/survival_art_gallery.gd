extends SceneTree
const Art=preload("res://scripts/art_catalog.gd")
const Character=preload("res://scripts/character_art.gd")
const IslandArt=preload("res://scripts/island_art.gd")
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1100,760)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var canvas:=Node2D.new();canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;root.add_child(canvas)
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(0,0,1100,760),Color("708f71"))
		var keys=Art.keys()
		for i in keys.size():
			var at:=Vector2(20+(i%12)*90,20+(i/12)*88)
			canvas.draw_texture_rect(Art.texture(keys[i]),Rect2(at,Art.fitted_size(keys[i],Vector2(54,54))),false)
			canvas.draw_string(ThemeDB.fallback_font,at+Vector2(0,70),keys[i],HORIZONTAL_ALIGNMENT_LEFT,-1,11)
		for i in 8:
			var key:String=["furnace","garden_empty","garden_growing","garden","hatch","orders","sea_chest","sea_chest_open"][i]
			var at:=Vector2(90+i*130,670)
			canvas.draw_texture_rect(Character.texture("host"),Rect2(at-Vector2(40,64),Vector2(32,64)),false)
			canvas.draw_texture_rect(Art.texture(key),Art.world_rect(key,at),false)
			canvas.draw_string(ThemeDB.fallback_font,at+Vector2(-30,42),key,HORIZONTAL_ALIGNMENT_LEFT,-1,11)
	)
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://artifacts/survival-art-0.13.png")
	quit()

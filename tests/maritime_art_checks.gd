extends SceneTree
const Sea = preload("res://scripts/maritime_art.gd")
const Tiles = preload("res://scripts/island_tiles.gd")
const Art = preload("res://scripts/art_catalog.gd")
const Archipelago = preload("res://scripts/archipelago.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	for key: String in Sea.REGIONS:
		var spec: Dictionary = Sea.REGIONS[key]
		var original: Image = Tiles.texture(spec.source,1).get_image()
		var original_bytes := original.get_data()
		check(Rect2i(Vector2i.ZERO,original.get_size()).encloses(spec.rect),key+": bounded source region")
		var source: Image = Sea.texture(key).get_image()
		var wet: Image = Sea.texture(key,true).get_image()
		check(source.get_size()==wet.get_size(),key+": underwater lighting preserves proportions")
		var alpha_same := true
		for y in source.get_height():
			for x in source.get_width(): alpha_same = alpha_same and source.get_pixel(x,y).a == wet.get_pixel(x,y).a
		check(alpha_same,key+": lighting preserves silhouette")
		check(original_bytes==Tiles.texture(spec.source,1).get_image().get_data(),key+": original remains unchanged")
		check(Sea.texture(key)==Sea.texture(key),key+": one cached presentation texture")
	for key in ["raft","sand"]:
		var bitmap: Image = Sea.texture(key).get_image()
		var solid := true
		for y in bitmap.get_height():
			for x in bitmap.get_width(): solid = solid and bitmap.get_pixel(x,y).a==1.0
		check(solid,key+": repeatable ground has no transparent holes")
	check(Art.texture("floor").get_image().get_data()==Sea.texture("raft").get_image().get_data(),"native board grain survives catalog; recipe and world share texture")
	check(Art.texture("floor").get_size()==Vector2(32,32),"native 32px foundation still fills 64-unit placement cell")
	var shore := Sea.outline(Vector2.ZERO,146)
	var bounded := true
	for point in shore: bounded = bounded and point.length()<=Archipelago.ISLAND_WORLD_RADIUS
	check(bounded,"island land silhouette stays inside existing navigation obstacle")
	check(Sea.WORLD_SCALE==2.0 and Sea.MINI_SCALE==0.5,"world materials and cartographic exception are explicit")
	print("MARITIME ART: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL "+label)

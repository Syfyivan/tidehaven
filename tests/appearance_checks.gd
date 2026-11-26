extends SceneTree
const World=preload("res://scripts/world_state.gd")
const Appearance=preload("res://scripts/appearance.gd")
const Player=preload("res://scripts/player_art.gd")
var count:=0
var failures:=0
func check(ok:bool,label:String)->void:
	count+=1
	if not ok:failures+=1;push_error("FAIL "+label)
func _init()->void:
	var world:=World.new();world.join("host","测试");world.join("guest","伙伴")
	var old:=world.snapshot();old.version=14;old.erase("wardrobe");old.erase("housing");old.erase("journal");old.erase("stories")
	var migrated:=World.new();check(migrated.restore(JSON.parse_string(JSON.stringify(old))),"v14 copy migrates")
	check(migrated.data.wardrobe==Appearance.create(),"old identity preserved")
	var guest_before:Dictionary=world.data.wardrobe.guest.duplicate()
	for body in 2:
		for hair in Appearance.HAIR.size():
			var spec:=Appearance.default_for("host");spec.body=body;spec.hair=hair;spec.shirt=hair;spec.skin=hair%6
			world.action("host","appearance",spec)
			Player.configure("host",spec)
			for direction in 4:
				check(Player.texture("host",direction).get_size()==Vector2(16,32),"same body grid")
				for stage in 5:check(Player.action_texture("host",direction,stage).get_size()==Vector2(16,32),"matched tool frames")
	check(world.data.wardrobe.guest==guest_before,"host cannot replace guest")
	for key:String in Appearance.KEYS:
		for invalid in [-1,999,0.5,"bad",NAN]:
			var spec:=Appearance.default_for("host");spec[key]=invalid
			var before:=world.snapshot();world.action("host","appearance",spec)
			check(world.snapshot()==before,"invalid request atomic")
	var restored:=World.new();check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"JSON restore")
	check(restored.data.wardrobe==world.data.wardrobe,"both choices round trip exact")
	print("APPEARANCE CHECKS ",count," failures=",failures)
	quit(1 if failures else 0)

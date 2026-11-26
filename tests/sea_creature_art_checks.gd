extends SceneTree
const Art=preload("res://scripts/sea_creature_art.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	for kind in Art.SOURCES:
		var previous:=PackedByteArray()
		for frame in 6:
			var source:Texture2D=Art.SOURCES[kind]
			var region:Rect2i=Art.region(kind,frame)
			check(Rect2i(Vector2i.ZERO,source.get_size()).encloses(region),kind+" crop stays in source")
			var bitmap:Image=Art.texture(kind,frame).get_image()
			check(bitmap.get_height()==64 and bitmap.get_width()*8==region.size.x,kind+" uses same 8:1 source ratio and 2x world scale")
			var visible:Rect2i=bitmap.get_used_rect()
			check(visible.size.x>=28 and visible.size.x<=68 and visible.size.y>=8 and visible.size.y<=48,kind+" silhouette stays in reviewed world budget, frame "+str(frame))
			var hard_alpha:=true
			for y in bitmap.get_height():
				for x in bitmap.get_width():
					var alpha:=bitmap.get_pixel(x,y).a
					hard_alpha=hard_alpha and (alpha==0.0 or alpha==1.0)
			check(hard_alpha,kind+" has no translucent dark halo")
			var raw:=bitmap.get_data()
			check(raw!=previous,kind+" has independent state frame "+str(frame));previous=raw
			check(Rect2(Vector2.ZERO,bitmap.get_size()).has_point(Art.anchor(kind,frame)) and Art.rect(kind,frame).position == -Art.anchor(kind,frame)*2,kind+" shared body anchor")
	for phase in {"windup":3,"charge":4,"repelled":5,"recover":5}:
		check(Art.frame({"phase":phase,"clock":0.0})=={"windup":3,"charge":4,"repelled":5,"recover":5}[phase],"state maps to actual pose "+phase)
	print("SEA CREATURE ART: %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)

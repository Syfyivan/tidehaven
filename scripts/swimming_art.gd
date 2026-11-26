extends RefCounted
## Side-view diving kit: genuine strokes/kicks, shared hood over all hairstyles.
const SOURCE=preload("res://assets/characters/swimming/diver-hood.png")
const Appearance=preload("res://scripts/appearance.gd")
const Player=preload("res://scripts/player_art.gd")
const FRAME_SIZE:=Vector2i(48,48)
const WORLD_SIZE:=Vector2(96,96)
const ANCHOR:=Vector2(24,27)
static var _frames:Dictionary={}

static func texture(slot:String,frame:int,skin:int)->Texture2D:
	var key:="%s:%d:%d"%[slot,frame,skin]
	if not _frames.has(key):
		var source:Image=SOURCE.get_image()
		var cell:=Vector2(float(source.get_width())/6,float(source.get_height())/2)
		var region:=Rect2i(Vector2i(Vector2(frame%6,frame/6)*cell),Vector2i(cell))
		var image:=source.get_region(region)
		image.convert(Image.FORMAT_RGBA8)
		# Source remains intact. Uniform nearest sampling establishes the game pixel grid.
		image.resize(FRAME_SIZE.x,FRAME_SIZE.y,Image.INTERPOLATE_NEAREST)
		var skin_color:=Player._image(Player.SKIN).get_pixel(1,Appearance.SKINS[clampi(skin,0,5)])
		for y in FRAME_SIZE.y:
			for x in FRAME_SIZE.x:
				var pixel:=image.get_pixel(x,y)
				if pixel.a<0.5:continue
				if x>25 and pixel.r>pixel.g*1.18 and pixel.g>pixel.b*1.25 and pixel.r>0.48 and pixel.g>0.30:
					var light:=clampf(pixel.v/0.8,0.5,1.3)
					image.set_pixel(x,y,Color(skin_color.r*light,skin_color.g*light,skin_color.b*light,pixel.a))
				elif slot=="guest" and pixel.g>pixel.r*1.1 and pixel.g>pixel.b*1.2:
					image.set_pixel(x,y,Color(pixel.r*0.85,pixel.g,pixel.g*0.9,pixel.a))
		_frames[key]=ImageTexture.create_from_image(image)
	return _frames[key]

static func frame(player:Dictionary,pose:Dictionary,time:float)->int:
	var activity:Dictionary=player.get("activity",{})
	if activity.get("kind")=="spear":return 10 if float(activity.get("remaining",0))>0.2 else 11
	if time-float(pose.last_move)<0.18:
		return posmod(int(time*7),6)
	return 6+posmod(int(time*2),2)

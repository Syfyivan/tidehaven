extends RefCounted
## Fixed appearances assembled from the original, matching farmer layers.
## No NPC heads, generated action bodies, resampling or per-frame body scaling.
const ROOT := "res://assets/vendor/stardew-island/player/"
const Appearance=preload("res://scripts/appearance.gd")
const MALE := preload(ROOT + "farmer_base.png")
const FEMALE := preload(ROOT + "farmer_girl_base.png")
const HAIR := preload(ROOT + "hairstyles.png")
const SHIRTS := preload(ROOT + "shirts.png")
const PANTS := preload(ROOT + "pants.png")
const SKIN := preload(ROOT + "skinColors.png")
const SHOES := preload(ROOT + "shoeColors.png")
const TOOLS := preload("res://assets/vendor/stardew-island/tools.png")
const SIZE := Vector2i(16,32)
const FOOT := Vector2(8,31)
const ACTION_FRAMES := [[66,67,68,69,70],[48,49,50,51,52],[48,49,50,51,52],[36,37,38,63,62]]
const WALK_FRAMES := [[0,1,0,2],[6,7,6,8],[6,7,6,8],[12,13,12,14]]
const FEATURE_Y := {0:1,1:2,2:2,6:1,7:2,8:2,12:0,13:1,14:1,36:1,37:1,38:0,48:1,49:0,50:-1,51:-2,52:-1,62:4,63:2,66:2,67:1,68:0,69:-1,70:1}
const APPEARANCE := {
	"host":{"hair":0,"hair_color":Color("9d603a"),"shirt":11,"pants_color":Color("547ab4"),"skin":3,"shoes":12},
	"guest":{"hair":26,"hair_color":Color("c07b44"),"shirt":17,"pants_color":Color("796049"),"skin":3,"shoes":12},
}
static var _images: Dictionary = {}
static var _frames: Dictionary = {}
static var _palettes: Dictionary = {}
static var _profiles: Dictionary = {}

static func configure(slot:String,value:Dictionary)->void:
	var checked:=Appearance.restore(value)
	if checked.is_empty() or _profiles.get(slot,{})==checked:return
	_profiles[slot]=checked
	_palettes.erase(slot)
	for key:String in _frames.keys():
		if key.begins_with(slot+":"):_frames.erase(key)

static func _male(slot:String)->bool:
	return int(_profiles.get(slot,Appearance.default_for(slot)).body)==0

static func texture(slot:String,direction:int=0,walk_frame:int=0)->Texture2D:
	return _texture(slot,clampi(direction,0,3),int(WALK_FRAMES[clampi(direction,0,3)][posmod(walk_frame,4)]),false)

static func action_texture(slot:String,direction:int,stage:int)->Texture2D:
	return _texture(slot,clampi(direction,0,3),int(ACTION_FRAMES[clampi(direction,0,3)][clampi(stage,0,4)]),false)

## Redraw this after a foreground side/down tool, keeping the native hands on the handle.
## Up-facing arms belong behind the hair; action_texture already handles that order.
static func action_arms_texture(slot:String,direction:int,stage:int)->Texture2D:
	return _texture(slot,clampi(direction,0,3),int(ACTION_FRAMES[clampi(direction,0,3)][clampi(stage,0,4)]),true)

static func _image(texture_source:Texture2D)->Image:
	var key:String=texture_source.resource_path
	if not _images.has(key):
		var value:Image=texture_source.get_image()
		value.convert(Image.FORMAT_RGBA8)
		_images[key]=value
	return _images[key]

static func _appearance(slot:String)->Dictionary:
	return Appearance.art(_profiles.get(slot,Appearance.default_for(slot)))

static func _palette(slot:String)->Dictionary:
	var who:String=slot
	if _palettes.has(who):return _palettes[who]
	var spec:=_appearance(who)
	var base:=_image(MALE if _male(who) else FEMALE)
	var result:Dictionary={}
	for i in 3:result[base.get_pixel(260+i,0).to_rgba32()]=_image(SKIN).get_pixel(i,int(spec.skin))
	for i in 4:result[base.get_pixel(268+i,0).to_rgba32()]=_image(SHOES).get_pixel(i,int(spec.shoes))
	var shirt_at:=Vector2i(int(spec.shirt)%16*8,int(spec.shirt)/16*32)
	for i in 3:
		result[base.get_pixel(256+i,0).to_rgba32()]=_image(SHIRTS).get_pixel(shirt_at.x,shirt_at.y+4-i)
	result[base.get_pixel(276,0).to_rgba32()]=Color("69764c")
	result[base.get_pixel(277,0).to_rgba32()]=Color("263525")
	_palettes[who]=result
	return result

static func _base_region(slot:String,source:Rect2i)->Image:
	var result:=_image(MALE if _male(slot) else FEMALE).get_region(source)
	var palette:=_palette(slot)
	for y in result.get_height():
		for x in result.get_width():
			var pixel:=result.get_pixel(x,y)
			if pixel.a>0 and palette.has(pixel.to_rgba32()):result.set_pixel(x,y,palette[pixel.to_rgba32()])
	return result

static func _tinted(source:Image,tint:Color)->Image:
	var result:Image=source.duplicate()
	for y in result.get_height():
		for x in result.get_width():
			var pixel:=result.get_pixel(x,y)
			if pixel.a>0:result.set_pixel(x,y,pixel*tint)
	return result

static func _over(target:Image,source:Image,at:Vector2i=Vector2i.ZERO)->void:
	target.blend_rect(source,Rect2i(Vector2i.ZERO,source.get_size()),at)

static func _texture(slot:String,direction:int,frame:int,arms_only:bool)->Texture2D:
	var who:String=slot
	var key:="%s:%d:%d:%s"%[who,direction,frame,arms_only]
	if _frames.has(key):return _frames[key]
	var rect:=Rect2i(frame%6*16,frame/6*32,16,32)
	var arm_rect:=Rect2i(rect.position+Vector2i(96,0),SIZE)
	var arms:=_base_region(who,arm_rect)
	if direction==1:arms.flip_x()
	if arms_only:
		_frames[key]=ImageTexture.create_from_image(arms)
		return _frames[key]
	var spec:=_appearance(who)
	var body:=_base_region(who,rect)
	var trousers:=_tinted(_image(PANTS).get_region(Rect2i(rect.position+Vector2i(0 if _male(who) else 96,0),SIZE)),spec.pants_color)
	if direction==1:
		body.flip_x()
		trousers.flip_x()
	_over(body,trousers)
	var feature_x:int=-1 if frame==48 else 0
	var feature_y:int=int(FEATURE_Y.get(frame,0))
	var shirt_at:=Vector2i(int(spec.shirt)%16*8,int(spec.shirt)/16*32+int([0,16,8,24][direction]))
	var shirt:=_image(SHIRTS).get_region(Rect2i(shirt_at,Vector2i(8,8)))
	var shirt_dye:=_image(SHIRTS).get_region(Rect2i(shirt_at+Vector2i(128,0),Vector2i(8,8)))
	var shirt_position:=Vector2i(4+(-feature_x if direction==1 else feature_x),14+feature_y)
	_over(body,shirt,shirt_position)
	_over(body,shirt_dye,shirt_position)
	if direction==3:_over(body,arms)
	var hair_at:=Vector2i(int(spec.hair)%8*16,int(spec.hair)/8*96+int([0,32,32,64][direction]))
	var hair:=_tinted(_image(HAIR).get_region(Rect2i(hair_at,SIZE)),spec.hair_color)
	if direction==1:hair.flip_x()
	var gender_y:int=-1 if _male(who) and int(spec.hair)>=16 else (1 if not _male(who) and int(spec.hair)<16 else 0)
	_over(body,hair,Vector2i(-feature_x if direction==1 else feature_x,feature_y+gender_y+(1 if direction==3 else 0)))
	if direction!=3:_over(body,arms)
	_frames[key]=ImageTexture.create_from_image(body)
	return _frames[key]

## Game1.drawTool translated from original 4x world coordinates to body pixels.
## Position/origin/grip/blade use the 16x32 body top-left, not the foot.
## The caller multiplies by its single world pixel scale (2), without stretching.
static func tool_pose(direction:int,stage:int)->Dictionary:
	direction=clampi(direction,0,3)
	stage=clampi(stage,0,4)
	var source_index:int=191
	var positions:Array
	var origins:Array
	var rotations:Array
	match direction:
		0:
			source_index=189 if stage<2 else 190
			positions=[Vector2(-5,-5),Vector2(-3,0),Vector2(0,8),Vector2(0,19),Vector2(0,20)]
			origins=[16,16,16,16,16]
			rotations=[0.0,-PI/24,0.0,0.0,0.0]
		1:
			positions=[Vector2(10,-6),Vector2(-4,-4),Vector2(-15,7),Vector2(-11,27),Vector2(-10,30)]
			origins=[16,16,16,16,16]
			rotations=[PI/12,-PI/12,-PI/4,-PI*7/12,-PI*7/12]
		2:
			positions=[Vector2(-9,-2),Vector2(2,9),Vector2(7,7),Vector2(15,8),Vector2(15,9)]
			origins=[16,32,32,32,32]
			rotations=[-PI/12,PI/12,PI/4,PI*7/12,PI*7/12]
		_:
			source_index=192 if stage==0 else 193
			positions=[Vector2(0,-10),Vector2(1,2),Vector2(0,8),Vector2(0,8),Vector2(0,8)]
			origins=[16,16,16,16,16]
			rotations=[0.0,0.0,0.0,0.0,0.0]
	var pivot:=Vector2(0,float(origins[stage]))
	var position:Vector2=positions[stage]
	var rotation:float=rotations[stage]
	var blade:=Vector2(11.5,18) if direction in [1,2] else (Vector2(7.5,28) if direction==0 and stage>=2 else Vector2(7.5,15))
	var grip:=Vector2(7.5,19) if direction==0 and stage>=2 else Vector2(7.5,30)
	if direction==1:
		blade.x=16-blade.x
		grip.x=16-grip.x
	# Matched native arm pixels are the anchor. The original renderer also folds in
	# Farmer bounding-box/origin offsets; don't carry those offsets into our foot grid.
	var native_grips:Array=[
		[Vector2(3,11),Vector2(6,15),Vector2(8,20),Vector2(8,22),Vector2(8,23)],
		[Vector2(13,11),Vector2(8,10),Vector2(2,12),Vector2(1,16),Vector2(1,18)],
		[Vector2(2,11),Vector2(7,10),Vector2(13,12),Vector2(14,16),Vector2(14,18)],
		[Vector2(8,12),Vector2(8,13),Vector2(8,14),Vector2(8,14),Vector2(8,14)],
	]
	# Rear-facing hands are occluded by the native body/hair; retain the original
	# tool transform there. Only visible side/front hands use pixel grip alignment.
	if direction!=3:position=Vector2(native_grips[direction][stage])-(grip-pivot).rotated(rotation)
	return {"region":Rect2i(source_index*16%336,source_index*16/336*16,16,32),
		"position":position,"origin":pivot,"rotation":rotation,"flip":direction==1,
		"behind":direction==3,"visible":direction!=3 or stage<3,
		"grip":position+(grip-pivot).rotated(rotation),
		"blade":position+(blade-pivot).rotated(rotation)}

static func tool_texture(direction:int,stage:int)->Texture2D:
	var pose:=tool_pose(direction,stage)
	var key:="tool:%s"%str(pose.region)
	if not _frames.has(key):
		var atlas:=AtlasTexture.new()
		atlas.atlas=TOOLS
		atlas.region=pose.region
		atlas.filter_clip=true
		_frames[key]=atlas
	return _frames[key]

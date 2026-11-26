extends RefCounted
const ROOT:="res://assets/characters/ocean/"
const SOURCES:={
	"bai_fan":preload(ROOT+"bai_fan.png"),
	"chi_sheng":preload(ROOT+"chi_sheng.png"),
	"chao_jia":preload(ROOT+"chao_jia.png"),
	"tai_lu":preload(ROOT+"tai_lu.png"),
	"lan_ying":preload(ROOT+"lan_ying.png"),
}
const REGIONS:={
	"bai_fan":Vector2i(16,32),
	"chi_sheng":Vector2i(16,32),
	"chao_jia":Vector2i(32,32),
	"tai_lu":Vector2i(16,16),
	"lan_ying":Vector2i(32,32),
}
static var _frames:Dictionary={}
static func texture(id:String,elapsed:float)->Texture2D:
	var frame:int=int(maxf(0.0,elapsed)*2.0)%2
	var key:=id+str(frame)
	if not _frames.has(key):
		var cell:Vector2i=REGIONS[id]
		var atlas:=AtlasTexture.new();atlas.atlas=SOURCES[id];atlas.filter_clip=true
		atlas.region=Rect2(frame*cell.x,0,cell.x,cell.y)
		_frames[key]=atlas
	return _frames[key]
static func rect(id:String,at:Vector2)->Rect2:
	return Rect2(at-Vector2(16,30),Vector2(32,32)) if id=="tai_lu" else Rect2(at-Vector2(32,48 if id=="chao_jia" else 36),Vector2(64,64)) if id in ["chao_jia","lan_ying"] else Rect2(at-Vector2(16,62),Vector2(32,64))

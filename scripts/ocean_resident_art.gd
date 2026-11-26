extends RefCounted
const ROOT:="res://assets/vendor/stardew-island/ocean-residents/"
const Player=preload("res://scripts/player_art.gd")
const SOURCES:={
	"chao_jia":preload(ROOT+"turtle.png"),
	"tai_lu":preload(ROOT+"Junimo.png"),
	"lan_ying":preload(ROOT+"SeaMonsterKrobus.png"),
	"chi_sheng":preload(ROOT+"pirates_tilesheet.png"),
}
static var _frames:Dictionary={}
static func texture(id:String,elapsed:float)->Texture2D:
	if id=="bai_fan":
		Player.configure("sea_merchant",{"body":0,"hair":4,"hair_color":4,"shirt":6,"pants":2,"skin":2})
		return Player.texture("sea_merchant",0,0)
	var frame:int=int(elapsed*2)%2
	var key:=id+str(frame)
	if not _frames.has(key):
		var atlas:=AtlasTexture.new();atlas.atlas=SOURCES[id];atlas.filter_clip=true
		atlas.region={"chao_jia":Rect2(frame*32,0,32,32),"tai_lu":Rect2(frame*16,0,16,16),"lan_ying":Rect2(frame*32,0,32,32),"chi_sheng":Rect2(240+frame*16,0,16,32)}[id]
		_frames[key]=atlas
	return _frames[key]
static func rect(id:String,at:Vector2)->Rect2:
	return Rect2(at-Vector2(16,30),Vector2(32,32)) if id=="tai_lu" else Rect2(at-Vector2(32,48 if id=="chao_jia" else 36),Vector2(64,64)) if id in ["chao_jia","lan_ying"] else Rect2(at-Vector2(16,62),Vector2(32,64))

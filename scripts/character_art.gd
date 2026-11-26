extends RefCounted
## Players share native matched appearance layers across idle/walk/tool actions.
## Residents retain their complete original sheets.
const Player=preload("res://scripts/player_art.gd")
const ROOT := "res://assets/vendor/stardew-island/characters/"
const HOST: Texture2D = Player.MALE
const GUEST: Texture2D = Player.FEMALE
const NPC_SHEETS := {
	"lu_zhou":preload(ROOT + "Alex.png"),
	"mu_tong":preload(ROOT + "Leah.png"),
	"gu_xing":preload(ROOT + "Maru.png"),
	"xu_mian":preload(ROOT + "Emily.png"),
	"chen_yu":preload(ROOT + "Elliott.png"),
	"wen_zhi":preload(ROOT + "Penny.png"),
	"qiao_xin":preload(ROOT + "Sam.png"),
	"shi_xun":preload(ROOT + "Linus.png"),
	"sen_ke":preload(ROOT + "Kent.png"),
	"xu_an":preload(ROOT + "Lewis.png"),
	"lin_sui":preload(ROOT + "Caroline.png"),
	"su_qin":preload(ROOT + "Harvey.png"),
	"tang_he":preload(ROOT + "Gus.png"),
	"he_mu":preload(ROOT + "Robin.png"),
	"yan_zhen":preload(ROOT + "Clint.png"),
	"zhou_chao":preload(ROOT + "Willy.png"),
	"tian_qing":preload(ROOT + "Marnie.png"),
	"lu_yao":preload(ROOT + "Evelyn.png"),
}
const STEP_FRAMES := [0, 1, 2, 3]
const DIRECTION_ROWS := [0,3,1,2] # Game down/left/right/up -> atlas down/right/up/left.
const IDLE_FRAME := 0
const STRIDE_STEP := 14.0
const WORLD_SIZE := Vector2(32, 64)
const FOOT_OFFSET := Vector2(16, 62)
static var _frames: Dictionary = {}

static func world_rect(at: Vector2) -> Rect2:
	return Rect2((at - FOOT_OFFSET).round(), WORLD_SIZE)

static func texture(slot: String, direction: int = 0, frame: int = 0) -> Texture2D:
	return Player.texture(slot,direction,frame)

static func npc_texture(id: String, direction: int = 0, frame: int = 0) -> Texture2D:
	assert(NPC_SHEETS.has(id), "Missing registered resident art: " + id)
	return _frame(id, NPC_SHEETS[id], direction, frame)

static func _frame(id: String, sheet: Texture2D, direction: int, frame: int) -> Texture2D:
	var row: int = DIRECTION_ROWS[clampi(direction, 0, 3)]
	var column := clampi(frame, 0, 3)
	var key := "%s:%d:%d" % [id, row, column]
	if not _frames.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(column * 16, row * 32, 16, 32)
		atlas.filter_clip = true
		_frames[key] = atlas
	return _frames[key]

# Pool water occludes the lower body; this is not a substitute for swimming frames.
static func pool_texture(slot:String,direction:int)->Texture2D:
	var source:=texture(slot,direction,0)
	var key:="pool:%s:%d:%d"%[slot,direction,source.get_instance_id()]
	if not _frames.has(key):
		var atlas:=AtlasTexture.new();atlas.atlas=source
		atlas.region=Rect2(Vector2.ZERO,Vector2(16,19));atlas.filter_clip=true
		_frames[key]=atlas
	return _frames[key]

static func step_frame(distance: float) -> int:
	return STEP_FRAMES[int(distance / STRIDE_STEP) % STEP_FRAMES.size()]

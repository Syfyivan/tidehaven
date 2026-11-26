extends RefCounted
## Players share native matched appearance layers across idle/walk/tool actions.
## Residents retain their complete original sheets.
const Player=preload("res://scripts/player_art.gd")
const HOST: Texture2D = Player.MALE
const GUEST: Texture2D = Player.FEMALE
const HARBOR_ROOT := "res://assets/characters/harbor/"
const NPC_SHEETS := {
	"lu_zhou":preload(HARBOR_ROOT + "lu_zhou.png"),
	"mu_tong":preload(HARBOR_ROOT + "mu_tong.png"),
	"gu_xing":preload(HARBOR_ROOT + "gu_xing.png"),
	"xu_mian":preload(HARBOR_ROOT + "xu_mian.png"),
	"chen_yu":preload(HARBOR_ROOT + "chen_yu.png"),
	"wen_zhi":preload(HARBOR_ROOT + "wen_zhi.png"),
	"qiao_xin":preload(HARBOR_ROOT + "qiao_xin.png"),
	"shi_xun":preload(HARBOR_ROOT + "shi_xun.png"),
	"sen_ke":preload(HARBOR_ROOT + "sen_ke.png"),
	"xu_an":preload(HARBOR_ROOT + "xu_an.png"),
	"lin_sui":preload(HARBOR_ROOT + "lin_sui.png"),
	"su_qin":preload(HARBOR_ROOT + "su_qin.png"),
	"tang_he":preload(HARBOR_ROOT + "tang_he.png"),
	"he_mu":preload(HARBOR_ROOT + "he_mu.png"),
	"yan_zhen":preload(HARBOR_ROOT + "yan_zhen.png"),
	"zhou_chao":preload(HARBOR_ROOT + "zhou_chao.png"),
	"tian_qing":preload(HARBOR_ROOT + "tian_qing.png"),
	"lu_yao":preload(HARBOR_ROOT + "lu_yao.png"),
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

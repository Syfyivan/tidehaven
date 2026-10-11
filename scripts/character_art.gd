extends RefCounted
## Unmodified PIPOYA 32px character sheets. See assets/vendor/pipoya/LICENSE.md.
const HOST: Texture2D = preload("res://assets/vendor/pipoya/Male-02-1.png")
const GUEST: Texture2D = preload("res://assets/vendor/pipoya/Female-02-1.png")
const STEP_FRAMES := [1, 0, 1, 2]
static var _frames: Dictionary = {}

static func texture(slot: String, direction: int = 0, frame: int = 1) -> Texture2D:
	var row := clampi(direction, 0, 3) # Down, left, right, up in the original sheet.
	var column := clampi(frame, 0, 2)
	var key := "%s:%d:%d" % [slot, row, column]
	if not _frames.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = HOST if slot == "host" else GUEST
		atlas.region = Rect2(column * 32, row * 32, 32, 32)
		_frames[key] = atlas
	return _frames[key]

static func step_frame(distance: float) -> int:
	return STEP_FRAMES[int(distance / 6.0) % STEP_FRAMES.size()]

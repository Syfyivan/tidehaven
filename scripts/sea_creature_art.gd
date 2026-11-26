extends RefCounted
## Untouched generated sheets; reviewed regions keep real silhouettes and 2x pixels.
const SOURCES := {
	"shark": preload("res://assets/sea-creatures/shark-0.14.png"),
	"moray": preload("res://assets/sea-creatures/moray-0.14.png"),
}
const SCALE := 2.0
static var _cache := {}
static func region(kind: String, frame: int) -> Rect2i:
	if kind == "moray" and frame == 3: return Rect2i(0,512,448,512)
	if kind == "moray" and frame == 4: return Rect2i(480,512,544,512)
	return Rect2i((frame % 3)*512,(frame / 3)*512,512,512)
static func anchor(kind: String, frame: int) -> Vector2:
	return Vector2(36 if kind == "moray" and frame == 4 else 32, 37 if frame < 3 else (34 if kind == "shark" else 32))
static func texture(kind: String, frame: int) -> Texture2D:
	frame = clampi(frame,0,5)
	var key := kind+str(frame)
	if not _cache.has(key):
		var bitmap: Image = SOURCES[kind].get_image()
		if bitmap.is_compressed(): bitmap.decompress()
		bitmap = bitmap.get_region(region(kind,frame))
		bitmap.resize(bitmap.get_width()/8,64,Image.INTERPOLATE_NEAREST)
		for y in bitmap.get_height():
			for x in bitmap.get_width():
				var c := bitmap.get_pixel(x,y)
				c.a = 1.0 if c.a >= 0.96 else 0.0
				bitmap.set_pixel(x,y,c)
		_cache[key] = ImageTexture.create_from_image(bitmap)
	return _cache[key]
static func frame(enemy: Dictionary) -> int:
	match str(enemy.phase):
		"windup": return 3
		"charge": return 4
		"recover", "repelled": return 5
	return [0,1,2,1][int(float(enemy.clock)*6.0)%4]
static func rect(kind: String, frame_index: int) -> Rect2:
	return Rect2(-anchor(kind,frame_index)*SCALE,Vector2(texture(kind,frame_index).get_size())*SCALE)

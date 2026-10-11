extends RefCounted
## Runtime presentation of the original licensed textures; never writes a PNG.
## Every prop uses a material-coloured edge, while enclosed recesses stay darker.
## Characters are deliberately outside this catalog and this colour treatment.

const WOOD := Color("987958")
const LINEN := Color("9c9981")
const METAL := Color("81928b")
const STONE := Color("939489")
const FOLIAGE := Color("7f9461")
const CERAMIC := Color("aa9980")
const WATER := Color("709d9f")
const FOOD := Color("aa8663")


static func material_color(key: String) -> Color:
	if key in ["wood", "floor", "floor_alt", "foundation", "chest", "chest_open", "treasure", "barrel", "paddle", "rod", "hook", "orders", "hatch", "rope"]:
		return WOOD
	if key in ["bedroll", "bed"]:
		return LINEN
	if key in ["scrap", "ingot", "anchor", "reinforced_hook", "hammer", "grill", "kitchen"]:
		return METAL
	if key in ["stone", "ore", "rock", "furnace"]:
		return STONE
	if key in ["leaf", "plant", "tree", "seaweed", "garden", "garden_empty", "garden_growing", "fins"]:
		return FOLIAGE
	if key in ["plastic", "fish", "purifier", "saltwater", "freshwater"]:
		return WATER
	if key in ["cup", "seed"]:
		return CERAMIC
	return FOOD


static func adapt(source: Texture2D, key: String, pixel_step: int = 1) -> Texture2D:
	if source == null:
		return null
	var original: Image = _source_image(source)
	if original == null or original.is_empty():
		return source
	# Work on a fresh RGBA image: vendor resources and their transparent silhouette
	# remain byte-for-byte unchanged, and repeated requests use ArtCatalog's cache.
	var result: Image = Image.create(original.get_width(), original.get_height(), false, Image.FORMAT_RGBA8)
	var material: Color = material_color(key)
	for y in original.get_height():
		for x in original.get_width():
			var pixel: Color = original.get_pixel(x, y)
			var shade: float = luminance(pixel)
			if pixel.a > 0.0 and shade < 0.49:
				var edge: bool = _at_edge(original, x, y, pixel_step)
				var body: Color = _nearby_material(original, x, y, pixel_step, material)
				# A brown barrel keeps a brown rim, linen keeps a fabric-coloured hem,
				# metal keeps a cool edge. Averaging only lit neighbours avoids copying
				# the old near-black ink into the new palette.
				var target: Color = body.lerp(material, 0.25)
				target = target.darkened(0.24 if edge else 0.36)
				target = _minimum_light(target, 0.43 if edge else 0.34)
				var amount: float = clampf((0.49 - shade) / 0.23, 0.0, 1.0)
				var softened: Color = pixel.lerp(target, amount)
				softened = _minimum_light(softened, 0.40 if edge else 0.31)
				softened.a = pixel.a
				pixel = softened
			result.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(result)


static func luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


static func _source_image(source: Texture2D) -> Image:
	# Explicitly crop atlas regions so neighbours from another sprite never bleed
	# into edge colour sampling. There are no margins in the prop catalog.
	if source is AtlasTexture:
		var atlas: AtlasTexture = source as AtlasTexture
		var sheet: Image = atlas.atlas.get_image()
		if sheet == null:
			return null
		if sheet.is_compressed():
			if sheet.decompress() != OK:
				return null
		return sheet.get_region(Rect2i(atlas.region))
	var bitmap: Image = source.get_image()
	if bitmap != null and bitmap.is_compressed():
		if bitmap.decompress() != OK:
			return null
	return bitmap


static func _at_edge(bitmap: Image, x: int, y: int, step: int) -> bool:
	for offset: Vector2i in [Vector2i(-step, 0), Vector2i(step, 0), Vector2i(0, -step), Vector2i(0, step)]:
		var at := Vector2i(x, y) + offset
		if at.x < 0 or at.y < 0 or at.x >= bitmap.get_width() or at.y >= bitmap.get_height():
			return true
		if bitmap.get_pixelv(at).a < 0.1:
			return true
	return false


static func _nearby_material(bitmap: Image, x: int, y: int, step: int, fallback: Color) -> Color:
	var red := 0.0
	var green := 0.0
	var blue := 0.0
	var weight_sum := 0.0
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if dx == 0 and dy == 0:
				continue
			var at := Vector2i(x + dx * step, y + dy * step)
			if at.x < 0 or at.y < 0 or at.x >= bitmap.get_width() or at.y >= bitmap.get_height():
				continue
			var pixel: Color = bitmap.get_pixelv(at)
			if pixel.a < 0.5 or luminance(pixel) < 0.49:
				continue
			var weight: float = 1.0 / float(dx * dx + dy * dy)
			red += pixel.r * weight
			green += pixel.g * weight
			blue += pixel.b * weight
			weight_sum += weight
	if weight_sum <= 0.0:
		return fallback.lightened(0.16)
	return Color(red / weight_sum, green / weight_sum, blue / weight_sum)


static func _minimum_light(color: Color, minimum: float) -> Color:
	var level: float = luminance(color)
	if level >= minimum:
		return color
	return color.lightened((minimum - level) / maxf(0.001, 1.0 - level))


static func floor_texture(alternate: bool = false) -> Texture2D:
	# Original code-native illustration of the scene's staggered warm raft planks.
	# It replaces the old red barn-wall crop in recipes and construction previews.
	var bitmap: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	bitmap.fill(Color("806b53"))
	var tones := [Color("987b5d"), Color("917458"), Color("9e8061"), Color("a18463")]
	for row in 4:
		var y: int = row * 8
		var tone: Color = tones[posmod(row + int(alternate), tones.size())]
		bitmap.fill_rect(Rect2i(0, y + 1, 32, 7), tone)
		bitmap.fill_rect(Rect2i(0, y + 1, 32, 1), tone.lightened(0.12))
		var joint: int = 9 if row % 2 == 0 else 25
		bitmap.fill_rect(Rect2i(joint, y + 1, 1, 7), Color("816b51"))
		bitmap.fill_rect(Rect2i(3, y + 4, 6, 1), tone.darkened(0.08))
		bitmap.fill_rect(Rect2i(16, y + 6, 8, 1), tone.darkened(0.07))
		bitmap.set_pixel(joint + 2, y + 3, Color("7b715d"))
	return ImageTexture.create_from_image(bitmap)


static func bedroll_texture() -> Texture2D:
	# Original linen pillow and sea-green sleeping bag, without a bed's hard frame.
	var pixels := [
		"................", ".....ssssss.....", "...ssllllllss...", "..sllhhhhhhlls..",
		"..slhhhhhhhhls..", "..sllhhhhhhlls..", "..ssssssssssss..", "..sggggggggggs..",
		"..sghhmmmmmmgs..", "..sghmmmmmmmgs..", "..sghmmmmmmmgs..", "..sghmmmmmmmgs..",
		"..sghmmmmmmmgs..", "..sghmmmmmmmgs..", "..sghmmmmmmmgs..", "..sghmmmmmmmgs..",
		"..sghmmmmmmmgs..", "..sghmmmmmmmgs..", "..sghmmmmmmmgs..", "..sggggggggggs..",
		"...sggggggggs...", "....ssssssss....", "................", "................",
	]
	var colors := {"s": Color("86846f"), "l": Color("c4b89a"), "h": Color("e5ddbb"), "g": Color("819986"), "m": Color("abc0a3")}
	var bitmap: Image = Image.create(16, 24, false, Image.FORMAT_RGBA8)
	bitmap.fill(Color.TRANSPARENT)
	for y in pixels.size():
		for x in 16:
			var code: String = str(pixels[y]).substr(x, 1)
			if colors.has(code):
				bitmap.set_pixel(x, y, colors[code])
	return ImageTexture.create_from_image(bitmap)

extends SceneTree
## CPU-readable texture contracts. Run headless; no game scene, save or input.
const Art = preload("res://scripts/art_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Recipes = preload("res://scripts/recipes.gd")
const CharacterArt = preload("res://scripts/character_art.gd")
const REQUIRED_KEYS: Array[String] = ["anchor", "autumn_seed", "axe", "barrel", "bed", "bedroll", "canopy", "chest", "chest_open", "coin", "compass", "cooked_fish", "cup", "fiber", "fins", "fire", "fish", "floor", "floor_alt", "foundation", "freshwater", "furnace", "garden", "garden_empty", "garden_growing", "grill", "hammer", "harpoon", "hatch", "hoe", "hook", "ingot", "kitchen", "leaf", "meal", "orders", "ore", "paddle", "pickaxe", "plant", "plastic", "purifier", "reinforced_hook", "rock", "rod", "rope", "saltwater", "scrap", "scythe", "seaweed", "seed", "seeds", "stone", "summer_seed", "treasure", "tree", "veg", "watering_can", "winter_seed", "wood"]
const QUANTIZATION_TOLERANCE: float = 1.1 / 255.0
var checks: int = 0
var failures: int = 0
var edge_pixels: int = 0
var recolored_pixels: int = 0


func _initialize() -> void:
	var before_character: PackedByteArray = CharacterArt.texture("host", 0, 1).get_image().get_data()
	var all_keys: Array[String] = Art.keys()
	_check(all_keys == REQUIRED_KEYS, "catalog exposes all 60 distinct, sorted prop and state keys")
	_check(Art.texture("missing_prop") == null, "unknown keys remain absent instead of borrowing unrelated artwork")
	for key: String in all_keys:
		_check_key(key)
	for item: String in Inventory.ITEMS:
		_check(item in all_keys and Art.item_icon(item) == Art.texture(item), item + ": inventory and world share the exact cached texture")
	for recipe: Dictionary in Recipes.ALL.values():
		var key: String = str(recipe.result) if not str(recipe.result).is_empty() else str(recipe.structure)
		_check(key in all_keys and Art.texture(key) != null, str(recipe.id) + ": crafting result has catalog artwork, including foundation")
	for key: String in ["chest_open", "furnace", "grill"]:
		_check_recess(key)
	_check(Art.texture("bedroll").get_size() == Vector2(16, 24) and Art.texture("bed").get_size() == Vector2(16, 32), "sleeping bag and framed bed retain distinct silhouettes")
	_check(Art.texture("floor").get_size() == Vector2(32, 32) and Art.texture("foundation").get_image().get_data() == Art.texture("floor").get_image().get_data(), "foundation recipe uses the same native wooden boards as floor")
	_check(CharacterArt.texture("host", 0, 1).get_image().get_data() == before_character, "processing the entire prop catalog leaves accepted character pixels unchanged")
	_check(edge_pixels > 0 and recolored_pixels > 0, "checks actually visited visible contours and changed source pixels")
	print("PROP ART CHECKS: %d checks, %d failures; %d edge pixels, %d recolored pixels" % [checks, failures, edge_pixels, recolored_pixels])
	quit(0 if failures == 0 else 1)


func _check_key(key: String) -> void:
	var source: Texture2D = Art.source_texture(key)
	var before: Image = source.get_image() if source != null else null
	var source_bytes: PackedByteArray = before.get_data() if before != null else PackedByteArray()
	var texture: Texture2D = Art.texture(key)
	_check(source != null and texture != null, key + ": source and presented texture exist")
	if source == null or texture == null:
		return
	var after: Image = texture.get_image()
	_check(before != null and after != null and not before.is_empty() and not after.is_empty(), key + ": textures expose nonempty pixel data")
	if before == null or after == null or before.is_empty() or after.is_empty():
		return
	_check(before.get_size() == after.get_size() and source.get_size() == texture.get_size(), key + ": palette keeps source dimensions and atlas region")
	_check(Art.texture(key) == texture and Art.item_icon(key) == texture, key + ": redraws and both callers reuse one cached texture")
	if before.get_size() != after.get_size():
		return
	var alpha_preserved: bool = true
	var contour_readable: bool = true
	var highlights_preserved: bool = true
	var interior_readable: bool = true
	var has_opaque_pixels: bool = false
	var min_value: float = 1.0
	var max_value: float = 0.0
	var step: int = 2 if Art.MATERIAL_ICONS.has(key) else 1
	for y: int in before.get_height():
		for x: int in before.get_width():
			var old: Color = before.get_pixel(x, y)
			var shown: Color = after.get_pixel(x, y)
			alpha_preserved = alpha_preserved and absf(old.a - shown.a) <= QUANTIZATION_TOLERANCE
			if old.a <= 0.0:
				continue
			has_opaque_pixels = true
			var value: float = _luma(shown)
			min_value = minf(min_value, value)
			max_value = maxf(max_value, value)
			if _exposed(before, Vector2i(x, y), step):
				edge_pixels += 1
				contour_readable = contour_readable and value >= 0.40 - QUANTIZATION_TOLERANCE
			else:
				interior_readable = interior_readable and value >= 0.31 - QUANTIZATION_TOLERANCE
			if _luma(old) >= 0.49:
				highlights_preserved = highlights_preserved and _rgb_delta(old, shown) <= QUANTIZATION_TOLERANCE
			if _rgb_delta(old, shown) > QUANTIZATION_TOLERANCE:
				recolored_pixels += 1
	_check(alpha_preserved and has_opaque_pixels, key + ": nonempty silhouette and every transparent/opaque alpha value are preserved")
	_check(contour_readable and interior_readable, key + ": contours have no near-black rims while inner shadows remain readable")
	_check(highlights_preserved and max_value - min_value > 0.025, key + ": lit pixels and useful colour variation survive the treatment")
	_check(source.get_image().get_data() == source_bytes, key + ": adaptation does not mutate the source image")


func _check_recess(key: String) -> void:
	var bitmap: Image = Art.texture(key).get_image()
	var darkest_inside: float = 1.0
	var lightest: float = 0.0
	var inside_found: bool = false
	for y: int in bitmap.get_height():
		for x: int in bitmap.get_width():
			var pixel: Color = bitmap.get_pixel(x, y)
			if pixel.a < 0.5:
				continue
			var value: float = _luma(pixel)
			lightest = maxf(lightest, value)
			if not _exposed(bitmap, Vector2i(x, y), 1):
				inside_found = true
				darkest_inside = minf(darkest_inside, value)
	_check(inside_found and darkest_inside >= 0.31 - QUANTIZATION_TOLERANCE and lightest - darkest_inside >= 0.10, key + ": cavity remains visibly darker than the lit rim/body")


func _exposed(bitmap: Image, at: Vector2i, step: int) -> bool:
	var bounds: Rect2i = Rect2i(Vector2i.ZERO, bitmap.get_size())
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = at + direction * step
		if not bounds.has_point(neighbor) or bitmap.get_pixelv(neighbor).a < 0.1:
			return true
	return false


func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _rgb_delta(first: Color, second: Color) -> float:
	return maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b)))


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", description)

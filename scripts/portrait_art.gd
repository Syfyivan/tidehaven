extends RefCounted
## Portraits use the same source identity as the resident's complete world sprite.
const CharacterArt = preload("res://scripts/character_art.gd")
static var _portraits: Dictionary = {}

static func texture(npc_id: String) -> Texture2D:
	if not CharacterArt.NPC_SHEETS.has(npc_id):
		return null
	if not _portraits.has(npc_id):
		var filename: String = CharacterArt.NPC_SHEETS[npc_id].resource_path.get_file()
		var path := "res://assets/vendor/stardew-island/portraits/" + filename
		if not ResourceLoader.exists(path):
			return null
		var source = load(path)
		if not source is Texture2D or source.get_width() < 64 or source.get_height() < 64:
			return null
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(0, 0, 64, 64)
		atlas.filter_clip = true
		_portraits[npc_id] = atlas
	return _portraits[npc_id]

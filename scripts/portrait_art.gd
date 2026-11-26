extends RefCounted
## Portraits match each character's world sprite identity (64x64 -> 2x UI).
## Supports P2-08a Chinese harbor sheets, 5 ocean companions, and town residents.
const CharacterArt = preload("res://scripts/character_art.gd")
const OceanResidents = preload("res://scripts/ocean_residents.gd")
static var _portraits: Dictionary = {}

static func texture(npc_id: String) -> Texture2D:
	if _portraits.has(npc_id):
		return _portraits[npc_id]
	var path := ""
	if npc_id in ["yan_zhen", "mu_tong"]:
		path = "res://assets/portraits/harbor/" + npc_id + ".png"
	elif OceanResidents.NPCS.has(npc_id):
		path = "res://assets/portraits/ocean/" + npc_id + ".png"
	elif CharacterArt.NPC_SHEETS.has(npc_id):
		var filename: String = CharacterArt.NPC_SHEETS[npc_id].resource_path.get_file()
		path = "res://assets/vendor/stardew-island/portraits/" + filename
	else:
		return null
	return _load_atlas(npc_id, path)

static func player_texture(profile: Dictionary) -> Texture2D:
	var key := "player_female" if int(profile.get("body", 0)) == 1 else "player_male"
	return _load_atlas(key, "res://assets/portraits/harbor/" + key + ".png")

static func _load_atlas(cache_key: String, path: String) -> Texture2D:
	if _portraits.has(cache_key):
		return _portraits[cache_key]
	if not ResourceLoader.exists(path):
		return null
	var source = load(path)
	if not source is Texture2D or source.get_width() < 64 or source.get_height() < 64:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(0, 0, 64, 64)
	atlas.filter_clip = true
	_portraits[cache_key] = atlas
	return atlas

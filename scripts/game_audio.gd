extends Node
## Read-only soundscape observer and WAV player pool.
## Never mutates WorldState, world saves or network messages; silent on initial snapshot.
const ToolMotion = preload("res://scripts/tool_motion.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const Rooms = preload("res://scripts/rooms.gd")
const SETTINGS_PATH := "user://audio_settings.json"
const CUES := [
	"ui_click", "dialogue_open", "hook_cast", "splash", "pickup",
	"build", "chop_hit", "tree_fall", "mine_hit", "spear", "alert", "craft_ready",
]
const AMBIENTS := ["sea_ambient", "underwater_ambient", "island_ambient"]
const VOLUMES := {
	"ui_click": -11.0, "dialogue_open": -10.0, "hook_cast": -8.0, "splash": -7.5,
	"pickup": -9.0, "build": -7.5, "chop_hit": -7.0, "tree_fall": -6.0,
	"mine_hit": -8.5, "spear": -8.0, "alert": -8.5, "craft_ready": -9.0,
	"sea_ambient": -18.0, "underwater_ambient": -17.0, "island_ambient": -19.0,
}

static var _streams: Dictionary = {}
var muted := false
var persist_settings := true
var current_ambient := ""
var recent_events: Array[String] = []
var _players: Array[AudioStreamPlayer] = []
var _ambient_player: AudioStreamPlayer
var _next_player := 0
var _initialized := false
var _seen_refs: Array = []
var _prev: Dictionary = {}
var _last_cue_ms: Dictionary = {}

func _ready() -> void:
	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_ambient_player = AudioStreamPlayer.new()
	add_child(_ambient_player)
	if persist_settings:
		_load_settings()

static func stream(cue: String) -> AudioStreamWAV:
	if _streams.has(cue):
		return _streams[cue]
	var path := "res://assets/audio/%s.wav" % cue
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var offset := 12
	var sample_rate := 22050
	var channels := 1
	var bits := 16
	var pcm := PackedByteArray()
	while offset + 8 <= bytes.size():
		var chunk_id := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var chunk_size := bytes.decode_u32(offset + 4)
		var body_start := offset + 8
		if body_start + chunk_size > bytes.size():
			break
		if chunk_id == "fmt " and chunk_size >= 16:
			channels = bytes.decode_u16(body_start + 2)
			sample_rate = bytes.decode_u32(body_start + 4)
			bits = bytes.decode_u16(body_start + 14)
		elif chunk_id == "data":
			pcm = bytes.slice(body_start, body_start + chunk_size)
			break
		offset = body_start + chunk_size + (chunk_size % 2)
	if pcm.is_empty() or bits != 16:
		return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = channels == 2
	wav.data = pcm
	if cue in AMBIENTS:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = pcm.size() / (2 * maxi(1, channels))
	_streams[cue] = wav
	return wav

func reset() -> void:
	_initialized = false
	_prev.clear()
	_seen_refs.clear()
	_stop_ambient()

func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for p in _players:
			p.stop()
		_ambient_player.stop()
	elif not current_ambient.is_empty():
		_apply_ambient(current_ambient, false)
	if _can_persist():
		_save_settings()

func _can_persist() -> bool:
	return persist_settings and (get_parent() == null or not bool(get_parent().get("automated")))

func toggle_muted() -> bool:
	set_muted(not muted)
	return muted

func play(cue: String) -> void:
	if cue not in CUES:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_cue_ms.get(cue, -1000)) < 35:
		return
	_last_cue_ms[cue] = now
	_record(cue)
	if muted or _players.is_empty():
		return
	var wav := stream(cue)
	if wav == null:
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = wav
	player.volume_db = float(VOLUMES.get(cue, -9.0))
	player.play()

func observe(data: Dictionary, slot: String, feedback_effects: Array, active_session: bool) -> void:
	if not active_session or data.is_empty() or not data.get("players", {}).has(slot):
		reset()
		return
	var snapshot := _sample(data, slot)
	_update_ambient(snapshot)
	if not _initialized or snapshot.elapsed < float(_prev.get("elapsed", 0.0)) or snapshot.slot != _prev.get("slot", ""):
		_initialized = true
		_prev = snapshot
		_seen_refs = feedback_effects.duplicate()
		return
	# Consume newly added SceneFeedback effects accurately even when older effects expire.
	for effect: Dictionary in feedback_effects:
		if _seen_refs.has(effect):
			continue
		match str(effect.get("kind", "")):
			"splash": play("splash")
			"gain": play("pickup")
			"build": play("build")
			"ready": play("craft_ready")
			"tree_fall": play("tree_fall")
	_seen_refs = feedback_effects.duplicate()
	if snapshot.day > int(_prev.get("day", snapshot.day)):
		play("craft_ready")
	if not _prev.hook_active and snapshot.hook_active:
		play("hook_cast")
	if not _prev.fishing_active and snapshot.fishing_active:
		play("hook_cast")
	if not _prev.spear_active and snapshot.spear_active:
		play("spear")
	if not _prev.chop_impact and snapshot.chop_impact:
		play("chop_hit")
	if not _prev.mine_impact and snapshot.mine_impact:
		play("mine_hit")
	if (not _prev.threat_windup and snapshot.threat_windup) or (not _prev.low_oxygen and snapshot.low_oxygen):
		play("alert")
	_prev = snapshot

func _sample(data: Dictionary, slot: String) -> Dictionary:
	var player: Dictionary = data.players[slot]
	var area := str(player.get("area", "deck"))
	var room := str(player.get("room", ""))
	var hook: Dictionary = player.get("hook", {})
	var fishing: Dictionary = player.get("fishing", {})
	var activity: Dictionary = player.get("activity", {})
	var chop_impact := false
	var mine_impact := false
	var spear_active := str(activity.get("kind", "")) == "spear" and str(activity.get("phase", "")) != "cooldown"
	if str(activity.get("kind", "")) == "island_gather" and not bool(activity.get("approach", false)):
		var resource := IslandMap.node(str(activity.get("id", "")))
		if not resource.is_empty():
			var motion := ToolMotion.sample(activity, Vector2(float(player.x), float(player.y)), Vector2(float(resource.x), float(resource.y)), str(resource.kind))
			if bool(motion.impact):
				if str(resource.get("tool", "")) == "axe":
					chop_impact = true
				elif str(resource.get("tool", "")) == "pickaxe":
					mine_impact = true
	elif str(activity.get("kind", "")) == "room_mine" and not bool(activity.get("approach", false)):
		var nodes := Rooms.nodes(str(activity.get("room", "")))
		if nodes.has(str(activity.get("id", ""))):
			var node: Dictionary = nodes[str(activity.get("id", ""))]
			var tool_id := str(node.get("tool", "pickaxe"))
			if tool_id == "axe":
				var motion := ToolMotion.sample(activity, Vector2(float(player.x), float(player.y)), Vector2(float(node.x), float(node.y)), "wood")
				chop_impact = bool(motion.impact)
			else:
				var swing := fposmod((float(activity.get("duration", 1.0)) - float(activity.get("remaining", 0.0))) * 1.5, 1.0)
				mine_impact = swing > 0.55 and swing < 0.75
	var threat_windup := false
	if area == "water":
		for enemy: Dictionary in data.get("threats", {}).get("enemies", {}).values():
			if str(enemy.get("phase", "")) == "windup" and Vector2(float(enemy.get("x", 0)), float(enemy.get("y", 0))).distance_to(Vector2(float(player.x), float(player.y))) < 260.0:
				threat_windup = true
				break
	var underwater := Rooms.underwater(player)
	return {
		"slot": slot,
		"elapsed": float(data.get("elapsed", 0.0)),
		"day": int(data.get("day", 1)),
		"area": area,
		"room": room,
		"underwater": underwater,
		"hook_active": not hook.is_empty() and str(hook.get("phase", "")) == "out",
		"fishing_active": not fishing.is_empty(),
		"spear_active": spear_active,
		"chop_impact": chop_impact,
		"mine_impact": mine_impact,
		"threat_windup": threat_windup,
		"low_oxygen": underwater and float(player.get("oxygen", 100.0)) <= 25.0,
	}

func _update_ambient(snapshot: Dictionary) -> void:
	var wanted := "sea_ambient"
	var quiet_room := false
	if bool(snapshot.underwater):
		wanted = "underwater_ambient"
	elif snapshot.area == "island" or (snapshot.area == "room" and str(snapshot.room).begins_with("island_")):
		wanted = "island_ambient"
	elif snapshot.area == "room":
		wanted = "island_ambient" if str(snapshot.room) != "raft_cabin" else "sea_ambient"
		quiet_room = true
	if wanted != current_ambient or (_ambient_player != null and not muted and not _ambient_player.playing):
		current_ambient = wanted
		_apply_ambient(wanted, quiet_room)
	elif _ambient_player != null and not muted:
		_ambient_player.volume_db = float(VOLUMES.get(wanted, -18.0)) - (6.0 if quiet_room else 0.0)

func _apply_ambient(cue: String, quiet_room: bool) -> void:
	if _ambient_player == null or muted:
		return
	var wav := stream(cue)
	if wav == null:
		return
	if _ambient_player.stream != wav:
		_ambient_player.stream = wav
	_ambient_player.volume_db = float(VOLUMES.get(cue, -18.0)) - (6.0 if quiet_room else 0.0)
	if not _ambient_player.playing:
		_ambient_player.play()

func _stop_ambient() -> void:
	current_ambient = ""
	if _ambient_player != null:
		_ambient_player.stop()

func _record(cue: String) -> void:
	if recent_events.size() >= 32:
		recent_events.pop_front()
	recent_events.append(cue)

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if parsed is Dictionary and parsed.get("muted") is bool:
		muted = bool(parsed.muted)

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"muted": muted}))
		file.close()

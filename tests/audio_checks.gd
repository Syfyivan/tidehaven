extends SceneTree
## Verifies WAV loading, silent initial/duplicate snapshots, full-bag silence,
## chop-contact-only audio sync, ambient switching, and mute control.
const GameAudio = preload("res://scripts/game_audio.gd")
const SceneFeedback = preload("res://scripts/scene_feedback.gd")
const WorldState = preload("res://scripts/world_state.gd")
const Inventory = preload("res://scripts/inventory.gd")
const IslandMap = preload("res://scripts/island_map.gd")
const IslandState = preload("res://scripts/island_state.gd")
var checks := 0
var failures := 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL audio: ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for cue in GameAudio.CUES + GameAudio.AMBIENTS:
		var wav := GameAudio.stream(cue)
		_check(wav != null and wav.format == AudioStreamWAV.FORMAT_16_BITS and wav.data.size() > 1000, "stream loads 16-bit PCM: " + cue)
		if cue in GameAudio.AMBIENTS:
			_check(wav != null and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_end > 40000, "ambient loop configured: " + cue)

	var audio := GameAudio.new()
	audio.persist_settings = false
	root.add_child(audio)
	await process_frame

	var world := WorldState.new()
	world.join("host", "测试")
	var feedback := SceneFeedback.new()
	feedback.update(world.data, "host", 0.0)
	audio.observe(world.data, "host", feedback.effects, true)
	_check(audio.recent_events.is_empty(), "initial snapshot is completely silent")
	_check(audio.current_ambient == "sea_ambient", "deck starts sea ambient")

	# Duplicate snapshot must remain silent
	feedback.update(world.snapshot(), "host", 0.0)
	audio.observe(world.snapshot(), "host", feedback.effects, true)
	_check(audio.recent_events.is_empty(), "duplicate snapshot triggers zero sounds")

	# Hook cast triggers hook_cast
	audio._last_cue_ms.clear()
	world.action("host", "hook", {"x": 1.0, "y": 0.0})
	world.tick(0.05)
	feedback.update(world.data, "host", 0.05)
	audio.observe(world.data, "host", feedback.effects, true)
	_check("hook_cast" in audio.recent_events, "throwing salvage hook plays hook_cast")

	# Full bag must NOT play pickup sound when hook returns salvage
	for i in Inventory.BAG_SIZE:
		world.data.players.host.bag[i] = {"item": "stone", "count": Inventory.STACK_LIMIT}
	world.data.elapsed += 0.02
	feedback.update(world.data, "host", 0.02)
	audio.observe(world.data, "host", feedback.effects, true)
	audio.recent_events.clear()
	audio._last_cue_ms.clear()
	world.data.drift.drift_00.x = world.data.players.host.x + 24.0
	world.data.drift.drift_00.y = world.data.players.host.y
	world.data.drift.drift_00.active = true
	for step in 30:
		world.tick(0.05)
		feedback.update(world.data, "host", 0.05)
		audio.observe(world.data, "host", feedback.effects, true)
	_check("pickup" not in audio.recent_events, "full bag produces no false pickup sound")

	# Confirmed item gain plays pickup
	world.data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	feedback.update(world.data, "host", 0.02)
	audio.observe(world.data, "host", feedback.effects, true)
	audio.recent_events.clear()
	audio._last_cue_ms.clear()
	Inventory.add(world.data.players.host.bag, "wood", 2)
	world.data.elapsed += 0.1
	feedback.update(world.data, "host", 0.1)
	audio.observe(world.data, "host", feedback.effects, true)
	_check("pickup" in audio.recent_events, "confirmed inventory gain plays pickup")

	# Diving switches ambient to underwater_ambient and plays splash
	audio.recent_events.clear()
	audio._last_cue_ms.clear()
	Inventory.add(world.data.players.host.bag, "anchor", 1)
	Inventory.add(world.data.players.host.bag, "harpoon", 1)
	world.action("host", "drop_anchor")
	world.data.players.host.x = 384.0
	world.data.players.host.y = 224.0
	world.action("host", "dive")
	world.data.elapsed += 0.1
	feedback.update(world.data, "host", 0.1)
	audio.observe(world.data, "host", feedback.effects, true)
	_check("splash" in audio.recent_events and audio.current_ambient == "underwater_ambient", "diving plays splash and switches to underwater ambient")

	# Spear action plays spear cue
	audio.recent_events.clear()
	audio._last_cue_ms.clear()
	world.action("host", "spear", {"x": 1.0, "y": 0.0})
	world.data.elapsed += 0.05
	feedback.update(world.data, "host", 0.05)
	audio.observe(world.data, "host", feedback.effects, true)
	_check("spear" in audio.recent_events, "firing harpoon plays spear cue")

	# Chopping tree plays chop_hit ONLY on actual blade impact window, then tree_fall on depletion
	var IslandActivity = preload("res://scripts/island_activity.gd")
	var tree_node := {}
	for node in IslandMap.nodes_near(Vector2(2500, 1700)).values():
		if node.kind == "tree" and IslandState.active(world.data.island, node.id, 1):
			if IslandActivity.chopping_stance(world.data, Vector2(float(node.x), float(node.y) + 32.0), node).is_finite():
				tree_node = node
				break
	if not tree_node.is_empty():
		world.data.chart.visited = true
		world.data.players.host.area = "island"
		world.data.players.host.x = float(tree_node.x)
		world.data.players.host.y = float(tree_node.y) + 32.0
		world.data.players.host.activity = {}
		world.data.players.host.stamina = 100.0
		Inventory.add(world.data.players.host.bag, "axe", 1)
		world.data.elapsed += 0.1
		feedback.update(world.data, "host", 0.1)
		audio.observe(world.data, "host", feedback.effects, true)
		_check(audio.current_ambient == "island_ambient", "island switches to island_ambient")
		audio.recent_events.clear()
		world.action("host", "gather_island", {"id": tree_node.id})
		var chop_hits := 0
		for step in 450:
			audio._last_cue_ms.clear()
			var before_len := audio.recent_events.size()
			world.tick(1.0 / 60.0)
			feedback.update(world.data, "host", 1.0 / 60.0)
			audio.observe(world.data, "host", feedback.effects, true)
			for ev_i in range(before_len, audio.recent_events.size()):
				if audio.recent_events[ev_i] == "chop_hit":
					chop_hits += 1
			if world.data.players.host.activity.is_empty():
				break
		_check(chop_hits == 8 and "tree_fall" in audio.recent_events, "6s tree chop plays 8 synchronized chop_hit cues and 1 tree_fall")

	# Mute toggle stops playback cleanly without losing state
	var world_before := world.snapshot()
	_check(audio.toggle_muted() == true and audio.muted, "toggle_muted enables mute")
	_check(not audio._ambient_player.playing, "muting stops ambient player")
	_check(audio.toggle_muted() == false and not audio.muted, "toggle_muted un-mutes")
	_check(world.snapshot() == world_before, "audio mute never mutates world state")

	audio.queue_free()
	await process_frame
	print("AUDIO CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

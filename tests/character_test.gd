extends SceneTree
const CharacterArt = preload("res://scripts/character_art.gd")
const WorldView = preload("res://scripts/world_view.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	for slot in ["host", "guest"]:
		for direction in 4:
			for frame in 3:
				var texture := CharacterArt.texture(slot, direction, frame)
				_check(texture.get_size() == Vector2(32, 32) and not texture.get_image().is_invisible(), "%s direction %d frame %d contains artwork" % [slot, direction, frame])
	_check(CharacterArt.HOST != CharacterArt.GUEST, "partners have distinct source artwork")
	var view := WorldView.new()
	view._elapsed = 5
	var pose: Dictionary = view._character_pose("host", Vector2(480, 288), "deck")
	_check(pose.frame == 1 and pose.direction == 0, "spawn starts on neutral down frame")
	for sample in [{"at": Vector2(488, 288), "direction": 2}, {"at": Vector2(480, 288), "direction": 1}, {"at": Vector2(480, 280), "direction": 3}, {"at": Vector2(480, 288), "direction": 0}]:
		view._elapsed += 0.1
		pose = view._character_pose("host", sample.at, "deck")
		_check(pose.direction == sample.direction, "movement faces actual direction %d" % sample.direction)
	var distance: float = pose.distance
	pose = view._character_pose("host", Vector2(480, 288), "deck")
	_check(pose.distance == distance, "redraw without movement does not advance stride")
	view._elapsed += 0.2
	pose = view._character_pose("host", Vector2(480, 288), "deck")
	_check(pose.frame == 1, "stopping returns to neutral stance")
	view._elapsed = 0
	pose = view._character_pose("host", Vector2(480, 288), "deck")
	_check(pose.frame == 1 and pose.distance == 0 and pose.direction == 0, "new world resets the previous world's stride and facing")
	pose = view._character_pose("host", Vector2(160, 190), "water")
	_check(pose.distance == 0 and pose.frame == 1, "scene switch resets visual motion")
	view.free()
	print("CHARACTER TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

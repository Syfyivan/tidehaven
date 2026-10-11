extends SceneTree
## Geometry contract only: the renderer never changes gameplay positions.
const WorldView = preload("res://scripts/world_view.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var view = WorldView.new()
	view.state = {"elapsed": 0.0, "deck_tiles": ["6,3", "7,3", "8,3", "6,4", "7,4", "8,4", "6,5", "7,5", "8,5"]}
	view.position = Vector2(10, 8)
	view.scale = Vector2(1.4, 1.4)
	var points := [Vector2(384, 192), Vector2(576, 192), Vector2(384, 384), Vector2(576, 384), Vector2(480, 288), Vector2(128, 128), Vector2(768, 448)]
	var bounded := true
	var rotation_bounded := true
	var rigid := true
	var invertible := true
	var unchanged := true
	var ocean_fixed := true
	var deterministic := true
	var maximum_motion := 0.0
	for phase in 240:
		view.state.elapsed = float(phase) * 0.375
		var before: Dictionary = view.state.duplicate(true)
		var motion: Transform2D = view.deck_transform()
		bounded = bounded and motion.origin.length() <= 2.5
		rotation_bounded = rotation_bounded and absf(motion.get_rotation()) <= deg_to_rad(0.2)
		rigid = rigid and is_equal_approx(motion.x.length(), 1.0) and is_equal_approx(motion.y.length(), 1.0) and absf(motion.x.dot(motion.y)) < 0.00001
		deterministic = deterministic and motion.is_equal_approx(view.deck_transform())
		for point in points:
			var rendered: Vector2 = view.world_to_screen(point)
			maximum_motion = maxf(maximum_motion, rendered.distance_to(point))
			bounded = bounded and rendered.distance_to(point) <= 2.5
			invertible = invertible and view.screen_to_world(rendered).distance_to(point) < 0.001
			invertible = invertible and rendered.distance_to(motion * point) < 0.001
			ocean_fixed = ocean_fixed and view.world_to_screen(point, "water") == point and view.screen_to_world(point, "water") == point
			ocean_fixed = ocean_fixed and view.world_to_screen(point, "drift") == point and view.screen_to_world(point, "drift") == point
		unchanged = unchanged and view.state == before
	_check(bounded, "raft translation and sampled deck/expanded corners stay within 2.5 local pixels")
	_check(rotation_bounded, "gentle hull roll never exceeds 0.2 degrees")
	_check(rigid, "raft transform preserves lengths and right angles, with no zoom")
	_check(invertible, "pointer inverse returns every tested logical raft corner")
	_check(ocean_fixed, "water and drift keep untransformed canvas coordinates")
	_check(deterministic, "paused elapsed time produces exactly the same raft transform")
	_check(maximum_motion > 0.8, "elapsed time produces visible but bounded raft motion")
	_check(unchanged, "render coordinate helpers do not mutate gameplay data")
	view.free()
	print("VIEW MOTION TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

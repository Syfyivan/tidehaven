extends RefCounted
## Host-owned travel. The camera stays with the raft; salvage uses relative velocity.
const CURRENT := Vector2(6, 0.6)
const DRAG := 0.75
const STROKE := 25.0
const MAX_PUSH := 38.0
const COOLDOWN := 0.7

static func create(anchored := false) -> Dictionary:
	return {"x": 0.0, "y": 0.0, "distance": 0.0, "anchored": anchored, "moored": false, "push_x": 0.0, "push_y": 0.0, "host_cooldown": 0.0, "guest_cooldown": 0.0}

static func velocity(nav: Dictionary) -> Vector2:
	return Vector2.ZERO if bool(nav.anchored) else CURRENT + Vector2(float(nav.push_x), float(nav.push_y))

static func tick(nav: Dictionary, delta: float) -> Vector2:
	for key in ["host_cooldown", "guest_cooldown"]:
		nav[key] = maxf(0, float(nav[key]) - delta)
	if bool(nav.anchored):
		nav.push_x = 0.0
		nav.push_y = 0.0
		return Vector2.ZERO
	var push := Vector2(float(nav.push_x), float(nav.push_y))
	var decay := exp(-DRAG * delta)
	var displacement := CURRENT * delta + push * ((1.0 - decay) / DRAG)
	nav.x = float(nav.x) + displacement.x
	nav.y = float(nav.y) + displacement.y
	nav.distance = float(nav.distance) + displacement.length()
	push *= decay
	nav.push_x = push.x
	nav.push_y = push.y
	return displacement

static func stroke(nav: Dictionary, slot: String, direction: Vector2) -> void:
	var push := (Vector2(float(nav.push_x), float(nav.push_y)) + direction.normalized() * STROKE).limit_length(MAX_PUSH)
	nav.push_x = push.x
	nav.push_y = push.y
	nav[slot + "_cooldown"] = COOLDOWN

static func restore(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() not in [8, 9] or not value.get("anchored") is bool:
		return {}
	for key in ["x", "y", "distance", "push_x", "push_y", "host_cooldown", "guest_cooldown"]:
		var number: Variant = value.get(key)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)):
			return {}
		if absf(float(number)) > 1.0e15:
			return {}
	if float(value.distance) < 0 or float(value.host_cooldown) < 0 or float(value.guest_cooldown) < 0 or float(value.host_cooldown) > COOLDOWN or float(value.guest_cooldown) > COOLDOWN:
		return {}
	var push := Vector2(float(value.push_x), float(value.push_y))
	if push.length() > MAX_PUSH + 0.001 or (bool(value.anchored) and push.length_squared() > 0.001):
		return {}
	if value.has("moored") and (not value.moored is bool or (value.moored and not value.anchored)):
		return {}
	var result: Dictionary = value.duplicate(true)
	result["moored"] = bool(value.get("moored", false))
	return result

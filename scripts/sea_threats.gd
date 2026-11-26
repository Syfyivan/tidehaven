extends RefCounted
## Host-owned encounters. Presentation reads these fields; it never applies hits.
const BUOY := Vector2(120, 65)
const SAFE_RADIUS := 145.0
const INVULNERABLE := 2.0
const DIVE_GRACE := 8.0
const RESCUE_RECOVERY := 8.0
const DEFINITIONS := {
	"shark": {"home": Vector2(695, 265), "detect": 265.0, "leash": 370.0, "reach": 140.0, "speed": 90.0, "charge": 245.0, "windup": 1.15, "rush": 0.9, "damage": 25.0, "radius": 24.0, "nose": 38.0, "repel": 14.0},
	"moray": {"home": Vector2(680, 465), "detect": 145.0, "leash": 155.0, "reach": 95.0, "speed": 65.0, "charge": 210.0, "windup": 1.0, "rush": 0.55, "damage": 18.0, "radius": 20.0, "nose": 26.0, "repel": 18.0},
}
const PHASES := ["patrol", "chase", "windup", "charge", "recover", "repelled"]

static func player_state() -> Dictionary:
	return {"grace": 0.0, "hurt": 0.0, "recovery": 0.0}

static func create() -> Dictionary:
	var result := {}
	for kind in DEFINITIONS:
		var home: Vector2 = DEFINITIONS[kind].home
		result[kind] = {"kind": kind, "x": home.x, "y": home.y, "dx": -1.0, "dy": 0.0, "phase": "patrol", "remaining": 0.0, "target": "", "clock": 0.0}
	return result

static func safe(point: Vector2) -> bool:
	return point.y < 155.0 or point.distance_to(BUOY) <= SAFE_RADIUS

static func eligible(player: Dictionary) -> bool:
	return player.get("online", false) and player.get("area") == "water" and float(player.get("stamina",0)) > 0.0 and float(player.get("dive_status", {}).get("grace", 0.0)) <= 0.0 and not safe(point(player))

static func point(value: Dictionary) -> Vector2:
	return Vector2(float(value.x), float(value.y))

static func tick(data: Dictionary, delta: float) -> Array[String]:
	var rescued: Array[String] = []
	if not is_finite(delta) or delta <= 0.0:
		return rescued
	# Substeps preserve the full telegraph and sweep collisions after delayed frames.
	var left := delta
	while left > 0.000001:
		var step := minf(0.05, left)
		left -= step
		for player in data.players.values():
			for key in ["grace", "hurt", "recovery"]:
				player.dive_status[key] = maxf(0.0, float(player.dive_status[key]) - step)
		for enemy in data.threats.values():
			_step(data, enemy, step)
		for slot in data.players:
			var player: Dictionary = data.players[slot]
			if player.get("online", false) and player.area == "water" and float(player.stamina) <= 0.0 and slot not in rescued:
				rescued.append(slot)
	return rescued

static func _step(data: Dictionary, enemy: Dictionary, delta: float) -> void:
	var spec: Dictionary = DEFINITIONS[enemy.kind]
	var home: Vector2 = spec.home
	var at := point(enemy)
	enemy.clock = fposmod(float(enemy.clock) + delta, 10000.0)
	var target: Dictionary = data.players.get(str(enemy.target), {})
	if enemy.phase in ["chase", "windup", "charge"] and (target.is_empty() or not eligible(target) or point(target).distance_to(home) > float(spec.leash)):
		_phase(enemy, "recover", 2.4)
	if enemy.phase == "repelled":
		_move(enemy, home, 150.0 * delta)
		enemy.remaining = maxf(0.0, float(enemy.remaining) - delta)
		if enemy.remaining <= 0.0: _phase(enemy, "patrol")
		return
	if enemy.phase == "recover":
		enemy.remaining = maxf(0.0, float(enemy.remaining) - delta)
		_move(enemy, home, 42.0 * delta)
		if enemy.remaining <= 0.0: _phase(enemy, "patrol")
		return
	if enemy.phase == "patrol":
		var nearest := float(spec.detect)
		for slot in data.players:
			var player: Dictionary = data.players[slot]
			var distance := at.distance_to(point(player))
			if eligible(player) and distance < nearest and point(player).distance_to(home) <= float(spec.leash):
				nearest = distance
				enemy.target = slot
		if not str(enemy.target).is_empty():
			enemy.phase = "chase"
			return
		var patrol := home + Vector2(sin(float(enemy.clock) * 0.35) * (95.0 if enemy.kind == "shark" else 30.0), sin(float(enemy.clock) * 0.51) * 23.0)
		_move(enemy, patrol, 38.0 * delta)
	elif enemy.phase == "chase":
		if at.distance_to(point(target)) <= float(spec.reach):
			var direction := (point(target) - at).normalized()
			if direction.is_zero_approx(): direction = Vector2.LEFT
			enemy.dx = direction.x; enemy.dy = direction.y
			enemy.phase = "windup"; enemy.remaining = spec.windup
		else:
			_move(enemy, point(target), float(spec.speed) * delta)
	elif enemy.phase == "windup":
		# Direction locks now: swimming across the line during the tell is effective.
		enemy.remaining = maxf(0.0, float(enemy.remaining) - delta)
		if enemy.remaining <= 0.0:
			enemy.phase = "charge"; enemy.remaining = spec.rush
	elif enemy.phase == "charge":
		var direction := Vector2(enemy.dx, enemy.dy)
		var moved := at + direction * float(spec.charge) * minf(delta, float(enemy.remaining))
		if safe(moved):
			_phase(enemy, "recover", 2.4)
			return
		enemy.x = clampf(moved.x, 55.0, 845.0); enemy.y = clampf(moved.y, 165.0, 510.0)
		var from := at + direction * float(spec.nose)
		var to := point(enemy) + direction * float(spec.nose)
		var hit_slot := ""
		var first := INF
		for slot in data.players:
			var player: Dictionary = data.players[slot]
			if not eligible(player) or float(player.dive_status.hurt) > 0.0: continue
			var fraction := segment_hit(from, to, point(player), float(spec.radius))
			if fraction >= 0.0 and fraction < first:
				first = fraction; hit_slot = slot
		if not hit_slot.is_empty():
			var player: Dictionary = data.players[hit_slot]
			player.stamina = maxf(0.0, float(player.stamina) - float(spec.damage))
			player.oxygen = maxf(0.0, float(player.oxygen) - 8.0)
			player.dive_status.hurt = INVULNERABLE
			player.activity = {}
			player.notice = "%s咬中了你！体力 -%d；向冲刺线两侧游开，可用鱼叉击退。" % ["鲨鱼" if enemy.kind == "shark" else "海鳗", int(spec.damage)]
			player.notice_id = int(player.notice_id) + 1
			_phase(enemy, "recover", 2.4)
		else:
			enemy.remaining = maxf(0.0, float(enemy.remaining) - delta)
			if enemy.remaining <= 0.0: _phase(enemy, "recover", 2.4)

static func _phase(enemy: Dictionary, phase: String, duration := 0.0) -> void:
	enemy.phase = phase; enemy.remaining = duration; enemy.target = ""

static func _move(enemy: Dictionary, destination: Vector2, distance: float) -> void:
	var at := point(enemy)
	var to := at.move_toward(destination, distance)
	var direction := (to - at).normalized()
	if not direction.is_zero_approx():
		enemy.dx = direction.x; enemy.dy = direction.y
	enemy.x = clampf(to.x, 55.0, 845.0); enemy.y = clampf(to.y, 165.0, 510.0)

static func segment_hit(from: Vector2, to: Vector2, centre: Vector2, radius: float) -> float:
	var segment := to - from
	var length := segment.length_squared()
	var offset := from - centre
	if offset.length_squared() <= radius * radius: return 0.0
	if length < 0.000001: return -1.0
	var projection := offset.dot(segment)
	var discriminant := projection * projection - length * (offset.length_squared() - radius * radius)
	if discriminant < 0.0: return -1.0
	var fraction := (-projection - sqrt(discriminant)) / length
	return fraction if fraction >= 0.0 and fraction <= 1.0 else -1.0

static func swept(data: Dictionary, from: Vector2, to: Vector2) -> Dictionary:
	var hit := {}
	var earliest := INF
	for id in data.get("threats", {}):
		var enemy: Dictionary = data.threats[id]
		if enemy.phase == "repelled": continue
		var fraction := segment_hit(from, to, point(enemy), float(DEFINITIONS[enemy.kind].radius))
		if fraction >= 0.0 and fraction < earliest:
			earliest = fraction; hit = {"id": id, "fraction": fraction, "threat": true}
	return hit

static func repel(data: Dictionary, id: String) -> String:
	if not data.get("threats", {}).has(id): return ""
	var enemy: Dictionary = data.threats[id]
	_phase(enemy, "repelled", float(DEFINITIONS[enemy.kind].repel))
	return "%s被鱼叉击退了，趁现在采集或返航！" % ("鲨鱼" if enemy.kind == "shark" else "海鳗")

static func valid_player(value: Variant) -> bool:
	return value is Dictionary and value.size() == 3 and _number(value.get("grace"), 0, DIVE_GRACE) and _number(value.get("hurt"), 0, INVULNERABLE) and _number(value.get("recovery"), 0, RESCUE_RECOVERY)

static func restore(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != DEFINITIONS.size(): return {}
	var result := {}
	for kind in DEFINITIONS:
		var enemy: Variant = value.get(kind)
		if not enemy is Dictionary or enemy.size() != 9 or not enemy.has_all(["kind", "x", "y", "dx", "dy", "phase", "remaining", "target", "clock"]): return {}
		if enemy.kind != kind or enemy.phase not in PHASES or enemy.target not in ["", "host", "guest"]: return {}
		if not _number(enemy.x, 55, 845) or not _number(enemy.y, 165, 510) or not _number(enemy.dx, -1, 1) or not _number(enemy.dy, -1, 1) or not _number(enemy.remaining, 0, 18) or not _number(enemy.clock, 0, 10000): return {}
		if not is_equal_approx(Vector2(enemy.dx, enemy.dy).length_squared(), 1.0): return {}
		var spec:Dictionary=DEFINITIONS[kind]
		var limits:Dictionary={"patrol":0.0,"chase":0.0,"windup":spec.windup,"charge":spec.rush,"recover":2.4,"repelled":spec.repel}
		if float(enemy.remaining)>float(limits[enemy.phase])+0.000001: return {}
		if (enemy.phase in ["chase","windup","charge"]) != (not str(enemy.target).is_empty()): return {}
		var clean: Dictionary = enemy.duplicate(true)
		# Reload cancels pending attacks, but preserves an earned repel window.
		if clean.phase != "repelled": _phase(clean, "recover", 2.4)
		clean.target = ""
		result[kind] = clean
	return result

static func _number(value: Variant, low: float, high: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= low and float(value) <= high

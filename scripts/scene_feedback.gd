extends RefCounted
## Cosmetic observations only: no rewards, RPCs or saved events. First snapshot is silent.
const Inventory = preload("res://scripts/inventory.gd")
const Map = preload("res://scripts/island_map.gd")
const LIMIT := 24
var effects: Array[Dictionary] = []
var _previous: Dictionary = {}

func reset() -> void:
	effects.clear()
	_previous.clear()

func update(data: Dictionary, slot: String, delta: float, show_gains := true) -> void:
	for index in range(effects.size() - 1, -1, -1):
		effects[index].age += delta
		if effects[index].age >= effects[index].duration:
			effects.remove_at(index)
	if data.is_empty() or not data.get("players", {}).has(slot):
		reset()
		return
	var now := _sample(data, slot)
	if _previous.is_empty() or now.elapsed < _previous.elapsed or now.slot != _previous.slot or now.room != _previous.room:
		effects.clear()
		_previous = now
		return
	for id in now.props:
		var prop: Dictionary = now.props[id]
		var old: Dictionary = _previous.props.get(id, {})
		if old.is_empty() or prop.at != old.at:
			_add("build", prop.area, prop.at, 0.65)
		elif old.remaining > 0 and prop.remaining == 0 and not prop.output.is_empty():
			_add("ready", prop.area, prop.at, 1.2)
	for tile in now.tiles:
		if tile not in _previous.tiles:
			var parts: PackedStringArray = str(tile).split(",")
			_add("build", "deck", Vector2(int(parts[0]) * 64 + 32, int(parts[1]) * 64 + 32), 0.65)
	for id in now.players:
		var player: Dictionary = now.players[id]
		var old: Dictionary = _previous.players.get(id, {})
		if old.is_empty() or not player.online or not old.online:
			continue
		var old_tree:String=old.get("tree","")
		if not old_tree.is_empty() and int(data.island.depleted.get(old_tree,0))>int(data.day):
			# Confirmed depletion only: cancellation/full bags never make a tree fall.
			if not effects.any(func(effect):return effect.kind=="tree_fall" and effect.items[0].id==old_tree):
				var node:=Map.node(old_tree)
				_add("tree_fall","island",Vector2(node.x,node.y),0.65,[{"id":old_tree,"side":-1 if old.at.x>node.x else 1}])
		if player.area != old.area and "water" in [player.area, old.area]:
			_add("splash", old.area, old.at, 0.85)
			_add("splash", player.area, player.at, 0.85)
		if player.area == "deck" and not player.hook.is_empty() and not old.hook.is_empty():
			if (old.hook.phase == "out" and player.hook.phase == "float") or player.hook.cargo > old.hook.cargo:
				_add("splash", "sea", player.hook.at, 0.6)
	var local: Dictionary = now.players[slot]
	if show_gains and local.online:
		var gains: Array = []
		for item in now.bag:
			var amount: int = int(now.bag[item]) - int(_previous.bag.get(item, 0))
			if amount > 0:
				gains.append({"item": item, "amount": amount})
		if not gains.is_empty():
			_add("gain", local.area, local.at, 1.6, gains)
	_previous = now

func _sample(data: Dictionary, slot: String) -> Dictionary:
	var result := {"elapsed": float(data.get("elapsed", 0)), "slot": slot, "room":str(data.players[slot].get("room","")), "tiles": data.get("deck_tiles", []).duplicate(), "props": {}, "players": {}, "bag": Inventory.totals(data.players[slot].bag)}
	for group in ["structures", "chests"]:
		for id in data.get(group, {}):
			var prop: Dictionary = data[group][id]
			result.props[group + ":" + str(id)] = {"area": str(prop.get("area", "deck")), "at": Vector2(prop.x, prop.y), "remaining": float(prop.get("remaining", 0)), "output": str(prop.get("output", ""))}
	for id in data.players:
		var player: Dictionary = data.players[id]
		var hook: Dictionary = player.get("hook", {})
		result.players[id] = {"at": Vector2(player.x, player.y), "area": str(player.area), "online": bool(player.online), "hook": {} if hook.is_empty() else {"at": Vector2(hook.x, hook.y), "phase": str(hook.phase), "cargo": hook.get("cargo", []).size()}}
		var activity:Dictionary=player.get("activity",{})
		var node:=Map.node(str(activity.get("id",""))) if activity.get("kind","")=="island_gather" else {}
		result.players[id].tree=str(node.id) if node.get("kind","")=="tree" and not activity.get("approach",false) else ""
	return result

func _add(kind: String, area: String, at: Vector2, duration: float, items: Array = []) -> void:
	if effects.size() >= LIMIT:
		effects.pop_front()
	effects.append({"kind": kind, "area": area, "at": at, "duration": duration, "age": 0.0, "items": items})

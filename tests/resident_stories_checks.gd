extends SceneTree
const World = preload("res://scripts/world_state.gd")
const Stories = preload("res://scripts/resident_stories.gd")
const Inventory = preload("res://scripts/inventory.gd")
var checks:int = 0
var failures:int = 0

func check(ok:bool, label:String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func reply_args(owner:String, step:int, choice:int = 0) -> Dictionary:
	return {"id":Stories.ARCS[owner].steps[step].at, "story":owner, "step":step, "reply":choice}

func open_args(owner:String, step:int) -> Dictionary:
	return {"id":owner if step == 3 else Stories.ARCS[owner].steps[step].at, "story":owner, "step":step}

func provide(data:Dictionary, owner:String, step:int, slot:String = "host") -> void:
	for item:String in Stories.ARCS[owner].steps[step].get("cost", {}):
		Inventory.add(data.players[slot].bag, item, int(Stories.ARCS[owner].steps[step].cost[item]))

func reject_unchanged(data:Dictionary, args:Dictionary, label:String, slot:String = "host") -> void:
	var before:Dictionary = data.duplicate(true)
	Stories.action(data, data.players.host, slot, args)
	check(data == before, label)

func _init() -> void:
	var world = World.new()
	var baseline:Dictionary = world.data.duplicate(true)
	check(baseline.get("stories") == Stories.create(), "New world initializes separate personal stories")
	check(Stories.ARCS.size() == 23, "Every one of the 18 town and 5 ocean residents has a story")
	var titles:Dictionary = {}
	var interlinked:int = 0
	var overnight:int = 0
	for owner:String in Stories.ARCS:
		var arc:Dictionary = Stories.ARCS[owner]
		check(not titles.has(arc.title), owner + " has a distinct title")
		titles[arc.title] = true
		check(arc.steps.size() == 3 and arc.steps[0].at == owner and arc.steps[2].at == owner, owner + " begins and ends with its own resident")
		check(arc.steps[2].replies[0].answer != arc.steps[2].replies[1].answer, owner + " has distinct remembered endings")
		for beat:Dictionary in arc.steps:
			check(Stories.ARCS.has(beat.at) and beat.replies.size() >= 2, owner + " known conversational partner and multiple replies")
			for item:String in beat.get("cost", {}): check(item in Inventory.ITEMS and int(beat.cost[item]) > 0 and int(beat.cost[item]) <= 4, owner + " modest real item cost")
		if arc.steps[1].at != owner: interlinked += 1
		if arc.steps[2].get("delay", 0) == 1: overnight += 1
		for final_choice:int in 2:
			var data:Dictionary = baseline.duplicate(true)
			data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
			var original_money:int = int(data.money)
			for step:int in 3:
				var opening:Dictionary = open_args(owner, step)
				check(Stories.entries(data, "host", opening.id).any(func(option:Dictionary)->bool: return option.args == opening), owner + " next story is discoverable at correct resident")
				var untouched:Dictionary = data.duplicate(true)
				check(not Stories.open(data, "host", opening).is_empty(), owner + " readable dialogue")
				check(data == untouched, owner + " opening dialogue never consumes items or advances story")
				if step > 0 and arc.steps[step].get("delay", 0) == 1:
					check(Stories.replies(data, "host", opening).is_empty(), owner + " no reply while waiting overnight")
					reject_unchanged(data, reply_args(owner, step, final_choice), owner + " forged same-day reply changes nothing")
					check(Stories.summary(data, "host").contains("过一夜"), owner + " journal explains waiting")
					data.day += 1
				provide(data, owner, step)
				check(Stories.replies(data, "host", opening).size() == 2, owner + " both replies available")
				var args:Dictionary = reply_args(owner, step, final_choice)
				var response:String = Stories.action(data, data.players.host, "host", args)
				check(data.stories.host[owner].step == step + 1 and data.stories.host[owner].choices[step] == final_choice, owner + " chosen reply and progress persist")
				check(response.contains(str(arc.steps[step].replies[final_choice].answer)), owner + " exact chosen response")
				for item:String in arc.steps[step].get("cost", {}): check(Inventory.count(data.players.host.bag, item) == 0, owner + " exact material cost applied once")
				reject_unchanged(data, args, owner + " repeated request cannot duplicate progress or reward")
			check(data.money == original_money + int(arc.coins) and data.journal.host.friendship[owner] == 40, owner + " final money once and personal affinity 10+10+20")
			check(data.stories.guest.is_empty() and data.journal.guest.friendship.is_empty(), owner + " partner progress remains independent")
			var memory:Dictionary = open_args(owner, 3)
			check(Stories.entries(data, "host", owner).any(func(option:Dictionary)->bool: return option.args == memory), owner + " completed story remains revisitable")
			check(Stories.replies(data, "host", memory).is_empty() and Stories.open(data, "host", memory).contains(str(arc.steps[2].replies[final_choice].answer)), owner + " memory reflects chosen ending without reply rewards")
			check(Stories.summary(data, "host").contains(str(arc.steps[2].replies[final_choice].answer)), owner + " journal remembers chosen ending")
			var restored:Dictionary = Stories.restore(JSON.parse_string(JSON.stringify(data.stories)), int(data.day))
			check(restored == data.stories and typeof(restored.host[owner].step) == TYPE_INT and typeof(restored.host[owner].choices[0]) == TYPE_INT, owner + " JSON restore normalizes integer state")
	check(interlinked == 23 and overnight >= 8, "All stories involve another resident and some allow natural overnight reflection")
	_bad_actions(baseline)
	_bad_saves()
	var together:Dictionary = baseline.duplicate(true)
	Stories.action(together, together.players.host, "host", reply_args("xu_mian", 0, 0))
	Stories.action(together, together.players.guest, "guest", reply_args("xu_mian", 0, 1))
	check(together.stories.host.xu_mian.choices == [0] and together.stories.guest.xu_mian.choices == [1], "Two players can make different choices for the same story")
	check(together.journal.host.friendship.xu_mian == 10 and together.journal.guest.friendship.xu_mian == 10, "Personal story friendship belongs to each player")
	print("Resident stories checks: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _bad_actions(baseline:Dictionary) -> void:
	var data:Dictionary = baseline.duplicate(true)
	var valid:Dictionary = reply_args("lu_zhou", 0)
	for invalid:Variant in [true, "0", -1, 0.25, INF, NAN, 4]:
		var args:Dictionary = valid.duplicate(true)
		args.step = invalid
		reject_unchanged(data, args, "Reject invalid step %s" % str(invalid))
		args = valid.duplicate(true)
		args.reply = invalid
		reject_unchanged(data, args, "Reject invalid reply %s" % str(invalid))
	var wrong:Dictionary = valid.duplicate(true)
	wrong.id = "xu_an"
	reject_unchanged(data, wrong, "Wrong resident cannot advance story")
	wrong = valid.duplicate(true)
	wrong.story = "unknown"
	reject_unchanged(data, wrong, "Unknown story rejected")
	wrong = valid.duplicate(true)
	wrong.coins = 100000
	reject_unchanged(data, wrong, "Extra client reward fields rejected")
	wrong = valid.duplicate(true)
	wrong.erase("reply")
	reject_unchanged(data, wrong, "Missing reply rejected")
	reject_unchanged(data, valid, "Unknown player slot rejected", "outsider")
	for amount:Variant in [-1, "2", INF, NAN, 0.5, true, 1000000001]:
		data.money = amount
		# NaN does not equal itself; compare the stable serialized structure instead.
		var snapshot:String = var_to_str(data)
		Stories.action(data, data.players.host, "host", valid)
		check(var_to_str(data) == snapshot, "Invalid money changes nothing")
	data = baseline.duplicate(true)
	data.players.host.bag = []
	reject_unchanged(data, valid, "Malformed inventory rejected without mutation")
	data = baseline.duplicate(true)
	data.stories.host.lu_zhou = {"step":2, "day":1, "choices":[0, 1]}
	data.day = 2
	data.players.host.bag = Inventory.empty_slots(Inventory.BAG_SIZE)
	Inventory.add(data.players.host.bag, "rope", 1)
	reject_unchanged(data, reply_args("lu_zhou", 2), "Insufficient story materials preserve progress and all items")
	Inventory.add(data.players.host.bag, "rope", 1)
	data.money = Stories.MONEY_LIMIT
	reject_unchanged(data, reply_args("lu_zhou", 2), "Full money bag preserves ready story and its materials")
	data.money = Stories.MONEY_LIMIT - int(Stories.ARCS.lu_zhou.coins)
	Stories.action(data, data.players.host, "host", reply_args("lu_zhou", 2, 1))
	check(data.money == Stories.MONEY_LIMIT and Inventory.count(data.players.host.bag, "rope") == 0 and data.stories.host.lu_zhou.step == 3, "Exact money ceiling accepts one atomic completion")
	data = baseline.duplicate(true)
	data.journal.host.friendship.lu_zhou = 995
	Stories.action(data, data.players.host, "host", valid)
	check(data.journal.host.friendship.lu_zhou == 1000, "Story affinity respects its cap")

func _bad_saves() -> void:
	var good:Dictionary = {"host":{"lu_zhou":{"step":2, "day":2, "choices":[0, 1]}}, "guest":{}}
	check(Stories.restore(good, 2) == good, "Valid partial progress restores")
	for malformed:Variant in [null, [], {}, {"host":{}}, {"host":{}, "guest":{}, "extra":{}}]:
		check(Stories.restore(malformed, 2).is_empty(), "Malformed story root rejected")
	for malformed:Variant in [{}, {"step":0, "day":1, "choices":[]}, {"step":4, "day":1, "choices":[0, 0, 0, 0]}, {"step":1, "day":3, "choices":[0]}, {"step":1, "day":0, "choices":[0]}, {"step":1, "day":1, "choices":[2]}, {"step":1, "day":1, "choices":[true]}, {"step":1, "day":1, "choices":[0.5]}, {"step":1, "day":1, "choices":[INF]}, {"step":1, "day":1, "choices":[NAN]}, {"step":2, "day":1, "choices":[0]}, {"step":true, "day":1, "choices":[0]}, {"step":1, "day":1, "choices":[0], "rewarded":true}]:
		check(Stories.restore({"host":{"lu_zhou":malformed}, "guest":{}}, 2).is_empty(), "Malformed personal record rejected")
	check(Stories.restore({"host":{"unknown":{"step":1, "day":1, "choices":[0]}}, "guest":{}}, 2).is_empty(), "Unknown resident in save rejected")
	var restored:Dictionary = Stories.restore(good, 2)
	restored.host.lu_zhou.choices[0] = 1
	check(good.host.lu_zhou.choices[0] == 0, "Restored story choices do not alias source save")

extends SceneTree
const World = preload("res://scripts/world_state.gd")
const Journal = preload("res://scripts/journal.gd")
const Dialogue = preload("res://scripts/resident_dialogue.gd")
const Stories = preload("res://scripts/resident_stories.gd")
const Town = preload("res://scripts/island_town.gd")
const Ocean = preload("res://scripts/ocean_residents.gd")
var checks:int = 0
var failures:int = 0

func check(ok:bool, label:String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func completed(choice:int = 0) -> Dictionary:
	return {"step":3, "day":1, "choices":[0, 0, choice]}

func _init() -> void:
	var world = World.new()
	var baseline:Dictionary = world.data.duplicate(true)
	check(Dialogue.BASIC.size() == 23 and Journal.REQUESTS.size() == 23, "23 existing residents covered, without candidate NPCs")
	for id:String in Journal.REQUESTS:
		check(Dialogue.BASIC.has(id) and (Town.NPCS.has(id) or Ocean.NPCS.has(id)), id + " dialogue belongs to a real resident")
		var data:Dictionary = baseline.duplicate(true)
		check(Dialogue.progress(data, "host", id).is_empty(), id + " fresh world cannot claim later accomplishments")
		var heard:Array[String] = []
		for day:int in [1, 2]:
			data.day = day
			var before:Dictionary = data.duplicate(true)
			var first:String = Dialogue.line(data, "host", id)
			check(not first.is_empty() and first == Dialogue.line(data, "host", id), id + " stable on repeated same-day clicks")
			check(data == before, id + " selecting dialogue never changes inventory, money, friendship or world")
			heard.append(first)
		check(heard[0] != heard[1], id + " both daily topics can occur across days")
		data.erase("stories")
		check(not Dialogue.line(data, "host", id).is_empty() and Dialogue.progress(data, "host", id).is_empty(), id + " older state without personal stories uses ordinary daily topics")
		if id in ["xu_an", "he_mu", "lin_sui"]: continue
		data = baseline.duplicate(true)
		data.stories.host[id] = {"step":2, "day":1, "choices":[0, 0]}
		check(Dialogue.progress(data, "host", id).is_empty(), id + " unfinished short story cannot emit an ending")
		data.stories.host[id] = completed()
		var followup:String = Dialogue.progress(data, "host", id)
		check(not followup.is_empty() and Dialogue.progress(data, "guest", id).is_empty(), id + " only the participant hears personal followup")
		var pool:Array[String] = []
		for day:int in [1, 2, 3]:
			data.day = day
			pool.append(Dialogue.line(data, "host", id))
		check(pool.has(followup) and pool.has(Dialogue.BASIC[id][0]) and pool.has(Dialogue.BASIC[id][1]), id + " finishing story does not replace all daily variety")
	_branches(baseline)
	_world_progress(baseline)
	_journal_and_dispatch()
	print("Resident dialogue checks: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _branches(baseline:Dictionary) -> void:
	var labels:Dictionary = {
		"tian_qing":["就叫野花田。", "叫歇一季的地。"],
		"lu_zhou":["就从和同伴练习开始。", "累了也可以把值班交出去。"],
		"xu_mian":["留下方便生活的小细节。", "留下你最喜欢的配色。"],
	}
	for id:String in labels:
		var data:Dictionary = baseline.duplicate(true)
		data.stories.host[id] = completed(0)
		data.stories.guest[id] = completed(1)
		for choice:int in 2:
			check(Stories.ARCS[id].steps[2].replies[choice].label == labels[id][choice], id + " followup meanings still match saved ending indices")
		check(Dialogue.progress(data, "host", id) != Dialogue.progress(data, "guest", id), id + " different personal answers retain different memories")
		var original:String = Dialogue.progress(data, "host", id)
		data.stories.guest[id].choices[2] = 0
		check(Dialogue.progress(data, "host", id) == original, id + " partner changes never rewrite host memory")

func _world_progress(baseline:Dictionary) -> void:
	var data:Dictionary = baseline.duplicate(true)
	data.island.homestead.rented = true
	data.island.homestead.claimed.host = true
	check(Dialogue.progress(data, "host", "xu_an").contains("已经领齐") and Dialogue.progress(data, "guest", "xu_an").contains("空些就来拿"), "Shared lease does not falsely mark partner's personal gifts as claimed")
	data.housing.ready_day = 3
	check(Dialogue.progress(data, "host", "he_mu").contains("施工") and not Dialogue.progress(data, "host", "he_mu").contains("屋子能住"), "House under repair cannot receive move-in congratulations")
	data.housing.level = 1
	data.housing.ready_day = 0
	check(Dialogue.progress(data, "host", "he_mu").contains("屋子能住"), "Completed repair is a shared observable accomplishment")
	data.housing.carpenter = true
	check(Dialogue.progress(data, "host", "he_mu").contains("船屋") and Dialogue.progress(data, "guest", "he_mu").contains("船屋"), "Carpenter's actual move is shared")
	data.restaurant.rented = true
	var shop_line:String = Dialogue.progress(data, "host", "lin_sui")
	check(shop_line.contains("接了北街旧店") and not shop_line.contains("昨晚") and not shop_line.contains("赚"), "Renting shop does not invent first-night earnings or service")
	check(shop_line == Dialogue.progress(data, "guest", "lin_sui"), "Both players can hear about the shared shop")
	check(Dialogue.line(data, "stranger", "xu_an").is_empty() and Dialogue.line(data, "host", "mi_luo").is_empty(), "Unknown slots and future candidates have no runtime dialogue")

func _journal_and_dispatch() -> void:
	var world = World.new()
	world.join("host", "船长")
	world.join("guest", "伙伴")
	var data:Dictionary = world.data
	var before:Dictionary = data.duplicate(true)
	var introduction:String = "保留第一次职业介绍。"
	check(Journal.talk(data, "host", "chen_yu", introduction) == introduction, "First conversation preserves introduction")
	var daily:String = Journal.talk(data, "host", "chen_yu", introduction)
	for repeat:int in 5:
		check(Journal.talk(data, "host", "chen_yu", introduction) == daily, "Repeated daily conversation stays deterministic")
	check(data.journal.host.friendship.chen_yu == 2 and data.journal.guest.friendship.is_empty(), "Daily friendship awarded only once to participant")
	before.journal = data.journal.duplicate(true)
	check(before == data, "Ordinary conversation changes only existing journal fields")
	check(Journal.talk(data, "guest", "chen_yu", introduction) == introduction and data.journal.guest.friendship.chen_yu == 2, "Partner keeps their own first meeting and daily reward")
	data.day += 1
	Journal.talk(data, "host", "chen_yu", introduction)
	check(data.journal.host.friendship.chen_yu == 4 and data.journal.guest.friendship.chen_yu == 2, "A new in-game day grants only that player's next daily reward")
	var restored = World.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Existing save schema restores daily conversation history")
	var saved_day:String = Journal.talk(data, "host", "chen_yu", introduction)
	check(Journal.talk(restored.data, "host", "chen_yu", introduction) == saved_day and restored.data.journal.host.friendship.chen_yu == 4, "Save/continue neither replays introduction nor repeats affinity")
	var legacy:Dictionary = world.snapshot()
	legacy.version = 15
	legacy.erase("stories")
	legacy.erase("chronicles")
	check(restored.restore(legacy) and restored.data.stories.host.is_empty(), "v15 migrates without manufacturing completed stories")
	check(Journal.talk(restored.data, "host", "chen_yu", introduction) == saved_day, "Old journal already met resident: ordinary dialogue without a reset introduction")
	var point:Dictionary = Town.location("lin_sui", 600, data)
	var player:Dictionary = data.players.host
	data.minute = 600
	player.area = point.area
	player.room = point.room
	player.x = point.at.x
	player.y = point.at.y
	check(Town.action(data, player, "town_talk", {"id":"lin_sui"}, "host").contains("种子得跟着季节买"), "Actual town first greeting preserves service introduction")
	check(Town.action(data, player, "town_talk", {"id":"lin_sui"}, "host").contains(Dialogue.line(data, "host", "lin_sui")), "Actual town repeat greeting uses daily voice")
	check(Town.options(data, player).any(func(option:Dictionary)->bool: return option.action == "town_trade"), "Daily voice does not hide trade actions")
	player.area = "room"
	player.room = "island_reef"
	var sea_at:Vector2 = Ocean.position("chao_jia")
	player.x = sea_at.x
	player.y = sea_at.y
	before = data.duplicate(true)
	check(Ocean.action(data, player, "host", "ocean_talk", {"id":"chao_jia"}).contains("还不能理解") and data == before, "Language gate rejects even daily conversation before tide speech")
	data.journal.tide_speech = true
	check(Ocean.action(data, player, "host", "ocean_talk", {"id":"chao_jia"}).contains(str(Ocean.NPCS.chao_jia.talk)), "First understandable sea conversation preserves introduction")
	check(Ocean.action(data, player, "host", "ocean_talk", {"id":"chao_jia"}).contains(Dialogue.line(data, "host", "chao_jia")) and data.journal.host.friendship.chao_jia == 2, "Ocean repeat greeting uses personal voice without reward replay")

extends RefCounted
## Versioned long-form story arcs ("chronicles"), separate from 3-step personal stories.
## Currently implements P2-09 《候潮院》 (hou_chao_yuan) end-to-end with strict validation.
const Inventory = preload("res://scripts/inventory.gd")
const MONEY_LIMIT := 1000000000
const STYLES := ["", "farm", "inn"]

static func create() -> Dictionary:
	return {
		"hou_chao_yuan": {
			"step": 0,
			"day": 0,
			"choices": [],
			"style": "",
		}
	}

static func record(data: Dictionary) -> Dictionary:
	return data.get("chronicles", {}).get("hou_chao_yuan", {"step": 0, "day": 0, "choices": [], "style": ""})

static func style_name(style: String) -> String:
	return "候潮驿院" if style == "inn" else "候潮农庄" if style == "farm" else "旧院"

static func waiting_mail(data: Dictionary) -> bool:
	var rec := record(data)
	return int(rec.get("step", 0)) == 4 and int(data.get("day", 1)) < int(rec.get("day", 0)) + 1

static func repair_covered(data: Dictionary) -> bool:
	var house: Dictionary = data.get("housing", {})
	return int(house.get("level", 0)) >= 1 or int(house.get("ready_day", 0)) > 0

static func target_npc(step: int) -> String:
	match step:
		1: return "xu_an"
		2: return "he_mu"
		3, 4: return "qiao_xin"
		_: return ""

static func entries(data: Dictionary, npc_id: String) -> Array:
	var rec := record(data)
	var step := int(rec.get("step", 0))
	if step >= 1 and step <= 4 and target_npc(step) == npc_id:
		return [{"action": "town_chronicle_open", "label": "长篇故事 · 《候潮院》", "args": {"id": npc_id, "arc": "hou_chao_yuan", "step": step}}]
	if step == 5 and npc_id in ["xu_an", "he_mu", "qiao_xin"]:
		return [{"action": "town_chronicle_open", "label": "回忆 · 《候潮院》", "args": {"id": npc_id, "arc": "hou_chao_yuan", "step": 5}}]
	return []

static func inspect_yard(data: Dictionary) -> String:
	if not data.get("island", {}).get("homestead", {}).get("rented", false):
		return "门柱上有些模糊刻痕。先找东街镇长许岸聊聊承租院子的事吧。"
	var rec := record(data)
	if int(rec.get("step", 0)) >= 1:
		return "门框内侧留着旧潮痕与半个『候』字，来历已记在J手记里。"
	data.chronicles.hou_chao_yuan.step = 1
	data.chronicles.hou_chao_yuan.day = int(data.get("day", 1))
	return "你在院门木柱内侧发现了几道旧潮位刻痕和半个『候』字。有空找镇长许岸问问《候潮院》的来历吧（已记入J手记）。"

static func toggle_yard_style(data: Dictionary) -> String:
	var rec := record(data)
	if int(rec.get("step", 0)) < 5:
		return "等《候潮院》的回信尘埃落定后，再来更换门牌布置。"
	var next_style := "inn" if str(rec.get("style", "farm")) != "inn" else "farm"
	data.chronicles.hou_chao_yuan.style = next_style
	return "院门已换为『%s』布置（%s）。" % [style_name(next_style), "傍晚门灯会亮起暖光" if next_style == "inn" else "门边摆好了歇脚竹篮"]

static func _valid_args(data: Dictionary, args: Dictionary, is_reply: bool) -> bool:
	if not data.get("chronicles") is Dictionary or not data.chronicles.get("hou_chao_yuan") is Dictionary:
		return false
	if args.size() != (4 if is_reply else 3) or not args.has_all(["id", "arc", "step"]):
		return false
	if str(args.get("arc", "")) != "hou_chao_yuan" or not args.get("id") is String:
		return false
	var rec := record(data)
	var step := int(rec.get("step", 0))
	if not integer(args.get("step"), 1, 4 if is_reply else 5) or int(args.step) != step:
		return false
	if step <= 4 and str(args.id) != target_npc(step):
		return false
	if step == 5 and str(args.id) not in ["xu_an", "he_mu", "qiao_xin"]:
		return false
	if is_reply and (not args.has("reply") or not integer(args.get("reply"), 0, 1)):
		return false
	return true

static func open(data: Dictionary, npc_name: String, args: Dictionary) -> String:
	if not _valid_args(data, args, false):
		return "这段院子旧事已有新进展，请重新和对方聊聊。"
	var rec := record(data)
	var step := int(rec.get("step", 0))
	match step:
		1:
			return "%s · 候潮院\n\n你看到门柱上那几道刻痕了？这座院子早年叫『候潮院』。那时候外海常有赶不上潮水、或遇风耽搁的船员，镇上就在这儿留了歇脚处和晒网空地。后来航道改了，照看院子的岑婆退休去了外港，院子才慢慢空下来。" % npc_name
		2:
			if repair_covered(data):
				return "%s · 候潮院\n\n修你们院里那间旧屋时，我在门廊梁下拆出这只桐油木匣，一直替你收着。里面是一本旧住客账本和几张海港热汤做法，末页写着外港邮路的地址——署名是岑婆。" % npc_name
			return "%s · 候潮院\n\n门廊那根横木确实有些松，带木板 ×6 来我替你一并顶稳，就能把梁下嵌着的防潮木匣取出来。\n\n继续这段对话会交付：木板 ×6（若已委托修屋则免材料）。" % npc_name
		3:
			return "%s · 候潮院\n\n寄给岑婆？这个外港转交点我熟！白帆的顺风船明早捎邮袋过去。拿两份植物纤维把信封捆紧防潮——你想在信里怎么跟她讲现在的院子？\n\n继续这段对话会交付：植物纤维 ×2。" % npc_name
		4:
			if waiting_mail(data):
				return "%s · 候潮院\n\n装信的邮袋还在海上跑呢。过一夜回程船靠岸，再来我这儿拆岑婆的回信；没有截止日期。" % npc_name
			return "%s · 候潮院\n\n回信到啦！岑婆随邮袋捎了干料和《候潮院院务笔记》，信上写：『我那双老腿不赶夜潮了，院子你们怎么顺手怎么改，别替旧人守空房，锅里有热饭比什么都强。』许岸说院门木牌正好按你们的心意重挂——你们想怎么安排？（完成后获得35金币与料理 ×2，请预留1格背包）" % npc_name
		5:
			var label := style_name(str(rec.get("style", "farm")))
			return "%s · 候潮院\n\n岑婆的《院务笔记》已经收妥，院门如今挂着『%s』的木牌。想换门牌与门边摆设时，在荒院西门打开右键菜单就能随时调整。" % [npc_name, label]
	return ""

static func replies(data: Dictionary, args: Dictionary) -> Array:
	if not _valid_args(data, args, false):
		return []
	var step := int(args.step)
	if step == 5 or (step == 4 and waiting_mail(data)):
		return []
	var labels: Array = {
		1: ["听起来这里以前很热闹。", "岑婆走的时候还留了话吗？"],
		2: ["托乔信寄封信，告诉她院子又有人住了。", "先把账本收好，顺便寄信报个平安。"],
		3: ["写我们正按自己的步调种地、过日子。", "写院门和水道都收拾过了，欢迎旧友歇脚。"],
		4: ["挂『候潮农庄』木牌，在门边添只歇脚竹篮。", "挂『候潮驿院』木牌，在门边留一盏夜归暖灯。"],
	}[step]
	var out: Array = []
	for i in labels.size():
		out.append({"action": "town_chronicle_reply", "label": labels[i], "args": {"id": args.id, "arc": "hou_chao_yuan", "step": step, "reply": i}})
	return out

static func action(data: Dictionary, player: Dictionary, slot: String, args: Dictionary) -> String:
	if slot not in ["host", "guest"] or not _valid_args(data, args, true):
		return "这段院子旧事已有变化，请重新和对方聊聊。"
	if not integer(data.get("money"), 0, MONEY_LIMIT) or not integer(data.get("day"), 1, 1000000):
		return "金币或日期状态异常，故事进度保持不变。"
	if not Inventory.validate_slots(player.get("bag"), Inventory.BAG_SIZE):
		return "背包状态异常，物品与故事进度保持不变。"
	var step := int(args.step)
	var reply := int(args.reply)
	if step == 4 and waiting_mail(data):
		return "装信的邮袋还在海上跑，过一夜再来拆信吧。"
	var cost: Dictionary = {}
	if step == 2 and not repair_covered(data):
		cost = {"wood": 6}
	elif step == 3:
		cost = {"fiber": 2}
	var reward_items: Dictionary = {"meal": 2} if step == 4 else {}
	var coins := 35 if step == 4 else 0
	if int(data.money) + coins > MONEY_LIMIT:
		return "共同钱袋已满，物品与故事进度都保留。"
	var bag: Array = player.bag.duplicate(true)
	for item: String in cost:
		if Inventory.count(bag, item) < int(cost[item]):
			return "还需要%s ×%d。材料与进度均保留，准备好再来。" % [Inventory.ITEM_NAMES[item], int(cost[item])]
		Inventory.remove(bag, item, int(cost[item]))
	for item: String in reward_items:
		if Inventory.add(bag, item, int(reward_items[item])) != 0:
			return "背包装不下回信附赠的料理 ×2，请先腾出一格空间再来。"
	player.bag = bag
	data.money = int(data.money) + coins
	var rec: Dictionary = record(data).duplicate(true)
	rec.step = step + 1
	rec.day = int(data.day)
	var choices: Array = rec.get("choices", []).duplicate()
	choices.append(reply)
	rec.choices = choices
	if step == 4:
		rec.style = "farm" if reply == 0 else "inn"
	data.chronicles.hou_chao_yuan = rec
	var friendships: Dictionary = data.journal[slot].friendship
	var speaker := str(args.id)
	friendships[speaker] = mini(1000, int(friendships.get(speaker, 0)) + (10 if step == 4 else 15))
	if step == 4:
		friendships["xu_an"] = mini(1000, int(friendships.get("xu_an", 0)) + 10)
	match step:
		1:
			var ans := "热闹谈不上，多半是湿衣服和热汤味。贺木替人看过旧屋梁木，说廊下嵌着只防潮木匣，去找他聊聊吧。" if reply == 0 else "她说院子是给人住的，不是拿来供着的。贺木上回提过旧屋门廊梁下有只旧木匣，你去找他看看吧。"
			return ans + "\n\n接下来找木匠贺木聊聊（工坊或船屋均可）· 许岸好感+15。"
		2:
			var ans := "这主意踏实，乔信跑惯了外港邮袋，准认得那个转交点。" if reply == 0 else "老木匠做的桐油匣子还严实。去广场找邮差乔信问问这趟邮船吧。"
			return ans + "\n\n收好了旧住客账本与地址，接下来带植物纤维 ×2 找邮差乔信寄信 · 贺木好感+15。"
		3:
			var ans := "实在！岑婆最烦客套话。信装进头班邮袋了，过一夜再来我这儿看回信！" if reply == 0 else "听着就敞亮！信封妥了，过一夜回程船靠岸再来找我取信！"
			return ans + "\n\n信已寄往外港，过一夜后再找乔信拆回信 · 乔信好感+15。"
		4:
			var style_label := style_name(str(rec.style))
			return "院门已挂起『%s』新木牌，%s！\n\n《候潮院》完成 · +35金币 · 获得海港热汤料理 ×2 · 乔信与许岸好感+10。院门右键菜单可随时切换门牌风貌。" % [
				style_label,
				"门边添好了竹编歇脚篮" if rec.style == "farm" else "傍晚六点后院门暖灯会自动点亮",
			]
	return ""

static func summary(data: Dictionary) -> String:
	var rec := record(data)
	var step := int(rec.get("step", 0))
	var out := "[b]长篇故事 · 候潮院（共享进度）[/b]\n"
	if step == 0:
		if data.get("island", {}).get("homestead", {}).get("rented", false):
			return out + "荒院西门的木柱内侧似乎留着旧刻痕，走近院门可以查看。\n"
		return out + "承租东南荒院后，可留意院门木柱上的旧痕迹。\n"
	match step:
		1: return out + "进度 1/5 · 已发现门框上的旧潮痕与半个『候』字。有空找镇长许岸问问来历。\n"
		2: return out + "进度 2/5 · 得知大院曾叫『候潮院』。去找木匠贺木查看门廊梁下的防潮木匣" + ("（已修屋免材料）。\n" if repair_covered(data) else "（可带木板 ×6 加固门廊）。\n")
		3: return out + "进度 3/5 · 找到了岑婆留下的旧住客账本与外港地址。带植物纤维 ×2 找邮差乔信寄封近况信。\n"
		4:
			return out + ("进度 4/5 · 信已寄出，过一夜后再找乔信拆读回信。\n" if waiting_mail(data) else "进度 4/5 · 外港回信已到！预留1格背包，找广场邮差乔信拆信并决定院门新木牌。\n")
		5:
			return out + "已完成 · 岑婆寄回了《候潮院院务笔记》，当前院门挂着『%s』木牌（可在院门右键菜单随时切换农庄／驿院布置）。\n" % style_name(str(rec.get("style", "farm")))
	return out

static func restore(value: Variant, day: int) -> Dictionary:
	if not value is Dictionary or value.size() != 1 or not value.has("hou_chao_yuan"):
		return {}
	var raw: Variant = value.hou_chao_yuan
	if not raw is Dictionary or raw.size() != 4 or not raw.has_all(["step", "day", "choices", "style"]):
		return {}
	if not integer(raw.step, 0, 5) or not integer(raw.day, 0, day) or not raw.choices is Array or not raw.style is String:
		return {}
	var step := int(raw.step)
	if step == 0 and (int(raw.day) != 0 or not raw.choices.is_empty() or raw.style != ""):
		return {}
	if step > 0 and int(raw.day) < 1:
		return {}
	var expected_choices := maxi(0, step - 1)
	if raw.choices.size() != expected_choices:
		return {}
	var clean_choices: Array = []
	for item in raw.choices:
		if not integer(item, 0, 1):
			return {}
		clean_choices.append(int(item))
	if (step < 5 and raw.style != "") or (step == 5 and raw.style not in ["farm", "inn"]):
		return {}
	return {
		"hou_chao_yuan": {
			"step": step,
			"day": int(raw.day),
			"choices": clean_choices,
			"style": str(raw.style),
		}
	}

static func integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and floorf(float(value)) == float(value) and value >= low and value <= high

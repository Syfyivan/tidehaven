extends RefCounted
## Versioned long-form story arcs ("chronicles"), separate from 3-step personal stories.
## Implements 8 playable P2 chronicles across v17-v19:
## - P2-09 《候潮院》 (hou_chao_yuan)
## - P2-10 《今晚留一碗》 (liu_yi_wan)
## - P2-11 《重新有人靠岸》 (kao_an)
## - P2-12 《海里也有邻居》 (hai_lin_ju)
## - P2-14 《开门能看见海》 (kan_jian_hai)
## - P2-20 《歪萝卜也能上桌》 (wai_luo_bo)
## - P2-28 《留一把椅子》 (liu_yi_ba_yi_zi)
## - P2-29 《今年的沙滩》 (jin_nian_sha_tan)
const Inventory = preload("res://scripts/inventory.gd")
const MONEY_LIMIT := 1000000000
const COAST_SITE := Vector2(184, 244)
const REEF_OFFSET := Vector2(80, -64)
const V18_ARCS := ["hou_chao_yuan", "liu_yi_wan", "kao_an", "hai_lin_ju"]
const ARCS := [
	"hou_chao_yuan", "liu_yi_wan", "kao_an", "hai_lin_ju",
	"kan_jian_hai", "wai_luo_bo", "liu_yi_ba_yi_zi", "jin_nian_sha_tan",
]
const TITLES := {
	"hou_chao_yuan": "候潮院",
	"liu_yi_wan": "今晚留一碗",
	"kao_an": "重新有人靠岸",
	"hai_lin_ju": "海里也有邻居",
	"kan_jian_hai": "开门能看见海",
	"wai_luo_bo": "歪萝卜也能上桌",
	"liu_yi_ba_yi_zi": "留一把椅子",
	"jin_nian_sha_tan": "今年的沙滩",
}
const ARC_STYLES := {
	"hou_chao_yuan": ["farm", "inn"],
	"liu_yi_wan": ["home", "season", "seafood"],
	"kao_an": ["supply", "ferry"],
	"hai_lin_ju": ["stone", "chime"],
	"kan_jian_hai": ["breeze", "lamp"],
	"wai_luo_bo": ["basket", "crock"],
	"liu_yi_ba_yi_zi": ["stool", "window", "slate"],
	"jin_nian_sha_tan": ["sand", "marker"],
}
const STYLE_LABELS := {
	"farm": "候潮农庄", "inn": "候潮驿院",
	"home": "家常暖锅席", "season": "时令鲜蔬席", "seafood": "海港鲜鱼席",
	"supply": "远航补给港", "ferry": "定期客船港",
	"stone": "白石安澜界", "chime": "听潮海螺架",
	"breeze": "迎风敞窗工角", "lamp": "防潮风灯工角",
	"basket": "田间直供菜篓", "crock": "时令腌菜陶坛",
	"stool": "廊下矮凳席", "window": "侧窗外带台", "slate": "港规留步牌",
	"sand": "向阳歇沙坪", "marker": "慢行浮木标",
}

static func _blank() -> Dictionary:
	return {"step": 0, "day": 0, "choices": [], "style": ""}

static func create() -> Dictionary:
	var out := {}
	for arc in ARCS:
		out[arc] = _blank()
	return out

static func record(data: Dictionary, arc: String = "hou_chao_yuan") -> Dictionary:
	return data.get("chronicles", {}).get(arc, _blank())

static func style_name(style: String) -> String:
	return str(STYLE_LABELS.get(style, "旧院"))

static func waiting_overnight(data: Dictionary, arc: String) -> bool:
	var rec := record(data, arc)
	return int(rec.get("step", 0)) == 4 and int(data.get("day", 1)) < int(rec.get("day", 0)) + 1

static func waiting_mail(data: Dictionary) -> bool:
	return waiting_overnight(data, "hou_chao_yuan")

static func repair_covered(data: Dictionary) -> bool:
	var house: Dictionary = data.get("housing", {})
	return int(house.get("level", 0)) >= 1 or int(house.get("ready_day", 0)) > 0

static func carpenter_settled(data: Dictionary) -> bool:
	return bool(data.get("housing", {}).get("carpenter", false))

static func house_ready_for_sea_window(data: Dictionary) -> bool:
	var house: Dictionary = data.get("housing", {})
	return int(house.get("level", 0)) >= 1 or bool(house.get("carpenter", false))

static func shop_operated(data: Dictionary) -> bool:
	return not data.get("restaurant", {}).get("last", {}).is_empty()

static func target_npc(arc: String, step: int) -> String:
	match arc:
		"hou_chao_yuan":
			match step:
				1: return "xu_an"
				2: return "he_mu"
				3, 4: return "qiao_xin"
		"liu_yi_wan":
			match step:
				1, 4: return "chen_yu"
				2: return "tian_qing"
				3: return "su_qin"
		"kao_an":
			match step:
				1: return "xu_an"
				2: return "lu_yao"
				3: return "bai_fan"
				4: return "qiao_xin"
		"hai_lin_ju":
			match step:
				1, 4: return "wen_zhi"
				2: return "chao_jia"
				3: return "lan_ying"
		"kan_jian_hai":
			match step:
				1, 4: return "he_mu"
				2: return "yan_zhen"
				3: return "bai_fan"
		"wai_luo_bo":
			match step:
				1, 4: return "tian_qing"
				2: return "lin_sui"
				3: return "chen_yu"
		"liu_yi_ba_yi_zi":
			match step:
				1, 3: return "chi_sheng"
				2: return "zhou_chao"
				4: return "chen_yu"
		"jin_nian_sha_tan":
			match step:
				1, 4: return "chao_jia"
				2: return "lu_zhou"
				3: return "tai_lu"
	return ""

static func recall_npcs(arc: String) -> Array:
	match arc:
		"hou_chao_yuan": return ["xu_an", "he_mu", "qiao_xin"]
		"liu_yi_wan": return ["chen_yu", "tian_qing", "su_qin"]
		"kao_an": return ["xu_an", "lu_yao", "bai_fan", "qiao_xin"]
		"hai_lin_ju": return ["wen_zhi", "chao_jia", "lan_ying", "tai_lu"]
		"kan_jian_hai": return ["he_mu", "yan_zhen", "bai_fan"]
		"wai_luo_bo": return ["tian_qing", "lin_sui", "chen_yu"]
		"liu_yi_ba_yi_zi": return ["chi_sheng", "zhou_chao", "chen_yu"]
		"jin_nian_sha_tan": return ["chao_jia", "lu_zhou", "tai_lu"]
	return []

static func entries(data: Dictionary, npc_id: String) -> Array:
	var out: Array = []
	for arc: String in ARCS:
		var rec := record(data, arc)
		var step := int(rec.get("step", 0))
		var title: String = TITLES[arc]
		if step >= 1 and step <= 4 and target_npc(arc, step) == npc_id:
			out.append({"action": "town_chronicle_open", "label": "长篇故事 · 《%s》" % title, "args": {"id": npc_id, "arc": arc, "step": step}})
		elif step == 5 and npc_id in recall_npcs(arc):
			out.append({"action": "town_chronicle_open", "label": "回忆 · 《%s》" % title, "args": {"id": npc_id, "arc": arc, "step": 5}})
	return out

static func inspect_yard(data: Dictionary) -> String:
	if not data.get("island", {}).get("homestead", {}).get("rented", false):
		return "门柱上有些模糊刻痕。先找东街镇长许岸聊聊承租院子的事吧。"
	if int(record(data, "hou_chao_yuan").get("step", 0)) >= 1:
		return "门框内侧留着旧潮痕与半个『候』字，来历已记在J手记里。"
	data.chronicles.hou_chao_yuan.step = 1
	data.chronicles.hou_chao_yuan.day = int(data.get("day", 1))
	return "你在院门木柱内侧发现了几道旧潮位刻痕和半个『候』字。有空找镇长许岸问问《候潮院》的来历吧（已记入J手记）。"

static func inspect_shop(data: Dictionary) -> String:
	if not data.get("restaurant", {}).get("rented", false):
		return "旧店尚未承租，先找东街镇长许岸聊聊吧。"
	if int(record(data, "liu_yi_wan").get("step", 0)) >= 1:
		return "收银台抽屉里的旧水牌写着『晚九点留一碗』，进展已记在J手记里。"
	data.chronicles.liu_yi_wan.step = 1
	data.chronicles.liu_yi_wan.day = int(data.get("day", 1))
	return "你在收银台抽屉底层翻出一叠旧粉笔水牌，边角写着『晚九点后，留一碗热汤』。去问问厨师陈鱼吧（已记入J手记）。"

static func inspect_dock(data: Dictionary) -> String:
	if int(data.get("journal", {}).get("story_step", 0)) < 1:
		return "系船柱上有块模糊的旧航线铜牌。等修亮西岸引航灯后，再向镇长打听当年的航路吧。"
	if int(record(data, "kao_an").get("step", 0)) >= 1:
		return "系船柱上的旧航线铜牌已经记下，去问问相关居民或查看J手记吧。"
	data.chronicles.kao_an.step = 1
	data.chronicles.kao_an.day = int(data.get("day", 1))
	return "引航灯照亮了系船柱侧面的旧铜牌，上面刻着早年停靠潮芽港的班次。去问问镇长许岸《重新有人靠岸》的往事吧（已记入J手记）。"

static func inspect_coast(data: Dictionary) -> String:
	if int(record(data, "hai_lin_ju").get("step", 0)) >= 1:
		return "浅滩那排白石与水痕已经记下，去镇公所找温知或查看J手记吧。"
	data.chronicles.hai_lin_ju.step = 1
	data.chronicles.hai_lin_ju.day = int(data.get("day", 1))
	return "退潮后的浅滩上留着几枚排成弧线的白石与轻敲水痕。去镇公所问问温知老师《海里也有邻居》吧（已记入J手记）。"

static func inspect_workshop(data: Dictionary) -> String:
	if not house_ready_for_sea_window(data):
		return "工坊廊下压着几张木窗草图。等请贺木修好荒院小屋后，再来和他聊聊船上木工吧。"
	if int(record(data, "kan_jian_hai").get("step", 0)) >= 1:
		return "船窗榫卯草图已经记下，去找贺木或查看J手记吧。"
	data.chronicles.kan_jian_hai.step = 1
	data.chronicles.kan_jian_hai.day = int(data.get("day", 1))
	return "工坊廊下的旧刨台压着一张画满海浪角度的船窗榫卯草图。去找木匠贺木聊聊《开门能看见海》吧（已记入J手记）。"

static func inspect_farm(data: Dictionary) -> String:
	if not data.get("island", {}).get("homestead", {}).get("rented", false):
		return "门边摆着一筐刚洗净的分叉萝卜。先向镇长许岸承租荒院安顿下来再来聊聊吧。"
	if int(record(data, "wai_luo_bo").get("step", 0)) >= 1:
		return "门边那筐分叉萝卜的事已经记在J手记里，去找相关居民聊聊吧。"
	data.chronicles.wai_luo_bo.step = 1
	data.chronicles.wai_luo_bo.day = int(data.get("day", 1))
	return "民居门边的竹筐里装着几根分叉的胖萝卜，泥洗得很干净却没送去超市。进屋问问农人田青《歪萝卜也能上桌》的事吧（已记入J手记）。"

static func inspect_pirate(data: Dictionary) -> String:
	if not data.get("restaurant", {}).get("rented", false):
		return "熏黑铁锅旁压着一张潮芽镇旧酒馆传单。等承租北街旧店后再来问问赤绳吧。"
	if int(record(data, "liu_yi_ba_yi_zi").get("step", 0)) >= 1:
		return "铁锅旁的旧店传单已经看过，按J手记继续推进《留一把椅子》吧。"
	data.chronicles.liu_yi_ba_yi_zi.step = 1
	data.chronicles.liu_yi_ba_yi_zi.day = int(data.get("day", 1))
	return "熏黑的铁锅旁压着半张潮间寿司屋的开业纸条，边角被翻得起毛。和海盗赤绳聊聊《留一把椅子》吧（已记入J手记）。"

static func inspect_reef(data: Dictionary) -> String:
	if not data.get("journal", {}).get("tide_speech", false):
		return "湿沙上留着几道折返的海龟爬痕。先完成温知老师的三章潮声故事理解潮语，再来问问老海龟潮甲吧。"
	if int(record(data, "jin_nian_sha_tan").get("step", 0)) >= 1:
		return "潮线折返爬痕已经记在J手记里，去找潮甲或相关伙伴聊聊吧。"
	data.chronicles.jin_nian_sha_tan.step = 1
	data.chronicles.jin_nian_sha_tan.day = int(data.get("day", 1))
	return "湿沙上留着几道爬到一半又退回海里的浅弧印。走近老海龟潮甲问问《今年的沙滩》是怎么回事吧（已记入J手记）。"

static func _cycle_style(data: Dictionary, arc: String, wait_msg: String, desc_map: Dictionary) -> String:
	var rec := record(data, arc)
	if int(rec.get("step", 0)) < 5:
		return wait_msg
	var options: Array = ARC_STYLES[arc]
	var cur := str(rec.get("style", options[0]))
	var idx := (options.find(cur) + 1) % options.size()
	var next_style := str(options[idx])
	data.chronicles[arc].style = next_style
	return str(desc_map[next_style])

static func toggle_yard_style(data: Dictionary) -> String:
	return _cycle_style(data, "hou_chao_yuan", "等《候潮院》的回信尘埃落定后，再来更换门牌布置。", {
		"inn": "院门已换为『候潮驿院』布置（傍晚门灯会亮起暖光）。",
		"farm": "院门已换为『候潮农庄』布置（门边摆好了歇脚竹篮）。",
	})

static func toggle_shop_style(data: Dictionary) -> String:
	return _cycle_style(data, "liu_yi_wan", "等《今晚留一碗》的熟客晚席办妥后，再来切换席面招牌。", {
		"home": "北街旧店已换为『家常暖锅席』布置（暖橙布帘与粗陶汤锅）。",
		"season": "北街旧店已换为『时令鲜蔬席』布置（青竹菜牌与田园竹篮）。",
		"seafood": "北街旧店已换为『海港鲜鱼席』布置（靛蓝鱼旗与木船刺身盘）。",
	})

static func toggle_dock_style(data: Dictionary) -> String:
	return _cycle_style(data, "kao_an", "等《重新有人靠岸》的首班联络船靠港后，再来切换码头布置。", {
		"supply": "西岸码头已换为『远航补给港』布置（栈桥边添置补给木箱与系缆短旗）。",
		"ferry": "西岸码头已换为『定期客船港』布置（栈桥边添置候船长椅与迎客风幡）。",
	})

static func toggle_coast_style(data: Dictionary) -> String:
	return _cycle_style(data, "hai_lin_ju", "等《海里也有邻居》的岸海约定定稿后，再来切换浅滩信物。", {
		"stone": "西岸浅滩已换为『白石安澜界』布置（叠起温润白石航标）。",
		"chime": "西岸浅滩已换为『听潮海螺架』布置（海风吹拂轻响的木架海螺）。",
	})

static func toggle_workshop_style(data: Dictionary) -> String:
	return _cycle_style(data, "kan_jian_hai", "等《开门能看见海》的船窗试制完成后，再来切换工角样式。", {
		"breeze": "工坊廊下与船屋已换为『迎风敞窗工角』布置（百叶海风木窗与刨花木架）。",
		"lamp": "工坊廊下与船屋已换为『防潮风灯工角』布置（黄铜防风暖灯，傍晚亮起柔光）。",
	})

static func toggle_farm_style(data: Dictionary) -> String:
	return _cycle_style(data, "wai_luo_bo", "等《歪萝卜也能上桌》的时令试菜落定后，再来切换门前陈列。", {
		"basket": "苔瓦民居门前已换为『田间直供菜篓』布置（青竹鲜菜篓与木签牌）。",
		"crock": "苔瓦民居门前已换为『时令腌菜陶坛』布置（粗陶小菜坛与木盖架）。",
	})

static func toggle_pirate_style(data: Dictionary) -> String:
	return _cycle_style(data, "liu_yi_ba_yi_zi", "等《留一把椅子》的旧账与规矩定下后，再来调整店门安排。", {
		"stool": "潮间寿司屋门外已换为『廊下矮凳席』安排（门廊边留一张守规矩矮木凳）。",
		"window": "潮间寿司屋门外已换为『侧窗外带台』安排（设取餐木托板，打包不进堂食）。",
		"slate": "潮间寿司屋门外已换为『港规留步牌』安排（挂起守约木牌，再观后效）。",
	})

static func toggle_reef_style(data: Dictionary) -> String:
	return _cycle_style(data, "jin_nian_sha_tan", "等《今年的沙滩》的潮线观察完成后，再来切换沙坪安排。", {
		"sand": "珊湾东侧潮线已换为『向阳歇沙坪』安排（护沙草束拢出安静暖沙角）。",
		"marker": "珊湾东侧潮线已换为『慢行浮木标』安排（保留自然原岸并立海龟纹木标）。",
	})

static func _reply_count(arc: String, step: int) -> int:
	return 3 if (step == 4 and arc in ["liu_yi_wan", "liu_yi_ba_yi_zi"]) else 2

static func _valid_args(data: Dictionary, args: Dictionary, is_reply: bool) -> bool:
	if not data.get("chronicles") is Dictionary:
		return false
	if args.size() != (4 if is_reply else 3) or not args.has_all(["id", "arc", "step"]):
		return false
	var arc := str(args.get("arc", ""))
	if arc not in ARCS or not data.chronicles.get(arc) is Dictionary or not args.get("id") is String:
		return false
	var rec := record(data, arc)
	var step := int(rec.get("step", 0))
	if not integer(args.get("step"), 1, 4 if is_reply else 5) or int(args.step) != step:
		return false
	if step <= 4 and str(args.id) != target_npc(arc, step):
		return false
	if step == 5 and str(args.id) not in recall_npcs(arc):
		return false
	if is_reply and (not args.has("reply") or not integer(args.get("reply"), 0, _reply_count(arc, step) - 1)):
		return false
	return true

static func open(data: Dictionary, npc_name: String, args: Dictionary) -> String:
	if not _valid_args(data, args, false):
		return "这段往事已有新进展，请重新和对方聊聊。"
	var arc := str(args.arc)
	var rec := record(data, arc)
	var step := int(rec.get("step", 0))
	var head := "%s · %s\n\n" % [npc_name, TITLES[arc]]
	match arc:
		"hou_chao_yuan":
			match step:
				1: return head + "你看到门柱上那几道刻痕了？这座院子早年叫『候潮院』。那时候外海常有赶不上潮水、或遇风耽搁的船员，镇上就在这儿留了歇脚处和晒网空地。后来航道改了，照看院子的岑婆退休去了外港，院子才慢慢空下来。"
				2:
					if repair_covered(data):
						return head + "修你们院里那间旧屋时，我在门廊梁下拆出这只桐油木匣，一直替你收着。里面是一本旧住客账本和几张海港热汤做法，末页写着外港邮路的地址——署名是岑婆。"
					return head + "门廊那根横木确实有些松，带木板 ×6 来我替你一并顶稳，就能把梁下嵌着的防潮木匣取出来。\n\n继续这段对话会交付：木板 ×6（若已委托修屋则免材料）。"
				3: return head + "寄给岑婆？这个外港转交点我熟！白帆的顺风船明早捎邮袋过去。拿两份植物纤维把信封捆紧防潮——你想在信里怎么跟她讲现在的院子？\n\n继续这段对话会交付：植物纤维 ×2。"
				4:
					if waiting_overnight(data, arc):
						return head + "装信的邮袋还在海上跑呢。过一夜回程船靠岸，再来我这儿拆岑婆的回信；没有截止日期。"
					return head + "回信到啦！岑婆随邮袋捎了干料和《候潮院院务笔记》，信上写：『我那双老腿不赶夜潮了，院子你们怎么顺手怎么改，别替旧人守空房，锅里有热饭比什么都强。』许岸说院门木牌正好按你们的心意重挂——你们想怎么安排？（完成后获得35金币与料理 ×2，请预留1格背包）"
				5: return head + "岑婆的《院务笔记》已经收妥，院门如今挂着『%s』的木牌。想换门牌与门边摆设时，在荒院西门打开右键菜单就能随时调整。" % style_name(str(rec.get("style", "farm")))
		"liu_yi_wan":
			match step:
				1: return head + "你翻到那块旧水牌了？以前老酒馆还在的时候，总有人替晚下班的熟客托一句『留一碗』。现在店刚重新开张，我可不赞成一上来写满十二道菜——你是想开店，还是想把自己钉在案板边上？先说说，你打算怎么定咱们厨房的步调？"
				2:
					if shop_operated(data):
						return head + "听说你们店里已经开过火了，手脚真利索！林穗挑货架总看个头齐不齐，我这儿正好留了一篮甜根菜直接送去厨房。对了，以前总托人『晚九点留一碗』的其实是澡堂汤禾，替诊所晚下班的苏芩留的——你去诊所问问苏芩真正收工的钟点吧。"
					return head + "陈鱼让你来的？林穗挑货架总看个头齐不齐，可萝卜歪一点，切进热汤里谁分得出来？带两份普通蔬菜来，我教你把根茎甜味煨出来——顺便告诉你，以前总托人『晚九点留一碗』的其实是汤禾，替晚下班的苏芩留的。\n\n继续这段对话会交付：蔬菜 ×2（若旧店已营业结算过则免材料）。"
				3: return head + "汤禾那个人，送茶嫌淡，留饭倒记了好几年。其实诊所没那么多半夜急症，我只是画窗边影子忘了看钟。带两条生鱼给陈鱼试锅底吧——不必替我熬到半夜，约个普通傍晚，我们光明正大来吃一碗。\n\n继续这段对话会交付：生鱼 ×2。"
				4:
					if waiting_overnight(data, arc):
						return head + "高汤已经在小火上煨着了，汤禾、苏芩和田青都说明天傍晚过来。睡一觉过一夜，明天再来店里定下咱们招牌席面的路数吧；没有截止日期。"
					return head + "昨晚那桌热汤吃得真舒坦！苏芩准点收工没让人等，林穗尝完田青的歪萝卜也没再挑刺。往后店里就留这块『今晚留一碗』的席面牌——你想把咱们的招牌定成哪种风味？（完成后获得40金币与寿司 ×2，请预留1格背包）"
				5: return head + "如今北街旧店挂着『%s』的招牌，熟客们路过都知道锅里留着热乎饭。想换席面风貌时，在店里收银台打开右键菜单就能随时切换。" % style_name(str(rec.get("style", "home")))
		"kao_an":
			match step:
				1: return head + "自从西岸引航灯重新亮起来，好几条路过外海的船都打旗号问能不能靠岸。可镇公所留着的两本旧航行簿，对雾岬外侧那道暗礁的转向记法正好相反——没核准之前我可不敢乱发靠港信。你先找陆遥比对一下岸线记录？"
				2: return head + "这两本册子都没写错，只是年代差了十几年！早年小船走内侧，后来大船改绕雾岬外侧，偏偏外侧那块木航标被风浪打没了。海商白帆常在雾岬岛停船，你划船去雾岬岛找他，带上木板 ×4 和绳子 ×1 把转向标重新立起来吧。"
				3: return head + "哈，我就说西岸那盏灯怎么亮得这么精神！雾岬外侧那处转向口我熟得很，起雾天没标牌确实不敢往里靠。把木板和绳子交给我加固在礁石桩上——明早第一班顺风联络船就能按新航标试靠潮芽港，过一夜回广场找乔信听信儿！\n\n继续这段对话会交付：木板 ×4、绳子 ×1。"
				4:
					if waiting_overnight(data, arc):
						return head + "白帆捎来旗语说航标已经立稳啦！首班试靠的联络船明早顺潮进港，过一夜再来找我清点船期和码头布置吧。"
					return head + "今早第一艘回访联络船稳稳靠上西岸码头啦！船长夸新航标老远就能认出来，还随船捎来了外港谢礼。许岸镇长请你们拿主意：西岸栈桥边往后按『远航补给港』摆备品箱，还是按『定期客船港』设候船长椅？（完成后获得45金币与烤鱼 ×2，请预留1格背包）"
				5: return head + "西岸航道已经顺畅通航，栈桥边现按『%s』布置。想更换码头风貌时，在西岸码头打开右键菜单就能随时切换。" % style_name(str(rec.get("style", "supply")))
		"hai_lin_ju":
			match step:
				1: return head + "你也注意到浅滩那排白石了？最近渔民说近岸海龟总故意绕远路，夜里又能听见像船钟一样的回音。我猜不是什么海怪，倒像两边都在躲着对方。理解潮声之后，去珊湾潮岸找老海龟潮甲当面问问最稳妥——你准备先记哪一头？"
				2: return head + "浅滩那几块白石是我推上去的。前些日子岸上修东西、海底又总传来闷闷的敲击声，年轻海龟以为礁洞要塌了，宁可多游半天绕远路。其实有一半声音是从回声海洞最深处传出来的——你下潜到海洞三层找澜影问问吧。"
				3: return head + "咦？岸上敲两下不是『打招呼』的意思吗？我听你们抛锚叮当响，就跟着敲石壁回礼，没想到把小海龟吓跑啦！给我两块结实的石料垫在水道边把回声收住吧——过一夜你回镇公所和温知把岸海约定记进图鉴！\n\n继续这段对话会交付：石料 ×2。"
				4:
					if waiting_overnight(data, arc):
						return head + "我正在把潮甲的路线和澜影的回音记号誊进图鉴附录，苔露捎来的风栖岛干叶也压在书页里晒着。过一夜再来镇公所定下西岸浅滩的标记吧。"
					return head + "《潮间邻居附录》定稿啦！今早周潮说看见小海龟重新游回近岸晒背了，澜影也没再半夜乱学船钟。我们准备在西岸浅滩留一处长久信物，好让岸上的人和海里的邻居都认得——你喜欢哪一种？（完成后获得45金币与鲜蔬沙拉 ×2，请预留1格背包）"
				5: return head + "岸上和海里的误会已经解开，西岸浅滩现立着『%s』。在浅滩打开右键菜单可以随时切换信物布置。" % style_name(str(rec.get("style", "stone")))
		"kan_jian_hai":
			match step:
				1:
					if carpenter_settled(data):
						return head + "那张草图是我搬上你们木筏前画的！刚住进船屋头两晚，半夜听着筏板底下哗啦响，推门就是一整片亮晶晶的潮水，比在岸上闷头刨木头痛快多了。不过海风湿气重，窗轴还得请老伙计严砧配一副耐盐插销——你回铁匠铺帮我取一趟？"
					return head + "你看到廊下那张船窗图了？替你们修好荒院小屋那天，我站在屋脊上往西看了一眼海，突然想起年轻时跟着修船队跑外岛的日子。岸上的窗怕漏雨，海上的窗却怕盐雾把榫头泡胀——我想试做一扇『推门能看见海、关窗不进浪花』的船用百叶窗。你去铁匠铺找严砧问问防海盐插销？"
				2:
					if carpenter_settled(data):
						return head + "贺木住上船屋前就把木料和锭子留我炉边了，这套热油淬过的防盐窗轴我早替他打好啦！他还记挂着我跟顾星借桌角的事呢。你带着这套窗轴去雾岬岛找海商白帆，借外海风口实测一下迎浪严不严实吧！"
					return head + "贺木那老小子，嘴上嫌海风腥，心里早惦记着听浪刨木头了！普通铁销吹半个月海风就锈死，得用热油淬过再嵌进硬木框里。带木板 ×4 和金属锭 ×1 来，我替他把防盐窗轴打出来——做好后带去雾岬岛找白帆借风口试试！\n\n继续这段对话会交付：木板 ×4、金属锭 ×1（若贺木已入住船屋则免材料）。"
				3: return head + "贺木手艺真是没得挑！你看这道斜口排水槽，浪花打上来顺着槽就溜回海里，半滴溅不湿里面的刨子。拿一根绳子来，我教你绑个跑船人用的活结风钩——明早我顺船捎他一包干茶，他答应回岸探望严砧和顾星顺便把样品装好，过一夜再找贺木挑样式！\n\n继续这段对话会交付：绳子 ×1。"
				4:
					if waiting_overnight(data, arc):
						return head + "我正约了严砧和顾星在岸上喝茶核对防潮尺寸呢，过一夜再来找我定下临海工作角的样式吧；没有截止日期。"
					return head + "昨天回工坊跟严砧、顾星坐了一下午，顾星还借我的新窗框测了半天海风湿度！白帆试过的活结风钩真管用，不管在工坊廊下还是在筏上船屋，推开门窗就能看见海面波光。这处临海工作角你想留哪种布置？（完成后获得40金币与料理 ×2，请预留1格背包）"
				5: return head + "临海工作角现按『%s』布置，岸上的老朋友也常托船捎话。在木匠工坊门前打开右键菜单就能随时切换工角风貌。" % style_name(str(rec.get("style", "breeze")))
		"wai_luo_bo":
			match step:
				1: return head + "这筐分叉萝卜你也瞧见啦？石子地里长出来的根茎偶尔拐个弯，咬一口其实水分更足、更甜。可早上送去超市，林穗非说摆在头排货架上像没挑过，镇民买菜爱拿笔直的，放两天蔫了反而可惜。沐桐倒借去画了两页速写——你去超市帮我探探林穗的意思？"
				2: return head + "我就猜田青大姐准在念叨我挑剔！零售柜台一格就摆十来把菜，顾客挑剩的歪萝卜压在筐底，隔天一软我既不能原价卖，又不好意思退给她。要是北街寿司屋愿意拿这些分叉鲜菜做切块时令小菜，两头都不浪费——你带蔬菜 ×3 和林菇 ×1 去找陈鱼试一盘？"
				3: return head + "歪萝卜配鲜林菇？上了我的案板全是滚刀块，谁还拿尺子量它直不直！这茬菜芯脆甜得很，拿热高汤一煨再撒点碎海苔，正好给等寿司的熟客垫肚子。菜我收下了，今晚端出去给林穗和常客尝尝——过一夜去找田青听准信！\n\n继续这段对话会交付：蔬菜 ×3、林菇 ×1。"
				4:
					if waiting_overnight(data, arc):
						return head + "陈鱼今晚正拿那批蔬菜和林菇试做时令小钵呢，过一夜再来我这儿听听镇上熟客怎么说吧。"
					return head + "今早林穗亲自拎着空盘子来敲门，说昨晚店里那道时令小菜头一个卖光，连她自己都添了半碗！我们约好了：顺直的菜照常摆货架，歪一点但脆甜的留作时令菜材，绝不强求你们包销。民居门前正好留一处时令角，你觉得摆哪样顺眼？（完成后获得35金币与鲜蔬沙拉 ×2，请预留1格背包）"
				5: return head + "如今歪萝卜也有了好去处，民居门前摆着『%s』。在苔瓦民居门前打开右键菜单可随时切换时令陈列。" % style_name(str(rec.get("style", "basket")))
		"liu_yi_ba_yi_zi":
			match step:
				1: return head + "咳，看什么看，本船长只是顺风捡了张纸！我这口铁锅顿顿烤焦鱼皮，听说你们在潮芽镇北街重开了饭馆……我要是带足干净银钱登岸吃碗热乎的，镇上那帮人不会还揪着几年前那点海上小事不放吧？尤其是渔铺那个周潮，你帮我回镇上探探口风？"
				2: return head + "『海上小事』？他倒会往自己脸上贴金！三年前大雾天，他船底擦了礁，一声不吭割走了我挂在外礁浮标上的两条备用粗缆和一串黄铜网坠，害我空手折返耽误了两水鱼汛。这绝不是什么误会——他想踏进潮芽港，先把欠下的双股缆绳和金属网扣亲手补齐送回来！"
				3: return head + "……行，周潮记性够毒，连黄铜网坠有几颗都没忘。当年船舱进水急着保命是不假，可顺走人家吃饭的家伙没还，确实是我理亏。这组绳子和废金属算我向你赊的工料，今晚我亲自编成双股粗缆，天亮前划舢板送到渔铺栈桥赔礼——至于饭馆怎么立规矩，过一夜你跟厨师陈鱼商量吧！\n\n继续这段对话会交付：绳子 ×2、废金属 ×2。"
				4:
					if waiting_overnight(data, arc):
						return head + "赤绳天亮前刚把编好的双股新缆和网坠送到渔铺栈桥，周潮正在清点，过一夜再来北街旧店商议规矩吧。"
					return head + "今早周潮来过了——新缆绳编得比原样还粗一圈，外加一袋擦亮的铜网扣和赔礼鱼干。周潮说『东西两清，但想让我跟他碰杯还早得很』。赤绳刚才在巷口探头问能不能买碗热饭，你是店主，这规矩怎么立最稳妥？（完成后获得45金币与烤鱼 ×2，请预留1格背包）"
				5: return head + "赤绳已经老老实实补还了渔铺旧账，店门外现按『%s』立规矩。在潮间寿司屋门外打开右键菜单可随时调整安排。" % style_name(str(rec.get("style", "stool")))
		"jin_nian_sha_tan":
			match step:
				1: return head + "那几道印子是前天两只年轻海龟留下的。今年季风把几团旧渔网碎布吹到了东边背风湾，它们嫌翻过去费劲，吵着要干脆改去外礁晒背；我倒觉得旧沙坪暖和得早，犯不着多游半天。听说渔铺的救援员陆舟每年都记近海漂流带，你回潮芽镇帮我问问今年风向？"
				2: return head + "珊湾东侧那片背风沙坪？我巡海册上正好画过！上个月两次急潮把断木和散草推上了高潮线，其实底下那层细沙一点没变。不用大动干戈挖沙子，只要去风栖岛请林地精灵苔露挑几束柔韧的滨草纤维，在迎风口编一道矮草束挡住杂物就行——你带植物纤维 ×3 去风栖岛找苔露？"
				3: return head + "潮甲又在跟小辈争哪块沙子更暖和啦？海边的草本来就懂怎么顺着风弯腰，人类一拿铲子推平反而站不住脚。这三把植物纤维我替你挽成松松的护沙结，顺着今晚涨潮漂回珊湾岸边——过一夜你再去珊湾找潮甲看看它们怎么选！\n\n继续这段对话会交付：植物纤维 ×3。"
				4:
					if waiting_overnight(data, arc):
						return head + "护沙草束刚顺着晚潮拢在珊湾岸边，等过一夜退潮沙暖后再来找我看看吧；没有截止日期。"
					return head + "今早退潮后我爬过去试了试，碎杂物都被草束拦在外侧，底下的沙子晒半个时辰就暖透了！那两只年轻海龟嘴上不服，刚才还是趴在旁边眯了一觉。这片潮岸你想帮我们整理成向阳歇沙坪，还是保留原岸只立一根慢行浮木记号？（完成后获得40金币与刺身 ×2，请预留1格背包）"
				5: return head + "珊湾东侧潮线现设为『%s』，年轻海龟和老海龟都能安心歇脚。在珊湾潮线打开右键菜单可随时切换安排。" % style_name(str(rec.get("style", "sand")))
	return ""

static func replies(data: Dictionary, args: Dictionary) -> Array:
	if not _valid_args(data, args, false):
		return []
	var arc := str(args.arc)
	var step := int(args.step)
	if step == 5 or (step == 4 and waiting_overnight(data, arc)):
		return []
	var table: Dictionary = {
		"hou_chao_yuan": {
			1: ["听起来这里以前很热闹。", "岑婆走的时候还留了话吗？"],
			2: ["托乔信寄封信，告诉她院子又有人住了。", "先把账本收好，顺便寄信报个平安。"],
			3: ["写我们正按自己的步调种地、过日子。", "写院门和水道都收拾过了，欢迎旧友歇脚。"],
			4: ["挂『候潮农庄』木牌，在门边添只歇脚竹篮。", "挂『候潮驿院』木牌，在门边留一盏夜归暖灯。"],
		},
		"liu_yi_wan": {
			1: ["先把几道常备菜做稳，让人随时来都有热乎的。", "跟着每天打上来的鱼和当季菜走，有什么鲜货做什么。"],
			2: ["太好了，店里专门留一道不挑长相的时令热菜。", "跟林穗分清用途，好看的摆货架，实在的进咱们锅里。"],
			3: ["好，就约明晚收工时分，给熟客们留一桌热饭。", "在柜台立块『留一碗』木牌，晚下班的人随时能热菜。"],
			4: ["定为『家常暖锅席』，挂暖橙布帘、备粗陶汤碗。", "定为『时令鲜蔬席』，挂青竹菜牌、配田园竹篮。", "定为『海港鲜鱼席』，挂靛蓝鱼旗、摆木船刺身盘。"],
		},
		"kao_an": {
			1: ["好，我去找陆遥把两份岸线记录比对清楚。", "对完记录我亲自开船去外海看一眼。"],
			2: ["明白，我这就备好木板和绳子出海去雾岬岛找白帆。", "等立好新航标，也在镇里的指路图旁注一行说明吧。"],
			3: ["劳烦白帆船长盯紧绳结，欢迎外港船只常来歇脚。", "顺便替潮芽镇捎句话，岸上淡水和热饭都备着呢。"],
			4: ["设为『远航补给港』，在栈桥边添置补给木箱与系缆短旗。", "设为『定期客船港』，在栈桥边添置候船长椅与迎客风幡。"],
		},
		"hai_lin_ju": {
			1: ["先去珊湾找潮甲问清海龟绕路的原委。", "记下敲击声的快慢节奏，顺便去海里核对声源。"],
			2: ["原来是回音闹的误会，我这就去海洞三层找澜影说清楚。", "等问清声源，我们在西岸浅滩立个不惊扰你们的安静记号。"],
			3: ["以后听到岸上轻敲木架三声，才是找你聊天的记号。", "回声收稳就好，海龟们又能安心回浅滩晒太阳了。"],
			4: ["立一座『白石安澜界』，按潮甲认路的习惯叠起白石标。", "挂一架『听潮海螺架』，海风吹过只有柔和低响。"],
		},
		"kan_jian_hai": {
			1: ["好，我去找严砧问问耐海盐的窗轴五金。", "顺便听听严砧怎么评价你想在海上开窗的主意。"],
			2: ["这就带窗轴出海去雾岬岛找白帆试风。", "替贺木谢谢你，等试稳了请你们一起喝茶。"],
			3: ["学会这个活结风钩了，船上开窗安心多了。", "替我把干茶捎给贺木，让他多跟岸上老朋友聚聚。"],
			4: ["设为『迎风敞窗工角』，支起百叶海风木窗与刨花木架。", "设为『防潮风灯工角』，挂起黄铜防风暖灯与工具挂板。"],
		},
		"wai_luo_bo": {
			1: ["我去超市跟林穗聊聊，看看她究竟顾虑什么。", "摆货架和进厨房本来就是两回事，我去帮你们搭个话。"],
			2: ["这主意两全其美，我带蔬菜和林菇去找陈鱼试菜。", "零售归货架、切配归后厨，谁都不吃亏。"],
			3: ["就叫『田间时令小钵』，实实在在最讨喜。", "记得给林穗留一小碟，免得她嘴硬不肯尝。"],
			4: ["设为『田间直供菜篓』，在门前摆起青竹鲜菜篓与木签牌。", "设为『时令腌菜陶坛』，在门前摆起粗陶小菜坛与木盖架。"],
		},
		"liu_yi_ba_yi_zi": {
			1: ["我先回渔铺问清楚当年到底是怎么回事。", "想上岸吃饭就别含糊其辞，我去问问周潮。"],
			2: ["明白，一码归一码，我回珊湾让他照数补还。", "欠的东西确实该他自己送回来，我去转告他。"],
			3: ["敢作敢当才像话，明早送到渔铺别贴错地方。", "先把渔铺的旧账还清，吃饭的规矩回镇再议。"],
			4: ["设为『廊下矮凳席』，收市后在门外留张矮凳、守规矩才准坐。", "设为『侧窗外带台』，设取餐木托板只卖打包、暂不进堂食。", "设为『港规留步牌』，先挂起守约木牌，等镇民再看一阵他的表现。"],
		},
		"jin_nian_sha_tan": {
			1: ["好，我回岸边渔铺找陆舟对照一下近海风浪记录。", "年轻海龟探新路也有道理，我先去问清岸线情况。"],
			2: ["不破坏原岸又能挡住漂流杂物，我这就去风栖岛找苔露。", "谢谢你的巡海册，等办妥了把新岸线也补记上去。"],
			3: ["顺着潮水留一道轻记号，不惊动歇脚的海龟。", "替潮甲谢谢你，明年换季你们还能隔海捎信。"],
			4: ["设为『向阳歇沙坪』，拢起护沙草束与平整暖沙角。", "设为『慢行浮木标』，保持自然原岸并立起海龟纹浮木桩。"],
		},
	}
	var labels: Array = table[arc][step]
	var out: Array = []
	for i in labels.size():
		out.append({"action": "town_chronicle_reply", "label": labels[i], "args": {"id": args.id, "arc": arc, "step": step, "reply": i}})
	return out

static func _step_cost(data: Dictionary, arc: String, step: int) -> Dictionary:
	match arc:
		"hou_chao_yuan":
			if step == 2 and not repair_covered(data): return {"wood": 6}
			if step == 3: return {"fiber": 2}
		"liu_yi_wan":
			if step == 2 and not shop_operated(data): return {"veg": 2}
			if step == 3: return {"fish": 2}
		"kao_an":
			if step == 3: return {"wood": 4, "rope": 1}
		"hai_lin_ju":
			if step == 3: return {"stone": 2}
		"kan_jian_hai":
			if step == 2 and not carpenter_settled(data): return {"wood": 4, "ingot": 1}
			if step == 3: return {"rope": 1}
		"wai_luo_bo":
			if step == 3: return {"veg": 3, "mushroom": 1}
		"liu_yi_ba_yi_zi":
			if step == 3: return {"rope": 2, "scrap": 2}
		"jin_nian_sha_tan":
			if step == 3: return {"fiber": 3}
	return {}

static func _final_reward(arc: String) -> Dictionary:
	match arc:
		"hou_chao_yuan": return {"coins": 35, "items": {"meal": 2}}
		"liu_yi_wan": return {"coins": 40, "items": {"maki": 2}}
		"kao_an": return {"coins": 45, "items": {"cooked_fish": 2}}
		"hai_lin_ju": return {"coins": 45, "items": {"salad": 2}}
		"kan_jian_hai": return {"coins": 40, "items": {"meal": 2}}
		"wai_luo_bo": return {"coins": 35, "items": {"salad": 2}}
		"liu_yi_ba_yi_zi": return {"coins": 45, "items": {"cooked_fish": 2}}
		"jin_nian_sha_tan": return {"coins": 40, "items": {"sashimi": 2}}
	return {"coins": 0, "items": {}}

static func action(data: Dictionary, player: Dictionary, slot: String, args: Dictionary) -> String:
	if slot not in ["host", "guest"] or not _valid_args(data, args, true):
		return "这段往事已有变化，请重新和对方聊聊。"
	if not integer(data.get("money"), 0, MONEY_LIMIT) or not integer(data.get("day"), 1, 1000000):
		return "金币或日期状态异常，故事进度保持不变。"
	if not Inventory.validate_slots(player.get("bag"), Inventory.BAG_SIZE):
		return "背包状态异常，物品与故事进度保持不变。"
	var arc := str(args.arc)
	var step := int(args.step)
	var reply := int(args.reply)
	if step == 4 and waiting_overnight(data, arc):
		return "还在筹备或等待回音中，过一夜再来吧。"
	var cost: Dictionary = _step_cost(data, arc, step)
	var fin: Dictionary = _final_reward(arc) if step == 4 else {"coins": 0, "items": {}}
	var coins := int(fin.coins)
	var reward_items: Dictionary = fin.items
	if int(data.money) + coins > MONEY_LIMIT:
		return "共同钱袋已满，物品与故事进度都保留。"
	var bag: Array = player.bag.duplicate(true)
	for item: String in cost:
		if Inventory.count(bag, item) < int(cost[item]):
			return "还需要%s ×%d。材料与进度均保留，准备好再来。" % [Inventory.ITEM_NAMES[item], int(cost[item])]
		Inventory.remove(bag, item, int(cost[item]))
	for item: String in reward_items:
		if Inventory.add(bag, item, int(reward_items[item])) != 0:
			return "背包装不下完结谢礼（%s ×%d），请先腾出一格空间再来。" % [Inventory.ITEM_NAMES[item], int(reward_items[item])]
	player.bag = bag
	data.money = int(data.money) + coins
	var rec: Dictionary = record(data, arc).duplicate(true)
	rec.step = step + 1
	rec.day = int(data.day)
	var choices: Array = rec.get("choices", []).duplicate()
	choices.append(reply)
	rec.choices = choices
	if step == 4:
		var styles: Array = ARC_STYLES[arc]
		rec.style = str(styles[reply])
	data.chronicles[arc] = rec
	var friendships: Dictionary = data.journal[slot].friendship
	var speaker := str(args.id)
	friendships[speaker] = mini(1000, int(friendships.get(speaker, 0)) + (10 if step == 4 else 15))
	if step == 4:
		for partner: String in recall_npcs(arc):
			if partner != speaker:
				friendships[partner] = mini(1000, int(friendships.get(partner, 0)) + 10)
	return _reply_feedback(arc, step, reply, str(rec.style))

static func _reply_feedback(arc: String, step: int, reply: int, chosen_style: String) -> String:
	var s_name := style_name(chosen_style)
	match arc:
		"hou_chao_yuan":
			match step:
				1: return ("热闹谈不上，多半是湿衣服和热汤味。去找木匠贺木看看旧屋门廊梁下的防潮木匣吧。" if reply == 0 else "她说院子是给人住的，不是拿来供着的。去找贺木看看旧屋门廊梁下的木匣吧。") + "\n\n接下来找木匠贺木聊聊（工坊或船屋均可）· 许岸好感+15。"
				2: return ("这主意踏实，乔信跑惯了外港邮袋，准认得那个转交点。" if reply == 0 else "老木匠做的桐油匣子还严实。去广场找邮差乔信问问这趟邮船吧。") + "\n\n收好了旧住客账本与地址，接下来带植物纤维 ×2 找邮差乔信寄信 · 贺木好感+15。"
				3: return ("实在！岑婆最烦客套话。信装进头班邮袋了，过一夜再来我这儿看回信！" if reply == 0 else "听着就敞亮！信封妥了，过一夜回程船靠岸再来找我取信！") + "\n\n信已寄往外港，过一夜后再找乔信拆回信 · 乔信好感+15。"
				4: return "院门已挂起『%s』新木牌！\n\n《候潮院》完成 · +35金币 · 获得海港热汤料理 ×2 · 院门右键菜单可随时切换门牌风貌。" % s_name
		"liu_yi_wan":
			match step:
				1: return ("对脾气！锅里常备着热汤比花哨名字管用。去找农人田青聊聊当季甜根菜吧。" if reply == 0 else "敞亮！海边小店就吃这口鲜。去找田青问问那些味道好却不好摆货架的当季菜吧。") + "\n\n接下来找农人田青聊聊 · 陈鱼好感+15。"
				2: return "甜根菜备妥了！去诊所带生鱼 ×2 找苏芩问清收工钟点、顺便给陈鱼试锅底吧 · 田青好感+15。"
				3: return "苏芩记下了傍晚收工时间，生鱼也送去厨房煨汤了。过一夜后再回北街旧店找陈鱼定下招牌席面吧 · 苏芩好感+15。"
				4: return "北街旧店已挂起『%s』席面牌！\n\n《今晚留一碗》完成 · +40金币 · 获得寿司 ×2 · 收银台右键菜单可随时切换席面风貌。" % s_name
		"kao_an":
			match step:
				1: return "稳妥！去广场附近找引路员陆遥核对那两本旧航行簿吧 · 许岸好感+15。"
				2: return "原来缺的是雾岬外侧转向标！带上木板 ×4 和绳子 ×1 划船前往雾岬岛找海商白帆立标吧 · 陆遥好感+15。"
				3: return "外礁转向标已经牢牢立稳！过一夜等首班联络船靠港后，回潮芽镇广场找邮差乔信吧 · 白帆好感+15。"
				4: return "西岸栈桥已设为『%s』！\n\n《重新有人靠岸》完成 · +45金币 · 获得烤鱼 ×2 · 西岸码头右键菜单可随时切换港口布置。" % s_name
		"hai_lin_ju":
			match step:
				1: return "记录册准备好了！理解潮声后，划船前往珊湾潮岸找老海龟潮甲问问绕路缘由吧 · 温知好感+15。"
				2: return "原来年轻海龟把回音当成了礁洞塌方！下潜到回声海洞三层（带石料 ×2）找澜影问清船钟声吧 · 潮甲好感+15。"
				3: return "定音石垫稳了，回声不再吓着小海龟啦！过一夜后回镇公所找温知老师定稿图鉴附录吧 · 澜影好感+15。"
				4: return "西岸浅滩已立起『%s』！\n\n《海里也有邻居》完成 · +45金币 · 获得鲜蔬沙拉 ×2 · 西岸浅滩右键菜单可随时切换信物布置。" % s_name
		"kan_jian_hai":
			match step:
				1: return "去炉火铁匠铺找严砧配一副耐海盐的窗轴五金吧 · 贺木好感+15。"
				2: return "防盐窗轴已备妥！带上绳子 ×1 划船前往雾岬岛找海商白帆实测海风迎浪吧 · 严砧好感+15。"
				3: return "活结风钩测试稳当！贺木正回岸探望老友并安装样品，过一夜再找贺木选定工角样式吧 · 白帆好感+15。"
				4: return "工坊廊下与船屋已设为『%s』！\n\n《开门能看见海》完成 · +40金币 · 获得海港热汤料理 ×2 · 木匠工坊门前右键菜单可随时切换。" % s_name
		"wai_luo_bo":
			match step:
				1: return "去潮芽超市找店主林穗聊聊分叉蔬菜的货架损耗吧 · 田青好感+15。"
				2: return "带上蔬菜 ×3 和林菇 ×1 去北街旧店找厨师陈鱼试做时令小菜吧 · 林穗好感+15。"
				3: return "时令小菜今晚端上桌给熟客试吃！过一夜再去找农人田青听准信吧 · 陈鱼好感+15。"
				4: return "苔瓦民居门前已摆起『%s』！\n\n《歪萝卜也能上桌》完成 · +35金币 · 获得鲜蔬沙拉 ×2 · 民居门前右键菜单可随时切换。" % s_name
		"liu_yi_ba_yi_zi":
			match step:
				1: return "先回潮芽镇岸边渔铺找周潮问清当年那笔旧账的真相吧 · 赤绳好感+15。"
				2: return "果然是真顺走了缆绳和铜网坠！带上绳子 ×2 和废金属 ×2 回珊湾找赤绳让他亲自补还吧 · 周潮好感+15。"
				3: return "赤绳答应天亮前亲自把双股粗缆和网坠送去渔铺赔礼！过一夜再找北街厨师陈鱼定规矩吧 · 赤绳好感+15。"
				4: return "潮间寿司屋门外已立起『%s』规矩！\n\n《留一把椅子》完成 · +45金币 · 获得烤鱼 ×2 · 店门外右键菜单可随时调整安排。" % s_name
		"jin_nian_sha_tan":
			match step:
				1: return "回潮芽镇岸边渔铺找救援员陆舟核对今年的近海漂流带记录吧 · 潮甲好感+15。"
				2: return "带上植物纤维 ×3 航行前往风栖岛找林地精灵苔露编一道护沙草束吧 · 陆舟好感+15。"
				3: return "护沙草束已顺晚潮送往珊湾！过一夜退潮后再去珊湾找老海龟潮甲看看吧 · 苔露好感+15。"
				4: return "珊湾东侧潮线已设为『%s』！\n\n《今年的沙滩》完成 · +40金币 · 获得刺身 ×2 · 珊湾潮线右键菜单可随时切换。" % s_name
	return ""

static func summary(data: Dictionary) -> String:
	var lines: PackedStringArray = ["[b]长篇故事（共享进度）[/b]"]
	var hcy := record(data, "hou_chao_yuan")
	match int(hcy.get("step", 0)):
		0: lines.append("• 《候潮院》：" + ("荒院西门木柱似乎留着旧刻痕，走近院门右键查看。" if data.get("island", {}).get("homestead", {}).get("rented", false) else "承租东南荒院后，可留意院门木柱上的旧痕迹。"))
		1: lines.append("• 《候潮院》 1/5：已发现门框旧潮痕，找镇长许岸问问来历。")
		2: lines.append("• 《候潮院》 2/5：找木匠贺木查看门廊梁下木匣" + ("（已修屋免材料）。" if repair_covered(data) else "（带木板 ×6）。"))
		3: lines.append("• 《候潮院》 3/5：带植物纤维 ×2 找邮差乔信寄信给岑婆。")
		4: lines.append("• 《候潮院》 4/5：" + ("信已寄出，过一夜再找乔信拆回信。" if waiting_overnight(data, "hou_chao_yuan") else "回信已到！预留1格背包找乔信定下院门木牌。"))
		5: lines.append("• 《候潮院》已完成：现挂『%s』木牌（荒院西门右键可切换）。" % style_name(str(hcy.get("style", "farm"))))
	var lyw := record(data, "liu_yi_wan")
	match int(lyw.get("step", 0)):
		0: lines.append("• 《今晚留一碗》：" + ("北街旧店收银台抽屉似乎留着旧水牌，进店右键查看。" if data.get("restaurant", {}).get("rented", false) else "自愿向镇长租下北街旧店后，可查看收银台边的旧点菜单。"))
		1: lines.append("• 《今晚留一碗》 1/5：发现了『晚九点留一碗』旧水牌，找厨师陈鱼聊聊。")
		2: lines.append("• 《今晚留一碗》 2/5：找农人田青商议当季甜根菜汤底" + ("（已营业过免材料）。" if shop_operated(data) else "（带蔬菜 ×2）。"))
		3: lines.append("• 《今晚留一碗》 3/5：带生鱼 ×2 去诊所找苏芩核对收工时间。")
		4: lines.append("• 《今晚留一碗》 4/5：" + ("高汤煨制中，过一夜再找陈鱼定招牌席面。" if waiting_overnight(data, "liu_yi_wan") else "熟客晚席圆满！预留1格背包找陈鱼选定席面牌。"))
		5: lines.append("• 《今晚留一碗》已完成：现设『%s』（店内收银台右键可切换）。" % style_name(str(lyw.get("style", "home"))))
	var ka := record(data, "kao_an")
	match int(ka.get("step", 0)):
		0: lines.append("• 《重新有人靠岸》：" + ("西岸码头系船柱露出了旧航线铜牌，走近码头右键查看。" if int(data.get("journal", {}).get("story_step", 0)) >= 1 else "修亮西岸引航灯后，可查看码头系船柱上的旧航线铜牌。"))
		1: lines.append("• 《重新有人靠岸》 1/5：找镇长许岸询问两本旧航行簿的分歧。")
		2: lines.append("• 《重新有人靠岸》 2/5：找引路员陆遥核对雾岬外侧转向记录。")
		3: lines.append("• 《重新有人靠岸》 3/5：带木板 ×4、绳子 ×1 航行至雾岬岛找海商白帆重立航标。")
		4: lines.append("• 《重新有人靠岸》 4/5：" + ("首班联络船明早顺潮进港，过一夜找乔信听信。" if waiting_overnight(data, "kao_an") else "首班船已靠港！预留1格背包找广场乔信选定西岸码头布置。"))
		5: lines.append("• 《重新有人靠岸》已完成：西岸现为『%s』（码头右键可切换）。" % style_name(str(ka.get("style", "supply"))))
	var hlj := record(data, "hai_lin_ju")
	match int(hlj.get("step", 0)):
		0: lines.append("• 《海里也有邻居》：潮芽岛西岸浅滩（码头北侧）排着整齐白石，走近浅滩右键查看。")
		1: lines.append("• 《海里也有邻居》 1/5：去镇公所找温知老师讨论浅滩白石与夜潮回音。")
		2: lines.append("• 《海里也有邻居》 2/5：" + ("前往珊湾潮岸找老海龟潮甲询问绕路原委。" if data.get("journal", {}).get("tide_speech", false) else "先完成温知的三章潮声故事理解潮语，再去珊湾找潮甲。"))
		3: lines.append("• 《海里也有邻居》 3/5：带石料 ×2 下潜至回声海洞三层找澜影收稳回声。")
		4: lines.append("• 《海里也有邻居》 4/5：" + ("图鉴附录整理中，过一夜再去镇公所找温知。" if waiting_overnight(data, "hai_lin_ju") else "《潮间邻居附录》定稿！预留1格背包找温知选定浅滩信物。"))
		5: lines.append("• 《海里也有邻居》已完成：浅滩现立『%s』（西岸浅滩右键可切换）。" % style_name(str(hlj.get("style", "stone"))))
	var kjh := record(data, "kan_jian_hai")
	match int(kjh.get("step", 0)):
		0: lines.append("• 《开门能看见海》：" + ("木匠工坊廊下压着一张船窗草图，门前右键查看。" if house_ready_for_sea_window(data) else "请贺木修好荒院小屋后，可留意木匠工坊廊下的船窗草图。"))
		1: lines.append("• 《开门能看见海》 1/5：找木匠贺木聊聊船用百叶窗与海上生活。")
		2: lines.append("• 《开门能看见海》 2/5：找铁匠严砧配防盐窗轴" + ("（已住船屋免材料）。" if carpenter_settled(data) else "（带木板 ×4、金属锭 ×1）。"))
		3: lines.append("• 《开门能看见海》 3/5：带绳子 ×1 航行至雾岬岛找白帆实测风口迎浪。")
		4: lines.append("• 《开门能看见海》 4/5：" + ("贺木正与老友喝茶装样，过一夜再找他定样式。" if waiting_overnight(data, "kan_jian_hai") else "船窗实测稳妥！预留1格背包找贺木选定临海工作角。"))
		5: lines.append("• 《开门能看见海》已完成：现设『%s』（木匠工坊门前右键可切换）。" % style_name(str(kjh.get("style", "breeze"))))
	var wlb := record(data, "wai_luo_bo")
	match int(wlb.get("step", 0)):
		0: lines.append("• 《歪萝卜也能上桌》：" + ("苔瓦民居门边摆着一筐分叉萝卜，门前右键查看。" if data.get("island", {}).get("homestead", {}).get("rented", false) else "承租荒院后，可留意苔瓦民居门前挑剩的蔬菜筐。"))
		1: lines.append("• 《歪萝卜也能上桌》 1/5：找农人田青询问门边分叉萝卜的去向。")
		2: lines.append("• 《歪萝卜也能上桌》 2/5：去超市找林穗了解零售货架的损耗顾虑。")
		3: lines.append("• 《歪萝卜也能上桌》 3/5：带蔬菜 ×3、林菇 ×1 找厨师陈鱼试做时令小菜。")
		4: lines.append("• 《歪萝卜也能上桌》 4/5：" + ("陈鱼正在试菜，过一夜再找田青听熟客反馈。" if waiting_overnight(data, "wai_luo_bo") else "时令小菜大受欢迎！预留1格背包找田青选定门前陈列。"))
		5: lines.append("• 《歪萝卜也能上桌》已完成：门前现设『%s』（苔瓦民居门前右键可切换）。" % style_name(str(wlb.get("style", "basket"))))
	var lybyz := record(data, "liu_yi_ba_yi_zi")
	match int(lybyz.get("step", 0)):
		0: lines.append("• 《留一把椅子》：" + ("珊湾岛海盗赤绳的铁锅边压着旧店传单，走近右键查看。" if data.get("restaurant", {}).get("rented", false) else "承租北街旧店后，可在珊湾岛赤绳营地留意铁锅边的传单。"))
		1: lines.append("• 《留一把椅子》 1/5：在珊湾岛听海盗赤绳提起想上岸吃饭的事。")
		2: lines.append("• 《留一把椅子》 2/5：回潮芽镇岸边渔铺找周潮核实当年的旧账。")
		3: lines.append("• 《留一把椅子》 3/5：带绳子 ×2、废金属 ×2 回珊湾让赤绳亲自编缆补还。")
		4: lines.append("• 《留一把椅子》 4/5：" + ("赤绳刚送还新缆与网坠，过一夜再找陈鱼商议店门规矩。" if waiting_overnight(data, "liu_yi_ba_yi_zi") else "旧账已补还！预留1格背包找陈鱼定下店门规矩。"))
		5: lines.append("• 《留一把椅子》已完成：店外现设『%s』（潮间寿司屋门外右键可切换）。" % style_name(str(lybyz.get("style", "stool"))))
	var jnst := record(data, "jin_nian_sha_tan")
	match int(jnst.get("step", 0)):
		0: lines.append("• 《今年的沙滩》：" + ("珊湾岛入口东侧潮线留着折返爬痕，走近右键查看。" if data.get("journal", {}).get("tide_speech", false) else "理解潮声后，可留意珊湾岛入口东侧潮线的海龟爬痕。"))
		1: lines.append("• 《今年的沙滩》 1/5：在珊湾岛找老海龟潮甲询问年轻海龟争路线的原因。")
		2: lines.append("• 《今年的沙滩》 2/5：回岸边渔铺找救援员陆舟核对近海漂流带记录。")
		3: lines.append("• 《今年的沙滩》 3/5：带植物纤维 ×3 前往风栖岛找苔露编护沙草束。")
		4: lines.append("• 《今年的沙滩》 4/5：" + ("护沙草束已顺潮漂回珊湾，过一夜再找潮甲查看。" if waiting_overnight(data, "jin_nian_sha_tan") else "潮岸暖透了！预留1格背包去珊湾找潮甲定下沙坪安排。"))
		5: lines.append("• 《今年的沙滩》已完成：珊湾现设『%s』（珊湾潮线右键可切换）。" % style_name(str(jnst.get("style", "sand"))))
	return "\n".join(lines) + "\n"

static func _restore_one(arc: String, raw: Variant, day: int) -> Dictionary:
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
	for idx in raw.choices.size():
		var item: Variant = raw.choices[idx]
		var max_reply := _reply_count(arc, idx + 1) - 1
		if not integer(item, 0, max_reply):
			return {}
		clean_choices.append(int(item))
	var valid_styles: Array = ARC_STYLES[arc]
	if (step < 5 and raw.style != "") or (step == 5 and raw.style not in valid_styles):
		return {}
	return {
		"step": step,
		"day": int(raw.day),
		"choices": clean_choices,
		"style": str(raw.style),
	}

static func restore(value: Variant, day: int, saved_version: int = 19) -> Dictionary:
	if not value is Dictionary:
		return {}
	if saved_version == 17:
		if value.size() != 1 or not value.has("hou_chao_yuan"):
			return {}
		var hcy := _restore_one("hou_chao_yuan", value.hou_chao_yuan, day)
		if hcy.is_empty():
			return {}
		var migrated := create()
		migrated.hou_chao_yuan = hcy
		return migrated
	if saved_version == 18:
		if value.size() != V18_ARCS.size() or not value.has_all(V18_ARCS):
			return {}
		var migrated_18 := create()
		for arc_18: String in V18_ARCS:
			var parsed_18 := _restore_one(arc_18, value[arc_18], day)
			if parsed_18.is_empty():
				return {}
			migrated_18[arc_18] = parsed_18
		return migrated_18
	if value.size() != ARCS.size() or not value.has_all(ARCS):
		return {}
	var out := {}
	for arc: String in ARCS:
		var parsed := _restore_one(arc, value[arc], day)
		if parsed.is_empty():
			return {}
		out[arc] = parsed
	return out

static func integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and floorf(float(value)) == float(value) and value >= low and value <= high

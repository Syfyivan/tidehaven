extends RefCounted
## Read-only daily conversation. The existing journal owns introductions and daily affinity.
const BASIC := {
	"xu_an": ["今早来找我的三个人都说只耽误一句话。现在茶已经凉了三回。", "陆遥替我把门口那张指路图转正了。我挂的时候，北街正冲着地面。"],
	"he_mu": ["这把勺子是门框剩下的料。别看它小，弧度比门框费事。", "顾星当初说只借半张桌。后来零件占一半，图纸占另一半，我只好站着。"],
	"yan_zhen": ["锤子、钳子，一样不少。茶杯又没了。汤禾上回说我这叫偏科。", "我喜欢收工后找个人坐桌子那头。有人陪着，茶总喝得快些。"],
	"lin_sui": ["这张纸别揉，背面还能写价签。省下来的钱不多，可我看着舒坦。", "许棉把我的右口袋补好了。左边也快磨穿了，我得找个自然的开场。"],
	"su_qin": ["画花瓶最难的倒是影子。人一来回挡窗光，我就得停笔等着。", "汤禾这壶茶，茶叶倒是精神得很。下次请他给水也留点位置。"],
	"tang_he": ["认领东西先说特征。说‘一个杯子’可不行，我这儿连花纹都能凑四种。", "茶罐摆成一排，倒显得我很会选茶。其实还是最常喝的那两种。"],
	"zhou_chao": ["今早那条大鱼我可没说有多长。是乔信一路听，一路给它添的。", "赤绳问烤鱼要不要讲究气势。我让他先把柴拿开两根。"],
	"tian_qing": ["萝卜歪一点，切进锅里就看不出来了。林穗的秤可别也跟着歪。", "沐桐画一片叶子画了半天。我说叶子还会长，她让我先别告诉它。"],
	"lu_yao": ["我今天找到一张写反的价牌。先别问是哪家，店主还没发现。", "往东再向南……算了，你记住镇公所，到了那儿就好认了。"],
	"chen_yu": ["今天这块鱼切得顺，连刀都像好说话了。昨天可不是这样。", "谁给这菜起的名字？四个字的东西写了十二个字，端上桌早凉了。"],
	"wen_zhi": ["今天有人把潮水写成‘海在换位置’。我还没想好要不要改，先留着。", "给林穗写价牌比改作文紧张。多写一个零，她会来找我当面算。"],
	"qiao_xin": ["我今早绕远路不是送错，是那户人在晒被子。路记熟了，也得看眼前。", "这封信写了三行‘劳烦转交’，地址倒只有半行。我得去问问。"],
	"shi_xun": ["这块像一只睡着的鸭子。严砧说像坏镐头。他看什么都像要修的。", "去山麓那段路，最后一截脚下松。回来时别只顾着数矿石。"],
	"sen_ke": ["我说的‘弯腰树’你认出来了吗？不是让你一路弯着腰走。", "田青叫它茶匙草，沐桐写的是另一种名。我先都记着，明天带实物给她们看。"],
	"lu_zhou": ["这结拉这头就开。白帆偏要多绕一圈，说看着牢。我替他解了半天。", "今天没什么急事。我想坐在这儿把午饭吃完，你路过打声招呼就行。"],
	"mu_tong": ["叶子的背面更浅，你看这一张。别急着夸，我把正反画反过一次。", "今天风不大，纸还是跑了。田青说我压纸的石头也画得太专心，忘了真放上去。"],
	"gu_xing": ["这颗螺丝应该是多出来的。嗯，‘应该’两个字先保留。", "贺木给我画了桌面的界线。零件没有越线，图纸的角算不算？"],
	"xu_mian": ["袖口翻进去了，要我帮你捋一下吗？你别动——好了，顺眼多了。", "林穗说补丁越小越好。我看那口袋，最省事的是让她少装半把铜币。"],
	"bai_fan": ["这个小盒子好卖，就是人人都问装什么。我说你先有盒子，总会有东西。", "货价和船位都得记清。多装一箱，就得少带别的。"],
	"chi_sheng": ["这地方我叫它三风口。其实只有一股风，名字先取大点。", "你别看我锅底黑，锅口这圈还是能照见人的。……别拿去问陈鱼。"],
	"chao_jia": ["你们又给岸边换名字了？石头没换，我还是按石头认。", "今天这层沙暖些。你要坐，坐旁边，我刚把这个位置压平。"],
	"tai_lu": ["你把花拔掉，又买另一种花种下。是原来那种站错地方了吗？", "我给石头排了队。风没吹乱，倒是我自己记不住谁排第一。"],
	"lan_ying": ["你们说钟响就是该回家。要是我学钟响，你们会不会提前收摊？", "刚才那个声音很短，尾巴却留了很久。你们的门是不是都爱这样抱怨？"],
}
const STORY_LINES := {
	"yan_zhen": "石寻那把镐的事已经说妥。以后修工具，我先问要留哪一处，省得白费一炉火。",
	"su_qin": "今天饭吃过了，碗也洗了。你这个检查的眼神，我平常就常用。",
	"tang_he": "乔信那四只木屐终于凑成两双了。要是再少一只，我先问他家里，不问失物篮。",
	"zhou_chao": "没鱼的日子我也记着呢。顾星看那几页最起劲，真是稀奇。",
	"lu_yao": "我那张小地图还留着。自己的路线画完，再看镇里的路，倒多看见几个平常没注意的拐角。",
	"chen_yu": "林穗再送饭单来，我先检查四个纸角。你笑吧，我确实养成习惯了。",
	"wen_zhi": "树林里的敲门声已经讲过了。现在孩子们想找一棵会开门的树，森柯恐怕得再听他们讲一回。",
	"qiao_xin": "今天有个包裹又响了。先看单子，铁皮的。好，这回我直接送。",
	"shi_xun": "矿记里那页没再划掉。旁边空了一行，等以后有新发现再补。",
	"sen_ke": "老树那页后面又接了一页。菌子画得不太像，沐桐说至少方向对。",
	"mu_tong": "那页留下了，题目也写好了。现在翻到它，我会停一会儿，再画后面的。",
	"gu_xing": "旧记录都留下了。再遇到同样的偏差，我至少不用从第一页重猜。",
	"bai_fan": "乔信那只箱子，我一个赠品都没塞。封盖前还特意看了眼自己的手。",
	"chi_sheng": "烤鱼那几条我记着。少添柴，抬高，翻面。顺序没错吧？我问问，不算求教。",
	"chao_jia": "年轻的认新路，我听它们讲过了。白石那段还记着，不必每次都从那里起头。",
	"tai_lu": "观察册捆好了。今天那株又偏出去一点，我就在纸边再添一笔。",
	"lan_ying": "那段歌还没取岸上的名字。你上回说怎么记，我还记得。",
}
const ENDING_LINES := {
	"tian_qing": ["野花田这个名字我记住了。有人再说那角落空着，我就指给他看。", "那块地就歇一季。明年再说，今天不往上添活。"],
	"lu_zhou": ["这两根新绳留作练习。那次救援的后半段，我也记起来了，人是一起带回来的。", "你说累了也能把值班交出去，这句我记着。下回我会先开口。"],
	"xu_mian": ["这次样子我先想口袋放什么。别笑，钥匙真能把好料子戳出洞。", "蓝绿那块布我留在手边。再挑配色时，先拿它放旁边看一眼。"],
}

static func line(data:Dictionary, slot:String, id:String) -> String:
	if slot not in ["host", "guest"] or not BASIC.has(id): return ""
	var pool:Array = BASIC[id].duplicate()
	var followup:String = progress(data, slot, id)
	if not followup.is_empty(): pool.append(followup)
	var chronicle:String = chronicle_line(data, id)
	if not chronicle.is_empty(): pool.append(chronicle)
	var index:int = posmod(int(data.get("day", 1)) + BASIC.keys().find(id), pool.size())
	return str(pool[index])

static func chronicle_line(data:Dictionary, id:String) -> String:
	var hcy:Dictionary = data.get("chronicles", {}).get("hou_chao_yuan", {})
	if int(hcy.get("step", 0)) != 5: return ""
	var inn:bool = str(hcy.get("style", "")) == "inn"
	match id:
		"xu_an": return "候潮驿院那盏门灯傍晚亮起来很显眼，岑婆听说了准高兴。" if inn else "候潮农庄的木牌挂正了。路过西门看见那只竹篮，就知道这院子真有人气了。"
		"he_mu": return "门廊那根横木顶稳了，挂风灯正合适，海风吹不晃。" if inn else "门廊横木加固过了，那只旧木匣的榫头我现在还记着。"
		"qiao_xin": return "现在往东南送信好认多了，看见候潮驿院的灯就知道没走岔。" if inn else "岑婆回信字大又清楚，比那些只写半行地址的省心多啦。"
		"lu_yao": return "指路图上我已经把『旧院』改成现在的候潮院名号了。"
	return ""

static func progress(data:Dictionary, slot:String, id:String) -> String:
	if slot not in ["host", "guest"] or not BASIC.has(id): return ""
	if id == "xu_an":
		var home:Dictionary = data.get("island", {}).get("homestead", {})
		if not home.get("rented", false): return ""
		if not home.get("claimed", {}).get(slot, false):
			return "院子的租约收好了。还有你的工具那份，我按人留着，包里空些就来拿。"
		return "你的工具已经领齐了。院子的事不用天天来报，想种什么就种什么。"
	if id == "he_mu":
		var house:Dictionary = data.get("housing", {})
		if house.get("carpenter", false): return "船屋里东西得放稳。我那把尺昨天滑到床下了，岸上可没这毛病。"
		if int(house.get("ready_day", 0)) > 0: return "材料都收妥了，屋子还在施工。你们照常出海，等完工再来挑放什么。"
		if int(house.get("level", 0)) >= 1: return "屋子能住了。想添家具时先量门，别等桌子做好才发现抬不进去。"
		return ""
	if id == "lin_sui":
		return "听说你们接了北街旧店。米要备多少，先算好；别开着门又回来找零头。" if data.get("restaurant", {}).get("rented", false) else ""
	var record:Dictionary = data.get("stories", {}).get(slot, {}).get(id, {})
	if int(record.get("step", 0)) != 3: return ""
	var choices:Array = record.get("choices", [])
	if choices.size() != 3: return ""
	if ENDING_LINES.has(id):
		if choices[2] not in [0, 1]: return ""
		return str(ENDING_LINES[id][int(choices[2])])
	return str(STORY_LINES.get(id, ""))

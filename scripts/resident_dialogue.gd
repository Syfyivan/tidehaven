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
	"cen_po": ["以前带船进港，连喝口茶都盯着风向标。现在坐着看云走偏了，倒觉得挺有意思。", "许岸每次见我都把桌面擦得锃亮。其实我最怀念的，反倒是旧值班室那张歪腿藤椅。"],
	"a_yuan": ["陈鱼店里那张靠窗凳子左横档磨得最亮，我猜常坐的人习惯踮着左脚喝汤。", "沐桐教我认了三种树皮颜料，我答应替她的标本夹画一枚小木签。"],
	"mi_luo": ["你们岸上丢下来的怀表真奇怪，走快两下就说是坏了，明明是赶着去看涨潮嘛。", "澜影借了我一块回音石试音梳，敲一下能把旁边睡着的小虾米震醒两只。"],
	"san_jin": ["三斤把圆下巴搁在铜秤盘边打了个盹，胡须跟着海风一翘一翘。", "三斤用前鳍把两颗扁石子拨成一排，歪着脑袋满意地拍了拍肚皮。"],
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
	"cen_po": "那只没上发条的旧怀表我还揣着，想散步时摸到它，就提醒自己今天不用赶钟点。",
	"a_yuan": "袖口那点擦不掉的朱砂红我干脆留在签名角当印章了，看着比正经印泥还顺眼。",
	"mi_luo": "少了一齿的八音盒留着那一拍空拍之后，海浪声正好替它补上了那个音！",
	"san_jin": "三斤认得你上次挑过的那块条纹海石，拿湿漉漉的鼻尖轻轻碰了碰你的靴面。",
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
	var chron:Dictionary = data.get("chronicles", {})
	var jyjl:Dictionary = chron.get("jiu_yuan_ji_lu", {})
	if int(jyjl.get("step", 0)) == 5:
		var rack:bool = str(jyjl.get("style", "")) == "rack"
		match id:
			"lu_zhou": return "港道口那副『岸边救生圈绳架』每天早晚我都顺手理一遍，巡海簿上连着好几页都是『今日无事』！" if rack else "『平潮备航公告栏』挂出来后，连路过的小孩都会背浮标方位口诀，巡海簿空着险情栏真舒心。"
			"su_qin": return "晴天演练过后，因为麻绳缠手来诊所涂药的人真少了一大半。"
			"sen_ke": return "现在大家报位置都晓得说『灯柱往南几船身』，再也没人光喊『大石头旁边』啦！"
	var mzbt:Dictionary = chron.get("ming_zi_bu_tong", {})
	if int(mzbt.get("step", 0)) == 5:
		var folio:bool = str(mzbt.get("style", "")) == "folio"
		match id:
			"mu_tong": return "『茶匙草 · 海风车前 · 听风耳』并排写在四时生长图谱顶上，每次翻开都觉得热闹极了！" if folio else "草圃边那三块俗名木签立在一起，田青大姐路过瞧见总会笑一笑。"
			"wen_zhi": return "我把『茶匙草』和『听风耳』都收进镇公所图鉴页了，孩子们记得比单背书名快得多！"
	var wcb:Dictionary = chron.get("wu_cha_biao", {})
	if int(wcb.get("step", 0)) == 5:
		var slate_t:bool = str(wcb.get("style", "")) == "slate_tide"
		match id:
			"gu_xing": return "『双栏潮汐余量板』把内湾基准和外岬横风提前量并排写清，再也不用死磕唯一数字了！" if slate_t else "『黄铜浮筒测潮仪』加上岑婆的横风余量游标后，跑船人和我都看得顺眼！"
			"lu_yao": return "我已经把内湾平水和雾岬急流的分界线补画在西岸指路图边啦。"
	var frcdq:Dictionary = chron.get("feng_ren_chu_de_qi", {})
	if int(frcdq.get("step", 0)) == 5:
		var f_style := str(frcdq.get("style", "tide"))
		var f_label := "潮青双燕尾旗" if f_style == "tide" else ("暖赭归航三角旗" if f_style == "sun" else "林翠风语长旒")
		match id:
			"xu_mian": return "你们木筏挂上『%s』以后，林穗说站在西街坡顶都能一眼认出你们回港！" % f_label
			"bai_fan": return "哈哈，你们那面『%s』在海雾里精神得很，老远我就知道是熟人靠过来啦！" % f_label
	var bgc:Dictionary = chron.get("bu_gan_chao", {})
	if int(bgc.get("step", 0)) == 5:
		var chair:bool = str(bgc.get("style", "")) == "chair"
		match id:
			"cen_po": return "西岸那把向海藤椅坐着真敞亮，下回从邻港过来我还先去那儿喝口热茶。" if chair else "《潮芽港新旧潮汐手札》摆在西岸木台上，路过的年轻船手翻一翻心里就有底了。"
			"xu_an": return "岑婆说不摆迎宾席果然自在多了，昨天她还顺手指点了我两句防风栏的位置。"
	var kyz:Dictionary = chron.get("kong_yi_zi", {})
	if int(kyz.get("step", 0)) == 5:
		var hall:bool = str(kyz.get("style", "")) == "hall"
		match id:
			"a_yuan": return "镇公所走廊和寿司屋都挂上空椅子速写后，路过的人总忍不住猜下一把画的是谁！" if hall else "寿司屋西墙那排空椅子小画框跟饭菜热气配在一起，看着就暖洋洋的。"
			"tang_he": return "阿沅画里那把搭半干毛巾的竹椅被林穗一眼认出来，我现在收毛巾都折得方方正正。"
	var zbzz:Dictionary = chron.get("zou_bu_zhun_zhong", {})
	if int(zbzz.get("step", 0)) == 5:
		var grotto:bool = str(zbzz.get("style", "")) == "grotto"
		match id:
			"mi_luo": return "礁洞的报潮八音钟一到平潮就叮咚响，连海洞口的鱼群都跟着打拍子呢！" if grotto else "海岸木架潮汐钟和礁洞主钟对得严丝合缝，夜潮一涨咱们两边同时知道！"
			"gu_xing": return "米洛改出来的太阴潮汐钟齿比妙极了，我还记进了自己的误差笔记里。"
	var bstw:Dictionary = chron.get("bu_shi_tan_wei", {})
	if int(bstw.get("step", 0)) == 5:
		var buoy:bool = str(bstw.get("style", "")) == "buoy"
		match id:
			"san_jin": return "三斤在暖烘烘的木台上舒展肚皮，前鳍轻轻拍了拍旁边装满圆贝壳的小木盒。" if buoy else "三斤安安稳稳趴在晒背木台上晒胡须，再也没去霸占周潮的鱼秤。"
			"zhou_chao": return "三斤昨天又往浅滩浮球边推了两颗圆石子，不讨鱼吃、各晒各的太阳，省心多啦！" if buoy else "有了岸边那张带海苔味的向阳晒背台，三斤早上晒够太阳自己就回珊湾去了。"
	var kjh:Dictionary = chron.get("kan_jian_hai", {})
	if int(kjh.get("step", 0)) == 5:
		var lamp:bool = str(kjh.get("style", "")) == "lamp"
		match id:
			"he_mu": return "『防潮风灯工角』傍晚一点亮，刨木头看纹路清清楚楚，严砧来瞧过也说稳当。" if lamp else "『迎风敞窗工角』推开就是海风，连顾星借桌角画图都嫌屋里闷了。"
			"yan_zhen": return "贺木那套热油淬过的防盐窗轴一点没生锈，昨天他还回岸跟我喝了一壶茶。"
			"gu_xing": return "我借贺木的新百叶窗框测过三次海雾湿度，读数比旧木窗稳多了！"
	var wlb:Dictionary = chron.get("wai_luo_bo", {})
	if int(wlb.get("step", 0)) == 5:
		var crock:bool = str(wlb.get("style", "")) == "crock"
		match id:
			"tian_qing": return "门前摆起『时令腌菜陶坛』后，歪萝卜切块脆生生的，半根都不糟蹋。" if crock else "门前有了『田间直供菜篓』，分叉的甜根菜一下地就有去处啦。"
			"lin_sui": return "顺直的摆货架、分叉的进时令菜篓，我这周的损耗账好看多了！"
			"mu_tong": return "田青大姐留了两根长相最稀奇的分叉萝卜给我画速写，画完照样下锅。"
	var lybyz:Dictionary = chron.get("liu_yi_ba_yi_zi", {})
	if int(lybyz.get("step", 0)) == 5:
		var p_style := str(lybyz.get("style", "stool"))
		match id:
			"chi_sheng": return "行行行，规矩我记着呢——双股缆绳我已经赔给周潮了，买热饭照价给钱！"
			"zhou_chao": return "赤绳编回来的那两条粗缆手艺倒不赖。一码归一码，旧账算清了，交情另说。"
			"chen_yu": return ("赤绳昨天收市后真规规矩矩坐在门外矮凳上喝完鱼汤，碗还自己叠好了。" if p_style == "stool" else ("侧窗外带台挺省心，钱货两清，镇上熟客也觉得稳妥。" if p_style == "window" else "港规木牌挂在门外，赤绳路过看了一眼倒也没耍赖，说等大家信得过再来。"))
	var jnst:Dictionary = chron.get("jin_nian_sha_tan", {})
	if int(jnst.get("step", 0)) == 5:
		var marker:bool = str(jnst.get("style", "")) == "marker"
		match id:
			"chao_jia": return "珊湾那根慢行浮木标立得好，路过的小船远远就收桨，小辈们晒背踏实多了。" if marker else "向阳歇沙坪被草束拢得暖洋洋的，那两只爱争路的小海龟今早抢着趴那儿呢。"
			"lu_zhou": return "我已经把珊湾东侧的新潮线标进巡海册了，出船路过都会留神慢行。"
			"tai_lu": return "海风捎信来啦，珊湾边那排护沙草束已经自己扎下浅根了！"
	var lyw:Dictionary = chron.get("liu_yi_wan", {})
	if int(lyw.get("step", 0)) == 5:
		var s_style := str(lyw.get("style", "home"))
		var s_label := "家常暖锅席" if s_style == "home" else ("时令鲜蔬席" if s_style == "season" else "海港鲜鱼席")
		match id:
			"chen_yu": return "『%s』挂出去以后，常客进门先看锅里冒没冒热气，比看菜单还快。" % s_label
			"tian_qing": return "我的歪萝卜如今在你们『%s』里可是抢手货，林穗昨天还多问了一句呢。" % s_label
			"su_qin": return "现在傍晚收工顺路去吃碗热汤，汤禾终于不用半夜替我盯灶台了。"
			"lin_sui": return "北街旧店挂起『%s』的牌子后，顺路来买米买料的人也准时多了。" % s_label
	var ka:Dictionary = chron.get("kao_an", {})
	if int(ka.get("step", 0)) == 5:
		var ferry:bool = str(ka.get("style", "")) == "ferry"
		match id:
			"bai_fan": return "雾岬外侧那块新转向标老远就能瞧见，起雾天靠潮芽港再也不用提心吊胆了。"
			"lu_yao": return "我在西岸指路图旁注好了新航标说明，下船的客人一眼就能认出进镇的路。" if ferry else "补给港的木箱码得整整齐齐，路过外海的船主看着就踏实。"
			"qiao_xin": return "定期客船靠岸那天，候船长椅上坐满了等信和访友的人！" if ferry else "联络船带货越来越准时，西岸补给箱省了我好多搬运工夫。"
	var hlj:Dictionary = chron.get("hai_lin_ju", {})
	if int(hlj.get("step", 0)) == 5:
		var chime:bool = str(hlj.get("style", "")) == "chime"
		match id:
			"wen_zhi": return "《潮间邻居附录》借阅得最快，孩子们都想去浅滩听听『听潮海螺架』的轻响。" if chime else "《潮间邻居附录》定稿后，大家都认得西岸浅滩那座『白石安澜界』了。"
			"chao_jia": return "浅滩的海螺声很轻，年轻海龟听见就知道岸边安稳，不用再绕远路了。" if chime else "那几块安澜白石叠得稳当，我们远远顺着浪看一眼就认得路。"
			"lan_ying": return "我现在分得清抛锚声和你们敲海螺架打招呼的声音啦！" if chime else "定音石垫好以后，回声干干净净，再也不会把海龟吓跑了。"
			"tai_lu": return "温知回信说干叶书签夹在附录里了，海风吹过浅滩的声音连风栖岛都听得见。"
	var hcy:Dictionary = chron.get("hou_chao_yuan", {})
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

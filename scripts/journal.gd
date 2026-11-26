extends RefCounted
## Optional shared story and personal errands. No timed failure or mandatory gates.
const Inventory=preload("res://scripts/inventory.gd")
const ResidentDialogue=preload("res://scripts/resident_dialogue.gd")
const REQUESTS:={
	"lu_zhou":{"title":"值夜的备用绳","text":"旧绳被盐水磨毛了。换一根，值夜时心里就踏实些。","item":"rope","count":2,"coins":14},
	"mu_tong":{"title":"压画纸的石头","text":"风一吹画纸就跑，找两块光滑的小石头压住它们吧。","item":"stone","count":2,"coins":10},
	"gu_xing":{"title":"拆开看一看","text":"坏掉的金属零件也有用，我想看看海水究竟磨损了哪里。","item":"scrap","count":3,"coins":14},
	"xu_mian":{"title":"给布料上浆","text":"这一批布要重新整理，纤维能补好磨破的衬边。","item":"fiber","count":4,"coins":14},
	"bai_fan":{"title":"下次航行的绳子","text":"这一趟船帆磨破了，带几根牢靠的绳子来吧。","item":"rope","count":4,"coins":24},
	"chi_sheng":{"title":"海盗的晚饭","text":"今晚不劫船，只想吃一顿热乎的。能带两份料理来吗？","item":"meal","count":2,"coins":30},
	"chao_jia":{"title":"干净的产卵地","text":"海边的废料缠住了我的家人，带走几块废金属，我来教你辨认潮声。","item":"scrap","count":6,"coins":18},
	"tai_lu":{"title":"林间的种子","text":"旧林子想要新的生命。送来六颗种子，我会教你唤醒一阵小雨。","item":"seed","count":6,"coins":20},
	"lan_ying":{"title":"潮洞的回响","text":"带来四块金属矿石，我能让你听清水中的气息。","item":"ore","count":4,"coins":24},
	"xu_an":{"title":"码头的长椅","text":"路过的人总想找个地方坐坐，能帮码头换些旧木板吗？","item":"wood","count":8,"coins":18},
	"he_mu":{"title":"耐用的绑绳","text":"修屋的工具架要重新捆扎。帮我找些纤维吧。","item":"fiber","count":6,"coins":16},
	"yan_zhen":{"title":"试炉","text":"这一炉刚生火，需要一些新矿石试试火候。","item":"ore","count":4,"coins":24},
	"lin_sui":{"title":"柜台的新鲜菜","text":"有人问起本地种的蔬菜，带一小篮来好吗？","item":"veg","count":3,"coins":18},
	"su_qin":{"title":"修补药箱","text":"诊所的药箱底板松了，我需要几块干木板。","item":"wood","count":5,"coins":14},
	"tang_he":{"title":"添柴","text":"澡堂今晚要多烧些热水，能带一捆柴来吗？","item":"wood","count":6,"coins":16},
	"zhou_chao":{"title":"今天的鱼讯","text":"带几条你在海里找到的鱼，咱们聊聊最近的鱼群。","item":"fish","count":3,"coins":21},
	"tian_qing":{"title":"田边的草绳","text":"篱笆缺了一截，纤维能编成不错的草绳。","item":"fiber","count":5,"coins":15},
	"lu_yao":{"title":"午后的汤","text":"晚点煮一锅菜汤，想放些新鲜蔬菜。","item":"veg","count":2,"coins":13},
	"chen_yu":{"title":"练刀的食材","text":"厨房想试一道新菜，先帮我准备两条鲜鱼吧。","item":"fish","count":2,"coins":16},
	"wen_zhi":{"title":"自然课","text":"孩子们想看看林里的蘑菇，带一点回来当标本吧。","item":"mushroom","count":2,"coins":14},
	"qiao_xin":{"title":"包裹的垫料","text":"易碎的货物需要垫好，海上捞来的叶子也能派上用场。","item":"leaf","count":6,"coins":12},
	"shi_xun":{"title":"矿道补缝","text":"矿道脚边有些坑洼，收些碎石就能填平。","item":"stone","count":5,"coins":18},
	"sen_ke":{"title":"林地观察","text":"林中蘑菇又长出来了，采些回来看看今年的收成。","item":"mushroom","count":3,"coins":20},
}
const OTHER_NAMES:={"bai_fan":"白帆","chi_sheng":"赤绳","chao_jia":"潮甲","tai_lu":"苔露","lan_ying":"澜影"}
const BEACON:=Vector2(284,336)
const STORY:=[
	{"npc":"xu_an","title":"海风里的旧灯","text":"码头的引航灯熄了以后，夜归的人总要绕远。愿意帮镇上修灯吗？这是自愿的，先过好你的日子也没关系。","cost":{"wood":12,"scrap":6},"coins":25},
	{"npc":"he_mu","title":"一盏灯，一个家","text":"灯修好了，海上也有了方向。等你的院子能住人，再来一起补好引航灯旁边的护栏。","cost":{"wood":10,"stone":8},"coins":30},
	{"npc":"wen_zhi","title":"海洞里的回声","text":"旧书说，深处的潮声带着语言。去过回声海洞第三层后，带点矿石来，我们试着解读它。","cost":{"ore":6},"coins":35},
]

static func personal()->Dictionary:return {"accepted":{},"completed":{},"friendship":{},"talked":{},"gifted":{}}
static func solids(data:Dictionary)->Array:
	var result:Array=[Rect2(BEACON-Vector2(8,10),Vector2(16,14))]
	if int(data.journal.story_step)>=2:result.append(Rect2(BEACON+Vector2(18,-12),Vector2(48,16)))
	return result
static func create()->Dictionary:return {"host":personal(),"guest":personal(),"story_step":0,"story_accepted":false,"tide_speech":false,"spells":{},"cooldown":{"host":0.0,"guest":0.0}}

static func choices(data:Dictionary,slot:String,id:String)->Array:
	if not REQUESTS.has(id):return []
	var p:Dictionary=data.journal[slot]
	var result:Array=[]
	if p.accepted.has(id):
		var q:Dictionary=REQUESTS[id]
		result.append(row("town_errand_finish","交付：%s ×%d · +%d金币 / 好感+20"%[Inventory.ITEM_NAMES[q.item],q.count,q.coins],id))
	elif int(data.day)-int(p.completed.get(id,-7))>=7:result.append(row("town_errand_accept","委托："+str(REQUESTS[id].title),id))
	result.append(row("town_gift","赠送一份料理 · 每日一次",id))
	var step:int=int(data.journal.story_step)
	if step<STORY.size() and STORY[step].npc==id:
		result.append(row("town_story_finish" if data.journal.story_accepted else "town_story_accept",("交付主线：" if data.journal.story_accepted else "可选故事：")+str(STORY[step].title),id))
	return result

static func row(verb:String,label:String,id:String)->Dictionary:return {"action":verb,"label":label,"args":{"id":id}}

static func talk(data:Dictionary,slot:String,id:String,introduction:String="")->String:
	if slot not in ["host","guest"] or not REQUESTS.has(id):return ""
	var p:Dictionary=data.journal[slot]
	var first_meeting:bool=not p.talked.has(id)
	if int(p.talked.get(id,0))!=int(data.day):
		p.talked[id]=int(data.day);p.friendship[id]=mini(1000,int(p.friendship.get(id,0))+2)
	return introduction if first_meeting and not introduction.is_empty() else ResidentDialogue.line(data,slot,id)

static func action(data:Dictionary,player:Dictionary,slot:String,id:String,verb:String)->String:
	var p:Dictionary=data.journal[slot]
	var q:Dictionary=REQUESTS[id]
	match verb:
		"town_errand_accept":
			if p.accepted.has(id):return "这份委托已经记在手记里。"
			if int(data.day)-int(p.completed.get(id,-7))<7:return "上次帮的忙已经够了，下周再来看看吧。"
			p.accepted[id]=int(data.day)
			return "%s 需要%s ×%d；不设期限，准备好再来交付。"%[q.text,Inventory.ITEM_NAMES[q.item],q.count]
		"town_errand_finish":
			if not p.accepted.has(id):return "还没有接取这份委托。"
			if int(data.money)+int(q.coins)>1000000000:return "共同钱袋已满，委托和材料都保留。"
			if not exchange(player,{q.item:q.count},{}):return "随身物资还不够，委托和物品都保留。"
			p.accepted.erase(id);p.completed[id]=int(data.day);p.friendship[id]=mini(1000,int(p.friendship.get(id,0))+20)
			data.money=mini(1000000000,int(data.money)+int(q.coins))
			return "委托完成 · +%d金币 · 好感+20。谢谢你特意跑一趟！"%q.coins
		"town_gift":
			if int(p.gifted.get(id,0))==int(data.day):return "今天已经送过礼物了，聊聊天就好。"
			if not exchange(player,{"meal":1},{}):return "随身带一份料理，再来送给这位朋友吧。"
			p.gifted[id]=int(data.day);p.friendship[id]=mini(1000,int(p.friendship.get(id,0))+10)
			return "对方收下了料理 · 好感+10。"
		"town_story_accept","town_story_finish":
			var step:int=int(data.journal.story_step)
			if step>=STORY.size() or STORY[step].npc!=id:return "这里暂时没有新的主线进展。"
			var chapter:Dictionary=STORY[step]
			if verb=="town_story_accept":data.journal.story_accepted=true;return str(chapter.text)+" 材料已记在J手记。"
			if not data.journal.story_accepted:return "先和对方聊聊这段故事吧。"
			if step==1 and int(data.housing.level)<1:return "等小屋修好，再回来聊码头护栏的事。"
			if step==2 and not data.rooms.visited.has("sea_3"):return "先亲自探索回声海洞第三层，听听那里的潮声。"
			if int(data.money)+int(chapter.coins)>1000000000:return "共同钱袋已满，故事和材料都保留。"
			if not exchange(player,chapter.cost,{}):return "材料还没带齐，故事不会过期，随时可以回来。"
			data.money=mini(1000000000,int(data.money)+int(chapter.coins));data.journal.story_step=step+1;data.journal.story_accepted=false
			if step==2:data.journal.tide_speech=true
			return "这一章完成 · +%d金币。%s"%[chapter.coins,"你听懂了海的语言。深处的伙伴现在能与你交谈。" if step==2 else "新的故事会在岛上继续，想做的时候再去。"]
	return "这项委托操作无效。"

static func exchange(player:Dictionary,cost:Dictionary,reward:Dictionary)->bool:
	var bag:Array=player.bag.duplicate(true)
	for item:String in cost:
		if Inventory.count(bag,item)<int(cost[item]):return false
		Inventory.remove(bag,item,int(cost[item]))
	for item:String in reward:
		if Inventory.add(bag,item,int(reward[item]))!=0:return false
	player.bag=bag;return true

static func restore(value:Variant,day:int)->Dictionary:
	if not value is Dictionary or value.size()!=7 or not value.has_all(["host","guest","story_step","story_accepted","tide_speech","spells","cooldown"]):return {}
	if not integer(value.story_step,0,3) or not value.story_accepted is bool or not value.tide_speech is bool:return {}
	if value.tide_speech!=(int(value.story_step)==3) or (value.story_step==3 and value.story_accepted):return {}
	if not value.spells is Dictionary or value.spells.size()>2 or not value.cooldown is Dictionary or value.cooldown.size()!=2:return {}
	for key in value.spells:
		if key not in ["breath","rain"] or value.spells[key]!=true or not value.tide_speech:return {}
	var result:Dictionary=value.duplicate(true);result.story_step=int(result.story_step)
	for slot:String in ["host","guest"]:
		if not value.get(slot) is Dictionary or value[slot].size()!=5 or not value[slot].has_all(["accepted","completed","friendship","talked","gifted"]):return {}
		for field:String in ["accepted","completed","friendship","talked","gifted"]:
			if not value[slot][field] is Dictionary or value[slot][field].size()>REQUESTS.size():return {}
			for id in value[slot][field]:
				if not REQUESTS.has(id) or not integer(value[slot][field][id],0,1000 if field=="friendship" else day):return {}
				result[slot][field][id]=int(value[slot][field][id])
		if typeof(value.cooldown.get(slot)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value.cooldown[slot])) or value.cooldown[slot]<0 or value.cooldown[slot]>30:return {}
		result.cooldown[slot]=float(value.cooldown[slot])
	return result

static func integer(value:Variant,low:int,high:int)->bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and floorf(float(value))==float(value) and value>=low and value<=high

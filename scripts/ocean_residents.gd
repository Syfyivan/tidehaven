extends RefCounted
const Rooms=preload("res://scripts/rooms.gd")
const Journal=preload("res://scripts/journal.gd")
const Inventory=preload("res://scripts/inventory.gd")
const Farming=preload("res://scripts/farming.gd")
const PersonalStories=preload("res://scripts/resident_stories.gd")
const NPCS:={
	"bai_fan":{"name":"白帆","role":"海商","room":"island_mist","magic":false,"talk":"海上没有固定的路。木板、绳子都留一点，修筏的时候就不慌。需要换补给，或愿意帮我修帆，都可以聊聊。"},
	"chi_sheng":{"name":"赤绳","role":"海盗","room":"island_reef","magic":false,"talk":"船长也得吃饭。你要是带了两份热料理，我愿意拿金币换，今天不谈打打杀杀。"},
	"chao_jia":{"name":"潮甲","role":"老海龟","room":"island_reef","magic":true,"talk":"潮水记得每一条回家的路。别着急，把海里的碎片一点点收起来，我们就能住得安心。"},
	"tai_lu":{"name":"苔露","role":"林地精灵","room":"island_wind","magic":true,"talk":"种子要过夜才会长大，魔法也不能跳过四季。你愿意帮林地播下希望，我就教你唤一阵雨。"},
	"lan_ying":{"name":"澜影","role":"潮洞海灵","room":"sea_3","magic":true,"talk":"别把气息留在最深处。帮我找回共鸣的矿石，我能教你借一口潮息；它会消耗体力，也需要休息才能再用。"},
}
static var _positions:Dictionary={}
static func position(id:String)->Vector2:
	if id=="lan_ying":return Vector2(460,240)
	if _positions.has(id):return _positions[id]
	var room:String=NPCS[id].room
	var wanted:=Rooms.entry(room)+Vector2(192 if id=="chao_jia" else 352,-128)
	var best:=INF
	var point:=Rooms.entry(room)
	for cell:Vector2i in Rooms.geometry(room).ordered:
		var at:=Vector2(cell)*32+Vector2(16,16)
		if not Rooms.can_stand(room,at) or not Rooms.can_stand(room,at+Vector2(0,32)):continue
		if Rooms.nodes(room).values().any(func(node):return at.distance_to(Vector2(node.x,node.y))<50):continue
		var d:=at.distance_squared_to(wanted)
		if d<best:best=d;point=at
	_positions[id]=point
	return point
static func near(player:Dictionary,id:String)->bool:
	return player.area=="room" and player.room==NPCS[id].room and Vector2(player.x,player.y).distance_to(position(id))<=64
static func options(data:Dictionary,player:Dictionary,slot:String)->Array:
	var result:Array=[]
	for id:String in NPCS:
		if not near(player,id):continue
		var npc:Dictionary=NPCS[id]
		result.append(Rooms.option("ocean_talk",str(npc.name)+" · "+str(npc.role),id,position(id)))
		if npc.magic and not data.journal.tide_speech:continue
		for choice:Dictionary in PersonalStories.entries(data,slot,id):
			choice.action=str(choice.action).replace("town_","ocean_")
			choice.target_x=position(id).x;choice.target_y=position(id).y;result.append(choice)
		for choice:Dictionary in Journal.choices(data,slot,id):
			choice.action=str(choice.action).replace("town_","ocean_")
			choice.target_x=position(id).x;choice.target_y=position(id).y;result.append(choice)
		if id=="bai_fan":result.append(Rooms.option("ocean_trade","换两杯淡水 · 塑料2",id,position(id)))
	return result
static func action(data:Dictionary,player:Dictionary,slot:String,verb:String,args:Dictionary)->String:
	var keys:Array=["id","story","step","reply"] if verb=="ocean_personal_reply" else ["id","story","step"] if verb=="ocean_personal_open" else ["id"]
	if args.size()!=keys.size() or not args.has_all(keys) or not args.get("id") is String or not NPCS.has(args.id) or not near(player,args.id):return "走近这位海上伙伴再交谈。"
	if not player.activity.is_empty() or not player.hook.is_empty() or not player.fishing.is_empty():return "先完成手上的动作，或右键取消。"
	var id:String=args.id
	var npc:Dictionary=NPCS[id]
	if npc.magic and not data.journal.tide_speech:return str(npc.name)+"：你听见轻轻的潮声，却还不能理解。岛上的温知也许知道它的来历。"
	if verb in ["ocean_personal_open","ocean_personal_reply"]:
		if player.get("resting",false) or player.get("sleep_ready",false):return "先起身再聊吧。"
		return str(npc.name)+"："+(PersonalStories.open(data,slot,args) if verb=="ocean_personal_open" else PersonalStories.action(data,player,slot,args))
	if verb=="ocean_talk":return str(npc.name)+"："+Journal.talk(data,slot,id,str(npc.talk))
	if verb=="ocean_trade":
		if id!="bai_fan":return "对方没有这些货物。"
		return "白帆：两杯淡水收好，路上别渴着。" if Journal.exchange(player,{"plastic":2},{"freshwater":2}) else "塑料不足或背包放不下，未交换物品。"
	if verb not in ["ocean_errand_accept","ocean_errand_finish","ocean_gift"]:return "这里没有这项操作。"
	var accepted:bool=data.journal[slot].accepted.has(id)
	var message:=Journal.action(data,player,slot,id,verb.replace("ocean_","town_"))
	if verb=="ocean_errand_finish" and accepted and not data.journal[slot].accepted.has(id):
		var spell:String={"tai_lu":"rain","lan_ying":"breath"}.get(id,"")
		if not spell.is_empty() and not data.journal.spells.has(spell):
			data.journal.spells[spell]=true
			message+=" 学会了%s，J手记可施放。"%("唤雨" if spell=="rain" else "潮息")
	return message

static func cast(data:Dictionary,player:Dictionary,slot:String,args:Dictionary)->String:
	if args.size()!=1 or args.get("id") not in ["breath","rain"]:return "请选择已经学会的法术。"
	var spell:String=args.id
	if not data.journal.spells.get(spell,false):return "还没有学会这个法术，先与海上的伙伴交谈。"
	if float(data.journal.cooldown[slot])>0:return "潮声还在回响，%.0f秒后可以再用。"%ceilf(data.journal.cooldown[slot])
	if not player.activity.is_empty() or player.resting or player.sleep_ready:return "先放下手上的动作或起身。"
	var cost:=12.0 if spell=="breath" else 20.0
	if player.stamina<cost:return "体力不足，不能借用潮汐的力量。"
	if spell=="breath":
		if not Rooms.underwater(player) or float(player.oxygen)>=100:return "潮息只能在缺氧的水下使用。"
		player.oxygen=minf(100,float(player.oxygen)+35)
	else:
		var plots:Dictionary=data.island.plots if player.area=="island" else data.gardens.plots if player.area=="room" and player.room=="greenhouse" else {}
		var candidates:Array=[]
		var center:=Vector2(player.x,player.y)
		for key:String in plots:
			var at:=Farming.plot_center(key)
			if absf(at.x-center.x)<=48 and absf(at.y-center.y)<=48 and not plots[key].dead and not plots[key].watered:candidates.append(key)
		if candidates.is_empty():return "身边没有需要浇水的农田，未消耗体力。"
		for key:String in candidates:plots[key].watered=true
	player.stamina-=cost;data.journal.cooldown[slot]=30.0
	return "借来一口潮息 · 氧气+35 / 体力-12。" if spell=="breath" else "附近三格范围落下小雨 · 体力-20。作物仍需过夜生长。"

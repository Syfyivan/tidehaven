extends RefCounted
## Host-owned shared stock, two preparation counters and optional evening service.
const Inventory=preload("res://scripts/inventory.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Routes=preload("res://scripts/resident_routes.gd")
const LongStories=preload("res://scripts/long_stories.gd")
const RECIPES:={
	"sashimi":{"cost":{"fish":2},"seconds":4.0,"price":12},
	"maki":{"cost":{"fish":1,"rice":1,"seaweed":1},"seconds":6.0,"price":16},
	"salad":{"cost":{"veg":2,"mushroom":1},"seconds":4.0,"price":14},
}
const SUPPLIES:={"fish":{"count":4,"price":20},"veg":{"count":6,"price":28},"mushroom":{"count":3,"price":15},"ore":{"count":4,"price":20}}
const MAX_CUSTOMERS:=6
const STOCK_ID:="restaurant_stock"

static func create()->Dictionary:
	return {"rented":false,"stock":Inventory.empty_slots(16),"menu":["sashimi","maki","salad"],"stations":[{},{}],"open":false,"day":0,"arrivals":0,"customers":[],"served":0,"missed":0,"earnings":0,"next":0.0,"settled":false,"last":{},"deliveries":{}}

static func counter()->Vector2:return Routes.place("restaurant",Vector2(592,624))
static func pantry()->Vector2:return Routes.place("restaurant",Vector2(400,624))
static func station(index:int)->Vector2:return Routes.place("restaurant",Vector2(464+index*64,624))
static func table(index:int)->Vector2:
	return Routes.place("restaurant",[Vector2(112,688),Vector2(352,736),Vector2(560,752),Vector2(1248,720)][index])
static func inside(player:Dictionary)->bool:return player.get("area")=="room" and player.get("room")=="restaurant" and player.get("online",false)
static func near(player:Dictionary,at:Vector2,reach:=72.0)->bool:return inside(player) and Vector2(player.x,player.y).distance_to(at)<=reach
static func stock_access(data:Dictionary,player:Dictionary)->bool:return data.restaurant.rented and near(player,pantry())

static func rent(data:Dictionary,player:Dictionary)->String:
	if data.restaurant.rented:return "许岸：店已经租给你们了，白天备料，傍晚自己决定开不开门。"
	if data.money<30:return "许岸：旧店首期租金30枚金币，修整柜台再带12块木板。"
	var bag:Array=player.bag.duplicate(true)
	if not Inventory.remove(bag,"wood",12):return "许岸：带12块木板修整柜台，再付30枚金币，就能开店。"
	player.bag=bag;data.money-=30;data.restaurant.rented=true
	return "许岸：北街旧店交给你们了。把食材放进备料柜，在案板做菜，18点后可以挂牌营业；走近客人上菜，打烊再结算。想出海的时候就不开店。"

static func supply(data:Dictionary,player:Dictionary,item:String)->String:
	if not SUPPLIES.has(item):return "没有这张供货单。"
	if int(data.restaurant.deliveries.get(item,0))==int(data.day):return "这单今天已经收到，明天再来吧。"
	var offer:Dictionary=SUPPLIES[item]
	if int(data.money)+int(offer.price)>1000000000:return "共同钱袋已满，这次不收物资。"
	var bag:Array=player.bag.duplicate(true)
	if not Inventory.remove(bag,item,int(offer.count)):return "供货需要%s ×%d。"%[Inventory.ITEM_NAMES[item],offer.count]
	player.bag=bag;data.money+=int(offer.price);data.restaurant.deliveries[item]=int(data.day)
	return "供货完成 · %s ×%d · +%d金币，明天还可接单。"%[Inventory.ITEM_NAMES[item],offer.count,offer.price]

static func options(data:Dictionary,player:Dictionary)->Array:
	var result:Array=[]
	if not inside(player):return result
	if not data.restaurant.rented:
		if near(player,counter()):result.append(_option("shop_manage","旧店待租 · 找镇长许岸",{},counter()))
		return result
	for point:Vector2 in [counter(),station(0),station(1)]:
		if near(player,point):result.append(_option("shop_manage","查看菜单与备餐",{},point))
	if near(player,counter(),96.0):
		var lyw_step:=int(LongStories.record(data,"liu_yi_wan").get("step",0))
		if lyw_step==0:result.append(_option("shop_inspect","查看旧店墙角的点菜单底稿",{},counter()))
		elif lyw_step>=5:result.append(_option("shop_style","切换旧店席面牌（家常／时令／海鲜）",{},counter()))
	if stock_access(data,player):result.append(_option("open_chest","打开备料柜 · 16格",{"id":STOCK_ID},pantry()))
	for customer:Dictionary in data.restaurant.customers:
		if customer.phase=="wait" and near(player,Vector2(customer.x,customer.y)):
			result.append(_option("shop_serve","给客人上%s"%Inventory.ITEM_NAMES[customer.recipe],{"id":customer.id},Vector2(customer.x,customer.y)))
	return result

static func _option(verb:String,label:String,args:Dictionary,at:Vector2)->Dictionary:
	return {"action":verb,"label":label,"args":args,"target_x":at.x,"target_y":at.y}

static func action(data:Dictionary,player:Dictionary,verb:String,args:Dictionary)->String:
	var shop:Dictionary=data.restaurant
	if not inside(player) or not shop.rented:return "先找镇长租下北街旧店，再到店里经营。"
	if not player.activity.is_empty():return "先完成手上的动作。"
	if verb=="shop_serve":
		if args.size()!=1 or not args.get("id") is String:return "走近等餐的客人上菜。"
		for customer:Dictionary in shop.customers:
			if customer.id!=args.id or customer.phase!="wait":continue
			if not near(player,Vector2(customer.x,customer.y)):return "走近客人再上菜。"
			if not Inventory.remove(player.bag,customer.recipe,1):return "客人要一份%s，先去案板取餐。"%Inventory.ITEM_NAMES[customer.recipe]
			customer.phase="eat";customer.remaining=5.0;shop.served+=1;shop.earnings+=int(RECIPES[customer.recipe].price)
			return "客人收到%s · +%d金币，打烊结算。"%[Inventory.ITEM_NAMES[customer.recipe],RECIPES[customer.recipe].price]
		return "这位客人已经点完单或离开了。"
	if verb in ["shop_prepare","shop_collect"]:
		var keys:Array=["station","recipe"] if verb=="shop_prepare" else ["station"]
		if args.size()!=keys.size() or not args.has_all(keys) or not _integer(args.station,0,1):return "请选择身边的案板。"
		var index:=int(args.station)
		if not near(player,station(index)):return "走近这张案板再备餐或取餐。"
		var work:Dictionary=shop.stations[index]
		if verb=="shop_collect":
			if work.is_empty() or float(work.remaining)>0:return "这张案板还没有做好的料理。"
			if Inventory.add(player.bag,work.recipe,1)!=0:return "背包已满，料理留在案板上。"
			shop.stations[index]={};return "取出了%s。"%Inventory.ITEM_NAMES[work.recipe]
		if not work.is_empty():return "先取走成品，或等备餐结束。"
		if not args.recipe is String or not RECIPES.has(args.recipe):return "请选择已知菜式。"
		var stock:Array=shop.stock.duplicate(true)
		for item:String in RECIPES[args.recipe].cost:
			if not Inventory.remove(stock,item,int(RECIPES[args.recipe].cost[item])):return "备料柜里的%s不足，按B存入食材。"%Inventory.ITEM_NAMES[item]
		shop.stock=stock;shop.stations[index]={"recipe":args.recipe,"remaining":RECIPES[args.recipe].seconds}
		return "开始制作%s，完成后走近案板取餐。"%Inventory.ITEM_NAMES[args.recipe]
	if not near(player,counter(),96.0 if verb in ["shop_inspect","shop_style"] else 72.0):return "走近收银台管理营业。"
	if verb=="shop_inspect":return LongStories.inspect_shop(data) if args.is_empty() else "操作参数无效。"
	if verb=="shop_style":return LongStories.toggle_shop_style(data) if args.is_empty() else "操作参数无效。"
	if verb=="shop_menu":
		if shop.open:return "先打烊，再调整菜单。"
		if args.size()!=1 or not args.get("recipe") is String or not RECIPES.has(args.recipe):return "请选择一道菜。"
		if args.recipe in shop.menu:
			if shop.menu.size()==1:return "菜单至少保留一道菜。"
			shop.menu.erase(args.recipe)
		else:shop.menu.append(args.recipe)
		return "菜单已更新，下一轮营业生效。"
	if not args.is_empty():return "操作参数无效。"
	if verb=="shop_open":
		if shop.open:return "已经营业了。"
		if data.minute<1080 or data.minute>=1380:return "晚上18:00—23:00可以挂牌营业，白天先准备食材。"
		if int(shop.day)==int(data.day) and shop.settled:return "今天已经打烊，明晚再营业。"
		shop.day=int(data.day);shop.open=true;shop.settled=false;shop.next=1.0
		return "开始营业 · 走近等餐客人上菜，最多接待6桌；23点不再接客，23:50自动结算。"
	if verb=="shop_close":return settle(data)
	return "请选择备餐、上菜或营业操作。"

static func _walk(customer:Dictionary,target:Vector2,delta:float)->bool:
	var origin:Vector2=Rooms.entry("restaurant") if customer.phase=="arrive" else table(int(customer.seat))
	var points:=Routes.path("restaurant",origin,target)
	customer.distance+=85.0*delta
	var left:=float(customer.distance)
	var at:=origin
	for point:Vector2 in points:
		var gap:=at.distance_to(point)
		if gap<=0.01:continue
		var offset:=point-at
		customer.direction=(2 if offset.x>0 else 1) if absf(offset.x)>absf(offset.y) else (0 if offset.y>0 else 3)
		if left<gap:at=at.move_toward(point,left);break
		at=point;left-=gap
	customer.x=at.x;customer.y=at.y
	return at.distance_to(target)<1

static func tick(data:Dictionary,delta:float)->void:
	var shop:Dictionary=data.restaurant
	for work:Dictionary in shop.stations:
		if not work.is_empty():work.remaining=maxf(0,float(work.remaining)-delta)
	if not shop.open:return
	if data.minute>=1430: settle(data);return
	for customer:Dictionary in shop.customers.duplicate():
		match str(customer.phase):
			"arrive":
				if _walk(customer,table(int(customer.seat)),delta):customer.phase="wait";customer.remaining=65.0
			"wait","eat":
				customer.remaining=maxf(0,float(customer.remaining)-delta)
				if float(customer.remaining)<=0:
					if customer.phase=="wait":shop.missed+=1
					customer.phase="leave";customer.distance=0.0
			"leave":
				if _walk(customer,Rooms.entry("restaurant"),delta):shop.customers.erase(customer)
	shop.next=maxf(0,float(shop.next)-delta)
	if shop.next>0 or data.minute>=1380 or shop.arrivals>=MAX_CUSTOMERS:return
	var occupied:Array=[]
	for customer:Dictionary in shop.customers:occupied.append(int(customer.seat))
	for seat in 4:
		if seat in occupied:continue
		var at:=Rooms.entry("restaurant")
		var recipe:String=shop.menu[(int(data.day)+int(shop.arrivals))%shop.menu.size()]
		shop.customers.append({"id":"%d-%d"%[data.day,shop.arrivals],"seat":seat,"recipe":recipe,"phase":"arrive","remaining":65.0,"x":at.x,"y":at.y,"direction":1,"distance":0.0,"variant":int(shop.arrivals)%5})
		shop.arrivals+=1;shop.next=8.0;break

static func settle(data:Dictionary)->String:
	var shop:Dictionary=data.restaurant
	if not shop.open:return "店已经打烊，今晚不会重复结算。"
	for customer:Dictionary in shop.customers:
		if customer.phase in ["arrive","wait"]:shop.missed+=1
	data.money=mini(1000000000,int(data.money)+int(shop.earnings))
	shop.last={"day":int(data.day),"served":int(shop.served),"missed":int(shop.missed),"revenue":int(shop.earnings)}
	shop.open=false;shop.settled=true;shop.customers=[]
	return "今晚打烊 · 上菜%d份 / 未接待%d桌 · 收入%d金币已到账。"%[shop.served,shop.missed,shop.earnings]

static func advance_day(data:Dictionary)->void:
	if data.restaurant.open:settle(data)
	for key:String in ["arrivals","served","missed","earnings","day"]:data.restaurant[key]=0
	data.restaurant.settled=false;data.restaurant.next=0.0;data.restaurant.deliveries={}

static func _integer(value:Variant,low:int,high:int)->bool:
	return _number(value,low,high) and float(value)==floorf(float(value))
static func _number(value:Variant,low:float,high:float)->bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=low and float(value)<=high
static func restore(value:Variant,day:int)->Dictionary:
	if not value is Dictionary or value.size()!=create().size() or not value.has_all(create().keys()):return {}
	for key in ["rented","open","settled"]:
		if not value[key] is bool:return {}
	if not Inventory.validate_slots(value.stock,16) or not value.menu is Array or value.menu.size()<1 or value.menu.size()>3:return {}
	var seen:Array=[]
	for item:Variant in value.menu:
		if not item is String or not RECIPES.has(item) or item in seen:return {}
		seen.append(item)
	if not value.stations is Array or value.stations.size()!=2:return {}
	for work:Variant in value.stations:
		if not work is Dictionary:return {}
		if work.is_empty():continue
		if work.size()!=2 or not work.get("recipe") is String or not RECIPES.has(work.recipe) or not _number(work.get("remaining"),0,float(RECIPES[work.recipe].seconds)):return {}
	if not _integer(value.day,0,day) or not _number(value.next,0,8):return {}
	for key in ["arrivals","served","missed"]:
		if not _integer(value[key],0,MAX_CUSTOMERS):return {}
	if int(value.served)+int(value.missed)>int(value.arrivals) or not _integer(value.earnings,0,MAX_CUSTOMERS*16):return {}
	if value.open and (not value.rented or value.settled or int(value.day)!=day):return {}
	if not value.customers is Array or value.customers.size()>4 or (not value.open and not value.customers.is_empty()):return {}
	var seats:Array=[];var ids:Array=[]
	for c:Variant in value.customers:
		if not c is Dictionary or c.size()!=10 or not c.has_all(["id","seat","recipe","phase","remaining","x","y","direction","distance","variant"]):return {}
		if not c.id is String or c.id in ids or not c.id.begins_with(str(day)+"-") or not c.id.get_slice("-",1).is_valid_int() or int(c.id.get_slice("-",1))>=int(value.arrivals):return {}
		if not _integer(c.seat,0,3) or int(c.seat) in seats or not c.recipe is String or not RECIPES.has(c.recipe) or c.phase not in ["arrive","wait","eat","leave"]:return {}
		if not _number(c.remaining,0,65) or not _number(c.x,0,Rooms.size("restaurant").x) or not _number(c.y,0,Rooms.size("restaurant").y) or not Rooms.can_stand("restaurant",Vector2(c.x,c.y)):return {}
		if not _integer(c.direction,0,3) or not _integer(c.variant,0,4) or not _number(c.distance,0,10000):return {}
		seats.append(int(c.seat));ids.append(c.id)
	if not value.last is Dictionary:return {}
	if not value.last.is_empty():
		if value.last.size()!=4 or not _integer(value.last.get("day"),1,day) or not _integer(value.last.get("served"),0,6) or not _integer(value.last.get("missed"),0,6) or not _integer(value.last.get("revenue"),0,96):return {}
	if not value.deliveries is Dictionary or value.deliveries.size()>SUPPLIES.size():return {}
	for item:Variant in value.deliveries:
		if not item is String or not SUPPLIES.has(item) or not _integer(value.deliveries[item],1,day):return {}
	var result:Dictionary=value.duplicate(true)
	result.stock=Inventory.normalize(result.stock)
	for key:String in ["day","arrivals","served","missed","earnings"]:result[key]=int(result[key])
	for key:String in result.last:result.last[key]=int(result.last[key])
	for key:String in result.deliveries:result.deliveries[key]=int(result.deliveries[key])
	for customer:Dictionary in result.customers:
		for key:String in ["seat","direction","variant"]:customer[key]=int(customer[key])
	return result

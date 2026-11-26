extends Control
signal action_requested(verb:String,args:Dictionary)
const UI=preload("res://scripts/ui_style.gd")
const Shop=preload("res://scripts/restaurant.gd")
const Inventory=preload("res://scripts/inventory.gd")
const Art=preload("res://scripts/survival_art.gd")
var menu_buttons:Dictionary={}
var prepare_buttons:Array=[]
var collect_buttons:Array=[]
var station_labels:Array=[]
var status:Label
var result:Label
var opening:Button
var stock:Button
var result_message:=""
func _ready()->void:
	size=Vector2(1280,800);mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.size=size;shade.color=UI.SHADE;add_child(shade)
	UI.panel(self,Rect2(112,64,1056,672),"paper")
	UI.label(self,"潮间寿司",Rect2(146,88,700,44),30)
	UI.button(self,"×",Rect2(1092,88,40,40),hide)
	status=UI.label(self,"",Rect2(148,144,980,60),18)
	UI.label(self,"今晚菜单 · 点击上架或撤下",Rect2(148,209,950,28),19)
	for i in Shop.RECIPES.size():
		var recipe:String=Shop.RECIPES.keys()[i]
		var button:=UI.button(self,"",Rect2(148+i*326,247,310,48),func():action_requested.emit("shop_menu",{"recipe":recipe}))
		button.icon=Art.texture(recipe);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",32)
		menu_buttons[recipe]=button
	for index in 2:
		var station_index:=index
		var x:=148+index*500
		UI.panel(self,Rect2(x,319,480,266),"wood")
		station_labels.append(UI.label(self,"",Rect2(x+16,334,448,28),20))
		var row:Dictionary={}
		for i in Shop.RECIPES.size():
			var recipe:String=Shop.RECIPES.keys()[i]
			var caption:="%s · %s"%[Inventory.ITEM_NAMES[recipe],cost_text(recipe)]
			row[recipe]=UI.button(self,caption,Rect2(x+16,374+i*46,448,40),func():
				action_requested.emit("shop_prepare",{"station":station_index,"recipe":recipe}))
		prepare_buttons.append(row)
		collect_buttons.append(UI.button(self,"取餐",Rect2(x+16,524,448,42),func():action_requested.emit("shop_collect",{"station":station_index})))
	stock=UI.button(self,"打开备料柜",Rect2(148,603,240,44),func():hide();action_requested.emit("open_chest",{"id":Shop.STOCK_ID}))
	opening=UI.button(self,"",Rect2(864,603,264,44),func():action_requested.emit("shop_close" if opening.get_meta("open",false) else "shop_open",{}))
	result=UI.label(self,"",Rect2(148,660,980,50),16,UI.MUTED);result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hide()
static func cost_text(recipe:String)->String:
	var parts:Array[String]=[]
	for item:String in Shop.RECIPES[recipe].cost:parts.append("%s%d"%[Inventory.ITEM_NAMES[item],Shop.RECIPES[recipe].cost[item]])
	return "/".join(parts)
func present(data:Dictionary,slot:String)->void:
	result_message="";refresh(data,slot);show()
func refresh(data:Dictionary,slot:String)->void:
	var shop:Dictionary=data.restaurant
	var player:Dictionary=data.players[slot]
	var by_counter:=Shop.near(player,Shop.counter())
	status.text="营业中 · 已上菜%d份 / 等待%d桌 · 待结算%d金币"%[shop.served,shop.customers.filter(func(c:Dictionary):return c.phase=="wait").size(),shop.earnings] if shop.open else "白天备料 · 18:00—23:00挂牌营业 · 23:50自动打烊"
	if not shop.last.is_empty() and not shop.open:status.text+="\n上次营业：%d份 / 收入%d金币"%[shop.last.served,shop.last.revenue]
	for recipe:String in menu_buttons:
		menu_buttons[recipe].text=("✓ " if recipe in shop.menu else "")+Inventory.ITEM_NAMES[recipe]+" · %d金币"%Shop.RECIPES[recipe].price
		menu_buttons[recipe].disabled=not shop.rented or shop.open or not by_counter
	for i in 2:
		var work:Dictionary=shop.stations[i]
		var nearby:=Shop.near(player,Shop.station(i))
		station_labels[i].text="案板%d · %s"%[i+1,"空闲" if work.is_empty() else Inventory.ITEM_NAMES[work.recipe]+(" · %.1f秒"%work.remaining if work.remaining>0 else " · 可取餐")]
		for recipe:String in prepare_buttons[i]:
			var enough:=true
			for item:String in Shop.RECIPES[recipe].cost:
				if Inventory.count(shop.stock,item)<int(Shop.RECIPES[recipe].cost[item]):enough=false
			prepare_buttons[i][recipe].disabled=not shop.rented or not nearby or not work.is_empty() or not enough
			prepare_buttons[i][recipe].tooltip_text="从共享备料柜扣除食材，耗时%.0f秒；完成后亲手取餐。"%Shop.RECIPES[recipe].seconds if nearby else "先关闭面板，走近案板%d。"%(i+1)
		collect_buttons[i].disabled=not nearby or work.is_empty() or float(work.get("remaining",1))>0
	stock.disabled=not Shop.stock_access(data,player)
	opening.text="打烊并结算" if shop.open else "挂牌营业"
	opening.set_meta("open",shop.open)
	opening.disabled=not shop.rented or not by_counter or (not shop.open and (data.minute<1080 or data.minute>=1380 or (shop.day==data.day and shop.settled)))
	result.text=result_message if not result_message.is_empty() else "食材存进备料柜，料理取到背包，走近客人点击上菜。开始备餐或营业后会关闭面板，让时间继续。"

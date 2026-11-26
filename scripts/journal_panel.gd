extends Control
signal action_requested(verb:String,args:Dictionary)
const UI=preload("res://scripts/ui_style.gd")
const Journal=preload("res://scripts/journal.gd")
const Town=preload("res://scripts/island_town.gd")
const Inventory=preload("res://scripts/inventory.gd")
const PersonalStories=preload("res://scripts/resident_stories.gd")
const Rooms=preload("res://scripts/rooms.gd")
var content:RichTextLabel
var magic_buttons:Dictionary={}
func _ready()->void:
	size=Vector2(1280,800);mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.size=size;shade.color=UI.SHADE;add_child(shade)
	UI.panel(self,Rect2(205,65,870,670))
	UI.label(self,"海上的手记",Rect2(245,94,700,45),30)
	UI.button(self,"×",Rect2(990,93,42,42),hide)
	UI.label(self,"故事与委托都可自由选择，没有完成期限。双人委托各自接取。",Rect2(245,149,750,28),16,UI.MUTED)
	content=RichTextLabel.new();content.position=Vector2(245,200);content.size=Vector2(780,410)
	content.bbcode_enabled=true;content.add_theme_color_override("default_color",UI.INK)
	content.add_theme_font_size_override("normal_font_size",19);add_child(content)
	magic_buttons.breath=UI.button(self,"潮息 · 12体力",Rect2(245,631,220,40),func():action_requested.emit("spell",{"id":"breath"});hide())
	magic_buttons.rain=UI.button(self,"唤雨 · 20体力",Rect2(482,631,220,40),func():action_requested.emit("spell",{"id":"rain"});hide())
	UI.label(self,"J / Esc 合上手记 · 好感：每日聊天+2，料理礼物+10，委托+20",Rect2(245,690,760,25),15,UI.MUTED)
	hide()
func present(data:Dictionary,slot:String)->void:
	refresh(data,slot);show()
func refresh(data:Dictionary,slot:String)->void:
	var j:Dictionary=data.journal
	var p:Dictionary=j[slot]
	for id:String in magic_buttons:magic_buttons[id].disabled=not j.spells.get(id,false) or float(j.cooldown[slot])>0
	var text:="[b]航海故事 · 共享进度[/b]\n"
	var step:int=int(j.story_step)
	if step>=Journal.STORY.size():text+="旧灯已亮，潮声也有了含义。去寻找那些愿意交谈的海上伙伴吧。\n"
	else:
		var chapter:Dictionary=Journal.STORY[step]
		text+="[b]%s[/b]  ·  %s\n%s\n找%s，带上：%s\n"%[chapter.title,"已接取" if j.story_accepted else "可选择接取",chapter.text,Town.NPCS[chapter.npc].name,cost_text(chapter.cost)]
	text+="\n"+PersonalStories.summary(data,slot)+"\n[b]你的委托[/b]\n"
	if p.accepted.is_empty():text+="还没有接取委托。到村民身边打开右键菜单，想帮忙时再接。\n"
	for id:String in p.accepted:
		var q:Dictionary=Journal.REQUESTS[id]
		text+="• %s · %s\n%s\n  %s %d/%d · 奖励%d金币 / 好感+20\n"%[npc_name(id),q.title,q.text,Inventory.ITEM_NAMES[q.item],Inventory.count(data.players[slot].bag,q.item),q.count,q.coins]
	text+="\n[b]岛上的朋友[/b]\n"
	for id:String in Town.NPCS:
		var affinity:int=int(p.friendship.get(id,0))
		var place:=Town.location(id,float(data.minute),data)
		var whereabouts:String=Rooms.room_name(place.room) if place.area=="room" else "镇上路途中" if place.moving else "广场附近"
		text+="%s · %s   %s (%d) · 现于%s\n"%[Town.NPCS[id].name,Town.NPCS[id].role,"亲近" if affinity>=100 else "熟悉" if affinity>=40 else "相识" if affinity>0 else "尚未交谈",affinity,whereabouts]
	for id:String in Journal.OTHER_NAMES:
		if p.friendship.has(id):text+="%s · 好感%d\n"%[npc_name(id),int(p.friendship[id])]
	text+="\n[b]潮汐魔法[/b]\n"+("已能听懂潮声。与海洞里的澜影、风栖岛的苔露交谈，帮忙后可学习潮息和唤雨。" if j.tide_speech else "跟随温知的可选故事，学习理解潮声。")
	if float(j.cooldown[slot])>0:text+="\n还需等待%.0f秒。"%ceilf(j.cooldown[slot])
	if not p.completed.is_empty():
		text+="\n[b]已完成的委托[/b]\n"
		for id:String in p.completed:text+="%s · 第%d天完成（七天后可再帮忙）\n"%[Journal.REQUESTS[id].title,int(p.completed[id])]
	if content.text!=text:
		var scroll:=content.get_v_scroll_bar().value
		content.text=text
		content.get_v_scroll_bar().value=scroll
func npc_name(id:String)->String:
	return str(Town.NPCS[id].name) if Town.NPCS.has(id) else str(Journal.OTHER_NAMES.get(id,id))
func cost_text(cost:Dictionary)->String:
	var names:PackedStringArray=[]
	for item:String in cost:names.append("%s ×%d"%[Inventory.ITEM_NAMES[item],cost[item]])
	return "、".join(names)

extends Control
signal closed
signal sea_requested
const UI=preload("res://scripts/ui_style.gd")
const Rooms=preload("res://scripts/rooms.gd")
const Tiles=preload("res://scripts/island_tiles.gd")
const Ocean=preload("res://scripts/ocean_residents.gd")
const Town=preload("res://scripts/island_town.gd")
var canvas:Control
var title:Label
var note:Label
var details:Label
var floors:Array[Button]=[]
var _data:Dictionary={}
var _slot:="host"
var selected:=""
func _ready()->void:
	size=Vector2(1280,800)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.size=size;shade.color=UI.SHADE;add_child(shade)
	UI.panel(self,Rect2(92,70,1096,660),"paper")
	title=UI.label(self,"",Rect2(126,96,950,42),28)
	UI.button(self,"×",Rect2(1114,94,40,40),func():closed.emit())
	note=UI.label(self,"",Rect2(126,149,980,48),16,UI.MUTED)
	canvas=Control.new();canvas.position=Vector2(126,215);canvas.size=Vector2(740,445);canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;canvas.draw.connect(_draw_map);add_child(canvas)
	for i in 3:
		var floor_index:=i+1
		floors.append(UI.button(self,"第%d层" % floor_index,Rect2(906,230+i*58,232,42),func():selected=selected.get_slice("_",0)+"_"+str(floor_index);refresh(_data,_slot)))
	details=UI.label(self,"",Rect2(906,435,232,208),17)
	details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	UI.button(self,"海域图",Rect2(906,640,232,38),func():sea_requested.emit())
	UI.label(self,"金色：出入口　蓝绿：你　米白：伙伴　紫色：居民　地图只作查看，不会传送。",Rect2(126,679,980,30),15,UI.MUTED)
	hide()
func present(data:Dictionary,slot:String)->void:
	selected=str(data.players[slot].room)
	refresh(data,slot);show()
func refresh(data:Dictionary,slot:String)->void:
	_data=data;_slot=slot
	if selected.is_empty():return
	title.text=Rooms.room_name(selected)
	note.text="沿入口返回上一层。开采矿脉疏通深处，矿石带回熔炉可做金属锭。" if selected.begins_with("mine_") or selected.begins_with("sea_") else "房门与走道按实际室内绘制，桌柜和墙面不可穿越。"
	if selected.begins_with("sea_"):note.text+="\n每层入口的空气洞可以补氧；在深处停留仍会消耗氧气。"
	if selected.begins_with("island_"):note.text="金点是木筏的停泊入口，紫点是海上伙伴；资源需走近后用对应工具采集。地图不会传送。"
	for i in floors.size():
		floors[i].visible=selected.begins_with("mine_") or selected.begins_with("sea_")
		var id:=selected.get_slice("_",0)+"_"+str(i+1)
		floors[i].disabled=not data.rooms.visited.has(id)
		floors[i].text="第%d层%s" % [i+1," · 尚未探索" if floors[i].disabled else " · 当前查看" if id==selected else ""]
	details.text=""
	for key in data.players:
		var player:Dictionary=data.players[key]
		if player.online:details.text+=str(player.name)+"：\n"+(Rooms.room_name(player.room) if player.area=="room" else {"deck":"甲板","water":"开放海域","island":"岛上"}.get(player.area,""))+"\n\n"
	canvas.queue_redraw()
func _draw_map()->void:
	if selected.is_empty():return
	var extent:=Rooms.size(selected)
	var scale_value:=minf(740/extent.x,445/extent.y)
	var offset:Vector2=(canvas.size-extent*scale_value)/2
	canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color("364d4e"))
	if selected.begins_with("sea_"):
		var path:=PackedVector2Array()
		for x in range(0,901,8):path.append(offset+Vector2(x,Rooms.ceiling(x,Rooms.floor_number(selected)))*scale_value)
		for x in range(900,-1,-8):path.append(offset+Vector2(x,Rooms.seabed(x,Rooms.floor_number(selected)))*scale_value)
		canvas.draw_colored_polygon(path,Color("639297"))
	else:
		Tiles.draw_patch(canvas,Rooms.source(selected),Rect2i(Vector2i.ZERO,Vector2i(extent/32)),offset,scale_value*2,int(_data.day))
	for point in [Rooms.entry(selected),Rooms.onward(selected)] if floors[0].visible else [Rooms.entry(selected)]:
		canvas.draw_circle(offset+Vector2(point)*scale_value,6,Color("e6bd74"))
	for node:Dictionary in Rooms.nodes(selected).values():
		if Rooms.active(_data,node):canvas.draw_circle(offset+Vector2(node.x,node.y)*scale_value,3,Color("b0bcc2"))
	for id:String in Ocean.NPCS:
		if Ocean.NPCS[id].room==selected:
			var at:=offset+Ocean.position(id)*scale_value
			canvas.draw_circle(at,5,Color("b593c9"))
			canvas.draw_string(ThemeDB.fallback_font,at+Vector2(7,-5),str(Ocean.NPCS[id].name),HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PAPER)
	for id:String in Town.NPCS:
		var place:=Town.location(id,float(_data.minute),_data)
		if place.area=="room" and place.room==selected:
			var at:Vector2=offset+Vector2(place.at)*scale_value
			canvas.draw_circle(at,4,Color("825d8f"))
			canvas.draw_string(get_theme_default_font(),at+Vector2(7,-5),str(Town.NPCS[id].name),HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.INK)
	for prop:Dictionary in _data.housing.furniture:
		if prop.room==selected:canvas.draw_rect(Rect2(offset+Vector2(prop.x-16,prop.y-16)*scale_value,Vector2(32,32)*scale_value),Color("b18c60"))
	for key in _data.players:
		var player:Dictionary=_data.players[key]
		if player.online and player.area=="room" and player.room==selected:
			canvas.draw_circle(offset+Vector2(player.x,player.y)*scale_value,5,Color("8fd8bd") if key==_slot else Color("faf1d5"))

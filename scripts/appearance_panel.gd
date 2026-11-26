extends Control
signal chosen(profile:Dictionary)
const UI=preload("res://scripts/ui_style.gd")
const Appearance=preload("res://scripts/appearance.gd")
const Player=preload("res://scripts/player_art.gd")
const Portraits=preload("res://scripts/portrait_art.gd")
var profile:Dictionary={}
var labels:Array[Label]=[]
var portraits:Array[TextureRect]=[]
var bust_portrait:TextureRect
var phase:=0.0
const NAMES:=["体型","发型","发色","上衣","裤色","肤色"]

func _ready()->void:
	size=Vector2(1280,800)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.color=UI.SHADE;shade.size=size;add_child(shade)
	UI.panel(self,Rect2(260,110,760,580))
	UI.label(self,"你的模样 · 海港行装",Rect2(300,140,600,42),30)
	UI.label(self,"近代海港劳动衣衫，随时可在菜单换装，衣着不会影响能力。",Rect2(300,187,660,28),17,UI.MUTED)
	UI.icon(self,UI.atlas("cursors",Rect2(583,411,115,97)),Rect2(345,224,184,155))
	bust_portrait=UI.icon(self,null,Rect2(386,238,102,102))
	var scroll_tag:=UI.label(self,"海港旅人",Rect2(355,342,164,28),15,UI.INK)
	scroll_tag.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	scroll_tag.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	UI.label(self,"四向行走预览",Rect2(314,386,260,26),17,UI.ACCENT)
	UI.label(self,"右侧箭头自由搭配；确认后只更改本人，\n双人可各自选择。",Rect2(302,520,285,54),15,UI.MUTED)
	for i in 4:
		var portrait:=TextureRect.new();portrait.position=Vector2(308+i*62,414);portrait.size=Vector2(48,96)
		portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(portrait);portraits.append(portrait)
	for i in Appearance.KEYS.size():
		var y:=233+i*53
		labels.append(UI.label(self,"",Rect2(610,y,245,36),19))
		UI.button(self,"‹",Rect2(850,y,48,37),func():_cycle(i,-1))
		UI.button(self,"›",Rect2(913,y,48,37),func():_cycle(i,1))
	UI.button(self,"取消",Rect2(610,610,140,45),hide)
	UI.button(self,"就这样出发",Rect2(772,610,190,45),func():chosen.emit(profile.duplicate());hide(),true)
	hide()

func present(value:Dictionary)->void:
	profile=value.duplicate();_refresh();show()

func _cycle(index:int,step:int)->void:
	var key:String=Appearance.KEYS[index]
	profile[key]=posmod(int(profile[key])+step,Appearance.LIMITS[index]);_refresh()

func _refresh()->void:
	Player.configure("preview",profile)
	if bust_portrait!=null:bust_portrait.texture=Portraits.player_texture(profile)
	for i in labels.size():labels[i].text="%s   %d / %d"%[NAMES[i],int(profile[Appearance.KEYS[i]])+1,Appearance.LIMITS[i]]
	_update_portraits()

func _process(delta:float)->void:
	if not visible:return
	phase+=delta
	_update_portraits()

func _update_portraits()->void:
	for i in portraits.size():portraits[i].texture=Player.texture("preview",i,int(phase*6)%4)

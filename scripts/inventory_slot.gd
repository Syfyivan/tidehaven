extends Button

const Art = preload("res://scripts/art_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const UI = preload("res://scripts/ui_style.gd")
const ITEM_HELP := {
	"fiber": ["制作绳子与暖棚的植物纤维。", "岛上用镰刀割取杂草"],
	"hoe": ["岛上按5开垦一格；点击埋藏痕迹可挖掘。", "手工制作：木板、石料、绳"],
	"scythe": ["随身携带后点击杂草割纤维，也能清理枯苗。", "手工制作：木板、废金属、绳"],
	"watering_can": ["按7浇一格，容量20；淡水池边P补水。", "手工制作：塑料、废金属"],
	"canopy": ["岛上按8给一格搭暖棚；可跨季，仍需每天浇水。", "手工制作：木板、纤维、塑料"],
	"summer_seed": ["玉米：夏秋可种，浇水过夜7天成熟。", "岛上挖掘埋藏种子"],
	"autumn_seed": ["南瓜：秋季可种，浇水过夜10天成熟。", "岛上挖掘埋藏种子"],
	"winter_seed": ["雪根：冬季可种，浇水过夜6天成熟。", "岛上挖掘埋藏种子"],
	"wood": ["建造甲板和设施，也可用作燃料。", "海面打捞、漂流桶或水下采集"],
	"leaf": ["拧成绳子，也可铺成叶子床。", "海面打捞、漂流桶"],
	"plastic": ["制作杯子、净水器和木筏地板。", "海面打捞、漂流桶"],
	"scrap": ["制作罗盘、鱼叉、烤架和熔炉。", "海面打捞、漂流桶"],
	"rope": ["用于工具、床与多数甲板设施。", "手工制作：棕榈叶 ×2"],
	"cup": ["在甲板边舀海水；喝完淡水后可再用。", "手工制作：塑料 ×2"],
	"saltwater": ["交给净水器处理，不能直接饮用。", "带空杯走到甲板边舀水"],
	"freshwater": ["补充饮水值，喝完会留下空杯。", "净水器：一杯海水 + 木板"],
	"fish": ["在烤架上烤熟，或用来做料理。", "钓鱼，或在水下用鱼叉捕捉"],
	"cooked_fish": ["直接食用，补充饱食度和体力。", "烤架：鱼 + 木板"],
	"veg": ["搭配鱼肉，在烤架制作料理。", "种植箱播种、浇水后收获"],
	"meal": ["直接食用，补充饱食度和体力。", "烤架：鱼 + 蔬菜"],
	"seed": ["春季露天种植；浇水生长4天。也可放进筏上种植箱。", "漂流桶、物资宝箱或收获作物"],
	"treasure": ["在背包中打开，取出里面的物资。", "钓鱼偶得、水下搜索沉箱"],
	"rod": ["随身携带，走到甲板边即可钓鱼。", "制作手册：木板 + 绳子"],
	"stone": ["制作石斧、石镐，也可搭建熔炉。", "水下采集浅色石堆"],
	"ore": ["在熔炉中加入木板，炼成金属锭。", "水下采集矿石"],
	"ingot": ["用于脚蹼和强化打捞钩等装备。", "熔炉：矿石 + 木板"],
	"fins": ["随身携带：游泳速度 +30%，不叠加。", "制作手册 · 探索与升级"],
	"reinforced_hook": ["随身携带：钩得更远、收钩更快。", "制作手册 · 探索与升级"],
	"paddle": ["按 3 选船桨，点击海面划向目标方向。", "手工制作：木板、塑料、绳子"],
	"anchor": ["在甲板按 G 抛锚或收锚；下潜前须停船。", "手工制作：木板、废金属、绳子"],
	"harpoon": ["水下按 4 选鱼叉，朝游鱼发射；命中才收获。", "手工制作：木板 ×3、废金属 ×2、绳子 ×1"],
	"axe": ["岛上砍树和枯枝必需；也能加快水下采木。", "手工制作：木板 ×3、石料 ×2、绳子 ×1"],
	"pickaxe": ["岛上采石和矿石必需；也能加快水下开采。", "手工制作：木板 ×3、石料 ×3、绳子 ×1"],
	"compass": ["随身携带：M 查看完整海图，并可设置航标。", "手工制作：废金属 ×3、塑料 ×2、绳子 ×1"],
}
var stack: Dictionary = {}
var selected := false
var caption: Label
var item_icon: TextureRect
var count_background: Panel

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item_icon = UI.icon(self, null, Rect2(12, 8, 48, 48))
	count_background = UI.panel(self, Rect2(39, 48, 27, 20), "paper")
	var count_style := UI.box("paper")
	count_style.set_border_width_all(0)
	count_style.shadow_size = 0
	count_style.bg_color = Color(UI.PAPER, 0.94)
	count_background.add_theme_stylebox_override("panel", count_style)
	count_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption = UI.label(count_background, "", Rect2(1, -1, 25, 22), 16)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_appearance()

func show_stack(value: Dictionary, is_selected: bool) -> void:
	stack = value
	selected = is_selected
	_update_appearance()

func _update_appearance() -> void:
	add_theme_stylebox_override("normal", UI.box("slot_selected" if selected else "slot"))
	add_theme_stylebox_override("hover", UI.box("slot_selected" if selected else "slot_hover"))
	add_theme_stylebox_override("pressed", UI.box("slot_selected"))
	add_theme_stylebox_override("disabled", UI.box("slot"))
	if not is_instance_valid(caption):
		return
	var item: String = str(stack.get("item", ""))
	item_icon.texture = Art.item_icon(item) if not stack.is_empty() else null
	item_icon.visible = not stack.is_empty()
	count_background.visible = not stack.is_empty()
	caption.text = str(stack.count) if not stack.is_empty() else ""
	tooltip_text = "%s ×%d\n%s\n来源：%s\n左键整堆 · 右键拆分" % [Inventory.ITEM_NAMES.get(item, item), int(stack.count), item_usage(item), item_source(item)] if not stack.is_empty() else ""

static func item_usage(item: String) -> String:
	return str(ITEM_HELP.get(item, ["可用于制作或甲板生活。", "探索海面和水下"])[0])

static func item_source(item: String) -> String:
	return str(ITEM_HELP.get(item, ["可用于制作或甲板生活。", "探索海面和水下"])[1])

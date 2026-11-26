extends RefCounted

const Inventory = preload("res://scripts/inventory.gd")

const WORKBENCH_DISTANCE := 64.0
const WORKBENCH_RECIPES := ["furnace", "fins", "reinforced_hook", "canopy","cabin"]

const ALL := {
	"workbench": {"id": "workbench", "name": "工作台", "description": "搭在甲板上，靠近后制作熔炉、脚蹼、强化钩和暖棚；双方可共用。", "category": "buildings", "costs": {"wood": 6, "scrap": 2, "rope": 2}, "result": "workbench", "amount": 1, "structure": "workbench"},
	"paddle": {"id": "paddle", "name": "船桨", "description": "点选背包中的船桨，再点击海面方向划桨；每划消耗 2 体力。", "category": "tools", "costs": {"wood": 3, "plastic": 2, "rope": 1}, "result": "paddle", "amount": 1, "structure": ""},
	"anchor": {"id": "anchor", "name": "简易锚", "description": "按 G 抛锚停船，再按 G 收回；下潜前先抛锚。可反复使用。", "category": "tools", "costs": {"wood": 3, "scrap": 2, "rope": 1}, "result": "anchor", "amount": 1, "structure": ""},
	"rope": {"id": "rope", "name": "绳子", "description": "把两片棕榈叶拧成绳子。", "category": "tools", "costs": {"leaf": 2}, "result": "rope", "amount": 1, "structure": ""},
	"fiber_rope": {"id": "fiber_rope", "name": "纤维绳", "description": "把两份岛上植物纤维搓成一根绳子。", "category": "tools", "costs": {"fiber": 2}, "result": "rope", "amount": 1, "structure": ""},
	"hoe": {"id": "hoe", "name": "锄头", "description": "在岛上清理后的草地开垦一格耕地，也能挖掘埋藏物。", "category": "tools", "costs": {"wood": 3, "stone": 2, "rope": 1}, "result": "hoe", "amount": 1, "structure": ""},
	"scythe": {"id": "scythe", "name": "镰刀", "description": "割取岛上纤维，清理换季枯萎的作物。", "category": "tools", "costs": {"wood": 2, "scrap": 2, "rope": 1}, "result": "scythe", "amount": 1, "structure": ""},
	"watering_can": {"id": "watering_can", "name": "浇水壶", "description": "到岛上淡水池装满，可浇20格地；作物只有浇过水才能隔夜生长。", "category": "tools", "costs": {"plastic": 4, "scrap": 2}, "result": "watering_can", "amount": 1, "structure": ""},
	"canopy": {"id": "canopy", "name": "暖棚套件", "description": "保护一格耕地，让作物跨季存活和种植；仍需浇水。", "category": "tools", "costs": {"wood": 6, "fiber": 4, "plastic": 4}, "result": "canopy", "amount": 1, "structure": ""},
	"cup": {"id": "cup", "name": "杯子", "description": "在甲板边舀水；喝完淡水会留下空杯。", "category": "tools", "costs": {"plastic": 2}, "result": "cup", "amount": 1, "structure": ""},
	"rod": {"id": "rod", "name": "钓竿", "description": "带在背包里，走到甲板边就能钓鱼。", "category": "tools", "costs": {"wood": 2, "rope": 2}, "result": "rod", "amount": 1, "structure": ""},
	"purifier": {"id": "purifier", "name": "简易净水器", "description": "一杯海水和一块木板，12 秒得到淡水。", "category": "buildings", "costs": {"wood": 4, "plastic": 2, "rope": 1}, "result": "purifier", "amount": 1, "structure": "purifier"},
	"grill": {"id": "grill", "name": "烤架", "description": "一条鱼和一块木板，10 秒做好烤鱼。", "category": "buildings", "costs": {"wood": 4, "scrap": 2, "rope": 1}, "result": "grill", "amount": 1, "structure": "grill"},
	"chest": {"id": "chest", "name": "储物木箱", "description": "16 格共享空间，每格最多 999 件。", "category": "buildings", "costs": {"wood": 4, "rope": 1}, "result": "chest", "amount": 1, "structure": "chest"},
	"garden": {"id": "garden", "name": "种植箱", "description": "每个盆独立种植一株，水壶浇水后按天生长；受季节影响，可搭暖棚。", "category": "buildings", "costs": {"wood": 4, "rope": 2}, "result": "garden", "amount": 1, "structure": "garden"},
	"bed": {"id": "bed", "name": "叶子床", "description": "休息恢复体力；全体准备后才结束今天。", "category": "buildings", "costs": {"leaf": 4, "rope": 2}, "result": "bed", "amount": 1, "structure": "bed"},
	"foundation": {"id": "foundation", "name": "木筏地板", "description": "接在已有甲板旁，逐格扩大海上家园。", "category": "buildings", "costs": {"wood": 2, "plastic": 2}, "result": "foundation", "amount": 1, "structure": "foundation"},
	"harpoon": {"id": "harpoon", "name": "鱼叉", "description": "水下选持后朝鼠标方向出手；命中游鱼可捕鱼，命中鲨鱼或海鳗可暂时击退。", "category": "exploration", "costs": {"wood": 3, "scrap": 2, "rope": 1}, "result": "harpoon", "amount": 1, "structure": ""},
	"axe": {"id": "axe", "name": "石斧", "description": "岛上砍树和枯枝需要石斧；也能加快水下采木。", "category": "exploration", "costs": {"wood": 3, "stone": 2, "rope": 1}, "result": "axe", "amount": 1, "structure": ""},
	"pickaxe": {"id": "pickaxe", "name": "石镐", "description": "岛上采石矿需要石镐；也能加快水下开采。", "category": "exploration", "costs": {"wood": 3, "stone": 3, "rope": 1}, "result": "pickaxe", "amount": 1, "structure": ""},
	"compass": {"id": "compass", "name": "罗盘", "description": "随身携带可查看完整群岛海图、设置航标；没有罗盘时只能看附近海域。", "category": "exploration", "costs": {"scrap": 3, "plastic": 2, "rope": 1}, "result": "compass", "amount": 1, "structure": ""},
	"furnace": {"id": "furnace", "name": "熔炉", "description": "一份矿石和一块木板，15 秒炼出金属锭。", "category": "exploration", "costs": {"stone": 6, "scrap": 2, "wood": 4}, "result": "furnace", "amount": 1, "structure": "furnace"},
	"fins": {"id": "fins", "name": "脚蹼", "description": "放在自己的背包里，游泳速度提高 30%；多双不叠加。", "category": "exploration", "costs": {"ingot": 2, "plastic": 4, "rope": 1}, "result": "fins", "amount": 1, "structure": ""},
	"reinforced_hook": {"id": "reinforced_hook", "name": "强化打捞钩", "description": "随身携带后，能钩到更远的漂流物，收钩也更快。", "category": "exploration", "costs": {"ingot": 2, "rope": 2}, "result": "reinforced_hook", "amount": 1, "structure": ""},
	"cabin":{"id":"cabin","name":"船屋套件","description":"四格宽、两格深，门前留一格甲板。可入住、布置家具，再邀请木匠作伴。","category":"exploration","costs":{"wood":60,"fiber":20,"rope":12,"ingot":4},"result":"cabin","amount":1,"structure":"cabin"},
}


static func get_all() -> Array:
	return ALL.values().duplicate(true)


static func nearby_workbench(data: Dictionary, slot: String) -> String:
	var player: Dictionary = data.get("players", {}).get(slot, {})
	if player.get("online",false) and player.get("area")=="room":
		for prop:Dictionary in data.housing.furniture:
			if prop.item=="workbench" and prop.room==player.room and Vector2(player.x,player.y).distance_to(Vector2(prop.x,prop.y))<=WORKBENCH_DISTANCE:return prop.id
	if not bool(player.get("online", false)) or player.get("area") != "deck":
		return ""
	var nearest := ""
	var distance := WORKBENCH_DISTANCE
	var at := Vector2(float(player.x), float(player.y))
	for id in data.get("structures", {}):
		var structure: Dictionary = data.structures[id]
		if structure.kind != "workbench":
			continue
		var gap := at.distance_to(Vector2(float(structure.x), float(structure.y)))
		if gap <= distance:
			distance = gap
			nearest = str(id)
	return nearest


static func station_available(data: Dictionary, slot: String, recipe: String) -> bool:
	return recipe not in WORKBENCH_RECIPES or not nearby_workbench(data, slot).is_empty()


static func output_fits(bag: Array, recipe_id: String) -> bool:
	var recipe: Dictionary = ALL[recipe_id]
	# Match host exchange: consume personal ingredients before using chest stock.
	# A currently full bag can still fit the result if crafting frees a slot.
	var after := bag.duplicate(true)
	for item in recipe.costs:
		Inventory.remove(after, item, mini(int(recipe.costs[item]), Inventory.count(after, item)))
	return Inventory.add(after, recipe.result, int(recipe.amount)) == 0

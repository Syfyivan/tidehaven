extends RefCounted

const BAG_SIZE := 12
const CHEST_SIZE := 16
const STACK_LIMIT := 20
const ITEMS := ["fish", "wood", "veg", "meal", "seed", "treasure", "leaf", "plastic", "scrap", "rope", "cup", "saltwater", "freshwater", "cooked_fish", "rod", "stone", "ore", "ingot", "fins", "reinforced_hook", "paddle", "anchor", "harpoon", "axe", "pickaxe", "compass", "fiber", "hoe", "scythe", "watering_can", "canopy", "summer_seed", "autumn_seed", "winter_seed"]
const ITEM_NAMES := {"fish": "鱼", "wood": "木板", "veg": "蔬菜", "meal": "料理", "seed": "春萝卜种子", "treasure": "物资宝箱", "leaf": "棕榈叶", "plastic": "塑料", "scrap": "废金属", "rope": "绳子", "cup": "空杯", "saltwater": "一杯海水", "freshwater": "一杯淡水", "cooked_fish": "烤鱼", "rod": "钓竿", "stone": "石料", "ore": "金属矿石", "ingot": "金属锭", "fins": "脚蹼", "reinforced_hook": "强化打捞钩", "paddle": "船桨", "anchor": "简易锚", "harpoon": "鱼叉", "axe": "石斧", "pickaxe": "石镐", "compass": "罗盘", "fiber": "植物纤维", "hoe": "锄头", "scythe": "镰刀", "watering_can": "浇水壶", "canopy": "暖棚套件", "summer_seed": "玉米种子", "autumn_seed": "南瓜种子", "winter_seed": "雪根种子"}


static func empty_slots(size: int) -> Array:
	var slots: Array = []
	for index in maxi(0, size):
		slots.append({})
	return slots


static func count(slots: Array, item: String) -> int:
	var amount := 0
	for slot in slots:
		if not slot.is_empty() and slot.item == item:
			amount += int(slot.count)
	return amount


static func totals(slots: Array) -> Dictionary:
	var result: Dictionary = {}
	for item in ITEMS:
		result[item] = count(slots, item)
	return result


static func used(slots: Array) -> int:
	var result := 0
	for slot in slots:
		if not slot.is_empty():
			result += 1
	return result


static func total_count(slots: Array) -> int:
	var result := 0
	for slot in slots:
		if not slot.is_empty():
			result += int(slot.count)
	return result


static func add(slots: Array, item: String, amount: int) -> int:
	if amount <= 0 or item not in ITEMS:
		return amount
	var remaining := amount
	for slot in slots:
		if not slot.is_empty() and slot.item == item:
			var moved := mini(remaining, STACK_LIMIT - int(slot.count))
			slot.count += moved
			remaining -= moved
			if remaining == 0:
				return 0
	for index in slots.size():
		if slots[index].is_empty():
			var moved := mini(remaining, STACK_LIMIT)
			slots[index] = {"item": item, "count": moved}
			remaining -= moved
			if remaining == 0:
				return 0
	return remaining


static func remove(slots: Array, item: String, amount: int) -> bool:
	if amount < 0 or item not in ITEMS or count(slots, item) < amount:
		return false
	var remaining := amount
	for index in slots.size():
		var slot: Dictionary = slots[index]
		if not slot.is_empty() and slot.item == item:
			var removed := mini(remaining, int(slot.count))
			slot.count -= removed
			remaining -= removed
			if int(slot.count) == 0:
				slots[index] = {}
			if remaining == 0:
				return true
	return remaining == 0


static func move(source: Array, source_index: int, target: Array, target_index: int, amount: int = 0) -> bool:
	if source_index < 0 or source_index >= source.size() or target_index < 0 or target_index >= target.size() or amount < 0:
		return false
	if is_same(source, target) and source_index == target_index:
		return false
	var from: Dictionary = source[source_index]
	var to: Dictionary = target[target_index]
	if from.is_empty():
		return false
	var moved := int(from.count) if amount == 0 else amount
	if moved > int(from.count):
		return false
	if not to.is_empty() and to.item != from.item:
		if moved != int(from.count):
			return false
		source[source_index] = to.duplicate()
		target[target_index] = from.duplicate()
		return true
	if not to.is_empty() and int(to.count) + moved > STACK_LIMIT:
		return false
	if to.is_empty():
		target[target_index] = {"item": from.item, "count": moved}
	else:
		to.count += moved
	from.count -= moved
	if int(from.count) == 0:
		source[source_index] = {}
	return true


static func sort_slots(slots: Array) -> void:
	var contents := totals(slots)
	for index in slots.size():
		slots[index] = {}
	for item in ITEMS:
		add(slots, item, int(contents[item]))


static func validate_slots(value: Variant, size: int) -> bool:
	if not value is Array or value.size() != size:
		return false
	for slot in value:
		if not slot is Dictionary:
			return false
		if slot.is_empty():
			continue
		if slot.size() != 2 or not slot.get("item") is String or slot.item not in ITEMS:
			return false
		var amount: Variant = slot.get("count")
		if typeof(amount) != TYPE_INT and typeof(amount) != TYPE_FLOAT:
			return false
		if not is_finite(float(amount)) or float(amount) != floorf(float(amount)) or float(amount) < 1.0 or float(amount) > STACK_LIMIT:
			return false
	return true


static func normalize(slots: Array) -> Array:
	var result := empty_slots(slots.size())
	for index in slots.size():
		if not slots[index].is_empty():
			result[index] = {"item": str(slots[index].item), "count": int(slots[index].count)}
	return result

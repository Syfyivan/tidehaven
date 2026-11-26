extends RefCounted
## Compact, validated choices shared by menu, host and save reader.
## P2-08a: maps existing 2x8x6x8x4x6 indices to Chinese harbor hairstyles, frog-button tops & cloth trousers.
const HAIR := [0,1,2,3,4,5,6,7]
const SHIRTS := [0,1,2,3,4,5,6,7]
const HAIR_COLORS := [Color("232730"),Color("3b2f2c"),Color("2d2524"),Color("694934"),Color("a7acb2"),Color("52383b")]
const PANTS_COLORS := [Color("304563"),Color("4c443f"),Color("395752"),Color("3d414b")]
const SKINS := [3,0,7,14,18,21]
const KEYS := ["body","hair","hair_color","shirt","pants","skin"]
const LIMITS := [2,8,6,8,4,6]

static func default_for(slot:String)->Dictionary:
	return {"body":1 if slot=="guest" else 0,"hair":6 if slot=="guest" else 0,"hair_color":2 if slot=="guest" else 0,"shirt":1 if slot=="guest" else 0,"pants":1 if slot=="guest" else 0,"skin":0}

static func restore(value:Variant)->Dictionary:
	if not value is Dictionary or value.size()!=KEYS.size() or not value.has_all(KEYS):return {}
	var result:Dictionary={}
	for i in KEYS.size():
		var number:Variant=value[KEYS[i]]
		if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)) or float(number)!=floorf(float(number)) or number<0 or number>=LIMITS[i]:return {}
		result[KEYS[i]]=int(number)
	return result

static func create()->Dictionary:
	return {"host":default_for("host"),"guest":default_for("guest")}

static func restore_pair(value:Variant)->Dictionary:
	if not value is Dictionary or value.size()!=2 or not value.has_all(["host","guest"]):return {}
	var result:Dictionary={}
	for slot:String in ["host","guest"]:
		result[slot]=restore(value[slot])
		if result[slot].is_empty():return {}
	return result

static func art(value:Dictionary)->Dictionary:
	return {"body":value.body,"hair":HAIR[value.hair],"hair_color":HAIR_COLORS[value.hair_color],"shirt":SHIRTS[value.shirt],"pants_color":PANTS_COLORS[value.pants],"skin":SKINS[value.skin],"shoes":12}

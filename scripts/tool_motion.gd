extends RefCounted
## Derived only from authoritative activity time; no local reward clock.
const PHASE_ENDS=[0.20,0.30,0.40,0.72,1.0]
const STRIKE=0.40
const CONTACT_END=0.52
const LAST_CONTACT=0.12
# Native tool contact relative to the fixed player foot, in world pixels.
# Kept alongside the stance contract; the visual adapter verifies these anchors.
const BLADE_OFFSETS=[Vector2(0,0),Vector2(-35,-16),Vector2(33,-16),Vector2(-1,-48)]
const TRUNK_CONTACTS=[Vector2(0,-24),Vector2(9,-16),Vector2(-11,-16),Vector2(-1,-16)]
static func contact(target:Vector2,direction:int,kind:String="tree")->Vector2:
	return target+(TRUNK_CONTACTS[direction] if kind=="tree" else Vector2.ZERO)
static func stance(target:Vector2,direction:int,kind:String="tree")->Vector2:
	return contact(target,direction,kind)-BLADE_OFFSETS[direction]
static func facing(at:Vector2,target:Vector2)->int:
	var delta:=target-at
	return (2 if delta.x>0 else 1) if absf(delta.x)>absf(delta.y) else (0 if delta.y>0 else 3)
static func sample(activity:Dictionary,at:Vector2,target:Vector2,kind:String="tree")->Dictionary:
	var duration:=maxf(float(activity.get("duration",0.8)),0.01)
	var cycles:=maxi(1,roundi(duration/0.8))
	var elapsed:=clampf(duration-float(activity.get("remaining",duration)),0,duration)
	var last_contact:=minf(LAST_CONTACT,duration*0.2)
	var period:=(duration-last_contact)/(cycles-1+STRIKE)
	var phase:=fposmod(elapsed/period,1.0)
	var final_hit:=elapsed>=duration-last_contact
	if final_hit:phase=STRIKE
	var frame:=4
	for i in PHASE_ENDS.size():
		if phase<float(PHASE_ENDS[i]):frame=i;break
	var direction:=facing(at,target)
	if kind!="tree":
		var distance:=INF
		for candidate in 4:
			var next:=at.distance_squared_to(stance(target,candidate,kind))
			if next<distance:distance=next;direction=candidate
	var chip_age:=clampf((elapsed-duration+last_contact)/last_contact,0,1) if final_hit else clampf((phase-STRIKE)/(CONTACT_END-STRIKE),0,1)
	return {"frame":frame,"direction":direction,"phase":phase,"impact":not activity.get("approach",false) and phase>=STRIKE and phase<CONTACT_END,"chip_age":chip_age,"final_hit":final_hit}

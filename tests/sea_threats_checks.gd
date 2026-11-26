extends SceneTree
const World = preload("res://scripts/world_state.gd")
const Threats = preload("res://scripts/sea_threats.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Actions = preload("res://scripts/underwater_actions.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_test_safe_and_detection()
	_test_attack_and_dodge()
	_test_spear_and_rescue()
	_test_save_and_invalid()
	print("SEA THREATS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL ", message)
func world():
	var w = World.new(); w.join("host", "船长"); w.join("guest", "伙伴")
	w.data.navigation.anchored = true
	return w
func swim(w, slot: String, at: Vector2) -> Dictionary:
	var p: Dictionary = w.data.players[slot]
	p.area = "water"; p.x = at.x; p.y = at.y; p.dive_status = Threats.player_state()
	return p
func step(w, seconds: float) -> void:
	for i in ceili(seconds / 0.02): w.tick(0.02)
func aim_enemy(w, kind: String, at: Vector2, phase := "windup") -> Dictionary:
	var e: Dictionary = w.data.threats[kind]
	e.x = at.x; e.y = at.y; e.dx = -1.0; e.dy = 0.0
	e.phase = phase; e.remaining = Threats.DEFINITIONS[kind].windup; e.target = "host"
	return e
func _test_safe_and_detection() -> void:
	var w = world()
	var p := swim(w, "host", Vector2(120,100))
	step(w, 18)
	check(p.stamina == 100 and w.data.threats.shark.target == "", "buoy remains safe without repeated dive grace")
	p.x = 600; p.y = 100
	step(w, 5)
	check(p.stamina == 100, "shallow water is safe along its width")
	p.x = 560; p.y = 265; p.dive_status.grace = 8
	step(w, 7)
	check(w.data.threats.shark.phase == "patrol", "new diver grace excludes targeting")
	step(w, 2)
	check(w.data.threats.shark.target == "host", "deep diver is discovered after grace")
	p.area = "deck"; step(w, 0.1)
	check(w.data.threats.shark.target == "" and p.stamina == 100, "surfacing cancels targeted attack")
	p = swim(w,"host",Vector2(610,450)); step(w,0.1)
	check(w.data.threats.moray.target == "host", "moray guards deep resources")
	p.x=410; step(w,0.1)
	check(w.data.threats.moray.target == "", "moray leash lets swimmer escape its territory")
	p.online=false;step(w,3)
	check(w.data.threats.shark.target == "", "offline players cannot be chased")
func _test_attack_and_dodge() -> void:
	for kind in ["shark","moray"]:
		var w=world()
		var p:=swim(w,"host",Vector2(580,400 if kind=="moray" else 265))
		var e:=aim_enemy(w,kind,Vector2(680,p.y))
		w.data.threats["moray" if kind=="shark" else "shark"].phase="repelled"
		w.data.threats["moray" if kind=="shark" else "shark"].remaining=18.0
		step(w,0.85)
		check(p.stamina==100 and e.phase=="windup", kind+" does not damage during full telegraph")
		p.y-=90
		step(w,1.2)
		check(p.stamina==100,kind+" sideways swim evades the locked direction")
		check(e.phase=="recover",kind+" has a vulnerable recovery after missing")
		p.x=580;p.y=400 if kind=="moray" else 265
		e=aim_enemy(w,kind,Vector2(680,p.y))
		p.activity={"kind":"gather","id":"ore_00","duration":16.0,"remaining":16.0,"start_x":p.x,"start_y":p.y}
		w.data.entities.ore_00.x=p.x;w.data.entities.ore_00.y=p.y
		var before:Array=p.bag.duplicate(true)
		step(w,1.55)
		check(p.stamina==100-float(Threats.DEFINITIONS[kind].damage),kind+" applies one hit per charge")
		check(p.activity.is_empty() and w.data.entities.ore_00.active and p.bag==before,kind+" hit interrupts gathering without granting or consuming resource")
		check(p.dive_status.hurt>0,kind+" grants short hurt protection")
		var stamina:float=p.stamina
		e=aim_enemy(w,kind,Vector2(p.x+40,p.y),"charge");e.remaining=0.2
		step(w,0.2)
		check(p.stamina==stamina,kind+" overlapping charge cannot hit again inside protection")
	check(Threats.segment_hit(Vector2(0,0),Vector2(1000,0),Vector2(500,0),20)>0,"swept collision catches a large step")
	check(Threats.segment_hit(Vector2(0,0),Vector2(1000,0),Vector2(500,21),20)<0,"swept collision rejects near miss")
	var w=world();var p:=swim(w,"host",Vector2(580,265));var guest:=swim(w,"guest",Vector2(580,265))
	aim_enemy(w,"shark",Vector2(680,265));step(w,1.6)
	check((100-p.stamina)+(100-guest.stamina)==25,"one charge cannot award two overlapping hits")
	check(w.data.players.host.dive_status.hurt!=w.data.players.guest.dive_status.hurt,"hurt protection is personal")
func _test_spear_and_rescue() -> void:
	var w=world();var p:=swim(w,"host",Vector2(570,265));Inventory.add(p.bag,"harpoon",1)
	var e:=aim_enemy(w,"shark",Vector2(670,265));var before:Array=p.bag.duplicate(true)
	w.action("host","spear",{"x":1.0,"y":0.0});step(w,0.8)
	check(e.phase=="repelled" and e.target=="","real spear flight cancels an enemy attack")
	check(p.stamina==95 and p.bag==before and p.caught==0,"repel costs one shot and creates no fish or items")
	check("击退" in p.notice,"successful repel is visible through existing notice protocol")
	step(w,2);check(e.remaining>10,"repel gives a real collection window")
	w.leave("guest");w.join("guest","伙伴")
	check(e.phase=="repelled" and e.remaining>10,"a partner reconnect does not reset repel cooldown")
	Inventory.add(p.bag,"fish",3)
	before=p.bag.duplicate(true);p.stamina=5;p.dive_status.hurt=0
	e=aim_enemy(w,"shark",Vector2(p.x+45,p.y),"charge");e.remaining=0.5
	step(w,0.1)
	check(p.area=="deck" and p.stamina==0,"exhausted diver is rescued to real safe deck")
	check(p.bag==before and p.dive_status.recovery>0,"rescue preserves bag and requires recovery")
	check("缓一缓" in w.action("host","dive"),"rescue cannot be immediately chained into another dive")
	check(w.data.players.guest.area=="deck" and w.data.day==1,"rescue does not move partner or end day")
	step(w,8.2);check(p.dive_status.recovery==0,"rescue recovery expires naturally")
	p=swim(w,"host",Vector2(120,100));p.oxygen=0.01;p.stamina=75;before=p.bag.duplicate(true)
	step(w,0.1)
	check(p.area=="deck" and p.bag==before and p.stamina==25,"oxygen rescue uses the same no-item-loss rule")
func _test_save_and_invalid() -> void:
	var w=world();Inventory.add(w.data.players.host.bag,"wood",999)
	Threats.repel(w.data,"moray")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(w.snapshot()))
	var loaded=World.new()
	check(loaded.restore(saved),"v13 full snapshot validates")
	check(loaded.data.threats.moray.phase=="repelled" and loaded.data.threats.moray.remaining==18,"save preserves earned repel window")
	check(loaded.data.threats.shark.phase=="recover" and loaded.data.threats.shark.target=="","load cancels pending attacks")
	check(loaded.data.players.host.bag==w.data.players.host.bag,"load preserves exact 999 stack slots")
	var old:Dictionary=saved.duplicate(true);old.version=12;old.erase("threats")
	for v14_key in ["rooms","gardens","restaurant","wardrobe","housing","journal","stories","chronicles"]:old.erase(v14_key)
	for v14_player in old.players.values():v14_player.erase("room")
	for p in old.players.values():p.erase("dive_status")
	check(loaded.restore(old) and loaded.data.version==19 and loaded.data.threats.size()==2,"old v12 creates threats without losing world")
	check(loaded.data.players.host.bag==w.data.players.host.bag and not old.has("threats"),"migration leaves supplied old snapshot unchanged")
	var baseline:Dictionary=loaded.snapshot()
	for field in ["x","y","dx","dy","remaining","clock"]:
		for invalid in [INF,NAN,"bad",{},null]:
			var bad:Dictionary=saved.duplicate(true);bad.threats.shark[field]=invalid
			check(not loaded.restore(bad) and loaded.snapshot()==baseline,"reject malformed enemy "+field+" without partial mutation")
	for bad_state in [{},{"grace":-1,"hurt":0,"recovery":0},{"grace":0,"hurt":0,"recovery":9},{"grace":0,"hurt":"a","recovery":0}]:
		var bad:Dictionary=saved.duplicate(true);bad.players.host.dive_status=bad_state
		check(not loaded.restore(bad),"reject invalid personal combat timers")
	for change in [{"phase":"unknown"},{"phase":"windup","target":"","remaining":1.0},{"phase":"patrol","target":"host"},{"dx":0.0,"dy":0.0},{"phase":"repelled","remaining":18.0},{"extra":"field"}]:
		var bad:Dictionary=saved.duplicate(true)
		for key in change:bad.threats.shark[key]=change[key]
		check(not loaded.restore(bad) and loaded.snapshot()==baseline,"reject incoherent enemy state atomically")


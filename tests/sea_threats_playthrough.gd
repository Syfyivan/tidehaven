extends "res://tests/playthrough.gd"
## Normal title, empty bag, live drift, real crafting and real inputs throughout.
## Reads state to observe; never grants, teleports, pauses enemies or accelerates time.
func _run() -> void:
	for key in ["save-path", "report", "evidence-dir"]:
		if not main.cli.has(key): _fail("Missing isolated argument: " + key); return
	for version in range(1,22):
		if ProjectSettings.globalize_path(str(main.save_path)).to_lower() == ProjectSettings.globalize_path("user://world_v%d.json" % version).to_lower():
			_fail("Refusing player default save"); return
	if FileAccess.file_exists(main.save_path) or FileAccess.file_exists(str(main.save_path)+".bak"):
		_fail("A fresh isolated save is required"); return
	await _settle(0.35)
	await _click(main.new_game_button.get_global_rect().get_center())
	if not (await _until(func(): return main.mode == "solo" and not main.overlay.visible,"normal solo title",4)): return
	if not _check(Inventory.total_count(_bag()) == 0 and _state().deck_tiles.size() == 9,"normal empty backpack opening"): return
	_record("Started normal empty-bag opening")
	await _capture("01-empty-raft.png")
	await _tap(KEY_H)
	if not (await _gather({"wood":6,"leaf":4,"scrap":4})): return
	for recipe in ["rope","rope","anchor","harpoon"]:
		if not (await _craft_item(recipe)): return
	_record("Hooked real drifting supplies and hand-crafted an anchor and harpoon")
	await _tap(KEY_G)
	if not _check(_state().navigation.anchored,"crafted anchor deploys"): return
	if not (await _walk(Vector2(544,288),"open raft edge")) or not (await _act("dive")): return
	if not (await _until(func(): return _player().area=="water","normal dive",3)): return
	var stamina: float = _player().stamina
	await _settle(8.2)
	if not _check(_player().stamina==stamina and _state().threats.shark.target=="","buoy remains safe after grace expires"): return
	await _capture("02-safe-buoy.png")
	await _equip_tool("harpoon")
	if not (await _walk(Vector2(450,265),"enter shark waters")): return
	if not (await _until(func(): return _state().threats.shark.phase=="windup","shark visibly prepares charge",8)): return
	_record("Shark acquired the diver and locked its charge direction")
	# Cross the locked direction with normal swimming; do not wait in its path.
	var at := Vector2(float(_player().x),float(_player().y))
	if not (await _walk(at+Vector2(0,80),"swim across shark charge")): return
	if not (await _until(func(): return _state().threats.shark.phase=="recover","shark finishes missed charge",3)): return
	if not _check(_player().stamina==stamina,"sideways swimming dodges without damage"): return
	await _capture("03-dodged-charge.png")
	_record("Dodged the telegraphed charge without stamina damage")
	if not (await _walk(Vector2(560,330),"approach shark with crafted harpoon")): return
	if not (await _repel("shark")): return
	await _capture("04-shark-repelled.png")
	if not (await _walk(Vector2(595,420),"approach deep moray territory")): return
	if not (await _repel("moray")): return
	await _capture("05-moray-repelled.png")
	# Return through shallow water while both enemies are repelled.
	if not (await _walk(Vector2(590,120),"leave deep water")): return
	if not (await _walk(Vector2(180,95),"safe floating wood")): return
	var wood_before := _count("wood")
	if not (await _act("collect","wood_00")): return
	if not (await _until(func(): return _count("wood")>wood_before,"normal timed collection after escape",12)): return
	if not (await _walk(Vector2(120,100),"return buoy")) or not (await _act("surface")): return
	if not (await _until(func(): return _player().area=="deck","surface onto original raft",3)): return
	_record("Returned with the crafted harpoon and naturally gathered underwater wood")
	expected_save=_saved_progress()
	if not (await _save_and_title()): return
	await _capture("06-saved-title.png")
	await _click(main.continue_button.get_global_rect().get_center())
	if not (await _until(func(): return main.mode=="solo" and not main.overlay.visible,"normal Continue",4)): return
	restored_save=_saved_progress()
	if not _check(_same_progress(restored_save,expected_save),"Continue preserves exact bag slots and raft progress"): return
	if not _check(_state().threats.size()==2 and _player().activity.is_empty(),"Continue has encounters without stale player attack"): return
	_record("Saved and continued exact inventory and raft through normal menus")
	await _capture("07-continued-raft.png")
	_release_keys();finished=true
	if not _write_report(true): get_tree().quit(1); return
	print("THREATS PLAYTHROUGH PASS: %.2fs; %d successful hooks" % [_seconds(),hook_count])
	get_tree().quit(0)

func _repel(kind: String) -> bool:
	if not (await _until(func(): return _state().threats[kind].phase=="windup",kind+" windup",9)): return false
	var enemy: Dictionary = _state().threats[kind]
	var before: float = _player().stamina
	var bag_before: Array = _bag().duplicate(true)
	await _click_world(Vector2(float(enemy.x),float(enemy.y)))
	if not (await _until(func(): return _state().threats[kind].phase=="repelled",kind+" repelled by actual spear flight",2)): return false
	if not _check(_player().stamina==before-5 and _bag()==bag_before,"repelling "+kind+" costs one spear action without invented loot"): return false
	_record("Repelled "+kind+" using the normally crafted harpoon")
	return true

extends SceneTree
## Verifies 5 ocean portraits, P2-08a Chinese harbor portraits & world sprite sheets,
## binary alpha (no translucent haze), foot anchors, and exact axe blade contact alignment.
const Portraits = preload("res://scripts/portrait_art.gd")
const CharacterArt = preload("res://scripts/character_art.gd")
const PlayerArt = preload("res://scripts/player_art.gd")
const Appearance = preload("res://scripts/appearance.gd")
const ChoppingArt = preload("res://scripts/chopping_art.gd")
const ToolMotion = preload("res://scripts/tool_motion.gd")
const OceanResidents = preload("res://scripts/ocean_residents.gd")
const OceanArt = preload("res://scripts/ocean_resident_art.gd")
var checks := 0
var failures := 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL harbor_art: ", label)

func _check_binary_alpha(image: Image, min_opaque: int, label: String) -> void:
	var opaque := 0
	var partial := 0
	for y in image.get_height():
		for x in image.get_width():
			var a := image.get_pixel(x, y).a
			if is_equal_approx(a, 1.0):
				opaque += 1
			elif a > 0.0:
				partial += 1
	_check(opaque >= min_opaque and partial == 0, "%s (opaque=%d, partial=%d)" % [label, opaque, partial])

func _initialize() -> void:
	for id: String in OceanResidents.NPCS:
		var tex := Portraits.texture(id)
		_check(tex is AtlasTexture and tex.get_size() == Vector2(64, 64), "ocean companion has 64x64 portrait: " + id)
		if tex != null:
			_check_binary_alpha(tex.get_image(), 1100, "ocean portrait crisp binary alpha: " + id)
		_check(OceanArt.SOURCES.has(id) and OceanArt.SOURCES[id].resource_path.begins_with("res://assets/characters/ocean/"), "ocean companion world sprite is original asset: " + id)
		for f_idx in 2:
			var otex := OceanArt.texture(id, float(f_idx) * 0.5)
			var expected_size: Vector2 = Vector2(OceanArt.REGIONS[id])
			_check(otex.get_size() == expected_size, "ocean world sprite size %s frame %d" % [id, f_idx])
			_check_binary_alpha(otex.get_image(), 80 if id == "tai_lu" else 130, "ocean world sprite binary alpha %s frame %d" % [id, f_idx])

	for body_idx in [0, 1]:
		var ptex := Portraits.player_texture({"body": body_idx})
		_check(ptex is AtlasTexture and ptex.get_size() == Vector2(64, 64), "harbor player portrait exists for body " + str(body_idx))
		if ptex != null:
			_check_binary_alpha(ptex.get_image(), 1200, "harbor player portrait binary alpha: " + str(body_idx))

	for npc_id: String in CharacterArt.NPC_SHEETS:
		var ptex := Portraits.texture(npc_id)
		_check(ptex is AtlasTexture and ptex.get_size() == Vector2(64, 64), "harbor NPC portrait exists: " + npc_id)
		if ptex != null:
			_check_binary_alpha(ptex.get_image(), 1200, "harbor NPC portrait binary alpha: " + npc_id)
			_check((ptex as AtlasTexture).atlas.resource_path.get_file() == CharacterArt.NPC_SHEETS[npc_id].resource_path.get_file(), "harbor NPC portrait filename matches world sheet: " + npc_id)
		for dir in 4:
			for step in 4:
				var wtex := CharacterArt.npc_texture(npc_id, dir, step)
				var img := wtex.get_image()
				_check(wtex.get_size() == Vector2(16, 32), "%s dir %d step %d is 16x32" % [npc_id, dir, step])
				_check_binary_alpha(img, 110, "%s dir %d step %d crisp pixels" % [npc_id, dir, step])
				var grounded := false
				for x in 16:
					if img.get_pixel(x, 31).a > 0.9:
						grounded = true
				_check(grounded, "%s dir %d step %d grounded at foot row y=31" % [npc_id, dir, step])

	# Check all harbor player body/hair/shirt combinations keep binary alpha & exact axe contact
	for body in 2:
		for hair in Appearance.HAIR.size():
			var spec := Appearance.default_for("host")
			spec.body = body
			spec.hair = hair
			spec.shirt = hair % Appearance.SHIRTS.size()
			spec.hair_color = hair % Appearance.HAIR_COLORS.size()
			spec.pants = hair % Appearance.PANTS_COLORS.size()
			PlayerArt.configure("host", spec)
			for dir in 4:
				var walk_img := PlayerArt.texture("host", dir, 1).get_image()
				_check_binary_alpha(walk_img, 90, "harbor player walk b%d h%d d%d" % [body, hair, dir])
				var chop_img := ChoppingArt.texture("host", dir, 3).get_image()
				_check_binary_alpha(chop_img, 85, "harbor player chop b%d h%d d%d" % [body, hair, dir])
				var pose := PlayerArt.tool_pose(dir, 3)
				var blade: Vector2 = (pose.blade - PlayerArt.FOOT) * 2.0
				_check(blade.distance_to(ToolMotion.BLADE_OFFSETS[dir]) < 1.0, "harbor player axe contact aligned d%d" % dir)

	print("HARBOR ART CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

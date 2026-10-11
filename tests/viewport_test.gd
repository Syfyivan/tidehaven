extends SceneTree
## Native viewport resizing and input-coordinate contracts; no save or game actions.
const Main = preload("res://scripts/main.gd")
const EPSILON := 0.01
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(str(ProjectSettings.get_setting("display/window/stretch/mode")) == "canvas_items", "native canvas scaling remains enabled")
	_check(str(ProjectSettings.get_setting("display/window/stretch/aspect")) == "expand", "engine expands instead of adding letterbox bars")
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = Vector2i(1280, 800)
	root.add_child(viewport)
	var main = Main.new()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(main)
	await process_frame
	# Include physical window shapes and the enlarged logical viewports produced
	# by Godot's expand stretch mode. Reuse the scene to exercise size_changed.
	var dimensions := [Vector2i(1280, 800), Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1920, 1080), Vector2i(960, 600), Vector2i(2560, 1080), Vector2i(1422, 800), Vector2i(1280, 960), Vector2i(1896, 800)]
	for dimensions_now in dimensions:
		viewport.size = dimensions_now
		await process_frame
		var visible_rect := Rect2(Vector2.ZERO, Vector2(dimensions_now))
		var world_transform: Transform2D = main.view.get_global_transform_with_canvas()
		var ui_transform: Transform2D = main.ui.get_global_transform_with_canvas()
		var description: String = "%dx%d" % [dimensions_now.x, dimensions_now.y]
		_check(_uniform(world_transform) and _uniform(ui_transform), description + ": world and UI retain uniform scale")
		_check(_contains(visible_rect, world_transform * Rect2(Vector2.ZERO, Main.WORLD_SIZE)), description + ": every gameplay edge stays visible")
		_check(_contains(visible_rect, ui_transform * Rect2(Vector2.ZERO, Main.UI_SIZE)), description + ": complete UI design frame stays visible")
		_check(_same_rect(world_transform * main.view.canvas_bounds, visible_rect), description + ": ocean canvas covers all viewport edges without a frame")
		var shades_cover: bool = main._window_shades.size() == 7
		for shade in main._window_shades:
			var drawn_rect: Rect2 = shade.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, shade.size)
			shades_cover = shades_cover and _same_rect(drawn_rect, visible_rect)
		_check(shades_cover, description + ": title, pause, inventory, discard, crafting, chart and island atlas shades reach all edges")
		var controls_visible := true
		var controls: Array = [main.new_game_button, main.continue_button, main.return_title_button, main.crafting_ui.make_button, main.crafting_ui.close_button, main.inventory_ui.discard_confirm_button, main.inventory_ui.close_button, main.hud.bag_button, main.hud.crafting_button, main.hud.menu_button]
		controls.append_array(main.inventory_ui.bag_buttons)
		controls.append(main.hud.anchor_button)
		controls.append_array(main.crafting_ui.recipe_buttons.values())
		controls.append_array(main.hud.quick_buttons)
		for control in controls:
			controls_visible = controls_visible and _contains(visible_rect, control.get_global_rect())
		_check(controls_visible, description + ": menu, modal, slot and hotbar controls remain within visible bounds")
		var pointer_roundtrip := true
		for logical in [Vector2(0, 0), Vector2(900, 560), Vector2(416, 224), Vector2(480, 352), Vector2(250, 100)]:
			var deck_pixel: Vector2 = world_transform * main.view.world_to_screen(logical, "deck")
			var deck_logical: Vector2 = main.view.screen_to_world(world_transform.affine_inverse() * deck_pixel, "deck")
			var ocean_pixel: Vector2 = world_transform * logical
			var ocean_logical: Vector2 = world_transform.affine_inverse() * ocean_pixel
			pointer_roundtrip = pointer_roundtrip and deck_logical.distance_to(logical) < EPSILON and ocean_logical.distance_to(logical) < EPSILON
			var hud_local: Vector2 = ui_transform.affine_inverse() * deck_pixel
			pointer_roundtrip = pointer_roundtrip and (ui_transform * hud_local).distance_to(deck_pixel) < EPSILON
		_check(pointer_roundtrip, description + ": deck inverse, drift targeting and HUD anchors agree on viewport coordinates")
		main.hud._layout_toolbar(true)
		var island_slots_visible := true
		for button in main.hud.quick_buttons:
			if button.visible:
				island_slots_visible = island_slots_visible and _contains(visible_rect, button.get_global_rect())
		_check(island_slots_visible and main.hud.slots.all(func(entry): return entry.button.visible), description + ": all twelve island bag slots stay visible and within the window")
		main.hud._layout_toolbar(false)
	viewport.free()
	print("VIEWPORT TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _uniform(value: Transform2D) -> bool:
	return absf(value.x.length() - value.y.length()) < EPSILON and absf(value.x.dot(value.y)) < EPSILON and absf(value.get_rotation()) < EPSILON

func _contains(outer: Rect2, inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x - EPSILON and inner.position.y >= outer.position.y - EPSILON and inner.end.x <= outer.end.x + EPSILON and inner.end.y <= outer.end.y + EPSILON

func _same_rect(first: Rect2, second: Rect2) -> bool:
	return first.position.distance_to(second.position) < EPSILON and first.size.distance_to(second.size) < EPSILON

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

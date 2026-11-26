extends "res://tests/island_ui_checks.gd"
const Rooms=preload("res://scripts/rooms.gd")
const Shop=preload("res://scripts/restaurant.gd")
const Gardens=preload("res://scripts/gardens.gd")
func _run()->void:
	evidence=ProjectSettings.globalize_path("res://artifacts/restaurant-ui-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(evidence)
	main=MainScene.instantiate();root.add_child(main);main.save_path=evidence.path_join("world.json");main.automated=true
	create_timer(100).timeout.connect(func():if not finished:printerr("FAIL restaurant UI deadline");quit(1))
	await _settle();await _click(main.new_game_button.get_global_rect().get_center());main.set_physics_process(false)
	main.world.data.chart.visited=true;main.world.data.navigation.anchored=true
	var coast:=Archipelago.island_position(main.world.data.chart);main.world.data.navigation.x=coast.x;main.world.data.navigation.y=coast.y
	for size in [Vector2i(960,600),Vector2i(1280,800)]:
		root.size=size
		main.world.data.restaurant=Shop.create();main.world.data.restaurant.rented=true;main.world.data.minute=1080
		_player().bag=Inventory.empty_slots(12);Inventory.add(_player().bag,"fish",8)
		Rooms._arrive(main.world.data,_player(),"restaurant",Shop.pantry());main.active_tool="hook"
		await _settle();await _tap(KEY_B)
		_check(main.inventory_ui.visible and main.inventory_ui.chest_id==Shop.STOCK_ID,"B opens actual pantry with bag")
		await _drag(main.inventory_ui.bag_buttons[0],main.inventory_ui.chest_buttons[0])
		_check(Inventory.count(main.world.data.restaurant.stock,"fish")==8,"real drag stores ingredients")
		await _capture("pantry-%d.png"%size.x);await _tap(KEY_ESCAPE)
		Rooms._arrive(main.world.data,_player(),"restaurant",Shop.station(0))
		await _settle();await _click(_world_point(Shop.station(0),"room"))
		_check(main.restaurant_ui.visible,"click actual counter opens preparation")
		await _capture("menu-%d.png"%size.x)
		await _click(main.restaurant_ui.prepare_buttons[0].sashimi.get_global_rect().get_center())
		_check(not main.restaurant_ui.visible and main.world.data.restaurant.stations[0].get("recipe")=="sashimi","prepare then close solo modal for time")
		main.world.tick(4.1);await _settle();await _capture("ready-%d.png"%size.x)
		await _click(_world_point(Shop.station(0),"room"));await _click(main.restaurant_ui.collect_buttons[0].get_global_rect().get_center())
		_check(Inventory.count(_player().bag,"sashimi")==1,"actual UI collects finished dish")
		await _tap(KEY_ESCAPE);Rooms._arrive(main.world.data,_player(),"restaurant",Shop.counter())
		await _settle();await _click(_world_point(Shop.counter(),"room"))
		await _click(main.restaurant_ui.menu_buttons.maki.get_global_rect().get_center());await _click(main.restaurant_ui.menu_buttons.salad.get_global_rect().get_center())
		await _click(main.restaurant_ui.opening.get_global_rect().get_center())
		_check(main.world.data.restaurant.open and not main.restaurant_ui.visible,"manual evening opening from UI")
		for i in 500:
			Shop.tick(main.world.data,0.1)
			if main.world.data.restaurant.customers.any(func(c:Dictionary):return c.phase=="wait"):break
		var customer:Dictionary=main.world.data.restaurant.customers.filter(func(c:Dictionary):return c.phase=="wait")[0]
		Rooms._arrive(main.world.data,_player(),"restaurant",Vector2(customer.x+24,customer.y))
		await _settle();await _capture("service-%d.png"%size.x)
		await _click(_world_point(Vector2(customer.x,customer.y),"room"))
		_check(customer.phase=="eat" and Inventory.count(_player().bag,"sashimi")==0,"click customer serves requested food")
		Rooms._arrive(main.world.data,_player(),"restaurant",Shop.counter());await _settle()
		await _click(_world_point(Shop.counter(),"room"));await _click(main.restaurant_ui.opening.get_global_rect().get_center())
		_check(main.world.data.restaurant.last.served==1,"manual close settlement displayed")
		await _capture("settlement-%d.png"%size.x);await _tap(KEY_ESCAPE)
		_check(main._persist(),"new content saves through normal save code")
		main.world.data.money=0
		await _tap(KEY_ESCAPE);await _click(main.return_title_button.get_global_rect().get_center());await _click(main.continue_button.get_global_rect().get_center())
		_check(main.mode=="solo" and main.world.data.restaurant.last.get("served")==1,"normal title Continue restores restaurant")
		main.world.data.gardens.greenhouse=true
		Rooms._arrive(main.world.data,_player(),"greenhouse",Vector2(336,400))
		for item in ["hoe","summer_seed","watering_can"]:Inventory.add(_player().bag,item,1)
		_player().can_water=20
		await _settle()
		for item in ["hoe","summer_seed","watering_can"]:
			var index:int=_player().bag.find(_player().bag.filter(func(s:Dictionary):return s.get("item")==item)[0])
			await _click(main.hud.slots[index].button.get_global_rect().get_center());await _click(_world_point(Vector2(336,400),"room"))
		_check(main.world.data.gardens.plots.get("10,12",{}).get("watered",false),"greenhouse held tools share normal click farming")
		# Display-only growth fixtures after the actual held-tool interaction above.
		for row in 4:
			for col in 7:
				var plot:=Farming.new_plot();plot.covered=true;plot.watered=col%2==0
				plot.crop=Farming.CROPS.keys()[row];plot.growth=mini(col*2,int(Farming.CROPS[plot.crop].days))
				main.world.data.gardens.plots["%d,%d"%[col+5,row+13]]=plot
		_player().x=496;_player().y=560;await _settle()
		await _capture("greenhouse-%d.png"%size.x)
	finished=true;print("RESTAURANT UI: %d checks, %d failures; %s"%[checks,failures,evidence]);quit(0 if failures==0 else 1)
func _drag(source:Button,target:Button)->void:
	var from:=source.get_global_rect().get_center();var to:=target.get_global_rect().get_center()
	await _move_mouse(from)
	var e:=InputEventMouseButton.new();e.position=from;e.global_position=from;e.button_index=MOUSE_BUTTON_LEFT;e.button_mask=MOUSE_BUTTON_MASK_LEFT;e.pressed=true
	root.push_input(e,true);await process_frame
	var previous:=from
	for i in range(1,9):
		var at:=from.lerp(to,i/8.0)
		var m:=InputEventMouseMotion.new();m.position=at;m.global_position=at;m.relative=at-previous;m.button_mask=MOUSE_BUTTON_MASK_LEFT
		root.push_input(m,true);previous=at;await _settle(0.04)
	e=InputEventMouseButton.new();e.position=to;e.global_position=to;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false
	root.push_input(e,true);await _settle()

func _settle(seconds:float=0.14)->void:
	await create_timer(seconds).timeout;await process_frame;RenderingServer.force_draw(false)

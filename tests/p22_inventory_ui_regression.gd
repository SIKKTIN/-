extends SceneTree

var game
var checks := {}
var suffix: String
var images: Array = []

func _initialize() -> void:
	call_deferred("run")

func frame(name: String = "") -> void:
	game._update_ui()
	game.presentation.tick(0)
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if name != "":
		var path := "res://docs/tests/p22-regression-%s-%s.png" % [name,suffix]
		root.get_texture().get_image().save_png(path)
		images.append(path)

func mouse(button: int, pressed: bool, point: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = root.get_final_transform()*point
	root.push_input(e)

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	mouse(MOUSE_BUTTON_LEFT,true,point)
	await process_frame
	mouse(MOUSE_BUTTON_LEFT,false,point)
	await frame()

func run() -> void:
	suffix = "%dx%d" % [root.size.x,root.size.y]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r03",["backpack","chat","strong"],20)
	await frame("r03-day-start")
	checks.default_new_map = game.room_id == "r03" and game.room_selector.selected == 2
	checks.merchant_asset = game.items_view.icon_for("merchant") is AtlasTexture and game.items_view.merchant_asset.world_height == 64
	checks.item_and_feedback_assets = ["scrap","door_key","lock_tool","backpack","trade","pickup","drop","transfer","full","empty"].all(func(id): return game.items_view.icon_for(id) != null)
	checks.seven_room_lamps = game.presentation.lighting.lamps.size() == 7
	checks.backpack_three_slots = game.inventory_panel.slots.all(func(s): return s.visible)
	checks.initial_empty_slots_fit = game.inventory_panel.slots.all(func(s): return s.size.x <= 48 and s.size.y <= 49)
	game.presentation.lighting.set_period("night")
	await frame("r03-night-start")
	checks.night_real_lights = game.presentation.lighting.lamps.all(func(l): return l.enabled and l.shadow_enabled) and game.guard.view_radius() == 155
	# UI fixture only: position close to merchant and stage three owned cargo instances.
	game.actors[0].position = Vector2(360,400)
	game.actors[1].position = Vector2(395,400)
	game.map_camera.locate_selected()
	var ids: Array = []
	for n in range(3):
		var id: String = game.inventory.add_ground("scrap",game.actors[0].position)
		game.inventory.try_pickup(0,id)
		ids.append(id)
	await frame()
	var trade_button: Button = game.presentation.interaction.extras["trade:warehouse_dealer"]
	checks.nearby_trade_icon = trade_button.visible and trade_button.icon != null
	await click(trade_button)
	checks.actual_click_opens_shop = game.shop_panel.panel.visible
	await click(game.inventory_panel.slots[0])
	checks.actual_click_selects_item = game.inventory_panel.selected_item == ids[0]
	await click(game.shop_panel.sell)
	checks.actual_click_sells = game.inventory.wallet == 3 and game.inventory.items(0).size() == 2 and game.inventory.instances[ids[0]].location == "shop"
	await click(game.inventory_panel.slots[0])
	await click(game.shop_panel.sell)
	await click(game.inventory_panel.slots[0])
	await click(game.shop_panel.sell)
	await click(game.shop_panel.buy)
	checks.actual_click_buys_key = game.inventory.wallet == 0 and game.inventory.items(0).size() == 1 and game.inventory.instances[game.inventory.items(0)[0]].definition_id == "door_key"
	await frame("r03-shop")
	game.shop_panel.close()
	await click(game.inventory_panel.slots[0])
	await click(game.inventory_panel.transfer_buttons[1])
	checks.actual_click_transfers = game.inventory.items(0).is_empty() and game.inventory.items(1).size() == 1
	await click(game.cards[1])
	checks.card_select_one_slot = game.selected_actor_id == 1 and game.inventory_panel.slots[0].visible and not game.inventory_panel.slots[1].visible
	await click(game.inventory_panel.slots[0])
	await click(game.inventory_panel.drop_button)
	checks.actual_click_drops = game.inventory.items(1).is_empty()
	await frame("r03-pickup")
	var dropped: String = ids[0] # Choose the actual dropped key, not a staged/sold scrap.
	for entry in game.inventory.instances.values():
		if entry.location == "ground" and entry.definition_id == "door_key":
			dropped = entry.id
	var pickup: Button = game.presentation.interaction.extras["pickup:"+dropped]
	await click(pickup)
	checks.actual_click_pickup = game.inventory.items(1).has(dropped)
	var old_positions: Array = game.actors.map(func(a): return a.position)
	var old_hud: Vector2 = game.cards[0].position
	var old_offset: Vector2 = game.map_camera.position
	mouse(MOUSE_BUTTON_MIDDLE,true,Vector2(700,450))
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform()*Vector2(450,350)
	motion.relative = root.get_final_transform().basis_xform(Vector2(-250,-100))
	root.push_input(motion)
	mouse(MOUSE_BUTTON_MIDDLE,false,Vector2(450,350))
	await frame("r03-scrolled")
	checks.actual_middle_drag_pans = game.map_camera.position.distance_to(old_offset) > 150
	checks.drag_does_not_move_actors_hud = old_positions == game.actors.map(func(a): return a.position) and game.cards[0].position == old_hud
	checks.offscreen_prompt_hidden = not game.presentation.interaction.extras["trade:warehouse_dealer"].visible
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.pressed = true
	root.push_input(key)
	key.pressed = false
	root.push_input(key)
	await frame()
	checks.actual_f_locates = game.map_camera.position.distance_to(old_offset) < 1
	var image := root.get_texture().get_image()
	var paper_point: Vector2 = root.get_final_transform()*Vector2(40,200)
	var color := image.get_pixel(int(paper_point.x),int(paper_point.y))
	checks.world_clipped_paper_unshaded = color.r > 0.85 and color.g > 0.80 and color.b > 0.70
	checks.slots_fit_panel = game.inventory_panel.slots.all(func(s): return s.size.x <= 48)
	var passed: bool = checks.values().all(func(x): return x == true)
	var file := FileAccess.open("res://docs/tests/p22-regression-native-ui-%s.json"%suffix,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"images":images,"headless":DisplayServer.get_name()=="headless","note":"Native synthetic Viewport.push_input GUI dispatch and rendered scene pixels; staged UI fixture, not human play or full-route proof."},"\t"))
	print(JSON.stringify({"passed":passed,"checks":checks,"size":suffix}))
	quit(0 if passed else 1)

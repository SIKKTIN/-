extends SceneTree

var game
var camera
var mini
var checks := {}
var suffix: String
var metrics := {}

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	game._update_ui()
	game.presentation.tick(0)
	await process_frame
	await process_frame

func mouse(button: int, down: bool, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	event.position = root.get_final_transform()*point
	root.push_input(event)

func touch(down: bool, point: Vector2, index: int = 0, cancel: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = down
	event.canceled = cancel
	event.position = root.get_final_transform()*point
	Input.parse_input_event(event)

func drag(point: Vector2, from: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = root.get_final_transform()*point
	event.relative = root.get_final_transform().basis_xform(point-from)
	Input.parse_input_event(event)

func tap(point: Vector2) -> void:
	touch(true,point)
	await frame()
	touch(false,point)
	await frame()

func screen(world_point: Vector2) -> Vector2:
	return game.get_global_transform_with_canvas()*world_point

func run() -> void:
	suffix = "%dx%d" % [root.size.x,root.size.y]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r03",["backpack","lockpick","strong"],22)
	camera = game.map_camera
	mini = game.mini_map
	root.grab_focus()
	await frame()
	checks.native_focused = root.has_focus()
	checks.touch_mouse_emulation_enabled = Input.is_emulating_mouse_from_touch()
	checks.minimap_visible_and_in_map = mini.visible and camera.VIEW.encloses(mini.get_global_rect())
	checks.phone_actions_visible = mini.locate_button.size.y >= 44 and mini.stop_button.size.y >= 44
	checks.aspect_preserved = absf(mini.map_rect().size.aspect()-game.world.bounds.size.aspect()) < 0.01
	camera.position = Vector2(400,240)
	camera.pan_by(Vector2.ZERO)
	for point in [Vector2(990,394),Vector2(80,394),Vector2(535,120),Vector2(535,669),Vector2(990,669)]:
		root.warp_mouse(point)
		var before: Vector2 = camera.position
		await create_timer(0.1).timeout
		checks["no_edge_scroll_"+str(point)] = camera.position == before
	var positions: Array = game.actors.map(func(a): return a.position)
	var cards: Array = game.cards.map(func(c): return c.position)
	var target := Vector2(1100,650)
	var point: Vector2 = mini.global_position+mini.to_map(target)
	mouse(MOUSE_BUTTON_LEFT,true,point)
	mouse(MOUSE_BUTTON_LEFT,false,point)
	await frame()
	checks.mouse_minimap_centers = camera.position.distance_to(target-camera.VIEW.get_center()) < 1
	checks.minimap_does_not_command = game.orders.active.is_empty()
	var frame_rect: Rect2 = mini.frame_rect()
	checks.frame_matches_view = frame_rect.position.distance_to(mini.to_map(camera.position+camera.VIEW.position)) < 0.01 and mini.map_rect().encloses(frame_rect)
	await tap(mini.global_position+mini.to_map(Vector2(81,101)))
	checks.touch_minimap_top_left_clamp = camera.position == Vector2(6,-14)
	metrics.touch_minimap_top_left = [camera.position.x,camera.position.y]
	point = mini.global_position+mini.map_rect().get_center()
	touch(true,point)
	await frame()
	var end: Vector2 = mini.global_position+mini.map_rect().end+Vector2(100,100)
	drag(end,point)
	await frame()
	touch(false,end)
	await frame()
	checks.touch_minimap_drag_outside_clamped = camera.position == Vector2(884,526) and mini.pointer_id == -2
	checks.minimap_never_moves_actors_or_hud = positions == game.actors.map(func(a): return a.position) and cards == game.cards.map(func(c): return c.position) and game.orders.active.is_empty()
	await tap(mini.locate_button.get_global_rect().get_center())
	checks.touch_locate_button = camera.position == Vector2(6,-14) and camera.pointer_id == -2
	await tap(screen(game.actors[1].position))
	checks.touch_selects_actor = game.selected_actor_id == 1 and game.orders.active.is_empty()
	var goal := Vector2(380,380)
	await tap(screen(goal))
	checks.touch_ground_moves_selected_once = game.orders.active.has(1) and game.orders.active.size() == 1 and game.orders.active[1].goal.distance_to(goal) < 1
	await tap(mini.stop_button.get_global_rect().get_center())
	checks.touch_stop_button = game.orders.active.is_empty()
	camera.position = Vector2(400,240)
	camera.pan_by(Vector2.ZERO)
	point = Vector2(680,520)
	end = Vector2(430,420)
	touch(true,point)
	await frame()
	drag(end,point)
	await frame()
	touch(false,end)
	await frame()
	checks.touch_main_drag_only_camera = camera.position.distance_to(Vector2(650,340)) < 1 and game.orders.active.is_empty() and camera.pointer_id == -2
	var before: Vector2 = camera.position
	touch(true,Vector2(600,500),0)
	await frame()
	touch(true,Vector2(400,400),1)
	drag(Vector2(350,350),Vector2(400,400),1)
	await frame()
	touch(false,Vector2(350,350),1)
	touch(false,Vector2(600,500),0,true)
	await frame()
	checks.second_finger_and_cancel_no_command = camera.position == before and camera.pointer_id == -2 and game.orders.active.is_empty()
	touch(true,Vector2(600,500))
	await frame()
	touch(false,Vector2(570,480))
	await frame()
	checks.fast_swipe_release_is_not_tap = camera.position.distance_to(before+Vector2(30,20)) < 1 and game.orders.active.is_empty()
	before = camera.position
	# Mouse also previews the mobile gestures, right-click remains compatible.
	point = Vector2(650,520)
	end = Vector2(500,450)
	mouse(MOUSE_BUTTON_LEFT,true,point)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform()*end
	motion.relative = root.get_final_transform().basis_xform(end-point)
	root.push_input(motion)
	mouse(MOUSE_BUTTON_LEFT,false,end)
	checks.mouse_main_drag_no_command = camera.position.distance_to((before+Vector2(150,70)).clamp(Vector2(6,-14),Vector2(884,526))) < 1 and game.orders.active.is_empty()
	game.actors[1].position = Vector2(1250,900)
	camera.locate_selected()
	goal = Vector2(1460,980)
	mouse(MOUSE_BUTTON_RIGHT,true,screen(goal))
	mouse(MOUSE_BUTTON_RIGHT,false,screen(goal))
	checks.right_click_scrolled_world_position = game.orders.active.has(1) and game.orders.active[1].goal.distance_to(goal) < 1
	game.orders.clear()
	await tap(game.cards[0].get_global_rect().get_center())
	checks.touch_sidebar_selects_no_move = game.selected_actor_id == 0 and game.orders.active.is_empty()
	game.actors[0].position = Vector2(360,400)
	camera.locate_selected()
	await frame()
	var trade_button: Button = game.presentation.interaction.extras["trade:warehouse_dealer"]
	metrics.trade_before = {"visible":trade_button.visible,"rect":str(trade_button.get_global_rect()),"selected":game.selected_actor_id,"point":str(game.actors[0].position)}
	var trade_presses := [0]
	trade_button.pressed.connect(func(): trade_presses[0] += 1)
	await tap(trade_button.get_global_rect().get_center())
	checks.touch_interaction_opens_shop_once = game.shop_panel.panel.visible and trade_presses[0] == 1 and game.orders.active.is_empty() and camera.pointer_id == -2
	metrics.trade_after = {"open":game.shop_panel.panel.visible,"presses":trade_presses[0],"orders":game.orders.active.size(),"pointer":camera.pointer_id,"status":game.status_text}
	before = camera.position
	await tap(mini.global_position+mini.map_rect().end-Vector2(2,2))
	checks.shop_blocks_minimap = camera.position == before
	checks.shop_has_priority_over_minimap = not mini.visible
	game.shop_panel.close()
	await frame()
	checks.close_shop_restores_minimap = mini.visible
	# Refresh the prompt between touch down/up, just like live gameplay frames.
	var item: String = game.inventory.add_ground("scrap",game.actors[0].position)
	await frame()
	var pickup: Button = game.presentation.interaction.extras["pickup:"+item]
	var pickups := [0]
	pickup.pressed.connect(func(): pickups[0] += 1)
	await tap(pickup.get_global_rect().get_center())
	checks.touch_pickup_once_across_frames = pickups[0] == 1 and game.inventory.items(0).has(item) and game.orders.active.is_empty()
	game.inventory.try_drop(0,item)
	game.load_room("r03",["chat","lockpick","strong"],22)
	game.actors[0].position = Vector2(650,420)
	camera.locate_selected()
	await frame()
	var skill_button: Button = game.presentation.interaction.button
	var skill_presses := [0]
	skill_button.pressed.connect(func(): skill_presses[0] += 1)
	await tap(skill_button.get_global_rect().get_center())
	checks.touch_chat_once_across_frames = skill_presses[0] == 1 and game.skills.actions.has(0) and game.guard.state == "talking"
	await tap(skill_button.get_global_rect().get_center())
	checks.touch_chat_stop_once = skill_presses[0] == 2 and not game.skills.actions.has(0)
	game.load_room("r03",["backpack","lockpick","strong"],22)
	game.actors[0].position = game.actors[0].home
	camera.locate_selected()
	game.command_move(0,Vector2(380,260))
	before = game.actors[0].position
	game.set_process(true)
	await tap(mini.global_position+mini.map_rect().get_center())
	await create_timer(0.12).timeout
	game.set_process(false)
	checks.independent_order_runs_while_view_moves = game.orders.active.has(0) and game.actors[0].position.x > before.x+10
	game.orders.clear()
	for room in ["r01","r02"]:
		game.load_room(room,["chat","lockpick","strong"],22)
		await tap(mini.global_position+mini.map_rect().get_center())
		checks[room+"_fixed_camera_full_frame"] = not camera.enabled_for_room and camera.position == Vector2.ZERO and mini.frame_rect().size.distance_to(mini.map_rect().size) < 0.01
		await tap(screen(Vector2(300,270)))
		checks[room+"_touch_move"] = game.orders.active.has(0)
		game.orders.clear()
	game.load_room("r03",["backpack","lockpick","strong"],22)
	camera.center_on(Vector2(1050,630))
	root.warp_mouse(Vector2(535,394))
	await frame()
	await RenderingServer.frame_post_draw
	var picture := "res://docs/tests/p22-mobile-minimap-%s.png"%suffix
	root.get_texture().get_image().save_png(picture)
	var passed: bool = checks.values().all(func(value): return value == true)
	var file := FileAccess.open("res://docs/tests/p22-mobile-minimap-%s.json"%suffix,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"metrics":metrics,"image":picture,"note":"Native Windows Godot real event dispatch, raw ScreenTouch/ScreenDrag via Input.parse_input_event with touch-to-mouse emulation enabled, plus mouse GUI input. Most gameplay frozen as fixtures; one independent-order case runs real frames. Not Android/iOS device testing."},"\t"))
	print(JSON.stringify({"passed":passed,"checks":checks,"metrics":metrics}))
	quit(0 if passed else 1)

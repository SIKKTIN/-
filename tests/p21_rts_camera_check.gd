extends SceneTree

var game
var camera
var checks := {}
var metrics := {}
var suffix: String

func _initialize() -> void:
	call_deferred("run")

func render() -> void:
	game._update_ui()
	game.presentation.tick(0)
	await process_frame
	await process_frame

func warp(point: Vector2) -> void:
	root.warp_mouse(point)
	await render()

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func scroll_at(point: Vector2, arrows: Array = []) -> Vector2:
	camera.set_process(false)
	camera.position = Vector2(400,240)
	camera.pan_by(Vector2.ZERO)
	await warp(point)
	var before: Vector2 = camera.position
	for arrow in arrows:
		key(arrow,true)
	camera.set_process(true)
	await create_timer(0.18).timeout
	camera.set_process(false)
	for arrow in arrows:
		key(arrow,false)
	var delta: Vector2 = camera.position-before
	metrics[str(point)+str(arrows)] = {"delta":[delta.x,delta.y],"mouse":[root.get_mouse_position().x,root.get_mouse_position().y],"focused":root.has_focus()}
	return delta

func mouse(button: int, pressed: bool, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = root.get_final_transform()*point
	root.push_input(event)

func run() -> void:
	suffix = "%dx%d" % [root.size.x,root.size.y]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r03",["backpack","lockpick","strong"],21)
	camera = game.map_camera
	camera.set_process(false)
	root.grab_focus()
	await render()
	checks.native_focus = root.has_focus()
	var positions: Array = game.actors.map(func(a): return a.position)
	var cards: Array = game.cards.map(func(c): return c.position)
	var delta := await scroll_at(Vector2(990,394))
	checks.right_edge = delta.x > 50 and absf(delta.y) < 0.01
	delta = await scroll_at(Vector2(80,394))
	checks.left_edge = delta.x < -50 and absf(delta.y) < 0.01
	delta = await scroll_at(Vector2(535,120))
	checks.top_edge = delta.y < -50 and absf(delta.x) < 0.01
	delta = await scroll_at(Vector2(535,669))
	checks.bottom_edge = delta.y > 50 and absf(delta.x) < 0.01
	delta = await scroll_at(Vector2(990,669))
	checks.corner_scroll = delta.x > 35 and delta.y > 35 and absf(delta.x-delta.y) < 0.01
	for point in [Vector2(535,394),Vector2(1100,394),Vector2(50,394),Vector2(535,80),Vector2(535,700)]:
		delta = await scroll_at(point)
		checks["no_edge_"+str(point)] = delta.length() < 0.01
	for pair in [[KEY_RIGHT,Vector2.RIGHT],[KEY_LEFT,Vector2.LEFT],[KEY_UP,Vector2.UP],[KEY_DOWN,Vector2.DOWN]]:
		delta = await scroll_at(Vector2(535,394),[pair[0]])
		checks["arrow_"+str(pair[0])] = delta.dot(pair[1]) > 50
	delta = await scroll_at(Vector2(535,394),[KEY_RIGHT,KEY_DOWN])
	checks.arrow_diagonal = delta.x > 35 and delta.y > 35 and absf(delta.x-delta.y) < 0.01
	checks.actors_and_hud_not_dragged = positions == game.actors.map(func(a): return a.position) and cards == game.cards.map(func(c): return c.position) and game.orders.active.is_empty()
	game.shop_panel.open("warehouse_dealer") # Far away: use a valid nearby fixture.
	game.actors[0].position = Vector2(360,400)
	game.shop_panel.open("warehouse_dealer")
	delta = await scroll_at(Vector2(990,394),[KEY_RIGHT])
	checks.shop_suppresses_edge_and_arrows = game.shop_panel.panel.visible and delta == Vector2.ZERO
	game.shop_panel.close()
	game.actors[0].position = game.actors[0].home
	camera.position = Vector2(400,240)
	camera.pan_by(Vector2(10000,10000))
	checks.bottom_right_clamp = camera.position == Vector2(884,526)
	camera.pan_by(Vector2(-10000,-10000))
	checks.top_left_clamp = camera.position == Vector2(6,-14)
	camera.position = Vector2(400,240)
	camera.pan_by(Vector2.ZERO)
	await warp(Vector2(535,394))
	mouse(MOUSE_BUTTON_MIDDLE,true,Vector2(700,450))
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform()*Vector2(450,350)
	motion.relative = root.get_final_transform().basis_xform(Vector2(-250,-100))
	root.push_input(motion)
	mouse(MOUSE_BUTTON_MIDDLE,false,Vector2(450,350))
	checks.middle_drag_preserved = camera.position.distance_to(Vector2(650,340)) < 1 and not camera.panning
	key(KEY_F,true)
	await render()
	key(KEY_F,false)
	await render()
	checks.f_locates = camera.position == Vector2(6,-14)
	# A real second OS window removes focus from the game.
	root.gui_embed_subwindows = false
	var other := Window.new()
	other.title = "P21 focus fixture"
	other.size = Vector2i(200,100)
	root.add_child(other)
	other.show()
	other.grab_focus()
	await render()
	var focus_before: Vector2 = camera.position
	key(KEY_RIGHT,true)
	camera.set_process(true)
	await create_timer(0.18).timeout
	camera.set_process(false)
	checks.unfocused_window_stops = not root.has_focus() and camera.position == focus_before
	key(KEY_RIGHT,false)
	other.queue_free()
	await process_frame
	root.grab_focus()
	await warp(Vector2(990,394))
	var held := InputEventMouseButton.new()
	held.button_index = MOUSE_BUTTON_LEFT
	held.pressed = true
	held.position = root.get_final_transform()*Vector2(990,394)
	Input.parse_input_event(held)
	await render()
	var held_before: Vector2 = camera.position
	camera.set_process(true)
	await create_timer(0.18).timeout
	camera.set_process(false)
	checks.held_left_prevents_edge = camera.position == held_before
	held.pressed = false
	Input.parse_input_event(held)
	await render()
	camera.position = Vector2(400,240)
	await warp(Vector2(535,394))
	key(KEY_SPACE,true)
	await render()
	mouse(MOUSE_BUTTON_LEFT,true,Vector2(700,450))
	var space_motion := InputEventMouseMotion.new()
	space_motion.position = root.get_final_transform()*Vector2(450,350)
	space_motion.relative = root.get_final_transform().basis_xform(Vector2(-250,-100))
	root.push_input(space_motion)
	mouse(MOUSE_BUTTON_LEFT,false,Vector2(450,350))
	key(KEY_SPACE,false)
	await render()
	checks.space_drag_preserved = camera.position.distance_to(Vector2(650,340)) < 1 and not camera.panning
	# The next command is sent through actual native viewport dispatch after scrolling.
	game.actors[0].position = Vector2(1250,900)
	camera.locate_selected()
	var goal := Vector2(1460,980)
	var screen: Vector2 = game.get_global_transform_with_canvas()*goal
	mouse(MOUSE_BUTTON_RIGHT,true,screen)
	mouse(MOUSE_BUTTON_RIGHT,false,screen)
	checks.scrolled_right_click_world_coordinates = game.orders.active.has(0) and game.orders.active[0].goal.distance_to(goal) < 1
	game.orders.clear()
	game.actors[0].position = game.actors[0].home
	game.map_camera.reset()
	# Existing independent movement keeps running while the camera scrolls.
	game.command_move(0,Vector2(380,260))
	await warp(Vector2(990,394))
	var before_actor: Vector2 = game.actors[0].position
	var before_camera: Vector2 = camera.position
	game.set_process(true)
	camera.set_process(true)
	await create_timer(0.18).timeout
	game.set_process(false)
	camera.set_process(false)
	checks.independent_order_keeps_running = game.orders.active.has(0) and game.actors[0].position.x > before_actor.x + 20 and camera.position.x > before_camera.x + 50
	game.orders.clear()
	game.load_room("r01",["chat","lockpick","strong"],21)
	delta = await scroll_at(Vector2(990,394),[KEY_RIGHT])
	checks.small_room_no_scrolling = not camera.enabled_for_room and delta == Vector2.ZERO
	game.load_room("r03",["backpack","lockpick","strong"],21)
	camera.position = Vector2(600,300)
	camera.pan_by(Vector2.ZERO)
	await warp(Vector2(535,394))
	await render()
	await RenderingServer.frame_post_draw
	var picture := "res://docs/tests/p21-rts-camera-%s.png"%suffix
	root.get_texture().get_image().save_png(picture)
	var passed: bool = checks.values().all(func(c): return c == true)
	var file := FileAccess.open("res://docs/tests/p21-rts-camera-%s.json"%suffix,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"metrics":metrics,"image":picture,"note":"Native OS cursor warp and physical-key input with real frame-clock camera updates; gameplay mostly isolated as UI fixture, independent-order case runs actual AI/game processing."},"\t"))
	print(JSON.stringify({"passed":passed,"checks":checks,"metrics":metrics}))
	quit(0 if passed else 1)

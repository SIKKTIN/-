extends SceneTree

var game
var checks := {}
var frame_times: Array = []
var input_times: Array = []

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func touch(down: bool, point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = down
	event.position = root.get_final_transform()*point
	Input.parse_input_event(event)

func tap(point: Vector2) -> void:
	touch(true,point)
	await frame()
	touch(false,point)
	await frame()

func expected_offset() -> Vector2:
	var camera = game.map_camera
	return (game.actors[game.selected_actor_id].position-camera.VIEW.get_center()).clamp(game.world.bounds.position-camera.VIEW.position,game.world.bounds.end-camera.VIEW.end)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.load_room("r04",["lockpick","chat","strong"],24)
	root.grab_focus()
	root.warp_mouse(Vector2(535,394))
	await frame()
	var camera = game.map_camera
	var mini = game.mini_map
	checks.follow_enabled_on_start = camera.following
	checks.no_edge_scrolling = not camera.snapshot().edge_scroll
	var hud: Array = game.cards.map(func(c): return c.position)
	# Safe-corridor start fixture; gameplay, guard and native clocks then run normally.
	game.actors[0].position = Vector2(540,970)
	camera.locate_selected()
	var before: Vector2 = camera.position
	game.command_move(0,Vector2(540,1200))
	await create_timer(0.4).timeout
	checks.follow_tracks_moving_actor = camera.following and camera.position.y > before.y+20
	checks.follow_is_smooth = camera.position.distance_to(expected_offset()) < 25
	await tap(game.cards[1].get_global_rect().get_center())
	await create_timer(0.8).timeout
	checks.touch_card_changes_follow_target = game.selected_actor_id == 1 and camera.following and camera.position.distance_to(expected_offset()) < 3
	checks.other_actor_order_continues = game.orders.active.has(0) or game.actors[0].position.distance_to(Vector2(540,1200)) < 3
	var start := Vector2(500,400)
	touch(true,start)
	await frame()
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = root.get_final_transform()*Vector2(400,300)
	drag.relative = root.get_final_transform().basis_xform(Vector2(-100,-100))
	Input.parse_input_event(drag)
	await frame()
	touch(false,Vector2(400,300))
	await frame()
	before = camera.position
	await create_timer(0.2).timeout
	checks.touch_pan_pauses_follow = not camera.following and camera.position == before
	checks.drag_does_not_issue_move = not game.orders.active.has(1)
	await tap(mini.global_position+mini.to_map(Vector2(1300,1100)))
	before = camera.position
	await create_timer(0.2).timeout
	checks.minimap_view_stays_manual = not camera.following and camera.position == before
	await tap(game.cards[1].get_global_rect().get_center())
	await create_timer(0.8).timeout
	checks.reselect_restores_follow = camera.following and camera.position.distance_to(expected_offset()) < 3
	await tap(mini.global_position+mini.to_map(Vector2(1300,1100)))
	await tap(mini.locate_button.get_global_rect().get_center())
	checks.locate_restores_follow = camera.following and camera.position.distance_to(expected_offset()) < 1
	game.select_actor(0)
	camera.locate_selected()
	var latest := Vector2.ZERO
	var all_accepted := true
	for index in range(30):
		latest = Vector2(520 if index%2 == 0 else 560,1140 if index%2 == 0 else 1260)
		var point: Vector2 = game.get_global_transform_with_canvas()*latest
		var begin := Time.get_ticks_usec()
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = true
		event.position = root.get_final_transform()*point
		root.push_input(event)
		input_times.append((Time.get_ticks_usec()-begin)/1000.0)
		all_accepted = all_accepted and game.orders.active.has(0) and game.orders.active[0].goal.distance_to(latest) < 1
		event.pressed = false
		root.push_input(event)
		begin = Time.get_ticks_usec()
		await frame()
		frame_times.append((Time.get_ticks_usec()-begin)/1000.0)
	checks.rapid_click_latest_goal = all_accepted
	checks.rapid_click_does_not_stop_actor = game.orders.active.has(0)
	all_accepted = true
	for index in range(30):
		latest = Vector2(520 if index%2 == 0 else 560,1060 if index%2 == 0 else 1340)
		var point: Vector2 = game.get_global_transform_with_canvas()*latest
		await tap(point)
		all_accepted = all_accepted and game.selected_actor_id == 0 and game.orders.active.has(0) and game.orders.active[0].goal.distance_to(latest) < 1
	checks.rapid_touch_latest_goal = all_accepted
	checks.hud_fixed = hud == game.cards.map(func(c): return c.position)
	checks.camera_clamped = game.world.bounds.encloses(Rect2(camera.position+camera.VIEW.position,camera.VIEW.size))
	await create_timer(1.5).timeout
	checks.last_goal_reached = game.actors[0].position.distance_to(latest) < 3 and not game.orders.active.has(0)
	checks.no_capture_in_safe_corridor = game.captures == 0
	game.load_room("r01",["chat","lockpick","strong"],24)
	game.select_actor(1)
	await frame()
	checks.small_map_still_fixed = not camera.enabled_for_room and camera.position == Vector2.ZERO
	game.load_room("r04",["lockpick","chat","strong"],24)
	await frame()
	checks.reload_restores_follow = camera.following and game.selected_actor_id == 0
	input_times.sort()
	frame_times.sort()
	var passed: bool = checks.values().all(func(v): return v == true)
	var suffix := "%dx%d"%[root.size.x,root.size.y]
	var report := {"passed":passed,"checks":checks,"input_p95_ms":input_times[28],"frame_p95_ms":frame_times[28],"input_max_ms":input_times.back(),"frame_max_ms":frame_times.back(),"scope":"Native Windows Godot 4.7.2 actual frames, continuous game/guard, 30 raw ScreenTouch taps and 30 Viewport right clicks. Input/frame timings cover right-click loop only. Safe-corridor start fixture; not human or Android/iOS timing."}
	FileAccess.open("res://docs/tests/p24-native-follow-%s.json"%suffix,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	root.get_texture().get_image().save_png("res://docs/tests/p24-native-follow-%s.png"%suffix)
	print(JSON.stringify(report))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0 if passed else 1)

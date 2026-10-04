extends SceneTree

var g
const DT := 1.0/60.0

func _initialize() -> void:
	call_deferred("_run")

func step(ticks: int) -> void:
	for i in range(ticks):
		g._process(DT)

func click(button: int, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = g.get_global_transform_with_canvas() * point
	g._unhandled_input(event)

func _run() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g.reset_round(["chat","lockpick","strong"],33)
	var checks := {}
	click(MOUSE_BUTTON_LEFT,Vector2(180,198))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(350,235)
	g._unhandled_input(motion)
	step(30)
	checks.left_select_without_drag = g.selected_actor_id == 0 and g.actors[0].position == Vector2(180,235) and g.orders.active.is_empty()
	click(MOUSE_BUTTON_RIGHT,Vector2(350,235))
	step(12)
	checks.right_click_moves_selected = g.actors[0].position.x > 220 and g.actors[1].position == Vector2(235,375) and g.actors[2].position == Vector2(185,510)
	click(MOUSE_BUTTON_LEFT,Vector2(235,338))
	click(MOUSE_BUTTON_RIGHT,Vector2(400,375))
	var first_x: float = g.actors[0].position.x
	step(12)
	checks.switch_keeps_first_order = g.actors[0].position.x > first_x and g.actors[1].position.x > 260 and g.orders.active.has(0) and g.orders.active.has(1)
	g.stop_selected()
	checks.stop_only_selected = g.orders.active.has(0) and not g.orders.active.has(1)
	step(90)
	checks.arrival_releases_order = g.actors[0].position.distance_to(Vector2(350,235)) < 3 and not g.orders.active.has(0)
	g.reset_round(["lockpick","chat","strong"],11)
	checks.wall_target_rejected = not g.command_move(0,Vector2(495,200)) and g.status_text.contains("目标被")
	g.actors[0].position = Vector2(440,250)
	checks.closed_partition_rejected = not g.command_move(0,Vector2(570,250)) and g.status_text.contains("暂时走不到")
	g.world.open_door()
	checks.open_door_path_started = g.command_move(0,Vector2(570,250))
	step(120)
	checks.automatically_routes_through_door = g.actors[0].position.distance_to(Vector2(570,250)) < 3
	g.reset_round(["chat","lockpick","strong"],33)
	g.actors[1].position = Vector2(300,235)
	g.command_move(0,Vector2(420,235))
	var minimum: float = INF
	for i in range(180):
		g._process(DT)
		minimum = minf(minimum,g.actors[0].position.distance_to(g.actors[1].position))
	checks.routes_around_parked_friend = g.actors[0].position.distance_to(Vector2(420,235)) < 3 and minimum >= 33.98 and g.actors[1].position == Vector2(300,235)
	g.reset_round(["chat","lockpick","strong"],33)
	g.guard.position = Vector2(690,250)
	g.actors[0].position = Vector2(620,215)
	g.actors[1].position = Vector2(440,395)
	g.skills.toggle(0)
	g.skills.toggle(1)
	g.skills.tick(0.5)
	var progress: float = g.world.lock_progress
	g.command_move(2,Vector2(300,510))
	g.orders.tick(0.1)
	checks.other_order_keeps_actions = g.skills.actions.has(0) and g.skills.actions.has(1)
	g.command_move(1,Vector2(400,395))
	checks.operator_move_cancels_only_self = g.skills.actions.has(0) and not g.skills.actions.has(1) and g.world.lock_progress == progress
	g.capture_actor(1)
	checks.capture_clears_only_own_order = not g.orders.active.has(1) and g.orders.active.has(2)
	g.reset_round(["chat","lockpick","strong"],33)
	g.command_move(0,Vector2(110,235))
	step(12)
	checks.friendly_mirrors_left = g.presentation.visuals[0].flip_h and g.actors[0].facing.x < 0
	g.orders.stop(0)
	step(6)
	checks.idle_preserves_left = g.presentation.visuals[0].flip_h and g.presentation.visuals[0].frame_name == "idle"
	g.command_move(0,Vector2(300,235))
	step(12)
	checks.friendly_restores_right = not g.presentation.visuals[0].flip_h and g.actors[0].facing.x > 0
	g.guard.facing = Vector2.LEFT
	g.presentation.tick(0)
	checks.guard_mirrors_left = g.presentation.visuals[3].flip_h
	g.guard.facing = Vector2.RIGHT
	g.presentation.tick(0)
	checks.guard_restores_right = not g.presentation.visuals[3].flip_h
	g.reset_round(["chat","lockpick","strong"],33)
	g.world.open_door()
	g.actors[0].position = Vector2(920,440)
	click(MOUSE_BUTTON_RIGHT,Vector2(951,437))
	step(60)
	checks.right_click_exit_sign_extracts = g.actors[0].escaped
	checks.reset_clears_orders = true
	g.reset_round(["chat","lockpick","strong"],33)
	checks.reset_clears_orders = g.orders.active.is_empty()
	var report := {"passed":checks.values().all(func(v): return v == true),"checks":checks,"minimum_friend_distance":minimum,"snapshot":g.snapshot()}
	var file := FileAccess.open("res://docs/tests/p11-rts.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("RTS_CHECK ",JSON.stringify(report.checks)," passed=",report.passed)
	g.queue_free()
	await process_frame
	quit(0 if report.passed else 1)

extends SceneTree

var game
var checks := {}
var native := false
var canvas_width := 1200

func _initialize() -> void:
	call_deferred("run")

func minute(value: float) -> void:
	game.schedule.clock_elapsed = (value-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.presentation.tick(0)

func fresh() -> void:
	game.load_room("r04",["chat","lockpick","backpack"],45)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	for actor in game.actors:
		actor.immune_until = 0

func run() -> void:
	native = DisplayServer.get_name() != "headless"
	if native:
		var args := OS.get_cmdline_user_args()
		canvas_width = int(args[0]) if not args.is_empty() else 1200
		var height := 540 if canvas_width == 960 else 720
		root.content_scale_size = Vector2i(canvas_width,height)
		root.size = Vector2i(canvas_width,height)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	fresh()
	checks.initial_clear = not game.prison_alert.active and game.prison_alert.reinforcements.is_empty()
	game.actors[0].position = game.guard.position+Vector2(0,-55)
	game.guard.tick(0.1)
	checks.normal_day_no_arrest = game.captures == 0 and game.guard.state != "chasing"
	game.prison_alert.check_rollcall()
	checks.normal_day_no_missing_alarm = not game.prison_alert.active
	for actor in game.actors:
		actor.position = actor.home
	minute(1440)
	checks.midnight_not_automatic_alarm = not game.prison_alert.active
	var visited := [false,false,false]
	for frame in range(10800):
		game._process(1.0/60)
		for id in range(3):
			visited[id] = visited[id] or game.prison_alert.checked_rooms.has(id)
		if visited.all(func(x): return x):
			break
	checks.actual_three_rollcalls = visited.all(func(x): return x)
	checks.all_present_no_alarm = not game.prison_alert.active and game.captures == 0
	checks.normal_sleep_skip = game.schedule.can_skip_night()
	# Presence means being in one's own room, not specifically asleep on a bed.
	game.guard.position = game.actors[0].home+Vector2(65,0)
	game.actors[0].position = game.actors[0].home+Vector2(40,0)
	game.prison_alert.check_rollcall()
	checks.awake_in_own_room_present = not game.prison_alert.active
	# Same inspector later notices that this previously-present prisoner is gone.
	game.actors[0].position = Vector2(850,760)
	game.prison_alert.check_rollcall()
	checks.later_room_absence_detected = game.prison_alert.active and game.prison_alert.missing_ids == [0]
	checks.absent_location_not_known = game.prison_alert.reinforcements.all(func(g): return g.position.distance_to(game.actors[0].position) > 100)
	fresh()
	checks.reset_clears_all = not game.prison_alert.active and game.prison_alert.reinforcements.is_empty() and game.prison_alert.checked_rooms.is_empty()
	minute(1440)
	game.orders.clear()
	game.actors[0].position = game.actors[1].home+Vector2(40,0)
	game.guard.position = game.schedule.inspection_point(0)
	game.prison_alert.check_rollcall()
	checks.wrong_dorm_is_missing = game.prison_alert.active and game.prison_alert.missing_ids == [0]
	fresh()
	# Reproduce the screenshot: one escaped, two present, wait for a REAL visit.
	game.actors[0].escaped = true
	game.on_actor_escaped(0)
	minute(1440)
	checks.escaped_not_alarm_before_visit = not game.prison_alert.active
	checks.missing_cannot_skip_inspection = not game.schedule.can_skip_night()
	var clock: float = game.schedule.clock_elapsed
	game.schedule.skip_night()
	checks.skip_does_not_hide_missing = game.schedule.clock_elapsed == clock
	for frame in range(7200):
		game._process(1.0/60)
		if game.prison_alert.active:
			break
	checks.escaped_found_by_actual_visit = game.prison_alert.active and game.prison_alert.checked_rooms.has(0) and game.schedule.dormitory(0).grow(-17).has_point(game.guard.position)
	checks.two_reinforcements = game.prison_alert.reinforcements.size() == 2
	checks.all_police_alarm = game.prison_alert.officers().all(func(g): return g.global_alert() and g.curfew_alert() and g.search_zone() == game.world.bounds)
	checks.spawn_geometry = game.prison_alert.reinforcements.all(func(g): return game.world.can_place_circle(g.position,17,g,false))
	checks.distinct_search_routes = game.prison_alert.routes.values().map(func(r): return r[0]).size() == 5 and game.prison_alert.routes[game.guard.get_instance_id()][0] != game.prison_alert.routes[game.prison_alert.reinforcements[0].get_instance_id()][0]
	checks.gate_guards_activated = game.gate_watch.guards.all(func(g): return g.on_duty() and g.visible and not g.blocking_gate())
	checks.alarm_skip_disabled = not game.schedule.can_skip_night()
	checks.alarm_message = "全厂区警戒" in game.status_text
	var starts: Array = game.prison_alert.reinforcements.map(func(g): return g.position)
	var gate_starts: Array = game.gate_watch.guards.map(func(g): return g.position)
	var moved := [false,false]
	var gates_moved := [false,false]
	var reached_rooms := [false,false]
	for frame in range(7200):
		game._process(1.0/60)
		for index in range(2):
			var officer = game.prison_alert.reinforcements[index]
			moved[index] = moved[index] or officer.position.distance_to(starts[index]) > 100
			reached_rooms[index] = reached_rooms[index] or game.schedule.dormitory(0).grow(-17).has_point(officer.position)
			gates_moved[index] = gates_moved[index] or game.gate_watch.guards[index].position.distance_to(gate_starts[index]) > 100
		if moved.all(func(x): return x) and gates_moved.all(func(x): return x) and reached_rooms.all(func(x): return x):
			break
	checks.reinforcements_really_walk = moved.all(func(x): return x)
	checks.gate_guards_really_search = gates_moved.all(func(x): return x)
	checks.reinforcements_use_room_keys = reached_rooms.all(func(x): return x)
	checks.no_duplicate_deployment = game.prison_alert.reinforcements.size() == 2
	checks.sleeping_people_not_arrested = game.captures == 0
	game.presentation.tick(0)
	checks.all_flashlights = game.presentation.lighting.search_lights.size() == 4 and game.presentation.lighting.search_lights.values().all(func(l): return l.enabled and l.shadow_enabled)
	checks.animated_reinforcements = game.prison_alert.reinforcements.all(func(g): return g.get_child_count() > 0 and g.get_children()[0] in game.presentation.visuals)
	var old_positions: Array = game.prison_alert.officers().map(func(g): return g.position)
	game.routine_panel.open()
	game._process(1)
	checks.planner_pauses_search = paused and old_positions == game.prison_alert.officers().map(func(g): return g.position)
	game.routine_panel.close()
	minute(1440+480)
	game.routine_panel.close()
	checks.morning_alarm_persists = game.prison_alert.active and game.prison_alert.officers().all(func(g): return g.curfew_alert() and g.search_zone() == game.world.bounds)
	checks.morning_dog_active = game.schedule.dog_active()
	# Isolated capture fixture uses only a REAL reinforcement tick/navigation.
	game.orders.clear()
	game.routines.take_control(1)
	game.actors[1].position = Vector2(680,960)
	game.actors[1].immune_until = 0
	var officer = game.prison_alert.reinforcements[0]
	officer.position = Vector2(680,820)
	officer.release_target()
	checks.reinforcement_detects = officer.sees(game.actors[1].position)
	var captures_before: int = game.captures
	for frame in range(1200):
		game.elapsed += 1.0/60
		officer.tick(1.0/60)
		if game.captures > captures_before:
			break
	checks.reinforcement_actual_capture = game.captures == captures_before+1 and game.room_access.is_held(1) and game.actors[1].confined
	checks.captured_does_not_cancel_alarm = game.prison_alert.active
	game.guard.position = Vector2(680,420)
	game.actors[1].position = Vector2(540,420)
	checks.wall_blocks_alarm_vision = not game.guard.sees(game.actors[1].position)
	# Two officers use different cell doors; last update must not close the first.
	minute(1440+30)
	game.guard.position = game.world.dorm_doors[0].rect.get_center()+Vector2(0,40)
	officer.position = game.world.dorm_doors[1].rect.get_center()+Vector2(0,40)
	game.world.update_dorm_doors(true,game.inspection_positions())
	checks.multiple_keys_hold_doors = not game.world.dorm_doors[0].closed and not game.world.dorm_doors[1].closed
	if native:
		game.actors[1].position = game.actors[1].home
		game.select_actor(1)
		game.map_camera.locate_selected()
		game.presentation.tick(0)
		game._update_ui()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/tests/p52-rollcall-%d-night.png" % canvas_width)
		minute(1440+480)
		game.routine_panel.close()
		game.presentation.tick(0)
		game._update_ui()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/tests/p52-rollcall-%d-day.png" % canvas_width)
	checks.snapshot_alarm = game.snapshot().prison_alert.active
	game.phase = "failed"
	old_positions = game.prison_alert.officers().map(func(g): return g.position)
	game._process(1)
	checks.round_end_stops_search = old_positions == game.prison_alert.officers().map(func(g): return g.position)
	fresh()
	game.presentation.tick(0)
	checks.reset_removes_search_lights = game.presentation.lighting.search_lights.is_empty()
	checks.reset_restores_gate_posts = game.gate_watch.guards.all(func(g): return g.position == g.post and g.blocking_gate())
	checks.reset_visual_count = game.presentation.visuals.filter(func(v): return v.is_guard).size() == 3
	checks.reset_normal_day = not game.guard.curfew_alert() and not game.prison_alert.active
	for id in ["r01","r02","r03"]:
		game.load_room(id,["chat","lockpick","strong"],45)
		game.routine_panel.close()
		game.actors[0].escaped = true
		minute(1440)
		game.guard.position = game.schedule.inspection_point(0)
		game.prison_alert.check_rollcall()
		checks[id+"_alarm_compatible"] = game.prison_alert.active and game.prison_alert.reinforcements.size() == 2
		game.reset_round(["chat","lockpick","strong"],45)
		game.routine_panel.close()
		checks[id+"_reset"] = not game.prison_alert.active
	var passed: bool = checks.values().all(func(x): return x)
	var report := {"passed":passed,"checks":checks,"native":native,"visited":visited,"reinforcement_room_visits":reached_rooms,"scope":"Actual R04 rollcall, deployment, navigation, key use, captures, pause/reset and framebuffer. Explicit isolated position fixtures noted in QA. No claim of human playtesting."}
	FileAccess.open("res://docs/tests/p52-rollcall-"+("native-%d" % canvas_width if native else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("P52_ROLLCALL passed=",passed," count=",checks.size()," failed=",checks.keys().filter(func(k): return not checks[k])," room_visits=",reached_rooms)
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

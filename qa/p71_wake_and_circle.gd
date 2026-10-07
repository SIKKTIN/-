extends SceneTree

var game
var checks := {}
var arrivals: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(label: String, ok: bool) -> void:
	checks[label] = ok
	print(label+": "+str(ok))

func clock(minute: float) -> void:
	game.schedule.clock_elapsed = (minute-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.workshop.update_gate()
	game.routines.tick()

func reset() -> void:
	game.reset_round(["lockpick","chat","backpack"],71)
	game.routine_panel.close()
	game.schedule.set_time_speed(1)

func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.presentation.tick(0)
	game._update_ui()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p71-"+label+".png")

func run() -> void:
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	check("first_day_0720_planner_pauses",paused and game.routine_panel.panel.visible and absf(game.schedule.clock_minutes()-440)<0.001)
	check("wake_stage",str(game.schedule.config.stages[game.schedule.stage_index].id)=="wake_prepare")
	check("wake_unlocks_dorms",game.world.dorm_doors.all(func(g): return not g.closed))
	check("planner_note_mentions_0720_and_0800",game.routine_panel.note.text.contains("07:20") and game.routine_panel.note.text.contains("08:00"))
	await shot("wake-planner")
	reset()
	check("work_gate_open_for_preparation",not game.world.access_by_id("workshop-entry").closed)
	check("preparation_no_arrest",not game.workshop.on_duty() and not game.workshop.outside_violation(0) and not game.guard.pursuit_allowed(game.actors[0]))
	for step in range(155): game._process(0.05)
	check("arrive_before_0800",game.schedule.clock_minutes()<480 and game.actors.all(func(a): return game.workshop.area.grow(-17).has_point(a.position)))
	check("at_station_no_early_work_credit",game.routines.working_ids().is_empty() and game.inventory.wallet==0 and game.routines.work_minutes==[0.0,0.0,0.0])
	check("ready_status",game.routines.status_for(0).contains("到岗待命"))
	arrivals = game.actors.map(func(a): return [a.position.x,a.position.y])
	clock(480)
	game.workshop.tick(0)
	check("0800_closes_gate",game.world.access_by_id("workshop-entry").closed)
	check("0800_starts_work",game.routines.working_ids().size()==3)
	check("labor_perimeter_alert",game.guard.alert_mode() and game.gate_watch.guards.all(func(g): return g.alert_mode()))
	var officers: Array = game.guard.warning_officers()
	check("all_day_guards_full_circle",officers.all(func(g): return absf(g.half_fov()-PI)<0.00001))
	game.presentation.lighting.tick()
	check("all_guards_in_warning_render_list",officers.has(game.guard) and game.gate_watch.guards.all(func(g): return g in officers) and game.workshop.overseer in officers)
	check("day_avoids_per_guard_shadow_lights",game.presentation.lighting.search_lights.is_empty() and not game.presentation.lighting.guard_light.enabled)
	check("day_circle_light_texture",game.presentation.lighting.guard_light.texture==game.presentation.lighting.curfew_beam_texture)
	game.guard.position = Vector2(1600,1000)
	game.guard.facing = Vector2.DOWN
	check("circle_sees_behind",game.guard.sees(Vector2(1600,930)))
	game.guard.position = Vector2(780,690)
	game.guard.facing = Vector2.LEFT
	check("circle_wall_blocks",not game.guard.sees(Vector2(700,690)))
	var polygon: PackedVector2Array = game.guard.view_polygon()
	check("circle_has_no_origin_spoke",not polygon.has(Vector2.ZERO))
	game.guard.facing = Vector2.UP
	check("circle_does_not_rotate_with_facing",game.guard.view_polygon()==polygon)
	check("polygon_clipped_at_left_wall",Array(polygon).all(func(p): return game.guard.position.x+p.x>=744-0.02))
	game.map_camera.center_on(Vector2(1690,820))
	game.map_camera.following = false
	game.guard.position = Vector2(1530,930)
	await shot("day-circles")
	game.actors[0].position = Vector2(1600,1040)
	check("no_morning_late_arrival_grace",game.workshop.outside_violation(0))
	game.guard.position = Vector2(1600,1080)
	game.guard.facing = Vector2.DOWN
	game.guard.tick(0)
	check("circle_behind_starts_real_chase",game.guard.state=="chasing" and game.guard.target_id==0)
	game.workshop.update_gate()
	check("alarm_does_not_open_door_remotely",game.world.access_by_id("workshop-entry").closed)
	game.guard.position = game.actors[0].position+Vector2(0,35)
	game.guard.tick(0)
	check("actual_capture_two_hours",game.actors[0].confined and absf(game.room_access.held[0].until-game.schedule.absolute_minutes()-120)<0.01)
	clock(720)
	check("noon_opens_work_gate",not game.world.access_by_id("workshop-entry").closed)
	check("noon_cafeteria_opens",not game.world.access_by_id("cafeteria-entry").closed)
	check("noon_perimeter_stands_down",not game.guard.alert_mode())
	check("noon_remains_circle",game.guard.half_fov()==PI)
	reset()
	game.actors[0].position = game.world.access_by_id("workshop-entry").rect.get_center()
	game.orders.stop(0)
	clock(480)
	check("0800_closes_even_if_body_crossing",game.world.access_by_id("workshop-entry").closed)
	check("closing_body_not_stuck",game.world.can_place_circle(game.actors[0].position,17,game.actors[0],true))
	reset()
	game.actors[0].position = Vector2(1600,1040)
	game.mobile_controls.direction = Vector2.RIGHT
	var before: Vector2 = game.actors[0].position
	game.mobile_controls.tick(0.1)
	print("manual_move_distance="+str(game.actors[0].position.distance_to(before)))
	check("manual_wake_travel_matches_auto_speed",game.actors[0].position.distance_to(before)>50)
	game.mobile_controls.cancel_input()
	reset()
	game.schedule.set_time_speed(16)
	for step in range(34): game._process(1.0/60)
	check("speed16_arrives_by_0800",game.actors.all(func(a): return game.workshop.area.grow(-17).has_point(a.position)) and game.captures==0)
	check("speed16_gate_closed",game.world.access_by_id("workshop-entry").closed)
	reset()
	game.schedule.set_time_speed(16)
	clock(1879.9)
	game.routine_panel.close()
	game._process(0.2)
	check("high_speed_exact_0720_boundary",absf(game.schedule.absolute_minutes()-1880)<0.001 and paused and game.routine_panel.panel.visible)
	check("day2_default_plans",game.routines.day==2 and game.routines.plans==game.routines.default_plans())
	reset()
	for actor in game.actors: actor.position = actor.home
	clock(1500)
	game.orders.clear()
	check("sleep_can_skip",game.schedule.can_skip_night())
	game.schedule.skip_night()
	check("skip_night_to_0720",absf(game.schedule.absolute_minutes()-1880)<0.001 and paused and game.routine_panel.panel.visible)
	check("skip_night_unlocks_dorms",game.world.dorm_doors.all(func(g): return not g.closed))
	reset()
	clock(439)
	game.orders.clear()
	for actor in game.actors: actor.position = actor.home
	check("0719_still_sleep_and_locked",game.schedule.is_sleep_time() and game.world.dorm_doors.all(func(g): return g.closed))
	game.routines.day = 0
	game._process(0.3)
	check("0719_to_0720_planner_pause",absf(game.schedule.clock_minutes()-440)<0.001 and paused)
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var tag := "headless" if DisplayServer.get_name()=="headless" else "native"
	var report := {"checks":checks,"failed":failed,"total":checks.size(),"arrival_positions":arrivals,"map_sha256":FileAccess.get_sha256("res://data/rooms/r04.json")}
	FileAccess.open("res://docs/tests/p71-wake-circle-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)

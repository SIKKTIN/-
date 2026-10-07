extends SceneTree

var game
var checks := {}

func _initialize() -> void:
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks[label] = passed
	print(label+": "+str(passed))

func clock(minute: float) -> void:
	game.schedule.clock_elapsed = (minute-480.0)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.room_access.tick()
	game.workshop.update_gate()
	game.routines.tick()

func stations() -> void:
	for actor in game.actors:
		actor.position = game.routines._target(actor.actor_id,"work")
		game.routines.resume(actor.actor_id)
	game.orders.clear()
	game.workshop.update_gate()

func screenshot(name_text: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.presentation.tick(0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/tests/p69-"+name_text+".png")

func run() -> void:
	root.size = Vector2i(1200,720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],69)
	var override_path := OS.get_environment("ESCAPE_P69_MAP_PATH")
	if not override_path.is_empty():
		game.room_config = JSON.parse_string(FileAccess.get_file_as_string(override_path))
		game.world.configure(game.room_config,game.actors)
		game.guard.configure(game.world,game)
		game.reset_round(["lockpick","chat","backpack"],69)
	game.routine_panel.close()
	game.schedule.set_time_speed(1)
	check("arrival_gate_open",not game.world.access_by_id("workshop-entry").closed)
	for step in range(120): game._process(0.2)
	game.schedule.set_time_speed(0)
	print("COMMUTE "+JSON.stringify({"positions":game.actors.map(func(a): return a.position),"routines":game.routines.snapshot(),"orders":game.orders.snapshot(),"merchants":game.trade.actors.values().map(func(a): return {"position":a.position,"goal":a.goal})}))
	check("natural_commute_all_work",game.routines.working_ids().size() == 3)
	check("commute_no_arrests",game.captures == 0)
	clock(550)
	check("work_gate_locked",game.world.access_by_id("workshop-entry").closed)
	check("closed_gate_physical",not game.world.motion_clear(Vector2(1190,750),Vector2(1190,870)))
	check("south_left_wall_physical",not game.world.motion_clear(Vector2(950,750),Vector2(950,870)))
	check("south_right_wall_physical",not game.world.motion_clear(Vector2(1600,750),Vector2(1600,870)))
	check("left_wall_complete",not game.world.motion_clear(Vector2(680,690),Vector2(780,690)))
	game.actors[0].position = Vector2(1190,765)
	for step in range(30):
		game.world.move_actor(game.actors[0],Vector2(0,8))
		game.workshop.update_gate()
	check("approaching_locked_gate_does_not_open",game.world.access_by_id("workshop-entry").closed and game.actors[0].position.y < 800)
	var builds: int = game.world.obstacle_revision
	for step in range(80): game.workshop.update_gate()
	check("gate_no_rebuild_each_frame",game.world.obstacle_revision == builds)
	game.actors[0].position = Vector2(1070,650)
	game.map_camera.center_on(Vector2(1360,580))
	await screenshot("locked-workshop")
	stations()
	game.stop_selected()
	var overseer = game.workshop.overseer
	overseer.position = Vector2(680,330)
	game.workshop.tick(3)
	check("wall_occludes_slacking_detection",not game.workshop.warnings.has(0))
	for step in range(10):
		overseer.position = Vector2(1030,350)
		game.workshop.tick(0.2)
	check("visible_slacking_warning",game.workshop.warnings.has(0) and game.captures == 0)
	game.presentation.interaction.refresh()
	check("right_work_button",game.presentation.interaction.targets.any(func(t): return t.kind == "work"))
	var old_warning: float = game.workshop.warnings[0]
	paused = true
	game.workshop.tick(20)
	check("paused_no_warning_progress",game.workshop.warnings[0] == old_warning and game.captures == 0)
	paused = false
	check("manual_return_to_work",game.workshop.start_work(0))
	game.workshop.tick(0.1)
	check("work_clears_warning",game.routines.is_working(0) and not game.workshop.warnings.has(0))
	game.stop_selected()
	for step in range(45):
		overseer.position = Vector2(1030,350)
		game.workshop.tick(0.2)
	check("persistent_slacking_chased",game.workshop.wanted.has(0))
	game.map_camera.tick(1)
	await screenshot("slacking-warning")
	for step in range(160):
		game.elapsed += 0.1
		game.workshop.tick(0.1)
		if game.actors[0].confined: break
	check("actual_chase_captures",game.actors[0].confined and game.captures == 1)
	check("two_hour_confinement",absf(game.room_access.held.get(0,{}).get("until",0)-game.schedule.absolute_minutes()-120) < 0.01)
	clock(670)
	check("timed_release",not game.actors[0].confined)
	game.workshop.update_gate()
	check("release_commute_grace",float(game.workshop.grace.get(0,0)) > game.schedule.absolute_minutes())
	clock(720)
	check("noon_gate_open",not game.world.access_by_id("workshop-entry").closed)
	check("noon_no_supervision",not game.workshop.on_duty() and game.workshop.wanted.is_empty())
	clock(840)
	check("afternoon_arrival_open",not game.world.access_by_id("workshop-entry").closed)
	stations()
	clock(930)
	check("afternoon_locked",game.world.access_by_id("workshop-entry").closed)
	for step in range(80): game.workshop.tick(0.1)
	check("working_npcs_not_arrested",not game.actors[1].confined and not game.actors[2].confined)
	clock(1080)
	check("evening_open",not game.world.access_by_id("workshop-entry").closed)
	check("evening_clear_warnings",game.workshop.warnings.is_empty() and game.workshop.wanted.is_empty())
	game.actors[0].position = game.guard.position+Vector2(0,38)
	game.routines.take_control(0)
	for step in range(50): game.guard.tick(0.1)
	check("normal_day_patrol_no_arrest",not game.actors[0].confined)
	game.reset_round(["lockpick","chat","backpack"],69)
	game.routine_panel.close()
	check("reset_one_overseer",game.presentation.visuals.filter(func(v): return v.actor.has_method("is_workshop_overseer")).size() == 1)
	stations()
	clock(570)
	game.stop_selected()
	game.actors[0].position = Vector2(680,960)
	for step in range(90):
		game.elapsed += 0.2
		game.workshop.tick(0.2)
		if game.actors[0].confined: break
	check("absentee_actual_search_capture",game.actors[0].confined)
	game.load_room("r01",["lockpick","chat","backpack"],69)
	game.routine_panel.close()
	check("other_maps_no_overseer",game.workshop.overseer == null and game.workshop.config.is_empty())
	check("no_stale_visual",game.presentation.visuals.filter(func(v): return v.actor.has_method("is_workshop_overseer")).is_empty())
	var document = load("res://scripts/editor/map_document.gd").new()
	document.open_file("res://data/rooms/r04.json" if override_path.is_empty() else override_path)
	var validation: Dictionary = document.validate()
	check("editor_valid_map",validation.errors.is_empty())
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"checks":checks,"failed":failed,"validation":validation}
	var tag := OS.get_environment("ESCAPE_P69_REPORT_TAG")
	if tag.is_empty(): tag = "headless" if DisplayServer.get_name() == "headless" else "native"
	FileAccess.open("res://docs/tests/p69-workshop-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)

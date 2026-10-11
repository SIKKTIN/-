extends SceneTree

var game
var checks := {}

func _initialize():
	call_deferred("run")

func run():
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH", "user://p90-diagnostic.cfg")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.schedule.clock_elapsed = (557.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.workshop.update_gate()
	game.routines.take_control(0)
	game.orders.clear()
	game.actors[0].position = Vector2(1080,540)
	game.actors[0].immune_until = 0
	for actor in game.actors.slice(1): actor.immune_until = INF
	var officer = game.workshop.overseer
	game.staff_traffic.records[officer.get_instance_id()].status = "duty"
	officer.position = Vector2(1220,788)
	checks.screenshot_estimate_seen = officer.sees(game.actors[0].position)
	checks.player_clear = game.world.can_place_circle(game.actors[0].position,8,game.actors[0])
	game.workshop.tick(0.1)
	checks.warning_on_detection = game.workshop.warnings.has(0) and not game.workshop.wanted.has(0)
	var initial: float = game.workshop.warnings.get(0,0)
	for i in range(100):
		officer.position = Vector2(2050,600)
		game.workshop.tick(0.1)
	checks.hidden_timer_paused = is_equal_approx(initial,game.workshop.warnings.get(0,-1)) and not game.workshop.wanted.has(0)
	checks.hidden_warning_retained = not game.workshop.warning_label(0).is_empty()
	game.workshop.warnings.clear()
	for i in range(79):
		officer.position = Vector2(1220,788)
		game.workshop.tick(0.1)
	checks.before_eight_seconds_warning = not game.workshop.wanted.has(0)
	for i in range(2):
		officer.position = Vector2(1220,788)
		game.workshop.tick(0.1)
	checks.after_eight_seconds_chasing = game.workshop.wanted.has(0) and officer.state == "chasing" and officer.target_id == 0
	for i in range(400):
		game.elapsed += 0.05
		game.world.begin_ai_paths()
		game.workshop.tick(0.05)
		game.world.end_ai_paths()
		if game.actors[0].confined: break
	checks.actual_walk_capture = game.actors[0].confined
	var failed = checks.keys().filter(func(k): return not checks[k])
	var report = {"checks":checks,"failed":failed,"warning_seconds":game.workshop.config.warning_seconds,"initial_warning":initial,"captures":game.captures}
	FileAccess.open("res://docs/tests/p90-warning-diagnostic.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)

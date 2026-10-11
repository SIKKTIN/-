extends SceneTree

var game
var checks := {}
var officer

func _initialize(): call_deferred("run")

func check(label: String, passed: bool):
	checks[label] = passed
	print(label+": "+str(passed))

func clock(minute: float):
	game.schedule.clock_elapsed = (minute-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.workshop.update_gate()
	game.routines.tick()
	game.routine_panel.close()

func idle():
	game.routines.take_control(0)
	game.orders.stop(0)

func working():
	game.actors[0].position = game.routines._target(0,"work")
	game.actors[0].action_state = "idle"
	game.workshop.start_work(0)
	game.orders.stop(0)

func tick(seconds: float, hide_officer := true):
	if hide_officer: officer.position = Vector2(2050,600)
	game.world.begin_ai_paths()
	game.workshop.tick(seconds)
	game.world.end_ai_paths()

func capture_screen(label: String):
	game.map_camera.center_on(game.actors[0].position)
	game.room_visibility.tick(0.25)
	game.presentation.tick(0)
	game.fullscreen_ui.layout()
	game.fullscreen_ui.refresh_warning(false)
	if DisplayServer.get_name() == "headless": return
	# Render long enough for the live FPS sampler; simulation stays frozen
	# at the tested warning/recovery value for a legible native screenshot.
	for frame in range(90): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/tests/p90-"+label+".png")

func run():
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p90-warning-qa.cfg")
	OS.set_environment("ESCAPE_FRAME_MODE","60")
	root.size = Vector2i(1200,720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	clock(557)
	officer = game.workshop.overseer
	game.staff_traffic.records[officer.get_instance_id()].status = "duty"
	for actor in game.actors: actor.immune_until = 0
	for actor in game.actors.slice(1):
		actor.position = game.routines._target(actor.actor_id,"work")
		game.routines.resume(actor.actor_id)
		game.orders.stop(actor.actor_id)
	game.actors[0].position = Vector2(1080,540)
	idle()
	check("three_second_setting",is_equal_approx(game.workshop.warning_seconds(),3))
	tick(1)
	check("unseen_without_prior_warning_is_safe",not game.workshop.warnings.has(0))
	officer.position = Vector2(1220,788)
	check("visible_detection_fixture",officer.sees(game.actors[0].position))
	tick(0.5,false)
	check("detection_starts_countdown",is_equal_approx(game.workshop.warning_remaining(0),2.5) and not game.workshop.wanted.has(0))
	await capture_screen("countdown-1200")
	check("countdown_ui",game.fullscreen_ui.warning_title.text.contains("2.5秒后追捕") and game.fullscreen_ui.warning_meter.visible and is_equal_approx(game.fullscreen_ui.warning_meter.value,0.5))
	paused = true
	tick(10)
	check("pause_freezes_countdown",is_equal_approx(game.workshop.warning_level(0),0.5))
	paused = false
	tick(2.4)
	check("hidden_countdown_continues",is_equal_approx(game.workshop.warning_level(0),2.9) and not game.workshop.wanted.has(0))
	tick(0.1)
	check("three_seconds_triggers_chase",game.workshop.wanted.has(0) and officer.state == "chasing" and officer.target_id == 0)
	working()
	check("actual_work_fixture",game.routines.is_working(0))
	tick(0)
	check("starting_work_does_not_reset_chase",game.workshop.wanted.has(0) and is_equal_approx(game.workshop.warning_level(0),3))
	tick(1)
	check("work_cools_at_half_rate",game.workshop.wanted.has(0) and is_equal_approx(game.workshop.warning_level(0),2.5) and is_equal_approx(game.workshop.recovery_seconds(0),5))
	game.fullscreen_ui.refresh_warning(false)
	check("chase_recovery_ui",game.fullscreen_ui.warning_detail.text.contains("5.0秒") and game.fullscreen_ui.warning_fill.bg_color == Color("318f83"))
	paused = true
	tick(10)
	check("pause_freezes_recovery",is_equal_approx(game.workshop.warning_level(0),2.5))
	paused = false
	idle()
	tick(0.2)
	check("stop_work_retains_chase",game.workshop.wanted.has(0) and is_equal_approx(game.workshop.warning_level(0),2.5))
	working()
	tick(4.9)
	check("chase_survives_partial_recovery",game.workshop.wanted.has(0) and game.workshop.warning_level(0)>0)
	tick(0.1)
	check("six_seconds_actual_work_clears",not game.workshop.wanted.has(0) and not game.workshop.warnings.has(0) and officer.state == "patrol")
	# Reach a genuine warning again, then briefly resume work and stop.
	idle()
	game.actors[0].position = Vector2(1080,540)
	officer.position = Vector2(1220,788)
	tick(2,false)
	working()
	tick(0.2)
	check("brief_work_retains_warning",is_equal_approx(game.workshop.warning_level(0),1.9) and not game.workshop.wanted.has(0))
	await capture_screen("recovering-1200")
	check("warning_recovery_ui",game.fullscreen_ui.warning_title.text.contains("还需3.8秒") and game.fullscreen_ui.warning_detail.text.contains("停工继续倒计时"))
	idle()
	tick(0.1)
	check("resume_slacking_uses_remaining_heat",is_equal_approx(game.workshop.warning_level(0),2.0))
	for i in range(7):
		working()
		tick(0.1)
		idle()
		tick(0.2)
	check("rapid_work_idle_toggling_cannot_evade",game.workshop.wanted.has(0))
	game.workshop.wanted.clear()
	game.workshop.warnings[0] = 2.0
	officer.release_target()
	var goal: Vector2 = game.routines._target(0,"work")
	var approach := goal
	for offset in [Vector2(0,50),Vector2(50,0),Vector2(-50,0),Vector2(0,-50)]:
		if game.world.can_place_circle(goal+offset,8,game.actors[0]) and game.world.line_clear(goal+offset,goal):
			approach = goal+offset
			break
	game.actors[0].position = approach
	idle()
	check("return_order_fixture",approach != goal and game.workshop.start_work(0) and not game.routines.is_working(0))
	tick(0.2)
	check("walking_to_work_does_not_cool",is_equal_approx(game.workshop.warning_level(0),2.2))
	working()
	tick(1)
	root.size = Vector2i(960,540)
	await process_frame
	await capture_screen("recovering-960")
	check("compact_ui_meter_inside_banner",game.fullscreen_ui.warning_banner.get_rect().end.x <= 960 and game.fullscreen_ui.warning_meter.get_rect().end.y <= game.fullscreen_ui.warning_banner.size.y)
	clock(720)
	check("shift_end_clears_all_warning",game.workshop.warnings.is_empty() and game.workshop.wanted.is_empty())
	game.fullscreen_ui.refresh_warning(false)
	check("off_shift_ui_hidden",not game.fullscreen_ui.warning_banner.visible)
	clock(840)
	check("next_shift_starts_clean",not game.workshop.warnings.has(0))
	clock(2000)
	check("next_day_starts_clean",game.workshop.warnings.is_empty() and game.workshop.wanted.is_empty())
	game.actors[0].position = Vector2(740,600)
	idle()
	game.workshop.grace[0] = 0
	officer.position = Vector2(740,700)
	tick(0.01,false)
	check("outside_seen_still_immediate_chase",game.workshop.wanted.has(0) and officer.state == "chasing")
	for i in range(300):
		game.elapsed += 0.05
		tick(0.05,false)
		if game.actors[0].confined: break
	check("real_chase_walks_and_captures",game.actors[0].confined and game.captures == 1)
	check("capture_clears_warning",not game.workshop.wanted.has(0) and not game.workshop.warnings.has(0))
	var failed = checks.keys().filter(func(k): return not checks[k])
	var tag := "headless" if DisplayServer.get_name() == "headless" else "native"
	FileAccess.open("res://docs/tests/p90-warning-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"warning_seconds":3,"recovery_rate":0.5},"\t"))
	print(JSON.stringify({"checks":checks,"failed":failed}))
	quit(0 if failed.is_empty() else 1)

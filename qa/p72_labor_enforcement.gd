extends SceneTree

var game
var checks := {}

func _initialize() -> void:
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks[label] = passed
	print(label+": "+str(passed))

func clock(minute: float) -> void:
	game.schedule.clock_elapsed = (minute-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.room_access.tick()
	game.workshop.update_gate()
	game.routines.tick()

func setup() -> void:
	game.reset_round(["lockpick","chat","backpack"],70)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	clock(600)
	for actor in game.actors:
		actor.position = game.routines._target(actor.actor_id,"work")
		game.routines.resume(actor.actor_id)
	game.orders.clear()
	game.workshop.update_gate()

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.presentation.tick(0)
	game.fullscreen_ui.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/tests/p72-"+label+".png")

func run() -> void:
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],70)
	setup()
	game.fullscreen_ui.refresh()
	check("only_main_card_visible",game.cards[0].visible and not game.cards[1].visible and not game.cards[2].visible)
	check("npcs_still_autonomous",game.routines.is_working(1) and game.routines.is_working(2))
	check("admitted_all",game.workshop.admitted.size() == 3)
	check("inside_main_safe",not game.guard.pursuit_allowed(game.actors[0]))
	game.stop_selected()
	check("inside_manual_only_supervisor",not game.guard.pursuit_allowed(game.actors[0]))
	game.actors[0].position = Vector2(1600,1040)
	check("outside_labor_violation",game.workshop.outside_violation(0))
	game.fullscreen_ui.refresh()
	check("persistent_outside_banner",game.fullscreen_ui.warning_banner.visible and game.fullscreen_ui.warning_title.text.contains("脱离"))
	game.show_status("工资 +4",1)
	game.elapsed += 10
	game.fullscreen_ui.refresh()
	check("toast_does_not_override_alert",game.fullscreen_ui.warning_banner.visible and not game.fullscreen_ui.toast.visible)
	for dimensions in [Vector2i(1200,720),Vector2i(960,540)]:
		root.size = dimensions
		root.content_scale_size = root.size
		game.fullscreen_ui.layout()
		game.fullscreen_ui.refresh()
		var ui = game.fullscreen_ui
		var r: Rect2 = ui.warning_banner.get_global_rect()
		check("safe_banner_"+str(dimensions.x),ui.safe_area().encloses(r) and not r.intersects(game.cards[0].get_global_rect()) and not r.intersects(game.mini_map.get_global_rect()) and not r.intersects(game.mobile_controls.pad.get_global_rect()) and not r.intersects(ui.action_button.get_global_rect()))
		game.map_camera.center_on(Vector2(1480,970))
		await shot("outside-"+str(dimensions.x))
	game.routine_panel.open()
	game.fullscreen_ui.refresh()
	check("alert_hidden_under_paused_planner",paused and not game.fullscreen_ui.warning_banner.visible)
	game.guard.position = game.actors[0].position+Vector2(0,35)
	game.guard.facing = Vector2.UP
	game.guard.tick(1)
	check("paused_guard_cannot_capture",not game.actors[0].confined)
	game.routine_panel.close()
	game.guard.tick(0)
	check("patrol_immediate_arrest",game.actors[0].confined)
	setup()
	game.actors[0].position = Vector2(2050,1050)
	var gate = game.gate_watch.guards[1]
	gate.facing = gate.position.direction_to(game.actors[0].position)
	gate.tick(0)
	check("gate_guard_sees_and_chases",gate.state == "chasing" and gate.target_id == 0)
	check("outside_seen_shared_wanted",game.workshop.wanted.has(0))
	game.fullscreen_ui.refresh()
	check("chase_banner_count",game.fullscreen_ui.warning_title.text.contains("追捕") and game.fullscreen_ui.warning_detail.text.contains("1名"))
	await shot("gate-chase")
	for step in range(100):
		game.elapsed += 0.1
		gate.tick(0.1)
		if game.actors[0].confined: break
	check("gate_guard_actual_capture",game.actors[0].confined)
	check("two_hour_sentence",absf(game.room_access.held.get(0,{}).get("until",0)-game.schedule.absolute_minutes()-120) < 0.01)
	game.fullscreen_ui.refresh()
	check("alert_clears_in_custody",not game.fullscreen_ui.warning_banner.visible)
	setup()
	game.actors[0].position = Vector2(1600,1040)
	game.workshop.overseer.position = Vector2(1600,1090)
	game.workshop.tick(0)
	check("overseer_outside_immediate_chase",game.workshop.overseer.state == "chasing" and game.workshop.wanted.has(0))
	setup()
	var extra = load("res://scripts/actors/guard.gd").new()
	game.add_child(extra)
	extra.configure(game.world,game)
	game.prison_alert.reinforcements.append(extra)
	game.gate_watch.attach_visual(extra)
	game.actors[0].position = Vector2(1600,1040)
	extra.position = Vector2(1600,1090)
	extra.facing = Vector2.UP
	extra.tick(0)
	check("reinforcement_immediate_chase",extra.state == "chasing" and extra.target_id == 0)
	for step in range(30):
		extra.tick(0.1)
		if game.actors[0].confined: break
	check("reinforcement_actual_capture",game.actors[0].confined)
	setup()
	game.actors[0].position = Vector2(1600,1040)
	game.guard.position = Vector2(1600,1090)
	game.guard.facing = Vector2.DOWN
	game.guard.tick(0)
	check("day_circle_detects_behind",game.guard.target_id == 0)
	game.guard.release_target()
	game.actors[0].position = Vector2(700,690)
	game.guard.position = Vector2(780,690)
	game.guard.facing = Vector2.LEFT
	game.guard.tick(0)
	check("wall_still_blocks_detection",game.guard.target_id == -1)
	game.actors[0].position = Vector2(1600,1040)
	# A chosen daily plan cannot legalize being outside the labor room.
	game.routines.plans[0][0] = "free"
	game.routines.records[0] = {"kind":"free","goal":game.actors[0].position,"status":"arrived","retry":INF}
	game.routines.manual.erase(0)
	check("lawful_routine_outside_still_illegal",game.routines.is_lawful(0) and game.guard.pursuit_allowed(game.actors[0]))
	clock(720)
	game.guard.position = game.actors[0].position+Vector2(0,-35)
	game.guard.facing = Vector2.DOWN
	game.guard.tick(0)
	game.fullscreen_ui.refresh()
	check("lunch_no_day_arrest",not game.actors[0].confined and game.guard.state != "chasing")
	check("lunch_clears_warning",not game.fullscreen_ui.warning_banner.visible)
	var returning_gate = game.gate_watch.guards[0]
	returning_gate.position = Vector2(550,990)
	for step in range(80): returning_gate.tick(0.1)
	check("gate_returns_after_outside_chase",returning_gate.position.x > 624 and returning_gate.target_id == -1)
	clock(1080)
	check("free_time_no_violation",not game.workshop.outside_violation(0))
	game.reset_round(["lockpick","chat","backpack"],70)
	game.routine_panel.close()
	game.workshop.update_gate()
	check("arrival_grace_no_arrest",not game.workshop.outside_violation(0))
	game.actors[0].position = game.routines._target(0,"work")
	game.workshop.update_gate()
	game.actors[0].position = Vector2(1600,1040)
	clock(480)
	check("early_exit_not_new_grace",game.workshop.outside_violation(0))
	game.capture_actor(0)
	game.room_access.release(0)
	check("release_return_grace",not game.workshop.outside_violation(0))
	game.actors[0].position = game.routines._target(0,"work")
	game.workshop.update_gate()
	game.actors[0].position = Vector2(1600,1040)
	check("release_grace_consumed_on_entry",game.workshop.outside_violation(0))
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game.fullscreen_ui.layout()
	game.fullscreen_ui.refresh()
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var tag := "headless" if DisplayServer.get_name() == "headless" else "native"
	FileAccess.open("res://docs/tests/p72-enforcement-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks,"failed":failed}))
	quit(0 if failed.is_empty() else 1)

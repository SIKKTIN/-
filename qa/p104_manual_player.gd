extends "res://qa/p101_npc_responses.gd"

func _initialize():
	create_timer(60).timeout.connect(func():quit(124))
	call_deferred("run")

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p104-manual.cfg")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.reset_round(["backpack","chat","backpack"],72)
	game.schedule.set_time_speed(1)
	game.actors[0].immune_until = INF
	var home: Vector2 = game.actors[0].position
	check("player_starts_without_any_automatic_plan",game.routines.plans[0].all(func(v):return v=="idle") and not game.routines.records.has(0) and not game.orders.active.has(0))
	for minute in [540,720,810,840,1020,1200,1440,1920]:
		clock(minute)
		game.npc_life.tick(1)
		check("no_player_schedule_at_"+str(minute),game.actors[0].position==home and not game.orders.active.has(0) and not game.routines.records.has(0))
	game.routines.resume(0)
	var plan: Array = game.routines.plans.duplicate(true)
	plan[0] = ["work","meal","work","free","free"]
	check("old_planner_cannot_reenable_autoplay",not game.routines.apply_today(plan) and not game.routines.records.has(0) and not game.orders.active.has(0))
	reset("backpack",600)
	game.actors[0].immune_until = INF
	check("standing_at_workstation_does_not_start_work",not game.routines.is_working(0) and not game.routines.records.has(0))
	check("explicit_work_command_starts_only_one_action",game.workshop.start_work(0) and game.routines.records[0].player_action and game.routines.is_working(0) and game.routines.plans[0].all(func(v):return v=="idle"))
	game.schedule.set_time_speed(1)
	for i in range(190): game._process(0.2)
	check("manual_work_still_earns_real_wages",game.inventory.wallet>=game.routines.work_wage())
	game.stop_selected()
	for i in range(5): game._process(0.2)
	check("stopping_work_does_not_resume_it",not game.routines.is_working(0) and not game.routines.records.has(0) and not game.orders.active.has(0))
	reset("backpack",740)
	game.actors[0].immune_until = INF
	check("no_automatic_player_lunch",not game.routines.records.has(0) and game.routines.meal_minutes[0]==0)
	var pickup: Array = game.room_config.routine_points.meal[0]
	game.actors[0].position = Vector2(pickup[0],pickup[1])
	check("explicit_meal_command_is_tagged_as_player_action",game.routines.start_meal(0) and game.routines.records[0].player_action)
	game.schedule.set_time_speed(1)
	for i in range(500):
		game._process(0.2)
		if game.routines.meal_minutes[0]>=20: break
	var after_meal: Vector2 = game.actors[0].position
	check("meal_completion_does_not_send_player_to_free_time",is_equal_approx(game.routines.meal_minutes[0],20) and not game.routines.records.has(0) and not game.orders.active.has(0))
	clock(810)
	check("afternoon_preparation_does_not_move_player",game.actors[0].position==after_meal and not game.orders.active.has(0))
	reset("backpack",1190)
	game.actors[0].immune_until = INF
	var origin: Vector2 = game.actors[0].position
	check("manual_route_is_valid",game.command_move(0,origin+Vector2(-60,0)))
	clock(1200)
	check("curfew_does_not_replace_or_stop_players_route",game.orders.active.has(0) and game.orders.active[0].source=="manual" and game.actors[0].position==origin)
	clock(1440)
	check("midnight_does_not_auto_return_player",game.orders.active.has(0) and game.orders.active[0].source=="manual" and game.actors[0].position==origin)
	reset("backpack",839)
	var gate: Dictionary = game.world.access_by_id("cafeteria-entry")
	var area: Array = gate.room_rect
	game.actors[0].position = Rect2(area[0],area[1],area[2],area[3]).get_center()
	game.routines.take_control(0)
	game.orders.stop(0)
	origin = game.actors[0].position
	clock(840)
	check("closing_room_requires_player_to_leave_manually",game.actors[0].position==origin and not game.orders.active.has(0))
	reset("backpack",740)
	game.routines.meal_minutes[1] = 20
	game.routines.meal_minutes[2] = 20
	game.actors[1].position = Vector2(1120,1300)
	game.actors[2].position = Vector2(1050,1300)
	game.actors[0].position = Vector2(750,1300)
	game.orders.clear()
	game.attributes.values[1].stamina = 100
	game.attributes.values[2].stamina = 35
	var first: String = game.npc_life.choose("prisoner:1",true)
	var second: String = game.npc_life.choose("prisoner:2",true)
	check("npcs_choose_independently_from_needs_and_personality",first=="socialize" and second=="rest" and game.npc_life.people["prisoner:1"].decision.candidates.size()==3)
	game.social.now += 9
	game.social.people["prisoner:1"].mood.fear = 95
	check("fear_changes_a_social_persons_leisure_decision",game.npc_life.choose("prisoner:1",true)=="rest")
	game.npc_life.tick(1)
	check("npc_rest_has_a_real_destination",game.routines.records[2].kind=="rest" and game.routines.records[2].goal==game.actors[2].home)
	check("every_human_npc_has_its_own_life_state",game.npc_life.people.size()==game.social.people.size()-1 and not game.npc_life.people.has("prisoner:0") and game.npc_life.people.has("merchant:prison_dealer") and game.npc_life.people.has("guard:patrol"))
	var decisions: int = game.npc_life.decisions
	for i in range(600): game.npc_life.tick(1.0/60)
	check("life_decisions_are_throttled",game.npc_life.decisions-decisions<=2)
	decisions = game.npc_life.decisions
	paused = true
	game.npc_life.tick(100)
	paused = false
	check("pause_stops_npc_life",game.npc_life.decisions==decisions)
	if DisplayServer.get_name()!="headless":
		game.actors[0].position = Vector2(1120,1400)
		game.map_camera.center_on(Vector2(1150,1300))
		game.room_visibility.tick(1,true)
		game.presentation.tick(0)
		game.fullscreen_ui.layout()
		game.fullscreen_ui.refresh()
		game.fullscreen_ui.fps_badge.hide()
		await frame()
		root.get_texture().get_image().save_png("res://docs/tests/p104-independent-life.png")
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	var tag := "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open("res://docs/tests/p104-manual-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"life":game.npc_life.snapshot()},"\t"))
	print(JSON.stringify({"failed":failed,"total":checks.size()}))
	quit(0 if failed.is_empty() else 1)

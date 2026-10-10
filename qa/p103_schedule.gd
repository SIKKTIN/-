extends "res://qa/p101_npc_responses.gd"

func minutes_elapsed(minute: float) -> float:
	return (minute-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds

func pay_window(start: float, end: float) -> Dictionary:
	var credit: Dictionary = game.attributes.accrue(minutes_elapsed(start),minutes_elapsed(end),["work","work","work"])
	game.routines.accrue_work(minutes_elapsed(start),minutes_elapsed(end),[0,1,2],credit)
	return credit

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p103-schedule.cfg")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	reset("backpack",480)
	game.schedule.set_time_speed(1)
	check("all_rooms_have_fifteen_minute_days",game.schedule.day_seconds==900 and game.schedule.config.room_seconds.values().all(func(v):return v==900))
	check("wake_at_eight_with_full_three_days",game.schedule.clock_minutes()==480 and game.schedule.limit_seconds==2700 and game.schedule.remaining()==2700)
	game.schedule.advance(60)
	check("one_real_minute_advances_96_game_minutes",is_equal_approx(game.schedule.clock_minutes(),576))
	check("daily_labor_is_six_hours",game.schedule.work_window(600)==Vector2(540,720) and game.schedule.work_window(900)==Vector2(840,1020))
	for sample in [[479,"sleep",false],[480,"wake_prepare",false],[539.99,"wake_prepare",false],[540,"morning_work",true],[719.99,"morning_work",true],[720,"meal_rest",false],[839.99,"meal_rest",false],[840,"afternoon_work",true],[1019.99,"afternoon_work",true],[1020,"free_time",false],[1199.99,"free_time",false],[1200,"dorm_free",false]]:
		clock(float(sample[0]))
		for actor in game.actors: actor.position = game.routines._target(actor.actor_id,"work")
		game.workshop.update_gate()
		check("boundary_"+str(sample[0]),game.schedule.config.stages[game.schedule.stage_index].id==sample[1] and game.workshop.on_duty()==sample[2] and game.world.access_by_id("workshop-entry").closed==sample[2])
		if sample[0] in [539.99,1020]:
			check("no_work_or_escape_penalty_"+str(sample[0]),not game.workshop.start_work(0) and not game.workshop.outside_violation(0) and not game.routines.is_working(1))
	reset("backpack",540)
	game.inventory.wallet = 0
	var credit := pay_window(540,720)
	check("morning_has_three_actual_paid_hours",is_equal_approx(credit[0],180) and game.inventory.wallet==3*game.routines.work_wage())
	var before: int = game.inventory.wallet
	pay_window(720,780)
	check("no_wages_after_noon",game.inventory.wallet==before)
	reset("backpack",840)
	game.inventory.wallet = 0
	credit = pay_window(840,1020)
	check("afternoon_has_three_actual_paid_hours",is_equal_approx(credit[0],180) and game.inventory.wallet==3*game.routines.work_wage())
	before = game.inventory.wallet
	pay_window(1020,1080)
	check("no_wages_after_five",game.inventory.wallet==before)
	reset("backpack",539)
	credit = pay_window(539,540)
	check("no_work_credit_before_nine",credit.is_empty())
	reset("backpack",719)
	credit = pay_window(719,721)
	check("long_frame_does_not_work_past_noon",is_equal_approx(credit[0],1))
	reset("backpack",1019)
	credit = pay_window(1019,1021)
	check("long_frame_does_not_work_past_five",is_equal_approx(credit[0],1))
	reset("backpack",1440)
	for actor in game.actors: actor.position = actor.home; actor.action_state = "idle"
	game.orders.clear()
	check("night_can_still_be_skipped",game.schedule.can_skip_night())
	game.schedule.skip_night()
	check("night_skip_lands_on_next_eight_oclock",game.schedule.day_number()==2 and is_equal_approx(game.schedule.clock_minutes(),480) and not game.schedule.is_sleep_time())
	game.prison_alert.active = true
	game.prison_alert.triggered_minute = 1440
	clock(1919)
	check("alarm_remains_until_eight",game.prison_alert.active)
	clock(1920)
	check("alarm_clears_at_eight",not game.prison_alert.active)
	reset("backpack",1020)
	var merchant = game.trade.actors["prison_dealer"]
	merchant.update_schedule()
	merchant.position = merchant.goal
	check("evening_shop_is_available_after_new_shift",merchant.entry.kind=="shop" and game.trade.is_open("prison_dealer"))
	check("tutorial_uses_new_clock_times",game.tutorial.steps.work_brief.clock==540 and game.tutorial.steps.cell_brief.clock==1020 and game.tutorial.steps.enter_brief.lines[0].contains("九点"))
	if DisplayServer.get_name()!="headless":
		for minute in [480,540,1020]:
			clock(minute)
			game.actors[0].position = game.actors[0].home if minute==480 else game.routines._target(0,"work")
			game.map_camera.center_on(game.actors[0].position)
			game.room_visibility.tick(1,true)
			game.presentation.tick(0)
			game.fullscreen_ui.layout()
			game.fullscreen_ui.refresh()
			game.fullscreen_ui.fps_badge.hide()
			await frame()
			root.get_texture().get_image().save_png("res://docs/tests/p103-clock-"+str(minute)+".png")
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	var tag := "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open("res://docs/tests/p103-schedule-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"schedule":game.schedule.snapshot()},"\t"))
	print(JSON.stringify({"failed":failed,"total":checks.size()}))
	quit(0 if failed.is_empty() else 1)

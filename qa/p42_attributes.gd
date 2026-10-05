extends SceneTree

var game
var checks := {}

func _initialize() -> void:
	call_deferred("run")

func minute(value: float) -> void:
	game.schedule.clock_elapsed = (value-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.routines.tick()

func reset_job() -> void:
	game.load_room("r04",["chat","chat","lockpick"],42)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	var plan: Array = game.routines.plans.duplicate(true)
	for id in range(3):
		plan[id][0] = "work"
		plan[id][1] = "rest"
	game.routines.apply_today(plan)
	for index in range(1200):
		game._process(1.0/60)
		if game.routines.working_ids().size() == 3:
			break

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	reset_job()
	checks.initial_independent = game.attributes.values.size() == 3 and game.attributes.values.all(func(v): return v.stamina == 100 and v.fullness == 80)
	checks.actual_work_arrival = game.routines.working_ids().size() == 3
	game.schedule.set_time_speed(1)
	game._process(12.5)
	checks.work_60_minutes = game.attributes.values.all(func(v): return is_equal_approx(v.stamina,89.2) and is_equal_approx(v.fullness,75.8))
	checks.wages_full_efficiency = game.inventory.wallet == 12 and game.routines.work_rounds == [1,1,1]
	var before: Dictionary = game.attributes.snapshot()
	game.routine_panel.open()
	game._process(20)
	checks.pause_freezes = game.attributes.snapshot() == before and paused
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game._process(20)
	checks.clock_zero_freezes = game.attributes.snapshot() == before
	var attributes = game.attributes
	var end: float = game.schedule.clock_elapsed
	attributes.accrue(0,end,["work","work","work"])
	checks.interval_not_double_counted = attributes.snapshot() == before
	attributes.values[0].stamina = 2.0
	attributes.values[1].fullness = 10.0
	game.schedule.set_time_speed(1)
	var money: int = game.inventory.wallet
	game._process(6.25)
	checks.exhausted_clamped = attributes.values[0].stamina == 0 and game.routines.work_minutes[0] < 12
	checks.exhausted_stops_work = not game.routines.is_working(0) and "疲惫" in game.routines.status_for(0)
	checks.no_free_pay_when_exhausted = game.inventory.wallet == money
	checks.hungry_slow_work = game.routines.work_minutes[1] < game.routines.work_minutes[2] and attributes.work_efficiency(1) < 1
	checks.low_attributes_slow_move = attributes.move_efficiency(0) < attributes.move_efficiency(2) and attributes.move_efficiency(0) > 0
	checks.exhausted_skill_rejected = "体力" in game.skills.target_reason(game.actors[0])
	game.routines.take_control(0)
	game.actors[0].position = game.actors[0].home
	game.orders.stop(0)
	game._process(1)
	checks.home_rest_recovers = attributes.values[0].stamina > 0
	minute(720)
	game.schedule.set_time_speed(0)
	for index in range(1200):
		game._process(1.0/60)
		if game.actors.all(func(a): return a.position.distance_to(a.home) <= 12):
			break
	checks.rest_real_home_arrival = game.actors.all(func(a): return a.position.distance_to(a.home) <= 12)
	attributes.values[0].stamina = 20
	attributes.values[0].fullness = 20
	game.schedule.set_time_speed(1)
	game._process(12.5)
	checks.meal_recovers_both = attributes.values[0].stamina > 55 and attributes.values[0].fullness > 65
	game.routines.take_control(1)
	game.actors[1].position = Vector2(850,1130)
	attributes.values[1].fullness = 20
	game._process(1)
	checks.not_at_home_no_meal = attributes.values[1].fullness < 20
	game.orders.clear()
	for actor in game.actors:
		actor.position = actor.home
	minute(1440)
	attributes.values[0].stamina = 10
	attributes.values[0].fullness = 60
	game.schedule.skip_night()
	checks.skip_sleep_recovers = attributes.values[0].stamina == 100 and attributes.values[0].fullness < 60 and attributes.values[0].fullness > 40
	checks.skip_to_paused_morning = paused and game.routine_panel.panel.visible and game.schedule.clock_minutes() == 480
	before = attributes.snapshot()
	game._process(10)
	checks.morning_pause_no_double_recovery = attributes.snapshot() == before
	game.routine_panel.close()
	game.phase = "failed"
	game._process(2)
	checks.terminal_freezes = attributes.snapshot() == before
	game.reset_round(["chat","chat","lockpick"],42)
	checks.reset_values = game.attributes.values.all(func(v): return v.stamina == 100 and v.fullness == 80) and game.attributes.account_clock == 0
	game.routine_panel.close()
	var passed: bool = checks.values().all(func(v): return v)
	FileAccess.open("res://docs/tests/p42-attributes.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Actual job/rest navigation and game-clock simulation. Explicit low-value/actor-location fixtures for threshold and meal exclusions."},"\t")+"\n")
	print("P42_ATTRIBUTES passed=",passed," failures=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

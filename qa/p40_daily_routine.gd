extends SceneTree

var game
var checks := {}

func _initialize() -> void:
	call_deferred("run")

func set_minute(value: float) -> void:
	game.schedule.clock_elapsed = (value-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.routines.tick()
	game.routine_panel.close()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],36)
	game.routine_panel.close() # Dismiss new daily allocation before the existing fixture.
	game.schedule.set_time_speed(0)
	checks.starts_unassigned = game.routines.plans.all(func(row): return row.all(func(k): return k == "idle"))
	var plans: Array = game.routines.plans.duplicate(true)
	for id in range(3):
		plans[id][0] = "work"
		plans[id][1] = "rest"
		plans[id][2] = "work"
		plans[id][3] = "free"
		plans[id][4] = "rest"
	checks.apply = game.routines.apply_today(plans)
	checks.three_orders = game.orders.active.size() == 3 and game.orders.active.values().all(func(o): return o.source == "routine" and not o.push)
	var captures: int = game.captures
	for index in range(1000):
		game._process(1.0/60)
		if game.actors.all(func(a): return a.position.distance_to(game.routines.records[a.actor_id].goal) <= 12) and game.orders.active.is_empty():
			break
	checks.reach_three_workstations = game.actors.all(func(a): return a.position.distance_to(game.routines.records[a.actor_id].goal) <= 12)
	checks.no_legal_capture = game.captures == captures
	checks.legal_work = game.actors.all(func(a): return game.routines.is_lawful(a.actor_id))
	game.guard.position = game.actors[0].position+Vector2(30,0)
	game.guard.facing = Vector2.LEFT
	game.guard.tick(0)
	checks.guard_ignores_worker = game.guard.state != "chasing"
	checks.manual_move = game.command_move(0,game.actors[0].position+Vector2(40,0))
	checks.manual_not_legal = not game.routines.is_lawful(0) and game.routines.manual.has(0)
	game.guard.facing = Vector2.LEFT
	game.guard.tick(0)
	checks.day_manual_not_captured = game.guard.state != "chasing" and game.captures == captures
	game.actors[0].position = Vector2(850,330)
	game.routines.resume(0)
	checks.restore = not game.routines.manual.has(0) and game.routines.is_lawful(0)
	game.select_actor(0)
	game.stop_selected()
	checks.stop_pauses_routine = game.routines.manual.has(0) and not game.orders.active.has(0)
	game.routines.resume(0)
	var before: float = game.schedule.clock_elapsed
	set_minute(720)
	checks.meal_rest = game.routines.slot == 1 and game.routines.records.values().all(func(r): return r.kind == "rest")
	for index in range(1000):
		game._process(1.0/60)
		if game.actors.all(func(a): return a.position.distance_to(a.home) <= 12) and game.orders.active.is_empty():
			break
	checks.rest_home = game.actors.all(func(a): return a.position.distance_to(a.home) <= 12)
	set_minute(840)
	checks.afternoon_resumes = game.routines.slot == 2 and game.orders.active.size() == 3
	set_minute(1080)
	checks.free_hall = game.routines.slot == 3 and game.routines.records.values().all(func(r): return r.kind == "free" and r.goal.x > 624)
	game.actors[0].position = Vector2(850,330)
	checks.dog_ignores_legal = not game.dog._valid_actor(0)
	game.routines.take_control(0)
	checks.day_dog_ignores_manual = not game.dog._valid_actor(0)
	set_minute(1200)
	checks.evening_dorm = game.routines.slot == 4 and game.routines.records.values().all(func(r): return r.goal.x < 624)
	game.orders.clear()
	for actor in game.actors:
		actor.position = actor.home
	set_minute(1440)
	checks.midnight_uses_sleep = game.routines.slot == -1 and game.routines.records.is_empty() and game.schedule.can_skip_night()
	game.schedule.skip_night()
	game.routine_panel.close() # Dismiss new daily allocation before the existing fixture.
	checks.next_day_empty = game.routines.day == 2 and game.routines.plans.all(func(row): return row.all(func(k): return k == "idle"))
	checks.next_day_no_orders = game.orders.active.is_empty()
	# A closed door gives a blocked order, never a teleport or unlock.
	game.reset_round(["chat","lockpick","backpack"],36)
	game.routine_panel.close() # Dismiss new daily allocation before the existing fixture.
	game.actors[0].position = Vector2(2100,1000)
	var start: Vector2 = game.actors[0].position
	plans = game.routines.plans.duplicate(true)
	plans[0][0] = "work"
	game.routines.apply_today(plans)
	checks.blocked_without_teleport = game.actors[0].position == start and not game.world.door_open and game.routines.records[0].status == "blocked"
	game.reset_round(["chat","lockpick","backpack"],36)
	game.routine_panel.close() # Dismiss new daily allocation before the existing fixture.
	checks.reset_clears = game.routines.day == 1 and game.routines.records.is_empty() and game.routines.manual.is_empty()
	for room in ["r01","r02","r03"]:
		game.load_room(room,["chat","lockpick","strong"],36)
		game.routine_panel.close() # Dismiss new daily allocation before the existing fixture.
		checks[room+"_no_fake_work"] = not game.routines.allowed(0,"work")
		plans = game.routines.plans.duplicate(true)
		plans[0][0] = "rest"
		checks[room+"_rest"] = game.routines.apply_today(plans)
	var passed: bool = checks.values().all(func(x): return x)
	FileAccess.open("res://docs/tests/p40-routine-logic.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Actual three-worker navigation with active guard/dog. Isolated close detection, blocked-exit and stage-boundary fixtures; no human or device claim."},"\t")+"\n")
	print("P40_LOGIC passed=",passed," failed=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

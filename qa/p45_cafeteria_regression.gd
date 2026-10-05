extends SceneTree

var game
var checks := {}
var entrance_visits := [false,false,false]

func _initialize() -> void:
	call_deferred("run")

func minute(value: float) -> void:
	game.schedule.clock_elapsed = (value-480)/1440.0*game.schedule.day_seconds
	game.attributes.account_clock = game.schedule.clock_elapsed
	game.schedule.tick(false)
	game.routines.tick()

func simulate_until_eating() -> bool:
	for index in range(2400):
		game._process(1.0/60)
		for id in range(3):
			entrance_visits[id] = entrance_visits[id] or Rect2(690,1180,44,220).has_point(game.actors[id].position)
		if range(3).all(func(id): return game.routines.is_eating(id)):
			game._process(0)
			return true
	return false

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["chat","chat","lockpick"],43)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	checks.map_extended = game.world.bounds.end.y == 1840
	checks.named_cafeteria = game.room_config.zones.any(func(z): return z.id == "cafeteria" and z.name == "食堂")
	checks.four_tables = game.world.fixtures.filter(func(f): return f.asset_id == "communal_table").size() == 4
	checks.kitchen_closed = not game.world.can_place_circle(Vector2(1200,1010),17,null,false)
	checks.counter_closed = not game.world.can_place_circle(Vector2(1200,1150),17,null,false)
	checks.enclosure_configured = game.room_config.cafeteria.enclosed
	checks.north_wall_collision = not game.world.can_place_circle(Vector2(1200,920),17,null,false)
	checks.south_wall_collision = not game.world.can_place_circle(Vector2(1200,1750),17,null,false)
	checks.east_wall_collision = not game.world.can_place_circle(Vector2(1750,1350),17,null,false)
	checks.west_wall_collision = not game.world.can_place_circle(Vector2(710,1030),17,null,false)
	checks.kitchen_side_collision = not game.world.can_place_circle(Vector2(950,1030),17,null,false)
	checks.wall_blocks_sight = not game.world.line_clear(Vector2(680,1030),Vector2(760,1030))
	checks.entrance_open = game.world.can_place_circle(Vector2(710,1290),17,null,false) and game.world.line_clear(Vector2(680,1290),Vector2(760,1290))
	checks.trays_not_colliders = game.world.fixtures.filter(func(f): return f.asset_id == "cafeteria_tray").all(func(f): return not f.blocks_movement)
	checks.meal_only_lunch = game.routines.allowed(1,"meal") and not game.routines.allowed(0,"meal") and not game.routines.allowed(4,"meal")
	var reachable := true
	for id in range(3):
		for kind in ["meal","dine","work","free"]:
			var coordinates: Array = game.room_config.routine_points[kind][id]
			var point := Vector2(coordinates[0],coordinates[1])
			reachable = reachable and not game.world.find_path(game.actors[id].home,point,game.actors[id],false).is_empty()
	checks.all_routine_points_reachable = reachable
	checks.items_clear = game.inventory.instances.values().filter(func(i): return i.location == "ground").all(func(i): return game.world.can_place_circle(Vector2(i.position[0],i.position[1]),8,null,false))
	var visited := [false,false,false,false]
	for index in range(4800):
		game._process(1.0/60)
		for point_index in range(4):
			visited[point_index] = visited[point_index] or game.guard.position.distance_to(game.world.patrol[point_index]) < 40
		if visited.all(func(v): return v):
			break
	checks.day_patrol_not_stuck = visited.all(func(v): return v)
	game.schedule.set_time_speed(1)
	var merchant = game.trade.actors.values()[0]
	for index in range(2400):
		game.trade.tick(1.0/60) # Fixed morning-stage fixture; actual NPC navigation.
		if merchant.at_destination():
			break
	checks.merchant_real_work_path = merchant.at_destination() and merchant.entry.kind == "work"
	game.schedule.set_time_speed(0)
	var plan: Array = game.routines.plans.duplicate(true)
	for id in range(3):
		plan[id][0] = "work"
		plan[id][1] = "meal"
	game.routines.apply_today(plan)
	for index in range(1500):
		game._process(1.0/60)
		if game.routines.working_ids().size() == 3:
			break
	checks.three_real_work_arrivals = game.routines.working_ids().size() == 3
	game.schedule.set_time_speed(1)
	game._process(12.5)
	checks.wages_retained = game.inventory.wallet == 12
	# Verify real default-clock travel from actual jobs through the new doorway.
	minute(720)
	game.schedule.set_time_speed(1)
	var eaten := [false,false,false]
	var merchant_shop_seen := false
	for index in range(1640):
		game._process(1.0/60)
		for id in range(3):
			eaten[id] = eaten[id] or game.routines.is_eating(id)
		merchant_shop_seen = merchant_shop_seen or merchant.is_open()
	checks.default_clock_meal_reachable = eaten.all(func(v): return v)
	checks.merchant_real_shop_path = merchant_shop_seen
	if not checks.default_clock_meal_reachable:
		print("Meal routes: ",eaten," positions=",game.actors.map(func(a): return a.position)," states=",game.routines.snapshot())
	game.load_room("r04",["chat","chat","lockpick"],43)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.routines.apply_today(plan)
	minute(720)
	game.schedule.set_time_speed(1)
	game.attributes.values[0].fullness = 20
	game._process(0.5)
	checks.no_meal_during_commute = game.attributes.values[0].fullness < 20 and not game.routines.is_eating(0)
	game.schedule.set_time_speed(0)
	checks.three_real_meal_arrivals = simulate_until_eating()
	checks.three_cross_real_entrance = entrance_visits.all(func(v): return v)
	checks.pickup_then_seats = game.routines.records.values().all(func(r): return r.meal_stage == "dine" and r.status == "arrived")
	checks.three_distinct_seats = game.actors[0].position.distance_to(game.actors[1].position) > 34 and game.actors[0].position.distance_to(game.actors[2].position) > 34
	checks.eat_status = range(3).all(func(id): return game.routines.status_for(id) == "用餐中")
	checks.carrying = range(3).all(func(id): return game.routines.carries_meal(id))
	checks.daytime_not_arrested = game.captures == 0 and game.guard.state != "chasing"
	game.attributes.values[0].fullness = 20
	game.attributes.values[0].stamina = 20
	game.schedule.set_time_speed(1)
	game._process(12.5)
	checks.eating_restores = is_equal_approx(game.attributes.values[0].fullness,65.9) and is_equal_approx(game.attributes.values[0].stamina,56)
	var before: Dictionary = game.attributes.snapshot()
	game.routine_panel.open()
	game._process(10)
	checks.pause_no_food = before == game.attributes.snapshot() and paused
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game._process(10)
	checks.zero_clock_no_food = before == game.attributes.snapshot()
	game.attributes.accrue(0,game.schedule.clock_elapsed,["meal","meal","meal"])
	checks.no_double_food = before == game.attributes.snapshot()
	for id in range(3):
		game.command_move(id,game.actors[id].home)
	for index in range(2000):
		game._process(1.0/60)
		if game.actors.all(func(a): return a.position.distance_to(a.home) <= 12):
			break
	checks.return_to_cells_through_entry = game.actors.all(func(a): return a.position.distance_to(a.home) <= 12)
	game.routines.take_control(0)
	game.actors[0].position = game.actors[0].home # Explicit exclusion fixture.
	game.attributes.values[0].fullness = 20
	game.schedule.set_time_speed(1)
	game._process(1)
	checks.home_no_food_r04 = game.attributes.values[0].fullness < 20 and not game.routines.carries_meal(0)
	checks.home_rest_still_recovers = game.attributes.values[0].stamina > 56
	minute(839.9)
	game._process(1)
	checks.afternoon_clears_meal = game.routines.slot == 2 and range(3).all(func(id): return not game.routines.is_eating(id) and not game.routines.carries_meal(id))
	checks.afternoon_no_extra_food = game.attributes.values[1].fullness < 100
	game.load_room("r03",["chat","chat","lockpick"],43)
	game.routine_panel.close()
	minute(720)
	game.schedule.set_time_speed(1)
	game.attributes.values[0].fullness = 20
	game.attributes.values[0].stamina = 20
	game._process(1)
	checks.legacy_home_meal = game.attributes.values[0].fullness > 20 and game.attributes.values[0].stamina > 20
	checks.legacy_meal_unavailable = not game.routines.allowed(1,"meal")
	game.load_room("r04",["chat","chat","lockpick"],43)
	game.routine_panel.close()
	checks.reset_meal_cleared = game.routines.records.is_empty() and game.attributes.values.all(func(v): return v.fullness == 80 and v.stamina == 100)
	var passed: bool = checks.values().all(func(v): return v)
	FileAccess.open("res://docs/tests/p45-cafeteria-logic.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Real movement/work/meal routing and clock accrual. Clock jumps select stages; low stats and home exclusion are explicit fixtures. No human or mobile-device claim."},"\t")+"\n")
	print("P45_CAFETERIA passed=",passed," failures=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

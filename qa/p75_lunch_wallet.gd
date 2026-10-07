extends SceneTree
var game
var checks := {}
func _initialize() -> void: call_deferred("run")
func clock(minute: float) -> void:
	game.schedule.clock_elapsed=(minute-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.room_access.tick()
	game.workshop.update_gate()
	game.routines.tick()
func reset() -> void:
	game.reset_round(["lockpick","chat","backpack"],73)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
func interval(begin_minute: float,end_minute: float,states: Array) -> void:
	var begin: float=(begin_minute-440)/1440.0*game.schedule.day_seconds
	var end: float=(end_minute-440)/1440.0*game.schedule.day_seconds
	var credit: Dictionary=game.attributes.accrue(begin,end,states)
	game.routines.accrue_work(begin,end,game.routines.working_ids(),credit)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	reset()
	clock(600)
	for id in [1,2]:
		game.actors[id].position=game.routines._target(id,"work")
		game.routines.resume(id)
	game.routines.take_control(0)
	game.orders.stop(0)
	interval(600,660,game.attributes.behaviors())
	checks.npc_earnings_separate=game.routines.work_earned[1]==4 and game.routines.work_earned[2]==4 and game.inventory.wallet==0
	checks.no_player_npc_wage_toast=not game.routines.recent_wages.has(1) and not game.routines.recent_wages.has(2)
	game.actors[0].position=game.routines._target(0,"work")
	game.routines.resume(0)
	interval(660,720,game.attributes.behaviors())
	checks.lead_only_receives_own_wage=game.inventory.wallet==4 and game.routines.work_earned==[4,8,8]
	var wallet: int=game.inventory.wallet
	interval(660,720,game.attributes.behaviors())
	checks.replayed_interval_no_duplicate_pay=game.inventory.wallet==wallet
	reset()
	clock(750)
	game.orders.stop(0)
	var seat: Array=game.room_config.routine_points.dine[0]
	game.actors[0].position=Vector2(seat[0],seat[1])
	game.routines.records[0]={"kind":"meal","meal_stage":"dine","goal":game.actors[0].position,"status":"arrived","retry":0.0}
	game.attributes.values[0].fullness=40
	game.attributes.values[0].stamina=40
	checks.meal_starts_at_actual_seat=game.routines.is_eating(0) and game.routines.meal_minutes[0]==0
	interval(750,765,game.attributes.behaviors())
	checks.partial_meal_credit=absf(game.routines.meal_minutes[0]-15)<0.001
	var before: float=game.routines.meal_minutes[0]
	paused=true
	interval(765,767,game.attributes.behaviors())
	paused=false
	checks.paused_meal_does_not_advance=game.routines.meal_minutes[0]==before
	interval(765,785,game.attributes.behaviors())
	checks.long_frame_caps_20=absf(game.routines.meal_minutes[0]-20)<0.001 and absf(game.attributes.values[0].fullness-(40-35*0.035+20*0.8))<0.001 and absf(game.attributes.values[0].stamina-52)<0.001
	game.routines.tick()
	checks.meal_finishes_to_free=not game.routines.is_eating(0) and not game.routines.carries_meal(0) and game.routines.records[0].kind=="free"
	checks.no_second_lunch=not game.routines.meal_reason(0).is_empty() and not game.routines.start_meal(0)
	game.routines.take_control(0)
	game.orders.stop(0)
	var pos: Vector2=game.actors[0].position
	clock(809)
	var before_depart: Array=game.actors.map(func(a): return a.position)
	clock(810)
	checks.departure_never_changes_position=range(3).all(func(id): return game.actors[id].position==before_depart[id])
	checks.npcs_prework_order=[1,2].all(func(id): return game.routines.records[id].kind=="work" and not game.routines.is_working(id))
	checks.manual_lead_not_forced_to_commute=game.actors[0].position==pos and game.routines.manual.has(0) and not game.orders.active.has(0)
	reset()
	clock(815)
	game.routines.take_control(0)
	game.orders.stop(0)
	var pickup: Array=game.room_config.routine_points.meal[0]
	game.actors[0].position=Vector2(pickup[0],pickup[1])
	checks.late_player_meal_can_start=game.routines.start_meal(0)
	game.routines.tick()
	checks.player_chosen_meal_not_canceled_at_1330=game.routines.records[0].kind=="meal"
	reset()
	clock(839)
	game.orders.clear()
	game.routines.take_control(0)
	game.actors[0].position=Vector2(920,1885)
	var inside: Vector2=game.actors[0].position
	var gate: Dictionary=game.world.access_by_id("cafeteria-entry")
	var outsider=game.actors[1]
	outsider.position=Vector2(1010,1160)
	clock(840)
	checks.closing_never_teleports=game.actors[0].position==inside
	checks.closing_passage_waits_for_walk=not gate.closed and game.room_access.closing.has("cafeteria-entry")
	checks.closed_hours_entry_blocked=not game.world.can_place_circle(Vector2(1010,1280),17,outsider,false)
	checks.closed_hours_exit_allowed=game.world.can_place_circle(Vector2(1010,1120),17,game.actors[0],false)
	checks.walking_exit_order=game.orders.active.has(0) and game.orders.active[0].goal==Vector2(1010,1100)
	# Advance physical orders without guards to test the doorway evacuation.
	var max_step:=0.0
	for step in range(500):
		var old: Vector2=game.actors[0].position
		game.elapsed+=0.05
		game.room_access.tick()
		game.workshop.update_gate()
		game.routines.tick()
		game.orders.tick(0.05)
		max_step=maxf(max_step,old.distance_to(game.actors[0].position))
	checks.exit_is_continuous_walk=max_step<=13.01 and not Rect2(720,1230,1304,1000).has_point(game.actors[0].position)
	checks.cafeteria_closes_when_empty=gate.closed
	clock(1880)
	checks.new_day_resets_meal_budget=game.routines.meal_minutes==[0.0,0.0,0.0]
	game.routine_panel.close()
	var failed: Array=checks.keys().filter(func(k): return not checks[k])
	var report: Dictionary={"checks":checks,"failed":failed,"passed":checks.size()-failed.size(),"total":checks.size(),"max_exit_step":max_step}
	FileAccess.open("res://docs/tests/p75-lunch-wallet.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)

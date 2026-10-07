extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],70)
	game.routine_panel.close()
	game.schedule.set_time_speed(1)
	var seen := {}
	var captures: Array = []
	var morning2: Array = []
	var last_captures := 0
	var arrival: Array = []
	var afternoon_arrival: Array = []
	var departures := {}
	var saw_free := {}
	var max_move := 0.0
	var max_staff_move := 0.0
	var hidden_inside := false
	var shift_arrivals: Array = []
	for step in range(2620):
		if paused: game.routine_panel.close()
		var before: Array = game.actors.map(func(a): return a.position)
		var staff_before: Dictionary = {}
		for record in game.staff_traffic.records.values(): staff_before[record.actor.get_instance_id()]=record.actor.position
		game._process(0.2)
		for record in game.staff_traffic.records.values():
			var actor = record.actor
			if staff_before.has(actor.get_instance_id()): max_staff_move=maxf(max_staff_move,staff_before[actor.get_instance_id()].distance_to(actor.position))
			if actor.escaped and actor.position.x<game.world.bounds.end.x: hidden_inside=true
		if game.workshop.on_duty() and (shift_arrivals.is_empty() or shift_arrivals[-1].shift != str(game.schedule.day_number())+":"+str(game.workshop.current_shift())):
			shift_arrivals.append({"shift":str(game.schedule.day_number())+":"+str(game.workshop.current_shift()),"onsite":not game.workshop.overseer.escaped and game.workshop.area.has_point(game.workshop.overseer.position),"status":game.staff_traffic.records[game.workshop.overseer.get_instance_id()].status})
		for id in range(3): max_move = maxf(max_move,before[id].distance_to(game.actors[id].position))
		if game.schedule.clock_minutes() >= 840 and afternoon_arrival.is_empty(): afternoon_arrival = game.actors.map(func(a): return [a.position.x,a.position.y])
		for id in [1,2]:
			if game.routines.slot==1 and game.routines.records.has(id):
				var record: Dictionary = game.routines.records[id]
				if record.kind=="free": saw_free[id]=true
				if record.kind=="work" and not departures.has(id): departures[id]=game.schedule.clock_minutes()
		if game.captures != last_captures:
			captures.append({"minute":game.schedule.clock_minutes(),"held":game.room_access.held.duplicate(true),"positions":game.actors.map(func(a): return [a.position.x,a.position.y]),"routines":game.routines.snapshot()})
			last_captures = game.captures
		if game.schedule.day_number()==2 and game.schedule.clock_minutes()>=480 and morning2.is_empty(): morning2 = game.actors.map(func(a): return [a.position.x,a.position.y])
		if game.schedule.clock_minutes() >= 480 and arrival.is_empty(): arrival = game.actors.map(func(a): return [a.position.x,a.position.y])
		for id in [1,2]:
			if game.routines.is_working(id): seen["work"+str(id)] = true
			if game.routines.is_eating(id): seen["meal"+str(id)] = true
			if game.schedule.is_sleeping(id): seen["sleep"+str(id)] = true
	var checks := {"no_workshop_false_arrests":game.captures == 0,"natural_npc_work":seen.get("work1",false) and seen.get("work2",false),"natural_npc_lunch":seen.get("meal1",false) and seen.get("meal2",false),"natural_npc_sleep":seen.get("sleep1",false) and seen.get("sleep2",false),"no_missing_alarm":not game.prison_alert.active,"npc_wages":game.routines.work_earned[1]>0 and game.routines.work_earned[2]>0,"night_beds":game.schedule.is_sleeping(1) and game.schedule.is_sleeping(2)}
	checks["npc_lunch_then_free"] = saw_free.size()==2
	checks["npc_depart_1330"] = departures.size()==2 and departures.values().all(func(m): return m>=810 and m<812)
	checks["no_timed_teleport"] = max_move<=52.01
	checks["afternoon_arrival"] = afternoon_arrival.size()==3 and afternoon_arrival.all(func(p): return game.workshop.area.grow(-17).has_point(Vector2(p[0],p[1])))
	checks["meal_exactly_20"] = game.routines.meal_minutes.all(func(m): return absf(m-20)<0.001)
	checks["wallet_is_lead_income_only"] = game.inventory.wallet==game.routines.work_earned[0]
	checks["staff_never_hidden_inside"] = not hidden_inside
	checks["staff_no_timed_teleport"] = max_staff_move<=43.01
	checks["supervisor_arrives_for_every_shift"] = shift_arrivals.size()>=3 and shift_arrivals.all(func(s): return s.onsite and s.status=="duty")
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"checks":checks,"failed":failed,"max_staff_move":max_staff_move,"shift_arrivals":shift_arrivals,"capture_events":captures,"afternoon_arrival":afternoon_arrival,"departures":departures,"max_move":max_move,"morning2":morning2,"arrival":arrival,"captured":game.captures,"clock":game.schedule.clock_minutes(),"routines":game.routines.snapshot(),"held":game.room_access.held,"positions":game.actors.map(func(a): return [a.position.x,a.position.y]),"alarm":game.prison_alert.snapshot()}
	FileAccess.open("res://docs/tests/p75-two-day-cycle.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)

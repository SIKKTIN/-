extends SceneTree

var game
var checks := {}
var traces: Array = []
var max_step := 0.0
var early_hidden := false
var crossing := {}

func _initialize() -> void:
	call_deferred("run")

func check(label: String, value: bool) -> void:
	checks[label] = value
	print(label+": "+str(value))

func clock(minute: float) -> void:
	game.schedule.clock_elapsed = (minute-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.workshop.update_gate()

func traffic_steps(count: int) -> void:
	for i in range(count):
		for record in game.staff_traffic.records.values():
			var actor = record.actor
			var before: Vector2 = actor.position
			game.staff_traffic.tick_guard(actor,0.05)
			max_step = maxf(max_step,before.distance_to(actor.position))
			if actor.position.x < game.world.bounds.end.x and actor.escaped: early_hidden = true
			var key: String = str(actor.get_instance_id())
			if game.world.door.grow(25).has_point(actor.position): crossing[key+"factory"] = true
			var gate: Dictionary = game.world.access_by_id("workshop-entry")
			if gate.rect.grow(25).has_point(actor.position): crossing[key+"workshop"] = true
		game.staff_traffic.update_gate()

func snapshot(label: String) -> void:
	var states: Array = []
	for record in game.staff_traffic.records.values():
		states.append({"role":record.role,"status":record.status,"position":[record.actor.position.x,record.actor.position.y],"visible":record.actor.visible,"legs":str(record.legs)})
	traces.append({"label":label,"states":states})

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],70)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	# Lawful workers leave sensory logic enabled without provoking a chase.
	for actor in game.actors: actor.immune_until = INF
	clock(720)
	var overseer = game.workshop.overseer
	var initial: Vector2 = overseer.position
	traffic_steps(1)
	check("no_noon_hide_or_teleport",overseer.visible and not overseer.escaped and initial.distance_to(overseer.position)<=10.76)
	traffic_steps(420)
	snapshot("after_noon_exit")
	var record: Dictionary = game.staff_traffic.records[overseer.get_instance_id()]
	check("overseer_exits_workshop_then_factory",crossing.has(str(overseer.get_instance_id())+"workshop") and crossing.has(str(overseer.get_instance_id())+"factory"))
	check("noon_retires_outside_map",record.status=="offsite" and overseer.position.x>game.world.bounds.end.x and not overseer.visible)
	check("factory_relocks_after_staff_exit",not game.world.door_open and game.world.lock_progress==0)
	clock(780)
	traffic_steps(1)
	check("afternoon_entry_starts_outside",record.status=="entering" and overseer.position.x>game.world.bounds.end.x and not overseer.visible)
	traffic_steps(440)
	snapshot("afternoon_arrival")
	check("returns_through_both_gates",record.status=="duty" and overseer.position.distance_to(record.home)<2 and overseer.visible)
	clock(1080)
	traffic_steps(460)
	check("evening_walks_out",record.status=="offsite" and not overseer.visible)
	clock(1200)
	traffic_steps(400)
	check("gate_guards_walk_out",game.gate_watch.guards.all(func(g): return game.staff_traffic.records[g.get_instance_id()].status=="offsite"))
	game.prison_alert.missing_ids.assign([0])
	game.prison_alert._raise_alarm()
	var pool: Array = game.prison_alert.reinforcements.duplicate()
	check("reinforcements_spawn_outside",pool.all(func(g): return not g.visible and g.position.x>game.world.bounds.end.x))
	traffic_steps(450)
	snapshot("alarm_arrivals")
	check("reinforcements_walk_in",pool.all(func(g): return not g.escaped and game.staff_traffic.records[g.get_instance_id()].status=="duty"))
	clock(1440+440)
	game.prison_alert.release_at_dawn()
	check("dawn_alarm_clears_without_deletion",not game.prison_alert.active and game.prison_alert.reinforcements==pool and pool.all(func(g): return is_instance_valid(g) and g.visible))
	traffic_steps(10)
	check("reinforcements_start_walking_out",pool.all(func(g): return game.staff_traffic.records[g.get_instance_id()].status=="leaving" and g.visible))
	var before: Array = pool.map(func(g): return g.position)
	game.prison_alert.missing_ids.assign([0])
	game.prison_alert._raise_alarm()
	traffic_steps(1)
	check("recall_reuses_same_people",game.prison_alert.reinforcements==pool and pool.size()==2)
	check("recall_never_repositions",pool[0].position.distance_to(before[0])<=10.76 and pool[1].position.distance_to(before[1])<=10.76)
	game.prison_alert.active = false
	traffic_steps(450)
	check("reinforcements_finish_departure",pool.all(func(g): return not g.visible and g.position.x>game.world.bounds.end.x))
	check("never_hidden_inside",not early_hidden)
	check("bounded_physical_step",max_step<=10.76)
	# A player's key takes ownership of an open gate permanently.
	clock(1440+720)
	game.world.open_door()
	traffic_steps(450)
	check("staff_does_not_relock_player_door",game.world.door_open and game.world.lock_progress==1)
	clock(1440+780)
	var still: Vector2 = overseer.position
	paused = true
	game.staff_traffic.tick_guard(overseer,1)
	check("pause_stops_commute",overseer.position==still)
	paused = false
	traffic_steps(10)
	check("player_cannot_use_staff_exterior",not game.world.can_place_circle(game.staff_traffic.exterior(),17,game.actors[0],false))
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"checks":checks,"failed":failed,"max_step":max_step,"traces":traces,"crossings":crossing}
	FileAccess.open("res://docs/tests/p75-staff-traffic.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)

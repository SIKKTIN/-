extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],68)
	game.routine_panel.close()
	game.schedule.set_time_speed(1)
	var seen := {}
	for step in range(1120):
		if paused: game.routine_panel.close()
		game._process(0.2)
		for id in [1,2]:
			if game.routines.is_working(id): seen["work"+str(id)] = true
			if game.routines.is_eating(id): seen["meal"+str(id)] = true
			if game.schedule.is_sleeping(id): seen["sleep"+str(id)] = true
	var checks := {"natural_npc_work":seen.get("work1",false) and seen.get("work2",false),"natural_npc_lunch":seen.get("meal1",false) and seen.get("meal2",false),"natural_npc_sleep":seen.get("sleep1",false) and seen.get("sleep2",false),"no_missing_alarm":not game.prison_alert.active,"npc_wages":game.routines.work_earned[1]>0 and game.routines.work_earned[2]>0,"night_beds":game.schedule.is_sleeping(1) and game.schedule.is_sleeping(2)}
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"checks":checks,"failed":failed,"captured":game.captures,"clock":game.schedule.clock_minutes(),"routines":game.routines.snapshot(),"held":game.room_access.held,"positions":game.actors.map(func(a): return [a.position.x,a.position.y]),"alarm":game.prison_alert.snapshot()}
	FileAccess.open("res://docs/tests/p68-day-cycle.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)

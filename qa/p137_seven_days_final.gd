extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p137-seven-days.cfg")
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.load_room("r04",["chat","chat","backpack"],137)
	game.schedule.set_escape_days(7)
	game.schedule.set_time_speed(1)
	game.actors[0].immune_until=INF
	var work: Dictionary={}
	var meals: Dictionary={}
	var sleep: Dictionary={}
	var last_day:=0
	for step in range(31520):
		game._process(0.2)
		var day: int=game.schedule.day_number()
		if day!=last_day:
			last_day=day
			print("SEVEN_DAY "+str(day))
		for id in [1,2]:
			var key: String="%d:%d" % [day,id]
			if game.routines.is_working(id):work[key]=true
			if game.routines.is_eating(id):meals[key]=true
			if game.schedule.is_sleeping(id):sleep[key]=true
		if game.phase!="playing":break
	var checks: Dictionary={"seven_days_reach_deadline":game.schedule.day_number()==8 and game.schedule.remaining()==0 and game.phase=="failed","no_false_arrests":game.captures==0,"no_missing_alarm":not game.prison_alert.active,"player_stays_manual":not game.routines.records.has(0) and game.actors[0].position.distance_to(game.actors[0].home)<0.001,"npc_income":game.routines.work_earned[1]>0 and game.routines.work_earned[2]>0}
	for day in range(1,8):
		for id in [1,2]:
			checks["day_%d_npc_%d_work" % [day,id]]=work.has("%d:%d" % [day,id])
			checks["day_%d_npc_%d_meal" % [day,id]]=meals.has("%d:%d" % [day,id])
			checks["night_%d_npc_%d_sleep" % [day,id]]=sleep.has("%d:%d" % [day+1,id])
	var failed: Array=checks.keys().filter(func(key):return not checks[key])
	FileAccess.open("res://docs/dev/p137/seven-days-final.json",FileAccess.WRITE).store_string(JSON.stringify({"accelerated_state_test":true,"checks":checks,"failed":failed,"schedule":game.schedule.snapshot()},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)

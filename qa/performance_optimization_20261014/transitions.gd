extends SceneTree
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://perf-transitions.cfg")
	var label: String=OS.get_cmdline_user_args()[0]
	var game=load("res://qa/performance_optimization_20261014/transition_before_game.gd" if label=="before" else "res://qa/performance_optimization_20261014/game.gd").new()
	game.room_id="r04";root.add_child(game);await process_frame
	game.set_process(false);game.fullscreen_ui.set_process(false)
	game.actors[0].immune_until=INF;game.schedule.set_time_speed(1)
	var previous: String="";var events: Array=[];var seen: Dictionary={};var pending_seen:=false
	for i in range(4520):
		game._process(0.2)
		var stage: String=str(game.schedule.day_number())+":"+str(game.schedule.stage_index)
		if stage!=previous:
			previous=stage
			events.append({"minute":game.schedule.absolute_minutes(),"script_ms":game.profile_total_ms,"path_ms":game.world.pathfinding.audit_records.map(func(r):return r.ms),"pending":game.routines.records.values().filter(func(r):return r.get("route_pending",false)).size()})
		for id in [1,2]:
			if game.routines.is_working(id):seen["work%d"%id]=true
			if game.routines.is_eating(id):seen["meal%d"%id]=true
		pending_seen=pending_seen or game.routines.records.values().any(func(r):return r.get("route_pending",false))
		game.world.pathfinding.audit_records.clear()
		if game.schedule.day_number()==2 and game.schedule.clock_minutes()>=480:break
	var checks: Dictionary={"reaches_next_dawn":game.schedule.day_number()==2,"work_and_meal_both_npcs":seen.size()==4,"no_false_arrests":game.captures==0,"no_missing_alarm":not game.prison_alert.active}
	if label=="after":checks["npc_routes_are_staggered"]=pending_seen
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	var out: Dictionary={"accelerated_state_test":true,"delta":0.2,"checks":checks,"failed":failed,"transitions":events}
	FileAccess.open("res://docs/dev/performance-optimization-2026-10-14/transitions-"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("TRANSITIONS "+JSON.stringify(out));quit(0 if failed.is_empty() else 1)

extends SceneTree
var game
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("SMOOTH_TEST_VARIANT","after")
	seed(141014)
	OS.set_environment("ESCAPE_FRAME_MODE","60")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://perf-chase.cfg")
	root.size=Vector2i(1200,720);root.content_scale_size=root.size
	game=load("res://qa/smoothness_optimization_20261014/game.gd").new();game.room_id="r04";root.add_child(game)
	await process_frame;await RenderingServer.frame_post_draw
	game.schedule.set_time_speed(0)
	game.schedule.clock_elapsed=(1441.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.actors[0].position=Vector2(1250,1750);game.actors[0].immune_until=0
	game.prison_alert.missing_ids.assign([0]);game.prison_alert._raise_alarm()
	game.guard.position=Vector2(1390,1750);game.guard.facing=Vector2.LEFT;game.guard.escaped=false
	var traffic: Dictionary=game.staff_traffic.records.get(game.guard.get_instance_id(),{})
	if not traffic.is_empty():traffic.status="duty"
	game.map_camera.center_on(game.actors[0].position);game.map_camera.following=false
	game.set_process(true)
	var frames: Array=[];var scripts: Array=[];var chased:=0;var moved:=0;var old: Vector2=game.guard.position
	var last:=Time.get_ticks_usec()
	for i in range(480):
		await process_frame;await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		if i>=30:frames.append((now-last)/1000.0);scripts.append(game.profile_total_ms)
		last=now
		if game.prison_alert.officers().any(func(g):return g.state=="chasing" and g.target_id==0):chased+=1
		if game.guard.position.distance_to(old)>0.01:moved+=1
		old=game.guard.position
	var checks: Dictionary={"real_detection_enters_chase":chased>10,"officer_moves":moved>10,"capture_occurs":game.captures>0,"alarm_remains_active":game.prison_alert.active}
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	var out: Dictionary={"checks":checks,"failed":failed,"chased_frames":chased,"moving_frames":moved,"captures":game.captures,"frame_ms":stats(frames),"script_ms":stats(scripts)}
	FileAccess.open("res://docs/dev/smoothness-optimization-2026-10-14/chase.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("CHASE "+JSON.stringify(out));quit(0 if failed.is_empty() else 1)
func stats(values: Array)->Dictionary:
	var ordered:=values.duplicate();ordered.sort()
	return {"mean":values.reduce(func(a,b):return a+b,0.0)/values.size(),"p95":ordered[int(values.size()*0.95)],"p99":ordered[int(values.size()*0.99)],"max":ordered.back()}

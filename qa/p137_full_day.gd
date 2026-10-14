extends SceneTree
var game
var times: Array=[]
var scripts: Array=[]
var stages: Dictionary={}
var spikes: Array=[]
var seen: Dictionary={}
var start_usec:=0
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func stats(a: Array) -> Dictionary:
	var sorted:=a.duplicate()
	sorted.sort()
	return {"count":a.size(),"mean":a.reduce(func(x,y):return x+y,0.0)/a.size(),"p95":sorted[int(sorted.size()*0.95)],"p99":sorted[int(sorted.size()*0.99)],"max":sorted.back()}
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_MODE","60")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p137-day-frame.cfg")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p137-day-dev.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	root.title="监狱风云 · 后台性能验证（15分钟）"
	root.unfocusable=true
	game=load("res://scenes/main.tscn").instantiate()
	game.set_script(preload("res://qa/p137_pacing_game.gd"))
	root.add_child(game)
	await frame()
	game.load_room("r04",["chat","chat","backpack"],137)
	game.actors[0].immune_until=INF
	game.actors[0].position=game.actors[0].home
	game.map_camera.center_on(game.actors[0].position)
	game.schedule.set_time_speed(1)
	game.schedule.clock_elapsed=0
	game.schedule.tick(false)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	start_usec=Time.get_ticks_usec()
	var last:=start_usec
	var checkpoint_usec:=start_usec
	while game.schedule.day_number()<2 or game.schedule.clock_minutes()<480:
		await frame()
		var now:=Time.get_ticks_usec()
		var ms: float=(now-last)/1000.0
		last=now
		times.append(ms)
		scripts.append(game.profile_total_ms)
		var stage: String=game.schedule.config.stages[game.schedule.stage_index].id
		if not stages.has(stage):
			stages[stage]={"first_minute":game.schedule.absolute_minutes(),"frames":0}
			print("DAY_STAGE "+stage+" "+str(game.schedule.absolute_minutes()))
		stages[stage].frames+=1
		for id in [1,2]:
			if game.routines.is_working(id):seen["work%d" % id]=true
			if game.routines.is_eating(id):seen["meal%d" % id]=true
			if game.schedule.is_sleeping(id):seen["sleep%d" % id]=true
		if now-checkpoint_usec>=60000000:
			checkpoint_usec=now
			var progress: Dictionary={"seconds":(now-start_usec)/1000000.0,"frames":times.size(),"clock":game.schedule.absolute_minutes(),"captures":game.captures,"stages":stages,"spikes":spikes.size()}
			FileAccess.open("res://docs/dev/p137/full-day-progress.json",FileAccess.WRITE).store_string(JSON.stringify(progress,"\t"))
			print("DAY_PROGRESS "+JSON.stringify(progress))
		if ms>33:
			spikes.append({"minute":game.schedule.absolute_minutes(),"frame_ms":ms,"script_ms":game.profile_total_ms,"sections":game.profile_sections.duplicate(),"paths":game.world.pathfinding.frame_records.duplicate(true),"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())})
		if (now-start_usec)/1000000.0>930:break
	var wall_seconds: float=(Time.get_ticks_usec()-start_usec)/1000000.0
	var checks: Dictionary={"one_day_at_real_speed":game.schedule.day_number()==2 and wall_seconds>890 and wall_seconds<930,"player_manual":game.actors[0].position.distance_to(game.actors[0].home)<0.001 and not game.routines.records.has(0),"npc_work":seen.get("work1",false) and seen.get("work2",false),"npc_meal":seen.get("meal1",false) and seen.get("meal2",false),"npc_sleep":seen.get("sleep1",false) and seen.get("sleep2",false),"no_false_arrests":game.captures==0,"no_missing_alarm":not game.prison_alert.active}
	var failed: Array=checks.keys().filter(func(key):return not checks[key])
	var result: Dictionary={"native":true,"time_speed":game.schedule.time_speed,"wall_seconds":wall_seconds,"frame_ms":stats(times),"script_ms":stats(scripts),"stages":stages,"spikes_over33ms":spikes,"checks":checks,"failed":failed,"textures_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0}
	FileAccess.open("res://docs/dev/p137/full-day.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FULL_DAY "+JSON.stringify({"seconds":wall_seconds,"frame_ms":result.frame_ms,"script_ms":result.script_ms,"failed":failed}))
	game.queue_free()
	await frame()
	await frame()
	quit(0 if failed.is_empty() else 1)

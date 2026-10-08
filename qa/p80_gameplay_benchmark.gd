extends SceneTree
var game
var label := "before"
var target_fps := 0
var samples: Array = []
var last := 0
var movement_time := 0.0
var sustained := false
var layer_profiles: Array=[]
func _initialize() -> void: call_deferred("run")
func percentile(values: Array, q: float) -> float:
	if values.is_empty(): return 0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size()-1,floori(sorted.size()*q))]
func stats(values: Array) -> Dictionary:
	return {"median_ms":percentile(values,0.5),"p95_ms":percentile(values,0.95),"p99_ms":percentile(values,0.99),"max_ms":percentile(values,1),"mean_ms":values.reduce(func(a,b):return a+b,0.0)/maxi(1,values.size())}
func measure(name: String, point: Vector2, chase: bool, night := false) -> void:
	game.reset_round()
	game.routine_panel.close()
	game.fullscreen_ui.close_menu()
	game.schedule.set_time_speed(0)
	game.schedule.clock_elapsed=((1450.0 if night else 530.0)-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.room_access.tick()
	game.workshop.update_gate()
	game.orders.clear()
	game.routines.take_control(0)
	game.actors[0].position=point
	game.actors[0].immune_until=0 if chase else INF
	if sustained and chase: game.workshop.grace[0]=0
	for actor in game.actors.slice(1): actor.immune_until=INF
	game.guard.position=point+Vector2(140,0)
	game.guard.returning_from_inspection=false
	if night:
		game.prison_alert.missing_ids.append(0)
		game.prison_alert._raise_alarm()
	game.map_camera.following=true
	game.map_camera.center_on(point)
	movement_time=0
	last=Time.get_ticks_usec()
	var start:=last
	var times: Array=[]
	var intervals: Array=[]
	var sections: Dictionary={}
	var paths: Array=[]
	for layer in layer_profiles:layer.draws.clear()
	var chasing_frames:=0
	var captures_before: int=game.captures
	var nav_before: int=game.world.navigation_builds
	while Time.get_ticks_usec()-start < 7000000:
		await process_frame
		var now:=Time.get_ticks_usec()
		var dt:=minf(0.05,(now-last)/1000000.0)
		var frame_interval: float=(now-last)/1000.0
		last=now
		movement_time+=dt
		# Real collision movement, one controlled actor. Continuous circular flight
		# exercises moving goals, occlusion and routes without teleporting each frame.
		if chase:
			game.world.move_actor(game.actors[0],Vector2.from_angle(movement_time*1.2)*260*dt)
		game.world.path_times.clear()
		game._process(dt)
		if game.guard.warning_officers().any(func(officer):return officer.state=="chasing"):chasing_frames+=1
		await RenderingServer.frame_post_draw
		if Time.get_ticks_usec()-start < 1500000: continue
		times.append((Time.get_ticks_usec()-now)/1000.0)
		intervals.append(frame_interval)
		for key in game.profile_sections:
			if not sections.has(key):sections[key]=[]
			sections[key].append(game.profile_sections[key])
		paths.append_array(game.world.path_times)
	var frame_stats:=stats(times)
	var section_stats: Dictionary={}
	for key in sections:section_stats[key]=stats(sections[key])
	var layers: Dictionary={}
	for layer in layer_profiles:layers[layer.kind]=stats(layer.draws.map(func(d):return d.ms))
	samples.append({"name":name,"fps_cap":Engine.max_fps,"frames":times.size(),"frame_intervals":stats(intervals),"work_frame":frame_stats,"sections":section_stats,"layer_draws":layers,"paths":stats(paths),"path_calls":paths.size(),"chasing_frames":chasing_frames,"captures":game.captures-captures_before,"navigation_builds":game.world.navigation_builds-nav_before})
	print(JSON.stringify(samples.back()))
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():label=args[0]
	if args.size()>1:target_fps=int(args[1])
	sustained=args.size()>2 and args[2]=="sustained"
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://qa/p79_profile_game.gd").new()
	game.room_id="r04"
	root.add_child(game)
	game.set_process(false)
	await process_frame
	for index in range(game.presentation.scene_layers.size()):
		var old=game.presentation.scene_layers[index]
		var layer=load("res://qa/p78_profile_layer.gd").new()
		game.add_child(layer)
		layer.configure(game,game.presentation,old.kind)
		game.presentation.scene_layers[index]=layer
		old.free()
		layer_profiles.append(layer)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game.frame_settings.apply(target_fps,false)
	if sustained:
		game.benchmark_capture_disabled=true
	var modes: Array=[60,90] if args.size()>3 and args[3]=="both" else [target_fps]
	for mode in modes:
		game.frame_settings.apply(mode,false)
		await measure("day_patrol",Vector2(720,750),false)
		await measure("day_dorm_chase",Vector2(380,710),true)
		await measure("day_corridor_chase",Vector2(740,1000),true)
		await measure("night_global_alert",Vector2(740,1000),true,true)
		if sustained:
			await measure("sustained_overseer_chase",Vector2(1450,1300),true)
			await measure("sustained_night_chase",Vector2(1500,1200),true,true)
	var report: Dictionary={"label":label,"map_sha256":FileAccess.get_sha256("res://data/rooms/r04.json"),"samples":samples,"adapter":RenderingServer.get_video_adapter_name()}
	FileAccess.open("res://docs/tests/p80-"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit()

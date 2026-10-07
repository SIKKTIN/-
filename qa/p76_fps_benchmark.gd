extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var args := OS.get_cmdline_user_args()
	var map_path := "res://docs/dev/p76/fps-map.json"
	if "--frozen-map" in args:
		game.room_config = JSON.parse_string(FileAccess.get_file_as_string(map_path))
		game.room_id = "r04"
		game.world.configure(game.room_config,game.actors)
		for index in range(game.actors.size()):
			var coords: Array = game.room_config.starts[index]
			game.actors[index].home=Vector2(coords[0],coords[1])
		game.guard.configure(game.world,game)
		game.reset_round(["lockpick","chat","backpack"],70)
	else:
		game.load_room("r04",["lockpick","chat","backpack"],70)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.schedule.clock_elapsed=(600-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	for actor in game.actors: actor.immune_until = INF
	game.routines.take_control(0)
	game.orders.clear()
	game.map_camera.following = false
	var results: Array = []
	for scene in [{"name":"corridor-day","point":Vector2(620,960),"camera":Vector2(900,700),"period":"day"},{"name":"workshop-day","point":Vector2(1040,440),"camera":Vector2(1100,570),"period":"day"},{"name":"corridor-night","point":Vector2(620,960),"camera":Vector2(900,700),"period":"night"}]:
		game.actors[0].position = scene.point
		game.map_camera.center_on(scene.camera)
		game.presentation.lighting.set_period(scene.period)
		var times: Array = []
		var started := Time.get_ticks_usec()
		var previous := started
		while Time.get_ticks_usec()-started < 5500000:
			var dt := minf(0.1,float(Time.get_ticks_usec()-previous)/1000000.0)
			game._process(dt)
			await process_frame
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			if now-started>1500000: times.append((now-previous)/1000.0)
			previous = now
		var total := 0.0
		for value in times: total+=value
		times.sort()
		results.append({"scene":scene.name,"fps":times.size()*1000.0/total,"p95_ms":times[floori(times.size()*0.95)],"frames":times.size(),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000})
	var tag := args[args.find("--tag")+1] if "--tag" in args else "after"
	var report := {"scenes":results,"adapter":RenderingServer.get_video_adapter_name(),"map_sha256":FileAccess.get_sha256(map_path if "--frozen-map" in args else "res://data/rooms/r04.json"),"frozen_map":"--frozen-map" in args,"has_visibility":game.get("room_visibility")!=null}
	FileAccess.open("res://docs/tests/p76-fps-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit()

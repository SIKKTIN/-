extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.load_room("r04",["lockpick","chat","backpack"],52)
	game.routine_panel.close();game.schedule.set_time_speed(0)
	game.schedule.clock_elapsed=(730-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false);game.room_access.tick()
	for actor in game.actors:actor.immune_until=INF
	game.routines.take_control(0);game.actors[0].position=Vector2(3500,1530)
	game.map_camera.center_on(Vector2(3280,1400));game.map_camera.following=false
	var started:=Time.get_ticks_msec()
	var next_sample:=started+4500
	var fps: Array=[]
	while Time.get_ticks_msec()-started<9500:
		await process_frame
		if Time.get_ticks_msec()>=next_sample:
			fps.append(Performance.get_monitor(Performance.TIME_FPS))
			next_sample+=500
	var report: Dictionary={"viewport":[1600,1000],"fps_samples_after_warmup":fps,
		"minimum_fps":fps.min(),"average_fps":fps.reduce(func(a,b):return a+b,0.0)/fps.size(),
		"walls":game.world.walls.size(),"fixtures":game.world.fixtures.size(),"navigation_builds":game.world.navigation_builds}
	FileAccess.open("res://docs/art/factory-detail-v44/performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	game.queue_free();await process_frame;quit()


extends SceneTree

var game
var label := "baseline"
var samples: Array = []

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func summarize(values: Array) -> Dictionary:
	values.sort()
	var total := 0.0
	for value in values: total += value
	var mean: float = total/values.size()
	return {"frames":values.size(),"fps":1000.0/mean,"mean_ms":mean,"p50_ms":values[values.size()/2],"p95_ms":values[mini(values.size()-1,floori(values.size()*0.95))]}

func measure(name: String, seconds: float, moving := false) -> void:
	await create_timer(1.0,true,false,true).timeout
	var started := Time.get_ticks_usec()
	var previous := started
	var times: Array = []
	var process_times: Array = []
	var draw_calls: Array = []
	var actual_fps: Array = []
	while Time.get_ticks_usec()-started < seconds*1000000:
		await frame()
		var now := Time.get_ticks_usec()
		times.append((now-previous)/1000.0)
		previous = now
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		actual_fps.append(Engine.get_frames_per_second())
		if moving:
			# A real moving actor with the normal continuous camera-follow tick.
			var t := (now-started)/1000000.0
			game.mobile_controls.direction = Vector2(0,1 if fmod(t,4.0)<2 else -1)
	game.mobile_controls.direction = Vector2.ZERO
	var result := summarize(times)
	result.name = name
	result.process = summarize(process_times)
	result.draw_calls = draw_calls.reduce(func(a,b): return a+b,0.0)/draw_calls.size()
	result.engine_fps = actual_fps.back()
	samples.append(result)
	print(JSON.stringify(result))

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): label = args[0]
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.load_room("r04",["chat","lockpick","backpack"],67)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.map_camera.center_on(game.actors[0].position)
	await measure("day_stationary",5)
	# Diagnostic toggles only, restore each immediately after measurement.
	var information = game.presentation.scene_layers.filter(func(n): return n.kind=="information")[0]
	information.hide()
	await measure("day_without_information",3)
	information.show()
	var micros := {}
	for method in ["view_polygon"]:
		var started := Time.get_ticks_usec()
		for i in range(15): game.guard.call(method)
		micros[method+"_ms"] = (Time.get_ticks_usec()-started)/15000.0
	var initial_position: Vector2 = game.guard.position
	var cold_start := Time.get_ticks_usec()
	for i in range(15):
		game.guard.position = initial_position+Vector2(i*0.01,0)
		game.guard.view_polygon()
	micros.view_polygon_uncached_ms = (Time.get_ticks_usec()-cold_start)/15000.0
	game.guard.position = initial_position
	game.actors[0].position = Vector2(540,530)
	game.map_camera.center_on(game.actors[0].position)
	await measure("day_moving",5,true)
	game.schedule.clock_elapsed = (1500.0-480)/1440*game.schedule.day_seconds
	game.schedule.tick(false)
	game.room_access.tick()
	await measure("night_inspection",5)
	game.prison_alert.missing_ids.append(0)
	game.prison_alert._raise_alarm()
	await measure("night_full_alert",5)
	var image := root.get_texture().get_image()
	image.save_png("res://docs/tests/p67-"+label+".png")
	var report := {"label":label,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"vsync":DisplayServer.window_get_vsync_mode(),"viewport":[1200,720],"samples":samples,"microbench":micros,"map_sha256":FileAccess.get_sha256("res://data/rooms/r04.json")}
	FileAccess.open("res://docs/tests/p67-"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit()


extends SceneTree
var game
var samples: Array = []
var label := "before"
var cold := false
func _initialize(): call_deferred("run")
func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	return {"mean_ms":values.reduce(func(a,b):return a+b,0.0)/values.size(),"p95_ms":sorted[floori((sorted.size()-1)*0.95)],"p99_ms":sorted[floori((sorted.size()-1)*0.99)],"max_ms":sorted.back()}
func sample(name: String, walking: bool):
	game.reset_round(["chat","backpack","strong"],96)
	game.tutorial.set_process(false)
	game.guard.position = game.actors[0].position+Vector2(147,2)
	game.tutorial._enter("follow_work")
	game.room_visibility.tick(0.5)
	game.map_camera.locate_selected()
	var frames: Array = []
	var process_cost: Array = []
	var sections := {}
	var slow: Array = []
	for i in range(0 if cold else 60):
		await process_frame
		game._process(1.0/60)
		await RenderingServer.frame_post_draw
	game.world.path_events.clear()
	game.world.nav_events.clear()
	var last := Time.get_ticks_usec()
	var steps := {}
	for i in range(360):
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-last)/1000.0)
		last = now
		if walking and i%45==0 and game.tutorial.step_id=="follow_work": game.orders.issue(0,game.tutorial._target("work_gate"),"manual")
		if walking and game.tutorial.speaking(): game.tutorial.speech.bubble.pressed.emit()
		var start := Time.get_ticks_usec()
		game._process(1.0/60)
		var ms := (Time.get_ticks_usec()-start)/1000.0
		process_cost.append(ms)
		steps[game.tutorial.step_id] = true
		for key in game.profile_sections:
			if not sections.has(key): sections[key]=[]
			sections[key].append(game.profile_sections[key])
		if ms>10: slow.append({"ms":ms,"frame":i,"sections":game.profile_sections.duplicate(),"step":game.tutorial.step_id})
		await RenderingServer.frame_post_draw
	var report_sections := {}
	for key in sections: report_sections[key]=stats(sections[key])
	var paths: Array = game.world.path_events
	var result := {"name":name,"frame":stats(frames),"process":stats(process_cost),"sections":report_sections,"steps":steps.keys(),"paths":stats(paths.map(func(p):return p.ms)),"path_calls":paths.size(),"slow_paths":paths.filter(func(p):return p.ms>2),"slow_frames":slow,"navigation_rebuilds":game.world.nav_events}
	samples.append(result)
	print(JSON.stringify(result))
func run():
	if not OS.get_cmdline_user_args().is_empty(): label=OS.get_cmdline_user_args()[0]
	cold = label.contains("cold")
	OS.set_environment("ESCAPE_TUTORIAL_MODE","on")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p96-benchmark.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p96-benchmark-layout.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://qa/p96_profile_game.gd").new()
	game.room_id="r04"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game.frame_settings.apply(60,false)
	await sample("follow_wait",false)
	await sample("follow_walk",true)
	FileAccess.open("res://docs/tests/p96-tutorial-"+label+".json",FileAccess.WRITE).store_string(JSON.stringify({"samples":samples,"gpu":RenderingServer.get_video_adapter_name(),"map_sha256":FileAccess.get_sha256("res://data/rooms/r04.json")},"\t"))
	quit()

extends SceneTree
var game
var report: Dictionary={}
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func stats(a: Array) -> Dictionary:
	var sorted:=a.duplicate()
	sorted.sort()
	return {"mean":a.reduce(func(x,y):return x+y,0.0)/a.size(),"p50":sorted[sorted.size()/2],"p95":sorted[int(sorted.size()*0.95)],"max":sorted.back()}
func sample(label: String,count: int) -> void:
	var times: Array=[]
	var scripts: Array=[]
	var sections: Dictionary={}
	var draws: Array=[]
	var spikes: Array=[]
	var over20:=0
	var last:=Time.get_ticks_usec()
	for i in range(count+90):
		await frame()
		var now:=Time.get_ticks_usec()
		var ms: float=(now-last)/1000.0
		last=now
		if i<90: continue
		times.append(ms)
		scripts.append(game.profile_total_ms)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		for key in game.profile_sections:
			if not sections.has(key):sections[key]=[]
			sections[key].append(game.profile_sections[key])
		if ms>20:over20+=1
		if ms>25:
			spikes.append({"index":i-90,"frame_ms":ms,"game_script_ms":game.profile_total_ms,"sections":game.profile_sections.duplicate(),"paths":game.world.pathfinding.frame_records.duplicate(true),"clock":game.schedule.clock_minutes(),"draw_calls":draws.back(),"fixture_revision":game.world.fixtures_revision,"texture_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0})
	var result: Dictionary={"frame_ms":stats(times),"game_script_ms":stats(scripts),"draw_calls":stats(draws),"over20ms":over20,"sample_frames":count,"spikes":spikes,"section_ms":{},"layer_draw_ms_last":{}}
	for key in sections:result.section_ms[key]=stats(sections[key])
	for layer in game.presentation.scene_layers:result.layer_draw_ms_last[layer.kind]=layer.draw_ms
	report[label]=result
	print(label+" "+JSON.stringify(result))
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_MODE","60")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p136-isolated-frame.cfg")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p136-isolated-dev.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	game.set_script(preload("res://qa/p136_pacing_game.gd"))
	root.add_child(game)
	await frame()
	game.load_room("r04",["chat","chat","backpack"],136)
	game.actors[0].position=Vector2(1640,1750)
	game.map_camera.center_on(game.actors[0].position)
	game.schedule.set_time_speed(1)
	await sample("cap60_running_time",900)
	game.frame_settings.apply(90,false)
	await sample("cap90_running_time",600)
	game.frame_settings.apply(0,false)
	await sample("uncapped_running_time",600)
	for hour in [9,12,14,17]:
		game.schedule.clock_elapsed=(hour*60.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
		await sample("hour_%d_transition" % hour,300)
	game.frame_settings.apply(60,false)
	var id: String=game.looting.containers.keys()[0]
	game.actors[0].position=game.looting.containers[id].fixture.rect.end+Vector2(12,5)
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(game.actors[0].position)
	game.looting.open(id)
	await sample("cap60_searching",600)
	FileAccess.open("res://docs/dev/p136/path-profile.json",FileAccess.WRITE).store_string(JSON.stringify({"native":true,"automatic_process":true,"time_speed":1,"viewport":[1200,720],"cases":report},"\t"))
	game.queue_free()
	await frame()
	await frame()
	quit()

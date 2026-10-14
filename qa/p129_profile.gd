extends SceneTree
var game
var rows: Dictionary={}

func _initialize():
	create_timer(120).timeout.connect(func():quit(124))
	call_deferred("run")

func sample(label: String):
	var cpu: Array=[]
	var frames: Array=[]
	var sections: Dictionary={}
	var draws: Array=[]
	var previous:=Time.get_ticks_usec()
	for i in range(260):
		var start:=Time.get_ticks_usec()
		game._process(1.0/60)
		game.fullscreen_ui.refresh()
		var elapsed: float=(Time.get_ticks_usec()-start)/1000.0
		await process_frame
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		if i>=60:
			cpu.append(elapsed)
			frames.append((now-previous)/1000.0)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			for key in game.profile_sections:
				if not sections.has(key):sections[key]=[]
				sections[key].append(game.profile_sections[key])
		previous=now
	var timings: Dictionary={}
	for key in sections:timings[key]=stats(sections[key])
	rows[label]={"cpu_ms":stats(cpu),"frame_ms":stats(frames),"draw_calls":stats(draws),"sections":timings}
	print(label+": "+JSON.stringify(rows[label]))

func stats(values: Array) -> Dictionary:
	values.sort()
	var total:=0.0
	for value in values:total+=value
	return {"mean":total/values.size(),"p50":values[values.size()/2],"p95":values[int(values.size()*0.95)]}

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_MODE","0")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p129-profile.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	game.set_script(preload("res://qa/p129_profile_game.gd"))
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["chat","chat","backpack"],129)
	game.fullscreen_ui.set_process(false)
	game.schedule.set_time_speed(0)
	game.actors[0].position=Vector2(430,1450)
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(game.actors[0].position)
	await sample("dorm_idle")
	await diagnose_draws()
	game.actors[0].position=Vector2(1640,1250)
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(game.actors[0].position)
	await sample("workshop_idle")
	var id: String=game.looting.containers.keys()[0]
	var rect: Rect2=game.looting.containers[id].fixture.rect
	game.actors[0].position=rect.end+Vector2(12,5)
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(game.actors[0].position)
	game.looting.open(id)
	game.looting.tick(30)
	await sample("looting_idle")
	var path:=OS.get_environment("ESCAPE_BENCHMARK_REPORT")
	if path.is_empty():path="res://docs/dev/p129/before.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"native":DisplayServer.get_name()!="headless","viewport":[1200,720],"frame_cap":Engine.max_fps,"samples":200,"cases":rows},"\t"))
	quit()

func diagnose_draws():
	var groups: Dictionary={"ground_static":[],"fixture_shadows":[],"volumes":game.presentation.volumes,"wall_edges":game.room_visibility.wall_edges.edges,"roofs":game.room_visibility.covers,"floor":[game.get_node("RetainedFloor")]}
	for layer in game.presentation.scene_layers:
		if groups.has(layer.kind):groups[layer.kind].append(layer)
	var results: Dictionary={}
	for key in groups:
		var restore: Array=[]
		for node in groups[key]:restore.append(node.visible);node.hide()
		for i in range(8):
			await process_frame
			await RenderingServer.frame_post_draw
		results[key]=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		for i in range(groups[key].size()):groups[key][i].visible=restore[i]
		for i in range(4):
			await process_frame
			await RenderingServer.frame_post_draw
	print("DRAW_DIAG: "+JSON.stringify(results))

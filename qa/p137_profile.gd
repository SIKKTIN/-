extends SceneTree
var game
var cases: Dictionary={}
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func stats(values: Array) -> Dictionary:
	var sorted:=values.duplicate()
	sorted.sort()
	return {"mean":values.reduce(func(a,b):return a+b,0.0)/values.size(),"p50":sorted[sorted.size()/2],"p95":sorted[int(sorted.size()*0.95)],"max":sorted.back()}
func sample(label: String,walking:=false, count:=360) -> void:
	var frames: Array=[]
	var script_time: Array=[]
	var draws: Array=[]
	var sections: Dictionary={}
	var presentation: Dictionary={}
	for i in range(count+100):
		var start:=Time.get_ticks_usec()
		game._process(1.0/60)
		if walking:
			var move_start:=Time.get_ticks_usec()
			game.world.move_actor(game.actors[0],Vector2(2 if i%60<30 else -2,0))
			game.profile_sections["player_collision_move"]=(Time.get_ticks_usec()-move_start)/1000.0
		var hud_start:=Time.get_ticks_usec()
		game.fullscreen_ui._process(1.0/60)
		game.profile_sections["fullscreen_hud"]=(Time.get_ticks_usec()-hud_start)/1000.0
		var total_script:=float(Time.get_ticks_usec()-start)/1000.0
		await frame()
		if i<100:continue
		frames.append(float(Time.get_ticks_usec()-start)/1000.0)
		script_time.append(total_script)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		for key in game.profile_sections:
			if not sections.has(key):sections[key]=[]
			sections[key].append(game.profile_sections[key])
		for key in game.presentation.profile_times:
			if not presentation.has(key):presentation[key]=[]
			presentation[key].append(game.presentation.profile_times[key])
	var section_stats: Dictionary={}
	var visual_stats: Dictionary={}
	for key in sections:section_stats[key]=stats(sections[key])
	for key in presentation:visual_stats[key]=stats(presentation[key])
	cases[label]={"frame_ms":stats(frames),"script_ms":stats(script_time),"draw_calls":stats(draws),"sections":section_stats,"visual_sections":visual_stats}
	print(label+" "+JSON.stringify(cases[label]))
func visit(point: Vector2) -> void:
	game.actors[0].position=point
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(point)
	game.presentation.tick(0)
	await frame()
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_MODE","0")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p137-profile.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	game.set_script(preload("res://qa/p137_profile_game.gd"))
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.load_room("r04",["chat","chat","backpack"],136)
	game.schedule.set_time_speed(0)
	await visit(Vector2(430,1450))
	await sample("dorm_idle")
	await visit(Vector2(1640,1750))
	await sample("workshop_idle")
	await visit(Vector2(740,2500))
	await sample("corridor_walk",true)
	var id: String=game.looting.containers.keys()[0]
	var rect: Rect2=game.looting.containers[id].fixture.rect
	await visit(rect.end+Vector2(12,5))
	game.looting.open(id)
	game.looting.tick(30)
	await sample("looting")
	game.looting.close()
	await visit(Vector2(1640,1750))
	var layers: Dictionary={"fixture_volumes":game.presentation.volumes.filter(func(v):return v.kind=="fixture"),"wall_volumes":game.presentation.volumes.filter(func(v):return v.kind=="wall"),"lighting":[game.presentation.lighting],"ground_static":[],"roofs":game.room_visibility.covers,"room_wall_edges":[game.room_visibility.wall_edges]}
	for layer in game.presentation.scene_layers:
		if layer.kind=="ground_static":layers.ground_static.append(layer)
	for name in layers:
		var restore: Array=[]
		for node in layers[name]:restore.append(node.visible);node.hide()
		await sample("render_without_"+name,false,180)
		for i in range(layers[name].size()):layers[name][i].visible=restore[i]
	var textures: Array=[]
	var seen: Dictionary={}
	for key in preload("res://scripts/presentation/world_texture.gd").cache:
		var texture: Texture2D=preload("res://scripts/presentation/world_texture.gd").cache[key]
		if texture==null or seen.has(texture.get_rid()):continue
		seen[texture.get_rid()]=true
		textures.append({"source":key,"dimensions":[texture.get_width(),texture.get_height()],"rgba_mips_mib":texture.get_width()*texture.get_height()*4.0*4.0/3.0/1048576.0})
	textures.sort_custom(func(a,b):return a.rgba_mips_mib>b.rgba_mips_mib)
	var report: Dictionary={"native":true,"viewport":[1200,720],"uncapped":Engine.max_fps==0,"driver":RenderingServer.get_current_rendering_driver_name(),"renderer":RenderingServer.get_current_rendering_method(),"cases":cases,"world":{"walls":game.world.walls.size(),"fixtures":game.world.fixtures.size(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"textures_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,"static_memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0},"largest_cached_textures":textures.slice(0,12)}
	FileAccess.open("res://docs/dev/p137/runtime-profile.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.queue_free()
	await frame()
	await frame()
	quit()

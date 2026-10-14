extends SceneTree
const OUT := "res://docs/performance/resource-audit-20261014/"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://resource-audit-20261014.cfg")
	root.size=Vector2i(1440,950);root.content_scale_size=root.size
	var started := Time.get_ticks_msec()
	var game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game)
	await process_frame
	var load_ms := Time.get_ticks_msec()-started
	root.title="监狱风云 · 临时资源测量"
	print("AUDIT_READY pid="+str(OS.get_process_id()))
	await create_timer(8.0).timeout
	var cache: Dictionary=preload("res://scripts/presentation/world_texture.gd").cache
	var rids := {};var biggest: Array=[];var pixels := 0
	for key in cache:
		var texture: Texture2D=cache[key]
		if texture==null or rids.has(texture.get_rid()):continue
		rids[texture.get_rid()]=true
		var area: int=texture.get_width()*texture.get_height();pixels+=area
		biggest.append({"key":key,"size":[texture.get_width(),texture.get_height()],"rgba_mib":float(area)*4/1048576.0})
	biggest.sort_custom(func(a,b):return a.rgba_mib>b.rgba_mib)
	biggest=biggest.slice(0,15)
	var monitors := {}
	var constants=ClassDB.class_get_integer_constant_list("Performance")
	for key in ["TIME_FPS","TIME_PROCESS","TIME_PHYSICS_PROCESS","MEMORY_STATIC","MEMORY_STATIC_MAX","OBJECT_NODE_COUNT","OBJECT_RESOURCE_COUNT","RENDER_TEXTURE_MEM_USED","RENDER_VIDEO_MEM_USED","RENDER_TOTAL_DRAW_CALLS_IN_FRAME","RENDER_TOTAL_OBJECTS_IN_FRAME"]:
		if key in constants:monitors[key]=Performance.get_monitor(ClassDB.class_get_integer_constant("Performance",key))
	var report := {"pid":OS.get_process_id(),"map":"r04","load_ms":load_ms,"rendering_method":RenderingServer.get_current_rendering_method(),"viewport":[root.size.x,root.size.y],"monitors":monitors,"world_texture_cache_entries":cache.size(),"unique_cached_texture_rids":rids.size(),"cached_rgba_base_mib_estimate":float(pixels)*4/1048576.0,"largest_cached_textures":biggest,"world_art_texture_keys":game.world.art_textures.size(),"fixture_count":game.world.fixtures.size(),"wall_count":game.world.walls.size()}
	FileAccess.open(OUT+"runtime-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("AUDIT_RESULT "+JSON.stringify(report))
	await create_timer(10.0).timeout
	quit()

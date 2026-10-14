extends SceneTree
var game
var samples: Dictionary={}
var measurements: Array=[]
func _initialize():
	create_timer(80).timeout.connect(func():quit(124))
	call_deferred("run")
func frame():
	await process_frame
	await RenderingServer.frame_post_draw
func metrics() -> Dictionary:
	return {"static_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"texture_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,"buffer_mib":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)/1048576.0,"video_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"fps":Performance.get_monitor(Performance.TIME_FPS),"cpu_frame_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
func stage(label: String, seconds: float):
	print("STAGE ",label)
	var values: Array=[]
	var until:=Time.get_ticks_msec()+roundi(seconds*1000)
	while Time.get_ticks_msec()<until:
		await frame()
		values.append(metrics())
	var summary: Dictionary={}
	for key in values[0]:
		var total:=0.0
		var peak:=0.0
		for row in values:total+=float(row[key]);peak=maxf(peak,float(row[key]))
		summary[key]={"mean":total/values.size(),"peak":peak,"last":values.back()[key]}
	samples[label]=summary
	print(label+" "+JSON.stringify(summary))
func visit(point: Vector2):
	game.actors[0].position=point
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(point)
	game.presentation.tick(0)
	for i in range(20):await frame()
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p132-memory.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	print("PID ",OS.get_process_id())
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.schedule.set_time_speed(0)
	await visit(Vector2(430,1450))
	await stage("dorm_idle",6)
	for cycle in range(3):
		for point in [Vector2(1640,1800),Vector2(2840,1750),Vector2(4600,2400),Vector2(3500,2780),Vector2(430,1450)]:await visit(point)
		measurements.append(metrics())
	await stage("after_room_visits",4)
	var id: String="detail44-dorm-personal-0"
	var rect: Rect2=game.looting.containers[id].fixture.rect
	await visit(rect.end+Vector2(16,5))
	game.looting.open(id)
	await stage("looting_open",5)
	game.looting.close()
	await visit(Vector2(430,1450))
	await stage("return_idle",5)
	var texture_rows: Array=[]
	var seen: Dictionary={}
	for key in preload("res://scripts/presentation/world_texture.gd").cache:
		var texture: Texture2D=preload("res://scripts/presentation/world_texture.gd").cache[key]
		if texture==null or seen.has(texture.get_rid()):continue
		seen[texture.get_rid()]=true
		texture_rows.append({"source":key,"width":texture.get_width(),"height":texture.get_height(),"estimated_rgba_mips_mib":texture.get_width()*texture.get_height()*4.0*4.0/3.0/1048576.0})
	texture_rows.sort_custom(func(a,b):return a.estimated_rgba_mips_mib>b.estimated_rgba_mips_mib)
	FileAccess.open("res://docs/dev/p132/texture-cache.json",FileAccess.WRITE).store_string(JSON.stringify(texture_rows,"\t"))
	FileAccess.open("res://docs/dev/p132/engine.json",FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"frame_cap":Engine.max_fps,"viewport":[1200,720],"cases":samples,"after_visit_cycles":measurements},"\t"))
	quit()

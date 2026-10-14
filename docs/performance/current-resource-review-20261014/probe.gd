extends SceneTree

const OUT := "res://docs/performance/current-resource-review-20261014/runtime.json"
const Textures = preload("res://scripts/presentation/world_texture.gd")
var report: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func stats(values: Array) -> Dictionary:
	values.sort()
	return {"mean": values.reduce(func(a,b):return a+b,0.0)/values.size(), "p95": values[int(values.size()*0.95)], "max":values.back()}

func sample(label: String, game, point: Vector2) -> void:
	game.map_camera.center_on(point)
	await create_timer(1.0).timeout
	var frames: Array = []
	var draws: Array = []
	var process_ms: Array = []
	var mark: int = Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now-mark)/1000.0)
		mark=now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
	report.cases[label]={"frame_ms":stats(frames),"draw_calls":stats(draws),"process_ms":stats(process_ms)}

func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://current-resource-review-20261014.cfg")
	OS.set_environment("ESCAPE_FRAME_MODE","0")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	var mark: int = Time.get_ticks_msec()
	var game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await process_frame
	await RenderingServer.frame_post_draw
	report={"first_frame_ms":Time.get_ticks_msec()-mark,"renderer":RenderingServer.get_current_rendering_method(),"viewport":[1200,720],"cases":{},"pid":OS.get_process_id(),"max_fps":Engine.max_fps}
	await sample("initial",game,game.actors[0].position)
	await sample("workshop_view",game,Vector2(1640,1750))
	await sample("courtyard_view",game,Vector2(740,2500))
	var monitors: Dictionary={}
	for key in ["MEMORY_STATIC","MEMORY_STATIC_MAX","OBJECT_NODE_COUNT","OBJECT_RESOURCE_COUNT","RENDER_TEXTURE_MEM_USED","RENDER_VIDEO_MEM_USED","RENDER_TOTAL_DRAW_CALLS_IN_FRAME","RENDER_TOTAL_OBJECTS_IN_FRAME"]:
		monitors[key]=Performance.get_monitor(ClassDB.class_get_integer_constant("Performance",key))
	report.monitors=monitors
	report.fixtures=game.world.fixtures.size()
	report.walls=game.world.walls.size()
	report.baked_hits=Textures.RuntimeStore.hits
	report.baked_misses=Textures.RuntimeStore.misses
	report.cache_entries=Textures.cache.size()
	var seen: Dictionary={}
	var totals: Dictionary={}
	var largest: Array=[]
	for key in Textures.cache:
		var tex: Texture2D=Textures.cache[key]
		if tex==null or seen.has(tex.get_rid()):continue
		seen[tex.get_rid()]=true
		var mib: float=tex.get_width()*tex.get_height()*4.0/1048576.0
		var category: String=str(key).trim_prefix("res://art/").split("/")[0]
		totals[category]=float(totals.get(category,0))+mib
		largest.append({"key":key,"width":tex.get_width(),"height":tex.get_height(),"rgba_base_mib_estimate":mib})
	largest.sort_custom(func(a,b):return a.rgba_base_mib_estimate>b.rgba_base_mib_estimate)
	report.unique_cache_rids=seen.size()
	report.cache_category_base_mib_estimate=totals
	report.largest=largest.slice(0,12)
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CURRENT_RESOURCE_REVIEW_COMPLETE")
	quit()

extends SceneTree
const ProfileLayer = preload("res://qa/p78_profile_layer.gd")
var game
var records: Array = []
func _initialize() -> void: call_deferred("run")
func frame(point: Vector2, event: String) -> void:
	game.set_meta("roof_probe_event",event)
	game.actors[0].position=point
	var start := Time.get_ticks_usec()
	game.room_visibility.tick(1.0/60)
	var roof_ms := (Time.get_ticks_usec()-start)/1000.0
	var present_start := Time.get_ticks_usec()
	game.presentation.tick(1.0/60)
	var present_ms := (Time.get_ticks_usec()-present_start)/1000.0
	await process_frame
	await RenderingServer.frame_post_draw
	records.append({"event":event,"frame_ms":(Time.get_ticks_usec()-start)/1000.0,"roof_ms":roof_ms,"present_ms":present_ms})
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],70)
	game.routine_panel.close()
	game.orders.clear()
	game.schedule.set_time_speed(0)
	game.map_camera.following=false
	var layers: Array=[]
	for old in game.presentation.scene_layers:
		var layer=ProfileLayer.new()
		game.add_child(layer)
		layer.configure(game,game.presentation,old.kind)
		layers.append(layer)
		old.free()
	game.presentation.scene_layers=layers
	for period in ["day","night"]:
		game.presentation.lighting.set_period(period)
		for case in [{"id":"workshop","outside":Vector2(1340,1080),"inside":Vector2(1340,1016),"camera":Vector2(1450,980)},{"id":"cafeteria","outside":Vector2(1060,1380),"inside":Vector2(1060,1444),"camera":Vector2(1350,1500)},{"id":"warehouse","outside":Vector2(2540,950),"inside":Vector2(2640,950),"camera":Vector2(2740,1000)}]:
			game.map_camera.center_on(case.camera)
			for i in range(18): await frame(case.outside,"warm")
			for repeat in range(5):
				await frame(case.inside,period+"-"+case.id+"-enter")
				for i in range(14): await frame(case.inside,"steady")
				await frame(case.outside,period+"-"+case.id+"-leave")
				for i in range(14): await frame(case.outside,"steady")
	var summary := {}
	for sample in records:
		if sample.event not in summary: summary[sample.event]={"frames":[],"roof":[],"presentation":[]}
		summary[sample.event].frames.append(sample.frame_ms)
		summary[sample.event].roof.append(sample.roof_ms)
		summary[sample.event].presentation.append(sample.present_ms)
	for key in summary:
		var row: Dictionary=summary[key]
		for metric in ["frames","roof","presentation"]:
			var values: Array=row[metric]
			values.sort()
			row[metric]={"median":values[values.size()/2],"max":values.back(),"p95":values[floori(values.size()*0.95)]}
	var draws := {}
	for layer in layers:
		var changes: Array=layer.draws.filter(func(d):return d.event.ends_with("-enter") or d.event.ends_with("-leave"))
		var durations: Array=changes.map(func(d):return d.ms)
		durations.sort()
		draws[layer.kind]={"transition_draws":durations.size(),"total_draws":layer.draws.size(),"max_ms":0 if durations.is_empty() else durations.back(),"median_ms":0 if durations.is_empty() else durations[durations.size()/2]}
	var args:=OS.get_cmdline_user_args()
	var tag: String=args[args.find("--tag")+1] if "--tag" in args else "after"
	var report: Dictionary={"summary":summary,"layer_draws":draws,"map_sha256":FileAccess.get_sha256("res://data/rooms/r04.json"),"adapter":RenderingServer.get_video_adapter_name(),"records":records}
	FileAccess.open("res://docs/tests/p78-doorways-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"tag":tag,"summary":summary,"layer_draws":draws}))
	quit()

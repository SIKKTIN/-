extends SceneTree
var editor
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func summary(samples: Array) -> Dictionary:
	var ordered:=samples.duplicate()
	ordered.sort()
	return {"mean_ms":samples.reduce(func(a,b):return a+b,0.0)/samples.size(),"p95_ms":ordered[int(ordered.size()*0.95)],"samples":samples.size()}
func run() -> void:
	var label: String=OS.get_cmdline_user_args()[0]
	root.size=Vector2i(1200,760)
	root.content_scale_size=root.size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	if label=="before-clean":
		editor=Control.new()
		editor.set_script(load("res://docs/dev/p135/baseline/map_editor.gd"))
	else:editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	for connection in root.get_signal_connection_list("focus_exited"):
		root.disconnect("focus_exited",connection.callable)
	await frame()
	await frame()
	editor.canvas.zoom=0.65
	editor.canvas.origin=editor.canvas.size/2-Vector2(700,3700)*0.65
	editor.canvas.queue_redraw()
	for i in range(20):await frame()
	var result: Dictionary={}
	var samples: Array=[]
	var cpu: Array=[]
	var draws: Array=[]
	for i in range(90):
		var start:=Time.get_ticks_usec()
		editor.canvas.origin+=Vector2(1 if i%30<15 else -1,0.5)
		editor.canvas.queue_redraw()
		await frame()
		samples.append(float(Time.get_ticks_usec()-start)/1000)
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	result.pan=summary(samples)
	result.pan.cpu=summary(cpu)
	result.pan.draw_calls=draws.reduce(func(a,b):return a+b,0.0)/draws.size()
	var fixture_index:=0
	for i in range(editor.document.data.fixtures.size()):
		if editor.catalog.assets.get(str(editor.document.data.fixtures[i].asset_id),{}).get("render_mode","")=="projected_prop":
			fixture_index=i
			break
	var ref: Dictionary={"group":"fixtures","index":fixture_index}
	var point: Vector2=editor.document.geometry(ref).position
	editor.canvas.choose(ref)
	editor.canvas.drag_ref=ref.duplicate()
	editor.document.begin()
	samples.clear()
	for i in range(24):
		var start:=Time.get_ticks_usec()
		editor.document.move(ref,point+Vector2(20 if i%2==0 else 0,0))
		await frame()
		samples.append(float(Time.get_ticks_usec()-start)/1000)
	result.drag=summary(samples)
	editor.canvas.finish_gesture(true)
	await frame()
	result.wall_count=editor.document.data.walls.size()
	result.fixture_count=editor.document.data.fixtures.size()
	FileAccess.open("res://docs/dev/p135/"+label+"-profile.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	editor.queue_free()
	await frame()
	await frame()
	quit()

extends SceneTree
const OUT := "res://docs/art/seaside-swe-v1/"
var demo
func _initialize() -> void:
	create_timer(30).timeout.connect(func():quit(124))
	call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	root.size=Vector2i(1200,812); root.content_scale_size=root.size; Engine.max_fps=60
	var style:=OS.get_cmdline_user_args().has("--style")
	demo=load("res://scenes/prototypes/seaside_swe_style_demo.tscn" if style else "res://scenes/prototypes/seaside_swe_demo.tscn").instantiate(); root.add_child(demo)
	var solver=demo.solver
	while not solver.initialized: await frame()
	await create_timer(3).timeout
	var intervals: Array=[]
	var began:=Time.get_ticks_usec()
	var sim_before:float=solver.sim_time
	for i in 180:
		var t:=Time.get_ticks_usec(); await frame(); intervals.append((Time.get_ticks_usec()-t)/1000.0)
	var elapsed:float=(Time.get_ticks_usec()-began)/1000000.0
	var sim_elapsed:float=solver.sim_time-sim_before
	intervals.sort()
	solver.paused=true
	for i in 3: await frame()
	solver.request_snapshot(); var pause_before:Dictionary=await solver.snapshot_ready
	for i in 20: await frame()
	solver.request_snapshot(); var pause_after:Dictionary=await solver.snapshot_ready
	var pause_ok:bool=pause_before.state==pause_after.state and pause_before.sim_time==pause_after.sim_time
	solver.paused=false
	await create_timer(.5).timeout
	var resumed:bool=solver.sim_time>pause_after.sim_time+.35
	demo._metrics(); await frame(); await frame()
	root.get_texture().get_image().save_png(("res://docs/art/seaside-swe-style-v2/" if style else OUT)+"interactive-live.png")
	# Hidden/minimized windows may keep processing without rendering new frames.
	RenderingServer.render_loop_enabled=false
	for i in 4: await process_frame
	var hidden_time:float=solver.sim_time
	for i in 180: await process_frame
	var hidden_ok:bool=solver.sim_time==hidden_time
	RenderingServer.render_loop_enabled=true
	await create_timer(.5).timeout
	var hidden_resume:bool=solver.sim_time>hidden_time+.30
	var checks:Dictionary={"paused_state_exactly_unchanged":pause_ok,"resume_advances_simulation":resumed,
		"real_time_simulation_rate":sim_elapsed/elapsed>.94 and sim_elapsed/elapsed<1.06,
		"frame_p95_below_20ms":intervals[171]<20,"no_compute_when_rendering_stops":hidden_ok,
		"resume_after_rendering_stops":hidden_resume}
	var data:Dictionary={"checks":checks,"device":solver.gpu_name,"measured_frames":180,
		"average_fps":180.0/elapsed,"frame_median_ms":intervals[90],"frame_p95_ms":intervals[171],
		"simulation_seconds_per_wall_second":sim_elapsed/elapsed,"snapshot":("res://docs/art/seaside-swe-style-v2/" if style else OUT)+"interactive-live.png",
		"scope":"automatic interactive prototype, capped to 60 FPS; not whole-game performance"}
	FileAccess.open(("res://docs/art/seaside-swe-style-v2/" if style else OUT)+"interactive-checks.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("SWE interactive checks: ",JSON.stringify(data))
	quit(0 if checks.values().all(func(v):return v) else 1)

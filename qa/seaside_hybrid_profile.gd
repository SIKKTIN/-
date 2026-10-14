extends SceneTree
const OUT:="res://docs/art/seaside-hybrid-v3/"
func _initialize() -> void:
	create_timer(30).timeout.connect(func():quit(124));call_deferred("run")
func frame() -> void:
	await process_frame;await RenderingServer.frame_post_draw
func run() -> void:
	root.size=Vector2i(1200,812);root.content_scale_size=root.size;Engine.max_fps=60
	var demo=load("res://scenes/prototypes/seaside_hybrid_demo.tscn").instantiate();root.add_child(demo)
	var solver=demo.solver;solver.automatic=false
	while not solver.initialized or solver.busy:await frame()
	for i in 150:solver.advance(24);await solver.advanced;await frame()
	solver.automatic=true;demo.spray.restart();await create_timer(1.5).timeout
	var compute:Array=[];var render:Array=[];var frames:Array=[]
	var start:=Time.get_ticks_usec();var sim_start:float=solver.sim_time
	for i in 180:
		var t:=Time.get_ticks_usec();await frame();frames.append((Time.get_ticks_usec()-t)/1000.0)
		compute.append(solver.compute_gpu_ms);render.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	var wall:float=(Time.get_ticks_usec()-start)/1000000.0;compute.sort();render.sort();frames.sort()
	var result:Dictionary={"device":solver.gpu_name,"frames":180,"average_fps":180.0/wall,"frame_median_ms":frames[90],"frame_p95_ms":frames[171],
		"compute_median_ms":compute[90],"compute_p95_ms":compute[171],"render_median_ms":render[90],"render_p95_ms":render[171],
		"simulation_rate":(solver.sim_time-sim_start)/wall,"simulation_texture_mib":solver.simulation_bytes()/1048576.0,
		"bounded_particle_slots":demo.spray.amount,"scope":"Final automatic-mode independent prototype; foam-triggered GPU spray enabled. Whole game and mobile unmeasured."}
	result.passed=result.frame_p95_ms<20 and result.simulation_rate>.94 and result.simulation_rate<1.06
	FileAccess.open(OUT+"performance-final.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	demo._metrics();await frame();await frame();root.get_texture().get_image().save_png(OUT+"interactive-live.png")
	print("HYBRID FINAL PERFORMANCE: ",JSON.stringify(result));quit(0 if result.passed else 1)

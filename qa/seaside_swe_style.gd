extends SceneTree
const OUT := "res://docs/art/seaside-swe-style-v2/"
const Solver = preload("res://scenes/prototypes/seaside_swe_solver.gd")
var demo
var solver
var report := {}

func _initialize() -> void:
	create_timer(100).timeout.connect(func():quit(124))
	call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func ready_solver() -> void:
	while not solver.initialized or solver.busy: await frame()
func steps(count: int) -> void:
	while count>0:
		await ready_solver()
		var n:=mini(count,24)
		solver.advance(n); await solver.advanced; await frame(); count-=n
func profile() -> Dictionary:
	for i in 30:
		solver.advance(2); await solver.advanced; await frame()
	var compute: Array=[]; var render: Array=[]; var cpu: Array=[]; var interval: Array=[]
	var start:=Time.get_ticks_usec()
	for i in 180:
		var time:=Time.get_ticks_usec()
		solver.advance(2); await solver.advanced; await frame()
		compute.append(solver.compute_gpu_ms)
		render.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		interval.append((Time.get_ticks_usec()-time)/1000.0)
	var elapsed:float=(Time.get_ticks_usec()-start)/1000000.0
	compute.sort(); render.sort(); cpu.sort(); interval.sort()
	return {"grid":[solver.grid_size.x,solver.grid_size.y],"compute_gpu_median_ms":compute[90],
		"compute_gpu_p95_ms":compute[171],"render_gpu_median_ms":render[90],"render_gpu_p95_ms":render[171],
		"estimated_combined_gpu_median_ms":compute[90]+render[90],"render_cpu_median_ms":cpu[90],
		"frame_median_ms":interval[90],"frame_p95_ms":interval[171],"average_fps":180.0/elapsed,
		"simulation_texture_mib":solver.grid_size.x*solver.grid_size.y*44.0/1048576,
		"reported_scene_video_memory_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
		"frames":180,"fixed_step_hz":120,"steps_per_frame":2,
		"note":"Compute and viewport render timings are separate scopes; combined value is their median sum, not a full-game GPU measurement."}
func replace_solver(size: Vector2i) -> void:
	solver.queue_free()
	for i in 3: await frame()
	solver=Solver.new(); solver.grid_size=size; solver.automatic=false
	demo.solver=solver
	solver.textures_ready.connect(demo._refresh); solver.advanced.connect(demo._refresh)
	demo.add_child(solver)
	await ready_solver()
func run() -> void:
	root.size=Vector2i(1200,812); root.content_scale_size=root.size; Engine.max_fps=60
	demo=load("res://scenes/prototypes/seaside_swe_style_demo.tscn").instantiate(); root.add_child(demo)
	solver=demo.solver; solver.automatic=false; await ready_solver()
	report.device=solver.gpu_name
	await steps(1200)
	# Render the exact same numerical state with both materials for a visual comparison.
	demo.use_style(false); await frame(); await frame()
	root.get_texture().get_image().save_png(OUT+"before-water.png")
	demo.use_style(true); await frame(); await frame()
	root.get_texture().get_image().save_png(OUT+"after-water.png")
	demo.use_style(false); report.previous_material=await profile()
	demo.use_style(true); report.adapted_material=await profile()
	# Resolution scaling of the same simulation, art and viewport.
	await replace_solver(Vector2i(256,170)); report.low_resolution=await profile()
	await replace_solver(Vector2i(512,342)); report.high_resolution=await profile()
	await replace_solver(Vector2i(384,256)); await steps(1800)
	demo._metrics(); await frame(); await frame()
	root.get_texture().get_image().save_png(OUT+"style-preview.png")
	DirAccess.make_dir_recursive_absolute(OUT+"frames/")
	for i in 60:
		await steps(12); await frame(); await frame()
		root.get_texture().get_image().save_png(OUT+"frames/%03d.png" % i)
	var checks:Dictionary={"original_and_style_share_solver":demo.solver.get_script()==Solver,
		"pier_texture_loaded":demo.pier_art!=null,"game_grass_loaded":demo.grass_art!=null,
		"game_character_loaded":demo.player_art!=null,
		"style_compute_gpu_p95_under_1ms":report.adapted_material.compute_gpu_p95_ms>0 and report.adapted_material.compute_gpu_p95_ms<1,
		"style_render_gpu_p95_under_2ms":report.adapted_material.render_gpu_p95_ms>0 and report.adapted_material.render_gpu_p95_ms<2,
		"style_frame_p95_under_20ms":report.adapted_material.frame_p95_ms<20,
		"all_resolutions_profiled":report.low_resolution.compute_gpu_median_ms>0 and report.high_resolution.compute_gpu_median_ms>0}
	report.checks=checks
	report.scope="Independent sea prototype on RTX 4050, 1200x812 output, capped 60 FPS; not whole-map or mobile performance. Shader simulation is unchanged."
	FileAccess.open(OUT+"performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SWE style profile: ",JSON.stringify(report))
	quit(0 if checks.values().all(func(v):return v) else 1)

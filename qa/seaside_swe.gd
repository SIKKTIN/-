extends SceneTree
const OUT := "res://docs/art/seaside-swe-v1/"
var demo
var solver
var checks := {}
var report := {}

func _initialize() -> void:
	create_timer(180).timeout.connect(func(): quit(124))
	call_deferred("run")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func ready_solver() -> void:
	while not solver.initialized or solver.busy: await frame()

func steps(count: int) -> void:
	while count > 0:
		await ready_solver()
		var batch := mini(count, 24)
		solver.advance(batch)
		await solver.advanced
		await frame()
		count -= batch

func reset_case(waves: bool, piers: bool, flat: bool, mode: float, foam: bool = true) -> void:
	await ready_solver()
	solver.waves_enabled=waves; solver.piers_enabled=piers; solver.flat_bed=flat
	solver.initial_mode=mode; solver.foam_enabled=foam
	solver.reset(); await solver.advanced
	await frame()

func snapshot() -> Dictionary:
	await ready_solver()
	solver.request_snapshot()
	return await solver.snapshot_ready

func stats(data: Dictionary) -> Dictionary:
	var a: PackedFloat32Array=data.state
	var bed: PackedFloat32Array=data.bed
	var result := {"finite": true, "max_depth": 0.0, "max_surface_abs": 0.0,
		"max_speed":0.0, "foam_sum":0.0, "max_foam":0.0, "solid_max_depth":0.0, "foam_center_x":0.0}
	for j in bed.size():
		var k:=j*4; var h:=a[k]; var foam:=a[k+3]
		for c in 4:
			if not is_finite(a[k+c]): result.finite=false
		result.max_depth=maxf(result.max_depth,h)
		result.max_speed=maxf(result.max_speed,Vector2(a[k+1],a[k+2]).length())
		# Sub-millimetre water is intentionally treated as dry by the solver.
		if bed[j]<-.002: result.max_surface_abs=maxf(result.max_surface_abs,absf(h+bed[j]))
		if bed[j]>.65: result.solid_max_depth=maxf(result.solid_max_depth,h)
		result.foam_sum+=foam
		result.foam_center_x+=float(j % data.size.x)/data.size.x*foam
		result.max_foam=maxf(result.max_foam,foam)
	if result.foam_sum>0: result.foam_center_x/=result.foam_sum
	return result

func annulus_energy(data: Dictionary, center: Vector2, inner: float, outer: float) -> float:
	var energy:=0.0
	var a: PackedFloat32Array=data.state; var bed: PackedFloat32Array=data.bed
	for y in data.size.y:
		for x in data.size.x:
			var d:float=((Vector2(x,y)/Vector2(data.size)-center)*Vector2(1.5,1)).length()
			if d>inner and d<outer:
				var i:int=y*data.size.x+x
				energy+=absf(a[i*4]+bed[i])
	return energy

func timing() -> Dictionary:
	var gpu: Array=[]; var wall: Array=[]; var viewport: Array=[]
	for i in 30: solver.advance(2); await solver.advanced; await frame()
	for i in 120:
		var t:=Time.get_ticks_usec()
		solver.advance(2); await solver.advanced; await frame()
		wall.append((Time.get_ticks_usec()-t)/1000.0)
		if solver.compute_gpu_ms>=0: gpu.append(solver.compute_gpu_ms)
		viewport.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	gpu.sort(); wall.sort(); viewport.sort()
	return {"grid":[solver.grid_size.x,solver.grid_size.y],"steps_per_frame":2,"fixed_step_seconds":solver.FIXED_DT,
		"compute_gpu_median_ms":gpu[gpu.size()/2] if not gpu.is_empty() else -1,
		"compute_gpu_p95_ms":gpu[int(gpu.size()*.95)] if not gpu.is_empty() else -1,
		"viewport_render_gpu_median_ms":viewport[60],"qa_iteration_median_ms":wall[60],
		"qa_iteration_p95_ms":wall[114],"frames":120,
		"note":"QA iteration includes asynchronous completion and capture synchronization; viewport timing excludes compute submitted outside viewport."}

func run() -> void:
	root.size=Vector2i(1200,812); root.content_scale_size=root.size
	root.title="2D 计算海水 · 数值与原生渲染验证"
	Engine.max_fps=60
	demo=load("res://scenes/prototypes/seaside_swe_demo.tscn").instantiate()
	root.add_child(demo); solver=demo.solver; solver.automatic=false
	await ready_solver()
	report.device=solver.gpu_name
	# Lake at rest: non-flat bathymetry must not spontaneously produce flow.
	await reset_case(false,true,false,0)
	await steps(240)
	var calm:=stats(await snapshot())
	checks.lake_at_rest=calm.max_surface_abs<.0002 and calm.max_speed<.0002
	report.lake_at_rest=calm
	# A local height impulse must propagate outside its initially excited area.
	await reset_case(false,false,true,0)
	solver.add_impulse(Vector2(.25,.28),.4)
	await steps(1)
	var early:=await snapshot()
	await steps(215)
	var later:=await snapshot()
	var before:=annulus_energy(early,Vector2(.25,.28),.05,.09)
	var after:=annulus_energy(later,Vector2(.25,.28),.05,.09)
	checks.impulse_propagates=after>before*2.0+0.1
	report.propagation={"initial_annulus_energy":before,"after_1_8_seconds":after}
	# Isolated foam: no production, uniform flow and known exponential decay.
	await reset_case(false,false,true,2,false)
	var foam_before:=stats(await snapshot())
	await steps(480)
	var foam_after:=stats(await snapshot())
	checks.foam_advects=foam_after.foam_center_x-foam_before.foam_center_x>.01
	checks.foam_decays=foam_after.foam_sum>0 and foam_after.foam_sum<foam_before.foam_sum*.5
	report.foam_transport={"before":foam_before,"after_4_seconds":foam_after}
	# Identical incoming waves with and without solid bridge piers.
	await reset_case(true,false,false,1)
	await steps(960)
	var no_piers:=await snapshot()
	await reset_case(true,true,false,1)
	await steps(960)
	var with_piers:=await snapshot()
	var pier_stats:=stats(with_piers)
	var difference:=0.0; var compared:=0
	for y in range(int(solver.grid_size.y*.34),int(solver.grid_size.y*.80)):
		for x in range(int(solver.grid_size.x*.40),int(solver.grid_size.x*.60)):
			var j:int=y*solver.grid_size.x+x
			if with_piers.bed[j]<-.1 and no_piers.bed[j]<-.1:
				difference+=absf(with_piers.state[j*4]-no_piers.state[j*4]); compared+=1
	checks.piers_change_flow=difference/compared>.002
	checks.piers_are_dry=pier_stats.solid_max_depth<.01
	checks.foam_generated_by_flow=pier_stats.foam_sum>10 and pier_stats.max_foam>.03
	report.piers={"mean_depth_difference_outside_solids":difference/compared,"compared_cells":compared,"stats":pier_stats}
	# Long run catches NaNs, instability and wet/dry growth, beyond a screenshot test.
	await steps(7200)
	var stable:=stats(await snapshot())
	checks.long_run_finite=stable.finite and stable.max_depth<8 and stable.max_speed<15 and stable.solid_max_depth<.01
	report.long_run={"seconds":solver.sim_time,"stats":stable}
	# Warm default sea and capture both visible effect and computational fields.
	await reset_case(true,true,false,1)
	await steps(1800)
	for i in 3: await frame()
	demo.set_view(0); await frame(); await frame()
	root.get_texture().get_image().save_png(OUT+"water-surface.png")
	demo.set_view(1); await frame(); await frame()
	root.get_texture().get_image().save_png(OUT+"water-height.png")
	demo.set_view(3); await frame(); await frame()
	root.get_texture().get_image().save_png(OUT+"water-foam.png")
	demo.set_view(0)
	report.performance=await timing()
	checks.compute_timing_available=report.performance.compute_gpu_median_ms>0
	checks.compute_under_budget=report.performance.compute_gpu_p95_ms<4.0 and report.performance.compute_gpu_p95_ms>0
	DirAccess.make_dir_recursive_absolute(OUT+"frames/")
	# 6 seconds recorded at 10 fps, each frame advances exactly 0.1 simulation seconds.
	for i in 60:
		await steps(12); await frame(); await frame()
		root.get_texture().get_image().save_png(OUT+"frames/%03d.png" % i)
	report.checks=checks
	report.implementation="GPU shallow-water height/velocity + persistent advected foam; no generated water imagery. Independent scene; live map unchanged."
	report.output="native Godot framebuffer captures"
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SWE checks: ",JSON.stringify(checks))
	print("SWE performance: ",JSON.stringify(report.performance))
	quit(0 if checks.values().all(func(v):return v) else 1)

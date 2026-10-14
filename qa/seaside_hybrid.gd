extends SceneTree
const OUT:="res://docs/art/seaside-hybrid-v3/"
var demo
var solver
var report:Dictionary={"checks":{},"scope":"Independent 1200x812 prototype, capped 60 FPS; whole game and mobile unmeasured."}
func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(124));call_deferred("run")
func frame() -> void:
	await process_frame;await RenderingServer.frame_post_draw
func ready_solver() -> void:
	while not solver.initialized or solver.busy:await frame()
func steps(count: int) -> void:
	while count>0:
		await ready_solver();var n:=mini(count,24);solver.advance(n);await solver.advanced;await frame();count-=n
func snapshot() -> Dictionary:
	await ready_solver();solver.request_snapshot();return await solver.snapshot_ready
func reset() -> void:
	await ready_solver();solver.reset();await solver.advanced;await frame()
func check(name: String,value: bool) -> void:
	report.checks[name]=value;print(name,": ",value)
func foam_stats(data: Dictionary,channel: int) -> Dictionary:
	var mass:=0.0;var moment:=0.0
	for i in data.foam.size()/4:
		var f:float=data.foam[i*4+channel];mass+=f;moment+=f*float(i%solver.grid_size.x)/solver.grid_size.x
	return {"mass":mass,"x":moment/maxf(mass,0.00001)}
func run() -> void:
	root.size=Vector2i(1200,812);root.content_scale_size=root.size;Engine.max_fps=60
	demo=load("res://scenes/prototypes/seaside_hybrid_demo.tscn").instantiate();root.add_child(demo)
	solver=demo.solver;solver.automatic=false;await ready_solver();report.device=solver.gpu_name
	solver.qa_single_mode=true;await steps(1);var single:Dictionary=await snapshot()
	var maximum_error:=0.0;var displacement_error:=0.0
	for y in 128:
		for x in 128:
			var angle:=TAU*(3.0*x+5.0*y)/128.0;var i:=(y*128+x)*4
			maximum_error=maxf(maximum_error,absf(single.ocean[i]-cos(angle)))
			displacement_error=maxf(displacement_error,absf(single.ocean[i+1]-sin(angle)*3.0/sqrt(34.0)))
	report.fft_max_height_error=maximum_error;report.fft_max_chop_error=displacement_error
	check("ifft_2d_matches_analytical_oblique_cosine",maximum_error<0.00002 and displacement_error<0.00002)
	solver.qa_single_mode=false;solver.waves_enabled=false;solver.flat_bed=true;solver.piers_enabled=false;solver.initial_mode=0;solver.foam_enabled=false
	await reset();await steps(120);var calm:Dictionary=await snapshot();var rest_error:=0.0
	for i in calm.bed.size():rest_error=maxf(rest_error,absf(calm.state[i*4]-3.0))
	check("lake_at_rest_stays_at_rest",rest_error<0.00005)
	solver.add_impulse(Vector2(.25,.30));await steps(300);var pulse:Dictionary=await snapshot();var ring:=0.0
	for y in solver.grid_size.y:
		for x in solver.grid_size.x:
			var world:Vector2=(Vector2(x,y)/Vector2(solver.grid_size)-Vector2(.25,.30))*Vector2(solver.grid_size)*solver.WIDTH_METRES/solver.grid_size.x
			if world.length()>7.0 and world.length()<15.0:ring=maxf(ring,absf(pulse.state[(y*solver.grid_size.x+x)*4]-3.0))
	check("local_disturbance_propagates",ring>.005)
	solver.initial_mode=2;solver.foam_transport_only=true;await reset()
	var foam_start:Dictionary=await snapshot();var before0:=foam_stats(foam_start,0);var before1:=foam_stats(foam_start,1)
	await steps(240);var foam_end:Dictionary=await snapshot();var after0:=foam_stats(foam_end,0);var after1:=foam_stats(foam_end,1)
	report.foam_transport={"density_start":before0,"density_end":after0,"detail_start":before1,"detail_end":after1}
	check("foam_density_and_detail_both_advect",after0.x>before0.x+.008 and after1.x>before1.x+.008)
	check("foam_density_and_detail_decay",after0.mass<before0.mass*.8 and after1.mass<before1.mass*.8)
	var parcel_index:int=(int(solver.grid_size.y*.5)*solver.grid_size.x+int(solver.grid_size.x*.3))*4+2
	report.foam_transport.parcel_x_start=foam_start.foam[parcel_index];report.foam_transport.parcel_x_end=foam_end.foam[parcel_index]
	check("foam_material_coordinates_travel_with_flow",foam_end.foam[parcel_index]<foam_start.foam[parcel_index]-1.0)
	solver.initial_mode=1;solver.foam_transport_only=false;solver.flat_bed=false;solver.piers_enabled=true;solver.waves_enabled=true;solver.foam_enabled=true
	await reset();await steps(2400);var first:Dictionary=await snapshot()
	var rms:=0.0;var small_rms:=0.0
	for i in 128*128:rms+=pow(first.ocean[i*4],2);small_rms+=pow(first.ocean_small[i*4],2)
	report.spectrum_rms_metres=[sqrt(rms/16384),sqrt(small_rms/16384)]
	check("both_spectral_scales_have_energy",report.spectrum_rms_metres[0]>.1 and report.spectrum_rms_metres[1]>.02)
	await steps(60);var second:Dictionary=await snapshot();var difference:=0.0
	for i in 128*128:difference+=absf(first.ocean[i*4]-second.ocean[i*4])
	check("spectral_waves_evolve_in_time",difference/16384>.02)
	await steps(4740);var stable:Dictionary=await snapshot()
	var finite:=true;var max_depth:=0.0;var max_speed:=0.0;var dry_pier:=0.0;var foam_sum:=0.0;var spray_sources:=0
	for i in stable.bed.size():
		var h:float=stable.state[i*4];var v:=Vector2(stable.state[i*4+1],stable.state[i*4+2])
		finite=finite and is_finite(h) and is_finite(v.x) and is_finite(v.y)
		max_depth=maxf(max_depth,h);max_speed=maxf(max_speed,v.length())
		if stable.bed[i]>1.5:dry_pier=maxf(dry_pier,h)
		foam_sum+=stable.foam[i*4]
		if h>.012 and h<1.0 and stable.bed[i]>-1.4 and stable.foam[i*4]>.2:spray_sources+=1
	report.stability={"simulated_seconds":stable.sim_time,"max_depth":max_depth,"max_speed":max_speed,"solid_pier_water":dry_pier,"foam_sum":foam_sum,"spray_source_cells":spray_sources}
	check("60_seconds_hybrid_simulation_finite",finite and max_depth<8 and max_speed<15)
	check("solid_bridge_piers_block_water",dry_pier<.0001)
	check("computed_breaking_generates_foam_and_spray_sources",foam_sum>20 and spray_sources>10)
	demo._metrics();await frame();await frame();root.get_texture().get_image().save_png(OUT+"preview.png")
	demo.set_view(3);await frame();await frame();root.get_texture().get_image().save_png(OUT+"foam-state.png");demo.set_view(0)
	# Actual automatic-mode frame timing, without readbacks or recording inside this scope.
	solver.automatic=true;await create_timer(1).timeout
	var compute:Array=[];var render:Array=[];var intervals:Array=[];var started:=Time.get_ticks_usec();var sim_start:float=solver.sim_time
	for i in 180:
		var t:=Time.get_ticks_usec();await frame();intervals.append((Time.get_ticks_usec()-t)/1000.0)
		compute.append(solver.compute_gpu_ms);render.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	var wall:float=(Time.get_ticks_usec()-started)/1000000.0;var rate:float=(solver.sim_time-sim_start)/wall
	compute.sort();render.sort();intervals.sort()
	report.performance={"frames":180,"average_fps":180.0/wall,"frame_median_ms":intervals[90],"frame_p95_ms":intervals[171],
		"compute_median_ms":compute[90],"compute_p95_ms":compute[171],"render_median_ms":render[90],"render_p95_ms":render[171],
		"simulation_rate":rate,"simulation_texture_mib":solver.simulation_bytes()/1048576.0,
		"scene_video_memory_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)}
	check("interactive_frame_p95_below_20ms",intervals[171]<20)
	check("interactive_simulation_runs_at_wall_time",rate>.94 and rate<1.06)
	solver.paused=true;for i in 4:await frame()
	var paused0:Dictionary=await snapshot();for i in 15:await frame()
	var paused1:Dictionary=await snapshot()
	check("pause_freezes_all_water_fields",paused0.state==paused1.state and paused0.foam==paused1.foam and paused0.ocean==paused1.ocean)
	solver.paused=false;await create_timer(.5).timeout
	check("resume_advances",solver.sim_time>paused1.sim_time+.3)
	RenderingServer.render_loop_enabled=false;for i in 4:await process_frame
	while solver.busy:await process_frame
	var hidden_time:float=solver.sim_time;for i in 90:await process_frame
	check("hidden_window_stops_compute",solver.sim_time==hidden_time)
	RenderingServer.render_loop_enabled=true;await create_timer(.5).timeout
	check("hidden_window_resume",solver.sim_time>hidden_time+.3)
	demo._metrics();await frame();await frame();root.get_texture().get_image().save_png(OUT+"interactive-live.png")
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("HYBRID REPORT: ",JSON.stringify(report))
	quit(0 if report.checks.values().all(func(v):return v) else 1)

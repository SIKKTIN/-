extends SceneTree
const OUT:="res://docs/art/seaside-hybrid-v3/"
var demo
func _initialize() -> void:
	create_timer(90).timeout.connect(func():quit(124));call_deferred("run")
func frame() -> void:
	await process_frame;await RenderingServer.frame_post_draw
func run() -> void:
	root.size=Vector2i(1200,812);root.content_scale_size=root.size;Engine.max_fps=60
	demo=load("res://scenes/prototypes/seaside_hybrid_demo.tscn").instantiate();root.add_child(demo)
	var solver=demo.solver;solver.automatic=false
	while not solver.initialized or solver.busy:await frame()
	for i in 150:
		solver.advance(24);await solver.advanced;await frame()
	solver.automatic=true;demo.spray.restart();await create_timer(1.5).timeout
	# Probe actual visible GPU particles on a blank background, without any water pixels.
	demo.water.visible=false;demo.pier.visible=false;await frame();await frame()
	var mask:=root.get_texture().get_image();mask.save_png(OUT+"spray-only.png")
	var drops:=0
	for y in range(112,812):
		for x in 1200:
			var c:=mask.get_pixel(x,y)
			if c.r>.4 and c.g>.4:drops+=1
	print("Visible particles: ",drops,"; bounds: ",demo.spray.capture_rect())
	if drops==0:
		(demo.spray.process_material as ShaderMaterial).set_shader_parameter("qa_emit_all",true)
		demo.spray.restart();await create_timer(.5).timeout;await frame()
		root.get_texture().get_image().save_png(OUT+"spray-debug-all.png")
		(demo.spray.process_material as ShaderMaterial).set_shader_parameter("qa_emit_all",false)
		demo.spray.restart();await create_timer(1.5).timeout
	demo.water.visible=true;demo.pier.visible=true;await frame();await frame()
	demo._metrics();await frame();root.get_texture().get_image().save_png(OUT+"interactive-live.png")
	# Render diagnostics are useful in the interactive window but hidden in the recording.
	demo.metric.visible=false
	DirAccess.make_dir_recursive_absolute(OUT+"frames/")
	var stamps:Array=[];var sim_stamps:Array=[];var images:Array[Image]=[];var started:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<6500:
		for i in 4:await frame()
		stamps.append(Time.get_ticks_msec()-started);sim_stamps.append(solver.sim_time)
		images.append(root.get_texture().get_image())
	# Encode after capture so PNG compression cannot stall the simulated water.
	for i in images.size():images[i].save_png(OUT+"frames/%03d.png" % i)
	var data:Dictionary={"timestamps_ms":stamps,"simulation_timestamps":sim_stamps,"native_recording":true,
		"recording_origin":"Godot framebuffer captured in automatic real-time mode, durations derived from wall timestamps",
		"visible_spray_pixels":drops,"bounded_particle_count":demo.spray.amount,"shader_emission_verified":drops>0}
	FileAccess.open(OUT+"recording.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("HYBRID RECORDING: ",stamps.size()," frames; visible spray pixels: ",drops)
	quit(0 if drops>0 else 1)

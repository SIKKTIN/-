extends SceneTree
const OUT="res://docs/art/seaside-water-demo-v1/"
var demo
func _initialize():
	create_timer(120).timeout.connect(func():quit(124));call_deferred("run")
func frame():
	await process_frame
	await RenderingServer.frame_post_draw
func sample_time(shader_on: bool) -> Dictionary:
	demo.water.material=demo.water_material if shader_on else null
	for i in 45:await frame()
	var gpu: Array=[];var cpu: Array=[]
	for i in 90:
		await frame();gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()));cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
	gpu.sort();cpu.sort()
	return {"gpu_median_ms":gpu[45],"gpu_p95_ms":gpu[85],"cpu_median_ms":cpu[45],"frames":90}
func run():
	root.size=Vector2i(960,844);root.content_scale_size=root.size;Engine.max_fps=60
	root.title="2D海水样例 · 原生渲染验证"
	demo=load("res://scenes/prototypes/seaside_water_demo.tscn").instantiate();root.add_child(demo);await frame()
	await create_timer(1).timeout
	var disabled=await sample_time(false);var enabled=await sample_time(true)
	demo.water.material=demo.water_material
	demo.water_material.set_shader_parameter("manual_time",0.0);await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"frame-start.png")
	demo.water_material.set_shader_parameter("manual_time",4.0);await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"frame-later.png")
	var frames=OUT+"frames/";DirAccess.make_dir_recursive_absolute(frames)
	for i in 60:
		demo.water_material.set_shader_parameter("manual_time",i*0.1);await frame();await frame()
		root.get_texture().get_image().save_png(frames+"%03d.png" % i)
	var checks={"material_loaded":demo.water_material.shader!=null,"source_static_render_commands":demo.water.get_child_count()==0,"rendered_animation_changes":FileAccess.get_sha256(OUT+"frame-start.png")!=FileAccess.get_sha256(OUT+"frame-later.png"),"render_timing_available":enabled.gpu_median_ms>0}
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"resolution":[960,844],"static":disabled,"animated":enabled,"implementation":"Godot CanvasItem shader over concept art; hue mask is provisional; map unchanged"},"\t"))
	print("Seaside 2D water timing: ",JSON.stringify({"static":disabled,"animated":enabled,"checks":checks}))
	quit(0 if checks.values().all(func(v):return v) else 1)

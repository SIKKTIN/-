extends SceneTree
func _initialize() -> void:
	create_timer(15).timeout.connect(func():quit(124));call_deferred("run")
func run() -> void:
	root.size=Vector2i(1200,812);root.content_scale_size=root.size;Engine.max_fps=60
	var demo=load("res://scenes/prototypes/seaside_hybrid_demo.tscn").instantiate();root.add_child(demo)
	await create_timer(4).timeout
	demo.solver.request_snapshot();var data:Dictionary=await demo.solver.snapshot_ready
	print("hybrid init: ",demo.solver.initialized," t: ",data.sim_time," ocean entries: ",data.ocean.size())
	root.get_texture().get_image().save_png("res://docs/art/seaside-hybrid-v3/smoke.png")
	quit(0)

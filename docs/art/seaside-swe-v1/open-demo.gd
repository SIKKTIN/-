extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1200,812)
	root.content_scale_size=root.size
	root.title="监狱风云 · 2D计算海水验证"
	Engine.max_fps=60
	var demo=load("res://scenes/prototypes/seaside_swe_demo.tscn").instantiate()
	root.add_child(demo)
	current_scene=demo

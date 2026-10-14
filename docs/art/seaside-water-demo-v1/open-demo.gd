extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(960,844);root.content_scale_size=root.size
	root.title="监狱风云 · 2D海水动态样例"
	var demo=load("res://scenes/prototypes/seaside_water_demo.tscn").instantiate();root.add_child(demo);current_scene=demo

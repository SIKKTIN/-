extends SceneTree
func _initialize() -> void: call_deferred("open")
func open() -> void:
	root.size = Vector2i(1280,820)
	root.min_size = Vector2i(1050,680)
	root.content_scale_size = root.size
	var viewer = load("res://scenes/editor/item_previewer.tscn").instantiate()
	root.add_child(viewer)
	viewer.select_item("canvas_pouch")

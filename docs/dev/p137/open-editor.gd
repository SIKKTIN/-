extends SceneTree
func _initialize() -> void: call_deferred("open")
func open() -> void:
	root.size = Vector2i(1200,760)
	root.content_scale_size = root.size
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	root.title += " · 橡皮擦修复版"
	editor.canvas.zoom = 0.75
	editor.canvas.origin = editor.canvas.size/2-Vector2(550,4090)*0.75
	editor.set_tool("eraser")

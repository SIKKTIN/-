extends SceneTree
func _initialize() -> void: call_deferred("open")
func open() -> void:
	root.size = Vector2i(1440,950)
	root.content_scale_size = root.size
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	root.title = "监狱风云 · 地图编辑器 · 橡皮擦修复版"
	editor.canvas.zoom = 0.42
	editor.canvas.origin = editor.canvas.size/2-Vector2(3050,3100)*editor.canvas.zoom
	editor.set_tool("eraser")
	editor.inspector_tabs.current_tab = 1
	editor.canvas.queue_redraw()

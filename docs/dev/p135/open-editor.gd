extends SceneTree
func _initialize() -> void:call_deferred("open")
func open() -> void:
	root.size=Vector2i(1200,760)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	editor.canvas.zoom=0.52
	editor.canvas.origin=editor.canvas.size/2-Vector2(475,3740)*0.52
	editor.canvas.queue_redraw()
	editor.show_status("外围草地已恢复；视野绘制和对象拖动已优化。当前加载刚保存的 R04 地图。")

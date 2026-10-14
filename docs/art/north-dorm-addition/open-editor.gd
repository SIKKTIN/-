extends SceneTree
func _initialize(): call_deferred("open")
func open():
	root.size=Vector2i(1280,800)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	root.title="监狱风云 · 地图编辑器 · 新增北侧宿舍"
	editor.canvas.zoom=0.7
	editor.canvas.origin=editor.canvas.size/2-Vector2(480,440)*0.7
	editor.canvas.queue_redraw()
	editor.show_status("北侧宿舍已保存到 R04：右侧入口、双层床、储物柜、洗漱台、马桶和矮凳。")
extends SceneTree
func _initialize(): call_deferred("open_editor")
func open_editor():
	root.size=Vector2i(1280,800); root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor); current_scene=editor
	await process_frame; await process_frame
	var door=editor.canvas.architecture_preview.doorways.by_id("workshop-entry")
	editor.canvas.zoom=1.08
	editor.canvas.origin=editor.canvas.size/2-(door.visual_rect.get_center()+Vector2(0,-80))*editor.canvas.zoom
	editor.canvas.queue_redraw()
	root.title="监狱风云 · 地图编辑器 · 车间门遮挡修正"
	editor.show_status("已修正车间门框、门扇与墙体的排序。此窗口读取已保存地图，原编辑器的未保存调整仍保留。")

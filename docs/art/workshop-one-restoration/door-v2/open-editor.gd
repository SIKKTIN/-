extends SceneTree
func _initialize(): call_deferred("open_editor")
func open_editor():
	root.size=Vector2i(1280,800); root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor); current_scene=editor
	await process_frame; await process_frame
	var door=editor.canvas.architecture_preview.doorways.by_id("workshop-entry")
	editor.canvas.zoom=1.5
	editor.canvas.origin=editor.canvas.size/2-(door.visual_rect.get_center()+Vector2(0,-55))*editor.canvas.zoom
	editor.canvas.queue_redraw()
	root.title="监狱风云 · 地图编辑器 · 统一车间钢门两态"
	editor.show_status("统一车间钢门已接入：仅关闭/全开两态，旧门残留已清理。此窗口载入已保存地图，原窗口草稿仍保留。")

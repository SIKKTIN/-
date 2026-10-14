extends SceneTree
func _initialize() -> void:call_deferred("open")
func open() -> void:
	root.size=Vector2i(1200,760)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	editor.category_picker.select(0)
	editor.rebuild_subcategories()
	editor.subcategory_picker.select(editor.subcategory_ids.find("tiles_junction"))
	editor.rebuild_palette()
	editor.canvas.zoom=1.2
	editor.canvas.origin=editor.canvas.size/2-Vector2(690,3320)*1.2
	editor.canvas.queue_redraw()
	editor.show_status("已补齐三向弧接（上 / 下 / 左），当前接头已替换；在左侧 T形连接分类可重复放置。")

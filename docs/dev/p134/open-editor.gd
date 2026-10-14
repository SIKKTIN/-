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
	editor.canvas.zoom=3.0
	editor.canvas.origin=editor.canvas.size/2-Vector2(675,3280)*3.0
	editor.canvas.queue_redraw()
	editor.show_status("三向接头细节已修正：压顶轮廓、弧线和墙面接口对齐。当前为 300% 放大检查。")

extends SceneTree
func _initialize():call_deferred("open")
func open():
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	root.title="监狱风云 · 食堂概念还原 · 关卡编辑器"
	editor.canvas.zoom=minf(.65,(editor.canvas.size.x-60)/1440.0)
	editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2730)*editor.canvas.zoom
	editor.canvas.queue_redraw()
	editor.category_picker.select(1);editor.category_picker.item_selected.emit(1)
	editor.status.text="食堂已按概念还原：五组纵桌、连续配餐区、新墙面与屋顶。原门禁、后勤通路保留。"

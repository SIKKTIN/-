extends SceneTree
func _initialize():call_deferred("open")
func open():
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	root.title="监狱风云 · 食堂概念还原完成 · 地图编辑器"
	editor.canvas.zoom=minf(.70,(editor.canvas.size.x-40)/1300.0)
	editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2180)*editor.canvas.zoom
	editor.canvas.queue_redraw()
	editor.category_picker.select(1);editor.category_picker.item_selected.emit(1)
	editor.status.text="食堂已还原：灰蓝瓷砖墙、五列长桌、分件后厨与取餐台、饮水及回收区。地面、屋顶和日常点已同步。"

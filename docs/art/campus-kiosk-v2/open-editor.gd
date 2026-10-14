extends SceneTree
func _initialize():call_deferred("open")
func open():
	root.size=Vector2i(1280,840);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	root.title="监狱风云 · 地图编辑器 · 小卖铺西侧入口"
	editor.canvas.zoom=.70
	editor.canvas.origin=editor.canvas.size/2-Vector2(2610,2190)*.70
	editor.canvas.queue_redraw()
	editor.show_status("小卖铺已还原：西侧门可通行，进入后隐藏屋顶与雨棚；只保留原正面售货台与一名店员。")

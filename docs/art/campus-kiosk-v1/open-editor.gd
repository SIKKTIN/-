extends SceneTree
func _initialize():call_deferred("open")
func open():
	root.size=Vector2i(1280,840);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	root.title="监狱风云 · 地图编辑器 · 小卖铺概念还原"
	editor.canvas.zoom=.70
	editor.canvas.origin=editor.canvas.size/2-Vector2(2640,2200)*.70
	editor.canvas.queue_redraw()
	editor.show_status("小卖铺已还原：独立铁皮屋顶、木柜台与货架；南侧窗口购买，营业08:00–20:00。")

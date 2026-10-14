extends SceneTree
func _initialize():call_deferred("open")
func open():
	root.size=Vector2i(1280,840);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	root.title="监狱风云 · 地图编辑器 · 小卖铺正面入口"
	editor.canvas.zoom=.70
	editor.canvas.origin=editor.canvas.size/2-Vector2(2610,2190)*.70
	editor.canvas.queue_redraw()
	editor.show_status("正面入口版已接入：左侧正门、右侧唯一售货窗口，完整屋顶；进入隐藏屋顶和雨棚，离开门口恢复。")

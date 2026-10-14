extends SceneTree
func _initialize():call_deferred("open")
func open():
	root.size=Vector2i(1280,840);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	root.title="监狱风云 · 地图编辑器 · 小卖铺西向入口修正"
	editor.canvas.zoom=.70
	editor.canvas.origin=editor.canvas.size/2-Vector2(2610,2190)*.70
	editor.canvas.queue_redraw()
	editor.show_status("西向入口已重做：屋檐内凹、上下墙垛连接侧墙、阴影和室内地面连续；进出屋顶显隐正常。")

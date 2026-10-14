extends SceneTree
func _initialize():call_deferred("open")
func open():
	root.size=Vector2i(1280,840);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	root.title="监狱风云 · 地图编辑器 · 小卖铺D敞开式入口"
	editor.canvas.zoom=.70
	editor.canvas.origin=editor.canvas.size/2-Vector2(2610,2190)*.70
	editor.canvas.queue_redraw()
	editor.show_status("已接入D敞开式门洞：无门扇，保留雨棚、入口牌和壁灯；侧面通行，进出屋顶自动显隐。")

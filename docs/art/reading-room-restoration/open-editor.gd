extends SceneTree
func _initialize():call_deferred("open")
func open():
	root.size=Vector2i(1280,800)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	root.title="监狱风云 · 地图编辑器 · 阅览室概念还原"
	editor.canvas.zoom=.75
	editor.canvas.origin=editor.canvas.size/2-Vector2(485,400)*.75
	editor.canvas.queue_redraw()
	editor.show_status("阅览室已保存到 R04：双书架、四人桌椅、报刊架、还书柜、告示栏、圆盆绿植和暖光壁灯。")
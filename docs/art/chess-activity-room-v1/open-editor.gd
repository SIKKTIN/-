extends SceneTree
func _initialize():call_deferred("open")
func open():
	root.size=Vector2i(1440,950);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	root.title="监狱风云 · 棋牌活动室还原完成 · 地图编辑器"
	editor.canvas.zoom=.82;editor.canvas.origin=editor.canvas.size/2-Vector2(1190,490)*editor.canvas.zoom
	editor.canvas.queue_redraw()
	editor.resource_search.text="棋牌"
	editor.rebuild_palette()
	editor.status.text="棋牌室已还原：上下两张方桌、八只方凳、长椅、收纳柜、茶水角和灰蓝墙裙；柜子可翻找，日常活动点已接入。"

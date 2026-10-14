extends SceneTree
func _initialize():call_deferred("open")
func open():
	root.size=Vector2i(1280,840);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	root.title="监狱风云 · 地图编辑器 · 地面缺口与接缝修复"
	editor.canvas.zoom=.115
	editor.canvas.origin=editor.canvas.size/2-Vector2(3000,2220)*.115
	editor.canvas.queue_redraw()
	editor.show_status("已修复室内露草、地面错位、门口缺口和道路砖缝；整栋移动/复制时地面同步跟随。")
extends SceneTree
func _initialize():call_deferred("open")
func open():
	root.size=Vector2i(1280,900)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	root.title="监狱风云 · 地图编辑器 · 工具房概念还原"
	var room: Dictionary=editor.document.data.visibility_rooms.filter(func(r):return r.id=="tools")[0]
	var center:=Vector2(room.rect[0]+room.rect[2]/2,room.rect[1]+220)
	editor.canvas.zoom=.9
	editor.canvas.origin=editor.canvas.size/2-center*.9
	editor.canvas.queue_redraw()
	editor.resource_search.text="工具房"
	editor.rebuild_palette()
	editor.show_status("工具房已保存：独立家具、蓝灰墙体、双入口门和专属屋顶；五处柜架可翻找。")
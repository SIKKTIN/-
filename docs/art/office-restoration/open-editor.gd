extends SceneTree

# A separate window loads the delivered saved map without touching any
# existing editor window's in-memory draft.
func _initialize() -> void: call_deferred("open_editor")
func open_editor() -> void:
	root.size=Vector2i(1280,800)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	current_scene=editor
	await process_frame
	await process_frame
	var room: Dictionary=editor.document.data.visibility_rooms.filter(func(v):return v.id=="office")[0]
	var r: Array=room.rect
	var area:=Rect2(r[0],r[1],r[2],r[3])
	editor.canvas.zoom=0.90
	editor.canvas.origin=editor.canvas.size/2-(area.get_center()+Vector2(0,-25))*editor.canvas.zoom
	editor.canvas.queue_redraw()
	editor.resource_search.text="办公室"
	editor.rebuild_palette()
	root.title="监狱风云 · 地图编辑器 · 办公室改造预览"
	editor.show_status("已载入办公室改造：新家具可编辑，文件柜可搜刮。此窗口读取磁盘最新地图，原窗口草稿仍保留。")

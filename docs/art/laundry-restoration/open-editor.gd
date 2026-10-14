extends SceneTree

# Separate preview window: load the delivered disk map while retaining any
# older editor window's unsaved in-memory work.
func _initialize() -> void: call_deferred("open_editor")
func open_editor() -> void:
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://laundry-editor-preview.cfg")
	root.size=Vector2i(1280,800)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	current_scene=editor
	await process_frame
	editor.open_now("res://data/rooms/r04.json")
	await process_frame
	await process_frame
	var room: Dictionary=editor.document.data.visibility_rooms.filter(func(v):return v.id=="laundry")[0]
	var r: Array=room.rect
	var area:=Rect2(r[0],r[1],r[2],r[3])
	editor.canvas.zoom=0.72
	editor.canvas.origin=editor.canvas.size/2-(area.get_center()+Vector2(0,-30))*editor.canvas.zoom
	editor.canvas.queue_redraw()
	editor.resource_search.text="洗衣房"
	editor.rebuild_palette()
	root.title="监狱风云 · 地图编辑器 · 洗衣房新版预览"
	editor.show_status("已载入新版洗衣房：四台洗衣机、布草收纳、新墙面与双扇钢门。食堂连接保留；此窗口读取磁盘地图，原窗口草稿仍保留。")

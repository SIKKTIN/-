extends SceneTree
func _initialize() -> void: call_deferred("open_editor")
func open_editor() -> void:
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://workshop-two-editor-preview.cfg")
	root.size=Vector2i(1280,800)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	current_scene=editor
	await process_frame
	editor.open_now("res://data/rooms/r04.json")
	await process_frame
	await process_frame
	var room: Dictionary=editor.document.data.visibility_rooms.filter(func(v):return v.id=="workshop-two")[0]
	var r: Array=room.rect
	var area:=Rect2(r[0],r[1],r[2],r[3])
	editor.canvas.zoom=0.45
	editor.canvas.origin=editor.canvas.size/2-(area.get_center()+Vector2(0,-10))*editor.canvas.zoom
	editor.canvas.queue_redraw()
	editor.resource_search.text="二号车间"
	editor.rebuild_palette()
	root.title="监狱风云 · 地图编辑器 · 二号车间改造预览"
	editor.show_status("二号车间已更新：四台机床、沿墙收纳、新墙面与金属屋顶。三个门均沿用一号车间同款。")

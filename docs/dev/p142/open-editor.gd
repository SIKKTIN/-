extends SceneTree

# Open the saved map with the medical bed selected; never replace the existing
# editor's in-memory draft or save this preview to the map file.
func _initialize() -> void: call_deferred("open_editor")
func open_editor() -> void:
	root.size = Vector2i(1280,800)
	root.content_scale_size = root.size
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	current_scene = editor
	await process_frame
	await process_frame
	var rooms: Array = editor.document.data.get("visibility_rooms",[])
	var clinic: Array = rooms.filter(func(room):return room.get("id","")=="clinic")
	if not clinic.is_empty():
		var r: Array = clinic[0].rect
		var area := Rect2(r[0],r[1],r[2],r[3])
		editor.canvas.zoom = 0.82
		editor.canvas.origin = editor.canvas.size/2-area.get_center()*editor.canvas.zoom
	for index in range(editor.document.data.fixtures.size()):
		if editor.document.data.fixtures[index].get("id","")=="campus-clinic-bed-0":
			editor.canvas.choose({"group":"fixtures","index":index})
			break
	editor.canvas.queue_redraw()
	editor.show_status("已载入磁盘地图并选中医疗床；左右镜像 X 可切换床头。原窗口有草稿时，先在原窗口保存，再从此窗口“文件”重读。")

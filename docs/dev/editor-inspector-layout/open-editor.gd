extends SceneTree
func _initialize() -> void: call_deferred("open")
func open() -> void:
	root.size = Vector2i(1440,950)
	root.content_scale_size = root.size
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	root.title = "监狱风云 · 地图编辑器 · 属性面板修复"
	editor.set_tool("floor_edit")
	var target := Vector2(2200,3100)
	var floors: Array = editor.document.collection("floor_regions")
	for index in range(floors.size()-1,-1,-1):
		if str(floors[index].get("id","")).begins_with("floor_"):
			var ref := {"group":"floor_regions","index":index}
			editor.canvas.choose(ref)
			target = editor.document.geometry(ref).get_center()
			break
	editor.canvas.zoom = 1.25
	editor.canvas.origin = editor.canvas.size/2-target*editor.canvas.zoom
	editor.canvas.queue_redraw()

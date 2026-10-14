extends SceneTree
func _initialize(): call_deferred("open_editor")
func open_editor():
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://energy-court-v1-editor.cfg")
	root.size=Vector2i(1440,960)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	current_scene=editor
	await process_frame
	await process_frame
	editor.open_now("res://data/rooms/r04.json")
	await process_frame
	await process_frame
	editor.canvas.zoom=.36
	editor.canvas.origin=editor.canvas.size/2-Vector2(3600,3030)*editor.canvas.zoom
	editor.resource_search.text="能源庭院"
	editor.rebuild_palette()
	editor.canvas.queue_redraw()
	root.title="监狱风云 · 地图编辑器 · 方案七管线能源庭院"
	editor.show_status("方案七已保存：L形设备间、五跨红蓝管架、八角阀门平台、弧形碎石收边与备件棚。点击试玩可体验屋顶和门。")
	print("ENERGY_COURT_EDITOR_READY saved=",not editor.document.dirty())

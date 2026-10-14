extends SceneTree
func _initialize() -> void: call_deferred("open_editor")
func open_editor() -> void:
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://drying-yard-edges-v1-editor.cfg")
	root.size=Vector2i(1440,900)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	current_scene=editor
	await process_frame
	await process_frame
	editor.open_now("res://data/rooms/r04.json")
	await process_frame
	await process_frame
	editor.canvas.zoom=.6
	editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2820)*editor.canvas.zoom
	editor.canvas.queue_redraw()
	editor.resource_search.text="晾晒区"
	editor.rebuild_palette()
	root.title="监狱风云 · 地图编辑器 · 晾晒区草坪围边优化"
	editor.show_status("已补上碎石、泥土和草芽围边，右侧折角已收口；围边属于地面装饰，不阻挡通行。")
	print("DRYING_YARD_EDGES_EDITOR_READY ",editor.document.path," saved=",not editor.document.dirty())

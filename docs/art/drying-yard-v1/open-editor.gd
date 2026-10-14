extends SceneTree
func _initialize() -> void:call_deferred("open_editor")
func open_editor() -> void:
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://drying-yard-v1-editor.cfg")
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
	editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2810)*editor.canvas.zoom
	editor.canvas.queue_redraw()
	editor.resource_search.text="晾晒区"
	editor.rebuild_palette()
	root.title="监狱风云 · 地图编辑器 · 食堂南侧晾晒区"
	editor.show_status("晾晒区已接入：左侧两排、右侧一排晾衣架，布草车、花坛、长椅和路灯；中央道路连接下方横路。素材栏搜索“晾晒区”可继续布置。")
	print("DRYING_YARD_EDITOR_READY ",editor.document.path," saved=",not editor.document.dirty())

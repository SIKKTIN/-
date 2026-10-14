extends SceneTree
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://tree-courtyard-editor.cfg")
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
	editor.canvas.zoom=.5
	editor.canvas.origin=editor.canvas.size/2-Vector2(3570,2390)*editor.canvas.zoom
	editor.resource_search.text="自强树庭"
	editor.rebuild_palette()
	editor.canvas.queue_redraw()
	root.title="监狱风云 · 地图编辑器 · 自强树庭概念还原"
	editor.show_status("自强树庭已保存：四向环路、L形花坛、南侧休息湾和五组独立生成的草丛。素材搜索：自强树庭。")
	print("TREE_COURT_EDITOR_READY saved=",not editor.document.dirty())

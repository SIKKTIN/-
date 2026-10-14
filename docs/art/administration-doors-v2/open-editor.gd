extends SceneTree
func _initialize() -> void:call_deferred("open_editor")
func open_editor() -> void:
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://administration-doors-v2-editor.cfg")
	root.size=Vector2i(1440,900)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	current_scene=editor
	await process_frame
	editor.open_now("res://data/rooms/r04.json")
	await process_frame
	await process_frame
	editor.canvas.zoom=.85
	editor.canvas.origin=editor.canvas.size/2-Vector2(4230,430)*editor.canvas.zoom
	editor.canvas.queue_redraw()
	editor.resource_search.text="钢门"
	editor.rebuild_palette()
	root.title="监狱风云 · 地图编辑器 · 值班室与办公室门优化"
	editor.show_status("两处门已采用车间同款门框和开关门扇。值班室默认打开，办公室保持锁门；素材栏可选两处门的开、关版本。")
	print("ADMINISTRATION_EDITOR_READY ",editor.document.path," saved=",not editor.document.dirty())

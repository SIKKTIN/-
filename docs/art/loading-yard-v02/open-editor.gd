extends SceneTree
func _initialize() -> void: call_deferred("open_editor")
func open_editor() -> void:
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://loading-yard-editor-preview.cfg")
	root.size=Vector2i(1280,800)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	current_scene=editor
	await process_frame
	editor.open_now("res://data/rooms/r04.json")
	await process_frame
	await process_frame
	editor.canvas.zoom=.24
	editor.canvas.origin=editor.canvas.size/2-Vector2(5470,1740)*editor.canvas.zoom
	editor.resource_search.text="装卸场"
	editor.rebuild_palette()
	editor.canvas.queue_redraw()
	root.title="监狱风云 · 地图编辑器 · 装卸场概念还原预览"
	editor.show_status("装卸场已保存：露天混凝土、东侧篷布货车、分组货垛、物流门岗及状态联动铁门。此窗口读取最新保存地图；全图可查看南北出口。")

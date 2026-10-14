extends SceneTree
func _initialize() -> void: call_deferred("open_editor")
func open_editor() -> void:
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://warehouse-editor-preview.cfg")
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
	editor.canvas.origin=editor.canvas.size/2-Vector2(4700,2110)*editor.canvas.zoom
	editor.resource_search.text="仓库"
	editor.rebuild_palette()
	editor.canvas.queue_redraw()
	root.title="监狱风云 · 地图编辑器 · 仓库概念还原预览"
	editor.show_status("已载入新版仓库：中央四组长货架、沿墙收纳、分拣登记、搬运停放区与同系钢门。此窗口读取最新保存地图。")

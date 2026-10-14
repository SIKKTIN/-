extends SceneTree
func _initialize():call_deferred("open_editor")
func open_editor():
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://cafeteria-door-editor.cfg")
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);current_scene=editor
	await process_frame;editor.open_now("res://data/rooms/r04.json");await process_frame;await process_frame
	editor.canvas.zoom=.7;editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2150)*.7;editor.canvas.queue_redraw()
	root.title="监狱风云 · 地图编辑器 · 食堂门统一接入"
	editor.show_status("已载入最新 R04：三扇上下门复用机房门组件，西侧门复用仓库侧门与朝向。门框对齐墙沿；入口位置、开放时间和西侧通行方式保持原样。")

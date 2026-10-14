extends SceneTree
func _initialize():call_deferred("open_editor")
func open_editor():
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://cafeteria-north-wall-editor.cfg")
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);current_scene=editor
	await process_frame;editor.open_now("res://data/rooms/r04.json");await process_frame;await process_frame
	editor.canvas.zoom=.7;editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2150)*.7;editor.canvas.queue_redraw()
	root.title="监狱风云 · 地图编辑器 · 食堂上墙比例优化"
	editor.show_status("已载入最新 R04：食堂上下墙沿统一蓝灰金属包边，墙高 120，窗户上移。门口碰撞、后厨和餐桌保持原位。")

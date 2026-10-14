extends SceneTree
func _initialize():call_deferred("open_editor")
func open_editor():
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://reading-chess-roof-editor.cfg")
	root.size=Vector2i(1280,850);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);current_scene=editor
	await process_frame;editor.open_now("res://data/rooms/r04.json");await process_frame;await process_frame
	editor.canvas.zoom=.68;editor.canvas.origin=editor.canvas.size/2-Vector2(785,460)*.68
	editor.subcategory_picker.select(0);editor.resource_search.text="阅览室";editor.rebuild_palette();editor.canvas.queue_redraw()
	root.title="监狱风云 · 地图编辑器 · 阅览室与棋牌室屋顶新版"
	editor.show_status("已接入阅览室旧砖红瓦顶、入口门牌和棋牌室旧灰瓦顶。选择房间可在属性中切换屋顶样式；试玩后在室外查看屋顶。此窗口读取最新保存地图。")

extends SceneTree
func _initialize():call_deferred("open_editor")
func open_editor():
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://bath-pocket-door-editor.cfg")
	root.size=Vector2i(1280,850);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);current_scene=editor
	await process_frame;editor.open_now("res://data/rooms/r04.json");await process_frame;await process_frame
	var f: Dictionary=editor.document.data.fixtures.filter(func(f):return f.id=="campus-bath")[0]
	var p=Vector2(f.rect[0]+f.rect[2]/2,f.rect[1]+100)
	editor.canvas.zoom=1;editor.canvas.origin=editor.canvas.size/2-p
	editor.resource_search.text="浴室北入口";editor.rebuild_palette();editor.canvas.queue_redraw()
	root.title="监狱风云 · 地图编辑器 · 浴室推拉门新版"
	editor.show_status("浴室北入口已替换为磨砂推拉门：门扇收进两侧，门框对齐门槛，保留当前家具摆放。左侧素材可查看打开、关闭两种状态。此窗口读取最新保存地图。")

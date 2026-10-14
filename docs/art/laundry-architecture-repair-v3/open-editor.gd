extends SceneTree
func _initialize():call_deferred("open_editor")
func open_editor():
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://laundry-repair-editor.cfg")
	root.size=Vector2i(1280,850);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);current_scene=editor
	await process_frame;editor.open_now("res://data/rooms/r04.json");await process_frame;await process_frame
	var f: Dictionary=editor.document.data.fixtures.filter(func(f):return f.id=="cafeteria-rear-visual45")[0]
	var center=Vector2(f.rect[0]+f.rect[2]/2+20,f.rect[1]+260)
	editor.canvas.zoom=0.65;editor.canvas.origin=editor.canvas.size/2-center*0.65
	editor.subcategory_picker.select(0)
	editor.resource_search.text="洗衣室";editor.rebuild_palette();editor.canvas.queue_redraw()
	root.title="监狱风云 · 地图编辑器 · 洗衣室门墙修复"
	editor.show_status("已修复洗衣室北入口双扇推拉门、压顶、墙角与短竖墙接缝。门的时段、侧门锁定及家具位置保留。此窗口读取最新保存地图。")

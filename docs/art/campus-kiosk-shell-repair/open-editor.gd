extends SceneTree
func _initialize():call_deferred("open_editor")
func open_editor():
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://kiosk-shell-repair-preview.cfg")
	root.size=Vector2i(1280,840);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor);current_scene=editor
	await process_frame;await process_frame
	editor.open_now("res://data/rooms/r04.json")
	await process_frame;await process_frame
	var shell: Dictionary=editor.document.data.fixtures.filter(func(f):return f.id=="kiosk-shell")[0]
	var rect: Array=shell.rect
	var center:=Vector2(rect[0]+rect[2]/2,rect[1]+250)
	editor.canvas.zoom=.70;editor.canvas.origin=editor.canvas.size/2-center*.70
	editor.resource_search.text="小卖铺";editor.rebuild_palette();editor.canvas.queue_redraw()
	root.title="监狱风云 · 地图编辑器 · 商店墙体显示修复"
	editor.show_status("连续墙壳修复已接入最新 R04：两侧包边完整，旧侧门色块已清除；保留正面入口、售货窗口及屋顶显隐。")

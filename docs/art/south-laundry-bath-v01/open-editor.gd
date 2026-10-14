extends SceneTree
func _initialize() -> void:call_deferred("open_editor")
func open_editor() -> void:
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://south-laundry-bath-editor.cfg")
	root.size=Vector2i(1500,960);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor);current_scene=editor
	await process_frame
	editor.open_now("res://data/rooms/r04.json")
	await process_frame;await process_frame
	editor.canvas.zoom=.55
	editor.canvas.origin=editor.canvas.size/2-Vector2(1590,3690)*editor.canvas.zoom
	editor.resource_search.text="洗衣"
	editor.rebuild_palette();editor.canvas.queue_redraw()
	root.title="监狱风云 · 地图编辑器 · 南侧洗衣房与公共浴室"
	editor.show_status("南侧组合已保存：北侧双入口、双排滚筒机、纵向三位水槽、北侧更衣收费区、靠西墙短隔屏及六个淋浴位。屋顶与水卡服务已验证。")

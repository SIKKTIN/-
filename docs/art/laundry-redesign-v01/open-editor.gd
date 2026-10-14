extends SceneTree
func _initialize() -> void:call_deferred("open")
func open() -> void:
	root.size=Vector2i(1440,900)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	editor.open_now("res://data/rooms/r04.json")
	root.title="监狱风云 · 洗衣房概念还原完成 · 地图编辑器"
	editor.canvas.zoom=minf(.82,(editor.canvas.size.x-40)/1000.0)
	editor.canvas.origin=editor.canvas.size/2-Vector2(1350,3620)*editor.canvas.zoom
	editor.canvas.queue_redraw()
	editor.resource_search.text="洗衣房"
	editor.resource_search.text_changed.emit("洗衣房")
	editor.status.text="洗衣房已保存：四台洗衣机、金属叠衣台、双蓝桶分拣组合，北侧入口与南侧出口已重排。"
	print("LAUNDRY_EDITOR_READY ",editor.document.path," saved=",not editor.document.dirty())

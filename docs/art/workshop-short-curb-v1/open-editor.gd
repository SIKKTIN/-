extends SceneTree
func _initialize() -> void:call_deferred("open")
func open() -> void:
	root.size=Vector2i(1440,950);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	editor.open_now("res://data/rooms/r04.json")
	await process_frame;await process_frame
	root.title="监狱风云 · 地图编辑器 · 短石条"
	editor.canvas.zoom=.64
	editor.canvas.origin=editor.canvas.size/2-Vector2(2860,1740)*editor.canvas.zoom
	editor.resource_search.text="车间连接道路"
	editor.rebuild_palette();editor.canvas.queue_redraw()
	root.show();root.grab_focus()

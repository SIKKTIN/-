extends SceneTree
func _initialize() -> void:call_deferred("open")
func open() -> void:
	root.size=Vector2i(1440,950);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	editor.open_now("res://data/rooms/r04.json")
	await process_frame
	await process_frame
	root.title="监狱风云 · 地图编辑器 · 主阀门检修区还原"
	editor.canvas.zoom=.55
	editor.canvas.origin=editor.canvas.size/2-Vector2(3920,3310)*editor.canvas.zoom
	editor.resource_search.text="主阀门检修区"
	editor.rebuild_palette();editor.canvas.queue_redraw()
	root.show();root.grab_focus()

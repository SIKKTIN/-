extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size
	root.title="这次怎么逃 · R04 黑工厂扩建 · 地图编辑器"
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	editor.open_now("res://data/rooms/r04.json")
	for layer in ["actors","patrol","items","routine","areas"]:editor.layers.set_visible(layer,false)
	editor.canvas.zoom=0.23;editor.canvas.origin=editor.canvas.size/2-Vector2(2080,1600)*0.23
	editor.canvas.queue_redraw()

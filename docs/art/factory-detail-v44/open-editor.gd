extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	editor.open_now("res://data/rooms/r04.json")
	for layer in ["actors","patrol","items","routine","areas","visibility"]:editor.layers.set_visible(layer,false)
	editor.category_picker.select(0);editor.rebuild_subcategories()
	editor.subcategory_picker.select(editor.subcategory_ids.find("furnishings"));editor.rebuild_palette()
	editor.canvas.zoom=0.23;editor.canvas.origin=editor.canvas.size/2-Vector2(2080,1600)*0.23
	editor.canvas.queue_redraw()
	root.title="这次怎么逃 · R04 工厂细节 V44 · 地图编辑器"
	print("V44 native editor ready: ",editor.document.data.fixtures.size()," fixtures; palette ",editor.catalog.entries.size())

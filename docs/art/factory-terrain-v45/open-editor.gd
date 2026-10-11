extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	editor.open_now("res://data/rooms/r04.json")
	for layer in ["actors","patrol","items","routine","areas","visibility"]:editor.layers.set_visible(layer,false)
	editor.canvas.zoom=0.22;editor.canvas.origin=editor.canvas.size/2-Vector2(2120,1520)*0.22
	editor.canvas.queue_redraw()
	root.title="这次怎么逃 · R04 分区地面与概念图墙线 V45 · 地图编辑器"
	print("V45 native editor ready: ",editor.document.data.floor_regions.size()," floor regions; ",editor.document.data.terrain_patches.size()," organic patches.")

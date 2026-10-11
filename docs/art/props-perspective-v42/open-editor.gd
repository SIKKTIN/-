extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await process_frame;await process_frame
	editor.open_now("res://data/rooms/r04.json")
	for layer in ["actors","patrol","items","routine","areas"]:editor.layers.set_visible(layer,false)
	editor.category_picker.select(1);editor.rebuild_subcategories()
	editor.subcategory_picker.select(editor.subcategory_ids.find("serving"));editor.rebuild_palette()
	await process_frame;await process_frame
	editor.canvas.zoom=0.68;editor.canvas.origin=editor.canvas.size/2-Vector2(1340,1680)*0.68;editor.canvas.queue_redraw()
	DisplayServer.window_set_title("这次怎么逃 · R04 统一斜俯视物件 · 地图编辑器")
	await process_frame;await RenderingServer.frame_post_draw
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/art/props-perspective-v42/r04-editor-open.png")
	print("R04_EDITOR_READY: prison-perspective-v42")

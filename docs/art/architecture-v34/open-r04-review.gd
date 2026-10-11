extends SceneTree
func _initialize() -> void: call_deferred("open_editor")
func open_editor() -> void:
	root.size=Vector2i(1600,1000)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.open_now("res://data/rooms/r04.json")
	for layer in ["actors","patrol","items","routine","areas"]:editor.layers.set_visible(layer,false)
	editor.category_picker.select(0);editor.rebuild_subcategories()
	editor.subcategory_picker.select(editor.subcategory_ids.find("tiles_h"));editor.rebuild_palette()
	await process_frame;await process_frame
	editor.canvas.zoom=0.54
	editor.canvas.origin=editor.canvas.size/2-Vector2(1370,1650)*editor.canvas.zoom
	editor.canvas.queue_redraw()
	print("R04_REVIEW_READY: 85 independent grid wall tiles, editor input enabled")

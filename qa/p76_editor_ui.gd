extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await RenderingServer.frame_post_draw
	editor.layers.set_visible("visibility",true)
	var ref: Dictionary=editor.document.entries().filter(func(r): return r.group=="visibility_rooms")[0]
	editor.canvas.choose(ref)
	await process_frame
	await RenderingServer.frame_post_draw
	var fields: Array=editor.inspector.find_children("VisibilityDoors","LineEdit",true,false)
	var checks: Dictionary={"editor_new_layer_row":editor.layer_rows.has("visibility"),"editor_loads_runtime_rooms":editor.document.collection("visibility_rooms").size()==11,"editor_layer_visible":editor.layers.is_visible("visibility_rooms"),"editor_inspector_door_field":fields.size()==1,"editor_full_view_no_runtime_masks":not editor.canvas.has_node("RoomCover")}
	root.get_texture().get_image().save_png("res://docs/tests/p76-editor-visibility-layer.png")
	var failed: Array=checks.keys().filter(func(k): return not checks[k])
	FileAccess.open("res://docs/tests/p76-editor-ui.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks,"failed":failed}))
	quit(0 if failed.is_empty() else 1)

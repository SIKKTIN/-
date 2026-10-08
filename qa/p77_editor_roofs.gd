extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.layers.set_visible("visibility",true)
	var ref: Dictionary = editor.document.entries().filter(func(r):return r.group=="visibility_rooms" and editor.document.value(r).id=="workshop")[0]
	editor.canvas.choose(ref)
	await process_frame
	var field: OptionButton = editor.inspector.find_child("RoofStyle",true,false)
	var checks := {"roof_picker_available":field!=null,"four_style_icons":range(1,5).all(func(i):return field.get_item_icon(i)!=null),"auto_and_four_styles":field.item_count==5}
	field.item_selected.emit(4)
	checks.roof_style_saved_in_document = editor.document.value(ref).roof_style=="metal_light"
	editor.document.undo()
	checks.roof_style_undo = not editor.document.value(ref).has("roof_style")
	editor.document.redo()
	checks.roof_style_redo = editor.document.value(ref).roof_style=="metal_light"
	var trial := "res://data/rooms/p77_roof_trial.json"
	checks.roof_style_save = editor.document.save_file(trial,true)
	var doc = load("res://scripts/editor/map_document.gd").new()
	checks.roof_style_reload = doc.open_file(trial) and doc.value(ref).roof_style=="metal_light"
	DirAccess.remove_absolute(trial)
	var invalid: Dictionary = doc.data.duplicate(true)
	invalid.visibility_rooms[0].roof_style="not-a-roof"
	checks.invalid_style_rejected = not doc.check_shape(invalid).is_empty()
	checks.editing_full_room_visible = not editor.canvas.has_node("RoomCover")
	await process_frame
	if DisplayServer.get_name()!="headless":
		editor.inspector.get_parent().ensure_control_visible(editor.inspector.find_child("RoofStyle",true,false))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/tests/p77-editor-roof-picker.png")
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	var tag := "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open("res://docs/tests/p77-editor-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks,"failed":failed}))
	quit(0 if failed.is_empty() else 1)

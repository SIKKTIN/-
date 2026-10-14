extends SceneTree
const OUT := "res://docs/dev/editor-inspector-layout/"
var checks := {}
var editor
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func check(label: String, passed: bool) -> void: checks[label] = passed
func mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
func move_mouse(position: Vector2, delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = delta
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1440,950)
	root.content_scale_size = root.size
	editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	for c in root.get_signal_connection_list("focus_exited"): root.disconnect("focus_exited",c.callable)
	await frame()
	await frame()
	editor.set_tool("floor_edit")
	var before: float = editor.inspector_tabs.size.x
	var floors: Array = editor.document.collection("floor_regions")
	var index := floors.size()-1
	editor.canvas.choose({"group":"floor_regions","index":index})
	await frame()
	await frame()
	var picker: OptionButton = editor.inspector.get_node("FloorMaterial")
	var readings := {"before":before,"after":editor.inspector_tabs.size.x,"canvas_width":editor.canvas.size.x,"picker_min":picker.get_combined_minimum_size().x,"inspector_min":editor.inspector.get_combined_minimum_size().x,"tabs_min":editor.inspector_tabs.get_combined_minimum_size().x,"split_min":editor.inspector_tabs.get_parent().get_combined_minimum_size().x}
	print(JSON.stringify(readings))
	check("floor selection keeps inspector width stable",absf(before-editor.inspector_tabs.size.x)<=2)
	check("map retains useful width",editor.canvas.size.x >= 650)
	check("floor picker has bounded minimum width",picker.get_combined_minimum_size().x < 250)
	for material in picker.item_count:
		picker.select(material)
		await frame()
		check("material %d does not expand inspector" % material,absf(before-editor.inspector_tabs.size.x)<=2)
		var icon := picker.get_item_icon(material)
		check("material %d uses bounded thumbnail" % material,icon == null or maxf(icon.get_width(),icon.get_height()) <= 24)
	picker.add_item("超长名称测试 · "+"材质".repeat(100))
	picker.select(picker.item_count-1)
	await frame()
	check("long material name cannot force panel wider",absf(before-editor.inspector_tabs.size.x)<=2)
	var split := editor.inspector_tabs.get_parent() as HSplitContainer
	check("split handle is explicitly visible",split.dragger_visibility == SplitContainer.DRAGGER_VISIBLE)
	var saved_offset := split.split_offset
	# Real GUI events verify the divider is draggable, not merely assignable.
	var start: Vector2 = editor.canvas.global_position+Vector2(editor.canvas.size.x+5,editor.canvas.size.y/2)
	mouse(start,true)
	await frame()
	move_mouse(start-Vector2(80,0),Vector2(-80,0))
	await frame()
	mouse(start-Vector2(80,0),false)
	await frame()
	check("actual divider mouse drag expands panel",editor.inspector_tabs.size.x >= before+60)
	var finish := start-Vector2(80,0)
	mouse(finish,true)
	await frame()
	move_mouse(finish+Vector2(80,0),Vector2(80,0))
	await frame()
	mouse(finish+Vector2(80,0),false)
	await frame()
	check("actual divider mouse drag shrinks panel",absf(before-editor.inspector_tabs.size.x)<=4)
	split.split_offset = saved_offset
	editor.canvas.choose({"group":"floor_regions","index":index})
	await frame()
	await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+"inspector-after.png")
	FileAccess.open(OUT+"probe.json",FileAccess.WRITE).store_string(JSON.stringify(readings,"\t"))
	var failed: Array = checks.keys().filter(func(label):return not checks[label])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	editor.queue_free()
	await frame()
	quit(0 if failed.is_empty() else 1)

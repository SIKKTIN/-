extends SceneTree

var editor
var checks := {}
var native := false

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	if native: await RenderingServer.frame_post_draw

func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform()*button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await frame()
	event.pressed = false
	Input.parse_input_event(event)
	await frame()

func run() -> void:
	native = DisplayServer.get_name() != "headless"
	root.content_scale_size = Vector2i(1280,800)
	root.size = root.content_scale_size
	editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	var d = editor.document
	var ref: Dictionary = d.duplicate_entry({"group":"fixtures","index":0})
	editor.canvas.choose(ref)
	await frame()
	var previous_id: String = d.value(ref).id
	var input: LineEdit = editor.inspector.get_node("Property_id")
	input.grab_focus()
	input.text = "pending_property"
	await click(editor.undo_button)
	checks.undo_pending_field_keeps_selected_object = d.collection("fixtures").size() == ref.index+1
	if checks.undo_pending_field_keeps_selected_object:
		checks.undo_restores_field_without_reapplying_focus = d.value(ref).id == previous_id and editor.inspector.get_node("Property_id").text == previous_id
	else:
		checks.undo_restores_field_without_reapplying_focus = false
	editor.open_now("res://data/rooms/r04.json")
	ref = d.duplicate_entry({"group":"fixtures","index":0})
	editor.canvas.choose(ref)
	await frame()
	input = editor.inspector.get_node("Property_id")
	input.grab_focus()
	input.text = "pending_before_delete"
	var delete_button: Button
	for node in editor.find_children("*","Button",true,false):
		if node.text == "删除": delete_button = node
	await click(delete_button)
	checks.delete_focused_object_removes_it = d.collection("fixtures").size() == ref.index
	await click(editor.undo_button)
	checks.undo_delete_restores_pending_field = d.collection("fixtures").size() == ref.index+1 and d.value(ref).id == "pending_before_delete"
	editor.open_now("res://data/rooms/r04.json")
	checks.source_unchanged_clean_end = not d.dirty()
	var passed: bool = checks.values().all(func(value): return value)
	FileAccess.open("res://docs/tests/p51-fields-"+("native" if native else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Real toolbar mouse clicks with focused, unsubmitted property text: undo, delete and undo deletion on isolated in-memory clone."},"\t")+"\n")
	print("P51_FIELDS passed=",passed," count=",checks.size()," failed=",checks.keys().filter(func(k): return not checks[k]))
	editor.queue_free()
	await frame()
	quit(0 if passed else 1)

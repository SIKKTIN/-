extends SceneTree

const OUT := "res://docs/dev/eraser-complete/"
var checks := {}
var editor
var canvas
var doc
var saved: Dictionary
var gate_id := "maintenance-entry"
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func check(label: String, passed: bool) -> void: checks[label] = passed
func reset() -> void:
	doc.data = saved.duplicate(true)
	doc.history.clear()
	doc.cursor = 0
	doc.transaction.clear()
	doc.changed.emit()
func ref_for(group: String, id: String) -> Dictionary:
	for index in doc.collection(group).size():
		if str(doc.collection(group)[index].get("id","")) == id: return {"group":group,"index":index}
	return {}
func click(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = canvas.screen(point)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	canvas.handle_input(event)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1200,760)
	root.content_scale_size = root.size
	editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	for connection in root.get_signal_connection_list("focus_exited"): root.disconnect("focus_exited",connection.callable)
	await frame()
	await frame()
	canvas = editor.canvas
	doc = editor.document
	saved = doc.data.duplicate(true)
	var disk := FileAccess.get_file_as_string(doc.path)
	editor.set_tool("eraser")
	# The producer can remove the screenshot gate after the fix. Exercise a
	# remaining removable gate instead of requiring that deleted map object.
	if ref_for("access_doors",gate_id).is_empty():
		for index in doc.collection("access_doors").size():
			var ref := {"group":"access_doors","index":index}
			if doc.value(ref).kind == "locked" and doc.can_remove(ref): gate_id = str(doc.value(ref).id); break
	var door := ref_for("access_doors",gate_id)
	check("equipment door is removable",doc.can_remove(door))
	var pairs: Array = doc.removal_refs([door])
	check("equipment door includes associated facade",pairs.size() == 2 and pairs.any(func(ref): return ref.group == "fixtures"))
	doc.remove_many([door,door])
	check("door collision data removed",ref_for("access_doors",gate_id).is_empty())
	check("associated facade removed",not doc.data.fixtures.any(func(f): return f.get("access_id","") == gate_id))
	check("linked doors no longer reference removed door",not doc.data.access_doors.any(func(g): return g.get("linked_to","") == gate_id))
	check("roof associations cleaned",not doc.data.visibility_rooms.any(func(r): return gate_id in r.get("door_ids",[])))
	await frame()
	check("preview has no ghost door",canvas.architecture_preview.doorways.by_id(gate_id) == null)
	var world = preload("res://scripts/world/prison_world.gd").new()
	world.configure(doc.data,[])
	check("runtime has no removed gate",world.access_by_id(gate_id).is_empty())
	world.free()
	check("edited real map validates",doc.validate().errors.is_empty())
	doc.undo()
	check("undo restores gate facade and associations",doc.data == saved)
	doc.redo()
	check("redo removes gate and facade again",ref_for("access_doors",gate_id).is_empty() and not doc.data.fixtures.any(func(f): return f.get("access_id","") == gate_id))
	reset()
	await frame()
	door = ref_for("access_doors",gate_id)
	var areas: Array = canvas.architecture_preview.visual_hit_areas(door)
	check("logical door has projected visual hit area",not areas.is_empty())
	if not areas.is_empty():
		var point: Vector2 = areas[0].get_center()
		canvas.zoom = 1.2
		canvas.origin = canvas.size/2-point*canvas.zoom
		canvas.layers.set_locked("fixtures",true)
		canvas.eraser.capture(canvas)
		check("locked facade protects associated gate",not canvas.eraser.candidates.any(func(c): return c.ref == door))
		canvas.layers.set_locked("fixtures",false)
		canvas.layers.set_locked("architecture",true)
		canvas.eraser.capture(canvas)
		check("locked gate protects associated facade",not canvas.eraser.candidates.any(func(c): return c.ref.group == "fixtures" and doc.value(c.ref).get("access_id","") == gate_id))
		canvas.layers.set_locked("architecture",false)
		await frame()
		if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+"equipment-door-before.png")
		canvas.eraser.capture(canvas)
		check("unlocked gate captured at visible frame",canvas.eraser.candidates.any(func(c): return c.ref == door))
		# Click projected steel rather than the thin physical threshold.
		click(point,true)
		click(point,false)
		await frame()
		check("real mouse erases equipment gate",ref_for("access_doors",gate_id).is_empty())
		check("real mouse clears preview facade",canvas.architecture_preview.doorways.by_id(gate_id) == null)
		if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+"equipment-door-after.png")
		doc.undo()
		check("mouse stroke undoes atomically",doc.data == saved)
	reset()
	await frame()
	var facade := {}
	for index in doc.collection("fixtures").size():
		if doc.data.fixtures[index].get("access_id","") == gate_id: facade = {"group":"fixtures","index":index}; break
	doc.remove_many([facade])
	check("deleting facade also deletes logical gate",ref_for("access_doors",gate_id).is_empty())
	reset()
	doc.remove_many([ref_for("access_doors","workshop-entry")])
	check("workshop switches association to remaining doorway",doc.data.workshop.access_id == "workshop-entry-east" and doc.validate().errors.is_empty())
	reset()
	check("mandatory confinement gate protected",not doc.can_remove(ref_for("access_doors","solitary-0")))
	check("mandatory confinement facade protected",not doc.can_remove(ref_for("fixtures","solitary-0-visual45")))
	check("base grass protected",not doc.can_remove(ref_for("floor_regions","exterior-base")))
	# Isolated ground sample still uses the actual editor mouse/stroke handlers.
	doc.data.walls = []
	doc.data.architecture.wall_surfaces = []
	doc.data.fixtures = []
	doc.data.access_doors = []
	doc.data.visibility_rooms = []
	doc.data.ground_details = []
	doc.data.terrain_patches = []
	doc.data.floor_regions = [saved.floor_regions[0].duplicate(true),{"id":"erase-room-floor","asset_id":"common_floor_v46","rect":[2500,2500,200,180]}]
	canvas.zoom = 1
	canvas.origin = canvas.size/2-Vector2(2600,2590)
	doc.changed.emit()
	await frame()
	check("ground layer visible and initially locked",canvas.layers.visible.ground and canvas.layers.locked.ground)
	click(Vector2(2600,2590),true)
	click(Vector2(2600,2590),false)
	check("ordinary erase does not delete entire paving",doc.data.floor_regions.size() == 2)
	canvas.layers.set_locked("ground",false)
	await frame()
	check("unlocked floor hover is deletable",canvas.at(canvas.screen(Vector2(2600,2590)),true).get("group","") == "floor_regions")
	var ground_before: Dictionary = doc.data.duplicate(true)
	click(Vector2(2600,2590),true)
	click(Vector2(2600,2590),false)
	check("unlocked floor erased",doc.data.floor_regions.size() == 1)
	await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+"floor-after.png")
	doc.undo()
	check("floor undo restores whole region",doc.data == ground_before)
	doc.data.floor_regions.resize(1)
	doc.data.ground_details = [{"kind":"line","from":[2500,2500],"to":[2700,2700],"width":3}]
	doc.changed.emit()
	await frame()
	check("diagonal line empty bounding-box corner is not hit",canvas.at(canvas.screen(Vector2(2505,2695)),true).is_empty())
	click(Vector2(2600,2600),true)
	click(Vector2(2600,2600),false)
	check("ground safety line erased",doc.data.ground_details.is_empty())
	doc.undo()
	check("ground safety line undo restores endpoints",doc.data.ground_details.size() == 1 and doc.data.ground_details[0].from == [2500,2500])
	doc.data.ground_details = [{"kind":"hatch","rect":[2550,2550,100,20]}]
	doc.changed.emit()
	await frame()
	click(Vector2(2600,2560),true)
	click(Vector2(2600,2560),false)
	check("ground hatch erased",doc.data.ground_details.is_empty())
	doc.data.terrain_patches = [{"asset_id":"common_floor_v46","rect":[2500,2500,200,200],"clip_rect":[2550,2550,80,80]}]
	doc.changed.emit()
	await frame()
	check("patch hit honors clipping",canvas.at(canvas.screen(Vector2(2510,2510)),true).is_empty())
	click(Vector2(2590,2590),true)
	click(Vector2(2590,2590),false)
	check("terrain patch erased",doc.data.terrain_patches.is_empty())
	reset()
	await frame()
	check("saved map remains unchanged",FileAccess.get_file_as_string(doc.path) == disk)
	var failed: Array = checks.keys().filter(func(label): return not checks[label])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	editor.queue_free()
	await frame()
	quit(0 if failed.is_empty() else 1)

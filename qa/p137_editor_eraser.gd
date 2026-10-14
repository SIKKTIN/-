extends SceneTree
const OUT := "res://docs/dev/p137/"
var editor
var canvas
var checks := {}
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func check(label: String, passed: bool) -> void: checks[label] = passed
func button_event(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = canvas.screen(point)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	canvas.handle_input(event)
func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = canvas.screen(point)
	canvas.handle_input(event)
func key(code: Key, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.ctrl_pressed = ctrl
	editor._input(event)
func run() -> void:
	root.size = Vector2i(1200,760)
	root.content_scale_size = root.size
	editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	for connection in root.get_signal_connection_list("focus_exited"): root.disconnect("focus_exited",connection.callable)
	await frame()
	await frame()
	canvas = editor.canvas
	var doc = editor.document
	var disk := FileAccess.get_file_as_string("res://data/rooms/r04.json")
	var saved: Dictionary = doc.data.duplicate(true)
	var furniture: Dictionary = saved.fixtures.filter(func(f):return editor.catalog.assets.get(str(f.asset_id),{}).get("render_mode","") == "projected_prop")[0].duplicate(true)
	# A disposable draft exercises real mouse events without changing the map.
	doc.data.walls = []
	doc.data.architecture.wall_surfaces = []
	for index in range(6):
		doc.data.walls.append([1000+60*index,2000,40,20])
		doc.data.architecture.wall_surfaces.append({"wall_index":index,"grid_tile_asset":"prison_h_a","marker":index})
	doc.data.fixtures = []
	for index in range(2):
		var fixture := furniture.duplicate(true)
		fixture.id = "eraser_test_%d" % index
		fixture.erase("draw_depth")
		fixture.erase("render_size")
		fixture.rect = [1000+100*index,2100,40,40]
		doc.data.fixtures.append(fixture)
	doc.data.starts[0] = [1250,2150]
	canvas.zoom = 1
	canvas.origin = Vector2(50,50)-Vector2(1000,2000)
	canvas.show_collision = true
	doc.changed.emit()
	await frame()
	key(KEY_E)
	check("E activates toolbar eraser",canvas.tool == "eraser" and editor.operation_buttons.eraser.button_pressed)
	check("eraser icon imported",editor.operation_buttons.eraser.icon != null)
	var before: Dictionary = doc.data.duplicate(true)
	var history: int = doc.history.size()
	button_event(Vector2(1005,2010),true)
	check("click immediately removes tile",doc.data.walls.size() == 5)
	motion(Vector2(1275,2010))
	check("fast drag erases all crossed tiles",doc.data.walls.size() == 1)
	check("stroke defers history and object list",doc.history.size() == history and editor.gesture_refresh_pending)
	check("wall materials remap after batches",doc.wall_surface(0).marker == 5 and doc.wall_surface(0).wall_index == 0)
	button_event(Vector2(1275,2010),false)
	check("one stroke creates one undo",doc.history.size() == history+1 and not canvas.erasing and not editor.gesture_refresh_pending)
	check("release refreshes object list",editor.object_refs.size() == doc.entries().size()-doc.entries().filter(func(r):return not editor.layers.is_visible(r.group)).size())
	key(KEY_Z,true)
	check("Ctrl Z restores entire stroke and surfaces",doc.data == before)
	key(KEY_Y,true)
	check("Ctrl Y redoes entire stroke",doc.data.walls.size() == 1 and doc.wall_surface(0).marker == 5)
	key(KEY_Z,true)
	await frame()
	button_event(Vector2(1010,2110),true)
	motion(Vector2(1110,2110))
	check("consecutive motions remove correct shifted fixtures",doc.data.fixtures.is_empty())
	key(KEY_ESCAPE)
	check("Escape cancels whole active stroke",doc.data == before and canvas.tool == "select" and doc.transaction.is_empty())
	await frame()
	key(KEY_E)
	var cursor: int = doc.cursor
	button_event(Vector2(1200,2300),true)
	button_event(Vector2(1200,2300),false)
	check("empty stroke leaves undo cursor unchanged",doc.cursor == cursor)
	editor.layers.set_locked("architecture",true)
	button_event(Vector2(1005,2010),true)
	motion(Vector2(1275,2010))
	button_event(Vector2(1275,2010),false)
	check("locked walls survive eraser",doc.data == before)
	editor.layers.set_locked("architecture",false)
	editor.layers.set_visible("fixtures",false)
	button_event(Vector2(1010,2110),true)
	button_event(Vector2(1010,2110),false)
	check("hidden fixtures survive eraser",doc.data == before)
	editor.layers.set_visible("fixtures",true)
	button_event(Vector2(1250,2150),true)
	button_event(Vector2(1250,2150),false)
	check("protected starts survive eraser",doc.data == before)
	button_event(Vector2(1005,2010),true)
	key(KEY_Z,true)
	check("undo while held ends and restores stroke",not canvas.erasing and doc.data == before)
	await frame()
	button_event(Vector2(1010,2110),true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(5,300)
	editor._input(release)
	check("release outside canvas finishes transaction",not canvas.erasing and doc.transaction.is_empty())
	key(KEY_Z,true)
	await frame()
	canvas.show_collision = false
	await frame()
	var area: Rect2 = canvas.architecture_preview.nodes["fixture:0"].display_rect
	motion(area.get_center())
	check("hover targets visible art",canvas.eraser_hover.get("group","") == "fixtures")
	button_event(area.get_center(),true)
	check("visual mode erases visible furniture",doc.data.fixtures.size() == 1)
	button_event(area.get_center(),false)
	key(KEY_Z,true)
	await frame()
	check("ordinary Delete retains standalone undo",doc.remove_many([{"group":"walls","index":0},{"group":"walls","index":0},{"group":"starts","index":0},{"group":"walls","index":9999}]) == 1)
	doc.undo()
	check("batch rejects duplicates and invalid protected refs",doc.data == before)
	doc.data = saved.duplicate(true)
	doc.history.clear()
	doc.cursor = 0
	doc.changed.emit()
	editor.set_tool("eraser")
	canvas.show_collision = false
	canvas.zoom = 0.65
	canvas.origin = canvas.size/2-Vector2(675,3280)*canvas.zoom
	canvas.erasing = false
	canvas.eraser_inside = true
	await frame()
	await frame()
	motion(Vector2(675,3280))
	await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+"eraser-editor.png")
	# Reproduce the user's case on the complete R04, with normal visual hits.
	# The old test only erased synthetic collision boxes and a projected prop.
	canvas.zoom = 0.75
	canvas.origin = canvas.size/2-Vector2(550,4090)*canvas.zoom
	var real_index := -1
	var nearest_distance := INF
	canvas.eraser.capture(canvas)
	for index in range(doc.data.walls.size()):
		var values: Array = doc.data.walls[index]
		if values[2] != 40 or values[3] != 120: continue
		var distance := Vector2(values[0],values[1]).distance_squared_to(Vector2(460,4100))
		if distance >= nearest_distance: continue
		var areas: Array[Rect2] = []
		areas.assign(canvas.architecture_preview.visual_hit_areas({"group":"walls","index":index}))
		if areas.size() != 1: continue
		var point := areas[0].get_center()
		if not Rect2(Vector2.ZERO,canvas.size).has_point(canvas.screen(point)): continue
		var overlaps: Array = canvas.eraser.candidates.filter(func(c):return c.areas.any(func(area):return area.has_point(point)))
		if overlaps.size() != 1: continue
		nearest_distance = distance
		real_index = index
	# The producer can erase the original screenshot wall in a saved map.
	# Test the nearest remaining matching tile instead of requiring that wall forever.
	check("real wall located in current saved map",real_index >= 0)
	if real_index >= 0:
		var real_values: Array = doc.data.walls[real_index].duplicate()
		var real_ref := {"group":"walls","index":real_index}
		var hit_areas: Array[Rect2] = []
		hit_areas.assign(canvas.architecture_preview.visual_hit_areas(real_ref))
		check("plain grid wall returns typed hit areas",hit_areas.size() == 1)
		var wall_point: Vector2 = hit_areas[0].get_center()
		motion(wall_point)
		await frame()
		if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+"actual-wall-before.png")
		button_event(wall_point,true)
		check("complete map capture reaches all visible walls",canvas.eraser.candidates.filter(func(c):return c.ref.group == "walls").size() > 500)
		check("real wall removed from actual draft",doc.data.walls.size() == saved.walls.size()-1 and real_values not in doc.data.walls)
		button_event(wall_point,false)
		await frame()
		await frame()
		check("actual preview geometry follows erased draft",canvas.architecture_preview.world.walls.size() == doc.data.walls.size())
		var ghost := false
		for index in range(doc.data.walls.size()):
			if canvas.architecture_preview.visual_hit({"group":"walls","index":index},wall_point): ghost = true; break
		check("erased wall no longer visible or hit testable",not ghost)
		if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+"actual-wall-after.png")
		key(KEY_Z,true)
		await frame()
		check("actual map undo restores wall and material",doc.data == saved and canvas.architecture_preview.visual_hit(real_ref,wall_point))
		key(KEY_Y,true)
		await frame()
		check("actual map redo removes wall again",real_values not in doc.data.walls)
		key(KEY_Z,true)
		await frame()
	check("QA leaves saved map file unchanged",FileAccess.get_file_as_string("res://data/rooms/r04.json") == disk)
	check("restored map validates",doc.validate().errors.is_empty())
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"eraser-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	editor.queue_free()
	await frame()
	await frame()
	quit(0 if failed.is_empty() else 1)

extends SceneTree
const OUT := "res://docs/dev/editor-floor/"
const Floors = preload("res://scripts/editor/floor_catalog.gd")
var editor
var canvas
var doc
var checks := {}
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func check(label: String, passed: bool) -> void: checks[label] = passed
func button_at(point: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = canvas.screen(point)
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	canvas.handle_input(e)
func motion(point: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = canvas.screen(point)
	canvas.handle_input(e)
func key(code: Key, ctrl := false) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = code
	e.ctrl_pressed = ctrl
	editor._input(e)
func shot(name: String) -> void:
	await frame()
	await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1440,950)
	root.content_scale_size = root.size
	editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	for c in root.get_signal_connection_list("focus_exited"): root.disconnect("focus_exited",c.callable)
	await frame()
	await frame()
	canvas = editor.canvas
	doc = editor.document
	var disk := FileAccess.get_sha256(doc.path)
	var original: Dictionary = doc.data.duplicate(true)
	var materials := Floors.materials()
	check("existing floor materials available",materials.size() >= 20)
	for spec in materials: check("floor texture available: "+str(spec.name),Floors.texture(spec) != null)
	key(KEY_G)
	check("G activates floor editing",canvas.tool == "floor_edit" and editor.operation_buttons.floor_edit.button_pressed)
	check("floor tool explicitly unlocks ground",editor.layers.is_editable("floor_regions"))
	check("floor tool opens material palette",editor.category_picker.selected == editor.Catalog.CATEGORIES.find("floors") and editor.palette_entries.size() == materials.size())
	# Use an isolated area in a disposable draft, never the producer's disk map.
	doc.data.walls = []
	doc.data.architecture.wall_surfaces = []
	doc.data.fixtures = []
	doc.data.access_doors = []
	doc.data.visibility_rooms = []
	doc.data.erase("workshop")
	doc.data.terrain_patches = []
	doc.data.ground_details = []
	doc.data.floor_regions = [doc.data.floor_regions[0].duplicate(true)]
	doc.history.clear()
	doc.cursor = 0
	doc.changed.emit()
	canvas.zoom = 1
	canvas.origin = canvas.size/2-Vector2(2720,2710)
	var brush: Dictionary = editor.palette_entries.filter(func(e): return e.asset_id == "bath_dry_tiles")[0]
	editor.activate_resource(brush)
	check("palette activates floor rectangle brush",canvas.tool == "floor_paint")
	var before: Dictionary = doc.data.duplicate(true)
	var builds: int = canvas.architecture_preview.full_refreshes
	button_at(Vector2(2800,2800),true)
	motion(Vector2(2600,2600))
	await frame()
	check("reverse rectangle normalized and snapped",doc.geometry(canvas.selection) == Rect2(2600,2600,200,200))
	check("floor source manifest and world tiling preserved",doc.data.floor_regions[-1].manifest == brush.floor_spec.manifest and doc.data.floor_regions[-1].tile_size == [160,160] and doc.data.floor_regions[-1].tile_origin == [0,0])
	check("no undo entries during paint gesture",doc.cursor == 0)
	check("drag avoids rebuilding every door and wall",canvas.architecture_preview.full_refreshes <= builds+1)
	button_at(Vector2(2600,2600),false)
	await frame()
	check("paint commits one undo entry",doc.cursor == 1)
	check("paint release enters editable floor mode",canvas.tool == "floor_edit" and editor.active_tool.text == "编辑地板")
	check("paint release exposes resize handle",canvas.floor_corner(canvas.screen(doc.geometry(canvas.selection).end)) == 2)
	check("new floor appears in editor object list",editor.object_refs.any(func(r): return r.group == "floor_regions" and r.index == 1))
	key(KEY_Z,true)
	check("undo removes painted floor atomically",doc.data == before)
	key(KEY_Y,true)
	check("redo restores painted floor",doc.data.floor_regions.size() == 2)
	key(KEY_G)
	button_at(Vector2(2700,2700),true)
	button_at(Vector2(2700,2700),false)
	check("floor tool selects floor independent of prop layers",canvas.selection == {"group":"floor_regions","index":1})
	var picker := editor.inspector.get_node("FloorMaterial") as OptionButton
	var all := Floors.materials(doc.data)
	var grass := all.find_custom(func(spec): return spec.asset_id == "grass_base_v46" and spec.manifest == "res://art/environment/factory_v46/manifest.json")
	picker.item_selected.emit(grass)
	check("inspector replaces material and tile scale",doc.data.floor_regions[1].asset_id == "grass_base_v46" and doc.data.floor_regions[1].tile_size == [930,930])
	check("grass replacement updates natural ground",doc.data.floor_regions[1].natural_ground)
	key(KEY_Z,true)
	check("material swap can be undone",doc.data.floor_regions[1].asset_id == "bath_dry_tiles")
	button_at(Vector2(2700,2700),true)
	motion(Vector2(2740,2720))
	button_at(Vector2(2740,2720),false)
	check("floor move snaps and preserves size",doc.geometry(canvas.selection) == Rect2(2640,2620,200,200))
	button_at(Vector2(2840,2820),true)
	motion(Vector2(2900,2860))
	button_at(Vector2(2900,2860),false)
	check("corner handle resizes floor with opposite anchor",doc.geometry(canvas.selection) == Rect2(2640,2620,260,240))
	var width := editor.inspector.find_child("Geometry_w",true,false) as SpinBox
	width.value = 280
	check("numeric size editing supported",doc.geometry(canvas.selection) == Rect2(2640,2620,280,240))
	# A prop may cover the room, but dedicated floor picking still reaches it.
	doc.data.fixtures = [{"id":"floor-prop","asset_id":"heavy_crate_handpaint_v03","rect":[2700,2700,40,40],"blocks_movement":false}]
	doc.changed.emit()
	await frame()
	button_at(Vector2(2720,2720),true)
	button_at(Vector2(2720,2720),false)
	check("overlying furniture does not steal floor selection",canvas.selection.group == "floor_regions")
	await shot("floor-editor")
	var painted: Dictionary = doc.data.duplicate(true)
	editor.activate_resource(brush)
	button_at(Vector2(2540,2520),true)
	motion(Vector2(2640,2580))
	key(KEY_ESCAPE)
	check("Escape cancels entire new floor gesture",doc.data == painted)
	editor.activate_resource(brush)
	button_at(Vector2(2540,2520),true)
	motion(Vector2(2580,2560))
	var release := InputEventMouseButton.new()
	release.position = Vector2.ZERO
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	editor._input(release)
	check("outside canvas release commits floor gesture",not canvas.painting_floor and doc.transaction.is_empty())
	key(KEY_Z,true)
	check("outside release retains single undo",doc.data == painted)
	editor.set_tool("floor_edit")
	editor.layers.set_locked("ground",true)
	var locked: Dictionary = doc.data.duplicate(true)
	button_at(Vector2(2720,2710),true)
	motion(Vector2(2760,2750))
	button_at(Vector2(2760,2750),false)
	check("locked floor cannot move or resize",doc.data == locked)
	key(KEY_G)
	canvas.choose({"group":"floor_regions","index":0})
	var base_rect: Array = doc.data.floor_regions[0].rect.duplicate()
	doc.begin()
	doc.set_geometry(canvas.selection,Rect2(1,1,10,10))
	doc.commit()
	check("base grass extent remains protected",doc.data.floor_regions[0].rect == base_rect)
	var current: Dictionary = doc.data.floor_regions[1].duplicate(true)
	doc.begin()
	doc.set_geometry({"group":"floor_regions","index":1},Rect2(5990,4490,280,240))
	doc.commit()
	check("edited floor constrained within map bounds",doc.geometry({"group":"bounds","index":-1}).encloses(doc.geometry({"group":"floor_regions","index":1})))
	doc.undo()
	check("boundary clipping undo restores floor",doc.data.floor_regions[1] == current)
	var edited: Dictionary = doc.data.floor_regions[1].duplicate(true)
	doc.data = original.duplicate(true)
	if not doc.data.has("floor_regions"):doc.data.floor_regions=[]
	edited.id=doc.unique_id("floor")
	doc.data.floor_regions.append(edited)
	doc.changed.emit()
	var path := "res://data/rooms/qa_floor_%d.json" % Time.get_ticks_msec()
	check("edited floor saves to disposable map",doc.save_file(path,true))
	if not checks["edited floor saves to disposable map"]:print("FLOOR_SAVE_ERROR "+doc.last_error)
	var reloaded = preload("res://scripts/editor/map_document.gd").new()
	check("saved floor reopens correctly",reloaded.open_file(path) and JSON.parse_string(JSON.stringify(reloaded.data.floor_regions)) == JSON.parse_string(JSON.stringify(doc.data.floor_regions)))
	preload("res://scripts/presentation/region_terrain.gd").warm_map(reloaded.data)
	check("saved material loads through runtime terrain painter",reloaded.data.has("floor_regions") and preload("res://scripts/presentation/region_terrain.gd").texture(str(reloaded.data.floor_regions[-1].asset_id),str(reloaded.data.floor_regions[-1].manifest)) != null)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check("producer map never overwritten",FileAccess.get_sha256("res://data/rooms/r04.json") == disk)
	var failed: Array = checks.keys().filter(func(label): return not checks[label])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	editor.queue_free()
	await frame()
	quit(0 if failed.is_empty() else 1)

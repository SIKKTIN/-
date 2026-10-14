extends SceneTree
const OUT := "res://docs/dev/p142/"
var editor
var checks := {}
var native := false
var fixture_ref := {}
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	if native: await RenderingServer.frame_post_draw
func check(name: String, passed: bool) -> void: checks[name] = passed
func key(code: Key, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.ctrl_pressed = ctrl
	editor._input(event)
	await frame()
func click(button: Button) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = root.get_final_transform()*button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await frame()
func shot(name: String) -> void:
	await frame()
	await frame()
	if native: root.get_texture().get_image().save_png(OUT+name+".png")
func sprite_image(data: Dictionary, ref: Dictionary) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(768,512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node2D.new()
	viewport.add_child(stage)
	var geometry = load("res://scripts/editor/preview_geometry.gd").new()
	geometry.update(data,false)
	geometry.art_textures = editor.canvas.textures
	var volume = load("res://scripts/presentation/world_volume.gd").new()
	stage.add_child(volume)
	volume.configure(geometry,"fixture",int(ref.index),editor.canvas.render_profile,editor.canvas.definitions)
	stage.scale = Vector2(2,2)
	stage.position = Vector2(viewport.size)/2-volume.display_rect.get_center()*2
	await frame()
	await frame()
	var result: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	await frame()
	return result
func mirror_error(before: Image, after: Image, horizontal: bool) -> float:
	var error := 0.0
	var pixels := 0
	for y in range(before.get_height()):
		for x in range(before.get_width()):
			var a := before.get_pixel(before.get_width()-1-x if horizontal else x,y if horizontal else before.get_height()-1-y)
			var b := after.get_pixel(x,y)
			if a.a<0.05 and b.a<0.05: continue
			error += maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),maxf(absf(a.b-b.b),absf(a.a-b.a)))
			pixels += 1
	return error/maxi(pixels,1)
func run() -> void:
	native = DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280,800)
	root.content_scale_size = root.size
	editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	for connection in root.get_signal_connection_list("focus_exited"): root.disconnect("focus_exited",connection.callable)
	await frame()
	await frame()
	var doc = editor.document
	var disk := FileAccess.get_sha256("res://data/rooms/r04.json")
	var original: Dictionary = doc.data.duplicate(true)
	var index := -1
	for i in range(doc.data.fixtures.size()):
		if doc.data.fixtures[i].get("id","")=="campus-clinic-bed-0": index = i; break
	fixture_ref = {"group":"fixtures","index":index}
	check("current saved clinic bed found",index>=0)
	var room: Dictionary = doc.data.visibility_rooms.filter(func(r):return r.id=="clinic")[0]
	var rect := Rect2(room.rect[0],room.rect[1],room.rect[2],room.rect[3])
	editor.canvas.zoom = 0.87
	editor.canvas.origin = editor.canvas.size/2-rect.get_center()*editor.canvas.zoom
	editor.canvas.choose(fixture_ref)
	editor.canvas.queue_redraw()
	await frame()
	var before_rect: Rect2 = doc.geometry(fixture_ref)
	var before_display: Rect2 = editor.canvas.architecture_preview.nodes["fixture:%d" % index].display_rect
	check("horizontal and vertical buttons visible",editor.inspector.find_child("MirrorHorizontal",true,false)!=null and editor.inspector.find_child("MirrorVertical",true,false)!=null)
	await shot("bed-before")
	var before_image: Image
	if native: before_image = await sprite_image(doc.data,fixture_ref); before_image.save_png(OUT+"sprite-before.png")
	var cursor: int = doc.cursor
	await click(editor.inspector.find_child("MirrorHorizontal",true,false))
	check("real horizontal button mirrors bed",doc.value(fixture_ref).get("mirror_x",false))
	check("mirror button displays active state",editor.inspector.find_child("MirrorHorizontal",true,false).button_pressed)
	check("mirror creates one undo action",doc.cursor==cursor+1)
	check("mirror keeps footprint and display bounds",doc.geometry(fixture_ref)==before_rect and editor.canvas.architecture_preview.nodes["fixture:%d" % index].display_rect==before_display)
	check("mirror leaves every other object unchanged",doc.data.fixtures.slice(0,index)==original.fixtures.slice(0,index) and doc.data.fixtures.slice(index+1)==original.fixtures.slice(index+1) and doc.data.walls==original.walls and doc.data.floor_regions==original.floor_regions)
	await shot("bed-horizontal-mirror")
	if native:
		var after_image := await sprite_image(doc.data,fixture_ref)
		after_image.save_png(OUT+"sprite-horizontal.png")
		var error := mirror_error(before_image,after_image,true)
		print("MIRROR_HORIZONTAL_PIXEL_ERROR ",error)
		check("actual bed pixels reverse left and right",error<0.015)
	var preview: String = doc.preview_file()
	var reopened = load("res://scripts/editor/map_document.gd").new()
	check("mirror survives file save and reopen",reopened.open_file(preview) and reopened.value(fixture_ref).get("mirror_x",false) and reopened.validate().errors.is_empty())
	DirAccess.remove_absolute(preview)
	# Runtime uses the exact same painter and retained mirror setting.
	var world = load("res://scripts/world/prison_world.gd").new()
	world.configure(JSON.parse_string(doc.text()),[])
	world.art_textures = editor.canvas.textures
	var volume = load("res://scripts/presentation/world_volume.gd").new()
	root.add_child(volume)
	volume.configure(world,"fixture",index,editor.canvas.render_profile,editor.canvas.definitions)
	check("runtime mirror and collision retained",world.fixtures[index].get("mirror_x",false) and volume.footprint==before_rect and volume.display_rect==before_display)
	volume.queue_free()
	world.free()
	await key(KEY_Z,true)
	check("Ctrl Z restores original bed",doc.data==original)
	await key(KEY_Y,true)
	check("Ctrl Y is redo and not vertical mirror",doc.value(fixture_ref).get("mirror_x",false) and not doc.value(fixture_ref).get("mirror_y",false))
	await key(KEY_X)
	check("second mirror restores exact original",doc.data==original)
	await key(KEY_Y)
	check("Y activates vertical mirror",doc.value(fixture_ref).get("mirror_y",false))
	if native:
		var image := await sprite_image(doc.data,fixture_ref)
		var error := mirror_error(before_image,image,false)
		print("MIRROR_VERTICAL_PIXEL_ERROR ",error)
		check("actual pixels reverse vertically",error<0.015)
	await key(KEY_Y)
	check("two vertical mirrors restore original",doc.data==original)
	editor.rotate_selected(1)
	await frame()
	var rotated: Dictionary = doc.data.duplicate(true)
	var rotated_before: Image
	if native: rotated_before = await sprite_image(doc.data,fixture_ref)
	await key(KEY_X)
	check("rotated horizontal mirror uses current screen axis",doc.value(fixture_ref).get("mirror_y",false) and not doc.value(fixture_ref).get("mirror_x",false))
	if native:
		var image := await sprite_image(doc.data,fixture_ref)
		var error := mirror_error(rotated_before,image,true)
		print("MIRROR_ROTATED_PIXEL_ERROR ",error)
		check("rotated pixels reflect horizontally",error<0.015)
	await key(KEY_X)
	check("rotated double mirror restores exact draft",doc.data==rotated)
	doc.undo()
	doc.undo()
	doc.undo()
	check("rotation and mirror undo restore map",doc.data==original)
	# Locks and text editing preserve existing safety and shortcuts.
	editor.layers.set_locked("fixtures",true)
	editor.mirror_selected(true)
	check("locked objects cannot mirror",doc.data==original)
	editor.layers.set_locked("fixtures",false)
	editor.canvas.choose(fixture_ref)
	var input: LineEdit = editor.inspector.find_child("Geometry_x",true,false).get_line_edit()
	input.grab_focus()
	await key(KEY_X)
	check("typing X in property field does not mirror",doc.data==original)
	input.release_focus()
	editor.canvas.choose_group([fixture_ref])
	editor.mirror_selected(true)
	check("group selection does not accidentally flip one member",doc.data==original)
	editor.canvas.choose(fixture_ref)
	# Explicit old false values and mirrored furniture duplicates remain compatible.
	doc.data.fixtures[index].mirror_x = false
	var explicit_before: Dictionary = doc.data.duplicate(true)
	doc.mirror_fixture(fixture_ref,true)
	doc.mirror_fixture(fixture_ref,true)
	check("explicit false mirror value survives roundtrip",doc.data==explicit_before)
	doc.data.fixtures[index].erase("mirror_x")
	editor.canvas.choose(fixture_ref)
	editor.mirror_selected(true)
	editor.duplicate_selected()
	check("duplicated prop retains mirror",doc.value(editor.selection).get("mirror_x",false))
	doc.undo()
	doc.undo()
	check("duplicate and mirror undo preserve user placement",doc.data==original)
	editor.canvas.choose(fixture_ref)
	root.size = Vector2i(960,640)
	root.content_scale_size = root.size
	await frame()
	await frame()
	check("mirror controls fit narrow inspector",root.get_visible_rect().encloses(editor.inspector_tabs.get_global_rect()))
	check("user map file untouched",FileAccess.get_sha256("res://data/rooms/r04.json")==disk)
	if native:
		# Test an existing compound sprite, including its per-patch rotations and
		# mirrored pieces, through the same retained renderer as ordinary props.
		var compound: Dictionary = original.duplicate(true)
		var specimen: Dictionary = compound.fixtures[index]
		specimen.asset_id = "cafeteria_t_20_v33"
		specimen.rect = [1540.0,360.0,68.0,121.5]
		specimen.erase("rotation_quarters")
		editor.canvas.load_referenced_textures(compound,{})
		var base := await sprite_image(compound,fixture_ref)
		specimen.mirror_x = true
		var horizontal := await sprite_image(compound,fixture_ref)
		var error := mirror_error(base,horizontal,true)
		print("ASSEMBLY_HORIZONTAL_PIXEL_ERROR ",error)
		check("compound sprite reflects all patches horizontally",error<0.015)
		specimen.erase("mirror_x")
		specimen.mirror_y = true
		var vertical := await sprite_image(compound,fixture_ref)
		error = mirror_error(base,vertical,false)
		print("ASSEMBLY_VERTICAL_PIXEL_ERROR ",error)
		check("compound sprite reflects all patches vertically",error<0.015)
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"mirror-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print("P142 ",JSON.stringify({"checks":checks.size(),"failed":failed}))
	editor.queue_free()
	await frame()
	await frame()
	quit(0 if failed.is_empty() else 1)

extends SceneTree
const OUT := "res://docs/dev/p141/"
var editor
var canvas
var checks := {}
var native := false
var difference_count := 0
func differences(a, b, path := "") -> void:
	if difference_count>20 or a==b: return
	if a is Dictionary and b is Dictionary:
		for k in a:
			if b.has(k): differences(a[k],b[k],path+"/"+str(k))
			else: print("DIFF missing ",path,"/",k); difference_count+=1
		for k in b:
			if not a.has(k): print("DIFF added ",path,"/",k); difference_count+=1
	elif a is Array and b is Array:
		for i in range(mini(a.size(),b.size())): differences(a[i],b[i],path+"/"+str(i))
	else: print("DIFF ",path," ",a," ",b," types ",typeof(a)," ",typeof(b)); difference_count+=1
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	if native: await RenderingServer.frame_post_draw
func check(name: String, value: bool) -> void: checks[name] = value
func mouse(p: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform()*(canvas.global_position+canvas.screen(p))
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	Input.parse_input_event(event)
	await frame()
func motion(p: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform()*(canvas.global_position+canvas.screen(p))
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	await frame()
func key(code: Key, shift := false, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	editor._input(event)
	await frame()
func shot(name: String) -> void:
	await frame()
	await frame()
	if native: root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	native = DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1600,960)
	root.content_scale_size = root.size
	editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	for connection in root.get_signal_connection_list("focus_exited"): root.disconnect("focus_exited",connection.callable)
	await frame()
	await frame()
	canvas = editor.canvas
	var doc = editor.document
	var disk_hash := FileAccess.get_sha256("res://data/rooms/r04.json")
	var original: Dictionary = doc.data.duplicate(true)
	check("existing map validates",doc.validate().errors.is_empty())
	check("inspector and layers use tabs",editor.inspector_tabs.get_tab_count()==2)
	check("three column palette",editor.palette.max_columns==3 and editor.palette.fixed_column_width==64)
	check("central canvas expands",canvas.size.x>1000)
	canvas.zoom = 0.86
	canvas.origin = canvas.size/2-Vector2(1780,650)*canvas.zoom
	canvas.queue_redraw()
	editor.set_tool("marquee")
	await mouse(Vector2(1460,280),true)
	await motion(Vector2(2100,1060))
	check("real left drag draws marquee",canvas.marquee_active)
	await mouse(Vector2(2100,1060),false)
	check("real release selects whole clinic",canvas.group_refs.size()>40 and canvas.group_refs.any(func(ref):return ref.group=="walls") and canvas.group_refs.any(func(ref):return ref.group=="fixtures"))
	check("room metadata selected with overlay hidden",canvas.group_refs.any(func(ref):return ref.group=="visibility_rooms" and doc.value(ref).id=="clinic"))
	check("default excludes people and loose items",canvas.group_refs.all(func(ref):return not ref.group in ["starts","resident_staff","items"]))
	check("selection creates no document edit",doc.data==original and not doc.dirty())
	check("group properties and actions visible",editor.inspector.find_child("Group_x",true,false)!=null and editor.selection_actions.visible)
	await shot("clinic-selected-1600")
	var refs: Array = canvas.group_refs.duplicate(true)
	var bounds: Rect2 = canvas.group_bounds()
	var before_history: int = doc.cursor
	var expected_floor: Array = doc.data.floor_regions.filter(func(f):return f.id=="campus-clinic")[0].rect.duplicate()
	await key(KEY_R)
	check("R rotates once as one undo action",doc.cursor==before_history+1 and canvas.selection_angle==90)
	check("group extents swap around same center",canvas.group_bounds().get_center().is_equal_approx(bounds.get_center()) and canvas.group_bounds().size.is_equal_approx(Vector2(bounds.size.y,bounds.size.x)))
	check("contained floor rotates",doc.data.floor_regions.filter(func(f):return f.id=="campus-clinic")[0].rect!=expected_floor)
	check("default people remain unchanged",doc.data.resident_staff==original.resident_staff and doc.data.starts==original.starts)
	var selected_wall: Dictionary = refs.filter(func(ref):return ref.group=="walls")[0]
	var surface: Dictionary = doc.wall_surface(int(selected_wall.index))
	check("wall orientation persisted",surface.get("rotation_quarters",0)==1)
	var wall_bounds: Rect2 = doc.geometry(selected_wall)
	check("wall collision remains in rotated footprint",surface.collision_parts.all(func(part):return Rect2(Vector2.ZERO,wall_bounds.size).grow(0.001).encloses(Rect2(part[0],part[1],part[2],part[3]))))
	var wall_node = canvas.architecture_preview.nodes["wall:%d" % int(selected_wall.index)]
	check("wall painter and collision agree",wall_node.rotation_quarters==1 and wall_node.footprint==wall_bounds)
	var furniture: Dictionary = refs.filter(func(ref):return ref.group=="fixtures" and editor.catalog.assets.get(str(doc.value(ref).asset_id),{}).get("render_mode","")=="projected_prop")[0]
	var node = canvas.architecture_preview.nodes["fixture:%d" % int(furniture.index)]
	check("fixture assembled or ordinary painter rotates",node.rotation_quarters==1 and node.footprint==doc.geometry(furniture))
	await shot("clinic-rotated")
	await key(KEY_R)
	await key(KEY_R)
	await key(KEY_R)
	check("four turns restore geometry and metadata",doc.data==original)
	if doc.data!=original:
		differences(original,doc.data)
		FileAccess.open(OUT+"four-turn-before.json",FileAccess.WRITE).store_string(JSON.stringify(original))
		FileAccess.open(OUT+"four-turn-after.json",FileAccess.WRITE).store_string(doc.text())
	await key(KEY_R)
	await key(KEY_R,true)
	check("Shift R reverses rotation",doc.data==original)
	# Drag the selected whole building through the actual viewport input route.
	await mouse(bounds.get_center(),true)
	var preview_builds: int = canvas.architecture_preview.full_refreshes
	await motion(bounds.get_center()+Vector2(80,100))
	check("whole building drag active",canvas.group_dragging)
	check("drag preview avoids serialization and architecture rebuild",doc.data==original and canvas.architecture_preview.full_refreshes==preview_builds)
	await mouse(bounds.get_center()+Vector2(80,100),false)
	check("whole building moves by snapped delta",canvas.group_bounds().position.is_equal_approx(bounds.position+Vector2(80,100)))
	check("floor follows moved building",doc.data.floor_regions.filter(func(f):return f.id=="campus-clinic")[0].rect.slice(0,2)==[float(expected_floor[0])+80,float(expected_floor[1])+100])
	await key(KEY_Z,false,true)
	check("one undo restores whole building",doc.data==original)
	await key(KEY_Y,false,true)
	check("one redo restores whole building movement",canvas.group_bounds().position.is_equal_approx(bounds.position+Vector2(80,100)))
	await key(KEY_Z,false,true)
	await mouse(bounds.get_center(),true)
	await motion(bounds.get_center()+Vector2(120,0))
	await key(KEY_ESCAPE)
	check("Escape cancels drag and selection",doc.data==original and canvas.group_refs.is_empty() and not canvas.group_dragging)
	# Locked/hidden scenery is never included in the marquee.
	editor.layers.set_locked("fixtures",true)
	canvas.marquee_select(Rect2(1460,280,640,780))
	check("locked fixtures excluded",canvas.group_refs.all(func(ref):return ref.group!="fixtures"))
	editor.layers.set_locked("fixtures",false)
	editor.layers.set_visible("fixtures",false)
	canvas.marquee_select(Rect2(1460,280,640,780))
	check("hidden fixtures excluded",canvas.group_refs.all(func(ref):return ref.group!="fixtures"))
	editor.layers.set_visible("fixtures",true)
	canvas.marquee_select(Rect2(1460,280,640,780))
	# Shared renderer used by runtime must retain the orientation after JSON reload.
	editor.rotate_selected(1)
	var serialized: Dictionary = JSON.parse_string(doc.text())
	var preview_file: String = doc.preview_file()
	var reopened = load("res://scripts/editor/map_document.gd").new()
	check("rotated preview file reopens and validates",reopened.open_file(preview_file) and reopened.validate().errors.is_empty())
	check("rotated preview preserves wall and door presentation",reopened.data==serialized)
	DirAccess.remove_absolute(preview_file)
	var world = load("res://scripts/world/prison_world.gd").new()
	world.configure(serialized,[])
	var volume = load("res://scripts/presentation/world_volume.gd").new()
	root.add_child(volume)
	world.art_textures = canvas.textures
	volume.configure(world,"wall",int(selected_wall.index),canvas.render_profile,canvas.definitions)
	check("rotation survives runtime JSON reload",volume.rotation_quarters==1 and world.walls[int(selected_wall.index)]==doc.geometry(selected_wall))
	volume.queue_free()
	world.free()
	doc.undo()
	canvas.choose_group(refs)
	editor.duplicate_selected()
	check("whole building duplicate adds walls and remaps door IDs",doc.data.walls.size()>original.walls.size() and doc.data.fixtures.size()>original.fixtures.size())
	check("copied metadata passes shape validation",doc.check_shape(doc.data).is_empty())
	await key(KEY_Z,false,true)
	check("duplicate undo restores all objects",doc.data==original)
	canvas.choose_group(refs)
	editor.delete_selected()
	check("group delete also removes contained floor",doc.data.walls.size()<original.walls.size() and not doc.data.floor_regions.any(func(region):return region.id=="campus-clinic"))
	doc.undo()
	check("group delete undo restores objects and floor",doc.data==original)
	canvas.choose(furniture)
	editor.rotate_selected(1)
	await frame()
	canvas.choose(furniture)
	check("reselect single object reports saved orientation",canvas.selection_angle==90)
	var rotated_rect: Rect2 = doc.geometry(furniture)
	doc.begin()
	doc.move(furniture,rotated_rect.position+Vector2(40,40))
	doc.commit()
	check("moving rotated prop preserves swapped footprint",doc.geometry(furniture).size.is_equal_approx(rotated_rect.size))
	doc.undo()
	doc.undo()
	check("single object rotation and movement undo",doc.data==original)
	canvas.selection_scope.actors = true
	canvas.marquee_select(Rect2(1460,280,640,780))
	check("optional actor scope selects clinic staff",canvas.group_refs.any(func(ref):return ref.group=="resident_staff"))
	canvas.selection_scope.actors = false
	canvas.choose_group(refs)
	await mouse(bounds.get_center(),true)
	await motion(bounds.get_center()+Vector2(40,0))
	var sidebar_release := InputEventMouseButton.new()
	sidebar_release.button_index = MOUSE_BUTTON_LEFT
	sidebar_release.pressed = false
	sidebar_release.position = editor.library_tabs.get_global_rect().get_center()
	editor._input(sidebar_release)
	check("releasing over sidebar completes one group drag",not canvas.group_dragging and doc.transaction.is_empty())
	doc.undo()
	check("sidebar release undo restores map",doc.data==original)
	canvas.choose_group(refs)
	root.size = Vector2i(1200,760)
	root.content_scale_size = root.size
	await frame()
	await frame()
	canvas.zoom = 0.65
	canvas.origin = canvas.size/2-Vector2(1780,650)*canvas.zoom
	canvas.queue_redraw()
	await shot("clinic-selected-1200")
	check("layout fits 1200x760",root.get_visible_rect().encloses(editor.inspector_tabs.get_global_rect()) and canvas.size.x>500)
	editor.inspector_tabs.current_tab = 1
	await shot("layers-1200")
	check("layer controls fit layer tab",editor.layer_rows.size()==8 and root.get_visible_rect().encloses(editor.layer_rows.visibility.locked.get_global_rect()))
	editor.inspector_tabs.current_tab = 0
	editor.toggle_library()
	await frame()
	check("collapsing library expands canvas",not editor.library_tabs.visible and canvas.size.x>800)
	editor.toggle_library()
	canvas.choose({})
	root.size = Vector2i(960,640)
	root.content_scale_size = root.size
	await frame()
	await frame()
	canvas.choose(furniture)
	await shot("object-properties-960")
	check("narrow window retains canvas and property panel",canvas.size.x>=280 and root.get_visible_rect().encloses(editor.inspector_tabs.get_global_rect()))
	check("selected object opens property tab",editor.inspector_tabs.current_tab==0)
	check("disk map untouched",FileAccess.get_sha256("res://data/rooms/r04.json")==disk_hash)
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"building-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print("P141 ",JSON.stringify({"checks":checks.size(),"failed":failed}))
	editor.queue_free()
	await frame()
	await frame()
	quit(0 if failed.is_empty() else 1)

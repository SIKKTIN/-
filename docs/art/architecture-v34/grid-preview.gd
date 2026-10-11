extends SceneTree
var editor
var checks: Array=[]
const OUT="res://docs/art/architecture-v34/"
func _initialize() -> void: call_deferred("run")
func check(label: String, result: bool) -> void:
	checks.append({"name":label,"passed":result})
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func add_tile(id: String, p: Vector2) -> Dictionary:
	return editor.document.add("fixtures",p,id)
func run() -> void:
	root.size=Vector2i(1280,850);root.content_scale_size=root.size
	root.gui_disable_input=true
	editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame()
	var doc=editor.document
	var baseline:=FileAccess.get_sha256("res://data/rooms/r04.json")
	doc.data.fixtures=[];doc.data.walls=[];doc.data.architecture={"wall_surfaces":[]};doc.data.id="grid-wall-review";doc.data.title="格子墙试拼 · 等待主美用户审评"
	for layer in ["walls","starts","patrol","guard_start","gate_guards","merchants","items","dormitories","dorm_doors","zones","access_doors","confinement","work","meal","dine","free"]:editor.layers.set_visible(layer,false)
	doc.grid=20;doc.changed.emit()
	# Exact cell placements: the independent short T and both L turns, complete bodies included.
	add_tile("wall_grid_l_left",Vector2(600,600))
	for x in [640,680,720]:add_tile("wall_grid_h",Vector2(x,600))
	add_tile("wall_grid_t",Vector2(760,600))
	for x in [820,860,900]:add_tile("wall_grid_h",Vector2(x,600))
	add_tile("wall_grid_l_right",Vector2(940,600))
	for x in [600,780,960]:
		for y in [720,840]:add_tile("wall_grid_v",Vector2(x,y))
		add_tile("wall_grid_end",Vector2(x,960))
	for x in range(600,980,40):add_tile("wall_grid_h",Vector2(x,1140))
	for f in doc.data.fixtures:
		check(str(f.id)+" whole cells",f.rect.all(func(v):return is_equal_approx(fmod(float(v),20.0),0.0)))
		check(str(f.id)+" exact painted rectangle",f.render_size==[f.rect[2],f.rect[3]])
	# A resized old instance may not leak into the next same-ID block.
	var ref=add_tile("wall_grid_h",Vector2(613,1437))
	check("new placement snaps both axes",doc.geometry(ref)==Rect2(620,1440,40,120))
	doc.set_geometry(ref,Rect2(627,1431,39,122))
	check("move/resize keeps exact grid footprint",doc.geometry(ref)==Rect2(620,1440,40,120))
	var another=add_tile("wall_grid_h",Vector2(667,1437))
	check("next block does not clone fractional size",doc.geometry(another)==Rect2(660,1440,40,120))
	doc.grid=0
	var no_snap=add_tile("wall_grid_h",Vector2(703,1431))
	check("grid blocks retain their own cell rule",doc.geometry(no_snap)==Rect2(700,1440,40,120))
	doc.grid=20
	# Save a review map only; active editor and R04 disk map remain untouched.
	FileAccess.open(OUT+"grid-sample-map.json",FileAccess.WRITE).store_string(doc.text())
	check("original R04 disk unchanged",FileAccess.get_sha256("res://data/rooms/r04.json")==baseline)
	doc.changed.emit();await frame();await frame()
	editor.category_picker.select(0);editor.rebuild_subcategories()
	var category: int=editor.subcategory_ids.find("tiles_h")
	editor.subcategory_picker.select(category);editor.rebuild_palette()
	check("one current grid horizontal tile",editor.palette_entries.size()==1 and editor.palette_entries[0].asset_id=="wall_grid_h")
	var c=editor.canvas
	c.zoom=1.2;c.origin=c.size/2-Vector2(800,840)*c.zoom;c.queue_redraw()
	await frame();await frame()
	check("runtime painter used by editor",c.architecture_preview.nodes.values().any(func(n):return n.get_script().resource_path=="res://scripts/presentation/world_volume.gd"))
	root.get_texture().get_image().save_png(OUT+"grid-editor-preview.png")
	# GPU seam samples: horizontal/H-T and T-V interfaces compared one screen pixel on each side.
	var im:=root.get_texture().get_image();var diffs=[]
	for seam in [640,680,720,760,820,860,900,940]:
		var delta:=0.0
		# The coping intentionally retains dark stone joints; compare the actual face and foot.
		for y in [650,675,700]:
			var p: Vector2=c.screen(Vector2(seam,y))+c.global_position
			var a: Color=im.get_pixel(int(p.x)-1,int(p.y));var b: Color=im.get_pixel(int(p.x),int(p.y))
			delta=maxf(delta,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
		diffs.append({"seam_world_x":seam,"face_and_foot_max_RGB_delta":delta});check("GPU horizontal face/foot port "+str(seam),delta<0.075)
	for x in [600,780,960]:
		var p: Vector2=c.screen(Vector2(x+10,720))+c.global_position
		var a: Color=im.get_pixel(int(p.x),int(p.y)-1);var b: Color=im.get_pixel(int(p.x),int(p.y))
		var delta:=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
		diffs.append({"vertical_root_x":x,"max_RGB_delta":delta});check("GPU corner/T vertical port "+str(x),delta<0.075)
	var failed=checks.filter(func(v):return not v.passed)
	FileAccess.open(OUT+"grid-native-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"seams":diffs,"passed":failed.is_empty()},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed,"seams":diffs}))
	c.zoom=0.8;c.origin=c.size/2-Vector2(800,940)*c.zoom;c.queue_redraw();await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"grid-editor-wide.png")
	if OS.get_cmdline_user_args().has("interactive") and failed.is_empty():
		root.gui_disable_input=false
		editor.open_now(OUT+"grid-sample-map.json")
		editor.maps.add_item("墙体试拼")
		editor.maps.set_item_metadata(editor.maps.item_count-1,OUT+"grid-sample-map.json")
		editor.maps.select(editor.maps.item_count-1)
		c.zoom=0.8;c.origin=c.size/2-Vector2(800,940)*c.zoom;c.queue_redraw()
		return
	quit(0 if failed.is_empty() else 1)

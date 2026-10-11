extends SceneTree
const OUT = "res://docs/art/architecture-v34/"
var editor
var checks: Array = []
func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool) -> void: checks.append({"name":label,"passed":passed})
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func view(center: Vector2, zoom: float, filename: String) -> void:
	var c = editor.canvas
	c.zoom = zoom
	c.origin = c.size/2-center*zoom
	c.queue_redraw()
	await frame(); await frame()
	root.get_texture().get_image().save_png(OUT+filename)
func run() -> void:
	root.size = Vector2i(1600,1000); root.content_scale_size = root.size
	root.gui_disable_input = true
	editor = load("res://scenes/editor/map_editor.tscn").instantiate(); root.add_child(editor)
	await frame(); await frame()
	editor.open_now("res://data/rooms/r04.json")
	await frame(); await frame()
	var doc = editor.document
	var validation: Dictionary = doc.validate()
	check("map valid: "+str(validation.errors),validation.errors.is_empty())
	var surfaces: Array = doc.data.architecture.wall_surfaces
	var grid: Array = surfaces.filter(func(s): return s.has("grid_tile_asset"))
	check("85 independent wall tiles",grid.size()==85)
	for s in grid:
		var r: Array = doc.data.walls[int(s.wall_index)]
		var a: Dictionary = editor.catalog.assets[s.grid_tile_asset]
		check(str(s.wall_index)+" integer cells and native dimensions",r.all(func(v):return is_zero_approx(fmod(float(v),20.0))) and r.slice(2)==a.render_size)
	check("old seven composite strips removed",not doc.data.walls.any(func(r):return r==[1100,1230,924,31.5]))
	# Exercise actual palette click placement, not only the model helper.
	var entry: Dictionary = editor.catalog.entries.filter(func(e):return e.id=="wall_grid_h")[0]
	check("palette creates walls",entry.group=="walls")
	editor.activate_resource(entry)
	var before: int = doc.data.walls.size()
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=editor.canvas.screen(Vector2(1507,1051))
	editor.canvas.handle_input(event)
	check("palette click makes fixed grid block",doc.data.walls.size()==before+1 and doc.geometry({"group":"walls","index":before})==Rect2(1500,1060,40,120))
	var ref: Dictionary = {"group":"walls","index":before}
	doc.set_geometry(ref,Rect2(1507,1051,111,31.5))
	check("move cannot stretch source tile",doc.geometry(ref)==Rect2(1500,1060,40,120))
	var duplicate: Dictionary = doc.duplicate_entry(ref)
	var collision: Array = doc.wall_surface(duplicate.index).collision_parts[0]
	check("duplicate carries collision and art",doc.wall_surface(duplicate.index).grid_tile_asset=="wall_grid_h" and Rect2(collision[0],collision[1],collision[2],collision[3])==Rect2(0,100,40,20))
	doc.remove(duplicate);doc.remove(ref)
	editor.set_tool("select")
	var world = load("res://scripts/world/prison_world.gd").new()
	world.configure(doc.data,[])
	var collisions: Array[Rect2] = world.wall_collision_rects()
	check("facade is not floor collision",not collisions.any(func(r):return r.has_point(Vector2(1150,1180))))
	check("facade foot blocks movement",collisions.any(func(r):return r.has_point(Vector2(1150,1250))))
	check("door aperture remains free of wall",not collisions.any(func(r):return r.has_point(Vector2(1010,1250))))
	for x in [720,2000]:
		check("continuous side collision "+str(x),range(1260,2240).all(func(y):return collisions.any(func(r):return r.has_point(Vector2(x+10,y)))))
	check("continuous southern collision",range(720,2020).all(func(x):return collisions.any(func(r):return r.has_point(Vector2(x,2230)))))
	world.free()
	# Show the real map with its furniture, then wall joints at working scale.
	for layer in ["actors","patrol","items","routine","areas"]: editor.layers.set_visible(layer,false)
	editor.category_picker.select(0);editor.rebuild_subcategories()
	editor.subcategory_picker.select(editor.subcategory_ids.find("tiles_h"));editor.rebuild_palette()
	await view(Vector2(1370,1650),0.54,"perimeter-editor-full.png")
	var first: Dictionary = editor.canvas.at(editor.canvas.screen(Vector2(1220,1190)))
	var next: Dictionary = editor.canvas.at(editor.canvas.screen(Vector2(1248,1190)))
	check("adjacent wall tiles select independently",first.get("group","")=="walls" and next.get("group","")=="walls" and first.index!=next.index)
	check("selection is one 40 by 120 block",doc.geometry(first).size==Vector2(40,120))
	await view(Vector2(1330,1240),0.95,"perimeter-editor-north.png")
	editor.canvas.choose(first)
	check("inspector reports native grid size",is_equal_approx(editor.inspector.find_child("Geometry_w",true,false).value,40) and is_equal_approx(editor.inspector.find_child("Geometry_h",true,false).value,120))
	await view(Vector2(1330,1240),0.95,"perimeter-editor-selection.png")
	editor.canvas.choose({})
	await view(Vector2(980,2180),1.15,"perimeter-editor-bottom.png")
	var failed: Array = checks.filter(func(c):return not c.passed)
	FileAccess.open(OUT+"perimeter-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"passed":failed.is_empty()},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed,"passed":failed.is_empty()}))
	if OS.get_cmdline_user_args().has("interactive") and failed.is_empty():
		editor.open_now("res://data/rooms/r04.json")
		root.gui_disable_input=false
		await frame();await frame()
		await view(Vector2(1370,1650),0.54,"perimeter-editor-open.png")
		return
	quit(0 if failed.is_empty() else 1)

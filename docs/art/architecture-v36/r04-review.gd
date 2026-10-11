extends SceneTree
const OUT="res://docs/art/architecture-v36/"
var editor
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func check(name: String, passed: bool) -> void:checks.append({"name":name,"passed":passed})
func shot(center: Vector2, zoom: float, name: String) -> void:
	var c=editor.canvas;c.zoom=zoom;c.origin=c.size/2-center*zoom;c.queue_redraw();await frame();await frame()
	root.get_texture().get_image().save_png(OUT+name)
func run() -> void:
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size;root.gui_disable_input=true
	editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame()
	editor.open_now("res://data/rooms/r04.json");await frame();await frame()
	var doc=editor.document
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"r04-before-universal.json"))
	var validation: Dictionary=doc.validate()
	check("R04 validates: "+str(validation.errors),validation.errors.is_empty())
	check("wall geometry unchanged",doc.data.walls==old.walls)
	check("fixtures and access rules unchanged",doc.data.fixtures==old.fixtures and doc.data.access_doors==old.access_doors and doc.data.cafeteria==old.cafeteria)
	var surfaces: Array=doc.data.architecture.wall_surfaces
	check("85 current universal wall tiles",surfaces.size()==85 and surfaces.all(func(s):return editor.catalog.assets[str(s.grid_tile_asset)].get("authoring_set","")=="universal-v36"))
	for s in surfaces:
		var prior: Dictionary=old.architecture.wall_surfaces.filter(func(p):return p.wall_index==s.wall_index)[0]
		check(str(s.wall_index)+" collision unchanged",s.collision_parts==prior.collision_parts)
		check(str(s.wall_index)+" asset available in material library",editor.catalog.entries.any(func(e):return e.id==s.grid_tile_asset))
	editor.category_picker.select(0);editor.rebuild_subcategories()
	for spec in [["tiles_h",8],["tiles_v",5],["tiles_corner",4],["tiles_junction",5],["tiles_end",4],["tiles_frame",3]]:
		editor.subcategory_picker.select(editor.subcategory_ids.find(spec[0]));editor.rebuild_palette()
		check(str(spec[0])+" current palette count",editor.palette_entries.size()==spec[1])
	for layer in ["actors","patrol","items","routine","areas"]:editor.layers.set_visible(layer,false)
	editor.subcategory_picker.select(editor.subcategory_ids.find("tiles_h"));editor.rebuild_palette()
	await shot(Vector2(1370,1650),0.54,"r04-full.png")
	await shot(Vector2(1320,1240),0.95,"r04-north.png")
	var ref: Dictionary=editor.canvas.at(editor.canvas.screen(Vector2(1220,1190)))
	check("real facade picks one tile",ref.get("group","")=="walls" and doc.geometry(ref).size==Vector2(40,120))
	editor.canvas.choose(ref)
	check("real R04 style menu has five compatible choices",editor.inspector.find_child("WallAppearance",true,false).item_count==5)
	await frame();await frame();root.get_texture().get_image().save_png(OUT+"r04-selection.png")
	editor.canvas.choose({})
	editor.subcategory_picker.select(editor.subcategory_ids.find("tiles_corner"));editor.rebuild_palette()
	await shot(Vector2(1000,2160),1.15,"r04-southwest.png")
	var failed: Array=checks.filter(func(c):return not c.passed)
	FileAccess.open(OUT+"r04-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"passed":failed.is_empty()},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed,"passed":failed.is_empty()}))
	if OS.get_cmdline_user_args().has("interactive") and failed.is_empty():
		editor.subcategory_picker.select(editor.subcategory_ids.find("tiles_h"));editor.rebuild_palette()
		root.gui_disable_input=false
		DisplayServer.window_set_title("这次怎么逃 · R04通用瓦片 · 地图编辑器")
		await shot(Vector2(1370,1650),0.54,"r04-open.png")
		print("UNIVERSAL_R04_EDITOR_READY: actual material library + R04 map")
		return
	quit(0 if failed.is_empty() else 1)

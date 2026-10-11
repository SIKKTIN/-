extends SceneTree
const OUT="res://docs/art/props-perspective-v42/"
var editor
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func check(label: String, result: bool) -> void:checks.append({"name":label,"passed":result})
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func shot(center: Vector2, zoom: float, filename: String) -> void:
	editor.canvas.zoom=zoom;editor.canvas.origin=editor.canvas.size/2-center*zoom;editor.canvas.queue_redraw()
	await frame();await frame();root.get_texture().get_image().save_png(OUT+filename)
func run() -> void:
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size;root.gui_disable_input=true
	editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	editor.open_now("res://data/rooms/r04.json");await frame();await frame()
	var doc=editor.document
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"r04-review-baseline.json"))
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"r04-before-props.json"))
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/props/prison_v42/manifest.json"))
	check("R04 validates",doc.validate().errors.is_empty())
	var expected: Dictionary=before.duplicate(true);var actual: Dictionary=doc.data.duplicate(true)
	expected.erase("fixtures");actual.erase("fixtures")
	check("all architecture, walls, doors, collision, rules, actor and item map data unchanged",expected==actual)
	check("all fixture rectangles and blocking unchanged",doc.data.fixtures.size()==before.fixtures.size() and range(before.fixtures.size()).all(func(i):return doc.data.fixtures[i].rect==before.fixtures[i].rect and doc.data.fixtures[i].blocks_movement==before.fixtures[i].blocks_movement and doc.data.fixtures[i].blocks_sight==before.fixtures[i].blocks_sight))
	check("original pre-art fixture footprints and collision preserved",original.fixtures.all(func(old):return doc.data.fixtures.any(func(f):return f.id==old.id and f.rect==old.rect and f.blocks_movement==old.blocks_movement and f.blocks_sight==old.blocks_sight)))
	check("V41 dining tables and trays unchanged",doc.data.fixtures.filter(func(f):return str(f.id).begins_with("dine-"))==before.fixtures.filter(func(f):return str(f.id).begins_with("dine-")))
	var assets: Dictionary=editor.catalog.assets
	check("old prop definitions retained for existing maps but hidden from new placement",editor.catalog.RETIRED_PROP_IDS.all(func(id):return assets.has(id) and not editor.catalog.is_placeable(id)))
	for a in manifest.assets:
		var id: String=a.id
		check(id+" formal palette with native thumbnail",editor.catalog.entries.any(func(e):return e.id==id and e.icon==a.editor_icon) and ResourceLoader.exists(a.editor_icon))
		check(id+" source PNG bytes unchanged",FileAccess.get_sha256(a.texture)==a.sha256)
		check(id+" uniform width-based registration",is_equal_approx(float(a.footprint_world_size[0])/a.ground_rect[2],float(a.footprint_world_size[1])/a.ground_rect[3]))
		var tex: Texture2D=editor.canvas.textures[id]
		check(id+" native cropped mipmap texture",tex!=null and tex.get_image().has_mipmaps())
		var pixels:=tex.get_image();var clear:=0
		for y in range(0,pixels.get_height(),8):
			for x in range(0,pixels.get_width(),8):
				if pixels.get_pixel(x,y).a<0.1:clear+=1
		check(id+" transparent silhouette/background",clear>10)
		var ref: Dictionary=doc.add("fixtures",Vector2(1300,1800),id)
		check(id+" independent placement works",str(doc.data.fixtures[ref.index].asset_id)==id)
		doc.undo()
	editor.open_now("res://data/rooms/r04.json");await frame();await frame()
	var scaled_correctly: bool=true
	for i in range(doc.data.fixtures.size()):
		var f: Dictionary=doc.data.fixtures[i]
		if not str(f.asset_id).ends_with("_v42"):continue
		var node=editor.canvas.architecture_preview.nodes["fixture:"+str(i)]
		var a: Dictionary=assets[f.asset_id]
		scaled_correctly=scaled_correctly and is_equal_approx(node.display_rect.size.x/a.region[2],node.display_rect.size.y/a.region[3]) and is_equal_approx(node.display_rect.end.y,f.rect[1]+f.rect[3])
	check("all23 placed props preserve native camera and ground baseline",scaled_correctly)
	var back_index: int=-1;var front_index: int=-1
	for i in range(doc.data.fixtures.size()):
		if doc.data.fixtures[i].id=="canteen-counter":front_index=i
		if doc.data.fixtures[i].id=="canteen-kitchen-collision":back_index=i
	var front=editor.canvas.architecture_preview.nodes["fixture:"+str(front_index)]
	var back=editor.canvas.architecture_preview.nodes["fixture:"+str(back_index)]
	check("rear row naturally overlaps wall base and remains flush",back.display_rect.position.y<1260 and is_equal_approx(back.display_rect.end.y,1320))
	check("kitchen retains more than100 visible units working aisle",front.display_rect.position.y-back.display_rect.end.y>100)
	var world=load("res://scripts/world/prison_world.gd").new();world.configure(doc.data,[])
	check("kitchen aisle remains physically clear and reachable",world.can_place_circle(Vector2(1600,1400),17,null,false) and not world.find_path(Vector2(1200,1600),Vector2(1600,1400),null,false).is_empty())
	check("all dining points remain reachable",doc.data.routine_points.dine.all(func(p):return world.can_place_circle(Vector2(p[0],p[1]),17,null,false) and not world.find_path(Vector2(1200,1900),Vector2(p[0],p[1]),null,false).is_empty()))
	world.free()
	for layer in ["actors","patrol","items","routine","areas"]:editor.layers.set_visible(layer,false)
	editor.category_picker.select(1);editor.rebuild_subcategories();editor.subcategory_picker.select(editor.subcategory_ids.find("serving"));editor.rebuild_palette()
	await shot(Vector2(1580,1360),1.2,"r04-kitchen-editor.png")
	editor.category_picker.select(0);editor.rebuild_subcategories();editor.subcategory_picker.select(editor.subcategory_ids.find("furnishings"));editor.rebuild_palette()
	await shot(Vector2(1300,400),0.95,"r04-workshop-editor.png")
	await shot(Vector2(400,560),0.9,"r04-cells-editor.png")
	await shot(Vector2(1180,1120),0.38,"r04-full.png")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);editor.hide();await frame()
	game.set_process(false);game.load_room("r04",["chat","lockpick","backpack"],52)
	game.routine_panel.close();game.schedule.set_time_speed(0);game.orders.clear()
	game.map_camera.center_on(Vector2(1550,1370));game.map_camera.following=false;game.presentation.tick(0);game._update_ui()
	await frame();await frame();root.get_texture().get_image().save_png(OUT+"r04-kitchen-runtime.png")
	check("runtime loads all10 updated prop definitions",manifest.assets.all(func(a):return game.world.art_textures.has(a.id)))
	game.queue_free();await frame();editor.show()
	var failed: Array=checks.filter(func(c):return not c.passed)
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"passed":failed.is_empty()},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed,"passed":failed.is_empty()}))
	quit(0 if failed.is_empty() else 1)

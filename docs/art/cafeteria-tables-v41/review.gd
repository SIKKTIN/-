extends SceneTree
const OUT="res://docs/art/cafeteria-tables-v41/"
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
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"r04-before-tables.json"))
	check("R04 validates",doc.validate().errors.is_empty())
	var expected: Dictionary=before.duplicate(true);var actual: Dictionary=doc.data.duplicate(true)
	expected.erase("fixtures");actual.erase("fixtures")
	check("architecture, walls, doors, schedule and all non-fixture map data unchanged",expected==actual)
	var untouched: Array=[];var old_untouched: Array=[]
	for f in doc.data.fixtures:
		if not str(f.id).begins_with("dine-"):untouched.append(f)
	for f in before.fixtures:
		if not str(f.id).begins_with("dine-"):old_untouched.append(f)
	check("kitchen, corridor tables and all other props unchanged",untouched==old_untouched)
	var old_solids: Array=[];var solids: Array=[]
	for f in before.fixtures:
		if f.get("blocks_movement",false):old_solids.append(f.rect)
	for f in doc.data.fixtures:
		if f.get("blocks_movement",false):solids.append(f.rect)
	check("all fixture collision geometry unchanged",solids==old_solids)
	var assets: Dictionary=editor.catalog.assets
	for id in ["cafeteria_table_v41","cafeteria_tray_v41"]:
		var a: Dictionary=assets[id]
		check(id+" visible formal palette with native thumbnail",editor.catalog.entries.any(func(e):return e.id==id and e.icon==a.editor_icon and e.category=="cafeteria") and ResourceLoader.exists(a.editor_icon))
		check(id+" native source bytes preserved",FileAccess.get_sha256(a.texture)==a.sha256)
		check(id+" uniform camera-preserving scale",is_equal_approx(float(a.footprint_world_size[0])/a.ground_rect[2],float(a.footprint_world_size[1])/a.ground_rect[3]))
		var tex: Texture2D=editor.canvas.textures[id]
		check(id+" imported cropped mipmap sprite",tex!=null and tex.get_image().has_mipmaps())
		var pixels:=tex.get_image();var clear:=0
		for y in range(0,pixels.get_height(),8):
			for x in range(0,pixels.get_width(),8):
				if pixels.get_pixel(x,y).a<0.1:clear+=1
		check(id+" alpha backdrop and furniture gaps",clear>20)
		var ref: Dictionary=doc.add("fixtures",Vector2(1370,1740),id)
		check(id+" independently placeable from palette",doc.geometry(ref).size.is_equal_approx(Vector2(a.footprint_world_size[0],a.footprint_world_size[1])))
		doc.undo()
	check("legacy table and tray definitions retained",assets.has("communal_table") and assets.has("cafeteria_tray"))
	editor.open_now("res://data/rooms/r04.json");await frame();await frame()
	for n in range(4):
		var table_index: int=-1;var tray_index: int=-1
		for i in range(doc.data.fixtures.size()):
			if doc.data.fixtures[i].id=="dine-table-"+str(n):table_index=i
			if doc.data.fixtures[i].id=="dine-tray-"+str(n):tray_index=i
		var table=editor.canvas.architecture_preview.nodes["fixture:"+str(table_index)]
		var tray=editor.canvas.architecture_preview.nodes["fixture:"+str(tray_index)]
		var scale: float=table.display_rect.size.x/float(assets.cafeteria_table_v41.region[2])
		# Tabletop y275..599 in the native sprite, registered crop starts at137.
		var top:=Rect2(table.display_rect.position+Vector2(0,(275-137)*scale),Vector2(table.display_rect.size.x,(599-275)*scale))
		check("tray"+str(n)+" fully on tabletop and sorts above furniture",top.encloses(tray.display_rect) and tray.z_index>table.z_index)
		check("table"+str(n)+" retains original dimensions and collision",doc.data.fixtures[table_index].rect==before.fixtures.filter(func(f):return f.id=="dine-table-"+str(n))[0].rect)
	var world=load("res://scripts/world/prison_world.gd").new();world.configure(doc.data,[])
	var points: Array=doc.data.routine_points.dine
	check("all existing dining points remain clear",points.all(func(p):return world.can_place_circle(Vector2(p[0],p[1]),17,null,false)))
	check("all dining points have routes from dining floor",points.all(func(p):return not world.find_path(Vector2(1200,1900),Vector2(p[0],p[1]),null,false).is_empty()))
	world.free()
	for layer in ["actors","patrol","items","routine","areas"]:editor.layers.set_visible(layer,false)
	editor.category_picker.select(1);editor.rebuild_subcategories()
	editor.subcategory_picker.select(editor.subcategory_ids.find("furnishings"));editor.rebuild_palette()
	await shot(Vector2(1200,1920),1.25,"r04-tables-editor.png")
	editor.subcategory_picker.select(editor.subcategory_ids.find("tableware"));editor.rebuild_palette()
	await shot(Vector2(1360,1650),0.56,"r04-full.png")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);editor.hide();await frame()
	game.set_process(false);game.load_room("r04",["chat","lockpick","backpack"],52)
	game.routine_panel.close();game.schedule.set_time_speed(0);game.orders.clear()
	game.map_camera.center_on(Vector2(1200,1850));game.map_camera.following=false;game.presentation.tick(0);game._update_ui()
	await frame();await frame();root.get_texture().get_image().save_png(OUT+"r04-tables-runtime.png")
	check("runtime loads new table and independent tray",game.world.art_textures.has("cafeteria_table_v41") and game.world.art_textures.has("cafeteria_tray_v41"))
	game.queue_free();await frame();editor.show()
	var failed: Array=checks.filter(func(c):return not c.passed)
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"passed":failed.is_empty()},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed,"passed":failed.is_empty()}))
	if OS.get_cmdline_user_args().has("interactive") and failed.is_empty():
		root.gui_disable_input=false;DisplayServer.window_set_title("这次怎么逃 · R04 斜俯视餐桌与餐盘 · 地图编辑器")
		editor.subcategory_picker.select(editor.subcategory_ids.find("furnishings"));editor.rebuild_palette()
		await shot(Vector2(1200,1920),1.25,"r04-editor-open.png")
		return
	quit(0 if failed.is_empty() else 1)

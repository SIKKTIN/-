extends SceneTree
const OUT="res://docs/art/cafeteria-v40/"
var editor
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func check(name: String, passed: bool) -> void:checks.append({"name":name,"passed":passed})
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func shot(center: Vector2, zoom: float, name: String) -> void:
	editor.canvas.zoom=zoom;editor.canvas.origin=editor.canvas.size/2-center*zoom;editor.canvas.queue_redraw()
	await frame();await frame();root.get_texture().get_image().save_png(OUT+name)
func run() -> void:
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size;root.gui_disable_input=true
	editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	editor.open_now("res://data/rooms/r04.json");await frame();await frame()
	var doc=editor.document;var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"r04-before-cafeteria.json"))
	check("R04 validates",doc.validate().errors.is_empty())
	check("approved wall geometry and artwork unchanged",doc.data.walls==before.walls and doc.data.architecture==before.architecture)
	check("cafeteria hours, gate and routine points unchanged",doc.data.access_doors==before.access_doors and doc.data.cafeteria==before.cafeteria and doc.data.routine_points==before.routine_points)
	var assets: Dictionary=editor.catalog.assets
	for id in ["cafeteria_counter_front_v40","cafeteria_backline_v40"]:
		var a: Dictionary=assets[id]
		check(id+" current formal palette and native thumbnail",editor.catalog.entries.any(func(e):return e.id==id and e.icon==a.editor_icon and e.category=="cafeteria" and e.subcategory=="serving") and ResourceLoader.exists(a.editor_icon))
		var ground: Array=a.ground_rect
		var dims: Array=a.footprint_world_size
		check(id+" uniform sprite scale preserves camera angle",is_equal_approx(float(dims[0])/ground[2],float(dims[1])/ground[3]))
		check(id+" native source bytes unchanged",FileAccess.get_sha256(a.texture)==a.sha256)
		var tex: Texture2D=editor.canvas.textures[id]
		check(id+" native cropped mipmap texture",tex!=null and tex.get_image().has_mipmaps())
		var pixels:=tex.get_image();var clear:=0
		for y in range(0,pixels.get_height(),8):
			for x in range(0,pixels.get_width(),8):
				if pixels.get_pixel(x,y).a<0.1:clear+=1
		check(id+" transparent cutout without scene background",clear>20)
		var ref: Dictionary=doc.add("fixtures",Vector2(1353,1286),id)
		check(id+" independent placement footprint",doc.geometry(ref).size==Vector2(dims[0],dims[1]))
		doc.undo()
	check("old combined image hidden from new placement, still readable",not editor.catalog.is_placeable("cafeteria_counter") and assets.has("cafeteria_counter"))
	editor.open_now("res://data/rooms/r04.json");await frame();await frame()
	var world=load("res://scripts/world/prison_world.gd").new();world.configure(doc.data,[])
	check("work aisle accepts a character",world.can_place_circle(Vector2(1600,1400),17,null,false))
	check("work aisle can be entered from cafeteria",not world.find_path(Vector2(1200,1600),Vector2(1600,1400),null,false).is_empty())
	check("back equipment still blocks movement",not world.can_place_circle(Vector2(1600,1290),17,null,false))
	check("serving counter still blocks movement",not world.can_place_circle(Vector2(1600,1530),17,null,false))
	world.free()
	var front_index:=0;var back_index:=0
	for i in range(doc.data.fixtures.size()):
		if doc.data.fixtures[i].id=="canteen-counter":front_index=i
		if doc.data.fixtures[i].id=="canteen-kitchen-collision":back_index=i
	var front=editor.canvas.architecture_preview.nodes["fixture:"+str(front_index)]
	var back=editor.canvas.architecture_preview.nodes["fixture:"+str(back_index)]
	check("front counter baseline shifted one grid for navigable entrance",is_equal_approx(front.display_rect.end.y,1560))
	check("rear footprint meets wall base1260",is_equal_approx(back.footprint.position.y,1260))
	check("rear furniture overlaps lower wall naturally",back.display_rect.position.y<1260 and back.display_rect.end.y<=1321)
	check("visible aisle is more than100 world units",front.display_rect.position.y-back.display_rect.end.y>100)
	check("removed hidden blocking slab",not doc.data.fixtures[back_index].get("hidden",false) and doc.data.fixtures[back_index].rect[3]<=60)
	var lamp_index: int=-1
	for i in range(doc.data.fixtures.size()):
		if doc.data.fixtures[i].id=="expansion-7":lamp_index=i
	var lamp=editor.canvas.architecture_preview.nodes["fixture:"+str(lamp_index)]
	check("wall lamp sorts above wall and remains above rear equipment",lamp.z_index>1260 and lamp.display_rect.end.y<back.display_rect.position.y+20)
	for layer in ["actors","patrol","items","routine","areas"]:editor.layers.set_visible(layer,false)
	editor.category_picker.select(1);editor.rebuild_subcategories();editor.subcategory_picker.select(editor.subcategory_ids.find("serving"));editor.rebuild_palette()
	await shot(Vector2(1580,1340),1.35,"r04-cafeteria-editor.png")
	editor.canvas.choose({"group":"fixtures","index":back_index})
	await shot(Vector2(1580,1340),1.15,"r04-backline-selection.png")
	editor.canvas.choose({})
	await shot(Vector2(1360,1650),0.56,"r04-full.png")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);editor.hide();await frame()
	game.set_process(false);game.load_room("r04",["chat","lockpick","backpack"],52)
	game.routine_panel.close();game.schedule.set_time_speed(0);game.orders.clear()
	game.map_camera.center_on(Vector2(1590,1370));game.map_camera.following=false;game.presentation.tick(0);game._update_ui()
	await frame();await frame();root.get_texture().get_image().save_png(OUT+"r04-cafeteria-runtime.png")
	check("runtime loads both separate kitchen textures",game.world.art_textures.has("cafeteria_counter_front_v40") and game.world.art_textures.has("cafeteria_backline_v40"))
	game.queue_free();await frame();editor.show()
	var failed: Array=checks.filter(func(c):return not c.passed)
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"passed":failed.is_empty()},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed,"passed":failed.is_empty()}))
	if OS.get_cmdline_user_args().has("interactive") and failed.is_empty():
		root.gui_disable_input=false;DisplayServer.window_set_title("这次怎么逃 · R04 贴墙食堂与工作通道 · 地图编辑器")
		await shot(Vector2(1580,1350),1.15,"r04-editor-open.png")
		return
	quit(0 if failed.is_empty() else 1)

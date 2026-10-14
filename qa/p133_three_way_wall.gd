extends SceneTree

const ID="prison_t_w_round_v53"
const OUT="res://docs/dev/p133/"
const Volume=preload("res://scripts/presentation/world_volume.gd")
var editor
var checks: Dictionary={}
var owners: Array=[]

class Background extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0,0,800,1100),Color("aab09f"))
		for x in range(0,801,80):draw_line(Vector2(x,0),Vector2(x,1100),Color(0.3,0.35,0.3,0.1))
		for y in range(0,1101,80):draw_line(Vector2(0,y),Vector2(800,y),Color(0.3,0.35,0.3,0.1))

func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func check(label: String, passed: bool) -> void:checks[label]=passed
func tile(view: Node,id: String,at: Vector2) -> void:
	var asset: Dictionary=editor.catalog.assets[id]
	var world=load("res://scripts/editor/preview_geometry.gd").new()
	world.walls.append(Rect2(Vector2.ZERO,Vector2(asset.render_size[0],asset.render_size[1])))
	world.wall_surfaces={0:{"height":20,"grid_tile_asset":id}}
	world.art_textures=editor.canvas.textures
	world.bounds=Rect2(0,0,10000,10000)
	owners.append(world)
	var node:=Volume.new()
	view.add_child(node)
	node.position=at
	node.scale=Vector2.ONE*4
	node.configure(world,"wall",0,{},editor.catalog.assets)
func difference(a: Color,b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func run() -> void:
	root.size=Vector2i(1600,1000)
	root.content_scale_size=root.size
	editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	var asset: Dictionary=editor.catalog.assets[ID]
	check("three ports north south west",asset.connections==["north","south","west"])
	check("native 20-unit grid",Vector2(asset.render_size[0],asset.render_size[1])==Vector2(40,140) and int(asset.grid_tile.cell)==20)
	check("registered T-junction palette and thumbnail",editor.catalog.entries.any(func(e):return e.id==ID and e.subcategory=="tiles_junction" and e.icon==asset.editor_icon) and ResourceLoader.exists(asset.editor_icon))
	check("real map validates",editor.document.validate().errors.is_empty())
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"r04-before.json"))
	var after: Dictionary=editor.document.data.duplicate(true)
	check("existing wall rectangles preserved",before.walls==after.walls)
	var surface: Dictionary=editor.document.wall_surface(104)
	check("screenshot junction replaced",surface.grid_tile_asset==ID)
	check("junction collision preserved",surface.collision_parts==asset.collision_parts)
	for s in after.architecture.wall_surfaces:
		if s.wall_index==104:s.grid_tile_asset="prison_l_nw"
	check("only designated appearance changes",after==before)
	var ref: Dictionary=editor.document.add("walls",Vector2(1227,1247),ID)
	check("editor can place new junction",editor.document.geometry(ref)==Rect2(1220,1240,40,140))
	editor.document.undo()
	if DisplayServer.get_name()!="headless":
		for direction in ["west","north","south"]:
			var viewport:=SubViewport.new()
			viewport.size=Vector2i(320,560) if direction=="west" else Vector2i(160,800)
			viewport.transparent_bg=true
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			match direction:
				"west":tile(viewport,"prison_h_b",Vector2(0,80));tile(viewport,ID,Vector2(160,0))
				"north":tile(viewport,"prison_v_a",Vector2(80,0));tile(viewport,ID,Vector2(0,240))
				"south":tile(viewport,ID,Vector2.ZERO);tile(viewport,"prison_v_b",Vector2(80,560))
			await frame()
			await frame()
			var image:=viewport.get_texture().get_image()
			var delta:=0.0
			var alpha:=1.0
			var edge: int=160 if direction=="west" else 240 if direction=="north" else 560
			for k in range(84,556) if direction=="west" else range(84,156):
				var first:=image.get_pixel(edge-1,k) if direction=="west" else image.get_pixel(k,edge-1)
				var second:=image.get_pixel(edge,k) if direction=="west" else image.get_pixel(k,edge)
				delta=maxf(delta,difference(first,second))
				alpha=minf(alpha,minf(first.a,second.a))
			check(direction+" seam has matched color and full coverage",delta<0.035 and alpha>0.99)
			viewport.queue_free()
			await frame()
		var gallery:=SubViewport.new()
		gallery.size=Vector2i(800,1100)
		gallery.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(gallery)
		gallery.add_child(Background.new())
		tile(gallery,ID,Vector2(400,300))
		tile(gallery,"prison_v_a",Vector2(480,60))
		tile(gallery,"prison_v_b",Vector2(480,860))
		for i in range(2):tile(gallery,["prison_h_b","prison_h_c"][i],Vector2(240-i*160,380))
		await frame()
		await frame()
		gallery.get_texture().get_image().save_png(OUT+"three-way-assembled.png")
		gallery.queue_free()
	for layer in ["actors","patrol","items","routine","areas"]:editor.layers.set_visible(layer,false)
	editor.category_picker.select(0)
	editor.rebuild_subcategories()
	editor.subcategory_picker.select(editor.subcategory_ids.find("tiles_junction"))
	editor.rebuild_palette()
	editor.canvas.zoom=1.8
	editor.canvas.origin=editor.canvas.size/2-Vector2(690,3320)*1.8
	editor.canvas.queue_redraw()
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+"map-junction.png")
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)

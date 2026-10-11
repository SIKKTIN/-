extends SceneTree
const OUT="res://docs/art/architecture-v38/"
const Volume=preload("res://scripts/presentation/world_volume.gd")
var editor
var checks: Array=[]
var owners: Array=[]
class Gallery extends Node2D:
	var font: Font
	func _draw() -> void:
		draw_rect(Rect2(0,0,1000,1000),Color("aab09f"))
		for x in range(0,1001,40):draw_line(Vector2(x,0),Vector2(x,1000),Color(0.35,0.4,0.33,0.09))
		for y in range(0,1001,40):draw_line(Vector2(0,y),Vector2(1000,y),Color(0.35,0.4,0.33,0.09))
		for spec in [["左上 · 向右 / 向下",Vector2(70,40)],["右上 · 向左 / 向下",Vector2(580,40)],["左下 · 向右 / 向上",Vector2(70,540)],["右下 · 向左 / 向上",Vector2(580,540)]]:
			draw_string(font,spec[1],spec[0],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("31413b"))
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func check(name: String, passed: bool) -> void:checks.append({"name":name,"passed":passed})
func shot(center: Vector2, zoom: float, filename: String) -> void:
	editor.canvas.zoom=zoom;editor.canvas.origin=editor.canvas.size/2-center*zoom;editor.canvas.queue_redraw()
	await frame();await frame()
	root.get_texture().get_image().save_png(OUT+filename)
func tile(v: Node,id: String,p: Vector2,factor:=4.0) -> void:
	var a: Dictionary=editor.catalog.assets[id]
	var w=load("res://scripts/editor/preview_geometry.gd").new()
	w.walls.append(Rect2(Vector2.ZERO,Vector2(a.render_size[0],a.render_size[1])))
	w.wall_surfaces={0:{"height":20,"grid_tile_asset":id}};w.art_textures=editor.canvas.textures;w.bounds=Rect2(0,0,10000,10000);owners.append(w)
	var n:=Volume.new();v.add_child(n);n.position=p;n.scale=Vector2.ONE*factor;n.configure(w,"wall",0,{},editor.catalog.assets)
func delta(a: Color,b: Color) -> float:return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func run() -> void:
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size;root.gui_disable_input=true
	editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	editor.open_now("res://data/rooms/r04.json");await frame();await frame()
	var doc=editor.document;var assets: Dictionary=editor.catalog.assets
	check("real R04 validates",doc.validate().errors.is_empty())
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"r04-before-continuous-corners.json"))
	check("fixtures and access rules preserved",before.fixtures==doc.data.fixtures and before.access_doors==doc.data.access_doors)
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"integration.json"))
	check("whole perimeter collision cells identical",report.collision_cells_unchanged)
	for code in ["se","sw","ne","nw"]:
		var id: String="prison_l_"+code;var a: Dictionary=assets[id]
		check(id+" updated formal library and native thumbnail",editor.catalog.entries.any(func(e):return e.id==id and e.icon==a.editor_icon) and ResourceLoader.exists(a.editor_icon))
		check(id+" exactly two adjacent ports",a.connections.size()==2 and a.connections.any(func(c):return c in ["east","west"]) and a.connections.any(func(c):return c in ["north","south"]))
		check(id+" grid has whole cells",int(a.render_size[0])%20==0 and int(a.render_size[1])%20==0)
		check(id+" single coherent corner painting",a.get("corner_shape","")=="continuous-rounded-two-port" and a.assembly_patches.all(func(p):return p.destination[0]==0 and p.destination[2]==40))
		var h: int=int(a.render_size[1]);var offset: int=int(a.grid_tile.horizontal_offset)*4
		for direction in a.connections:
			var horizontal: bool=direction in ["east","west"]
			var v:=SubViewport.new();v.size=Vector2i(320,h*4) if horizontal else Vector2i(160,(h+60)*4)
			v.transparent_bg=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(v)
			var sx: int=int(a.grid_tile.stem_x)*4
			match direction:
				"east":tile(v,id,Vector2.ZERO);tile(v,"prison_h_b",Vector2(160,offset))
				"west":tile(v,"prison_h_c",Vector2(0,offset));tile(v,id,Vector2(160,0))
				"north":tile(v,"prison_v_a",Vector2(sx,0));tile(v,id,Vector2(0,240))
				"south":tile(v,id,Vector2.ZERO);tile(v,"prison_v_b",Vector2(sx,h*4))
			await frame();await frame()
			var im:=v.get_texture().get_image();var diff:=0.0;var alpha:=1.0
			var edge: int=160 if horizontal else 240 if direction=="north" else h*4
			for k in range(offset+4,h*4-4) if horizontal else range(sx+4,sx+76):
				var l:=im.get_pixel(edge-1,k) if horizontal else im.get_pixel(k,edge-1)
				var r:=im.get_pixel(edge,k) if horizontal else im.get_pixel(k,edge)
				diff=maxf(diff,delta(l,r));alpha=minf(alpha,minf(l.a,r.a))
			check(id+" "+direction+" color and coverage join",diff<0.035 and alpha>0.99)
			v.queue_free();await frame()
		var ref: Dictionary=doc.add("walls",Vector2(727,1247),id)
		check(id+" 20-grid placement with correct height",doc.geometry(ref)==Rect2(720,1240,40,h))
		doc.undo()
	editor.open_now("res://data/rooms/r04.json");await frame();await frame()
	for layer in ["actors","patrol","items","routine","areas"]:editor.layers.set_visible(layer,false)
	editor.category_picker.select(0);editor.rebuild_subcategories();editor.subcategory_picker.select(editor.subcategory_ids.find("tiles_corner"));editor.rebuild_palette()
	await shot(Vector2(810,1220),2.2,"r04-upper-left.png")
	await shot(Vector2(1910,1220),2.2,"r04-upper-right.png")
	await shot(Vector2(810,2140),2.2,"r04-lower-left.png")
	await shot(Vector2(1910,2140),2.2,"r04-lower-right.png")
	await shot(Vector2(1370,1660),0.56,"r04-full.png")
	var gallery:=SubViewport.new();gallery.size=Vector2i(1000,1000);gallery.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(gallery)
	var background:=Gallery.new();background.font=editor.canvas.font;gallery.add_child(background)
	for code in ["se","sw","ne","nw"]:
		var east: bool=code.ends_with("e");var south: bool=code.begins_with("s")
		var p:=Vector2(90 if east else 830,70 if south else 690)
		tile(gallery,"prison_l_"+code,p,2)
		for i in range(3):
			var q:=p+Vector2((40+i*40)*2 if east else -(40+i*40)*2,0 if south else 40)
			tile(gallery,["prison_h_b","prison_h_c","prison_h_a"][i],q,2)
		tile(gallery,"prison_v_b",p+Vector2(0 if east else 40,240 if south else -120),2)
	await frame();await frame();gallery.get_texture().get_image().save_png(OUT+"four-corners-native.png")
	gallery.queue_free();await frame()
	var failed: Array=checks.filter(func(c):return not c.passed)
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"passed":failed.is_empty()},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed,"passed":failed.is_empty()}));owners.clear()
	if OS.get_cmdline_user_args().has("interactive") and failed.is_empty():
		root.gui_disable_input=false;DisplayServer.window_set_title("这次怎么逃 · R04 四向连续L型弧角 · 地图编辑器")
		await shot(Vector2(900,1330),1.4,"r04-editor.png")
		return
	quit(0 if failed.is_empty() else 1)

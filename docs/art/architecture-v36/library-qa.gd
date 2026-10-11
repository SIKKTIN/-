extends SceneTree
const OUT="res://docs/art/architecture-v36/"
const Volume=preload("res://scripts/presentation/world_volume.gd")
const TextureSource=preload("res://scripts/presentation/world_texture.gd")
var assets: Dictionary={}
var checks: Array=[]
var owners: Array=[]
var editor
class Gallery extends Node2D:
	var font: Font
	var labels: Array=[]
	func _draw() -> void:
		draw_rect(Rect2(0,0,1600,1120),Color("e9e4d8"))
		draw_string(font,Vector2(30,36),"通用监狱瓦片 · 完整墙体 / 整格拼接",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("34433c"))
		for spec in labels:draw_string(font,spec[1],spec[0],HORIZONTAL_ALIGNMENT_LEFT,230,15,Color("34433c"))
func _initialize() -> void:call_deferred("run")
func check(name: String, result: bool) -> void:checks.append({"name":name,"passed":result})
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func owner_for(id: String, position:=Vector2.ZERO):
	var owner=load("res://scripts/editor/preview_geometry.gd").new()
	var dims: Array=assets[id].render_size
	owner.walls.append(Rect2(position,Vector2(dims[0],dims[1])))
	owner.wall_surfaces={0:{"height":20,"grid_tile_asset":id}}
	owner.art_textures=editor.canvas.textures
	owner.bounds=Rect2(0,0,10000,10000)
	owners.append(owner)
	return owner
func viewport(size: Vector2i) -> SubViewport:
	var v:=SubViewport.new();v.size=size;v.transparent_bg=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(v);return v
func tile_node(v: Node, id: String, p: Vector2, scale_factor: float) -> Node2D:
	var n:=Volume.new();v.add_child(n);n.scale=Vector2.ONE*scale_factor;n.position=p;n.configure(owner_for(id),"wall",0,{},assets);return n
func run() -> void:
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size;root.gui_disable_input=true
	editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame()
	assets=editor.catalog.assets
	var library: Array=assets.values().filter(func(a):return a.get("authoring_set","")=="universal-v36")
	check("29 current library assets",library.size()==29)
	check("all registered in real palette",library.all(func(a):return editor.catalog.entries.any(func(e):return e.id==a.id and e.group=="walls")))
	check("retired grid set hidden from new placement",not editor.catalog.is_placeable("wall_grid_h"))
	check("old map references remain loaded",assets.has("wall_grid_h"))
	check("all native thumbnails load",library.all(func(a):return ResourceLoader.exists(a.editor_icon) and load(a.editor_icon) is MeshTexture))
	for a in library:
		check(str(a.id)+" full integer cells",a.render_size.all(func(n):return is_zero_approx(fmod(float(n),20))) and a.grid_tile.columns*20==a.render_size[0] and a.grid_tile.rows*20==a.render_size[1])
		var dims: Array=a.render_size
		var v:=viewport(Vector2i(dims[0]*4,dims[1]*4))
		tile_node(v,str(a.id),Vector2.ZERO,4)
		await frame();await frame()
		var im:=v.get_texture().get_image();var alpha:=1.0
		for x in range(im.get_width()):alpha=minf(alpha,minf(im.get_pixel(x,0).a,im.get_pixel(x,im.get_height()-1).a))
		for y in range(im.get_height()):alpha=minf(alpha,minf(im.get_pixel(0,y).a,im.get_pixel(im.get_width()-1,y).a))
		check(str(a.id)+" GPU reaches all four boundaries",is_equal_approx(alpha,1))
		v.queue_free();await frame()
	# Every ordered A/B/C/D/E pair, not a hand-picked sequential demonstration.
	var variants=["prison_h_a","prison_h_b","prison_h_c","prison_h_d","prison_h_e"]
	var seam_results=[]
	for a in variants:
		for b in variants:
			var v:=viewport(Vector2i(320,480));tile_node(v,a,Vector2.ZERO,4);tile_node(v,b,Vector2(160,0),4)
			await frame();await frame()
			var im:=v.get_texture().get_image();var delta:=0.0
			for y in range(4,476):
				var l:=im.get_pixel(159,y);var r:=im.get_pixel(160,y)
				delta=maxf(delta,maxf(absf(l.r-r.r),maxf(absf(l.g-r.g),absf(l.b-r.b))))
			check(a+" + "+b+" compatible painted edges",delta<0.035)
			seam_results.append({"left":a,"right":b,"RGB_delta":delta})
			v.queue_free();await frame()
	# Short blocks use the same full-height facade profile.
	for pair in [["prison_h_a","prison_h_short_b"],["prison_h_short_c","prison_h_e"]]:
		var wa: int=int(assets[pair[0]].render_size[0]);var wb: int=int(assets[pair[1]].render_size[0])
		var v:=viewport(Vector2i((wa+wb)*4,480));tile_node(v,pair[0],Vector2.ZERO,4);tile_node(v,pair[1],Vector2(wa*4,0),4)
		await frame();await frame()
		var im:=v.get_texture().get_image();var delta:=0.0
		for y in range(4,476):
			var l:=im.get_pixel(wa*4-1,y);var r:=im.get_pixel(wa*4,y)
			delta=maxf(delta,maxf(absf(l.r-r.r),maxf(absf(l.g-r.g),absf(l.b-r.b))))
		check("short facade compatibility "+str(pair),delta<0.035)
		v.queue_free();await frame()
	# Every open directional junction meets the corresponding native facade
	# or longitudinal profile. Direction is artwork plus ports, not rotation.
	for a in library:
		if a.render_size[1]!=120:continue
		for direction in ["west","east"]:
			if not a.connections.has(direction):continue
			var w: int=int(a.render_size[0]);var v:=viewport(Vector2i((w+40)*4,480))
			if direction=="west":
				tile_node(v,"prison_h_c",Vector2.ZERO,4);tile_node(v,str(a.id),Vector2(160,0),4)
			else:
				tile_node(v,str(a.id),Vector2.ZERO,4);tile_node(v,"prison_h_b",Vector2(w*4,0),4)
			await frame();await frame()
			var im:=v.get_texture().get_image();var sx: int=160 if direction=="west" else w*4;var delta:=0.0
			for y in range(4,476):
				var l:=im.get_pixel(sx-1,y);var r:=im.get_pixel(sx,y)
				delta=maxf(delta,maxf(absf(l.r-r.r),maxf(absf(l.g-r.g),absf(l.b-r.b))))
			check(str(a.id)+" "+direction+" facade junction",delta<0.035)
			v.queue_free();await frame()
	for a in library:
		if a.id.begins_with("prison_v_"):continue
		for direction in ["north","south"]:
			if not a.connections.has(direction):continue
			var w: int=int(a.render_size[0]);var h: int=int(a.render_size[1]);var sx: int=maxi(0,int(a.grid_tile.stem_x))*4
			var v:=viewport(Vector2i(w*4,(h+60)*4))
			if direction=="north":
				tile_node(v,"prison_v_b",Vector2(sx,0),4);tile_node(v,str(a.id),Vector2(0,240),4)
			else:
				tile_node(v,str(a.id),Vector2.ZERO,4);tile_node(v,"prison_v_a",Vector2(sx,h*4),4)
			await frame();await frame()
			var im:=v.get_texture().get_image();var sy: int=240 if direction=="north" else h*4;var delta:=0.0
			for x in range(sx+4,sx+76):
				var l:=im.get_pixel(x,sy-1);var r:=im.get_pixel(x,sy)
				delta=maxf(delta,maxf(absf(l.r-r.r),maxf(absf(l.g-r.g),absf(l.b-r.b))))
			check(str(a.id)+" "+direction+" longitudinal junction",delta<0.035)
			v.queue_free();await frame()
	# Actual editor operations: placement, changing a style, random mode,
	# undo, serialization, and collision shape preservation.
	var doc=editor.document
	var baseline:=FileAccess.get_sha256("res://data/rooms/r04.json")
	var before: int=doc.data.walls.size()
	var entry: Dictionary=editor.catalog.entries.filter(func(e):return e.id=="prison_h_a")[0]
	editor.activate_resource(entry)
	editor.place_object("walls",Vector2(1507,1051))
	var ref: Dictionary={"group":"walls","index":before}
	check("manual palette makes actual wall tile",doc.wall_surface(before).grid_tile_asset=="prison_h_a" and doc.geometry(ref)==Rect2(1500,1060,40,120))
	var collisions: Array=doc.wall_surface(before).collision_parts.duplicate(true)
	doc.set_wall_asset(before,"prison_h_e")
	check("swap style preserves geometry and collision",doc.wall_surface(before).grid_tile_asset=="prison_h_e" and doc.geometry(ref)==Rect2(1500,1060,40,120) and doc.wall_surface(before).collision_parts==collisions)
	doc.undo();check("style change undo",doc.wall_surface(before).grid_tile_asset=="prison_h_a")
	doc.set_wall_asset(before,"prison_corner_se")
	check("incompatible shape is not a style replacement",doc.wall_surface(before).grid_tile_asset=="prison_h_a")
	editor.canvas.choose(ref)
	check("inspector exposes all five horizontal styles",editor.inspector.find_child("WallAppearance",true,false).item_count==5)
	var variant_choices: Array[String]=[]
	for x in range(1500,1900,40):variant_choices.append(editor.catalog.stable_variant("prison_h_a",str(doc.data.id),Vector2(x,1060)))
	check("random choices are stable and varied",range(variant_choices.size()).all(func(i):return variant_choices[i]==editor.catalog.stable_variant("prison_h_a",str(doc.data.id),Vector2(1500+i*40,1060))) and variant_choices.any(func(id):return id!=variant_choices[0]))
	editor.random_wall_variants.button_pressed=true
	editor.place_object("walls",Vector2(1540,1060))
	check("random toggle controls actual placement",doc.wall_surface(before+1).grid_tile_asset==editor.catalog.stable_variant("prison_h_a",str(doc.data.id),Vector2(1540,1060)))
	FileAccess.open(OUT+"roundtrip-map.json",FileAccess.WRITE).store_string(doc.text())
	var reloaded=load("res://scripts/editor/map_document.gd").new()
	check("save reload preserves style and collision",reloaded.open_file(OUT+"roundtrip-map.json") and reloaded.wall_surface(before+1).grid_tile_asset==doc.wall_surface(before+1).grid_tile_asset and reloaded.wall_surface(before+1).collision_parts==doc.wall_surface(before+1).collision_parts and reloaded.geometry({"group":"walls","index":before+1})==doc.geometry({"group":"walls","index":before+1}))
	check("QA does not overwrite R04",baseline==FileAccess.get_sha256("res://data/rooms/r04.json"))
	editor.set_tool("walls")
	var stroke_before: int=doc.data.walls.size()
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=editor.canvas.screen(Vector2(1500,1080));editor.canvas.handle_input(press)
	var move:=InputEventMouseMotion.new();move.position=editor.canvas.screen(Vector2(1660,1080));editor.canvas.handle_input(move)
	var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=move.position;editor.canvas.handle_input(release)
	check("B horizontal stroke creates four independent current tiles",doc.data.walls.size()==stroke_before+4 and range(stroke_before,stroke_before+4).all(func(i):return str(doc.wall_surface(i).grid_tile_asset).begins_with("prison_h_") and doc.geometry({"group":"walls","index":i}).size==Vector2(40,120)))
	editor.canvas.choose({});doc.undo();check("whole stroke undo is atomic",doc.data.walls.size()==stroke_before)
	press.position=editor.canvas.screen(Vector2(1500,1080));editor.canvas.handle_input(press)
	move.position=editor.canvas.screen(Vector2(1500,1280));editor.canvas.handle_input(move)
	release.position=move.position;editor.canvas.handle_input(release)
	check("B vertical stroke fills whole cells with long and short tiles",doc.data.walls.size()==stroke_before+3 and range(stroke_before,stroke_before+3).all(func(i):return str(doc.wall_surface(i).grid_tile_asset).begins_with("prison_v_")))
	editor.canvas.choose({});doc.undo();editor.set_tool("select")
	# Complete native gallery gives every direction a visual review, not a
	# rotated front wall pretending to be a vertical wall.
	var gallery_view:=viewport(Vector2i(1600,1120));gallery_view.transparent_bg=false
	var gallery:=Gallery.new();gallery.font=editor.canvas.font;gallery_view.add_child(gallery)
	for i in range(library.size()):
		var a: Dictionary=library[i];var cx: int=i%6;var cy: int=i/6
		var base:=Vector2(30+cx*260,68+cy*205)
		gallery.labels.append([a.name,base+Vector2(0,185)])
		tile_node(gallery_view,str(a.id),base+Vector2(95-a.render_size[0]*0.65,0),1.3)
	gallery.queue_redraw();await frame();await frame()
	gallery_view.get_texture().get_image().save_png(OUT+"library-gallery.png")
	var failed: Array=checks.filter(func(c):return not c.passed)
	FileAccess.open(OUT+"library-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"passed":failed.is_empty(),"seams":seam_results,"random_sequence":variant_choices},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed,"passed":failed.is_empty()}))
	quit(0 if failed.is_empty() else 1)

extends SceneTree
const OUT="res://docs/art/architecture-v37/"
const Volume=preload("res://scripts/presentation/world_volume.gd")
var editor
var checks: Array=[]
var owners: Array=[]
func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool) -> void: checks.append({"name":label,"passed":passed})
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func shot(center: Vector2, zoom: float, filename: String) -> void:
	editor.canvas.zoom=zoom
	editor.canvas.origin=editor.canvas.size/2-center*zoom
	editor.canvas.queue_redraw()
	await frame();await frame()
	root.get_texture().get_image().save_png(OUT+filename)
func tile(v: Node, id: String, p: Vector2) -> void:
	var a: Dictionary=editor.catalog.assets[id]
	var owner=load("res://scripts/editor/preview_geometry.gd").new()
	owner.walls.append(Rect2(Vector2.ZERO,Vector2(a.render_size[0],a.render_size[1])))
	owner.wall_surfaces={0:{"height":20,"grid_tile_asset":id}}
	owner.art_textures=editor.canvas.textures
	owner.bounds=Rect2(0,0,10000,10000)
	owners.append(owner)
	var n:=Volume.new();v.add_child(n);n.scale=Vector2(4,4);n.position=p
	n.configure(owner,"wall",0,{},editor.catalog.assets)
func rgb_delta(a: Color,b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func run() -> void:
	root.size=Vector2i(1600,1000);root.content_scale_size=root.size;root.gui_disable_input=true
	editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame()
	editor.open_now("res://data/rooms/r04.json");await frame();await frame()
	var doc=editor.document
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"r04-before-l-gate.json"))
	check("R04 validates",doc.validate().errors.is_empty())
	check("wall rectangles preserved",doc.data.walls==before.walls)
	for s in doc.data.architecture.wall_surfaces:
		var previous: Array=before.architecture.wall_surfaces.filter(func(x):return x.wall_index==s.wall_index)
		check("collision preserved "+str(s.wall_index),s.collision_parts==previous[0].collision_parts)
	var assets: Dictionary=editor.catalog.assets
	for code in ["se","sw","ne","nw"]:
		var id: String="prison_l_"+code
		check(id+" visible in L palette",editor.catalog.entries.any(func(e):return e.id==id and e.subcategory=="tiles_corner"))
		check(id+" same ports as rounded corner",assets[id].connection_tag==assets["prison_corner_"+code].connection_tag)
		check(id+" can switch style",editor.catalog.compatible_wall_ids(id).has("prison_corner_"+code))
		var a: Dictionary=assets[id]
		check(id+" curved junction has exactly two adjacent ports",a.get("corner_shape","")=="rounded-two-port" and a.connections.size()==2 and a.connections.any(func(c):return c in ["east","west"]) and a.connections.any(func(c):return c in ["north","south"]))
		for direction in a.connections:
			var v:=SubViewport.new();v.transparent_bg=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			var horizontal: bool=direction in ["west","east"]
			v.size=Vector2i(320,480) if horizontal else Vector2i(160,720)
			root.add_child(v)
			var edge: int=160 if direction in ["west","east"] else 240 if direction=="north" else 480
			var stem: int=int(a.grid_tile.stem_x)*4
			match direction:
				"west": tile(v,"prison_h_b",Vector2.ZERO);tile(v,id,Vector2(160,0))
				"east": tile(v,id,Vector2.ZERO);tile(v,"prison_h_c",Vector2(160,0))
				"north": tile(v,"prison_v_a",Vector2(stem,0));tile(v,id,Vector2(0,240))
				"south": tile(v,id,Vector2.ZERO);tile(v,"prison_v_b",Vector2(stem,480))
			await frame();await frame()
			var im:=v.get_texture().get_image();var delta:=0.0
			var min_alpha:=1.0
			for k in range(4,476) if horizontal else range(stem+4,stem+76):
				var l:=im.get_pixel(edge-1,k) if horizontal else im.get_pixel(k,edge-1)
				var r:=im.get_pixel(edge,k) if horizontal else im.get_pixel(k,edge)
				delta=maxf(delta,rgb_delta(l,r))
				min_alpha=minf(min_alpha,minf(l.a,r.a))
			check(id+" "+direction+" joins seamlessly",delta<0.035 and min_alpha>0.99)
			v.queue_free();await frame()
	var ref: Dictionary=doc.add("walls",Vector2(729,1132),"prison_l_se")
	check("L placement snapped 20",doc.geometry(ref)==Rect2(720,1140,40,120))
	doc.set_geometry(ref,Rect2(745,1147,47,126))
	check("L move fixed footprint",doc.geometry(ref)==Rect2(740,1140,40,120))
	doc.undo()
	for state in ["closed","open"]:
		var id: String="prison_gate_"+state+"_v37"
		check(id+" registered",editor.catalog.entries.any(func(e):return e.id==id))
		check(id+" matching crop dimensions",Vector2(assets[id].region[2],assets[id].region[3])==Vector2(946,550))
		check(id+" grid dimensions",Vector2(assets[id].render_size[0],assets[id].render_size[1])==Vector2(180,100) and Vector2(assets[id].footprint_world_size[0],assets[id].footprint_world_size[1])==Vector2(180,20))
		ref=doc.add("fixtures",Vector2(927,1248),id)
		check(id+" placement fills footprint",doc.geometry(ref)==Rect2(920,1240,180,20) and Vector2(doc.value(ref).render_size[0],doc.value(ref).render_size[1])==Vector2(180,100))
		doc.set_geometry(ref,Rect2(945,1273,179,31.5))
		check(id+" move stays on 20-grid",doc.geometry(ref)==Rect2(940,1280,180,20))
		doc.undo()
	check("legacy gate hidden but compatible",not editor.catalog.is_placeable("cafeteria_gate_closed_v23") and assets.has("cafeteria_gate_closed_v23"))
	editor.open_now("res://data/rooms/r04.json");await frame();await frame()
	for layer in ["actors","patrol","items","routine","areas"]:editor.layers.set_visible(layer,false)
	editor.category_picker.select(0);editor.rebuild_subcategories()
	editor.subcategory_picker.select(editor.subcategory_ids.find("tiles_corner"));editor.rebuild_palette()
	check("four L and four rounded corner options",editor.palette_entries.size()==8)
	await shot(Vector2(950,1230),1.8,"r04-l-gate-closed.png")
	await shot(Vector2(780,1220),3.2,"r04-curved-l-detail.png")
	var world=editor.canvas.architecture_preview.world
	var gate_index: int=-1
	for i in range(world.fixtures.size()):
		if world.fixtures[i].get("id","")=="cafeteria-door-visual":gate_index=i
	var closed:=Volume.new();root.add_child(closed);closed.configure(world,"fixture",gate_index,{},assets)
	check("closed frame fills aperture",closed.display_rect==Rect2(920,1160,180,100))
	var door_rect: Array=doc.data.access_doors.filter(func(d):return d.id=="cafeteria-entry")[0].rect
	check("closed logical door 20-grid",Rect2(door_rect[0],door_rect[1],door_rect[2],door_rect[3])==Rect2(920,1240,180,20))
	closed.queue_free()
	var gate: Dictionary=world.access_by_id("cafeteria-entry")
	gate.closed=false
	for node in editor.canvas.architecture_preview.nodes.values():
		if node is Volume: node.tick_visual()
	await shot(Vector2(950,1230),1.8,"r04-l-gate-open.png")
	var opened:=Volume.new();root.add_child(opened);opened.configure(world,"fixture",gate_index,{},assets)
	check("open frame exact same aperture",opened.display_rect==Rect2(920,1160,180,100))
	check("open state paired texture",opened.prop_id()=="prison_gate_open_v37")
	opened.queue_free();gate.closed=true
	for node in editor.canvas.architecture_preview.nodes.values():
		if node is Volume: node.tick_visual()
	var failed: Array=checks.filter(func(c):return not c.passed)
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"passed":failed.is_empty()},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed,"passed":failed.is_empty()}))
	owners.clear()
	if OS.get_cmdline_user_args().has("interactive") and failed.is_empty():
		root.gui_disable_input=false
		DisplayServer.window_set_title("这次怎么逃 · R04 双开口L型弧角 · 地图编辑器")
		await shot(Vector2(1010,1340),1.15,"r04-editor.png")
		return
	quit(0 if failed.is_empty() else 1)

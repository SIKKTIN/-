extends SceneTree
const OUT="res://docs/art/architecture-v35/"
var editor
var checks: Array=[]
var candidate: Dictionary={}
class StudyBackdrop extends Node2D:
	var floor_texture: Texture2D
	var font: Font
	func _draw() -> void:
		load("res://scripts/presentation/texture_tiles.gd").paint(self,floor_texture,Rect2(0,0,1400,900),Vector2(320,320),Rect2(0,0,1400,900))
		draw_string(font,Vector2(130,54),"修正样段 · 连续石砖 / 独立格子拼块",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("33443e"))
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func check(label: String, passed: bool) -> void: checks.append({"name":label,"passed":passed})
func add(id: String, p: Vector2) -> Dictionary: return editor.document.add("walls",p,id)
func native_labels() -> void:
	for spec in [["修改前：额外黑缝，纹理每块重复",Vector2(570,540)],["修正样段：原图连续切分，砖缝跨格子",Vector2(570,1040)]]:
		var label:=Label.new();label.text=spec[0];label.add_theme_font_override("font",editor.canvas.font);label.add_theme_font_size_override("font_size",18);label.add_theme_color_override("font_color",Color("33443e"))
		label.position=editor.canvas.global_position+editor.canvas.screen(spec[1]);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;editor.add_child(label)
func shot(center: Vector2, zoom: float, name: String) -> void:
	var c=editor.canvas;c.zoom=zoom;c.origin=c.size/2-center*zoom;c.queue_redraw()
	await frame();await frame()
	root.get_texture().get_image().save_png(OUT+name)
func clean_shot() -> void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(1400,900);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var backdrop:=StudyBackdrop.new();backdrop.font=editor.canvas.font
	backdrop.floor_texture=editor.canvas.textures[str(editor.canvas.render_profile.floor_asset)]
	viewport.add_child(backdrop)
	var group:=Node2D.new();group.scale=Vector2(2.2,2.2);group.position=Vector2(150,150)-Vector2(600,1100)*2.2;viewport.add_child(group)
	var owner=editor.canvas.architecture_preview.world
	for index in range(owner.walls.size()):
		if owner.walls[index].position.y<1100:continue
		var tile=load("res://scripts/presentation/world_volume.gd").new();group.add_child(tile);tile.configure(owner,"wall",index,{},editor.canvas.definitions)
	for i in range(3):await frame()
	viewport.get_texture().get_image().save_png(OUT+"sample-clean.png")
	viewport.queue_free()
func run() -> void:
	root.size=Vector2i(1600,1100);root.content_scale_size=root.size;root.gui_disable_input=true
	editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame()
	var baseline:=FileAccess.get_sha256("res://data/rooms/r04.json")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"sample-manifest.json"))
	for a in manifest.assets:
		candidate[a.id]=a
		editor.canvas.definitions[a.id]=a
		editor.canvas.textures[a.id]=load("res://scripts/presentation/world_texture.gd").load_asset(a)
		editor.catalog.assets[a.id]=a
	editor.document.placement_assets=editor.canvas.definitions
	var doc=editor.document
	doc.data.id="wall_style_study";doc.data.title="墙体样段 · 原材质 / 连续砖缝 · 待审评"
	doc.data.walls=[];doc.data.fixtures=[];doc.data.architecture={"wall_surfaces":[]}
	doc.data.confinement.cells=[]
	doc.data.crate=[-2000,-2000,20,20];doc.data.door=[-2000,-2000,20,20]
	for layer in ["actors","patrol","items","routine","areas"]:editor.layers.set_visible(layer,false)
	# Existing art, unmodified, at identical camera scale for the comparison.
	for x in [600,640,680]:add("wall_grid_h",Vector2(x,600))
	add("wall_grid_t",Vector2(720,600))
	for x in range(780,1100,40):add("wall_grid_h",Vector2(x,600))
	add("wall_grid_v",Vector2(740,720));add("wall_grid_end",Vector2(740,840))
	# Three left slices end exactly where the T artwork begins (source x=590).
	for i in range(3):add("study_h_left_"+str(i),Vector2(600+i*40,1100))
	add("study_t",Vector2(720,1100))
	# Six-block reflected period: C then C-mirror share the same native edge;
	# no synthetic mortar or bright boundary is painted on the joining tiles.
	var sequence=["0","1","2","2_mirror","1_mirror","0_mirror","0","1"]
	for i in range(sequence.size()):add("study_h_right_"+sequence[i],Vector2(780+i*40,1100))
	add("study_v",Vector2(740,1220));add("study_end",Vector2(740,1280))
	for s in doc.data.architecture.wall_surfaces:
		var ref: Dictionary={"group":"walls","index":s.wall_index}
		var r: Rect2=doc.geometry(ref)
		check(str(s.wall_index)+" full integer grid rectangle",is_zero_approx(fmod(r.position.x,20)) and is_zero_approx(fmod(r.position.y,20)) and is_zero_approx(fmod(r.size.x,20)) and is_zero_approx(fmod(r.size.y,20)))
	check("R04 kept unchanged",baseline==FileAccess.get_sha256("res://data/rooms/r04.json"))
	FileAccess.open(OUT+"sample-map.json",FileAccess.WRITE).store_string(doc.text())
	doc.path=OUT+"sample-map.json";doc.disk_hash=FileAccess.get_sha256(doc.path)
	editor.maps.add_item("墙体样段");editor.maps.set_item_metadata(editor.maps.item_count-1,doc.path);editor.maps.select(editor.maps.item_count-1)
	doc.saved_text=doc.text();doc.changed.emit();editor.set_tool("select")
	await shot(Vector2(830,960),0.96,"comparison.png")
	native_labels();await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"comparison.png")
	# The enlarged review is the new sample only, with native grid selection.
	for n in editor.get_children():
		if n is Label:n.hide()
	await shot(Vector2(840,1240),1.6,"sample-detail.png")
	var a: Dictionary=editor.canvas.at(editor.canvas.screen(Vector2(790,1160)))
	var b: Dictionary=editor.canvas.at(editor.canvas.screen(Vector2(830,1160)))
	check("native sample blocks select independently",a.get("group","")=="walls" and b.get("group","")=="walls" and a.index!=b.index)
	editor.canvas.choose(a);await frame();await frame()
	root.get_texture().get_image().save_png(OUT+"sample-selected.png")
	editor.canvas.choose({})
	await clean_shot()
	# Native image evidence: each boundary uses neighboring master UVs, with no
	# added black strip. Ensure different UV slices rather than repeating a crop.
	check("right-hand faces use three distinct adjacent UV slices",candidate.study_h_right_0.assembly_patches[0].source[0]==950 and candidate.study_h_right_1.assembly_patches[0].source[0]==1140 and candidate.study_h_right_2.assembly_patches[0].source[0]==1330)
	check("left-T-right UV registration",candidate.study_h_left_2.assembly_patches[0].source[0]+190==590 and candidate.study_t.assembly_patches[0].source[0]==590 and candidate.study_t.assembly_patches[2].source[0]+120==950)
	var failed: Array=checks.filter(func(c):return not c.passed)
	FileAccess.open(OUT+"sample-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"passed":failed.is_empty(),"source":"V33 PNG unchanged","review_scope":"sample only; no R04 migration or producer message"},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed,"passed":failed.is_empty()}))
	if OS.get_cmdline_user_args().has("interactive") and failed.is_empty():
		DisplayServer.window_set_title("这次怎么逃 · 墙体修正样段 · 地图编辑器")
		root.gui_disable_input=false
		await shot(Vector2(840,1240),1.4,"sample-open.png")
		print("WALL_STYLE_EDITOR_READY: interactive sample editor")
		return
	quit(0 if failed.is_empty() else 1)

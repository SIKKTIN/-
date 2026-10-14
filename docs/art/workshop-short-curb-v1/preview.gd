extends SceneTree
const OUT := "res://docs/art/workshop-short-curb-v1/"
const ID := "workshop_road_curb_240_v4"
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func run() -> void:
	root.size=Vector2i(1440,950);root.content_scale_size=root.size
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"before-map.json"))
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame();editor.open_now(path);await frame();await frame()
	var doc=editor.document
	var catalog=load("res://scripts/editor/editor_catalog.gd").new()
	var fixture: Dictionary=doc.data.fixtures.filter(func(f):return f.id=="workshop-road-workshop-two-front-short-curb")[0]
	var ref := {"group":"fixtures","index":doc.data.fixtures.find(fixture)}
	var report := {"map_valid":doc.validate().errors.is_empty(),
		"saved_props_retained":doc.data.fixtures.filter(func(f):return not f.get("workshop_short_curb_generated",false))==before.fixtures,
		"walls_retained":doc.data.walls==before.walls,
		"floors_retained":doc.data.floor_regions==before.floor_regions,
		"short_curb_in_palette":catalog.is_placeable(ID),
		"short_curb_searchable":catalog.filtered_entries("furniture","all","短石条").any(func(e):return e.id==ID),
		"no_movement_collision":not fixture.blocks_movement,
		"doorway_not_covered":fixture.rect[0]+fixture.rect[2]==2520,
		"visual_hit_area":not editor.canvas.architecture_preview.visual_hit_areas(ref).is_empty()}
	var placement=doc.add("fixtures",Vector2(100,100),ID)
	var placed: Dictionary=doc.value(placement)
	print("Placed short curb: "+JSON.stringify(placed))
	report.palette_placement_short=placed.rect[2]==240 and placed.get("render_size",[]).size()==2 and placed.render_size[0]==240 and placed.render_size[1]==20 and not placed.blocks_movement
	doc.remove(placement)
	editor.canvas.zoom=.64
	editor.canvas.origin=editor.canvas.size/2-Vector2(2860,1740)*editor.canvas.zoom
	editor.resource_search.text="车间连接道路";editor.rebuild_palette();editor.canvas.queue_redraw()
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+"editor-short-curb.png")
	report.disk_unchanged=FileAccess.get_sha256(path)==disk
	var failed: Array=report.keys().filter(func(k):return not report[k])
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":report,"failed":failed},"\t"))
	print(JSON.stringify({"checks":report.size(),"failed":failed}));quit(0 if failed.is_empty() else 1)

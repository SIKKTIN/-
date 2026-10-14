extends SceneTree
const OUT := "res://docs/art/workshop-roads-v4/"
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String) -> void:
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func read(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://workshop-roads-preview.cfg")
	root.size=Vector2i(1440,950);root.content_scale_size=root.size
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var doc=load("res://scripts/editor/map_document.gd").new()
	assert(doc.open_file(path));assert(doc.validate().errors.is_empty())
	var before := read(OUT+"comparison-baseline.json") if FileAccess.file_exists(OUT+"comparison-baseline.json") else read(OUT+"before-map.json")
	var receipt := read(OUT+"registration.json")
	var report := {"map_valid":true,"all_saved_floors_retained":before.floor_regions==doc.data.floor_regions.filter(func(f):return not f.get("workshop_roads_generated",false)),
		"all_saved_props_retained":before.fixtures==doc.data.fixtures.filter(func(f):return not f.get("workshop_roads_generated",false)),
		"walls_and_doors_retained":before.walls==doc.data.walls and before.access_doors==doc.data.access_doors,
		"original_stone_png_unchanged":FileAccess.get_sha256(receipt.source_png)==receipt.source_sha256}
	var game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game)
	await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	for actor in game.actors:
		actor.set_process(false);actor.set_physics_process(false);actor.immune_until=INF
	game.guard.position=Vector2(3500,3600);game.dog.position=Vector2(3500,3700)
	var actor=game.actors[0];actor.position=Vector2(2200,1770)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	for route in [["north_avenue",Vector2(950,880),Vector2(4160,880)],
		["central_spine",Vector2(2200,1000),Vector2(2200,1950)],
		["workshop_one_front",Vector2(1000,1770),Vector2(2200,1770)],
		["workshop_two_front",Vector2(2360,1820),Vector2(4200,1820)]]:
		report[str(route[0])+" reachable"]=not game.world.find_path(route[1],route[2],actor,false,true).is_empty()
	report.tree_court_entry_clear=game.world.motion_clear(Vector2(3590,1820),Vector2(3590,1960),actor,false,true)
	for id: String in receipt.added_fixture_ids:
		var f: Dictionary=game.world.fixtures.filter(func(f):return f.id==id)[0]
		report["curb nonblocking "+id]=not f.blocks_movement and not game.world.static_solids.has(f.rect)
		var v=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and game.world.fixtures[v.wall_index].id==id)[0]
		report["curb calibrated "+id]=v.visible and v.display_rect.size.is_equal_approx(Vector2(f.rect.size.x,20))
	game.map_camera.following=false;game.map_camera.zoom=Vector2(.35,.35)
	game.map_camera.position=Vector2(2700,1390)-Vector2(root.size)/.7;game.map_camera.force_update_scroll()
	game.presentation.tick(0);await shot("runtime-roads")
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame();editor.open_now(path);await frame();await frame()
	editor.canvas.zoom=.28;editor.canvas.origin=editor.canvas.size/2-Vector2(2540,1515)*editor.canvas.zoom
	editor.resource_search.text="车间连接道路";editor.rebuild_palette();editor.canvas.queue_redraw()
	for id: String in receipt.added_fixture_ids:
		var ref := {"group":"fixtures","index":editor.document.data.fixtures.find(editor.document.data.fixtures.filter(func(f):return f.id==id)[0])}
		report["curb editable "+id]=editor.document.can_remove(ref) and not editor.canvas.architecture_preview.visual_hit_areas(ref).is_empty()
	await shot("editor-roads")
	report.saved_map_unchanged=FileAccess.get_sha256(path)==disk
	var failed: Array=report.keys().filter(func(k):return not report[k])
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":report,"failed":failed},"\t"))
	print(JSON.stringify({"checks":report.size(),"failed":failed}));quit(0 if failed.is_empty() else 1)

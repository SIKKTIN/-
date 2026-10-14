extends SceneTree
const OUT := "res://docs/art/west-service-roads-v3/"
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
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://west-service-roads-preview.cfg")
	root.size=Vector2i(1600,1100);root.content_scale_size=root.size
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var doc=load("res://scripts/editor/map_document.gd").new()
	assert(doc.open_file(path));assert(doc.validate().errors.is_empty())
	var before := read(OUT+"before-map.json")
	var receipt := read(OUT+"registration.json")
	var report := {"map_valid":true,
		"saved_floors_retained":before.floor_regions==doc.data.floor_regions.filter(func(f):return not f.get("west_service_roads_generated",false)),
		"other_props_retained":before.fixtures.filter(func(f):return f.id not in receipt.modified_decor_ids)==doc.data.fixtures.filter(func(f):return f.id not in receipt.modified_decor_ids and not f.get("west_service_roads_generated",false)),
		"walls_and_doors_retained":before.walls==doc.data.walls and before.access_doors==doc.data.access_doors}
	for source: Dictionary in receipt.source_pngs:report["source PNG unchanged "+str(source.path)]=FileAccess.get_sha256(source.path)==source.sha256
	var game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game)
	await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	for actor in game.actors:
		actor.set_process(false);actor.set_physics_process(false);actor.immune_until=INF
	game.guard.position=Vector2(3500,1300);game.dog.position=Vector2(3500,1400)
	var actor=game.actors[0];actor.position=Vector2(2200,3280)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	report.west_lane_north_to_south=not game.world.find_path(Vector2(2200,1900),Vector2(2200,4020),actor,false,true).is_empty()
	report.branch_joins_west_lane=game.world.motion_clear(Vector2(1500,3270),Vector2(2200,3270),actor,false,true)
	report.west_lane_joins_south_road=not game.world.find_path(Vector2(2200,4020),Vector2(4880,4040),actor,false,true).is_empty()
	report.main_lane_no_air_wall=game.world.motion_clear(Vector2(2200,2550),Vector2(2200,3950),actor,false,true)
	for id: String in receipt.added_fixture_ids:
		var f: Dictionary=game.world.fixtures.filter(func(f):return f.id==id)[0]
		report["curb nonblocking "+id]=not f.blocks_movement and not game.world.static_solids.has(f.rect)
		var v=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and game.world.fixtures[v.wall_index].id==id)[0]
		var expected := Vector2(20,f.render_size[0]) if int(f.rotation_quarters)%2 else Vector2(f.render_size[0],20)
		report["curb rotation calibrated "+id]=v.visible and v.display_rect.size.is_equal_approx(expected)
		var ref := {"group":"fixtures","index":doc.data.fixtures.find(doc.data.fixtures.filter(func(s):return s.id==id)[0])}
		report["curb editable "+id]=doc.can_remove(ref)
	game.map_camera.following=false;game.map_camera.zoom=Vector2(.36,.36)
	game.map_camera.position=Vector2(3000,2920)-Vector2(root.size)/.72;game.map_camera.force_update_scroll()
	game.presentation.tick(0);await shot("runtime-roads")
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame();editor.open_now(path);await frame();await frame()
	editor.canvas.zoom=.30;editor.canvas.origin=editor.canvas.size/2-Vector2(3000,2950)*editor.canvas.zoom
	editor.resource_search.text="西侧连接道路";editor.rebuild_palette();editor.canvas.queue_redraw()
	await shot("editor-roads")
	report.saved_map_unchanged=FileAccess.get_sha256(path)==disk
	var failed: Array=report.keys().filter(func(k):return not report[k])
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":report,"failed":failed},"\t"))
	print(JSON.stringify({"checks":report.size(),"failed":failed}));quit(0 if failed.is_empty() else 1)

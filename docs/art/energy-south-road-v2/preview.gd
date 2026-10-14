extends SceneTree
const OUT := "res://docs/art/energy-south-road-v2/"
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
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://energy-south-road-border-preview.cfg")
	root.size=Vector2i(1650,1000);root.content_scale_size=root.size
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var doc=load("res://scripts/editor/map_document.gd").new()
	assert(doc.open_file(path));assert(doc.validate().errors.is_empty())
	var before := read(OUT+"before-map.json")
	var receipt := read(OUT+"registration.json")
	var report := {"map_valid":true,
		"original_png_unchanged":FileAccess.get_sha256(receipt.source_png)==receipt.source_sha256,
		"existing_props_and_physics_unchanged":before.fixtures==doc.data.fixtures.filter(func(f):return not f.get("energy_south_border_generated",false)) and before.walls==doc.data.walls and before.access_doors==doc.data.access_doors}
	var game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game)
	await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	for actor in game.actors:
		actor.set_process(false);actor.set_physics_process(false);actor.immune_until=INF
	game.guard.position=Vector2(3500,1600);game.dog.position=Vector2(3500,1700)
	game.actors[0].position=Vector2(3690,4045)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	game.map_camera.following=false;game.map_camera.zoom=Vector2(.5,.5)
	game.map_camera.position=Vector2(3620,3500)-Vector2(root.size);game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	report.south_walkway_route_reachable=not game.world.find_path(Vector2(2380,4040),Vector2(4880,4040),game.actors[0],false,true).is_empty()
	report.valve_approach_crosses_curb=game.world.motion_clear(Vector2(3930,3950),Vector2(3930,4020),game.actors[0],false,true)
	report.public_yard_crosses_curb=game.world.motion_clear(Vector2(3650,3930),Vector2(3650,4030),game.actors[0],false,true)
	for id: String in receipt.added_fixture_ids:
		var f: Dictionary=game.world.fixtures.filter(func(f):return f.id==id)[0]
		report["curb has no air wall "+id]=not f.blocks_movement and not game.world.static_solids.has(f.rect)
		var v=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and game.world.fixtures[v.wall_index].id==id)[0]
		report["curb art calibrated "+id]=is_equal_approx(v.display_rect.size.x,f.rect.size.x) and is_equal_approx(v.display_rect.size.y,20)
		var ref := {"group":"fixtures","index":doc.data.fixtures.find(doc.data.fixtures.filter(func(s):return s.id==id)[0])}
		report["curb editable "+id]=doc.can_remove(ref)
		var saved := JSON.stringify(doc.data)
		doc.remove(ref);doc.undo()
		report["curb undo exact "+id]=JSON.stringify(doc.data)==saved
	await shot("runtime-bordered")
	# A road-focused native close-up makes both coping boundaries easy to inspect.
	game.map_camera.zoom=Vector2(.9,.9)
	game.map_camera.position=Vector2(3620,3960)-Vector2(root.size)/1.8;game.map_camera.force_update_scroll()
	await shot("road-detail")
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor)
	await frame();await frame();editor.open_now(path);await frame();await frame()
	editor.canvas.zoom=.35;editor.canvas.origin=editor.canvas.size/2-Vector2(3620,3550)*editor.canvas.zoom
	editor.resource_search.text="能源区南侧道路";editor.rebuild_palette();editor.canvas.queue_redraw()
	await shot("editor-bordered")
	report.saved_map_unchanged=FileAccess.get_sha256(path)==disk
	var failed: Array=report.keys().filter(func(k):return not report[k])
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":report,"failed":failed},"\t"))
	print(JSON.stringify({"checks":report.size(),"failed":failed}));quit(0 if failed.is_empty() else 1)
